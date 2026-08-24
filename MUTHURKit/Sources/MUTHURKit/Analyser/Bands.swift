import Foundation

/// §9 — sixteen bands, spaced by octaves rather than hertz (`player:109`).
///
/// The script hands the sixteen centres to sixteen ffmpeg `bandpass` filters and
/// reads the RMS out of each. There is no ffmpeg in the path here, so what is
/// ported is the *filter*: its magnitude response, evaluated once per bin at
/// setup and used to weight the spectrum. Same shape, same overlap, same
/// skirts — arrived at by arithmetic instead of by a subprocess.
public enum Bands {

    /// `SPEC_FREQS` (`player:109`). Even steps in octaves, because that is how
    /// the ear divides it and how the low end earns enough bands to move
    /// independently instead of as one lump.
    public static let centres: [Double] = [
        40, 59, 88, 132, 197, 294, 439, 655,
        976, 1456, 2171, 3237, 4827, 7197, 10731, 16000,
    ]

    public static let count = centres.count

    /// `w=1.1` octaves (`player:783`). Enough overlap that no frequency falls in
    /// a gap between two bands, tight enough that neighbours still move
    /// independently.
    public static let width = 1.1

    /// The power response of ffmpeg's `bandpass=f=<centre>:width_type=o:w=1.1`
    /// at one frequency, as a plain gain — 1.0 at the centre.
    ///
    /// This is the RBJ cookbook bandpass ffmpeg builds from `af_biquads.c`, in
    /// its constant-peak-gain form (`csg=0`, which is the default and therefore
    /// what the script gets):
    ///
    ///     w0    = 2π f0 / Fs
    ///     alpha = sin(w0) · sinh( (ln2 / 2) · w · w0 / sin(w0) )
    ///     b = [ alpha, 0, −alpha ]     a = [ 1 + alpha, −2cos(w0), 1 − alpha ]
    ///
    /// `width_type=o` is what puts the bandwidth in octaves, and it is the
    /// `sinh` that turns octaves into a Q.
    public static func power(centre: Double, width: Double = Bands.width, rate: Double, at
        frequency: Double) -> Double
    {
        let w0 = 2 * .pi * centre / rate
        let sinW0 = sin(w0)
        guard sinW0 > 0, centre * 2 < rate else { return 0 }
        let alpha = sinW0 * sinh(log(2.0) / 2 * width * w0 / sinW0)

        let b0 = alpha, b1 = 0.0, b2 = -alpha
        let a0 = 1 + alpha, a1 = -2 * cos(w0), a2 = 1 - alpha

        // |H(e^{jw})|², evaluated straight off the coefficients. z⁻¹ = e^{-jw}.
        let w = 2 * .pi * frequency / rate
        let (c1, s1) = (cos(w), sin(w))
        let (c2, s2) = (cos(2 * w), sin(2 * w))

        let numeratorReal = b0 + b1 * c1 + b2 * c2
        let numeratorImaginary = -(b1 * s1 + b2 * s2)
        let denominatorReal = a0 + a1 * c1 + a2 * c2
        let denominatorImaginary = -(a1 * s1 + a2 * s2)

        let numerator = numeratorReal * numeratorReal + numeratorImaginary * numeratorImaginary
        let denominator =
            denominatorReal * denominatorReal + denominatorImaginary * denominatorImaginary
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    /// One band's response across every bin of an FFT of this length, ready to
    /// be dotted with a power spectrum.
    ///
    /// Above Nyquist there is nothing, and the top band's centre is 16 kHz — a
    /// rate low enough to put that above Nyquist leaves the band silent rather
    /// than wrapped around, which is what a real filter would do to it too.
    static func weights(centre: Double, rate: Double, length: Int) -> [Float] {
        let bins = length / 2 + 1
        return (0..<bins).map { bin in
            Float(power(centre: centre, rate: rate, at: Double(bin) * rate / Double(length)))
        }
    }
}
