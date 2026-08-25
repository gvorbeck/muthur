import Foundation

/// §10 — what the album is, in labelled lines under the faceplate
/// (`player:2325`).
///
/// `ALBUM`, `ARTIST`, `SOURCE`, and then `SHELF` and `NOTE` when the record is
/// on the shelf. The note is the half you wrote down yourself and the only line
/// here you cannot get from any other player, which is why it is the one that
/// gets the amber.
///
/// The metadata source is **not** a line here. The faceplate says where the
/// titles came from; saying it twice on one screen reads like two different
/// facts.
public struct HeaderBlock: Sendable, Equatable {

    public struct Row: Sendable, Equatable {
        public let label: String
        public let value: String
        /// Whether the value is the record's own writing rather than the
        /// record's metadata — which is what the amber marks here.
        public let annotated: Bool

        public init(label: String, value: String, annotated: Bool = false) {
            self.label = label
            self.value = value
            self.annotated = annotated
        }
    }

    public let rows: [Row]

    /// The label column, `%-8s` in the script.
    public static let labelWidth = 8

    /// Nothing at all is an em dash rather than a blank, so an empty line still
    /// reads as a line with nothing in it rather than as a line that failed to
    /// print (`player:2325`).
    static func orDash(_ text: String) -> String { text.isEmpty ? "—" : text }

    /// **D6 — the year is on the panel.** One year, from the first source that
    /// has one: tags, then the MusicBrainz release date, then the collection.
    ///
    /// In bash the year appeared only in `-n` (`player:3542`), while the
    /// panel's `SHELF` line carried the *collection's* year (`player:2333`) —
    /// so a record not in the collection showed no year anywhere, and one that
    /// was in it showed a year that had not come from the record. Here it is
    /// set after the artist as `(1979)`, the same shape `-n` prints, and
    /// `SHELF` stops carrying it: where the two disagree, that disagreement is
    /// not worth two lines on a faceplate.
    public static func year(tags: String, musicBrainz: String? = nil, collection: String? = nil)
        -> String
    {
        for candidate in [tags, musicBrainz ?? "", collection ?? ""] where !candidate.isEmpty {
            return candidate
        }
        return ""
    }

    /// `Miles Davis (1959)`, or just the artist where nothing had a year.
    public static func artistLine(_ artist: String, year: String) -> String {
        let name = orDash(artist)
        return year.isEmpty ? name : "\(name) (\(year))"
    }

    /// What the collection had to say about this record, when it is on the
    /// shelf at all. §8 fills this in; until it does, the record is simply not
    /// on the shelf and the two lines are absent.
    public struct Shelf: Sendable, Equatable {
        public let shelf: String
        public let note: String
        public let year: String

        public init(shelf: String = "", note: String = "", year: String = "") {
            self.shelf = shelf
            self.note = note
            self.year = year
        }
    }

    public init(record: Record, releaseYear: String? = nil, shelf: Shelf? = nil) {
        let year = HeaderBlock.year(
            tags: record.year, musicBrainz: releaseYear, collection: shelf?.year
        )
        var rows: [Row] = [
            Row(label: "ALBUM", value: HeaderBlock.orDash(record.album)),
            Row(label: "ARTIST", value: HeaderBlock.artistLine(record.albumArtist, year: year)),
            Row(label: "SOURCE", value: record.sourceLabel),
        ]
        if let shelf {
            if !shelf.shelf.isEmpty {
                rows.append(Row(label: "SHELF", value: shelf.shelf))
            }
            if !shelf.note.isEmpty {
                rows.append(Row(label: "NOTE", value: shelf.note, annotated: true))
            }
        }
        self.rows = rows
    }
}
