import Foundation

/// §20.3 — what will actually be written into one disc's lead-in.
///
/// `write_cue` (`burncd:2141`) and the ladder that drives it (`burncd:2554`),
/// minus the cue sheet itself. The cue's `FILE` line names the converted image
/// and its `INDEX` lines are MSF offsets into it, and neither of those exists
/// until stage 2 has converted anything — so what is settled here is the part
/// that is decided before the conversion and does not depend on it: which
/// fields survive, what they read after transliteration, what they cost, and
/// what the operator is told about the difference. Stage 2 serialises this into
/// a cue sheet; it does not get to make any of these choices again.
public struct DiscText: Sendable, Equatable {

    /// A rough byte ceiling for the CD-Text packs in the lead-in
    /// (`burncd:125`).
    ///
    /// Rough because the true figure depends on the drive, and the failure mode
    /// does not deserve precision: a drive handed more lead-in than fits
    /// rejects the whole burn, so the number to aim at is a safe one rather
    /// than an exact one.
    public static let budget = 3800

    /// The rungs, in the order they are given up (`burncd:2130`).
    ///
    /// A disc that arrives with fewer of its names on it beats one the drive
    /// refuses to write, and the order is that of least loss first: the
    /// per-track artists are the field a listener is least likely to miss on a
    /// single-artist album, and the disc's own title and artist are the last
    /// thing standing before there is nothing.
    public enum Shed: Int, Sendable, Comparable, CaseIterable {
        /// Everything.
        case full = 0
        /// No per-track artists.
        case noTrackArtists = 1
        /// Track titles cut to 60 characters.
        case titlesTo60 = 2
        /// Cut again, to 30.
        case titlesTo30 = 3
        /// No track titles — the disc's own title and artist only.
        case noTrackTitles = 4
        /// No CD-Text at all.
        case none = 5

        public static func < (a: Shed, b: Shed) -> Bool { a.rawValue < b.rawValue }

        /// How long a track title may be at this rung.
        var titleLimit: Int {
            switch self {
            case .titlesTo30: 30
            case .titlesTo60, .noTrackTitles, .none: 60
            case .full, .noTrackArtists: 120
            }
        }

        /// What the operator is told, in the script's words (`burncd:2568`).
        /// `nil` at the top rung, where nothing was given up and there is
        /// nothing to say.
        func announcement(disc: Int) -> String? {
            switch self {
            case .full: nil
            case .noTrackArtists:
                "CD-Text too large for the lead-in; dropped the per-track artists"
            case .titlesTo60:
                "CD-Text too large for the lead-in; shortened the track titles"
            case .titlesTo30:
                "CD-Text too large for the lead-in; cut the track titles again"
            case .noTrackTitles:
                "CD-Text too large for the lead-in; dropped the track titles"
            case .none:
                "CD-Text will not fit the lead-in; writing disc \(disc) without it"
            }
        }
    }

    /// One track's names, after conversion. Either may be empty, which means
    /// nothing survived — a title written entirely in an alphabet the disc has
    /// no room for. An empty field is left out rather than written as an empty
    /// string: the player shows the same nothing either way, and the cue sheet
    /// stays honest about what it carries.
    public struct TrackText: Sendable, Equatable {
        public let title: String
        public let artist: String
    }

    public let disc: Int
    public let level: Shed
    /// `REM DATE`. A cue comment, not CD-Text — the format has no year field —
    /// so it costs nothing against the budget and survives every rung.
    /// Some rippers and players read it; a CD player's display never will.
    public let date: String
    public let discTitle: String
    public let discArtist: String
    public let tracks: [TrackText]
    /// What the surviving fields cost in the lead-in.
    public let bytes: Int
    /// How many fields do not read the way the tag did.
    public let approximatedCount: Int

    /// Everything to say about this disc's names, in the order it is said.
    ///
    /// Kept inside the panel's 69 columns like every other line of it
    /// (`burncd:2576`): `note` prints what it is given, and a line too long for
    /// the frame wraps, which costs the frame a row it did not budget for and
    /// scrolls its top away.
    public var notes: [String] {
        var out: [String] = []
        if let announcement = level.announcement(disc: disc) { out.append(announcement) }
        if approximatedCount > 0 {
            out.append(
                "CD-Text: \(approximatedCount) field(s) approximated into the disc's ISO-8859-1"
            )
        }
        return out
    }

    /// Whether the burn will carry CD-Text at all — `CDTEXT_THIS`
    /// (`burncd:2559`), which is the flag the burn reads and is turned off by
    /// the bottom rung rather than by the operator.
    public var writesCDText: Bool { level != .none }

    // MARK: - Building it

    /// Shed a rung at a time, measuring again after each, and stop at the first
    /// one that fits (`burncd:2563`).
    ///
    /// The measurement is redone from scratch at every rung rather than
    /// subtracted from the last, because the rungs are not independent: cutting
    /// titles to 60 characters changes how many packs each one takes, and a
    /// pack is 12 bytes wide, so the saving is not the number of characters
    /// removed.
    public static func make(
        disc: Int,
        entries: [BurnPlan.Entry],
        album: String,
        albumArtist: String,
        year: String,
        enabled: Bool = true
    ) -> DiscText {
        guard enabled else {
            return at(.none, disc: disc, entries: entries, album: album,
                      albumArtist: albumArtist, year: year)
        }

        var candidate = at(.full, disc: disc, entries: entries, album: album,
                           albumArtist: albumArtist, year: year)
        var level = Shed.full
        while candidate.bytes > budget, level < .none {
            level = Shed(rawValue: level.rawValue + 1) ?? .none
            candidate = at(level, disc: disc, entries: entries, album: album,
                           albumArtist: albumArtist, year: year)
        }
        return candidate
    }

    /// `write_cue <level>` — the field selection at one rung.
    static func at(
        _ level: Shed,
        disc: Int,
        entries: [BurnPlan.Entry],
        album: String,
        albumArtist: String,
        year: String
    ) -> DiscText {
        var bytes = 0
        var approximated = 0

        /// Convert, count the approximation, and — where asked — charge it to
        /// the lead-in. The date is converted and not charged, which is the
        /// whole difference between a cue comment and CD-Text.
        func take(_ raw: String, max: Int = 120, charged: Bool) -> String {
            guard !raw.isEmpty else { return "" }
            let field = CueText.convert(raw, max: max)
            if field.approximated { approximated += 1 }
            if charged { bytes += CueText.packBytes(field.text) }
            return field.text
        }

        let text = level != .none
        let date = take(year, charged: false)
        let discArtist = text ? take(albumArtist, charged: true) : ""
        let discTitle = text ? take(album, charged: true) : ""

        let tracks = entries.map { entry -> TrackText in
            guard text, level < .noTrackTitles else { return TrackText(title: "", artist: "") }
            let title = take(entry.title, max: level.titleLimit, charged: true)
            let artist = level < .noTrackArtists ? take(entry.artist, charged: true) : ""
            return TrackText(title: title, artist: artist)
        }

        return DiscText(
            disc: disc, level: level, date: date, discTitle: discTitle,
            discArtist: discArtist, tracks: tracks, bytes: bytes,
            approximatedCount: approximated
        )
    }
}
