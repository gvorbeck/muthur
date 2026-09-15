import Foundation

/// **D91** — the directories you keep records in, and what was found in them.
///
/// **Neither script has this.** `player`'s picker is `PLAYER_DIRS` walked afresh
/// every time it starts, and D50 took even that away. What came back is not the
/// search path: it is a list you edit, of places you named, with each record's
/// sleeve fetched once and kept. The walk is `LibraryWalk`; this is what is
/// remembered between walks.
///
/// **It is a record of what was there, not a promise that it still is.** A
/// directory on a drive that is not plugged in keeps its records, and the panel
/// draws them dimmed; the only thing that removes a record is a walk of a
/// directory that could be reached and no longer had it.
public struct Library: Codable, Sendable, Equatable {

    public var directories: [Directory]

    public init(directories: [Directory] = []) {
        self.directories = directories
    }

    public struct Directory: Codable, Sendable, Equatable, Identifiable {
        public let id: UUID
        /// The path it was added at, and where it is looked for when the
        /// bookmark cannot say.
        public var path: String
        /// What the open panel handed over, kept the way `CatalogueFile` keeps
        /// the shelf's (D5): a string stops working the day this is sandboxed.
        public var bookmark: Data?
        /// When it was last walked. Nil is *never* — added while the drive was
        /// away, or not yet opened since.
        public var scanned: Date?
        public var albums: [Album]

        public init(
            id: UUID = UUID(), path: String, bookmark: Data? = nil, scanned: Date? = nil,
            albums: [Album] = []
        ) {
            self.id = id
            self.path = path
            self.bookmark = bookmark
            self.scanned = scanned
            self.albums = albums
        }

        public var url: URL { URL(fileURLWithPath: path) }
    }

    public struct Album: Codable, Sendable, Equatable, Identifiable {
        /// Under the directory, `/`-separated — `LibraryWalk.Found.path`.
        public let path: String
        public var kind: LibraryWalk.Kind
        public var title: String
        public var artist: String
        /// The sleeve's filename in the library's own covers directory, or nil.
        public var cover: String?
        public var coverSource: Sleeve.Source?
        /// Whether a sleeve has been looked for. **This is the "once".** A
        /// record that has been asked about is not asked about again — found or
        /// not — until a rescan says to try the ones that came back empty.
        public var coverAsked: Bool

        public init(
            path: String, kind: LibraryWalk.Kind, title: String, artist: String,
            cover: String? = nil, coverSource: Sleeve.Source? = nil, coverAsked: Bool = false
        ) {
            self.path = path
            self.kind = kind
            self.title = title
            self.artist = artist
            self.cover = cover
            self.coverSource = coverSource
            self.coverAsked = coverAsked
        }

        public var id: String { path }
    }

    // MARK: - Adding and removing

    public enum Refusal: Error, Sendable, Equatable {
        /// The same directory, or one already inside the library by way of
        /// another. Either would put every record in it on the screen twice.
        case alreadyThere(String)
        /// A directory that holds one already in the library. Taking it would
        /// mean quietly merging the two, and removing either later would not
        /// do what it said.
        case holdsOneAlready(String)
    }

    @discardableResult
    public mutating func add(_ url: URL, bookmark: Data?) throws(Refusal) -> Directory {
        let path = url.standardizedFileURL.path
        for existing in directories {
            if Library.contains(existing.path, path) { throw .alreadyThere(existing.path) }
            if Library.contains(path, existing.path) { throw .holdsOneAlready(existing.path) }
        }
        let directory = Directory(path: path, bookmark: bookmark)
        directories.append(directory)
        return directory
    }

    /// Takes the directory and its records off the list, and hands back what
    /// was taken so the caller can clear up its sleeves.
    @discardableResult
    public mutating func remove(_ id: UUID) -> Directory? {
        guard let index = directories.firstIndex(where: { $0.id == id }) else { return nil }
        return directories.remove(at: index)
    }

    /// `outer` is `inner` or a directory above it. By path components, so that
    /// `/Volumes/Music 2` is not inside `/Volumes/Music`.
    static func contains(_ outer: String, _ inner: String) -> Bool {
        let a = URL(fileURLWithPath: outer).standardizedFileURL.pathComponents
        let b = URL(fileURLWithPath: inner).standardizedFileURL.pathComponents
        return b.count >= a.count && Array(b.prefix(a.count)) == a
    }

    // MARK: - After a walk

    /// What a walk found, laid over what was already known.
    ///
    /// A record that was there before keeps everything it had — its sleeve, and
    /// any name its tags gave it. A new one arrives named off its path. One the
    /// walk did not find is gone, and comes back in `dropped` so its sleeve can
    /// go with it.
    public static func merge(
        _ known: [Album], with found: [LibraryWalk.Found]
    ) -> (albums: [Album], dropped: [Album]) {
        var byPath: [String: Album] = [:]
        for album in known { byPath[album.path] = album }
        var albums: [Album] = []
        var kept: Set<String> = []
        for record in found {
            kept.insert(record.path)
            if var existing = byPath[record.path] {
                existing.kind = record.kind
                albums.append(existing)
            } else {
                let name = named(record.path, kind: record.kind)
                albums.append(Album(path: record.path, kind: record.kind, title: name.title, artist: name.artist))
            }
        }
        return (albums, known.filter { !kept.contains($0.path) })
    }

    /// A record's name before any tag has been read, off nothing but where it
    /// sits: `070 Shake/Modus Vivendi.zip` is Modus Vivendi by 070 Shake, and a
    /// loose `Agriculture - Agriculture.zip` is the Bandcamp shape, artist
    /// first. Anything else is a title with no artist, which is the truth.
    ///
    /// Only a guess, and treated as one: the sleeve lookup reads the tags and
    /// replaces both halves with what they say.
    public static func named(_ path: String, kind: LibraryWalk.Kind) -> (artist: String, title: String) {
        let parts = path.split(separator: "/").map(String.init)
        guard let last = parts.last else { return ("", path) }
        let label = kind == .zip ? Record.albumFromSourceLabel(last) : last
        if parts.count >= 2 {
            return (parts[parts.count - 2], label)
        }
        if let dash = label.range(of: " - ") {
            let artist = String(label[..<dash.lowerBound])
            let title = String(label[dash.upperBound...])
            if !artist.isEmpty, !title.isEmpty { return (artist, title) }
        }
        return ("", label)
    }

    /// How the library is laid out on the screen: artist, then title, the way
    /// a shelf is filed — and not path order, which files the Bandcamp zips at
    /// the top of a drive apart from every folder by the same band.
    public static func filed(_ albums: [Album]) -> [Album] {
        albums.sorted { a, b in
            let artist = NaturalOrder.compare(Library.filing(a.artist), Library.filing(b.artist))
            if artist != .orderedSame { return artist == .orderedAscending }
            let title = NaturalOrder.compare(a.title.lowercased(), b.title.lowercased())
            if title != .orderedSame { return title == .orderedAscending }
            return AudioFiles.byteOrder(a.path, b.path) == .orderedAscending
        }
    }

    /// `The Cure` under C, and `B-52's, The` beside it under B — the second is
    /// how a collection already filed that way names its folders. Every record
    /// shop does it and every shopper expects it; filing them under T is the
    /// kind of tidy nobody asked for.
    static func filing(_ artist: String) -> String {
        let lowered = artist.lowercased()
        if lowered.hasPrefix("the ") { return String(lowered.dropFirst(4)) }
        if lowered.hasSuffix(", the") { return String(lowered.dropLast(5)) }
        return lowered
    }

    /// The sleeve's filename, stable for the life of the record in this
    /// directory. Hashed rather than folded from the path, because two paths
    /// that fold alike — `Live/1.zip` and `Live 1.zip` — are two records.
    public static func coverName(directory: UUID, path: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in path.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return "\(directory.uuidString.lowercased())-\(String(hash, radix: 16)).jpg"
    }
}

extension Sleeve.Source: Codable {}
