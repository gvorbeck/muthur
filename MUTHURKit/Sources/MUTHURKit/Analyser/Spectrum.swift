import Accelerate
import Foundation

/// §9's measurement: sixteen band levels in dBFS, ten times a second, off live
/// samples.
///
/// The script decodes each track ahead of time through sixteen ffmpeg
/// bandpasses and reads `lavfi.astats.Overall.RMS_level` out of each
/// (`player:766`). Nothing here can decode ahead — the samples arrive as they
/// are heard — so the sixteen filters become one FFT and sixteen weighted sums
/// of its power spectrum. The number that comes out is the same number: the RMS
/// of the band-passed signal over the window, in decibels below full scale.
///
/// **Ten rows a second at any sample rate.** The script resamples to 44.1 kHz
/// before counting the window in samples, so that a 48 kHz file lands at the
/// same row rate as a CD (`player:774`). The reason is the row rate, not the
/// resampling, so the window here is `rate / 10` samples of whatever came in.
///
/// Not `Sendable`, and not by accident: it owns an `FFTSetup` and a scratch
/// buffer, and it is meant to be held by one thing at a time.
final class Spectrum {

    /// `SPEC_HZ` (`player:97`).
    static let rowsPerSecond = 10

    let rate: Double
    /// `n = 44100 / SPEC_HZ` (`player:771`), in this file's own samples.
    let hop: Int
    /// The transform, longer than the window. The extra length buys no
    /// resolution — a hundred-millisecond window resolves what it resolves —
    /// but it puts enough bins under the bottom band that the weighted sum is a
    /// fair reading of the filter rather than a five-point sketch of it.
    let length: Int

    /// Hann. The script's windows are square, because an IIR biquad does not
    /// care; an FFT does. A square window's skirts fall away at six decibels an
    /// octave, which would put a loud kick drum into the top band and light it,
    /// and a column that moves because of something an octave away is the panel
    /// lying about what you are hearing.
    private let window: [Float]
    /// Σw². Parseval's normaliser, and the reason a full-scale sine reads
    /// −3.01 dB here and not something a window function decided.
    private let windowPower: Double

    private let weights: [[Float]]
    private let setup: FFTSetup
    private let log2n: vDSP_Length

    private var windowed: [Float]
    private var real: [Float]
    private var imaginary: [Float]
    private var binPower: [Float]

    init(rate: Double) {
        self.rate = rate
        let hop = max(64, Int((rate / Double(Spectrum.rowsPerSecond)).rounded()))
        self.hop = hop

        var length = 1
        while length < hop { length <<= 1 }
        length = min(32768, max(4096, length << 1))
        self.length = length

        log2n = vDSP_Length(log2(Double(length)).rounded())
        setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

        window = vDSP.window(
            ofType: Float.self, usingSequence: .hanningDenormalized, count: hop,
            isHalfWindow: false
        )
        windowPower = window.reduce(0) { $0 + Double($1) * Double($1) }

        weights = Bands.centres.map { Bands.weights(centre: $0, rate: rate, length: length) }

        windowed = [Float](repeating: 0, count: length)
        real = [Float](repeating: 0, count: length / 2)
        imaginary = [Float](repeating: 0, count: length / 2)
        binPower = [Float](repeating: 0, count: length / 2 + 1)
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    /// Digital silence comes back from ffmpeg as `-inf`, which would read as
    /// 0 dB — the loudest thing there is — if it were simply added to a number
    /// (`player:819`).
    static let floor = -90.0

    /// Sixteen levels in dBFS for one window of one hop's worth of samples.
    ///
    /// `channels` is deinterleaved and every one of them is measured, because
    /// `astats`' `Overall` is the aggregate across channels and a mono downmix
    /// would lose anything the two sides do out of phase — which on a record is
    /// usually the bass.
    func levels(_ channels: [[Float]]) -> [Double] {
        guard !channels.isEmpty else {
            return [Double](repeating: Spectrum.floor, count: Bands.count)
        }
        for index in binPower.indices { binPower[index] = 0 }
        for samples in channels { accumulate(samples) }

        let share = Float(channels.count)
        var levels = [Double](repeating: Spectrum.floor, count: Bands.count)
        for band in 0..<Bands.count {
            var meanSquare: Float = 0
            vDSP_dotpr(binPower, 1, weights[band], 1, &meanSquare, vDSP_Length(binPower.count))
            let value = Double(meanSquare / share)
            // 10·log₁₀ of a mean square is 20·log₁₀ of an RMS. The floor stands
            // in for the logarithm of nothing.
            let dB = value > 0 ? 10 * log10(value) : Spectrum.floor
            levels[band] = dB.isFinite ? max(Spectrum.floor, dB) : Spectrum.floor
        }
        return levels
    }

    /// One channel's power spectrum, added into `binPower`, already scaled so
    /// that the sum over every bin is the channel's mean square.
    ///
    /// Parseval, with vDSP's packed-real convention accounted for: `zrip`
    /// returns twice the true transform, DC in `real[0]` and Nyquist in
    /// `imaginary[0]`, and every bin between stands for a conjugate pair.
    private func accumulate(_ samples: [Float]) {
        let taken = min(samples.count, hop)
        guard taken > 0 else { return }

        vDSP.multiply(
            samples[0..<taken], window[0..<taken], result: &windowed[0..<taken]
        )
        if taken < length {
            for index in taken..<length { windowed[index] = 0 }
        }

        let half = length / 2
        let scale = Float(1 / (Double(length) * windowPower))

        windowed.withUnsafeBufferPointer { source in
            real.withUnsafeMutableBufferPointer { realBuffer in
                imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                    var split = DSPSplitComplex(
                        realp: realBuffer.baseAddress!, imagp: imaginaryBuffer.baseAddress!
                    )
                    source.baseAddress!.withMemoryRebound(
                        to: DSPComplex.self, capacity: half
                    ) { interleaved in
                        vDSP_ctoz(interleaved, 2, &split, 1, vDSP_Length(half))
                    }
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))

                    let realp = realBuffer.baseAddress!
                    let imagp = imaginaryBuffer.baseAddress!

                    // DC and Nyquist ride in one another's slot and stand for
                    // themselves alone; everything between stands for two.
                    binPower[0] += realp[0] * realp[0] * 0.25 * scale
                    binPower[half] += imagp[0] * imagp[0] * 0.25 * scale
                    for bin in 1..<half {
                        let magnitude = realp[bin] * realp[bin] + imagp[bin] * imagp[bin]
                        binPower[bin] += magnitude * 0.5 * scale
                    }
                }
            }
        }
    }
}
