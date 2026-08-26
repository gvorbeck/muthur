import Foundation

/// §8 — what your own catalogue has to say about the record that is playing
/// (`player:1609`).
///
/// **This is the one thing a general-purpose player cannot do.** MusicBrainz
/// knows what a disc is; only the shelf it came off knows that you bought it
/// used at Amoeba and that it skips on track seven — and track seven skipping
/// is precisely the moment you want to be told you already knew
/// (`player:1613`).
///
/// **Nothing here is allowed to matter.** No file, a renamed header, an album
/// that is simply not in the catalogue — every one of them leaves the panel
/// exactly as it would have been, because a missing note is not a reason to
/// interrupt a record (`player:1618`). That is why every failure in this file
/// is a `nil` and none of them is an error: there is no caller that would want
/// to hear about it.
///
/// Named for the script's own word (`player:1611`, and §13 calls the setting a
/// path to the catalogue CSV). Not `Collection`, which would shadow the
/// standard library's protocol for every file that imports this module.
public struct Catalogue: Sendable {

    /// One record's row on the shelf.
    public struct Entry: Sendable, Equatable {
        public let year: String
        public let genre: String
        public let tags: String
        public let note: String

        public init(year: String = "", genre: String = "", tags: String = "", note: String = "") {
            self.year = year
            self.genre = genre
            self.tags = tags
            self.note = note
        }

        /// `COLL_SHELF` (`player:1725`) — **less the year**, which D6 moved up
        /// beside the artist. The script put the catalogue's year here and
        /// nowhere else, so a record not on the shelf showed no year at all and
        /// one that was showed a year that had not come from the record. It is
        /// one year now, from one precedence, and where that year and this line
        /// would disagree the disagreement is not worth two lines on a
        /// faceplate.
        public var shelf: String {
            [genre, tags].filter { !$0.isEmpty }.joined(separator: " · ")
        }

        /// Nothing to say. The row matched and every field on it was blank,
        /// which is a hit with no annotation in it — the script's `COLL_ROWS`
        /// of zero (`player:1731`).
        public var isEmpty: Bool { shelf.isEmpty && note.isEmpty && year.isEmpty }
    }

    /// Which column holds what.
    ///
    /// **Found by name, not by number** (`player:1645`). The two CSVs in that
    /// repository do not agree on whether `Number` comes first — the wishlist
    /// has no `Number` or `Book` at all and puts `Notes` before `Art URL` — and
    /// a lookup that silently reads the wrong column is worse than one that
    /// finds nothing.
    ///
    /// `Art URL` is deliberately not here. The script reads it into `COLL_ART`
    /// and never looks at it again, which is §15: vestigial, listed so nobody
    /// rebuilds it looking for the consumer.
    struct Columns: Sendable, Equatable {
        var artist: Int?
        var title: Int?
        var year: Int?
        var genre: Int?
        var tags: Int?
        var notes: Int?
    }

    let columns: Columns
    let rows: [[String]]

    /// How many rows the catalogue has, header excluded. Nothing on the panel
    /// wants this; §11 will.
    public var count: Int { rows.count }

    /// Parse a catalogue. A file with no header line, or a header with no
    /// `Title` column, is not an error — it is a catalogue that will never
    /// match anything, which is the same thing as no catalogue at all.
    public init(csv text: String) {
        let records = CSV.rows(text)
        guard let header = records.first else {
            columns = Columns()
            rows = []
            return
        }

        var found = Columns()
        for (index, name) in header.enumerated() {
            // Lowercased and compared whole, as the script does — no trimming,
            // because a header that has grown a leading space has been edited
            // by something and guessing at it is the move `by name` exists to
            // avoid (`player:1688`).
            switch name.lowercased() {
            case "artist": found.artist = index
            case "title": found.title = index
            case "year": found.year = index
            case "parent genre": found.genre = index
            case "tags": found.tags = index
            case "notes": found.notes = index
            default: break
            }
        }
        columns = found
        rows = Array(records.dropFirst())
    }

    /// Loose enough that `The Beatles` finds `Beatles` and punctuation and case
    /// never decide it, strict enough that two different records cannot collide
    /// (`player:1679`).
    ///
    /// The order matters and is the script's: lowercase, then drop a leading
    /// `the ` — one or more spaces, so `Theory` keeps its head — then throw
    /// away everything that is not `a`–`z` or `0`–`9`. That last step also
    /// throws away every non-ASCII letter, so `Björk` normalises to `bjrk`;
    /// both sides of every comparison go through here, so it matches itself.
    public static func normalise(_ text: String) -> String {
        var lowered = Substring(text.lowercased())
        if lowered.hasPrefix("the ") {
            lowered = lowered.dropFirst(4).drop { $0 == " " }
        }
        var out = ""
        out.reserveCapacity(lowered.count)
        for scalar in lowered.unicodeScalars {
            switch scalar.value {
            case 0x61...0x7A, 0x30...0x39: out.unicodeScalars.append(scalar)
            default: break
            }
        }
        return out
    }

    /// Look the playing record up.
    ///
    /// The title has to agree. The **artist has to agree when there is one** —
    /// and when the files carried no album artist at all, a title on its own is
    /// accepted only if exactly one record in the catalogue answers to it, two
    /// being a coin toss (`player:1698`). The test for *is there one* is on the
    /// album artist as it arrived, not on its normalised form, which is the
    /// script's `want_a!=""`.
    ///
    /// With an album artist and more than one row matching both, the **last**
    /// matching row wins. That is not a choice — awk's body overwrites its
    /// captured fields on every hit and the `END` block prints whatever was
    /// left in them (`player:1703`), and a rule that reads the same catalogue
    /// twice and answers differently would be worse than one that is arbitrary
    /// in a way you can predict.
    public func look(album: String, albumArtist: String) -> Entry? {
        // No album name, no lookup — there is nothing to match on
        // (`player:1657`).
        guard !album.isEmpty else { return nil }
        guard let titleColumn = columns.title else { return nil }

        let wantedTitle = Catalogue.normalise(album)
        let wantedArtist = Catalogue.normalise(albumArtist)
        let artistMatters = !albumArtist.isEmpty

        var hits = 0
        var last: Entry?

        for row in rows {
            guard Catalogue.normalise(field(row, titleColumn)) == wantedTitle else { continue }
            if artistMatters {
                guard let artistColumn = columns.artist,
                    Catalogue.normalise(field(row, artistColumn)) == wantedArtist
                else { continue }
            }
            hits += 1
            last = Entry(
                year: flattened(field(row, columns.year)),
                genre: flattened(field(row, columns.genre)),
                tags: flattened(field(row, columns.tags)),
                note: flattened(field(row, columns.notes))
            )
        }

        // `hits==1 || (hits>1 && want_a!="")` (`player:1706`).
        guard hits == 1 || (hits > 1 && artistMatters) else { return nil }
        return last
    }

    /// A field out of a row, or nothing. A row shorter than the header is not
    /// malformed enough to throw away — awk hands back an empty string for a
    /// column past the end of the record, and so does this.
    private func field(_ row: [String], _ column: Int?) -> String {
        guard let column, column >= 0, column < row.count else { return "" }
        return row[column]
    }

    /// The script squashes tabs out of these fields on the way past
    /// (`player:1712`), and its reason is a bash one — `read` treats a tab as
    /// IFS whitespace, so an empty field in the middle would shift every later
    /// field left and a record with no `Notes` would hand its `Art URL` to
    /// `COLL_NOTES`. There is no `read` here and that hazard is gone.
    ///
    /// The tab is flattened anyway, and so is the newline, for the other
    /// reason: this text is drawn on a grid the panel works to keep square.
    /// The newline is new — awk could never have put one in a field, and now
    /// that a quoted field may span lines it can.
    private func flattened(_ text: String) -> String { Track.flatten(text) }
}

extension HeaderBlock.Shelf {
    /// §8's answer, in the shape §10 draws (`player:2333`). The note is in
    /// amber and the rest is plain, because the note is the half you wrote down
    /// yourself and the only line here you cannot get from any other player.
    public init(_ entry: Catalogue.Entry) {
        self.init(shelf: entry.shelf, note: entry.note, year: entry.year)
    }
}
