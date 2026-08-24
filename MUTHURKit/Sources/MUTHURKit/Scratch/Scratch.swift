import Foundation

/// Where a zip is unpacked to, and the promise that it does not outlive the
/// app. §2.
///
/// Not `$TMPDIR`, which is the obvious place and the wrong one. macOS treats
/// everything under `/var/folders/…/T` as space it may take back whenever the
/// disk gets tight, and it does not care that something is playing out of it: a
/// six-hour record unpacked onto a volume with little room left can simply cease
/// to exist halfway through, and what that looks like from the panel is every
/// remaining track failing to open inside two seconds and the album quietly
/// "finishing" (`player:170`).
///
/// So it goes under the cache directory, which is ours and which nothing else
/// reclaims. That trades one risk for another — `$TMPDIR` does at least get
/// swept eventually, and a session killed outright would leave its gigabytes
/// here for good. Hence `sweep`: every session writes its pid into its own
/// directory, and every session starting up clears away the directories whose
/// pid is nobody.
///
/// Made once, and destroyed by `tearDown` however the app ends. The directory
/// is created by this process and nothing else is ever in it, which is what
/// makes the recursive delete at the end safe to write at all.
public struct Scratch: Sendable {
    /// The directory sessions are made in and swept from.
    public let base: URL
    /// This session's own directory. Nothing else is in it.
    public let url: URL
    /// Where an album unpacks to.
    public let album: URL
    /// Where the analyser's tables go, and they go the same way at the end (§9).
    public let spec: URL
    /// True when the cache directory would not have us and `$TMPDIR` was taken
    /// instead. Worth knowing in diagnostics (§11); not worth refusing over.
    public let baseIsFallback: Bool

    /// The pid file, written before anything else goes in.
    public var pidFile: URL { url.appending(path: Scratch.pidName) }
    /// Present when somebody asked for the directory to survive.
    public var keepFile: URL { url.appending(path: Scratch.keepName) }

    // MARK: - Names

    /// Ours, and deliberately not the script's `player.` — see D13. Two
    /// programs sharing a base directory would put each sweep over the other's
    /// sessions, and the sweep's entire job is deleting things it did not
    /// create.
    static let prefix = "muthur."
    static let pidName = "pid"
    static let keepName = "keep"
    /// A directory with no pid in it is given five minutes before it counts as
    /// abandoned, so that a player starting up this instant is not swept by one
    /// starting up the next (`player:219`).
    static let graceSeconds: TimeInterval = 5 * 60

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case cannotMakeDirectory(base: String)
        case cannotWrite(path: String)
        /// A path that is not one of ours was handed to the delete. Never seen
        /// in practice; here because the alternative to checking is a recursive
        /// delete pointed at whatever was in the variable.
        case notOurs(path: String)

        public var description: String {
            switch self {
            case .cannotMakeDirectory(let base):
                "cannot make a scratch directory in \(base)"
            case .cannotWrite(let path):
                "cannot write to \(path)"
            case .notOurs(let path):
                "refusing to delete \(path): this process did not make it"
            }
        }
    }

    // MARK: - Opening one

    /// Sweep what the last sessions left behind, then take a directory of our
    /// own and put our pid in it.
    ///
    /// The pid goes in *before* the album directory does, because until that
    /// file exists this directory is one the next session's sweep cannot tell
    /// from an abandoned one (`player:243`).
    public static func open(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = URL(fileURLWithPath: NSHomeDirectory()),
        processID: Int32 = ProcessInfo.processInfo.processIdentifier,
        isAlive: (Int32) -> Bool = Scratch.processIsAlive,
        now: Date = Date()
    ) throws -> Scratch {
        let (base, fellBack) = workBase(environment: environment, home: home)
        sweep(base, now: now, isAlive: isAlive)

        let url = try makeSessionDirectory(in: base)
        let manager = FileManager.default

        // First, and on its own.
        let pid = Data("\(processID)\n".utf8)
        guard manager.createFile(atPath: url.appending(path: pidName).path, contents: pid) else {
            try? manager.removeItem(at: url)
            throw Failure.cannotWrite(path: url.path)
        }

        let album = url.appending(path: "album")
        let spec = url.appending(path: "spec")
        do {
            try manager.createDirectory(at: album, withIntermediateDirectories: false)
            try manager.createDirectory(at: spec, withIntermediateDirectories: false)
        } catch {
            try? manager.removeItem(at: url)
            throw Failure.cannotWrite(path: url.path)
        }

        return Scratch(base: base, url: url, album: album, spec: spec, baseIsFallback: fellBack)
    }

    /// The cache if it will have us, `$TMPDIR` if it will not. A read-only or
    /// missing home is a reason to take the worse directory, not a reason to
    /// refuse to play a record (`player:196`).
    static func workBase(
        environment: [String: String],
        home: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) -> (url: URL, fellBack: Bool) {
        let manager = FileManager.default
        let cache = environment["XDG_CACHE_HOME"].flatMap(nonEmpty).map(URL.init(fileURLWithPath:))
            ?? home.appending(path: ".cache")
        // `PLAYER_WORK` still answers, for somebody who has had it exported for
        // years and means it (D13, §13).
        let wanted = nonEmpty(environment["MUTHUR_WORK"]) ?? nonEmpty(environment["PLAYER_WORK"])
        let preferred = wanted.map(URL.init(fileURLWithPath:))
            ?? cache.appending(path: "muthur/work")

        if (try? manager.createDirectory(at: preferred, withIntermediateDirectories: true)) != nil,
            manager.isWritableFile(atPath: preferred.path)
        {
            return (preferred, false)
        }
        let fallback = nonEmpty(environment["TMPDIR"]) ?? "/tmp"
        return (URL(fileURLWithPath: fallback), true)
    }

    /// `mktemp -d "$base/muthur.XXXXXX"`, which is what gives us a directory
    /// nothing else is in.
    private static func makeSessionDirectory(in base: URL) throws -> URL {
        let manager = FileManager.default
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        for _ in 0..<64 {
            let suffix = String((0..<6).map { _ in alphabet.randomElement()! })
            let candidate = base.appending(path: prefix + suffix)
            // Not `withIntermediateDirectories`, so that a name already taken
            // is an error and not a directory somebody else is playing out of.
            do {
                try manager.createDirectory(
                    at: candidate,
                    withIntermediateDirectories: false,
                    attributes: [.posixPermissions: 0o700]
                )
                return candidate
            } catch CocoaError.fileWriteFileExists {
                continue
            } catch {
                throw Failure.cannotMakeDirectory(base: base.path)
            }
        }
        throw Failure.cannotMakeDirectory(base: base.path)
    }

    // MARK: - The sweep

    /// What sessions that are not running any more left behind (`player:207`).
    ///
    /// Two decks at once is allowed, and the second must not delete the first
    /// one's album out from under it — which is the whole failure this move was
    /// made to prevent.
    static func sweep(_ base: URL, now: Date, isAlive: (Int32) -> Bool) {
        let manager = FileManager.default
        guard
            let entries = try? manager.contentsOfDirectory(
                at: base,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        else { return }

        for entry in entries where entry.lastPathComponent.hasPrefix(prefix) {
            let values = try? entry.resourceValues(
                forKeys: [.isDirectoryKey, .contentModificationDateKey]
            )
            guard values?.isDirectory == true else { continue }
            // Somebody asked for this one with MUTHUR_KEEP. Theirs to delete,
            // not ours.
            if manager.fileExists(atPath: entry.appending(path: keepName).path) { continue }

            switch pid(in: entry) {
            case .some(let pid):
                // A pid that answers is a player still using it.
                if !isAlive(pid) { try? manager.removeItem(at: entry) }
            case .none:
                // No pid at all: a session that died between making its
                // directory and writing into it, or one that is doing exactly
                // that right now. Five minutes tells them apart.
                let modified = values?.contentModificationDate ?? .distantPast
                if now.timeIntervalSince(modified) > graceSeconds {
                    try? manager.removeItem(at: entry)
                }
            }
        }
    }

    /// The pid a directory claims, or nil where there is no file, no number in
    /// it, or something that is not a number.
    static func pid(in directory: URL) -> Int32? {
        guard
            let data = try? Data(contentsOf: directory.appending(path: pidName)),
            let text = String(data: data, encoding: .utf8)
        else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isASCII), trimmed.allSatisfy(\.isNumber),
            let value = Int32(trimmed), value > 0
        else { return nil }
        return value
    }

    /// `kill -0`. A pid we are not allowed to signal is still a pid that
    /// answers — `EPERM` means somebody is there.
    public static func processIsAlive(_ pid: Int32) -> Bool {
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    // MARK: - Teardown

    /// Torn down however the app ends. `keep` is the debug setting: the
    /// directory survives, and it is *marked*, or the next session's sweep would
    /// take it — this pid is about to stop answering, which is exactly what the
    /// sweep looks for (`player:313`).
    ///
    /// Returns the path when it was kept, so the caller can say where it is.
    @discardableResult
    public func tearDown(keep: Bool = false) throws -> URL? {
        // The one thing a recursive delete has to be sure of.
        guard url.deletingLastPathComponent().standardizedFileURL == base.standardizedFileURL,
            url.lastPathComponent.hasPrefix(Scratch.prefix)
        else { throw Failure.notOurs(path: url.path) }

        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return nil }

        if keep {
            manager.createFile(atPath: keepFile.path, contents: Data())
            return url
        }
        try manager.removeItem(at: url)
        return nil
    }

    /// Whether this session was asked to leave its directory behind.
    public static func keepRequested(environment: [String: String]) -> Bool {
        nonEmpty(environment["MUTHUR_KEEP"]) != nil || nonEmpty(environment["PLAYER_KEEP"]) != nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
