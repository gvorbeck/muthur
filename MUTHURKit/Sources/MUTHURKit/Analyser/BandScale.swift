import Foundation

/// §9's whole trick, re-derived for a signal that arrives as it is heard
/// (`player:831`).
///
/// Each band is scaled by what *that band* actually does, not by one scale for
/// all sixteen: the bass of a record runs tens of decibels above its top octave,
/// and a single scale would leave half the panel flat all night.
///
/// The anchors are the **25th and 90th percentile** of the band's own level
/// distribution, placed a quarter and six-sevenths of the way up the column. Not
/// the extremes, and this is the part that matters: a record mastered in this
/// century spends its life within a few decibels of its own ceiling with a long
/// thin tail down into the gaps between songs. Scale that tail into the column
/// and the tail gets the column — every band sits pinned near the top and
/// twitches. Throw the tail away and the columns use their whole height.
///
/// **What changed, and it is only the sample.** The script has the finished
/// track in front of it before it draws a frame, so its percentiles are over the
/// whole track. Here they are over the track *so far* — the same histogram, the
/// same two percentiles, the same arithmetic, asked a hundred times a second of
/// a growing pile instead of once of a finished one. The scale therefore settles
/// during the opening bars rather than being right from the downbeat, which is
/// the price of not knowing the future and is §18.21.
public struct BandScale: Sendable, Equatable {

    /// `SPEC_WINDOW` (`player:98`). A band that genuinely does not move — a
    /// constant hiss, a held tone — gets a scale wide enough that it stays
    /// honestly flat a quarter of the way up, rather than having its own noise
    /// magnified to fill the column (`player:866`).
    public static let minimumSpan = 6.0

    /// Half-decibel bins from −90 to 0. A whole one is too coarse to divide a
    /// scale that can come out six decibels wide (`player:846`).
    private var histogram = [Int](repeating: 0, count: 181)
    private var count = 0

    public init() {}

    /// The columns reset at every track change, and so does this: a scale
    /// carried over from the last track is the last track's scale.
    public mutating func reset() {
        for index in histogram.indices { histogram[index] = 0 }
        count = 0
    }

    public mutating func observe(_ dB: Double) {
        let clamped = dB.isFinite ? max(Spectrum.floor, dB) : Spectrum.floor
        let bin = min(180, max(0, Int((clamped + 90) * 2)))
        histogram[bin] += 1
        count += 1
    }

    /// Where the bottom and the top of this column sit, in decibels.
    ///
    /// `span = (q90 − q25) / 0.60` and `lo = q25 − 0.25·span` is the placement:
    /// the quarter mark a quarter of the way up, the ninety mark six sevenths
    /// of the way up, and the 0.60 between them falling out of the two
    /// (`player:869`).
    public var bounds: (lo: Double, hi: Double) {
        guard count > 0 else {
            return (Spectrum.floor - 0.25 * BandScale.minimumSpan,
                Spectrum.floor - 0.25 * BandScale.minimumSpan + BandScale.minimumSpan)
        }
        let wantA = Int(Double(count) * 0.25)
        let wantB = Int(Double(count) * 0.90)

        var cumulative = 0
        var q25 = Spectrum.floor
        var q90 = 0.0
        var haveA = false
        for bin in 0...180 {
            cumulative += histogram[bin]
            // `c > 0` is not in the awk, and is the one place the live version
            // has to say something the script never had to. With a whole track
            // in hand both marks land in the thousands and an empty bin cannot
            // satisfy them; with four frames in hand both marks are nought, and
            // without this the scan would answer −90 to both before it had
            // looked at a single reading. It changes nothing at all once a
            // second of music has gone by.
            guard cumulative > 0 else { continue }
            if !haveA && cumulative >= wantA {
                q25 = Double(bin) / 2 - 90
                haveA = true
            }
            if cumulative >= wantB {
                q90 = Double(bin) / 2 - 90
                break
            }
        }

        var span = (q90 - q25) / 0.60
        if span < BandScale.minimumSpan { span = BandScale.minimumSpan }
        let lo = q25 - 0.25 * span
        return (lo, lo + span)
    }

    /// One column's height in eighths, 0 through `AnalyserColumns.top`
    /// (`player:877`).
    public func height(of dB: Double) -> Int {
        let (lo, hi) = bounds
        guard hi > lo else { return 0 }
        let value = dB.isFinite ? max(Spectrum.floor, dB) : Spectrum.floor
        let scaled = (value - lo) / (hi - lo) * Double(AnalyserColumns.top) + 0.5
        return min(AnalyserColumns.top, max(0, Int(scaled)))
    }
}
