import Foundation

/// §20.4 — the plan screen, as a state machine.
///
/// `tui_edit` and everything it calls (`burncd:893`–`1350`). The drawing is in
/// `App/`; what a key means is here, where it can be tested without a terminal.
///
/// **Nothing on this screen touches the record on disk.** Every rename, every
/// dropped track and every disc break lives in this value and dies with it. The
/// script is the same and says so — the tags on the files are read once at the
/// start and never written — and it matters more here than there, because a
/// panel that looks like a tag editor and is not has to be trusted to be what
/// it says.
public struct PlanEditor: Sendable {

    /// The three header fields sit above the tracks and are selected the same
    /// way, so the cursor is one number over one list (`burncd:1148`, where it
    /// starts at 3 — on the first track, not on the album title, because the
    /// running order is what anyone came here to look at).
    public enum Row: Sendable, Equatable {
        case album
        case albumArtist
        case year
        /// A position in the running order, not a source index.
        case track(Int)
    }

    /// How many rows the header takes.
    public static let headerRows = 3

    public private(set) var draft: PlanDraft
    /// The plan as it stands. Re-derived after every change, because everything
    /// after the running order is a function of it (`replan`, `burncd:731`).
    public private(set) var plan: BurnPlan
    /// What the last key did. Read once by the panel and cleared, exactly as
    /// `tui_edit` clears it after each draw (`burncd:1180`).
    public private(set) var status: String = ""
    public private(set) var cursor: Int

    /// `ORDER_ORIG` — the running order as the folder gave it, kept for `R`.
    private let originalOrder: [Int]
    private let capacity: Int
    private let splitLong: Bool
    private var undoStack: [Undo] = []

    /// `UNDO_MAX` (`burncd:1111`). Bounded because an hour of nudging a running
    /// order should not grow a stack without end, and nobody is undoing ninety
    /// edits ago one keystroke at a time.
    public static let undoLimit = 100

    public init(
        draft: PlanDraft, capacity: Int = BurnLimits.capacity, splitLong: Bool = false
    ) throws {
        self.draft = draft
        self.originalOrder = draft.order
        self.capacity = capacity
        self.splitLong = splitLong
        self.plan = try BurnPlan.make(draft: draft, capacity: capacity, splitLong: splitLong)
        self.cursor = Self.headerRows
    }

    // MARK: - Where the cursor is

    public var rowCount: Int { Self.headerRows + draft.order.count }

    public var row: Row {
        switch cursor {
        case 0: .album
        case 1: .albumArtist
        case 2: .year
        default: .track(cursor - Self.headerRows)
        }
    }

    /// The position in the running order, or nil on a header field.
    public var selectedPosition: Int? {
        guard case .track(let position) = row else { return nil }
        return position
    }

    /// The source index the cursor is on, or nil on a header field.
    public var selectedSource: Int? {
        guard let position = selectedPosition, position < draft.order.count else { return nil }
        return draft.order[position]
    }

    /// `↑` and `↓`. Clamped rather than wrapped — the script clamps
    /// (`burncd:1157`), and a list that wraps from the last track to the album
    /// title is a list you can overshoot in both directions at once.
    public mutating func moveCursor(_ delta: Int) {
        cursor = min(max(0, cursor + delta), rowCount - 1)
    }

    public mutating func moveCursor(to row: Int) {
        cursor = min(max(0, row), rowCount - 1)
    }

    // MARK: - The edits

    /// `⇧↑` / `⇧↓` — swap a track with its neighbour (`tui_move`,
    /// `burncd:1211`).
    ///
    /// Returns false when the move is impossible, so the caller knows not to
    /// move the cursor with it — the cursor follows the track, and a cursor
    /// that moved when the track did not has left the track behind.
    @discardableResult
    public mutating func moveTrack(_ delta: Int) -> Bool {
        guard let from = selectedPosition else { return false }
        let to = from + delta
        guard to >= 0, to < draft.order.count else { return false }
        push(.order(label: "ORDER"))
        draft.order.swapAt(from, to)
        replan()
        cursor += delta
        return true
    }

    /// `⏎` — rename whatever the cursor is on.
    ///
    /// Nothing is pushed onto the undo stack for an edit that changed nothing
    /// (`burncd:1261`): pressing `⏎` on a title and then `⏎` again to keep it
    /// is how anyone reads a row that is too long for the column, and it should
    /// not cost an undo that appears to do nothing when it is spent.
    public mutating func rename(to new: String) {
        switch row {
        case .album:
            guard new != draft.album else { return }
            push(.album(label: "ALBUM", old: draft.album))
            draft.album = new
        case .albumArtist:
            guard new != draft.albumArtist else { return }
            push(.albumArtist(label: "ARTIST", old: draft.albumArtist))
            draft.albumArtist = new
        case .year:
            guard new != draft.year else { return }
            push(.year(label: "YEAR", old: draft.year))
            draft.year = new
        case .track:
            guard let source = selectedSource, new != draft.rows[source].title else { return }
            push(.title(label: "TITLE", source: source, old: draft.rows[source].title))
            draft.rows[source].title = new
        }
        replan()
    }

    /// The text `⏎` should offer for editing, and what to call it.
    public var renamePrompt: (label: String, value: String) {
        switch row {
        case .album: ("ALBUM", draft.album)
        case .albumArtist: ("ARTIST", draft.albumArtist)
        case .year: ("YEAR", draft.year)
        case .track: ("TITLE", selectedSource.map { draft.rows[$0].title } ?? "")
        }
    }

    /// `A` — the artist. On any header row it is the album's, which is what
    /// `tui_artist` does with a cursor above the tracks (`burncd:1285`): the
    /// key means "the artist of the thing I am looking at", and above the
    /// tracks the thing you are looking at is the record.
    public var artistPrompt: (label: String, value: String) {
        guard let source = selectedSource else { return ("ARTIST", draft.albumArtist) }
        return ("ARTIST", draft.rows[source].artist)
    }

    public mutating func setArtist(to new: String) {
        guard let source = selectedSource else {
            guard new != draft.albumArtist else { return }
            push(.albumArtist(label: "ARTIST", old: draft.albumArtist))
            draft.albumArtist = new
            replan()
            return
        }
        guard new != draft.rows[source].artist else { return }
        push(.artist(label: "ARTIST", source: source, old: draft.rows[source].artist))
        draft.rows[source].artist = new
        replan()
    }

    /// `S` — start a new disc here, or stop doing so (`tui_break`,
    /// `burncd:1238`).
    ///
    /// Two rows cannot take a break: the header fields, which are not tracks,
    /// and the first track, which opens disc 1 whatever anyone does. Both say
    /// so rather than doing nothing, since **a key that silently declines reads
    /// as a key that is broken** — the script's own words, and the principle
    /// D65 applies to `X` as well.
    public mutating func toggleBreak() {
        guard let position = selectedPosition else {
            status = Readout.status("SELECT A TRACK TO START A DISC AT")
            return
        }
        guard position > 0 else {
            status = Readout.status("THE FIRST TRACK ALREADY STARTS DISC 1")
            return
        }
        let source = draft.order[position]
        push(.order(label: "DISC BREAK"))
        if draft.breaks.contains(source) {
            draft.breaks.remove(source)
            status = Readout.status("DISC BREAK CLEARED")
        } else {
            draft.breaks.insert(source)
            status = Readout.status("DISC BREAK SET — A NEW DISC STARTS HERE")
        }
        replan()
    }

    /// `X` — take a track out of the running order.
    ///
    /// The whole order goes on the undo stack first, so a track comes back
    /// where it was rather than on the end — and so does everything else the
    /// drop moved (`burncd:1300`).
    ///
    /// **D65: both refusals say why.** `tui_drop` returns nonzero on a header
    /// row and on the last remaining track, and `burncd:1193` calls it as
    /// `tui_drop "$cur" && status=…`, which swallows the refusal — so `x` on
    /// the last track of a one-track plan does nothing and says nothing. That
    /// is the exact failure `tui_break` was written to avoid, three functions
    /// further down and in the script's own words. The principle is the
    /// script's; only this application of it is new.
    public mutating func drop() {
        guard let position = selectedPosition else {
            status = Readout.status("SELECT A TRACK TO DROP")
            return
        }
        guard draft.order.count > 1 else {
            status = Readout.status("A DISC NEEDS ONE TRACK — THIS IS THE LAST")
            return
        }
        push(.order(label: "TRACK"))
        draft.order.remove(at: position)
        replan()
        // The cursor was on the last row and that row is gone.
        cursor = min(cursor, rowCount - 1)
        status = Readout.status("TRACK DROPPED — PRESS U TO UNDO")
    }

    /// `U` — one step back, whatever the last step was.
    ///
    /// Succeeds even with nothing to undo, and says so. The label is what the
    /// status line reports was restored, so undoing a drop reads "TRACK
    /// RESTORED" the way it always did (`burncd:1104`).
    public mutating func undo() {
        guard let record = undoStack.popLast() else {
            status = Readout.status("NOTHING TO UNDO")
            return
        }
        switch record {
        case .order(let label, let order, let breaks):
            draft.order = order
            draft.breaks = breaks
            status = Readout.status("\(label) RESTORED")
        case .title(let label, let source, let old):
            draft.rows[source].title = old
            status = Readout.status("\(label) RESTORED")
        case .artist(let label, let source, let old):
            draft.rows[source].artist = old
            status = Readout.status("\(label) RESTORED")
        case .album(let label, let old):
            draft.album = old
            status = Readout.status("\(label) RESTORED")
        case .albumArtist(let label, let old):
            draft.albumArtist = old
            status = Readout.status("\(label) RESTORED")
        case .year(let label, let old):
            draft.year = old
            status = Readout.status("\(label) RESTORED")
        }
        cursor = min(cursor, rowCount - 1)
        replan()
    }

    /// `R` — put the running order back the way the folder had it.
    ///
    /// **D66: the order and the breaks, and not the names.** `burncd:1198` is
    /// `undo_state PLAN; ORDER=("${ORDER_ORIG[@]}"); BREAK_AT=(); replan` —
    /// renames survive it. burncd's README says "Reset to the original tags and
    /// order", which is a wider claim than the code makes, and the standing
    /// rule settles it: where any description conflicts with the script, the
    /// script is right. It is also the better key. A rename is one `U` away and
    /// a shuffled order is not, so tying the two together makes `R` a key that
    /// can lose work you cannot get back in one press.
    public mutating func reset() {
        push(.order(label: "PLAN"))
        draft.order = originalOrder
        draft.breaks = []
        replan()
        cursor = min(cursor, rowCount - 1)
        status = Readout.status("ORIGINAL ORDER RESTORED")
    }

    /// Read the status line and clear it, the way the draw loop does.
    public mutating func takeStatus() -> String {
        defer { status = "" }
        return status
    }

    // MARK: - The undo stack

    /// A snapshot rather than an inverse operation for anything structural
    /// (`burncd:1099`). An order is a hundred bytes, the plan re-derives from
    /// it, and a stack of snapshots cannot get the inverse of a move wrong the
    /// way a stack of moves can.
    private enum Undo: Sendable {
        case order(label: String, order: [Int], breaks: Set<Int>)
        case title(label: String, source: Int, old: String)
        case artist(label: String, source: Int, old: String)
        case album(label: String, old: String)
        case albumArtist(label: String, old: String)
        case year(label: String, old: String)
    }

    /// What a caller asks to push. The structural snapshot is filled in from
    /// the draft at push time, so no caller has to remember to take one — the
    /// bug that makes an undo stack useless is the one where somebody took the
    /// snapshot after the edit.
    private enum Pending {
        case order(label: String)
        case title(label: String, source: Int, old: String)
        case artist(label: String, source: Int, old: String)
        case album(label: String, old: String)
        case albumArtist(label: String, old: String)
        case year(label: String, old: String)
    }

    private mutating func push(_ pending: Pending) {
        let record: Undo =
            switch pending {
            case .order(let label): .order(label: label, order: draft.order, breaks: draft.breaks)
            case .title(let l, let s, let o): .title(label: l, source: s, old: o)
            case .artist(let l, let s, let o): .artist(label: l, source: s, old: o)
            case .album(let l, let o): .album(label: l, old: o)
            case .albumArtist(let l, let o): .albumArtist(label: l, old: o)
            case .year(let l, let o): .year(label: l, old: o)
            }
        undoStack.append(record)
        if undoStack.count > Self.undoLimit { undoStack.removeFirst() }
    }

    public var undoCount: Int { undoStack.count }

    /// `replan` (`burncd:731`) — everything after the running order derives
    /// from it, so a reorder is a rebuild.
    ///
    /// The throw cannot happen from here. Nothing the editor does lengthens a
    /// track or empties the order — `drop` refuses the last one — so a draft
    /// that made a plan at `init` still makes one. Holding the last good plan
    /// rather than crashing is the answer that costs nothing if that ever stops
    /// being true.
    private mutating func replan() {
        if let fresh = try? BurnPlan.make(
            draft: draft, capacity: capacity, splitLong: splitLong
        ) {
            plan = fresh
        }
    }
}
