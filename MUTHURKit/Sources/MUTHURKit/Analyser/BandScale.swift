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
///
/// **Where it settles from is a decision, and so is how long it takes** (D33).
/// Measured, a cold histogram was wrong *upward* on every track tried, by better
/// than three to one: it has not yet heard the loud part, so both percentiles sit
/// low, and every level maps above where the finished scale puts it. A fade-in
/// drawn three and a half rows tall is the analyser inventing a song.
///
/// So a band that has heard nothing is claimed to have been **at full scale all
/// along** (see `Prior`). Both anchors start at the ceiling and the scale
/// descends onto the record rather than rising to meet it, which is what stops
/// the invention. The bottom anchor is the one that shows: while it is still up
/// there, nothing is drawn at all.
///
/// **That makes the prior's weight a length of time, and it is fitted to the
/// script** (`priorWeight`). Pushed far enough the other way it stops inventing
/// and starts erasing — a blank panel over a loud opening is the same failure
/// pointed the other way, and measured, it lasted five seconds. The weight is
/// swept against the script's own behaviour rather than chosen, so what the
/// opening looks like is the script's answer and not anyone's preference.
public struct BandScale: Sendable, Equatable {

    /// `SPEC_WINDOW` (`player:98`). A band that genuinely does not move — a
    /// constant hiss, a held tone — gets a scale wide enough that it stays
    /// honestly flat a quarter of the way up, rather than having its own noise
    /// magnified to fill the column (`player:866`).
    public static let minimumSpan = 6.0

    /// Half-decibel bins from −90 to 0. A whole one is too coarse to divide a
    /// scale that can come out six decibels wide (`player:846`).
    static let bins = 181

    /// The mass a flat prior over this histogram has by construction. Held fixed
    /// while the prior's *shape* was measured, so that what §18.21 compared was
    /// where the mass sits and nothing else. It is a control, not a setting, and
    /// nothing ships at it.
    static let flatMass = BandScale.bins

    /// **The prior's weight, and it is a duration.**
    ///
    /// This was claimed to be "not a second number" and that was wrong. The
    /// weight is the only thing setting how long the prior outvotes the record,
    /// and the arithmetic says exactly how long: the bottom anchor comes off the
    /// seed once `0.25(N + w) ≤ N`, and the top once `0.90(N + w) ≤ N`. At 55,
    /// with ten windows a second, that is **1.9 seconds** for the bottom anchor
    /// and **49.5 seconds** for the top. The bottom one is the number you can
    /// see: it is how long the panel stays dark at the start of a record.
    ///
    /// Which means a warm-up window was never actually avoided — it was only
    /// spelled differently. §18.21 rejected one for needing an invented length,
    /// then picked a length anyway by picking a mass. So it is **fitted** rather
    /// than invented: swept, and set to the value that minimises total
    /// divergence from the script's own lit-band curve over the opening ten
    /// seconds of four real sides. The objective is the script, which `CLAUDE.md`
    /// makes the authority, and that is what separates this from taste.
    static let priorWeight = 55

    private var histogram = [Int](repeating: 0, count: BandScale.bins)
    private var count = 0

    /// What the band is claimed to have done before it was heard at all.
    ///
    /// Only `fullScale` ships. The other two exist because §18.21 was settled by
    /// measuring the three against each other on real material, and a decision
    /// made by measurement should stay measurable.
    enum Prior {
        /// Nothing. What the script effectively has, since it never scales a
        /// track it has not already decoded.
        case none

        /// One count in every bin — *anything is possible*. The cold scale is as
        /// wide as a band can be, which halves the opening error but cannot turn
        /// it over: a scale ninety-odd decibels wide still puts a −60 dBFS
        /// fade-in a third of the way up. Measured and rejected.
        case flat

        /// Everything at 0 dBFS — *the loud part is coming*. Both anchors start
        /// at the ceiling, so the cold scale is narrow and at the top and
        /// anything quieter than full scale draws nothing at all.
        ///
        /// **The weight is how many seconds that lasts**, and it nearly hid this
        /// result twice. At weight one the prior is gone inside a tenth of a
        /// second and the analyser behaves exactly as if it had none — measured,
        /// 27.2 eighths against a cold scale's 27.9. At `flatMass` it holds the
        /// bottom anchor up for five seconds and the panel is blank over audible
        /// music. `priorWeight` is the swept answer in between.
        case fullScale(weight: Int)
    }

    public init() { seed(.fullScale(weight: BandScale.priorWeight)) }

    init(_ prior: Prior) { seed(prior) }

    /// Seeded as the app seeds it, or not at all. Nothing in the app builds the
    /// unseeded one — the §18.21 measurement does, because comparing the starts
    /// is the whole of what it measures.
    init(seeded: Bool) {
        seed(seeded ? .fullScale(weight: BandScale.priorWeight) : .none)
    }

    /// **A new record**, not a new track. A scale carried over from another
    /// record is that record's scale; one carried over from the previous track
    /// is the same performers in the same room an hour apart, and is most of the
    /// evidence this band is ever going to get about track one (D33).
    public mutating func reset() {
        for index in histogram.indices { histogram[index] = 0 }
        count = 0
        seed(.fullScale(weight: BandScale.priorWeight))
    }

    /// The initial condition. Its *level* is not a choice — full scale, the one
    /// level a band cannot exceed. Its *weight* is a choice, and it is the length
    /// of the warm-up this was supposed not to need; see `priorWeight` for what
    /// it was fitted against.
    ///
    /// It is never removed. Taking it out at some threshold would put a second
    /// number in, and it does not need taking out — a record dilutes it during
    /// its first track and the scales carry, so it is spent once per record and
    /// not once per track.
    private mutating func seed(_ prior: Prior) {
        switch prior {
        case .none:
            break
        case .flat:
            for index in histogram.indices { histogram[index] = 1 }
            count = histogram.count
        case .fullScale(let weight):
            histogram[histogram.count - 1] += weight
            count += weight
        }
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
            // looked at a single reading. The seed now covers that case as
            // well — it stands for the unseeded scale the measurement builds,
            // and it changes nothing at all once a second of music has gone by.
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
