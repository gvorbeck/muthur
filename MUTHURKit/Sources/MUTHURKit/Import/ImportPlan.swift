import Foundation

/// §21 — every file an import is going to write, worked out before it writes
/// one.
///
/// The shape is `BurnPlan`'s and the reason is `BurnPlan`'s: a job that decides
/// where a track goes *while* it is converting it is a job that discovers the
/// volume is full, or the name is taken, at track eleven — with ten files
/// already on somebody's disk and nothing to say about them. Everything that
/// can be decided without decoding a second of audio is decided here, and what
/// is left is a list of ffmpeg invocations that cannot surprise anybody.
public struct ImportPlan: Sendable, Equatable {

    /// One track, from where it is to where it is going.
    public struct Entry: Sendable, Equatable {
        /// The file on the mounted disc — `1 Audio Track.aiff` and its
        /// thirteen siblings.
        public let source: URL
        /// Where it lands. Already made vacant against the filesystem as it
        /// stood when the plan was built.
        public let destination: URL
        /// What goes in the `track` tag, and what the filename is numbered
        /// with. See `ImportPlan.number(for:)` — it is not always the track's
        /// own.
        public let number: Int
        public let title: String
        public let artist: String
        public let duration: Int

        public init(
            source: URL, destination: URL, number: Int,
            title: String, artist: String, duration: Int
        ) {
            self.source = source
            self.destination = destination
            self.number = number
            self.title = title
            self.artist = artist
            self.duration = duration
        }
    }

    public let entries: [Entry]
    /// The directory the tracks go in. The record's own folder when one is
    /// being made (D96), and the chosen directory itself when not.
    public let folder: URL
    /// Whether `folder` is ours to delete if the job is called off. False when
    /// the user chose to write straight into a directory that was already
    /// there, and a cancel then takes the files it wrote and nothing else.
    public let folderIsOurs: Bool
    public let format: ImportFormat
    public let album: String
    public let albumArtist: String
    public let year: String
    /// The rules these names were made under (**D98**). Kept so the screen can
    /// say when it has had to change any, rather than doing it silently.
    public let naming: ImportNames.Policy
    /// How many names this policy altered that `.native` would have left
    /// alone. Nought under `.native`, and nought on a portable volume whose
    /// record happens to contain nothing Windows objects to — which is most
    /// records, which is why the note is only printed when this is not nought.
    public let renamed: Int

    /// The disc's running time — the denominator the bar is drawn against.
    public var runtime: Int { entries.reduce(0) { $0 + $1.duration } }

    public var durations: [Int] { entries.map(\.duration) }

    public enum Failure: Error, Equatable, CustomStringConvertible {
        /// The record has no tracks in it. Cannot happen off a disc that
        /// opened, and is not assumed not to.
        case nothingToImport
        /// A name could not be made vacant — 999 folders of the same album, or
        /// a filesystem answering that everything exists.
        case noVacantName(String)
        /// The destination could not be made or written to. Carries what the
        /// filesystem said, because "permission denied" and "read-only volume"
        /// are different problems with different answers.
        case cannotWrite(path: String, reason: String)
        /// Not enough room, measured before anything is decoded.
        case noRoom(need: Int, have: Int, path: String)

        public var description: String {
            switch self {
            case .nothingToImport:
                "there are no tracks on this disc to import"
            case .noVacantName(let name):
                "could not find a free name for \(name)"
            case .cannotWrite(let path, let reason):
                "cannot write to \(path) — \(reason)"
            case .noRoom(let need, let have, let path):
                """
                this import needs about \(TempSpace.human(need)), only \
                \(TempSpace.human(have)) free
                  on \(path). Free some space or choose another volume.
                """
            }
        }
    }

    // MARK: - Building one

    /// Lay the record out under `destination`.
    ///
    /// **Nothing is created here** — not the folder, not a file. The plan is a
    /// description, and a description that left a directory behind when it was
    /// refused would be a side effect nobody asked for. `ImportJob` makes the
    /// folder as its first act, having been handed the plan.
    ///
    /// That is also why `exists` is injected: the whole of this is testable
    /// against a filesystem that is not there, which is the only way the
    /// collision arithmetic ever gets exercised against 999 of anything.
    public static func make(
        record: Record,
        destination: URL,
        format: ImportFormat,
        folderStyle: ImportNames.FolderStyle = .album,
        trackStyle: ImportNames.TrackStyle = .dash,
        naming: ImportNames.Policy? = nil,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) throws -> ImportPlan {
        let running = record.running
        guard !running.isEmpty else { throw Failure.nothingToImport }

        // **Asked once, here, because here is where the destination is known**
        // (D98). Every name below is made under the same policy, so a record
        // cannot end up with a folder written to one rule and its tracks to
        // another. `nil` means ask the volume; the suite passes one outright.
        let policy = naming ?? Volume.naming(for: destination)

        var folder = destination
        var ours = false
        if folderStyle != .none {
            let name = ImportNames.recordFolder(
                album: record.album, albumArtist: record.albumArtist, style: folderStyle,
                policy: policy)
            guard let vacant = ImportNames.vacant(name, in: destination, exists: exists) else {
                throw Failure.noVacantName(name)
            }
            folder = vacant
            ours = true
        }

        // Counted here rather than inferred later, because here is the only
        // place that still has both the title and the two answers to it. The
        // `(2)` dedup below would make the comparison a guess afterwards.
        var renamed = 0
        func countingRename(_ text: String) {
            guard policy != .native, !text.isEmpty else { return }
            if ImportNames.component(text, policy: policy)
                != ImportNames.component(text, policy: .native)
            {
                renamed += 1
            }
        }
        countingRename(record.album)
        countingRename(record.albumArtist)

        var entries: [Entry] = []
        // Names are checked against the filesystem *and* against each other.
        // Two tracks on one disc can genuinely share a title — a reprise, a
        // hidden track, an untitled disc where §4.1 gave every row the same
        // name — and the second one must not be planned onto the first. The
        // number leading every filename makes that rare; rare is not never.
        var taken: Set<String> = []
        let occupied: (URL) -> Bool = { url in
            taken.contains(url.path) || (ours ? false : exists(url))
        }

        for (index, track) in running.enumerated() {
            let number = ImportPlan.number(for: track, at: index)
            countingRename(track.title)
            let name = ImportNames.trackFile(
                number: number, title: track.title, format: format, style: trackStyle,
                policy: policy)
            guard let url = ImportNames.vacant(name, in: folder, exists: occupied) else {
                throw Failure.noVacantName(name)
            }
            taken.insert(url.path)
            entries.append(
                Entry(
                    source: track.url, destination: url, number: number,
                    title: track.title, artist: track.artist, duration: track.duration))
        }

        return ImportPlan(
            entries: entries, folder: folder, folderIsOurs: ours, format: format,
            album: record.album, albumArtist: record.albumArtist, year: record.year,
            naming: policy, renamed: renamed)
    }

    /// The number this track is written as.
    ///
    /// **Its own where it has one, and its place in the running order where it
    /// does not.** `Track.noNumber` is 9999 — a sort key and not a fact — and a
    /// file called `9999 Untitled.flac` is the sort key escaping onto somebody's
    /// disk, which is the one thing §3 is careful never to let happen on the
    /// panel either.
    ///
    /// Off a CD this almost never fires: §3's `numberFromFilename` already
    /// reads the number out of `7 Audio Track.aiff`, because macOS put it
    /// there. It fires for a disc whose files macOS named some other way, and
    /// for the folder and zip sources this same import path serves.
    static func number(for track: Track, at index: Int) -> Int {
        track.isNumbered ? track.number : index + 1
    }

    // MARK: - Room

    /// Roughly how many bytes this will take, by format.
    ///
    /// Deliberately an over-estimate in every case, because the number is only
    /// ever used to refuse a job, and refusing one that would have fitted is a
    /// smaller failure than filling somebody's disk. The two uncompressed
    /// formats are exact — CD audio is 176,400 bytes a second and a container
    /// header is a rounding error — and the rest are the high end of what this
    /// material actually compresses to.
    ///
    /// FLAC at level 8 on pop music lands near 55%; 70 is used. ALAC is a
    /// little worse than FLAC and gets the same allowance. MP3 V0 averages
    /// about 245 kbps and Opus is told to use 128.
    public static func bytes(seconds: Int, format: ImportFormat) -> Int {
        let pcm = seconds * BurnLimits.bytesPerSecond
        return switch format {
        case .aiff, .wav: pcm + 4096
        case .flac, .alac: pcm * 70 / 100
        case .mp3: seconds * 32_000
        case .opus: seconds * 18_000
        }
    }

    /// Refuse now rather than at track eleven.
    ///
    /// `TempSpace.free`'s reasoning applies unchanged, including the part that
    /// matters most: a volume that will not say how much room it has is not
    /// refused. The check is a courtesy and the write is the authority.
    public func checkRoom(in directory: URL) throws {
        let need = ImportPlan.bytes(seconds: runtime, format: format) + TempSpace.margin
        guard let have = TempSpace.free(at: directory) else { return }
        guard have >= need else {
            throw Failure.noRoom(need: need, have: have, path: directory.path)
        }
    }

    public init(
        entries: [Entry], folder: URL, folderIsOurs: Bool, format: ImportFormat,
        album: String, albumArtist: String, year: String,
        naming: ImportNames.Policy = .native,
        renamed: Int = 0
    ) {
        self.naming = naming
        self.renamed = renamed
        self.entries = entries
        self.folder = folder
        self.folderIsOurs = folderIsOurs
        self.format = format
        self.album = album
        self.albumArtist = albumArtist
        self.year = year
    }
}
