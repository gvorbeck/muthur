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
        // `store: nil` throughout: this test is about what the *environment*
        // says, and reading the machine's real defaults would make it depend on
        // whatever the person running it last chose on the settings screen.
        let options = BurnOptions.atLaunch(
            environment: [
                "MUTHUR_DUMMY": "1",
                "MUTHUR_DEMO": "1",
                "BURNCD_LEVEL": "track",
                "BURNCD_NO_MEDIA_CHECK": "1",
                "BURNCD_LUFS": "-14",
            ], store: nil)
        #expect(options.rehearsal)
        #expect(options.demo)
        #expect(options.level == .track)
        #expect(!options.mediaCheck)
        #expect(options.targets.lufs == -14)

        // An empty variable is an unset one, as `[ -n "${X:-}" ]` has it.
        #expect(
            BurnOptions.atLaunch(environment: ["MUTHUR_DUMMY": ""], store: nil) == BurnOptions())
        #expect(BurnOptions.atLaunch(environment: [:], store: nil) == BurnOptions())
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

    // MARK: - The five that are kept, and the three that are not (D105)

    private func store() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "muthur.test.\(UUID().uuidString)"))
    }

    /// **The test D86 is amended by, and the one that has to keep working.**
    ///
    /// The five that describe how this person burns discs come back; the three
    /// that describe one run do not, and `rehearsal` is the one it exists for —
    /// a rehearsal remembered from last month is an hour spent not burning a
    /// disc somebody meant to keep.
    @Test("How you burn discs is kept; what this run is, is not")
    func savedHalf() throws {
        let store = try store()
        defer { store.removePersistentDomain(forName: store.description) }

        var options = BurnOptions()
        options.verify = true
        options.cdText = false
        options.splitLong = true
        options.level = .album
        options.mediaCheck = false
        // The three that must not come back, each set to the dangerous side.
        options.rehearsal = true
        options.demo = true
        options.from = 3
        options.save(to: store)

        let back = BurnOptions.atLaunch(environment: [:], store: store)
        #expect(back.verify)
        #expect(!back.cdText)
        #expect(back.splitLong)
        #expect(back.level == .album)
        #expect(!back.mediaCheck)

        #expect(!back.rehearsal)
        #expect(!back.demo)
        #expect(back.from == 1)
    }

    /// The saved half is still only *where the menu starts*: a variable typed
    /// this launch beats it, and is not written back.
    @Test("A variable beats the saved burn settings, and is not written back")
    func environmentBeatsTheSavedHalf() throws {
        let store = try store()
        defer { store.removePersistentDomain(forName: store.description) }

        var options = BurnOptions()
        options.level = .album
        options.save(to: store)

        #expect(
            BurnOptions.atLaunch(environment: ["BURNCD_LEVEL": "track"], store: store).level
                == .track)
        #expect(BurnOptions.atLaunch(environment: [:], store: store).level == .album)
    }

    /// An unset variable leaves the setting standing. `mediaCheck` is the one
    /// that would bite: `MediaCheck.enabled` answers `true` for an empty
    /// environment, so reading it unconditionally would turn a deliberate
    /// *off* back on at every launch.
    @Test("An unset variable does not overwrite a saved burn setting")
    func unsetLeavesTheSavedHalfAlone() throws {
        let store = try store()
        defer { store.removePersistentDomain(forName: store.description) }

        var options = BurnOptions()
        options.mediaCheck = false
        options.cdText = false
        options.save(to: store)

        let back = BurnOptions.atLaunch(environment: [:], store: store)
        #expect(!back.mediaCheck)
        #expect(!back.cdText)
    }

    @Test("A saved set from a version with one switch fewer still decodes")
    func forwardCompatible() throws {
        let store = try store()
        defer { store.removePersistentDomain(forName: store.description) }
        // Only `verify`, as an older build would have written it.
        store.set(try #require(#"{"verify":true}"#.data(using: .utf8)), forKey: "burn.options")

        let back = BurnOptions.atLaunch(environment: [:], store: store)
        #expect(back.verify)
        #expect(back.cdText)
        #expect(!back.splitLong)
        #expect(back.level == .off)
        #expect(back.mediaCheck)
    }
}
