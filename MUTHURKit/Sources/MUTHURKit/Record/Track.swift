import Foundation

/// One row of the record, after §3's rules have been applied to what came off
/// the file.
///
/// `title` and `artist` are `var` because §4 overwrites them: CD-Text and
/// MusicBrainz answer in track numbers and write back into rows that already
/// exist. Everything the running order is computed from is `let` — once the
/// order is decided, nothing may move underneath it.
public struct Track: Sendable, Equatable {
    public let url: URL
    /// Seconds, rounded **up**. Never down: a track that ends before the meter
    /// says it does looks like a skip (`player:1478`).
    public let duration: Int
    public var title: String
    public var artist: String
    /// `Track.noNumber` when the file did not say. Not an optional, because it
    /// is a sort key first and a fact about the file second, and every place
    /// that reads it wants the sort key.
    public let number: Int
    public let disc: Int

    /// 9999 — the sort key for a file with no usable track tag. Tagged files
    /// are unaffected by it, because it sorts after every real track number,
    /// so one untagged bonus track cannot displace an album that is otherwise
    /// correctly tagged (`player:1451`).
    public static let noNumber = 9999

    /// Whether the number above was read off the file or invented.
    public var isNumbered: Bool { number != Track.noNumber }

    public init(
        url: URL, duration: Int, title: String, artist: String, number: Int, disc: Int
    ) {
        self.url = url
        self.duration = duration
        self.title = title
        self.artist = artist
        self.number = number
        self.disc = disc
    }

    /// Apply §3 to one read. Everything here is testable without a file, and
    /// the degenerate cases are the whole point of it being separable.
    ///
    /// `discFallback` is what a file with no disc tag gets. The script has a
    /// literal `1` there (`player:1452`); D12 lets a zip pass the ordinal of the
    /// directory the file came out of instead. It is a *fallback* and not an
    /// override — a tag always wins over the directory it sits in.
    public init(url: URL, raw: RawMetadata, discFallback: Int = 1) {
        self.url = url
        self.duration = Track.roundedUp(raw.duration ?? 0)
        self.number = Track.number(from: raw.track) ?? Track.noNumber
        self.disc = Track.number(from: raw.disc) ?? discFallback
        // `${title:-$(basename "$f")}` — the basename *with* its extension,
        // which is what the script falls back to and what you would rather see
        // than a blank row (`player:1481`).
        let flatTitle = Track.flatten(raw.title)
        self.title = flatTitle.isEmpty ? url.lastPathComponent : flatTitle
        self.artist = Track.flatten(raw.artist)
    }

    // MARK: - The rules

    /// `trk="${trk%%/*}"`, then base ten.
    ///
    /// Tags are routinely `3/12`; keep the part before the slash. The base is
    /// stated because bash reads a leading zero as octal and rejects `08` and
    /// `09` outright, and taggers write `08` (`player:1447`). Swift does not
    /// have that problem, but the rule is the same rule and belongs where it
    /// can be seen.
    ///
    /// Nil means "the file did not say", and the caller decides what that is
    /// worth — 9999 for a track, 1 for a disc.
    public static func number(from tag: String?) -> Int? {
        guard let tag else { return nil }
        let head = tag.prefix { $0 != "/" }
        guard !head.isEmpty, head.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        // A tag of forty digits is not a track number. Refusing it is the same
        // answer as refusing `A3`, and for the same reason.
        return Int(head)
    }

    /// A tab or a newline inside a tag is rare and entirely possible, and it
    /// breaks two things at once: a newline bends the frame the panel works to
    /// keep square, and a tab is the separator every record in the resume file
    /// is split on. Flattened once, on the way in (`player:1468`).
    public static func flatten(_ text: String?) -> String {
        guard let text else { return "" }
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text.unicodeScalars {
            out.unicodeScalars.append(ch == "\t" || ch == "\n" || ch == "\r" ? " " : ch)
        }
        return out
    }

    /// Round up, never down (`player:1478`). A duration that is already whole
    /// stays whole — the script's `d == int(d) ? d : int(d) + 1` is a ceiling,
    /// written out longhand because awk has no `ceil`.
    public static func roundedUp(_ seconds: Double) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int(seconds.rounded(.up))
    }

    /// The year is the only part of a date anyone labels a record with, and
    /// tags carry full ISO stamps: `1977-02-04T08:00:00Z` is a year
    /// (`player:1488`).
    public static func year(from date: String?) -> String {
        guard let date else { return "" }
        return String(date.prefix { $0 != "-" })
    }
}
