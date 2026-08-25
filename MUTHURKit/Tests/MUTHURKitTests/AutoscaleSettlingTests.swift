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

    /// **The three priors, on the one track nothing else can help** — the track
    /// you put the record on for. One decode, four scales, and the whole of why
    /// D33 is the prior it is.
    @Test(
        "Only a prior at full scale turns the bias over, and only at full weight",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func theThreePriors() throws {
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
        // bias over, because a scale ninety decibels wide still puts a quiet
        // fade-in a third of the way up. Rejected on that.
        let flat = opening(.flat)
        #expect(flat.mean < cold.mean / 1.8, "flat opens \(flat.mean) against \(cold.mean)")
        #expect(flat.signed > 10, "the flat prior has stopped reading high: \(flat.signed)")

        // Full scale — *the loud part is coming*. Measured 0.0 / 4 / −0.0.
        let top = opening(.fullScale(weight: BandScale.priorMass))
        #expect(top.signed <= 0.5, "the bias did not turn over: \(top.signed)")
        #expect(top.mean < 1, "\(top.mean) eighths out at the top of the record")
        #expect(top.peak < AnalyserColumns.rows, "worst cell is \(top.peak) eighths out")

        // And the weight is the thing that nearly hid the result. One full-scale
        // observation is gone inside a tenth of a second: measured 27.2 against
        // a cold scale's 27.9, which is no prior at all.
        let feather = opening(.fullScale(weight: 1))
        #expect(
            abs(feather.mean - cold.mean) < 2,
            "one observation now does something: \(feather.mean) against \(cold.mean)")
    }

    /// The governing sentence, held down on real material: **short is the
    /// sanctioned direction and tall is not**. Not "never tall" — the worst
    /// upward excursion measured is nine eighths, a little over one cell of
    /// eight — but tall by the whole column is what a cold scale did and is what
    /// this is for.
    @Test(
        "A cold analyser draws short, and no longer runs the column",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func errsShort() throws {
        let files = Self.sides()
        try #require(files.count > 3)

        for url in files.prefix(4) {
            let rows = try Self.levels(of: url)
            let reference = Self.script(rows)
            let drawn = Self.live(
                rows, from: Self.fresh(.fullScale(weight: BandScale.priorMass)))

            var tallest = 0
            var tall = 0
            var short = 0
            for window in 0..<min(15 * Spectrum.rowsPerSecond, rows.count) {
                for (a, b) in zip(reference[window], drawn[window]) {
                    if b > a {
                        tallest = max(tallest, b - a)
                        tall += 1
                    }
                    if b < a { short += 1 }
                }
            }

            let note = "\(url.lastPathComponent): tall \(tall), short \(short), worst \(tallest)"
            #expect(short > tall * 2, "\(note)")
            // Measured 6 to 9 eighths, against the forty a cold scale reached.
            #expect(tallest < 12, "\(note)")
        }
    }

    /// **The price of the prior, and it is the one the eighths could not see.**
    /// A scale that starts at the ceiling draws *nothing at all* until real
    /// evidence has pulled the bottom anchor down, which takes about sixty
    /// windows — six seconds of a blank analyser at the top of a record.
    ///
    /// It is once per record and not once per track, because the scales carry.
    /// On a track that fades in it is exactly right and the script is blank too.
    /// On a track that opens loud it is wrong, and it is wrong in the sanctioned
    /// direction. Both ends are held so neither can grow.
    @Test(
        "A record opens on a blank analyser for five seconds, and no longer",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func blankAtTheTopOfARecord() throws {
        let files = Self.sides()
        try #require(files.count > 3)

        for url in files.prefix(4) {
            let rows = try Self.levels(of: url)
            let drawn = Self.live(
                rows, from: Self.fresh(.fullScale(weight: BandScale.priorMass)))

            for second in 0..<5 {
                let value = Self.lit(drawn, second: second)
                #expect(value == 0, "\(url.lastPathComponent) second \(second): \(value)% lit")
            }
            // And it is over by the ninth second on every side measured — the
            // worst is Dreams, which comes back through 3, 19, 44 and then 89.
            let recovered = Self.lit(drawn, second: 8)
            #expect(recovered > 85, "\(url.lastPathComponent) is still \(recovered)% lit at 8s")
        }
    }

    /// The other half of D33, and the half that does the most work. Every track
    /// after the first opens on the previous track's evidence, and the prior is
    /// long spent by then.
    @Test(
        "A carried scale fixes every track but the one you start on",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func carriedOver() throws {
        let files = Self.sides()
        try #require(files.count > 3)

        var carried = Self.fresh(.fullScale(weight: BandScale.priorMass))
        var first = true
        for url in files.prefix(4) {
            let rows = try Self.levels(of: url)
            let reference = Self.script(rows)
            let opening = Self.apart(reference, Self.live(rows, from: carried), seconds: 0..<5)

            if !first {
                // Measured 5.1, 6.7 and 6.6 eighths, against 11.3, 16.1 and 21.0
                // with no carry at all. Under a row of five, which is where
                // §18.21 wanted to be.
                let note = "\(url.lastPathComponent) opens \(opening.mean) eighths out"
                #expect(opening.mean < 8, "\(note)")
                // And not by drawing a blank panel: the prior is spent by now.
                #expect(Self.lit(Self.live(rows, from: carried), second: 0) > 0, "\(note)")
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
    /// whole length. Worst measured, a minute in: 7.7 eighths on the opener and
    /// 7.6 on Never Going Back Again, an acoustic track between two loud ones.
    /// Under a row of five, and it stays under a row.
    @Test(
        "What a carried scale costs a minute in, and it is under a row",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func steadyStateCost() throws {
        let files = Self.sides()
        try #require(files.count > 3)

        var carried = Self.fresh(.fullScale(weight: BandScale.priorMass))
        for url in files.prefix(4) {
            let rows = try Self.levels(of: url)
            let reference = Self.script(rows)
            let minute = Self.apart(reference, Self.live(rows, from: carried), seconds: 55..<60)

            let note = "\(url.lastPathComponent) is \(minute.mean) eighths out a minute in"
            #expect(minute.mean < 8, "\(note)")

            for row in rows {
                for band in row.indices { carried[band].observe(row[band]) }
            }
        }
    }
}
