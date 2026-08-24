import Foundation

/// §7's other half: the thing that keeps the file up to date while a record
/// plays, and holds the standing offer until it is spent.
///
/// It is driven by the same tick the deck is, and it learns everything it knows
/// by looking at `PlaybackEngine.State`. That is on purpose — the script writes
/// the file from two places, `enter_track` (`player:3396`) and the `time-pos`
/// property change (`player:2776`), and both of those are *observations of the
/// player*, not decisions the player takes. Nothing in `Play/` had to move to
/// make this work, and nothing in `Play/` knows this exists.
public struct ResumeWatch: Sendable {

    private let file: ResumeFile
    private let key: String
    private let sourceLabel: String

    /// The position the file was last told about. `saved_at` (`player:2775`).
    private var savedAt = 0
    /// The row the last observation was on. `nil` before the first one, which
    /// is what makes the first track a track change.
    private var lastRow: Int?
    /// Cleared once, at the end, and not again on every tick after it.
    private var cleared = false

    /// What was in the file when the record was put on, if it was worth
    /// offering. Stays here for the whole session so `u` keeps working; it is
    /// only *shown* once.
    public private(set) var offer: ResumeFile.Offer?

    /// Whether the offer has been put on the status line yet. The offer goes up
    /// after the first track has started, because starting a track clears the
    /// status line and this is the one thing on it that has to outlive that
    /// (`player:2825`).
    private var shown = false

    public init(file: ResumeFile, key: String, sourceLabel: String, rows: Int) {
        self.file = file
        self.key = key
        self.sourceLabel = sourceLabel
        self.offer = file.offer(key: key, rows: rows)
    }

    // MARK: - The offer

    /// The offer, the first time it is asked for after a track has started, and
    /// never again. The panel calls this once per tick and puts what it gets on
    /// the status line.
    public mutating func offerToShow(mode: PlaybackEngine.Mode) -> ResumeFile.Offer? {
        guard !shown, let offer, mode == .playing || mode == .paused else { return nil }
        shown = true
        return offer
    }

    /// `u` was pressed (`player:2720`). The caller picks the row and seeks; this
    /// only stops the offer being spent twice.
    public mutating func spend() -> ResumeFile.Offer? {
        defer { offer = nil }
        return offer
    }

    // MARK: - Keeping the file

    /// One tick of the deck. Everything §7 writes, it writes from here.
    ///
    /// A record that has not started has nothing to say about where it got to,
    /// so `stopped` is passed over rather than written as row nought.
    public mutating func observe(mode: PlaybackEngine.Mode, row: Int, positionInTrack: Double) {
        if mode == .finished {
            // `album_ended` (`player:3493`). Once — a finished record stays
            // finished, and rewriting the file every tick for the rest of the
            // session would be a lot of writing to say the same nothing.
            if !cleared {
                cleared = true
                file.clear(key: key)
            }
            return
        }
        guard mode != .stopped else { return }
        cleared = false

        // A new track, written before a note of it has played, so that quitting
        // between tracks comes back to the right one (`player:3396`).
        if row != lastRow {
            lastRow = row
            savedAt = 0
            file.save(key: key, row: row, position: 0, sourceLabel: sourceLabel)
            return
        }

        // Five seconds rather than every one of them: a file write a second for
        // the length of a record is a lot of writing to save a number that is
        // only ever read once, and five seconds is inside the margin of where
        // you would say you had got to anyway (`player:2772`).
        //
        // Symmetric, and that is not decoration — it is what catches a seek
        // backwards, and it is what catches REPEAT TRACK starting the same row
        // over without the row ever changing.
        let position = Int(positionInTrack)
        if position >= savedAt + 5 || position <= savedAt - 5 {
            savedAt = position
            file.save(key: key, row: row, position: position, sourceLabel: sourceLabel)
        }
    }

    // MARK: - Deliberately absent

    // No `apply`. This never moves the needle — §7's first box is that the
    // offer is offered and never applied, and the way to keep a rule like that
    // is to give the thing that would break it no way to.
}
