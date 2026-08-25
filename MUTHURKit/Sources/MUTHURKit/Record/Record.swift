import Foundation

/// The album, read and put in order. §3.
///
/// Two orders live in here and they are not the same thing:
///
/// - **scan order** — `tracks`, the order the folder was walked in, which is
///   byte order over the paths and identical on any machine. Everything
///   indexes by it.
/// - **running order** — `order`, indices into `tracks`, which is what you
///   hear and what the panel draws.
///
/// Keeping them separate is the whole of `player:1518`: CD-Text and MusicBrainz
/// answer in *track numbers* while the arrays are in *scan order*, and nothing
/// may index a track number as `n - 1`.
public struct Record: Sendable {
    /// Scan order. §4 writes titles back into these rows.
    public var tracks: [Track]
    /// Indices into `tracks`, disc then track then natural filename.
    public private(set) var order: [Int]
    public var album: String
    public var albumArtist: String
    /// Four digits, or empty. A string and not an Int because it is a label,
    /// and because a record whose tag says `19XX` should show `19XX`.
    public var year: String
    /// The sum of the ordered durations (`player:1513`).
    public private(set) var total: Int
    /// The folder or zip this came out of, as it is named on screen.
    public let sourceLabel: String
    /// Files found and skipped because nothing could read them. Not fatal, but
    /// the panel is entitled to say so — §17.
    public let unreadableCount: Int

    /// The tracks in the order they play.
    public var running: [Track] { order.map { tracks[$0] } }

    /// How many rows have no track number of their own. The script sets a flag
    /// for this and never reads it (§15, §18.15); this is the same fact,
    /// computed rather than remembered, so it cannot go stale when §4 rewrites
    /// a row.
    public var unnumberedCount: Int { tracks.count { !$0.isNumbered } }

    // MARK: - Reading

    public enum Failure: Error, Equatable, CustomStringConvertible {
        /// Nothing with an audio extension under the source at all
        /// (`player:1423`).
        case noAudio(source: String)
        /// Files were found and not one of them could be read
        /// (`player:1494`).
        case noReadableAudio(source: String)

        public var description: String {
            switch self {
            case .noAudio(let source):
                "no audio in \(source)"
            case .noReadableAudio(let source):
                "no readable audio in \(source)"
            }
        }
    }

    /// Where the loading meter is up to. `read` of `total` is progress through
    /// the *folder*, not through the album: a file that could not be read still
    /// advances it, because the denominator counted that file too
    /// (`player:1445`, §18.12).
    public struct Progress: Sendable, Equatable {
        public let read: Int
        public let total: Int
        public let filename: String
        public var percent: Int { total > 0 ? read * 100 / total : 0 }
    }

    public static func read(
        directory: URL,
        sourceLabel: String,
        discsFromSubdirectories: Bool = false,
        numbersFromFilenames: Bool = false,
        reader: any MetadataReader = ChainedMetadataReader.standard(),
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> Record {
        // The pre-count that drives the meter uses the identical scan, so the
        // percentage cannot exceed 100 partway through (`player:1422`).
        let files = AudioFiles.scan(directory)
        guard !files.isEmpty else { throw Failure.noAudio(source: sourceLabel) }

        let discs = discsFromSubdirectories ? Record.discsByDirectory(of: files) : [:]

        var tracks: [Track] = []
        var album = ""
        var albumArtist = ""
        var year = ""
        var skipped = 0
        var seen = 0

        for url in files {
            let raw = await reader.read(url)
            seen += 1

            // A file nothing can read is skipped, not fatal. It still counts
            // towards the meter — see Progress.
            guard raw.isReadable else {
                skipped += 1
                continue
            }

            let folder = url.deletingLastPathComponent().standardizedFileURL.path
            tracks.append(
                Track(
                    url: url, raw: raw, discFallback: discs[folder] ?? 1,
                    numberFromFilename: numbersFromFilenames
                )
            )

            // Album, album artist and year come from the first file that
            // carries each, independently — a folder whose first track is
            // missing its album tag still gets an album off the second
            // (`player:1485`).
            if album.isEmpty { album = Track.flatten(raw.album) }
            if albumArtist.isEmpty {
                let candidate = Track.flatten(raw.albumArtist)
                albumArtist = candidate.isEmpty ? Track.flatten(raw.artist) : candidate
            }
            if year.isEmpty { year = Track.year(from: raw.date) }

            progress?(Progress(read: seen, total: files.count, filename: url.lastPathComponent))
        }

        guard !tracks.isEmpty else { throw Failure.noReadableAudio(source: sourceLabel) }

        if album.isEmpty { album = Record.albumFromSourceLabel(sourceLabel) }

        return Record(
            tracks: tracks,
            album: album,
            albumArtist: albumArtist,
            year: year,
            sourceLabel: sourceLabel,
            unreadableCount: skipped
        )
    }

    /// `ALBUM="${SRC_LABEL%.zip}"` (`player:1497`). The folder or zip's own
    /// name, which is nearly always the album — and for the untagged rips this
    /// is written for, it is the only name there is.
    ///
    /// The suffix comes off whatever case it is written in. The script matches
    /// it exactly while §1.1 accepts a source ending `.ZIP`, so a zip named in
    /// capitals puts `KMRU - Kin.ZIP` across the top of the panel where every
    /// other album shows its name — §18.16, resolved.
    public static func albumFromSourceLabel(_ label: String) -> String {
        label.lowercased().hasSuffix(".zip") ? String(label.dropLast(4)) : label
    }

    /// D12: where a zip's audio came out in more than one directory, those
    /// directories are the discs.
    ///
    /// Nothing is read off what a directory is *called* — that is guessing
    /// structure from a string, and `CD2`, `Disc Two` and `bonus` are all the
    /// same guess with different odds. What is read is the shape of the
    /// archive, which is a fact about it: audio in two folders was somebody
    /// telling you something no tag was going to.
    ///
    /// `files` arrives in scan order, so the first directory to appear is disc
    /// one. One directory produces an empty map and the ordinary literal `1`.
    ///
    /// The discs have to be *siblings* — §18.17. A folder holding a few loose
    /// files next to a subfolder is a stray and a wrapper, not disc one of two,
    /// and the two layouts are byte-for-byte the same archive. Declining to
    /// guess there is the same move as declining to read `CD2` as a number.
    static func discsByDirectory(of files: [URL]) -> [String: Int] {
        var folders: [String] = []
        var seen: Set<String> = []
        for file in files {
            let folder = file.deletingLastPathComponent().standardizedFileURL.path
            if seen.insert(folder).inserted { folders.append(folder) }
        }

        // A directory with audio *and* another audio directory under it is the
        // thing the discs are in, not one of them.
        let discs = folders.filter { folder in
            !folders.contains { $0 != folder && isAncestor(folder, of: $0) }
        }
        guard discs.count > 1, Set(discs.map(parent)).count == 1 else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: discs.enumerated().map { ($0.element, $0.offset + 1) }
        )
    }

    private static func isAncestor(_ path: String, of other: String) -> Bool {
        other.hasPrefix(path == "/" ? path : path + "/")
    }

    private static func parent(_ path: String) -> String {
        URL(fileURLWithPath: path).deletingLastPathComponent().standardizedFileURL.path
    }

    public init(
        tracks: [Track],
        album: String,
        albumArtist: String,
        year: String,
        sourceLabel: String,
        unreadableCount: Int = 0
    ) {
        self.tracks = tracks
        self.album = album
        self.albumArtist = albumArtist
        self.year = year
        self.sourceLabel = sourceLabel
        self.unreadableCount = unreadableCount
        self.order = []
        self.total = 0
        reorder()
    }

    // MARK: - Ordering

    /// Disc, then track number, then a natural filename sort — and the last of
    /// the three only ever separates files that agreed on both numbers
    /// (`player:1501`). Order comes from metadata, not filenames. Not
    /// negotiable, per `spec.md`.
    ///
    /// The script builds a tab-separated record with `%04d` disc and `%04d`
    /// track and hands it to `sort -k1,1n -k2,2n -k3,3V`. The padding is what
    /// makes that stable in bash; here the numbers are numbers and the padding
    /// has nothing left to do.
    public mutating func reorder() {
        order = Array(tracks.indices).sorted { lhs, rhs in
            let a = tracks[lhs], b = tracks[rhs]
            if a.disc != b.disc { return a.disc < b.disc }
            if a.number != b.number { return a.number < b.number }
            let byName = NaturalOrder.compare(
                a.url.lastPathComponent, b.url.lastPathComponent
            )
            if byName != .orderedSame { return byName == .orderedAscending }
            // Two files agreeing on disc, track *and* basename means the same
            // name in two directories. Scan order settles it, so that an album
            // read twice is in the same order twice; `sort` would fall through
            // to comparing the record as text and decide it on the digits of
            // the index.
            return lhs < rhs
        }
        total = order.reduce(0) { $0 + tracks[$1].duration }
    }

    // MARK: - Track numbers are not row numbers

    /// The **scan index** of the first file carrying this track number, or nil.
    ///
    /// This is `row_of_track` (`player:1521`) with its name corrected: the
    /// value is an index into `tracks`, not a position in `order`, and the
    /// script's callers were always using it as one. Everything §4 writes back
    /// — CD-Text titles, MusicBrainz titles — is written through this, because
    /// those sources answer in track numbers and the arrays are in scan order.
    ///
    /// First match wins. With a duplicate track number the incoming title lands
    /// on whichever of the two sorted first and the other keeps what it had —
    /// which is the script's behaviour and is better than refusing to label
    /// either (§3.1).
    public func fileIndex(ofTrackNumber number: Int) -> Int? {
        tracks.firstIndex { $0.number == number }
    }

    /// Where that file sits in the running order, for the one caller that
    /// genuinely wants a row: the track list on screen.
    public func row(ofTrackNumber number: Int) -> Int? {
        guard let index = fileIndex(ofTrackNumber: number) else { return nil }
        return order.firstIndex(of: index)
    }
}
