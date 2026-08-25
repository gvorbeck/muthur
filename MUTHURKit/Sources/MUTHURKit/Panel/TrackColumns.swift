import Foundation

/// §10 — how the room between the row number and the duration is divided
/// between the title and the artist, and whether there is an artist column at
/// all (`player:2288`).
///
/// On an album there is not. Every row would carry the same name and that name
/// is already printed at the top of the panel under ARTIST: a column that
/// repeats one fact fifty times is not a column, it is a margin with writing on
/// it. Dropping it hands the title the whole width, which is the difference
/// between `Libet's all joyful camarad…` and the title the record actually has.
///
/// On a compilation it is a real column, because there the artist changes per
/// row and is the second thing you read.
public struct TrackColumns: Sendable, Equatable {

    /// Columns for the title.
    public let title: Int
    /// Columns for the artist, or zero where there is no artist column. The
    /// artist field carries its own leading gap, so a record without one leaves
    /// no gap where one would have been — the title simply runs on to where the
    /// artist used to start.
    public let artist: Int

    /// The gap between the two, which only exists when both do.
    public static let gap = 2

    /// No name gets more than this, however long it is. Past eighteen columns
    /// the column has stopped being the second thing you read and started being
    /// the first (`player:2314`).
    public static let artistCap = 18

    /// Everything between the row number and the duration, at bash's fixed
    /// panel width — `NP_TITLE_W` of 52 with no artist column, and 50 plus the
    /// gap with one (`player:2287`).
    public static let standardTextWidth = 52

    public init(title: Int, artist: Int) {
        self.title = title
        self.artist = artist
    }

    /// Decided **once per record and not per row**, which is what keeps the
    /// list a grid: this gives the titles the slack, it does not make the edges
    /// ragged (`player:2284`).
    ///
    /// The test for dropping the column is against the *album artist* rather
    /// than merely "they all agree", because a record whose tracks say
    /// `Miles Davis Quintet` under an album credited to `Miles Davis` is not
    /// repeating the header — it is saying something else, and dropping the
    /// column would throw that away (`player:2301`).
    public static func decide(for record: Record, textWidth: Int = standardTextWidth)
        -> TrackColumns
    {
        var one: String? = nil
        var same = true
        var longest = 0
        for track in record.running {
            if let one {
                if track.artist != one { same = false }
            } else {
                one = track.artist
            }
            longest = max(longest, Columns.width(of: track.artist))
        }

        // An empty artist all the way down is the same case as the album's own
        // name all the way down: there is nothing a column would be carrying.
        let repeated = one.map { $0.isEmpty || $0 == record.albumArtist } ?? true
        if same && repeated {
            return TrackColumns(title: textWidth, artist: 0)
        }

        // Sized to the longest name the record actually contains rather than to
        // the worst case, so the titles still get whatever the names do not use.
        let artist = min(longest, artistCap)
        return TrackColumns(title: textWidth - gap - artist, artist: artist)
    }
}
