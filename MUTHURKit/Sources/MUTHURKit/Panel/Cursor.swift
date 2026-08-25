import Foundation

/// §6 — the cursor, which is not the playhead (`player:2344`).
///
/// `♪` is the track the music is coming out of; the highlighted row is the row
/// the cursor is on. Usually they agree. When you browse ahead they do not, and
/// the panel has to be able to say so — which is why the playing mark is not a
/// second arrow.
///
/// **Moving the cursor is browsing, and browsing stops it chasing the music**
/// until you pick something with it again (`player:2693`). Everything that is
/// you choosing a track — `⏎`, `n`, `p`, a click on the album meter, taking the
/// resume offer — puts it back to following. Everything that is you reading the
/// list — the arrows, page keys, the wheel, a click that only selects — takes
/// it off.
public struct Cursor: Sendable, Equatable {

    /// The row the cursor is on.
    public private(set) var row: Int
    /// The first row of the window the list is scrolled to (`np_top`).
    public private(set) var top: Int
    /// Whether the cursor is still chasing the music (`np_follow`, which starts
    /// at 1 — a record you have not touched follows itself).
    public private(set) var follows: Bool

    public init(row: Int = 0, top: Int = 0, follows: Bool = true) {
        self.row = row
        self.top = top
        self.follows = follows
    }

    // MARK: - Staying inside the record

    /// `np_clamp` (`player:2868`). A record that has lost a track since the
    /// cursor was last put somewhere must not leave it pointing off the end.
    private mutating func clamp(count: Int) {
        if row < 0 { row = 0 }
        if row >= count { row = max(0, count - 1) }
    }

    /// The scroll window (`player:2904`).
    ///
    /// It moves only as far as it has to: a cursor above the window pulls the
    /// window's top up to it, a cursor below pushes its bottom down to it, and a
    /// cursor already inside moves nothing. Which is why walking down a list
    /// scrolls a row at a time from the bottom rather than jumping a page.
    ///
    /// **Four lines, where the script has three (§18.22).** The script has no
    /// rule pulling the window back up when it has more room than it needs, so a
    /// terminal made taller leaves `np_top` where it was and draws a short list
    /// with blank space under it until the cursor next moves (`player:2904`).
    ///
    /// That is not a judgement being overruled — it is a judgement that was
    /// never asked for. A `SIGWINCH` is a rare event and the next arrow key
    /// tidies up after it; a window dragged by its corner asks this question
    /// hundreds of times in a second, and the blank space under a short list is
    /// then not a stale frame but the thing you are looking at while you drag.
    /// The environment changed, not the script's reasoning.
    ///
    /// The fourth line (D31) only ever shrinks `top`, and only when the list cannot
    /// fill the window from where it is — so it is silent whenever the window is
    /// smaller than the list, which is every case bash was actually in.
    private mutating func scroll(rows: Int, count: Int) {
        if row < top { top = row }
        if row >= top + rows { top = row - rows + 1 }
        if top > max(0, count - rows) { top = max(0, count - rows) }
        if top < 0 { top = 0 }
    }

    private mutating func settle(rows: Int, count: Int) {
        clamp(count: count)
        scroll(rows: rows, count: count)
    }

    // MARK: - Reading the list

    /// An arrow, a page key or the wheel. Browsing: the cursor stops following.
    public mutating func browse(by delta: Int, rows: Int, count: Int) {
        row += delta
        follows = false
        settle(rows: rows, count: count)
    }

    /// A click that lands on a row the cursor is not already on. Also browsing —
    /// the first click moves the cursor and the second one starts it, which is
    /// the difference between reading the list with the pointer and being made
    /// to listen to whatever the pointer happened to land on (`player:3213`).
    public mutating func browse(to target: Int, rows: Int, count: Int) {
        row = target
        follows = false
        settle(rows: rows, count: count)
    }

    // MARK: - Choosing a track

    /// `⏎`, `n`, `p`, the album meter, the resume offer, and the second click on
    /// a row: the cursor goes back to following the music.
    public mutating func choose(_ target: Int, rows: Int, count: Int) {
        row = target
        follows = true
        settle(rows: rows, count: count)
    }

    /// A track has started (`player:3405`). If the cursor is still following,
    /// it goes where the music went; if you are browsing, it stays where you
    /// left it and the list does not move under you.
    public mutating func trackStarted(_ playing: Int, rows: Int, count: Int) {
        guard follows, row != playing else { return }
        row = playing
        settle(rows: rows, count: count)
    }

    /// The window has changed size, or the record has. The cursor keeps its row
    /// and the window is worked out again around it.
    public mutating func reflow(rows: Int, count: Int) {
        settle(rows: rows, count: count)
    }

    // MARK: - What the panel asks it

    /// The rows actually on screen, and how many are below the fold.
    public func window(rows: Int, count: Int) -> (visible: Range<Int>, more: Int) {
        let last = min(top + rows, count)
        return (top..<max(top, last), max(0, count - last))
    }
}
