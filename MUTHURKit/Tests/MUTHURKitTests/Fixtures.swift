import Foundation

import MUTHURKit

/// Where the tests get material, and what never enters the repository.
///
/// Two tiers, on purpose:
///
/// - **Rules** — §3's arithmetic, tested against `StubMetadataReader` and
///   zero-byte files with the right names. No audio, no ffmpeg, no library.
///   These are the tests that must pass on any machine, and they are where
///   every degenerate case in §3.1 actually lives, because a degenerate case
///   is a degenerate *tag* and no real album has one on demand.
///
/// - **Material** — the readers, against real files, which is the only way to
///   find out that an MP4 writes its track number as a binary atom. These
///   point at files already on this machine and copy nothing into the tree:
///   `~/Music` for tagged MP4s, the zips in `~/Downloads` for untagged AIFFs.
///   Both locations are overridable, and every test in this tier is
///   `.enabled(if:)` on the material being there, so a fresh clone is green
///   rather than red about somebody else's record collection.
///
/// Nothing here writes to the repository. The one thing that is materialised —
/// a few megabytes off the front of an AIFF inside a zip — goes to the user
/// cache, beside where §2 will put unpacked albums, and is reused across runs.
enum Fixtures {

    /// Tagged MP4s: `Artist/Album/NN Title.m4a`, real track and disc atoms,
    /// real ISO date stamps.
    static var musicLibrary: URL {
        if let override = ProcessInfo.processInfo.environment["MUTHUR_TEST_MUSIC"] {
            return URL(fileURLWithPath: override)
        }
        return home.appending(path: "Music/Music/Media.localized/Music")
    }

    /// Zipped albums. The interesting ones are AIFF rips with no tags at all,
    /// which is the 9999-and-natural-sort case as it actually occurs.
    static var zipDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["MUTHUR_TEST_ZIPS"] {
            return URL(fileURLWithPath: override)
        }
        return home.appending(path: "Downloads")
    }

    /// §8's catalogue, on this machine. The live CSV in `cd-collection`, which
    /// is **read-only, always** (`CLAUDE.md`) — nothing in this suite writes to
    /// it, and every test that reads it is `.enabled(if:)` on it being there so
    /// a clone without that repository beside this one is green.
    static var collection: URL {
        if let override = ProcessInfo.processInfo.environment["MUTHUR_TEST_COLLECTION"] {
            return URL(fileURLWithPath: override)
        }
        return home.appending(path: "Sites/cd-collection/data/collection.csv")
    }

    static let home = URL(fileURLWithPath: NSHomeDirectory())

    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Tagged material

    /// Eleven MP4s, `track=3/11`, `disc=1/1`, `date=1977-02-04T08:00:00Z` —
    /// three of §3's rules in one album, none of them contrived.
    static var rumours: URL { musicLibrary.appending(path: "Fleetwood Mac/Rumours") }

    /// Any album directory under the library, for the invariants that should
    /// hold of every record rather than of one.
    static func anyTaggedAlbums(limit: Int = 4) -> [URL] {
        guard
            let artists = try? FileManager.default.contentsOfDirectory(
                at: musicLibrary, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else { return [] }
        var albums: [URL] = []
        for artist in artists.sorted(by: { $0.path < $1.path }) {
            let children =
                (try? FileManager.default.contentsOfDirectory(
                    at: artist, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
                )) ?? []
            for album in children.sorted(by: { $0.path < $1.path }) {
                guard !AudioFiles.scan(album).isEmpty else { continue }
                albums.append(album)
                if albums.count == limit { return albums }
            }
        }
        return albums
    }

    // MARK: - Untagged material, out of a zip

    /// The audio zips in `zipDirectory`, by name.
    static func audioZips() -> [URL] {
        let listing =
            (try? FileManager.default.contentsOfDirectory(
                at: zipDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            )) ?? []
        return listing
            .filter { $0.pathExtension.lowercased() == "zip" }
            .filter { !zipMembers($0).isEmpty }
            .sorted { $0.path < $1.path }
    }

    /// The audio entries inside a zip, in the order the archive lists them.
    /// Names only — §2 owns unpacking, and this is a test asking the archive
    /// what it is called, not the player opening it.
    static func zipMembers(_ zip: URL) -> [String] {
        guard let output = run("/usr/bin/unzip", ["-Z1", zip.path]) else { return [] }
        return output
            .split(separator: "\n")
            .map(String.init)
            .filter { AudioFiles.isAudio(URL(fileURLWithPath: $0)) }
    }

    /// A playable-enough copy of a zipped album: the first few megabytes of
    /// each audio member, which for AIFF is the whole header and therefore the
    /// whole of what §3 asks a file.
    ///
    /// Test scaffolding, deliberately not the app's zip path — §2 reads the
    /// archive itself and does not shell out. This shells out on purpose, so
    /// that nothing in this file can be mistaken for the real unpacker.
    ///
    /// Cached under the user cache directory, never under the repository.
    static func headsOfZippedAlbum(_ zip: URL, bytesPerMember: Int = 2_000_000) -> URL? {
        let name = zip.deletingPathExtension().lastPathComponent
        let destination = cacheRoot.appending(path: name)
        let members = zipMembers(zip)
        guard !members.isEmpty else { return nil }

        let already = AudioFiles.scan(destination)
        if already.count == members.count { return destination }

        try? FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true
        )
        for member in members {
            let out = destination.appending(
                path: URL(fileURLWithPath: member).lastPathComponent
            )
            guard !exists(out) else { continue }
            guard
                head(
                    of: member, in: zip, bytes: bytesPerMember, to: out
                )
            else { return nil }
        }
        return AudioFiles.scan(destination).isEmpty ? nil : destination
    }

    // MARK: - A seam that is real music on both sides

    /// The last few seconds of one track and the first few of the next, off the
    /// same record, cut so that the join between them is the join the album
    /// actually has.
    ///
    /// This is what makes the ambient records worth the trouble: on a held drone
    /// there is nothing else going on to hide behind, so a seam that survives
    /// here survives anywhere. Synthetic tones prove the arithmetic; this proves
    /// it on a file somebody mastered.
    ///
    /// The cut is done with `ffmpeg -c copy`, which is a byte copy of the PCM and
    /// not a re-encode — the samples in these files are the samples in the album.
    /// Shelling out is deliberate and is scaffolding only: it builds the fixture,
    /// it is not in the path of anything being tested. A few megabytes, cached
    /// beside the other fixtures and never in the repository.
    static func continuousSeam(seconds: Int = 8) -> (before: URL, after: URL)? {
        guard let ffmpeg = locate("ffmpeg") else { return nil }
        guard
            let zip = audioZips().first(where: { zipMembers($0).count >= 2 })
        else { return nil }

        let members = zipMembers(zip)
        let name = zip.deletingPathExtension().lastPathComponent
        let destination = cacheRoot.appending(path: "seam/\(name)")
        let before = destination.appending(path: "before.aiff")
        let after = destination.appending(path: "after.aiff")
        if exists(before) && exists(after) { return (before, after) }

        try? FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true
        )

        // `-sseof` needs to seek, so the member has to be a file rather than a
        // pipe. It is deleted as soon as it has been cut — these run to hundreds
        // of megabytes and none of it is wanted.
        guard
            cut(
                member: members[0], of: zip, with: ffmpeg,
                arguments: ["-sseof", "-\(seconds)"], to: before
            ),
            cut(
                member: members[1], of: zip, with: ffmpeg,
                arguments: ["-t", "\(seconds)"], to: after
            )
        else { return nil }
        return (before, after)
    }

    private static func cut(
        member: String, of zip: URL, with ffmpeg: URL, arguments: [String], to out: URL
    ) -> Bool {
        let whole = cacheRoot.appending(path: "seam-scratch-\(UUID().uuidString).aiff")
        defer { try? FileManager.default.removeItem(at: whole) }

        guard FileManager.default.createFile(atPath: whole.path, contents: nil),
            let sink = try? FileHandle(forWritingTo: whole)
        else { return false }
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-p", zip.path, member]
        unzip.standardOutput = sink
        unzip.standardError = FileHandle.nullDevice
        guard (try? unzip.run()) != nil else { return false }
        unzip.waitUntilExit()
        try? sink.close()
        guard unzip.terminationStatus == 0 else { return false }

        let cutter = Process()
        cutter.executableURL = ffmpeg
        // `-vn` and `-map 0:a:0` because these AIFFs carry the sleeve as a video
        // stream, which is also why §6 opens them with `-map 0:a:0`.
        cutter.arguments =
            ["-v", "error", "-nostdin"] + arguments
            + ["-i", whole.path, "-map", "0:a:0", "-vn", "-c:a", "copy", "-y", out.path]
        cutter.standardOutput = FileHandle.nullDevice
        cutter.standardError = FileHandle.nullDevice
        guard (try? cutter.run()) != nil else { return false }
        cutter.waitUntilExit()
        return cutter.terminationStatus == 0 && exists(out)
    }

    /// `Tooling.locate` is not visible from here and this is scaffolding, so the
    /// two places Homebrew puts things will do.
    static func locate(_ name: String) -> URL? {
        for directory in ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"] {
            let candidate = URL(fileURLWithPath: directory).appending(path: name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    static var cacheRoot: URL {
        let base =
            ProcessInfo.processInfo.environment["XDG_CACHE_HOME"].map {
                URL(fileURLWithPath: $0)
            } ?? home.appending(path: ".cache")
        return base.appending(path: "muthur/test-fixtures")
    }

    // MARK: - Shelling out, for scaffolding only

    private static func head(of member: String, in zip: URL, bytes: Int, to out: URL) -> Bool {
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-p", zip.path, member]
        let pipe = Pipe()
        unzip.standardOutput = pipe
        unzip.standardError = FileHandle.nullDevice
        guard (try? unzip.run()) != nil else { return false }

        var collected = Data()
        let handle = pipe.fileHandleForReading
        while collected.count < bytes {
            let chunk = handle.readData(ofLength: min(1 << 16, bytes - collected.count))
            if chunk.isEmpty { break }
            collected.append(chunk)
        }
        // Stop reading and let unzip die on the closed pipe rather than
        // decompressing three hundred megabytes nobody asked for.
        unzip.terminate()
        unzip.waitUntilExit()
        try? handle.close()

        guard !collected.isEmpty else { return false }
        return (try? collected.write(to: out)) != nil
    }

    private static func run(_ path: String, _ arguments: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = try? pipe.fileHandleForReading.readToEnd()
        process.waitUntilExit()
        guard let data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - A folder of names, for the rules tier

/// A throwaway directory of zero-byte files. The names are what the natural
/// sort sees; `StubMetadataReader` supplies whatever the tags are meant to say.
/// Between the two, every case in §3.1 can be built exactly, which no folder of
/// real music can.
struct NamedFolder: ~Copyable {
    let url: URL

    init(_ name: String, files: [String]) throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "muthur-tests/\(UUID().uuidString)/\(name)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for file in files {
            let child = url.appending(path: file)
            try FileManager.default.createDirectory(
                at: child.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            FileManager.default.createFile(atPath: child.path, contents: Data())
        }
    }

    deinit {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
