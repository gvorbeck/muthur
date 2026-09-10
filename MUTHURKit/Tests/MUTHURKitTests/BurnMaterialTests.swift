import Foundation
import Testing

@testable import MUTHURKit

/// §20 stage 3b, material tier — the burn, against the drive in this building.
///
/// Everything stage 2 does is proved in `BurnConversionTests` against material
/// lavfi makes in a tenth of a second. What no synthetic record can tell you is
/// whether *this* drive takes the vector `Cdrecord.write` builds, whether it
/// accepts `-text`, and whether the lines it prints on the carriage returns are
/// the lines `BurnPanel.parse` is anchored on. Those are hardware questions and
/// they are answered here or not at all.
///
/// Nothing here spends a blank without being asked to. Every test is
/// `.enabled(if:)` on an environment variable, so a clone with no drive — or
/// this machine on an ordinary day — is green rather than red.
/// `docs/hardware.md` step 14 is the procedure, one command per variable.
///
/// - `MUTHUR_TEST_BURN_WORK` — a directory to build the record into and leave
///   it there. Without it nothing below builds anything.
/// - `MUTHUR_TEST_BURN_SOURCE` — the folder of music to build. A short record:
///   a rehearsal runs at write speed, so eight minutes of audio is about a
///   minute of laser-off drive time and a twelve-track album is five.
/// - `MUTHUR_TEST_REHEARSE` — set to actually drive the drive, `--dummy`. The
///   laser stays off and the blank survives, so this is free and repeatable —
///   but it takes the drive for a minute and it has to be asked for.
/// - `MUTHUR_TEST_BURN_FOR_REAL` — **spends the blank.** The laser comes on and
///   what comes out is a disc or a coaster. Nothing else in this repository is
///   irreversible, which is why it is its own variable and not a mode of the one
///   above: a hand that meant to rehearse and typed the wrong name should get a
///   rehearsal. It takes the whole record rather than `tracks` of it, because a
///   burn that only proved three tracks would have spent a blank to prove less
///   than the rehearsal already did.
/// - `MUTHUR_TEST_VERIFY_DISC` — set with the *burnt* disc in the drive, and
///   with `MUTHUR_TEST_BURN_SOURCE` still naming the record it was burnt from.
///   It reads the disc end to end, which is a minute of drive time for a short
///   album and free otherwise: nothing is written and the blank is long gone.
@Suite("§20 stage 3b — with a drive")
struct BurnMaterialTests {

    static func setting(_ name: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
            return nil
        }
        return value
    }

    /// A directory of its own per test, under whatever the operator named.
    ///
    /// Swift Testing runs the two tests below in parallel and both build a
    /// `disc1.wav`. Sharing one directory means one of them silently reading the
    /// other's half-written image — and worse, the rehearsal finding a
    /// `cdrecord-1.log` it did not write and believing it.
    static func work(_ named: String) -> URL? {
        setting("MUTHUR_TEST_BURN_WORK").map { URL(fileURLWithPath: $0).appending(path: named) }
    }

    static var work: URL? { setting("MUTHUR_TEST_BURN_WORK").map { URL(fileURLWithPath: $0) } }
    static var source: URL? {
        setting("MUTHUR_TEST_BURN_SOURCE").map { URL(fileURLWithPath: $0) }
    }

    /// How many tracks of the folder to take. A rehearsal is real time at the
    /// write speed, and three tracks is enough to prove a multi-track cue, two
    /// index marks and a CD-Text block.
    ///
    /// `MUTHUR_TEST_BURN_TRACKS` lifts it, which is what you want before
    /// spending a blank: the burn below takes the whole record, and building the
    /// whole record first is the cheapest way to find out that its titles shed,
    /// its runtime splits, or a file will not decode. Junk falls back to three
    /// rather than to zero, because a cap of zero is a job with nothing in it and
    /// a mistyped variable should not look like an empty album.
    static var tracks: Int {
        guard let asked = setting("MUTHUR_TEST_BURN_TRACKS").flatMap(Int.init), asked > 0
        else { return 3 }
        return asked
    }

    // MARK: - A real record, built

    /// The whole of stage 2 on somebody's actual music, left on disk where a
    /// `cdrecord` can be pointed at it.
    ///
    /// The synthetic records elsewhere are all lavfi tones at conveniently round
    /// durations; a real album is variable bit rate AAC with apostrophes in the
    /// titles and a running time that lands wherever it lands. This is stage 2
    /// against one, left on disk where a `cdrecord` can be pointed at it.
    @Test(
        "A real album builds to an image and a cue",
        .enabled(if: BurnMaterialTests.work != nil && BurnMaterialTests.source != nil))
    func buildARealRecord() async throws {
        let work = try #require(Self.work("build"))
        let source = try #require(Self.source)
        let ffmpeg = try #require(Fixtures.locate("ffmpeg"))
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        let record = try await Record.read(
            directory: source, sourceLabel: source.lastPathComponent)
        var draft = PlanDraft(record: record)
        draft.order = Array(draft.order.prefix(Self.tracks))
        // The cap is a ceiling and not a demand: a five-track folder asked for
        // twelve is a five-track job, and asserting against the ceiling would
        // fail it for being short of tracks it never had.
        let taken = draft.order.count

        // `files` is parallel to `rows`, which is the source level — dropping
        // tracks from the running order does not renumber them, and that is the
        // point of `PlanDraft` keeping both.
        let files = AudioFiles.scan(source)
        #expect(files.count == draft.rows.count)

        let job = BurnJob(
            draft: draft, files: files, work: work, stop: .afterBuilding, cdText: true)
        let outcome = try job.run(ffmpeg: ffmpeg)

        let disc = try #require(outcome.discs.first)
        #expect(outcome.discs.count == 1)
        #expect(disc.starts.count == taken)
        #expect(disc.text.writesCDText)

        // The cue is what cdrecord is handed, so it is the cue that has to be
        // right — and the CD-TEXT block in it is the whole of the question the
        // rehearsal below exists to answer.
        let cue = try String(contentsOf: disc.cue, encoding: .isoLatin1)
        #expect(cue.contains("CDTEXTFILE") || cue.contains("TITLE "))
        #expect(cue.contains("FILE \"\(disc.image.lastPathComponent)\" WAVE"))
        #expect(FileManager.default.fileExists(atPath: disc.image.path))
    }

    // MARK: - The rehearsal

    /// The whole job through the real drive with the write laser off.
    ///
    /// This is `--dummy`, and it is the only test in the repository that runs
    /// `BurnJob` → `Burner` → `cdrecord` end to end against hardware. It costs a
    /// minute of drive time and nothing else: the blank comes out of it blank,
    /// which is why it can assert the things a `FakeDrive` can only assume.
    ///
    /// **It is also where the CD-Text question is settled.** `-text` is on the
    /// vector, and cdrecord either takes it or says so and stops — there is no
    /// third outcome and no way to ask it that does not involve the drive. A
    /// green run here is the licence to keep CD-Text on the real burn.
    ///
    /// The blank has to already be in the drive: `wait` says yes without asking
    /// anybody, because there is nobody at a keyboard in a test and a prompt
    /// that blocked would hang the suite rather than fail it.
    @Test(
        "A rehearsal drives the real drive, and cdrecord takes -text",
        .enabled(
            if: BurnMaterialTests.work != nil && BurnMaterialTests.source != nil
                && BurnMaterialTests.setting("MUTHUR_TEST_REHEARSE") != nil))
    func rehearseAgainstTheDrive() async throws {
        let work = try #require(Self.work("rehearsal"))
        let source = try #require(Self.source)
        let ffmpeg = try #require(Fixtures.locate("ffmpeg"))
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        let record = try await Record.read(
            directory: source, sourceLabel: source.lastPathComponent)
        var draft = PlanDraft(record: record)
        draft.order = Array(draft.order.prefix(Self.tracks))
        let taken = draft.order.count

        let job = BurnJob(
            draft: draft, files: AudioFiles.scan(source), work: work,
            stop: .throughTheBurn, cdText: true, rehearsal: true)

        let asked = Asked()
        let outcome = try job.run(
            ffmpeg: ffmpeg,
            drive: Burner(),
            insert: BurnJob.Insert(wait: { disc in
                asked.prompts.append(disc)
                return true
            }),
            frame: { asked.frames.append($0) })

        // The prompt went up for the one disc, and the check took what was in
        // the drive — a refusal would have looped it and hung here instead.
        #expect(asked.prompts == [1])

        let panel = try #require(outcome.burns.first)
        #expect(panel.rehearsal)
        #expect(panel.verb == "REHEARSING")

        // The drive narrated the whole disc. `percent` carries the rounding
        // arrears of a real image, so the weak assertion is the honest one; the
        // track number is the tight one, because reaching the last track is what
        // says the drive did not stop early.
        #expect(panel.track == taken)
        #expect(panel.percent >= BurnPanel.tailPercent)
        #expect(panel.doneMegabytes > 0)
        #expect(asked.frames.count > 1)

        // The two lines a rehearsal owes the operator, and the one that says it
        // finished.
        #expect(outcome.notes.contains { $0.hasPrefix("TEST BURN") })
        #expect(outcome.notes.contains { $0.contains("not ejected") })
        #expect(outcome.notes.contains { $0.contains("rehearsed") })

        // What cdrecord actually said, which the panel throws away. A `-text`
        // run writes a lead-in and a no-text run does not, so this line is the
        // evidence that the CD-Text block went to the drive rather than merely
        // onto the vector.
        //
        // There is no assertion about what cdrecord *says* on the subject,
        // because on the three rehearsals this was written against it said
        // nothing at all — and an absence observed three times is not a promise.
        // The proof that `-text` was accepted is the exit status, which `run`
        // has already turned into a throw if it was not zero.
        let log = try String(
            contentsOf: Cdrecord.logURL(work: work, disc: 1), encoding: .isoLatin1)
        #expect(log.contains("Lead-in write time"))
    }

    // MARK: - The burn

    /// The same job with the laser on. **This one spends the blank.**
    ///
    /// It is the rehearsal above with `rehearsal: false` and no cap on the
    /// running order, and that is the whole difference — which is the claim
    /// stage 3a made about the seam and this is where it is either true or not.
    /// `-dummy` comes off the vector and `-eject` goes on, both from the same
    /// flag, so what proves the burn happened is not a line in the log but the
    /// disc in your hand.
    ///
    /// **What is asserted here is deliberately narrow.** Whether the disc plays,
    /// whether the joins are gapless and whether a player shows the CD-Text are
    /// questions about a disc, and a disc is not something a process can look
    /// at — `--verify` is the box for the first of those and a pair of ears is
    /// the box for the rest. What this can say is that the drive took the vector,
    /// narrated every track of it, and exited zero.
    @Test(
        "The laser comes on and the blank is spent",
        .enabled(
            if: BurnMaterialTests.work != nil && BurnMaterialTests.source != nil
                && BurnMaterialTests.setting("MUTHUR_TEST_BURN_FOR_REAL") != nil))
    func burnForReal() async throws {
        let work = try #require(Self.work("burn"))
        let source = try #require(Self.source)
        let ffmpeg = try #require(Fixtures.locate("ffmpeg"))
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        let record = try await Record.read(
            directory: source, sourceLabel: source.lastPathComponent)
        let draft = PlanDraft(record: record)
        let wanted = draft.order.count

        let job = BurnJob(
            draft: draft, files: AudioFiles.scan(source), work: work,
            stop: .throughTheBurn, cdText: true)

        let asked = Asked()
        let outcome = try job.run(
            ffmpeg: ffmpeg,
            drive: Burner(),
            insert: BurnJob.Insert(wait: { disc in
                asked.prompts.append(disc)
                return true
            }),
            frame: { asked.frames.append($0) })

        // One disc, asked for once. A second prompt would mean the check refused
        // the blank, and a refused blank is not something to discover afterwards.
        #expect(asked.prompts == [1])
        #expect(outcome.discs.count == 1)

        let panel = try #require(outcome.burns.first)
        #expect(!panel.rehearsal)
        #expect(panel.verb == "WRITING")
        #expect(panel.track == wanted)
        #expect(panel.percent >= BurnPanel.tailPercent)

        // The rehearsal's two lines are *not* here — this disc is ejected and
        // there is no burning it again — and the closing note says burnt rather
        // than rehearsed.
        #expect(!outcome.notes.contains { $0.hasPrefix("TEST BURN") })
        #expect(outcome.notes.contains { $0.contains("Disc 1 of 1 written") })

        // The lead-in is where the CD-Text block goes. A run without `-text`
        // writes no lead-in at all, so this line is the evidence that the names
        // reached the disc rather than only the cue sheet.
        let log = try String(
            contentsOf: Cdrecord.logURL(work: work, disc: 1), encoding: .isoLatin1)
        #expect(log.contains("Lead-in write time"))
    }

    // MARK: - Reading it back

    /// `--verify` against the disc that is actually in the drive.
    ///
    /// This is the one check in the repository whose subject is a disc rather
    /// than a file, and it cannot be faked: `DiscVerifyTests` proves every branch
    /// against captures, and what is left over is whether *this* drive will hand
    /// `cdrecord -toc` a table of contents and let `cdda2wav` walk the whole disc
    /// without a read error. Both are questions about a piece of plastic.
    ///
    /// **What it is checked against is the record it was burnt from.** The image
    /// is deleted when the disc is written (D79), so the folder is the only copy
    /// left — the plan and the shedding ladder are derived again here, without
    /// converting anything, which is the same arithmetic the job did on the way
    /// in. If the disc reports a different number of tracks than that plan lays
    /// out, either the burn was wrong or the plan is not the one that was burnt,
    /// and both are worth failing for.
    ///
    /// It does not open the tray afterwards, though a real `--verify` does: a
    /// test that ejects is a test you cannot run twice without standing up.
    @Test(
        "The disc in the drive reads back as the record that was burnt",
        .enabled(
            if: BurnMaterialTests.work != nil && BurnMaterialTests.source != nil
                && BurnMaterialTests.setting("MUTHUR_TEST_VERIFY_DISC") != nil))
    func verifyTheDiscInTheDrive() async throws {
        let work = try #require(Self.work("verify"))
        let source = try #require(Self.source)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        let record = try await Record.read(
            directory: source, sourceLabel: source.lastPathComponent)
        let draft = PlanDraft(record: record)
        let plan = try BurnPlan.make(draft: draft)
        let entries = plan.entries(onDisc: 1)
        let text = DiscText.make(
            disc: 1, entries: entries, album: draft.album,
            albumArtist: draft.albumArtist, year: draft.year)

        let report = DiscVerify().look(
            disc: 1,
            want: entries.count,
            device: OpticalDrive.detect().device,
            album: text.discTitle,
            cdText: text.writesCDText,
            log: DiscVerify.logURL(work: work, disc: 1))

        // The notes are the whole point of a hardware run — a bare `passed` tells
        // you nothing about which of the three checks did the failing, and the
        // drive's own complaint is in there when one did.
        for line in report.notes { print(line) }

        #expect(report.notes.first == "VERIFYING disc 1...")
        #expect(report.notes.contains("  ✓ table of contents — \(entries.count) tracks"))
        #expect(report.notes.contains("  ✓ full read — every sector came back"))
        #expect(report.passed)
    }

    /// Somewhere for the closures to put what they were told, since a `run` is
    /// not `async` and its callbacks are not `Sendable`.
    private final class Asked: @unchecked Sendable {
        var prompts: [Int] = []
        var frames: [BurnPanel] = []
    }
}
