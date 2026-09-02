import Foundation

/// A zip, read where it lies. §2.2.
///
/// The script prefers `bsdtar` and falls back to `unzip`, and the comment at
/// `player:256` is the reason this type exists instead: Apple's `unzip` runs a
/// UTF-8 name through a conversion to the local charset before it writes it, so
/// a decomposed `ô` — which is how a Mac writes `Hôtel` — comes out as two bytes
/// no filesystem will take, and `unzip` reports that as exit 50, the same code
/// it uses for a full disk. An album then stops with a message about room on a
/// volume with a hundred gigabytes free.
///
/// Reading the archive directly is the version of that with nothing left to go
/// wrong: the name bytes go from the central directory to the filesystem
/// untouched, and there is no exit code standing between the failure and the
/// sentence about it.
///
/// Only the central directory is held. Entry data is read on demand, so a
/// four-gigabyte record costs a few kilobytes to open.
public struct ZipArchive: Sendable {

    public struct Entry: Sendable, Equatable {
        /// The name as the filesystem will spell it, made from the archive's
        /// own bytes and not from a re-encoding of them.
        public let name: String
        /// Those bytes, kept because they are the truth and the string is a
        /// rendering of it.
        public let nameBytes: [UInt8]
        public let isDirectory: Bool
        /// General purpose bit 0, or one of the AES methods. Either way it is
        /// refused with a sentence rather than a prompt.
        public let isEncrypted: Bool
        public let method: UInt16
        public let compressedSize: UInt64
        public let uncompressedSize: UInt64
        public let crc32: UInt32
        let headerOffset: UInt64

        /// Store and deflate. Everything else in the spec is either extinct or
        /// patented into disuse, and an entry compressed some other way is one
        /// bad entry, not a bad album.
        public var isSupported: Bool { method == 0 || method == 8 }
    }

    public let url: URL
    public let entries: [Entry]

    /// What the count and the meter are about: directories are not entries
    /// anybody is waiting for (`player:1210`).
    public var files: [Entry] { entries.filter { !$0.isDirectory } }

    /// What it comes to unpacked, which is what decides whether to start at all
    /// (§2.1).
    public var unpackedSize: UInt64 {
        files.reduce(0) { $0 &+ $1.uncompressedSize }
    }

    /// One encrypted entry is an encrypted archive as far as this is concerned.
    /// Asked before anything is written, so the refusal costs nothing.
    public var isEncrypted: Bool { entries.contains(where: \.isEncrypted) }

    /// Whether there is anything in here §3 would play. §1.2, and D47.
    ///
    /// The picker's whole rule for a folder is `audio_count > 0`
    /// (`player:1039`), and this is that rule asked of an archive. It is asked
    /// of the **central directory** and of nothing else: a name and a member
    /// type are already in hand once the archive is open, so the question costs
    /// no bytes of entry data and nothing is written to disk to answer it.
    ///
    /// The definition of audio is `AudioFiles.extensions` — the same one the
    /// folder rows count with and the same one `Record.read` will use on the
    /// scratch directory afterwards. That agreement is the point: D7's lesson
    /// was that a picker counting by a different rule from playback drops
    /// albums that play perfectly.
    public var holdsAudio: Bool { files.contains { ZipArchive.isAudioMember($0.name) } }

    /// One member name, against the same rule `AudioFiles` applies to a path on
    /// disk — extension only, case-insensitively, and **nothing hidden**.
    ///
    /// The hidden clause is not tidiness. `AudioFiles.scan` walks with
    /// `.skipsHiddenFiles`, so after the unpack a `__MACOSX/._Song.flac` — which
    /// is in almost every archive a Mac made — is not a track. An archive whose
    /// only `.flac` is an AppleDouble stub would otherwise be offered as a
    /// record and then open as nothing, which is the failure this rule exists to
    /// prevent, arriving one step later.
    ///
    /// A member with no extension is not audio, which is the same answer
    /// `AudioFiles.isAudio` gives a file with no extension. Neither is a claim
    /// that every name has one.
    static func isAudioMember(_ name: String) -> Bool {
        let components = name.split(separator: "/", omittingEmptySubsequences: true)
        guard let last = components.last else { return false }
        guard !components.contains(where: { $0.hasPrefix(".") }) else { return false }
        guard let dot = last.lastIndex(of: "."), dot != last.startIndex else { return false }
        let ext = last[last.index(after: dot)...].lowercased()
        return AudioFiles.extensions.contains(ext)
    }

    // MARK: - Opening

    public init(url: URL) throws {
        self.url = url
        let file = try ZipFile(url: url)
        defer { file.close() }
        self.entries = try ZipArchive.readCentralDirectory(file)
    }

    // MARK: - Reading one entry

    /// The bytes of one entry, handed out a chunk at a time so that a lossless
    /// track never exists in memory twice.
    ///
    /// `sink` is called with each chunk in order. The CRC the archive recorded
    /// is checked at the end and a mismatch throws — which the caller is free to
    /// treat as one bad entry rather than a bad album.
    func extract(
        _ entry: Entry,
        from file: ZipFile,
        sink: (UnsafeRawBufferPointer) throws -> Void
    ) throws {
        // The local header repeats the name and extra field and they are
        // allowed to differ in length from the central directory's, so the data
        // offset can only be had from here.
        let header = try file.read(at: entry.headerOffset, count: 30)
        guard header.count == 30, load32(header, 0) == 0x0403_4b50 else {
            throw ZipFailure.damaged
        }
        let nameLength = UInt64(load16(header, 26))
        let extraLength = UInt64(load16(header, 28))
        let dataOffset = entry.headerOffset + 30 + nameLength + extraLength

        var crc = CRC32()
        var remaining = entry.compressedSize
        var offset = dataOffset

        // Reading in fixed bites rather than whole, because the entries this is
        // built for are lossless audio and the sizes are what they are.
        func nextChunk() throws -> [UInt8] {
            guard remaining > 0 else { return [] }
            let want = Int(min(remaining, UInt64(ZipArchive.chunk)))
            let bytes = try file.read(at: offset, count: want)
            guard !bytes.isEmpty else {
                // The archive stops before it said it would. Whether that is a
                // truncated file or a file that went away is a question for the
                // filesystem, not for a guess — see `Unpacker`.
                throw ZipFailure.shortRead
            }
            offset &+= UInt64(bytes.count)
            remaining &-= UInt64(bytes.count)
            return bytes
        }

        func emit(_ buffer: UnsafeRawBufferPointer) throws {
            crc.update(buffer)
            try sink(buffer)
        }

        switch entry.method {
        case 0:
            while true {
                let bytes = try nextChunk()
                if bytes.isEmpty { break }
                try bytes.withUnsafeBytes(emit)
            }
        case 8:
            try Inflate.run(next: nextChunk, emit: emit)
        default:
            throw ZipFailure.unsupportedMethod(entry.method)
        }

        guard remaining == 0 else { throw ZipFailure.shortRead }
        guard crc.value == entry.crc32 else { throw ZipFailure.badCRC }
    }

    static let chunk = 256 * 1024

    // MARK: - The central directory

    private static func readCentralDirectory(_ file: ZipFile) throws -> [Entry] {
        let size = file.size
        guard size >= 22 else { throw ZipFailure.notAZip }

        // The end record is last, unless there is an archive comment, which may
        // be up to 64K. Scanned backwards for the signature, which is what every
        // reader has to do.
        let window = Int(min(size, UInt64(22 + 0xFFFF)))
        let tail = try file.read(at: size - UInt64(window), count: window)
        guard let end = lastIndex(of: 0x0605_4b50, in: tail) else { throw ZipFailure.notAZip }

        var count = UInt64(load16(tail, end + 10))
        var directoryOffset = UInt64(load32(tail, end + 16))

        // Zip64, for the archives that need it. The locator sits immediately
        // before the end record.
        if count == 0xFFFF || directoryOffset == 0xFFFF_FFFF, end >= 20,
            load32(tail, end - 20) == 0x0706_4b50
        {
            let recordOffset = load64(tail, end - 20 + 8)
            let record = try file.read(at: recordOffset, count: 56)
            if record.count == 56, load32(record, 0) == 0x0606_4b50 {
                count = load64(record, 32)
                directoryOffset = load64(record, 48)
            }
        }
        guard directoryOffset < size else { throw ZipFailure.damaged }

        let directory = try file.read(at: directoryOffset, count: Int(size - directoryOffset))
        var entries: [Entry] = []
        entries.reserveCapacity(Int(min(count, 8192)))
        var cursor = 0

        while cursor + 46 <= directory.count, load32(directory, cursor) == 0x0201_4b50 {
            let flags = load16(directory, cursor + 8)
            let method = load16(directory, cursor + 10)
            let nameLength = Int(load16(directory, cursor + 28))
            let extraLength = Int(load16(directory, cursor + 30))
            let commentLength = Int(load16(directory, cursor + 32))
            let nameStart = cursor + 46
            guard nameStart + nameLength + extraLength + commentLength <= directory.count else {
                throw ZipFailure.damaged
            }

            var uncompressed = UInt64(load32(directory, cursor + 24))
            var compressed = UInt64(load32(directory, cursor + 20))
            var headerOffset = UInt64(load32(directory, cursor + 42))

            // The zip64 extra field carries only the values that overflowed,
            // in this order, so which fields are present depends on which of
            // the three read 0xFFFFFFFF.
            if uncompressed == 0xFFFF_FFFF || compressed == 0xFFFF_FFFF
                || headerOffset == 0xFFFF_FFFF
            {
                var extra = nameStart + nameLength
                let extraEnd = extra + extraLength
                while extra + 4 <= extraEnd {
                    let id = load16(directory, extra)
                    let length = Int(load16(directory, extra + 2))
                    guard extra + 4 + length <= extraEnd else { break }
                    if id == 0x0001 {
                        var field = extra + 4
                        let fieldEnd = field + length
                        if uncompressed == 0xFFFF_FFFF, field + 8 <= fieldEnd {
                            uncompressed = load64(directory, field)
                            field += 8
                        }
                        if compressed == 0xFFFF_FFFF, field + 8 <= fieldEnd {
                            compressed = load64(directory, field)
                            field += 8
                        }
                        if headerOffset == 0xFFFF_FFFF, field + 8 <= fieldEnd {
                            headerOffset = load64(directory, field)
                        }
                        break
                    }
                    extra += 4 + length
                }
            }

            let nameBytes = Array(directory[nameStart..<(nameStart + nameLength)])
            entries.append(
                Entry(
                    name: fileSystemName(nameBytes),
                    nameBytes: nameBytes,
                    isDirectory: nameBytes.last == 0x2F,
                    isEncrypted: flags & 1 == 1 || method == 99,
                    method: method,
                    compressedSize: compressed,
                    uncompressedSize: uncompressed,
                    crc32: load32(directory, cursor + 16),
                    headerOffset: headerOffset
                )
            )
            cursor = nameStart + nameLength + extraLength + commentLength
        }

        guard !entries.isEmpty || count == 0 else { throw ZipFailure.damaged }
        return entries
    }

    /// Bytes to the string the filesystem uses for those bytes, and back again
    /// unchanged. This is the whole of §2.2's first box: no re-encoding, no
    /// round trip through a matcher, nothing that can turn a combining
    /// circumflex into a name that will not open.
    static func fileSystemName(_ bytes: [UInt8]) -> String {
        guard !bytes.isEmpty else { return "" }
        let name = bytes.withUnsafeBufferPointer { buffer -> String? in
            buffer.withMemoryRebound(to: CChar.self) { chars in
                guard let base = chars.baseAddress else { return nil }
                return FileManager.default.string(
                    withFileSystemRepresentation: base, length: chars.count
                )
            }
        }
        // A name with a NUL in it has no filesystem spelling; decoding it
        // loosely at least gives the skip message something to print.
        return name ?? String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - Little-endian, at an offset

    private static func lastIndex(of signature: UInt32, in bytes: [UInt8]) -> Int? {
        guard bytes.count >= 4 else { return nil }
        var index = bytes.count - 4
        while index >= 0 {
            if load32(bytes, index) == signature { return index }
            index -= 1
        }
        return nil
    }
}

func load16(_ bytes: [UInt8], _ at: Int) -> UInt16 {
    UInt16(bytes[at]) | UInt16(bytes[at + 1]) << 8
}

func load32(_ bytes: [UInt8], _ at: Int) -> UInt32 {
    UInt32(bytes[at]) | UInt32(bytes[at + 1]) << 8 | UInt32(bytes[at + 2]) << 16
        | UInt32(bytes[at + 3]) << 24
}

func load64(_ bytes: [UInt8], _ at: Int) -> UInt64 {
    UInt64(load32(bytes, at)) | UInt64(load32(bytes, at + 4)) << 32
}

/// What can be wrong with the archive, before it is turned into a sentence
/// about the album. `Unpacker` does the turning, because only it knows the
/// label and only it can ask the disk.
enum ZipFailure: Error, Equatable {
    case notAZip
    case damaged
    case shortRead
    case badCRC
    case unsupportedMethod(UInt16)
    case cannotOpen(String)
}

/// A read-only file that can be read at an offset. `FileHandle` would do, but
/// its offset API throws on every call and this is read at from two places per
/// entry.
final class ZipFile {
    private let descriptor: Int32
    let size: UInt64

    init(url: URL) throws {
        let fd = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return Darwin.open(path, O_RDONLY)
        }
        guard fd >= 0 else { throw ZipFailure.cannotOpen(String(cString: strerror(errno))) }
        var status = stat()
        guard fstat(fd, &status) == 0, status.st_mode & S_IFMT == S_IFREG else {
            Darwin.close(fd)
            throw ZipFailure.notAZip
        }
        self.descriptor = fd
        self.size = UInt64(status.st_size)
    }

    /// Short reads are not an error here: a read that comes back short of what
    /// was asked is how the caller finds out the archive stops early.
    func read(at offset: UInt64, count: Int) throws -> [UInt8] {
        guard count > 0, offset < size else { return [] }
        let want = Int(min(UInt64(count), size - offset))
        var bytes = [UInt8](repeating: 0, count: want)
        var got = 0
        while got < want {
            let n = bytes.withUnsafeMutableBytes { buffer -> Int in
                pread(
                    descriptor,
                    buffer.baseAddress!.advanced(by: got),
                    want - got,
                    off_t(offset) + off_t(got)
                )
            }
            if n > 0 {
                got += n
            } else if n == 0 {
                break
            } else if errno == EINTR {
                continue
            } else {
                throw ZipFailure.cannotOpen(String(cString: strerror(errno)))
            }
        }
        if got < want { bytes.removeLast(want - got) }
        return bytes
    }

    func close() { Darwin.close(descriptor) }
}
