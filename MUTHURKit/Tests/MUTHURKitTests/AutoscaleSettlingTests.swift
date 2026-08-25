import AVFoundation
import Foundation
import Testing

@testable import MUTHURKit

/// §18.21, measured rather than looked at, three times over.
///
/// The question was how long the live autoscale takes to agree with the one the
/// script has from the downbeat. The script decodes the whole track before it
/// draws a frame, so its percentiles are over all of it; here they are over the
/// track *so far*. The difference is only the sample.
///
/// Both are run over the same real record, window for window, and compared in
/// the unit the disagreement is visible in: **eighths of a cell**, of which a
/// column has forty. One eighth is the smallest move a column can make; eight is
/// a whole row of the five.
///
/// **What it found was not a delay but a direction.** A cold scale was wrong
/// *upward* on every track tried — it had not yet heard the loud part, so both
/// percentiles sat low and every level mapped above where it belonged — and on a
/// track that fades in it drew twenty-eight eighths, three and a half of the five
/// rows, where the script drew none. That is the analyser inventing a song.
///
/// **D33 is the answer and it is two things.** Carry the scales between tracks,
/// which fixes everything but the track you start on; and start the histogram at
/// the ceiling, so a band that has heard nothing is claimed to have been at full
/// scale all along and the scale comes *down* onto the record rather than up to
/// meet it.
///
/// Three priors were measured against each other and the numbers are in §18.21.
/// The rejected ones are kept alive here as `BandScale.Prior` cases, because a
/// decision made by measurement should stay measurable.
///
/// Material tier: needs the library, skipped without it. Nothing is written.
@Suite("§18.21 — how the autoscale settles")
struct AutoscaleSettlingTests {

    /// Every window of one track, as sixteen band levels in dBFS.
    ///
    /// Decoded flat out rather than in real time — the same arithmetic the tap
    /// does, asked of a file instead of of a buffer, so a three-minute track
    /// measures in about a second.
    static func levels(of url: URL) throws -> [[Double]] {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(
            standardFormatWithSampleRate: file.processingFormat.sampleRate,
            channels: file.processingFormat.channelCount
        )!
        let spectrum = Spectrum(rate: format.sampleRate)
        let hop = AVAudioFrameCount(spectrum.hop)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: hop)!

        var rows: [[Double]] = []
        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: hop)
            guard buffer.frameLength == hop else { break }
            let channels = (0..<Int(format.channelCount)).map { channel in
                Array(
                    UnsafeBufferPointer(
                        start: buffer.floatChannelData![channel], count: spectrum.hop))
            }
            rows.append(spectrum.levels(channels))
        }
        return rows
    }

    /// What the script would draw: the whole track in hand before a frame is,
    /// and no prior — the bash player has the future and needs no guess about it.
    static func script(_ rows: [[Double]]) -> [[Int]] {
        var whole = [BandScale](repeating: BandScale(.none), count: Bands.count)
        for row in rows {
            for band in row.indices { whole[band].observe(row[band]) }
        }
        return rows.map { row in row.indices.map { whole[$0].height(of: row[$0]) } }
    }

    /// What the port draws: the same histogram asked of a growing pile, from
    /// whatever the scales were at the start of the track.
    static func live(_ rows: [[Double]], from start: [BandScale]) -> [[Int]] {
        var growing = start
        return rows.map { row in
            for band in row.indices { growing[band].observe(row[band]) }
            return row.indices.map { growing[$0].height(of: row[$0]) }
        }
    }

    /// Sixteen scales that have heard nothing, believing whatever the prior says.
    static func fresh(_ prior: BandScale.Prior) -> [BandScale] {
        [BandScale](repeating: BandScale(prior), count: Bands.count)
    }

    /// Disagreement over one stretch of the track, in eighths. `signed` is the
    /// half that matters most: positive is the port drawing taller than the
    /// script, which is the direction that must not happen.
    static func apart(
        _ script: [[Int]], _ live: [[Int]], seconds: Range<Int>
    ) -> (mean: Double, peak: Int, signed: Double) {
        let from = min(seconds.lowerBound * Spectrum.rowsPerSecond, script.count)
        let to = min(seconds.upperBound * Spectrum.rowsPerSecond, script.count)
        guard to > from else { return (0, 0, 0) }
        var sum = 0
        var signed = 0
        var peak = 0
        for window in from..<to {
            for (a, b) in zip(script[window], live[window]) {
                sum += abs(a - b)
                signed += b - a
                peak = max(peak, abs(a - b))
            }
        }
        let cells = Double((to - from) * Bands.count)
        return (Double(sum) / cells, peak, Double(signed) / cells)
    }

    /// What fraction of cells are lit at all over one second. The eighths metric
    /// cannot see this and it is the thing the eye sees first: nought is a blank
    /// panel and three is a sliver at the bottom of every band.
    static func lit(_ drawn: [[Int]], second: Int) -> Double {
        let from = second * Spectrum.rowsPerSecond
        let to = min(from + Spectrum.rowsPerSecond, drawn.count)
        guard to > from else { return 0 }
        let count = drawn[from..<to].flatMap { $0 }.filter { $0 > 0 }.count
        return Double(count) * 100 / Double((to - from) * Bands.count)
    }

    static func sides() -> [URL] {
        AudioFiles.scan(Fixtures.rumours).sorted { $0.path < $1.path }
    }


    /// **Where the mass sits.** Three shapes of prior on the one track nothing
    /// else can help — the track you put the record on for — at the mass a flat
    /// prior over this histogram has, so that only the *shape* varies.
    ///
    /// This is the measurement that settled the location and it is kept at its
    /// original weight on purpose: it is a control, and re-running it at the
    /// shipping weight would answer a different question.
    @Test(
        "Only a prior at full scale turns the bias over, and only at real weight",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func whereTheMassSits() throws {
        let files = Self.sides()
        try #require(!files.isEmpty, "no audio in \(Fixtures.rumours.path)")

        let rows = try Self.levels(of: files[0])
        try #require(rows.count > 600, "\(files[0].lastPathComponent) is too short to say anything")
        let reference = Self.script(rows)

        func opening(_ prior: BandScale.Prior) -> (mean: Double, peak: Int, signed: Double) {
            Self.apart(reference, Self.live(rows, from: Self.fresh(prior)), seconds: 0..<5)
        }

        // No prior: measured 27.9 eighths of a 40-eighth column, all of it
        // upward, peaking at the whole column over a track that fades in.
        let cold = opening(.none)
        #expect(cold.signed > 25, "a cold scale now opens at \(cold.signed)")
        #expect(cold.peak == AnalyserColumns.top)

        // Flat — *anything is possible*. Measured 14.0 / 27 / +14.0: it halves
        // the error and takes the peak off the ceiling, and it cannot turn the
        // bias over, because a scale ninety decibels wide still maps a quiet
        // fade-in a third of the way up. Rejected on that.
        let flat = opening(.flat)
        #expect(flat.mean < cold.mean / 1.8, "flat opens \(flat.mean) against \(cold.mean)")
        #expect(flat.signed > 10, "the flat prior has stopped reading high: \(flat.signed)")

        // Full scale at the same mass — *the loud part is coming*. Measured
        // 0.0 / 4 / −0.0. Only moving the **bottom** anchor can do this.
        let top = opening(.fullScale(weight: BandScale.flatMass))
        #expect(top.signed <= 0.5, "the bias did not turn over: \(top.signed)")
        #expect(top.peak < AnalyserColumns.rows, "worst cell is \(top.peak) eighths out")

        // And weight is not free. One full-scale observation is gone inside a
        // tenth of a second: measured 27.2 against a cold scale's 27.9, which is
        // no prior at all. This is why the weight had to be fitted rather than
        // reasoned about — see `theFittedWeight`.
        let feather = opening(.fullScale(weight: 1))
        #expect(
            abs(feather.mean - cold.mean) < 2,
            "one observation now does something: \(feather.mean) against \(cold.mean)")
    }

    /// **The objective, and the shape of the answer.**
    ///
    /// Stated before it was run and not changed after: the mean absolute
    /// difference, in percentage points, between the port's lit-band curve and
    /// the script's over seconds 0–9, across four sides, each decoded cold —
    /// because the scales only carry *within* a sitting, so any track can be the
    /// one you dropped the needle on. Forty points, no weighting, no tie-breaks.
    ///
    /// Swept 0…400. The basin is broad and shallow — everything from 40 to 105
    /// scores within 1.6 points — which is the useful part: the fitted weight is
    /// not balanced on a knife edge and a change of a few either way is not a
    /// regression. It is held here against the two ends that *are* wrong.
    @Test(
        "The fitted weight beats both ends of the sweep on the script's own curve",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func theFittedWeight() throws {
        let files = Self.sides()
        try #require(files.count > 3)

        func divergence(_ prior: BandScale.Prior) throws -> Double {
            var total = 0.0
            for url in files.prefix(4) {
                let rows = try Self.levels(of: url)
                let reference = Self.script(rows)
                let drawn = Self.live(rows, from: Self.fresh(prior))
                for second in 0..<10 {
                    total += abs(Self.lit(drawn, second: second) - Self.lit(reference, second: second))
                }
            }
            return total / 40
        }

        // Measured: 34.03 with no prior, 27.22 fitted, 34.50 at the flat mass.
        // The two failures are symmetrical and the fit sits between them.
        let fitted = try divergence(.fullScale(weight: BandScale.priorWeight))
        let none = try divergence(.none)
        let heavy = try divergence(.fullScale(weight: BandScale.flatMass))

        let note = "fitted \(fitted), none \(none), heavy \(heavy)"
        #expect(fitted < none, "\(note)")
        #expect(fitted < heavy, "\(note)")
        #expect(fitted < 29, "\(note)")
    }

    /// **The two-ended guard, and it is the whole point of the fit.** Neither
    /// failure may come back: not the full panel lit from second zero over a
    /// fade-in the script leaves dark, and not the blank panel over a loud
    /// opening the script draws on.
    ///
    /// Measured at the fitted weight, the dark start is **one second**, not five,
    /// and every side is up past four fifths of its bands by the third.
    @Test(
        "A record neither blanks nor floods at the top",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func neitherBlankNorFlooded() throws {
        let files = Self.sides()
        try #require(files.count > 3)

        for url in files.prefix(4) {
            let rows = try Self.levels(of: url)
            let drawn = Self.live(rows, from: Self.fresh(.fullScale(weight: BandScale.priorWeight)))

            // The flat prior's failure: 100% of bands lit from the downbeat.
            let start = Self.lit(drawn, second: 0)
            #expect(start < 50, "\(url.lastPathComponent) opens \(start)% lit")

            // The heavy prior's failure: nothing at all, for five seconds.
            // Measured here at 84, 96, 98 and 100 percent.
            let recovered = Self.lit(drawn, second: 2)
            #expect(recovered > 80, "\(url.lastPathComponent) is only \(recovered)% lit at 2s")
        }
    }

    /// **What the fit costs, in the unit the fit did not optimise.** The
    /// objective was the lit-band curve, so the eighths are a report rather than
    /// a target — and they are worth keeping because the trade is visible in
    /// them: the fitted weight is **worse** than the heavy one on the side that
    /// fades in and better on the three that do not.
    ///
    /// Cold, first five seconds, measured: 9.4 / 10.2 / 7.0 / 5.0 fitted against
    /// 0.0 / 13.0 / 12.7 / 3.8 heavy. No cold column reaches the top row from
    /// nothing on either — the failure that started all this was a peak of forty.
    @Test(
        "No cold column runs the whole height, whatever it costs elsewhere",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func nothingRunsTheColumn() throws {
        let files = Self.sides()
        try #require(files.count > 3)

        for url in files.prefix(4) {
            let rows = try Self.levels(of: url)
            let reference = Self.script(rows)
            let drawn = Self.live(rows, from: Self.fresh(.fullScale(weight: BandScale.priorWeight)))

            var tallest = 0
            for window in 0..<min(15 * Spectrum.rowsPerSecond, rows.count) {
                for (a, b) in zip(reference[window], drawn[window]) where b > a {
                    tallest = max(tallest, b - a)
                }
            }
            // Measured 8 to 21 eighths against a cold scale's 40 on all four.
            let note = "\(url.lastPathComponent) draws \(tallest) eighths over the script"
            #expect(tallest < AnalyserColumns.top / 2 + 4, "\(note)")

            let opening = Self.apart(reference, drawn, seconds: 0..<5)
            #expect(opening.mean < 12, "\(url.lastPathComponent) opens \(opening.mean) out")
        }
    }

    /// The other half of D33, and the half that does the most work. Every track
    /// after the first opens on the previous track's evidence, and the prior is
    /// long spent by then — measured, it makes under an eighth of difference to
    /// these three whether it was 55, 181 or nothing at all.
    @Test(
        "A carried scale fixes every track but the one you start on",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func carriedOver() throws {
        let files = Self.sides()
        try #require(files.count > 3)

        var carried = Self.fresh(.fullScale(weight: BandScale.priorWeight))
        var first = true
        for url in files.prefix(4) {
            let rows = try Self.levels(of: url)
            let reference = Self.script(rows)
            let drawn = Self.live(rows, from: carried)
            let opening = Self.apart(reference, drawn, seconds: 0..<5)

            if !first {
                // Measured 4.1, 6.5 and 6.8 eighths, against 11.3, 16.1 and 21.0
                // with no carry at all. Under a row of five.
                let note = "\(url.lastPathComponent) opens \(opening.mean) eighths out"
                #expect(opening.mean < 8, "\(note)")
                // And not by drawing nothing: the prior is spent, so there is no
                // dark second on any track but the first. Measured 35, 20 and 68.
                #expect(Self.lit(drawn, second: 0) > 10, "\(note)")
            }
            first = false

            for row in rows {
                for band in row.indices { carried[band].observe(row[band]) }
            }
        }
    }

    /// **A known permanent divergence, not a cost that is going to be fixed.**
    /// A scale made of the whole record rather than of one track is not this
    /// track's scale, and a track quieter than its neighbours reads low for its
    /// whole length. Worst measured a minute in: 7.2 eighths on Never Going Back
    /// Again, an acoustic track between two loud ones.
    ///
    /// **The baseline is measured here rather than quoted**, because most of
    /// that number is not the carry. Against the same track scaled by itself —
    /// a live scale started fresh on it, prior and all, which is what happens
    /// when you drop the needle there — the four sides read 3.2 / 3.1 / 2.9 /
    /// 2.0 against 3.2 / 5.4 / 7.2 / 4.2 carried. A live scale a minute in has
    /// still not heard the rest of the track and the script has, and that gap
    /// would be there with nothing carried at all. **The carry's own share is
    /// the difference: 4.3 eighths at worst, half a row.**
    ///
    /// The first side is the check on the arithmetic — with nothing to carry
    /// the two figures have to agree exactly, and they do.
    @Test(
        "What a carried scale costs a minute in, against scaling the track by itself",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func steadyStateCost() throws {
        let files = Self.sides()
        try #require(files.count > 3)

        var carried = Self.fresh(.fullScale(weight: BandScale.priorWeight))
        var first = true
        for url in files.prefix(4) {
            let rows = try Self.levels(of: url)
            let reference = Self.script(rows)
            let minute = Self.apart(reference, Self.live(rows, from: carried), seconds: 55..<60)

            // What this track would read with nothing carried into it: the same
            // seed the app starts a record on, applied to this track alone.
            let alone = Self.apart(
                reference,
                Self.live(rows, from: Self.fresh(.fullScale(weight: BandScale.priorWeight))),
                seconds: 55..<60)

            let note =
                "\(url.lastPathComponent) is \(minute.mean) carried, \(alone.mean) by itself"
            #expect(minute.mean < 8, "\(note)")

            // Live-against-whole-track, with the carry taken out of it. Measured
            // 3.2 / 3.1 / 2.9 / 2.0 — under half a row on every side.
            #expect(alone.mean < 4, "\(note)")

            if first {
                // There is nothing to carry into the first side, so the two
                // measurements are the same measurement. If this ever parts, the
                // harness is lying about which scale it fed.
                #expect(minute.mean == alone.mean, "\(note)")
            } else {
                // The carry's own price: 2.3, 4.3 and 2.2 eighths.
                let cost = minute.mean - alone.mean
                #expect(cost < 5, "the carry costs \(cost) eighths on \(url.lastPathComponent)")
            }
            first = false

            for row in rows {
                for band in row.indices { carried[band].observe(row[band]) }
            }
        }
    }
}
