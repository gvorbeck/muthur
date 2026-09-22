import Foundation
import Testing

@testable import MUTHURKit

// MARK: - §13 The settings screen (D105)

@Suite("§13 — the settings that outlive a launch")
struct PreferencesTests {

    /// A store nothing else is in, so a developer's own settings cannot decide
    /// whether the suite passes.
    private func store() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "muthur.test.\(UUID().uuidString)"))
    }

    @Test("nothing saved is the defaults, and the defaults are what the variables meant by absence")
    func defaults() throws {
        let store = try store()
        defer { store.removePersistentDomain(forName: store.description) }

        let settings = Preferences.load(from: store, environment: [:])
        #expect(settings == Preferences())
        // Each of these is what the program did before there was a screen: the
        // tube allowed to fault, type rather than dots, the run-out filled, the
        // network asked, and the scratch directory swept.
        #expect(settings.faults)
        #expect(settings.lettering == .type)
        #expect(settings.numerals == .type)
        #expect(settings.composition == .runout)
        #expect(settings.useMusicBrainz)
        #expect(!settings.keepScratch)
        #expect(settings.work == nil)
    }

    @Test("every switch survives a relaunch")
    func roundTrip() throws {
        let store = try store()
        defer { store.removePersistentDomain(forName: store.description) }

        let chosen = Preferences(
            faults: false,
            lettering: .matrix,
            numerals: .segment,
            composition: .deck,
            useMusicBrainz: false,
            keepScratch: true,
            work: "/Volumes/Big/scratch")
        chosen.save(to: store)
        #expect(Preferences.load(from: store, environment: [:]) == chosen)
    }

    /// `ImportOptions`'s rule, now keeping three values rather than one: the
    /// variable was typed this launch, so it wins — and it is not written back,
    /// because a variable exported in a shell profile that silently became the
    /// saved setting would be a preference nobody chose and could not find.
    @Test("a variable beats what was saved, and is not written back")
    func environmentWins() throws {
        let store = try store()
        defer { store.removePersistentDomain(forName: store.description) }

        Preferences(lettering: .matrix, useMusicBrainz: false, work: "/saved").save(to: store)

        let named = Preferences.load(
            from: store,
            environment: [
                "MUTHUR_CRT": "0",
                "MUTHUR_LETTERING": "type",
                "MUTHUR_NO_MB": "0",
                "MUTHUR_WORK": "/typed",
            ])
        #expect(!named.faults)
        #expect(named.lettering == .type)
        // `MUTHUR_NO_MB=0` is on, which is the one variable in the program that
        // reads the other way up.
        #expect(named.useMusicBrainz)
        #expect(named.work == "/typed")

        // Still what was chosen, underneath.
        let saved = Preferences.load(from: store, environment: [:])
        #expect(saved.lettering == .matrix)
        #expect(!saved.useMusicBrainz)
        #expect(saved.work == "/saved")
        #expect(saved.faults)
    }

    /// The failure this is really about: an unset variable must leave the saved
    /// value standing rather than overwrite it with the function's answer for
    /// *unset*. `MUTHUR_CRT` is the one that would bite — `faultsAllowed` says
    /// `true` for an empty environment, which would silently turn a person's
    /// deliberate `off` back on at every launch.
    @Test("an unset variable does not overwrite what was chosen")
    func unsetLeavesTheSettingAlone() throws {
        let store = try store()
        defer { store.removePersistentDomain(forName: store.description) }

        Preferences(faults: false, useMusicBrainz: false, keepScratch: true).save(to: store)
        let back = Preferences.load(from: store, environment: [:])
        #expect(!back.faults)
        #expect(!back.useMusicBrainz)
        #expect(back.keepScratch)
    }

    @Test("PLAYER_WORK still answers, for somebody who has had it exported for years")
    func oldName() throws {
        let store = try store()
        defer { store.removePersistentDomain(forName: store.description) }
        let settings = Preferences.load(from: store, environment: ["PLAYER_WORK": "/old"])
        #expect(settings.work == "/old")
    }

    @Test("a settings blob from a version with fewer switches still decodes")
    func forwardCompatible() throws {
        let data = try #require(#"{"numerals":"segment"}"#.data(using: .utf8))
        let settings = try JSONDecoder().decode(Preferences.self, from: data)
        #expect(settings.numerals == .segment)
        #expect(settings.faults)
        #expect(settings.lettering == .type)
        #expect(settings.composition == .runout)
        #expect(settings.useMusicBrainz)
        #expect(!settings.keepScratch)
        #expect(settings.work == nil)
    }

    @Test("a case this build has never heard of falls back rather than refusing the set")
    func unknownCase() throws {
        let data = try #require(
            #"{"lettering":"plasma","numerals":"segment"}"#.data(using: .utf8))
        let settings = try JSONDecoder().decode(Preferences.self, from: data)
        #expect(settings.lettering == .type)
        // The rest of the set survived it, which is the whole point.
        #expect(settings.numerals == .segment)
    }

    // MARK: - Reaching the two functions that still read a dictionary

    @Test("the storage settings reach Scratch as the variables it reads")
    func storageEnvironment() throws {
        // A directory that really exists, because `workBase` makes the choice
        // by trying to create and write it — pointing this at an invented path
        // would be testing the fallback rather than the setting.
        let chosen = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "muthur.test.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: chosen) }

        let merged = Preferences(keepScratch: true, work: chosen.path).storageEnvironment(
            merging: [:])
        #expect(merged["MUTHUR_WORK"] == chosen.path)
        #expect(Scratch.keepRequested(environment: merged))

        let base = Scratch.workBase(environment: merged, home: URL(fileURLWithPath: "/nowhere"))
        #expect(!base.fellBack)
        // Compared by resolved path: `$TMPDIR` is under `/var`, which is a
        // symlink to `/private/var`, and `workBase` hands back whichever form
        // it was given.
        #expect(base.url.resolvingSymlinksInPath() == chosen.resolvingSymlinksInPath())
    }

    @Test("a real variable still beats the setting on the way out")
    func storageEnvironmentDefersToTheVariable() {
        let merged = Preferences(work: "/from-settings").storageEnvironment(
            merging: ["MUTHUR_WORK": "/from-the-shell"])
        #expect(merged["MUTHUR_WORK"] == "/from-the-shell")
    }

    @Test("the defaults add nothing to the environment at all")
    func storageEnvironmentIsEmptyByDefault() {
        #expect(Preferences().storageEnvironment(merging: [:]).isEmpty)
    }
}
