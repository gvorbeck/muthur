import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A record's sleeve for the library, found once and kept. **D91.**
///
/// **§5's order, unchanged, and §5's resolver doing the work** — beside the
/// record, then the tags, then the Cover Art Archive. A library that preferred
/// a different picture from the one the panel draws when the record is playing
/// would show you one cover to choose it by and another once it was on.
///
/// Two things differ, and both follow from nobody waiting for the answer:
///
/// - **The archive is awaited.** §5 forbids the panel from joining the fetch
///   because a record is playing while it runs. Here nothing is playing on its
///   account; the walk is the only thing waiting and it has nothing better to
///   do.
/// - **A zip is not unpacked to be asked.** The panel's zip has already been
///   unpacked into §2's scratch by the time its sleeve is looked for, so §5
///   finds a picture beside the record like any folder's. The library's has
///   not, and unpacking a whole album to look at its cover is a thing nobody
///   would do by hand. So the pictures in the central directory are ranked by
///   §5.1's names and only those are taken out; failing that, the first track,
///   for its tags.
///
/// **What is kept is a copy, cut down.** `side` on its longest edge, JPEG. A
/// 3000-pixel scan is the right thing beside a playing record and several
/// megabytes too many for a tile, and the original is still where it was
/// found.
public struct LibraryCovers: Sendable {

    public var resolver: SleeveResolver
    public var metadata: any MetadataReader
    /// Where zip members and tag pictures are written while they are looked at.
    /// Emptied after each record.
    public var work: URL

    /// Twice a tile at its largest, so the true-colour reveal is not soft.
    public static let side = 600

    public init(
        resolver: SleeveResolver = SleeveResolver(),
        metadata: any MetadataReader = ChainedMetadataReader.standard(),
        work: URL
    ) {
        self.resolver = resolver
        self.metadata = metadata
        self.work = work
    }

    /// What was learned about one record.
    public struct Outcome: Sendable, Equatable {
        /// Where the sleeve came from, or nil if none was stored.
        public var source: Sleeve.Source?
        /// The tags' names, where the tags had any.
        public var title: String?
        public var artist: String?
        /// Whether the archive was asked — so the walk can leave MusicBrainz
        /// its second between requests (`ReleaseSearch`).
        public var askedTheArchive: Bool

        public init(source: Sleeve.Source? = nil, title: String? = nil, artist: String? = nil, askedTheArchive: Bool = false) {
            self.source = source
            self.title = title
            self.artist = artist
            self.askedTheArchive = askedTheArchive
        }
    }

    /// Find the record's sleeve and write it to `destination`.
    public func find(_ album: Library.Album, at url: URL, storingAt destination: URL) async -> Outcome {
        let scratch = work.appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        switch album.kind {
        case .folder:
            let files = Array(AudioFiles.scan(url).prefix(3))
            return await resolve(
                album, directory: url, files: files, scratch: scratch, destination: destination)
        case .zip:
            guard let archive = try? ZipArchive(url: url) else { return Outcome() }
            // The head of the first track, for its tags and for a picture in
            // them. Read before the pictures inside are looked at, because the
            // names are wanted either way: a zip is named `Briva - Briva - Nite
            // Callane` on disk far more often than a folder is.
            let track = firstTrack(of: archive, scratch: scratch)
            if let picture = pictureInside(archive, scratch: scratch),
                store(picture, to: destination)
            {
                var outcome = await names(track.map { [$0] } ?? [])
                outcome.source = .besideTheRecord
                return outcome
            }
            return await resolve(
                album, directory: nil, files: track.map { [$0] } ?? [], scratch: scratch,
                destination: destination)
        }
    }

    // MARK: - §5, asked

    private func resolve(
        _ album: Library.Album, directory: URL?, files: [URL], scratch: URL, destination: URL
    ) async -> Outcome {
        var outcome = await names(files)
        let request = SleeveResolver.Request(
            directory: directory,
            files: files,
            album: outcome.title ?? album.title,
            albumArtist: outcome.artist ?? album.artist,
            scratch: scratch.appending(path: "tags")
        )
        let resolution = await resolver.resolve(request)
        var sleeve = resolution.sleeve
        if sleeve == nil, let pending = resolution.pending {
            outcome.askedTheArchive = true
            sleeve = await pending.value
        }
        if let sleeve, store(sleeve.url, to: destination) {
            outcome.source = sleeve.source
        }
        return outcome
    }

    /// `Record.read`'s rule for the record's names, asked of the first track:
    /// the album tag, and the album artist falling back to the artist.
    private func names(_ files: [URL]) async -> Outcome {
        var outcome = Outcome()
        guard let first = files.first else { return outcome }
        let raw = await metadata.read(first)
        let title = Track.flatten(raw.album)
        let albumArtist = Track.flatten(raw.albumArtist)
        let artist = albumArtist.isEmpty ? Track.flatten(raw.artist) : albumArtist
        if !title.isEmpty { outcome.title = title }
        if !artist.isEmpty { outcome.artist = artist }
        return outcome
    }

    // MARK: - Inside a zip

    /// §5.1's ranking over member names, and the probe's floor over the bytes
    /// of each candidate in turn — the same two steps `BesideTheRecord.find`
    /// takes on a folder, with an extraction in between.
    func pictureInside(_ archive: ZipArchive, scratch: URL) -> URL? {
        let pictures = archive.files.filter { entry in
            let parts = entry.name.split(separator: "/")
            // `__MACOSX/` is where the `._` stubs live in an archive a Mac made,
            // and every one of them has a picture's extension if its original
            // did.
            guard !parts.contains(where: { $0.hasPrefix(".") || $0 == "__MACOSX" }),
                parts.count <= BesideTheRecord.maximumDepth, entry.isSupported, !entry.isEncrypted
            else { return false }
            return BesideTheRecord.extensions.contains(
                (entry.name as NSString).pathExtension.lowercased())
        }
        let byName = Dictionary(pictures.map { ("/" + $0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let ranked = BesideTheRecord.ranked(byName.keys.map { URL(fileURLWithPath: $0) })
        for (index, candidate) in ranked.enumerated() {
            guard let entry = byName[candidate.path] else { continue }
            let out = scratch.appending(path: "picture-\(index).\(candidate.pathExtension)")
            guard extract(entry, from: archive, to: out) else { continue }
            if resolver.probe.isPicture(out, minimumSide: BesideTheRecord.minimumSide) { return out }
        }
        return nil
    }

    /// How much of the first track is taken out. Tags and the picture in them
    /// come first in a FLAC and an MP3, and a whole lossless track off a USB
    /// drive is several seconds per record for bytes nobody will hear. An
    /// `m4a` that keeps its `moov` at the end loses its tags to this, and gets
    /// the path's name and the archive's sleeve, which is what it would have
    /// had untagged.
    static let head = 8 * 1024 * 1024

    /// The track that plays first, near enough: byte order over the names,
    /// which is `AudioFiles.scan`'s order after an unpack. Only its tags and
    /// its picture are wanted, and a record is tagged alike on every track.
    func firstTrack(of archive: ZipArchive, scratch: URL) -> URL? {
        let tracks = archive.files
            .filter { ZipArchive.isAudioMember($0.name) && $0.isSupported && !$0.isEncrypted }
            .sorted { AudioFiles.byteOrder($0.name, $1.name) == .orderedAscending }
        guard let entry = tracks.first else { return nil }
        let ext = (entry.name as NSString).pathExtension
        let out = scratch.appending(path: "track.\(ext)")
        return extract(entry, from: archive, to: out, limit: LibraryCovers.head) ? out : nil
    }

    private struct Enough: Error {}

    /// One member out, whole or up to `limit` bytes. Stopping early is not a
    /// failure, and the CRC that would have caught a short read is not asked,
    /// because nobody claimed these were all the bytes.
    private func extract(
        _ entry: ZipArchive.Entry, from archive: ZipArchive, to out: URL, limit: Int = .max
    ) -> Bool {
        do {
            let file = try ZipFile(url: archive.url)
            defer { file.close() }
            guard FileManager.default.createFile(atPath: out.path, contents: nil) else { return false }
            let handle = try FileHandle(forWritingTo: out)
            defer { try? handle.close() }
            var written = 0
            do {
                try archive.extract(entry, from: file) { buffer in
                    try handle.write(contentsOf: Data(buffer))
                    written += buffer.count
                    if written >= limit { throw Enough() }
                }
            } catch is Enough {}
            return true
        } catch {
            try? FileManager.default.removeItem(at: out)
            return false
        }
    }

    // MARK: - Keeping it

    /// Cut down to `side` and written as JPEG, atomically. The orientation a
    /// camera phone's photo of a sleeve carries is applied on the way, since a
    /// JPEG out of `CGImageDestination` has nowhere to keep it.
    func store(_ picture: URL, to destination: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(picture as CFURL, nil) else { return false }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: LibraryCovers.side,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return false
        }
        try? FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let part = destination.appendingPathExtension("part")
        guard
            let out = CGImageDestinationCreateWithURL(part as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { return false }
        CGImageDestinationAddImage(out, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(out) else {
            try? FileManager.default.removeItem(at: part)
            return false
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: part, to: destination)
            return true
        } catch {
            try? FileManager.default.removeItem(at: part)
            return false
        }
    }
}

extension Library.Album {
    /// A sleeve search's answer, written onto the record.
    public mutating func apply(_ outcome: LibraryCovers.Outcome, coverName: String) {
        coverAsked = true
        if let title = outcome.title { self.title = title }
        if let artist = outcome.artist { self.artist = artist }
        if let source = outcome.source {
            cover = coverName
            coverSource = source
        }
    }
}
