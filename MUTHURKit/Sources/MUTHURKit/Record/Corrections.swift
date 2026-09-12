import Foundation

/// **D85** — what you have told this program about a record, kept beside the
/// program rather than written into your files.
///
/// **Neither script has anything like this, and the reason it exists here is a
/// window.** `burncd`'s editor is a screen you pass through on the way to a
/// disc: the names it fixes are the names that go in that lead-in, the process
/// ends, and next time you fix them again. That is a fair bargain for a program
/// you run to burn one disc. It is not a fair bargain for an app you leave open,
/// where the same wrong year is in front of you every time you put the record
/// on — and where the editor is the only place in the program you can type.
///
/// **It corrects, it does not tag.** Nothing here is written into anybody's
/// files. `PlanEditor` promises that the plan screen does not touch the record
/// on disk and that promise is kept; what changes is that the promise no longer
/// costs you the correction. The two reasons not to write tags are worth
/// stating, because "just fix the tags" is the obvious objection:
///
/// - **A zip cannot be corrected in place at all.** Its audio is unpacked into
///   §2's scratch, which sweeps itself, so a tag written there is gone at the
///   next launch. Writing to the archive means rebuilding it, which is a
///   library-sized operation to change four characters.
/// - **The tag is frequently not wrong.** A rip tagged from MusicBrainz carries
///   `.releases[0].date` — *this pressing*, which for a reissue is honestly not
///   the year the record came out. `2001 - Drukqs` with `date=2017` is a 2017
///   pressing of a 2001 album, and both numbers are true. Overwriting one with
///   the other destroys a fact to display a different one; this keeps both and
///   says which to show.
///
/// **The file is plain and disposable.** Delete it and every record goes back to
/// what its tags say. That is the undo, and it is the reason nothing here is
/// allowed to fail loudly: a correction store that cannot be written is a
/// program that shows the tag's year, which is exactly where it started.
public struct Corrections: Sendable, Equatable {

    /// One record's corrections. Every field is optional because an absent
    /// correction and an empty one are different: nil means *nothing was said*,
    /// and `""` means *you cleared it on purpose*.
    public struct Entry: Codable, Sendable, Equatable {
        public var album: String?
        public var albumArtist: String?
        public var year: String?

        /// Track titles, keyed by the file's name within the record.
        ///
        /// **Not by position, and not by index.** A running order is the one
        /// thing the plan editor is built to rearrange, so a correction keyed on
        /// where a track sat would follow the wrong track the moment anything
        /// moved. The filename is what does not move — it is the same string
        /// whether the file is first or eleventh, and it is stable across the
        /// unpack of a zip, which an absolute path is not.
        public var titles: [String: String]

        /// Track artists, keyed the same way.
        ///
        /// **Separate from `albumArtist` because the editor treats them
        /// separately.** `A` on a header row sets the record's artist and on a
        /// track row sets that track's — `tui_artist`'s own rule, that the key
        /// means *the artist of the thing I am looking at* (`burncd:1285`). A
        /// compilation is the case that needs it, and a compilation is exactly
        /// the kind of record whose tags are wrong.
        public var artists: [String: String]

        public init(
            album: String? = nil, albumArtist: String? = nil, year: String? = nil,
            titles: [String: String] = [:], artists: [String: String] = [:]
        ) {
            self.album = album
            self.albumArtist = albumArtist
            self.year = year
            self.titles = titles
            self.artists = artists
        }

        public var isEmpty: Bool {
            album == nil && albumArtist == nil && year == nil
                && titles.isEmpty && artists.isEmpty
        }
    }

    private var entries: [String: Entry]
    private let url: URL?

    /// Where the file lives.
    ///
    /// `XDG_DATA_HOME` and not `XDG_CACHE_HOME`, which is the one thing about
    /// this path worth an argument. `LevelCache` is a cache in the true sense —
    /// throw it away and the program recomputes it, slowly. This cannot be
    /// recomputed by anything: it is the only copy of something a person typed,
    /// and a directory whose contract is *may be deleted at any time* is the
    /// wrong place for the only copy of anything.
    public static func location(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let base: URL
        if let xdg = environment["XDG_DATA_HOME"], !xdg.isEmpty {
            base = URL(fileURLWithPath: xdg)
        } else {
            base = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent(".local/share")
        }
        return base.appendingPathComponent("muthur/corrections.json")
    }

    /// Read what is there, if anything is, and if anything can be.
    ///
    /// A missing file is the ordinary case and not a failure — nobody has
    /// corrected anything yet. A corrupt one is discarded rather than repaired,
    /// on `LevelCache`'s reasoning: the alternative is a program that refuses to
    /// start over a file the user has never heard of.
    public init(at url: URL?) {
        self.url = url
        if let url, let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        {
            self.entries = decoded
        } else {
            self.entries = [:]
        }
    }

    /// How a record is recognised again next time.
    ///
    /// The source's own path, standardised — the zip or the folder you opened,
    /// which is the thing you would point at to play it again. **A disc has no
    /// such path**: `/Volumes/Audio CD` is a mount point that belongs to
    /// whatever is in the drive this minute, so keying on it would hand one
    /// disc's correction to the next disc you put in. Discs return nil and are
    /// not corrected — §4 already names them from CD-Text and MusicBrainz,
    /// which is a better answer than a note about the last disc that happened to
    /// mount at the same path.
    public static func key(source: URL?, kind: SourceKind) -> String? {
        guard kind != .disc, let source else { return nil }
        return source.standardizedFileURL.path
    }

    public func entry(for key: String?) -> Entry? {
        guard let key else { return nil }
        return entries[key]
    }

    /// Put a correction in, and take it out again when it agrees with what the
    /// tags already said.
    ///
    /// **A correction that matches the tag is deleted rather than stored.**
    /// Typing the year the file already carries is not a correction, and a store
    /// that accumulated those would slowly become a second copy of everyone's
    /// tags — and would go on asserting them after the tags themselves were
    /// fixed somewhere else.
    public mutating func set(
        _ field: Field, to value: String, was original: String, for key: String?
    ) {
        guard let key else { return }
        var entry = entries[key] ?? Entry()
        let agrees = value == original
        switch field {
        case .album: entry.album = agrees ? nil : value
        case .albumArtist: entry.albumArtist = agrees ? nil : value
        case .year: entry.year = agrees ? nil : value
        case .title(let file):
            if agrees {
                entry.titles.removeValue(forKey: file)
            } else {
                entry.titles[file] = value
            }
        case .artist(let file):
            if agrees {
                entry.artists.removeValue(forKey: file)
            } else {
                entry.artists[file] = value
            }
        }
        if entry.isEmpty {
            entries.removeValue(forKey: key)
        } else {
            entries[key] = entry
        }
    }

    public enum Field: Sendable, Equatable {
        case album
        case albumArtist
        case year
        /// Keyed by the track's filename — see `Entry.titles`.
        case title(file: String)
        /// One track's artist, keyed the same way. **Not `albumArtist`**: `A` on
        /// a track row is about that track, and conflating the two would let a
        /// compilation's per-track correction quietly overwrite the record's.
        case artist(file: String)
    }

    /// Write it out, and say nothing if it cannot be written.
    ///
    /// A read-only home, a sandbox, odd permissions: all of them mean the
    /// correction lasts as long as this session, which is what the program did
    /// before this file existed. It is not worth a sentence on a panel, and
    /// there is nothing the person reading it could do.
    public func save() {
        guard let url else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Whether anything is known about this record. The panel uses it to say so
    /// — a corrected record that looked identical to an uncorrected one would be
    /// a program quietly disagreeing with your files.
    public func corrects(_ key: String?) -> Bool {
        guard let key else { return false }
        return entries[key]?.isEmpty == false
    }
}

extension Record {

    /// Apply what the user has said about this record.
    ///
    /// **Applied to the `Record` and not to the panel**, which is the whole
    /// design in one line: everything downstream — the faceplate, the plan
    /// draft, the CD-Text that goes into a lead-in, the `REM DATE` in the cue —
    /// reads the record, so correcting it once is correcting all of them. A
    /// correction that only reached the header would put 2001 on the panel and
    /// burn 2017 onto the disc, which is worse than not having one.
    public mutating func correct(with entry: Corrections.Entry?) {
        guard let entry else { return }
        if let album = entry.album { self.album = album }
        if let albumArtist = entry.albumArtist { self.albumArtist = albumArtist }
        if let year = entry.year { self.year = year }
        guard !entry.titles.isEmpty || !entry.artists.isEmpty else { return }
        for index in tracks.indices {
            let file = tracks[index].url.lastPathComponent
            if let title = entry.titles[file] { tracks[index].title = title }
            if let artist = entry.artists[file] { tracks[index].artist = artist }
        }
    }
}
