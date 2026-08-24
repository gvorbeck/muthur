import Foundation
import Testing

@testable import MUTHURKit

/// §2 — the directory a zip unpacks into, and the promise that it does not
/// outlive the app.
///
/// The sweep is the part worth testing hard. It is the only code in the program
/// that deletes a directory it did not create, it runs before anything is on
/// screen to report from, and the failure it exists to prevent — a second deck
/// taking the first one's album out from under it — is silent while it happens.
@Suite("§2 — the scratch directory")
struct ScratchTests {

    // MARK: - Where it goes

    @Test("the cache, not $TMPDIR (player:170)")
    func baseIsUnderTheCache() {
        let cache = TempDirectory()
        let (base, fellBack) = Scratch.workBase(
            environment: ["XDG_CACHE_HOME": cache.url.path, "TMPDIR": "/var/folders/x/T"]
        )
        #expect(base.path == cache.url.appending(path: "muthur/work").path)
        #expect(!fellBack)
        #expect(FileManager.default.fileExists(atPath: base.path))
    }

    @Test("MUTHUR_WORK overrides, and PLAYER_WORK still answers (D13)")
    func workOverrides() {
        let ours = TempDirectory()
        let theirs = TempDirectory()
        #expect(Scratch.workBase(environment: ["MUTHUR_WORK": ours.url.path]).url.path == ours.url.path)
        #expect(
            Scratch.workBase(environment: ["PLAYER_WORK": theirs.url.path]).url.path
                == theirs.url.path
        )
        // Ours wins where both are set.
        let both = Scratch.workBase(
            environment: ["MUTHUR_WORK": ours.url.path, "PLAYER_WORK": theirs.url.path]
        )
        #expect(both.url.path == ours.url.path)
    }

    @Test("a home that will not have us is a reason to take $TMPDIR (player:196)")
    func fallsBackToTmp() throws {
        let home = TempDirectory()
        let cache = home.directory("locked")
        // A read-only cache directory, which is what a read-only or missing
        // home looks like from here.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500], ofItemAtPath: cache.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: cache.path
            )
        }

        let tmp = TempDirectory()
        let (base, fellBack) = Scratch.workBase(
            environment: ["XDG_CACHE_HOME": cache.path, "TMPDIR": tmp.url.path]
        )
        #expect(fellBack)
        #expect(base.path == tmp.url.path)
    }

    // MARK: - Opening one

    @Test("the pid goes in before anything else does (player:243)")
    func pidIsWrittenFirst() throws {
        let base = TempDirectory()
        let scratch = try Scratch.open(environment: ["MUTHUR_WORK": base.url.path])
        defer { _ = try? scratch.tearDown() }

        #expect(scratch.url.lastPathComponent.hasPrefix("muthur."))
        #expect(scratch.url.deletingLastPathComponent().path == base.url.path)
        #expect(FileManager.default.fileExists(atPath: scratch.pidFile.path))
        #expect(Scratch.pid(in: scratch.url) == ProcessInfo.processInfo.processIdentifier)
        // And the two directories that go in after it.
        #expect(FileManager.default.fileExists(atPath: scratch.album.path))
        #expect(FileManager.default.fileExists(atPath: scratch.spec.path))
    }

    @Test("one directory per session, and nothing else is in it (player:241)")
    func oneDirectoryPerSession() throws {
        let base = TempDirectory()
        let first = try Scratch.open(environment: ["MUTHUR_WORK": base.url.path])
        let second = try Scratch.open(environment: ["MUTHUR_WORK": base.url.path])
        defer {
            _ = try? first.tearDown()
            _ = try? second.tearDown()
        }
        #expect(first.url != second.url)
    }

    // MARK: - The sweep

    @Test("a directory whose pid does not answer is removed (player:207)")
    func sweepsTheDead() throws {
        let base = TempDirectory()
        let dead = try session(in: base.url, pid: "4242")
        Scratch.sweep(base.url, now: Date(), isAlive: { _ in false })
        #expect(!FileManager.default.fileExists(atPath: dead.path))
    }

    @Test("a pid that answers is a player still using it")
    func sparesTheLiving() throws {
        let base = TempDirectory()
        let live = try session(in: base.url, pid: "4242")
        Scratch.sweep(base.url, now: Date(), isAlive: { _ in true })
        #expect(FileManager.default.fileExists(atPath: live.path))
    }

    @Test("no pid file: five minutes, so this instant is not swept by the next")
    func sweepsOnlyStaleUnclaimedDirectories() throws {
        let base = TempDirectory()
        let starting = try session(in: base.url, pid: nil)
        let abandoned = try session(in: base.url, pid: nil)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -10 * 60)],
            ofItemAtPath: abandoned.path
        )

        Scratch.sweep(base.url, now: Date(), isAlive: { _ in false })
        #expect(FileManager.default.fileExists(atPath: starting.path))
        #expect(!FileManager.default.fileExists(atPath: abandoned.path))
    }

    @Test("a pid file with nothing usable in it is no pid file at all")
    func garbagePidCountsAsAbsent() throws {
        let base = TempDirectory()
        for text in ["", "  ", "not-a-pid", "12x", "-3", "0"] {
            let directory = try session(in: base.url, pid: text)
            #expect(Scratch.pid(in: directory) == nil, "\(text.debugDescription) read as a pid")
        }
    }

    @Test("a `keep` file is never swept — somebody asked for it")
    func keepSurvivesTheSweep() throws {
        let base = TempDirectory()
        let kept = try session(in: base.url, pid: "4242")
        FileManager.default.createFile(
            atPath: kept.appending(path: "keep").path, contents: Data()
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -60 * 60)], ofItemAtPath: kept.path
        )
        Scratch.sweep(base.url, now: Date(), isAlive: { _ in false })
        #expect(FileManager.default.fileExists(atPath: kept.path))
    }

    @Test("nothing outside the prefix is touched, whatever it is")
    func sweepsOnlyItsOwn() throws {
        let manager = FileManager.default
        let base = TempDirectory()
        // A bash `player` session in a shared base, which D13 says should never
        // happen — and which this proves costs nothing if it does.
        let theirs = base.directory("player.abcdef")
        let innocent = base.directory("Rumours")
        Scratch.sweep(base.url, now: Date(), isAlive: { _ in false })
        #expect(manager.fileExists(atPath: theirs.path))
        #expect(manager.fileExists(atPath: innocent.path))
    }

    @Test("two decks at once, and the second does not delete the first's album")
    func twoDecksAtOnce() throws {
        let base = TempDirectory()
        let first = try Scratch.open(environment: ["MUTHUR_WORK": base.url.path])
        let album = first.album.appending(path: "01 Second Hand News.flac")
        FileManager.default.createFile(atPath: album.path, contents: Data("audio".utf8))

        // The second session sweeps on its way in, with the real liveness test.
        let second = try Scratch.open(environment: ["MUTHUR_WORK": base.url.path])
        defer {
            _ = try? first.tearDown()
            _ = try? second.tearDown()
        }
        #expect(FileManager.default.fileExists(atPath: album.path))
    }

    @Test("this process answers kill -0")
    func weAreAlive() {
        #expect(Scratch.processIsAlive(ProcessInfo.processInfo.processIdentifier))
        #expect(!Scratch.processIsAlive(Int32.max - 1))
    }

    // MARK: - Teardown

    @Test("teardown takes the directory with it")
    func tearsDown() throws {
        let base = TempDirectory()
        let scratch = try Scratch.open(environment: ["MUTHUR_WORK": base.url.path])
        FileManager.default.createFile(
            atPath: scratch.album.appending(path: "a.flac").path, contents: Data("x".utf8)
        )
        #expect(try scratch.tearDown() == nil)
        #expect(!FileManager.default.fileExists(atPath: scratch.url.path))
    }

    @Test("MUTHUR_KEEP: the directory survives, and is marked so the next sweep spares it")
    func keepMarksAndSurvives() throws {
        let base = TempDirectory()
        let scratch = try Scratch.open(environment: ["MUTHUR_WORK": base.url.path])
        defer { try? FileManager.default.removeItem(at: scratch.url) }

        let kept = try scratch.tearDown(keep: true)
        #expect(kept == scratch.url)
        #expect(FileManager.default.fileExists(atPath: scratch.keepFile.path))

        // The mark is the point: this pid is about to stop answering, which is
        // exactly what the sweep looks for.
        Scratch.sweep(base.url, now: Date(), isAlive: { _ in false })
        #expect(FileManager.default.fileExists(atPath: scratch.url.path))
    }

    @Test("MUTHUR_KEEP and PLAYER_KEEP are both read")
    func keepIsRequestedByEither() {
        #expect(Scratch.keepRequested(environment: ["MUTHUR_KEEP": "1"]))
        #expect(Scratch.keepRequested(environment: ["PLAYER_KEEP": "1"]))
        #expect(!Scratch.keepRequested(environment: ["MUTHUR_KEEP": ""]))
        #expect(!Scratch.keepRequested(environment: [:]))
    }

    @Test("the delete refuses a path this process did not make")
    func tearDownRefusesAStranger() throws {
        let base = TempDirectory()
        let elsewhere = TempDirectory()
        let valuable = elsewhere.directory("Music")
        let forged = Scratch(
            base: base.url,
            url: valuable,
            album: valuable,
            spec: valuable,
            baseIsFallback: false
        )
        #expect(throws: Scratch.Failure.notOurs(path: valuable.path)) {
            try forged.tearDown()
        }
        #expect(FileManager.default.fileExists(atPath: valuable.path))
    }

    // MARK: -

    /// A session directory as some other process would have left it.
    private func session(in base: URL, pid: String?) throws -> URL {
        let url = base.appending(path: "muthur.\(UUID().uuidString.prefix(6))")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        if let pid {
            FileManager.default.createFile(
                atPath: url.appending(path: "pid").path, contents: Data("\(pid)\n".utf8)
            )
        }
        return url
    }
}
