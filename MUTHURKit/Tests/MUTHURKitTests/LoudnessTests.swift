import Foundation
import Testing

@testable import MUTHURKit

/// §20 stage 2 — `--level`, without decoding anything.
///
/// The measurement is one ffmpeg invocation and the rest is arithmetic, so the
/// arithmetic is tested against readings written down by hand. Whether ffmpeg
/// actually says what this expects is `BurnConversionTests`, which is gated on
/// having it.
@Suite("§20 stage 2 — the level pass")
struct LoudnessTests {

    /// Real output, captured from the ffmpeg on this machine rather than
    /// imagined — the leading spaces and the trailing units are what the
    /// script's two anchors are anchored on.
    private static let summary = """
        [Parsed_ebur128_0 @ 0x600001708000] t: 4.79979   TARGET:-23 LUFS    M: -20.7 S: -20.7
        [Parsed_ebur128_0 @ 0x600001708000] Summary:

          Integrated loudness:
            I:         -20.7 LUFS
            Threshold: -30.8 LUFS

          Loudness range:
            LRA:         0.0 LU

          True peak:
            Peak:       -6.0 dBFS

        [out#0/null @ 0x600002a04000] video:0KiB audio:0KiB
        """

    // MARK: - Reading it

    @Test("The two summary figures come out, and nothing else does")
    func parse() {
        let reading = Loudness.parse(Self.summary)
        #expect(reading.lufs == -20.7)
        #expect(reading.peak == -6.0)
    }

    /// A per-frame progress line is not a summary line, and the difference is
    /// only ever the start of the line — which is why the script anchors both
    /// patterns and why this does too.
    @Test("A progress line is never mistaken for the summary")
    func progressLines() {
        let noisy = """
            [Parsed_ebur128_0 @ 0x1] t: 1  I: -99.9 LUFS
            [Parsed_ebur128_0 @ 0x1] Peak: -99.9 dBFS
              I:         -14.0 LUFS
              Peak:       -2.0 dBFS
            """
        let reading = Loudness.parse(noisy)
        #expect(reading.lufs == -14.0)
        #expect(reading.peak == -2.0)
    }

    /// Digital silence reads `-inf` on both, which is not a number anything
    /// downstream can use: the energy sum, and both subtractions, would carry
    /// it straight through to a gain nothing can be done with (`burncd:502`).
    @Test("Silence reads as -70, not as -inf")
    func silence() {
        let silent = Loudness.parse("""
              I:          -inf LUFS
              Peak:       -inf dBFS
            """)
        #expect(silent.lufs == Loudness.floor)
        #expect(silent.peak == Loudness.floor)

        // Nothing at all is the same case. A file ffmpeg could not read has
        // nothing to say about how loud the disc should be.
        let nothing = Loudness.parse("")
        #expect(nothing.lufs == Loudness.floor)
        #expect(nothing.peak == Loudness.floor)
    }

    // MARK: - Which limit applied

    /// The gain is the smaller of the two, always — and here the loudness
    /// target is the smaller, so the disc reaches it.
    @Test("A quiet record with headroom to spare goes up to the target")
    func loudnessBound() {
        let quiet = [
            (duration: 200, loudness: Loudness(lufs: -18, peak: -10)),
            (duration: 200, loudness: Loudness(lufs: -18, peak: -10)),
        ]
        let (gain, bound) = Loudness.albumGain(tracks: quiet, targets: LevelTargets())
        #expect(Loudness.format(gain) == "7.0")
        #expect(bound == .loudness)
    }

    /// And here it is not: the record is quiet but already peaking, so all it
    /// gets is the headroom there is. This is the case `--level` exists to be
    /// honest about — no compression, so no more than this.
    @Test("A quiet record that already peaks gets only the headroom")
    func peakBound() {
        let squashed = [(duration: 300, loudness: Loudness(lufs: -18, peak: -2))]
        let (gain, bound) = Loudness.albumGain(tracks: squashed, targets: LevelTargets())
        #expect(Loudness.format(gain) == "1.0")
        #expect(bound == .peak)
    }

    /// **Album mode never turns anything down.** Turning a loud record down is
    /// not what "this disc plays quiet" asks for, and cutting to hit a loudness
    /// target would need a limiter (`burncd:583`).
    @Test("Album mode never attenuates")
    func neverDown() {
        let loud = [(duration: 300, loudness: Loudness(lufs: -6, peak: -0.1))]
        let (gain, _) = Loudness.albumGain(tracks: loud, targets: LevelTargets())
        #expect(gain == 0)
        #expect(Loudness.format(gain) == "0.0")
    }

    /// Track mode does attenuate, and that is the whole point of it: a
    /// compilation of unrelated masters is matched to itself, which means
    /// bringing the loud ones down (`burncd:553`).
    @Test("Track mode does attenuate, which is what it is for")
    func trackAttenuates() {
        let targets = LevelTargets()
        #expect(Loudness(lufs: -6, peak: -3).trackGain(targets) == -5)
        #expect(Loudness(lufs: -18, peak: -10).trackGain(targets) == 7)
        // Still bounded by the ceiling in both directions.
        #expect(Loudness(lufs: -18, peak: -0.5).trackGain(targets) == -0.5)
    }

    /// Energy-weighted by duration, because averaging the dB figures would let
    /// a short quiet intro drag the whole record up (`burncd:566`).
    @Test("The album's loudness is energy-weighted, not averaged")
    func energyWeighted() {
        // Thirty seconds at -40 LUFS in front of ten minutes at -14. The
        // arithmetic mean of the two figures is -27, which would ask for
        // sixteen dB of gain on a record that needs three.
        let record = [
            (duration: 30, loudness: Loudness(lufs: -40, peak: -30)),
            (duration: 600, loudness: Loudness(lufs: -14, peak: -6)),
        ]
        let (gain, bound) = Loudness.albumGain(tracks: record, targets: LevelTargets())
        #expect(bound == .loudness)
        #expect(Loudness.format(gain) == "3.2")
    }

    /// One gain has to be safe for all of it, so the peak that matters is the
    /// loudest one anywhere in the job.
    @Test("The ceiling is measured against the loudest peak on the disc")
    func loudestPeakWins() {
        let record = [
            (duration: 300, loudness: Loudness(lufs: -20, peak: -12)),
            (duration: 300, loudness: Loudness(lufs: -20, peak: -3)),
        ]
        let (gain, bound) = Loudness.albumGain(tracks: record, targets: LevelTargets())
        #expect(bound == .peak)
        #expect(Loudness.format(gain) == "2.0")
    }

    /// A playlist of silence has no loudness to read off it, so there is no
    /// gain and nothing to say about why (`burncd:578`).
    @Test("Nothing to measure is no gain and no reason")
    func nothing() {
        let (gain, bound) = Loudness.albumGain(tracks: [], targets: LevelTargets())
        #expect(gain == 0)
        #expect(bound == nil)
    }

    // MARK: - What it says

    private static func entries(_ count: Int) -> [BurnPlan.Entry] {
        (0..<count).map {
            BurnPlan.Entry(
                source: $0, title: "T\($0)", artist: "A", duration: 300,
                offset: nil, length: nil, disc: 1
            )
        }
    }

    /// The plan says which limit applied, because a disc that stays quiet
    /// should be explained rather than mysterious (`level_note`, `burncd:787`).
    @Test("The plan says which of the two limits stopped it")
    func note() {
        let quiet = LevelDecision.make(
            mode: .album, targets: LevelTargets(),
            readings: [Loudness(lufs: -18, peak: -10)], entries: Self.entries(1)
        )
        #expect(quiet.note == "Level: +7.0 dB to reach -11 LUFS")

        let peaking = LevelDecision.make(
            mode: .album, targets: LevelTargets(),
            readings: [Loudness(lufs: -18, peak: -2)], entries: Self.entries(1)
        )
        #expect(
            peaking.note == "Level: +1.0 dB — all the headroom there is before clipping"
        )

        let already = LevelDecision.make(
            mode: .album, targets: LevelTargets(),
            readings: [Loudness(lufs: -6, peak: -0.5)], entries: Self.entries(1)
        )
        #expect(already.note == "Level: already at CD loudness, no change")

        let each = LevelDecision.make(
            mode: .track, targets: LevelTargets(),
            readings: [Loudness(lufs: -18, peak: -10)], entries: Self.entries(1)
        )
        #expect(each.note == "Level: each track matched to -11 LUFS")

        let off = LevelDecision.make(
            mode: .off, targets: LevelTargets(),
            readings: [], entries: Self.entries(1)
        )
        #expect(off.note == nil)
    }

    /// D73. The script's track branch claims the target was reached whatever
    /// happened; `TRACK_GAIN` is `min(gl, gh)` with no clamp, so a hot master is
    /// held by its own peak and was never matched to anything.
    @Test("Track mode says which limit applied, the way album mode does")
    func trackNote() {
        // gl = 7, gh = 9 — the target is the nearer limit and is reached.
        let matched = Loudness(lufs: -18, peak: -10)
        // gl = 7, gh = 1 — a master with a dB of headroom and nothing else.
        let held = Loudness(lufs: -18, peak: -2)

        let all = LevelDecision.make(
            mode: .track, targets: LevelTargets(),
            readings: [matched, matched], entries: Self.entries(2)
        )
        #expect(all.note == "Level: each track matched to -11 LUFS")
        #expect(all.trackTally == LevelDecision.TrackTally(peakHeld: 0, total: 2))

        let none = LevelDecision.make(
            mode: .track, targets: LevelTargets(),
            readings: [held, held], entries: Self.entries(2)
        )
        #expect(none.note == "Level: every track held by its peak, short of -11 LUFS")
        #expect(none.trackTally == LevelDecision.TrackTally(peakHeld: 2, total: 2))

        let mixed = LevelDecision.make(
            mode: .track, targets: LevelTargets(),
            readings: [matched, held, matched], entries: Self.entries(3)
        )
        #expect(mixed.note == "Level: 2 of 3 matched to -11 LUFS, the rest held by peaks")
        #expect(mixed.trackTally == LevelDecision.TrackTally(peakHeld: 1, total: 3))
    }

    /// `compute_album_gain`'s comparison is `gl < gh`, so a gain that satisfies
    /// both limits exactly is the ceiling's. The tie is the script's, not a
    /// preference.
    @Test("A track that hits both limits at once is held by the peak")
    func boundTie() {
        let targets = LevelTargets()
        // gl = gh = 3.
        let tie = Loudness(lufs: -14, peak: -4)
        #expect(tie.trackBound(targets) == .peak)
        #expect(Loudness.format(tie.trackGain(targets)) == "3.0")

        #expect(Loudness(lufs: -18, peak: -10).trackBound(targets) == .loudness)
        #expect(Loudness(lufs: -18, peak: -2).trackBound(targets) == .peak)
    }

    /// A track cut across two discs is one measurement, and the sentence about
    /// the job should count it once — as `compute_album_gain` counts it once.
    @Test("A split track is one track in the count")
    func tallyCountsSources() {
        let entries = [
            BurnPlan.Entry(
                source: 0, title: "Long", artist: "A", duration: 1800,
                offset: 0, length: 1800, disc: 1
            ),
            BurnPlan.Entry(
                source: 0, title: "Long", artist: "A", duration: 1800,
                offset: 1800, length: 1800, disc: 2
            ),
        ]
        let decision = LevelDecision.make(
            mode: .track, targets: LevelTargets(),
            readings: [Loudness(lufs: -18, peak: -2)], entries: entries
        )
        #expect(decision.trackTally == LevelDecision.TrackTally(peakHeld: 1, total: 1))
    }

    /// The gain reaches the filter as text, and the filter picks its shape by
    /// comparing that text to `"0.0"` (`burncd:2519`).
    @Test("The gain is text by the time the filter sees it")
    func gainText() {
        let album = LevelDecision.make(
            mode: .album, targets: LevelTargets(),
            readings: [Loudness(lufs: -18, peak: -10), Loudness(lufs: -12, peak: -8)],
            entries: Self.entries(2)
        )
        // One gain for the whole disc, whichever entry is asked.
        #expect(album.gain(for: Self.entries(2)[0]) == album.gain(for: Self.entries(2)[1]))

        let track = LevelDecision.make(
            mode: .track, targets: LevelTargets(),
            readings: [Loudness(lufs: -18, peak: -10), Loudness(lufs: -6, peak: -3)],
            entries: Self.entries(2)
        )
        #expect(track.gain(for: Self.entries(2)[0]) == "7.0")
        #expect(track.gain(for: Self.entries(2)[1]) == "-5.0")

        let off = LevelDecision.make(
            mode: .off, targets: LevelTargets(), readings: [], entries: Self.entries(2)
        )
        #expect(off.gain(for: Self.entries(2)[0]) == "0.0")
    }

    /// A track cut across two discs is one measurement and one gain, and both
    /// halves get it — which is what `source` is for.
    @Test("Both halves of a split track carry the same gain")
    func slices() {
        let entries = [
            BurnPlan.Entry(
                source: 0, title: "Long (part 1/2)", artist: "A", duration: 2400,
                offset: 0, length: 2400, disc: 1
            ),
            BurnPlan.Entry(
                source: 0, title: "Long (part 2/2)", artist: "A", duration: 2400,
                offset: 2400, length: 2400, disc: 2
            ),
        ]
        let decision = LevelDecision.make(
            mode: .track, targets: LevelTargets(),
            readings: [Loudness(lufs: -20, peak: -12)], entries: entries
        )
        #expect(decision.gain(for: entries[0]) == decision.gain(for: entries[1]))
        #expect(decision.gain(for: entries[0]) == "9.0")
    }

    // MARK: - Where the settings come from

    @Test("The mode and the targets are read from the environment")
    func environment() {
        #expect(LevelMode.from(environment: [:]) == .off)
        #expect(LevelMode.from(environment: ["BURNCD_LEVEL": "album"]) == .album)
        #expect(LevelMode.from(environment: ["MUTHUR_LEVEL": "track"]) == .track)
        // The port's own name wins where both are set.
        #expect(
            LevelMode.from(environment: ["MUTHUR_LEVEL": "album", "BURNCD_LEVEL": "track"])
                == .album
        )
        // A typo in a shell profile is not a reason to refuse to open a record.
        #expect(LevelMode.from(environment: ["MUTHUR_LEVEL": "loud"]) == .off)

        let defaults = LevelTargets.from(environment: [:])
        #expect(defaults.lufs == -11)
        #expect(defaults.peak == -1)

        let set = LevelTargets.from(environment: ["BURNCD_LUFS": "-14", "MUTHUR_PEAK": "-0.3"])
        #expect(set.lufs == -14)
        #expect(set.peak == -0.3)

        // Junk falls back rather than becoming zero, which is where `awk` would
        // have put it and is about as wrong as a loudness target can be.
        #expect(LevelTargets.from(environment: ["MUTHUR_LUFS": "loud"]).lufs == -11)
    }

    /// A target reads as it was written down. Nobody chose −11.0 over −11.1,
    /// and the trailing zero would be a claim of precision the number does not
    /// have.
    @Test("A target keeps the shape it was typed in")
    func targetText() {
        #expect(Loudness.formatTarget(-11) == "-11")
        #expect(Loudness.formatTarget(-14.5) == "-14.5")
        #expect(Loudness.formatTarget(0) == "0")
    }

    // MARK: - The cache

    /// **Not the script's TSV.** Keyed by path with the size and mtime beside
    /// the reading, so a file that changed replaces its own entry instead of
    /// growing a second one that nothing will ever reach again. D69.
    @Test("A measurement is remembered, and forgotten when the file changes")
    func cache() throws {
        let work = FileManager.default.temporaryDirectory
            .appending(path: "muthur-cache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        let file = work.appending(path: "track.flac")
        try Data(repeating: 1, count: 100).write(to: file)

        var cache = LevelCache(at: work.appending(path: "levels.json"))
        #expect(cache.reading(for: file) == nil)

        cache.record(Loudness(lufs: -14.2, peak: -1.5), for: file)
        #expect(cache.reading(for: file) == Loudness(lufs: -14.2, peak: -1.5))
        cache.save()

        // It survives a restart.
        let reopened = LevelCache(at: work.appending(path: "levels.json"))
        #expect(reopened.reading(for: file) == Loudness(lufs: -14.2, peak: -1.5))

        // Re-tag the file — same path, different size — and the entry no
        // longer answers for it.
        try Data(repeating: 1, count: 200).write(to: file)
        #expect(reopened.reading(for: file) == nil)
    }

    /// The cache is an optimisation, never a requirement (`burncd:521`). A
    /// read-only home means measuring every time, and not a word about it to
    /// somebody who never asked for a cache and cannot do anything about it.
    @Test("An unwritable cache measures every time and says nothing")
    func cacheOptional() throws {
        let work = FileManager.default.temporaryDirectory
            .appending(path: "muthur-nocache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        let file = work.appending(path: "track.flac")
        try Data(repeating: 1, count: 100).write(to: file)

        var cache = LevelCache(at: nil)
        cache.record(Loudness(lufs: -14, peak: -1), for: file)
        cache.save()
        #expect(cache.reading(for: file) == Loudness(lufs: -14, peak: -1))
        #expect(LevelCache(at: nil).reading(for: file) == nil)
    }

    /// Measuring reads every file end to end, so the first run is slow and has
    /// to say so — once, before the wait, and not at all on the second burn of
    /// the same record (`burncd:544`).
    @Test("The first run announces the wait; the second is silent")
    func announcesTheWait() throws {
        let work = FileManager.default.temporaryDirectory
            .appending(path: "muthur-pass-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        var files: [URL] = []
        for index in 0..<3 {
            let file = work.appending(path: "t\(index).flac")
            try Data(repeating: UInt8(index), count: 50).write(to: file)
            files.append(file)
        }

        var cache = LevelCache(at: work.appending(path: "levels.json"))
        var said: [String] = []
        var decodes = 0
        let measure: LevelPass.Measure = { _ in
            decodes += 1
            return Loudness(lufs: -16, peak: -4)
        }

        let first = try LevelPass.run(
            files: files, cache: &cache, measure: measure, note: { said.append($0) }
        )
        #expect(first.readings.count == 3)
        #expect(first.measuredAnything)
        #expect(decodes == 3)
        #expect(said.first == LevelPass.firstRunNote)
        // Said once, not once a file.
        #expect(said.count { $0 == LevelPass.firstRunNote } == 1)
        #expect(said.contains("1 of 3 — t0.flac"))

        var again = LevelCache(at: work.appending(path: "levels.json"))
        var quiet: [String] = []
        let second = try LevelPass.run(
            files: files, cache: &again, measure: measure, note: { quiet.append($0) }
        )
        #expect(second.readings.count == 3)
        #expect(!second.measuredAnything)
        #expect(decodes == 3)
        #expect(quiet.isEmpty)
    }
}
