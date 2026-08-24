import AVFoundation
import Foundation

import MUTHURKit

/// How a seam is measured, and the tones it is measured on.
///
/// §6 says gapless is a requirement and does not say how you would know. By ear
/// is not an answer: a gap of one millisecond is inaudible on most material and
/// a *phase* discontinuity — the thing that actually happens when a resampler is
/// torn down and rebuilt at a track boundary — is inaudible on nearly all of it,
/// right up until the record is thirty minutes of a single held drone and it is
/// the only thing you can hear.
///
/// So: synthesize a sine, cut it in two, play the two halves as a record, and
/// measure the join. Four numbers come out, and they answer different questions.
///
/// **Length.** How many frames the engine produced against how many the two
/// files contain. Anything inserted at the seam or eaten by it shows up here and
/// nowhere else — a gap that is exactly one buffer of silence is still a perfect
/// waveform on either side of it.
///
/// **Worst sample error.** Every output frame is at a known time, so the sample
/// that should have come out is known too. Subtract. This is deliberately the
/// bluntest measure available: it forgives nothing and flatters nothing, where
/// anything built on differences quietly forgives a smooth droop.
///
/// **Steepness.** The biggest jump between two adjacent output samples, over the
/// biggest jump the signal is entitled to make. This is the one that means
/// *click*: a gap, a dropped frame or a repeated buffer all read far above 1,
/// and a waveform merely going where it was always going reads exactly 1.
///
/// **Spread.** How many frames either side of the boundary are disturbed at all.
/// A number on its own cannot tell a tick from a fade, and those sound nothing
/// alike.
///
/// `worstResidual` is kept for material there is no ideal to subtract — a sine
/// obeys `x[n] = 2·cos(ω)·x[n−1] − x[n−2]` for any phase and amplitude, so it
/// needs no alignment and no reference recording.
enum Seam {

    // MARK: - Tones

    /// A sine written as 32-bit float, sampled at `rate`, whose first sample is
    /// at `startTime` seconds. Parameterised by *time* rather than by frame
    /// number so that two files at two different rates can be two halves of one
    /// continuous signal.
    static func writeTone(
        to url: URL,
        rate: Double,
        channels: AVAudioChannelCount = 2,
        frequency: Double,
        frames: Int,
        startTime: Double,
        amplitude: Double = 1
    ) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)!
        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: rate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        let chunk = 8192
        var written = 0
        while written < frames {
            let count = min(chunk, frames - written)
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: AVAudioFrameCount(count)
            )!
            buffer.frameLength = AVAudioFrameCount(count)
            for channel in 0..<Int(channels) {
                let out = buffer.floatChannelData![channel]
                for n in 0..<count {
                    let t = startTime + Double(written + n) / rate
                    out[n] = Float(amplitude * sin(2 * .pi * frequency * t))
                }
            }
            try file.write(from: buffer)
            written += count
        }
    }

    /// Silence, for the cases where the shape of the record matters and the
    /// waveform does not.
    static func writeSilence(
        to url: URL, rate: Double, channels: AVAudioChannelCount = 2, frames: Int
    ) throws {
        try writeTone(
            to: url, rate: rate, channels: channels, frequency: 0, frames: frames, startTime: 0,
            amplitude: 0
        )
    }

    // MARK: - Measuring

    /// The sample that *should* have come out at output frame `n`.
    static func ideal(
        frame n: Int, rate: Double, frequency: Double, amplitude: Double = 1
    ) -> Double {
        amplitude * sin(2 * .pi * frequency * Double(n) / rate)
    }

    /// The worst any one sample in a window is off by. Straight subtraction
    /// against the tone the record *is*, which is possible because the frame
    /// counts come out exact and output frame n is therefore known to be time
    /// n/rate.
    ///
    /// Preferred over anything cleverer because it cannot flatter the result:
    /// a smooth droop and a single-sample click both show up at their true size,
    /// where a difference-based measure would quietly forgive the first.
    static func worstError(
        _ x: [Float], rate: Double, frequency: Double, amplitude: Double = 1,
        over range: Range<Int>
    ) -> Double {
        var worst = 0.0
        let low = max(0, range.lowerBound)
        let high = min(x.count, range.upperBound)
        guard low < high else { return 0 }
        for n in low..<high {
            let want = ideal(frame: n, rate: rate, frequency: frequency, amplitude: amplitude)
            worst = max(worst, abs(Double(x[n]) - want))
        }
        return worst
    }

    /// `x[n] − 2·cos(ω)·x[n−1] + x[n−2]`, worst case over a window.
    ///
    /// A sampled sine satisfies that recurrence exactly, for any phase and any
    /// amplitude. It is the measure for material there is no ideal to subtract —
    /// it needs no alignment and no reference recording.
    static func worstResidual(_ x: [Float], omega: Double, over range: Range<Int>) -> Double {
        let k = 2 * cos(omega)
        var worst = 0.0
        let low = max(2, range.lowerBound)
        let high = min(x.count, range.upperBound)
        guard low < high else { return 0 }
        for n in low..<high {
            worst = max(worst, abs(Double(x[n]) - k * Double(x[n - 1]) + Double(x[n - 2])))
        }
        return worst
    }

    /// The biggest jump between two adjacent output samples in a window.
    ///
    /// This is the one that means *click*. A gap, a repeated buffer, a converter
    /// that dropped frames — all of them show up as a step from one sample to
    /// the next that the signal itself could never have made. A sine's own
    /// steepest slope is `A·2·sin(πf/rate)`, so anything at or under that is a
    /// waveform going where it was always going to go.
    static func worstStep(_ x: [Float], over range: Range<Int>) -> Double {
        var worst = 0.0
        let low = max(1, range.lowerBound)
        let high = min(x.count, range.upperBound)
        guard low < high else { return 0 }
        for n in low..<high {
            worst = max(worst, abs(Double(x[n]) - Double(x[n - 1])))
        }
        return worst
    }

    /// What that sine's steepest slope actually is, to measure the above against.
    static func naturalStep(rate: Double, frequency: Double, amplitude: Double = 1) -> Double {
        amplitude * 2 * sin(.pi * frequency / rate)
    }

    /// Relative to full scale. `-inf` for an exact zero, which is a real answer
    /// and the one the same-rate seam gives.
    static func decibels(_ linear: Double) -> Double {
        linear <= 0 ? -.infinity : 20 * log10(linear)
    }

    struct Report {
        var expectedFrames: Int
        var actualFrames: Int
        /// Worst sample error in a window centred on the seam.
        var seam: Double
        /// The same measure taken in the middle of a track, where nothing is
        /// happening. This is the floor the measurement itself sits on — the
        /// resampler's own passband error, plus float arithmetic — and the seam
        /// is only interesting relative to it.
        var floor: Double
        /// How many frames around the boundary are disturbed at all, and where
        /// they sit relative to it. A number on its own does not say whether the
        /// artefact is a click or a droop, and those sound nothing alike.
        var spread: Range<Int>
        /// The biggest sample-to-sample jump near the boundary, and the biggest
        /// the signal itself is entitled to make. `step` over `naturalStep`
        /// greater than one is a click.
        var step: Double
        var naturalStep: Double
        var rate: Double

        var seamDB: Double { Seam.decibels(seam) }
        var floorDB: Double { Seam.decibels(floor) }
        var framesLost: Int { expectedFrames - actualFrames }
        var spreadMilliseconds: Double { Double(spread.count) * 1000 / rate }
        /// 1.0 means the waveform is exactly as steep as it is allowed to be.
        var steepness: Double { naturalStep > 0 ? step / naturalStep : 0 }

        var description: String {
            let where_ =
                spread.isEmpty
                ? "nothing"
                : String(
                    format: "%+d…%+d frames (%.2f ms)",
                    spread.lowerBound, spread.upperBound - 1, spreadMilliseconds)
            return String(
                format:
                    "frames %d/%d (%+d) · seam %.1f dBFS (%.3g) · floor %.1f dBFS (%.3g)"
                    + " · disturbs %@ · steepness %.3f",
                actualFrames, expectedFrames, -framesLost, seamDB, seam, floorDB, floor,
                where_ as NSString, steepness
            )
        }
    }

    /// A window of ±`radius` frames either side of where the seam is expected.
    /// Wide on purpose: a resampler smears a boundary across its filter length,
    /// and a measurement that only looked at the exact frame would miss it.
    static func report(
        capture: [Float],
        rate: Double,
        frequency: Double,
        amplitude: Double = 1,
        expectedFrames: Int,
        seamFrame: Int,
        radius: Int = 512
    ) -> Report {
        let seam = worstError(
            capture, rate: rate, frequency: frequency, amplitude: amplitude,
            over: max(0, seamFrame - radius)..<min(capture.count, seamFrame + radius)
        )
        // Half way through the first track, as far from either edge as the
        // signal gets.
        let middle = seamFrame / 2
        let floor = worstError(
            capture, rate: rate, frequency: frequency, amplitude: amplitude,
            over: max(0, middle - radius)..<min(capture.count, middle + radius)
        )
        // Anything an order of magnitude above the floor is the seam's doing
        // rather than the resampler's ordinary error.
        let threshold = max(floor * 10, 1e-7)
        var low = Int.max
        var high = Int.min
        for n in max(0, seamFrame - radius)..<min(capture.count, seamFrame + radius) {
            let want = ideal(frame: n, rate: rate, frequency: frequency, amplitude: amplitude)
            guard abs(Double(capture[n]) - want) > threshold else { continue }
            low = min(low, n - seamFrame)
            high = max(high, n - seamFrame)
        }

        return Report(
            expectedFrames: expectedFrames,
            actualFrames: capture.count,
            seam: seam,
            floor: floor,
            spread: low <= high ? low..<(high + 1) : 0..<0,
            step: worstStep(
                capture, over: max(0, seamFrame - radius)..<min(capture.count, seamFrame + radius)
            ),
            naturalStep: naturalStep(rate: rate, frequency: frequency, amplitude: amplitude),
            rate: rate
        )
    }
}

/// The measurements go to stdout in one grep-able form, because the numbers are
/// the deliverable and they end up in `docs/parity.md` by hand.
enum SeamLog {
    static func record(_ label: String, _ report: Seam.Report) {
        print("SEAM | \(label) | \(report.description)")
    }
}

/// A throwaway directory that cleans up after itself, for the written tones.
/// Nothing here is ever committed and nothing outlives the test.
struct ToneFolder: ~Copyable {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "muthur-play/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func file(_ name: String) -> URL { url.appending(path: name) }

    deinit { try? FileManager.default.removeItem(at: url) }
}

/// A record made of files that exist, without asking §3 to read them — the
/// durations are known because the tones were written to order.
func recordOf(_ entries: [(URL, Int)], label: String = "tones") -> Record {
    Record(
        tracks: entries.enumerated().map { index, entry in
            Track(
                url: entry.0, duration: entry.1, title: entry.0.lastPathComponent,
                artist: "", number: index + 1, disc: 1
            )
        },
        album: label,
        albumArtist: "",
        year: "",
        sourceLabel: label
    )
}
