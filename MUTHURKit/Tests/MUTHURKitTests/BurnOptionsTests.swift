import Foundation
import Testing

@testable import MUTHURKit

// MARK: - §20 The Burn menu (D86)

@Suite("§20 — the Burn menu's options")
struct BurnOptionsTests {

    private func draft(_ durations: [Int]) -> PlanDraft {
        PlanDraft(
            rows: durations.enumerated().map {
                PlanDraft.Row(title: "Track \($0.offset + 1)", artist: "", duration: $0.element)
            },
            order: Array(durations.indices),
            album: "A Record", albumArtist: "Someone", year: "1979",
            orderedByFilename: false
        )
    }

    /// `burncd` with nothing after it (`burncd:62–86`). The two that are on by
    /// default are the two whose flags are spelled `--no-`.
    @Test("With no flags, CD-Text and the media check are on and everything else is off")
    func defaults() {
        let options = BurnOptions()
        #expect(!options.rehearsal)
        #expect(!options.verify)
        #expect(options.cdText)
        #expect(!options.splitLong)
        #expect(options.level == .off)
        #expect(options.from == 1)
        #expect(options.mediaCheck)
        #expect(!options.demo)
    }

    /// Every variable that meant something before the menu still sets where
    /// the menu starts — D83's two and the script's own.
    @Test("The environment seeds the menu")
    func seededFromTheEnvironment() {
        let options = BurnOptions.atLaunch(environment: [
            "MUTHUR_DUMMY": "1",
            "MUTHUR_DEMO": "1",
            "BURNCD_LEVEL": "track",
            "BURNCD_NO_MEDIA_CHECK": "1",
            "BURNCD_LUFS": "-14",
        ])
        #expect(options.rehearsal)
        #expect(options.demo)
        #expect(options.level == .track)
        #expect(!options.mediaCheck)
        #expect(options.targets.lufs == -14)

        // An empty variable is an unset one, as `[ -n "${X:-}" ]` has it.
        #expect(BurnOptions.atLaunch(environment: ["MUTHUR_DUMMY": ""]) == BurnOptions())
        #expect(BurnOptions.atLaunch(environment: [:]) == BurnOptions())
    }

    /// The whole point: the menu reaches the job.
    @Test("Every switch arrives on the job")
    func reachesTheJob() {
        var options = BurnOptions()
        options.rehearsal = true
        options.cdText = false
        options.splitLong = true
        options.level = .album
        options.from = 2
        let job = options.job(
            draft: draft([300]), files: [URL(fileURLWithPath: "/a.flac")],
            work: URL(fileURLWithPath: "/tmp"))
        #expect(job.rehearsal)
        #expect(!job.cdText)
        #expect(job.splitLong)
        #expect(job.level == .album)
        #expect(job.from == 2)
        #expect(job.stop == .throughTheBurn)
    }

    /// `burncd:2665`: `--verify` is skipped for `--demo`, and a rehearsal
    /// `continue`s past it (`burncd:2655`) with a blank still in the tray.
    @Test("Verify reads back only a real burn")
    func verifyOnlyARealBurn() {
        #expect(BurnOptions().verifier() == nil)
        #expect(BurnOptions(verify: true).verifier() != nil)
        #expect(BurnOptions(rehearsal: true, verify: true).verifier() == nil)
        #expect(BurnOptions(verify: true, demo: true).verifier() == nil)
    }

    /// Nil is `--demo`, as `BurnJob.Insert` documents it.
    @Test("A demo is never asked for a disc")
    func demoHasNoPrompt() {
        #expect(BurnOptions(demo: true).insert(wait: { _ in true }) == nil)
        #expect(BurnOptions().insert(wait: { _ in true }) != nil)
        #expect(BurnOptions(mediaCheck: false).insert(wait: { _ in true }) != nil)
    }

    // MARK: Split Long Tracks, with the editor up

    /// A switch flipped after planning keeps the edits made before it.
    @Test("Splitting long tracks remakes the plan and keeps the edits")
    func splitKeepsEdits() throws {
        var editor = try PlanEditor(draft: draft([300, 300, 300]))
        editor.drop()
        #expect(editor.undoCount == 1)
        try editor.setSplitLong(true)
        #expect(editor.splitLong)
        #expect(editor.undoCount == 1)
        #expect(editor.draft.order.count == 2)
    }

    /// Turning the split off under a track longer than a disc is refused, and
    /// refused without moving anything: the plan on screen is still the one
    /// the switch said it was.
    @Test("Turning the split off under a too-long track changes nothing")
    func unsplitRefused() throws {
        var editor = try PlanEditor(draft: draft([5700]), splitLong: true)
        let before = editor.plan.discCount
        #expect(throws: PlanFailure.self) { try editor.setSplitLong(false) }
        #expect(editor.splitLong)
        #expect(editor.plan.discCount == before)

        #expect(throws: PlanFailure.self) { try PlanEditor(draft: draft([5700])) }
    }
}
