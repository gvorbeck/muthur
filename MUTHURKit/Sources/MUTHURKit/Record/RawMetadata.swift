import Foundation

/// What one read of one file comes back with, before any of §3's rules have
/// been applied to it.
///
/// These are the eight things the script asks ffprobe for and nothing else
/// (`player:1439`) — one read per file, because a folder of two hundred
/// lossless tracks is two hundred file opens either way and the loading meter
/// has to move while it happens.
///
/// Deliberately all strings: `3/12`, `08` and `1979-05-25T00:00:00Z` are all
/// things a real tagger writes, and the rules that turn them into numbers are
/// in `Track`, where they can be tested without a file on disk.
public struct RawMetadata: Sendable, Equatable {
    /// Seconds, as read. Nil means the file could not be read at all — which is
    /// the one condition that makes a file get skipped.
    public var duration: Double?
    public var track: String?
    public var disc: String?
    public var title: String?
    public var album: String?
    public var artist: String?
    public var albumArtist: String?
    public var date: String?

    public init(
        duration: Double? = nil,
        track: String? = nil,
        disc: String? = nil,
        title: String? = nil,
        album: String? = nil,
        artist: String? = nil,
        albumArtist: String? = nil,
        date: String? = nil
    ) {
        self.duration = duration
        self.track = track
        self.disc = disc
        self.title = title
        self.album = album
        self.artist = artist
        self.albumArtist = albumArtist
        self.date = date
    }

    /// Whether this read is worth keeping. A file with no duration is skipped,
    /// not fatal: it is one bad track in a zip, and eleven good ones are still
    /// an album worth playing (`player:1443`).
    public var isReadable: Bool {
        guard let duration else { return false }
        return duration.isFinite && duration >= 0
    }
}
