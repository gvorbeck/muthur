import Foundation

/// Opening a zip: whether it fits, then one pass over it, then what to say when
/// it goes wrong. §2.1 and §2.2.
///
/// The **whole** archive is unpacked, not just the audio, because the cover art
/// is worth having on the panel and a zip of an album is not big enough to be
/// worth being clever about (`player:1181`).
public enum Unpacker {

    /// 32 MiB. A record that only just fits must not leave the volume at zero:
    /// the rest of the machine is still using it, and an album is not worth
    /// wedging a Mac for (`player:1391`).
    public static let headroom: UInt64 = 33_554_432

    /// Where the meter is up to, one entry at a time (`player:1290`).
    public struct Progress: Sendable, Equatable {
        public let done: Int
        public let total: Int
        public let name: String
        public var percent: Int { total > 0 ? min(done, total) * 100 / total : 0 }
    }

    public struct Result: Sendable, Equatable {
        /// Entries written.
        public let written: Int
        /// Entries that were not, and why, in archive order. A resource fork, a
        /// corrupt booklet scan, an entry compressed some way this does not
        /// know. Not fatal, and the panel is entitled to say so (§17).
        public let skipped: [Skip]
        /// Directories the audio came out in, in scan order — the input to D12.
        /// One means the archive was flat.
        public let directories: [String]

        public struct Skip: Sendable, Equatable {
            public let name: String
            public let reason: String
        }
    }

    // MARK: - The one entry point

    /// Unpack `zip` into `destination`, which is `Scratch.album`.
    ///
    /// `freeSpace` and `isCancelled` are arguments rather than facts so that
    /// every branch below can be tested without a full disk and without a
    /// signal — which matters, because the branches that only run on a full
    /// disk are exactly the ones that have been wrong before.
    public static func unpack(
        zip: URL,
        into destination: URL,
        label: String? = nil,
        work: String? = nil,
        freeSpace: (URL) -> UInt64 = Unpacker.freeSpace(at:),
        isCancelled: () -> Bool = { false },
        progress: ((Progress) -> Void)? = nil
    ) throws -> Result {
        let label = label ?? zip.lastPathComponent
        let work = work ?? destination.path

        let archive: ZipArchive
        do {
            archive = try ZipArchive(url: zip)
        } catch ZipFailure.notAZip {
            throw UnpackFailure.notAZip(label: label)
        } catch ZipFailure.damaged {
            throw UnpackFailure.notAZip(label: label)
        } catch ZipFailure.cannotOpen(let detail) {
            guard FileManager.default.fileExists(atPath: zip.path) else {
                throw UnpackFailure.sourceVanished(path: zip.path)
            }
            throw UnpackFailure.unreadable(label: label, detail: detail)
        }

        // Refused with one sentence, and before a byte is written. The bash
        // version hands its unpacker a passphrase it will certainly not accept
        // purely to turn a hang nobody can see into an error (`player:267`);
        // reading the archive directly, the flag is simply there to be read.
        guard !archive.isEncrypted else { throw UnpackFailure.encrypted(label: label) }

        let files = archive.files
        guard !files.isEmpty else { throw UnpackFailure.empty(label: label) }

        // Whether it fits, asked before a byte of it is written. A lossless
        // record is two to three times its zip, a long one is several gigabytes
        // of that, and the volume this unpacks onto is nobody's idea of empty.
        // Finding out afterwards means a half-unpacked album and a disk with
        // nothing left on it (`player:1381`).
        let need = archive.unpackedSize
        if need > 0 {
            let have = freeSpace(destination)
            if have < need || have - need < headroom {
                throw UnpackFailure.doesNotFit(
                    label: label, need: need, have: have, work: work
                )
            }
        }

        return try write(
            archive: archive,
            files: files,
            into: destination,
            label: label,
            work: work,
            freeSpace: freeSpace,
            isCancelled: isCancelled,
            progress: progress
        )
    }

    // MARK: - One pass over the archive

    private static func write(
        archive: ZipArchive,
        files: [ZipArchive.Entry],
        into destination: URL,
        label: String,
        work: String,
        freeSpace: (URL) -> UInt64,
        isCancelled: () -> Bool,
        progress: ((Progress) -> Void)?
    ) throws -> Result {
        let manager = FileManager.default
        let file: ZipFile
        do {
            file = try ZipFile(url: archive.url)
        } catch {
            throw UnpackFailure.sourceVanished(path: archive.url.path)
        }
        defer { file.close() }

        let root = destination.standardizedFileURL
        var written = 0
        var skipped: [Result.Skip] = []
        var directories: [String] = []
        var seenDirectory: Set<String> = []

        for (index, entry) in files.enumerated() {
            if isCancelled() { throw UnpackFailure.interrupted(label: label) }

            guard entry.isSupported else {
                skipped.append(.init(name: entry.name, reason: "compressed a way this cannot read"))
                continue
            }
            // A name that climbs out of the directory it was given. Not an
            // archive worth stopping for and not an entry worth writing.
            guard let target = safeDestination(entry.name, under: root) else {
                skipped.append(.init(name: entry.name, reason: "its name points outside the album"))
                continue
            }

            do {
                try manager.createDirectory(
                    at: target.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try writeEntry(entry, of: archive, from: file, to: target)
            } catch let failure as ZipFailure {
                switch failure {
                case .shortRead:
                    // Asked of the filesystem, never inferred: an archive that
                    // stops early is truncated, and one that is no longer there
                    // went away while this was reading it.
                    guard manager.fileExists(atPath: archive.url.path) else {
                        throw UnpackFailure.sourceVanished(path: archive.url.path)
                    }
                    throw UnpackFailure.truncated(label: label, entry: entry.name)
                case .badCRC:
                    skipped.append(.init(name: entry.name, reason: "it did not come out whole"))
                    try? manager.removeItem(at: target)
                    continue
                default:
                    skipped.append(.init(name: entry.name, reason: "this cannot read it"))
                    try? manager.removeItem(at: target)
                    continue
                }
            } catch {
                // Something would not write. This is the exit-50 problem
                // (`player:1345`): the same failure covers a full disk and a
                // name the filesystem will not take, so the *disk* is asked
                // rather than the error believed. Still room means it was the
                // name, and one unwritable entry is not a reason to close the
                // record — the rest of the album is sitting right there.
                if freeSpace(destination) < headroom {
                    throw UnpackFailure.outOfRoom(
                        label: label, free: freeSpace(destination), work: work
                    )
                }
                skipped.append(.init(name: entry.name, reason: "it would not write"))
                continue
            }

            written += 1
            let folder = target.deletingLastPathComponent().standardizedFileURL.path
            if seenDirectory.insert(folder).inserted { directories.append(folder) }
            progress?(
                Progress(done: index + 1, total: files.count, name: target.lastPathComponent)
            )
        }

        // Something wrong with an entry is one thing; an archive that yielded
        // nothing at all is the end of the album (`player:1308`).
        guard written > 0 else { throw UnpackFailure.yieldedNothing(label: label) }

        directories.sort { AudioFiles.byteOrder($0, $1) == .orderedAscending }
        return Result(written: written, skipped: skipped, directories: directories)
    }

    private static func writeEntry(
        _ entry: ZipArchive.Entry,
        of archive: ZipArchive,
        from file: ZipFile,
        to target: URL
    ) throws {
        guard FileManager.default.createFile(atPath: target.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let handle = try FileHandle(forWritingTo: target)
        defer { try? handle.close() }
        try archive.extract(entry, from: file) { buffer in
            try handle.write(contentsOf: Data(buffer))
        }
    }

    /// The path an entry may be written to, or nil where it may not be. `..`,
    /// an absolute name, and anything else that would land outside the album.
    static func safeDestination(_ name: String, under root: URL) -> URL? {
        // A leading slash is refused rather than trimmed. `unzip` quietly drops
        // it and carries on; an entry that names an absolute path is not naming
        // a file in this album, and the album is better off without it.
        guard !name.hasPrefix("/") else { return nil }
        let parts = name.split(separator: "/").map(String.init)
        guard !parts.isEmpty, !parts.contains(".."), !parts.contains(".") else { return nil }
        let target = parts.reduce(root) { $0.appending(path: $1) }.standardizedFileURL
        guard target.path.hasPrefix(root.path + "/") else { return nil }
        return target
    }

    // MARK: - How much room is left

    /// `df -Pk` in one call: the blocks the volume will actually let you have.
    /// Deliberately not the "important usage" figure, which counts space the
    /// system would have to purge to give you — the question here is the same
    /// one `room_free` asks (`player:1200`).
    public static func freeSpace(at url: URL) -> UInt64 {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        guard let capacity = values?.volumeAvailableCapacity, capacity > 0 else { return 0 }
        return UInt64(capacity)
    }
}

/// Why the album did not open, in a sentence somebody who has just been told no
/// can act on. Ported message for message from `unpack_die` and its two callers
/// (`player:1226`, `player:1230`, `player:1350`), with the exit codes gone —
/// nothing here is inferred from a return value.
public enum UnpackFailure: Error, Equatable, CustomStringConvertible {
    /// The disk filled partway through. Asked of the disk, never inferred.
    case outOfRoom(label: String, free: UInt64, work: String)
    /// It will not fit, asked before anything was written (§2.1).
    case doesNotFit(label: String, need: UInt64, have: UInt64, work: String)
    case encrypted(label: String)
    case truncated(label: String, entry: String?)
    case notAZip(label: String)
    case unreadable(label: String, detail: String)
    case sourceVanished(path: String)
    case interrupted(label: String)
    /// The archive holds no files at all (`player:1379`).
    case empty(label: String)
    /// It held some and not one of them came out (`player:1308`).
    case yieldedNothing(label: String)

    public var description: String {
        switch self {
        case .outOfRoom(let label, let free, let work):
            "ran out of room unpacking \(label) — \(UnpackFailure.room(free)) left in \(work)"
        case .doesNotFit(let label, let need, let have, let work):
            "\(label) unpacks to \(UnpackFailure.room(need)) and there is "
                + "\(UnpackFailure.room(have)) free in \(work) — set MUTHUR_WORK to somewhere "
                + "with room"
        case .encrypted(let label):
            "\(label) is encrypted — this player cannot open it"
        case .truncated(let label, let entry):
            entry.map { "\(label) is truncated — it ends partway through \(($0 as NSString).lastPathComponent)" }
                ?? "\(label) is truncated — it stops partway through"
        case .notAZip(let label):
            "\(label) is not a zip this can read"
        case .unreadable(let label, let detail):
            "cannot open \(label) — \(detail)"
        case .sourceVanished(let path):
            "\(path) went away while it was being unpacked"
        case .interrupted(let label):
            "interrupted while unpacking \(label)"
        case .empty(let label):
            "nothing inside \(label)"
        case .yieldedNothing(let label):
            "nothing came out of \(label)"
        }
    }

    /// Bytes as something a person can read. Only the two messages about room
    /// use it, and both of them are read by somebody who has just been told no
    /// (`player:1189`).
    static func room(_ bytes: UInt64) -> String {
        let units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var value = Double(bytes)
        var index = 0
        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return index == 0
            ? "\(UInt64(value)) \(units[index])"
            : String(format: "%.1f %@", value, units[index])
    }
}
