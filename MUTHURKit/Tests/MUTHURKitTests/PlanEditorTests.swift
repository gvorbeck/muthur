import Foundation
import Testing

@testable import MUTHURKit

// MARK: - §20.4 The plan screen

@Suite("§20.4 — the plan editor")
struct PlanEditorTests {

    private func editor(_ count: Int = 5, each: Int = 300) throws -> PlanEditor {
        try PlanEditor(
            draft: PlanDraft(
                rows: (0..<count).map {
                    PlanDraft.Row(
                        title: "Track \($0 + 1)", artist: "Artist \($0 + 1)", duration: each
                    )
                },
                order: Array(0..<count),
                album: "A Record", albumArtist: "Someone", year: "1979",
                orderedByFilename: false
            )
        )
    }

    /// The cursor starts on the first track and not on the album title
    /// (`burncd:1148`, `cur=3`) — the running order is what anyone came here to
    /// look at, and the header fields are above it because that is where a
    /// header goes, not because they are what you want first.
    @Test("The cursor opens on the first track, below the three header fields")
    func opensOnTheTracks() throws {
        let editor = try editor()
        #expect(editor.cursor == 3)
        #expect(editor.row == .track(0))
        #expect(editor.rowCount == 8)
    }

    /// Clamped rather than wrapped (`burncd:1157`). A list that wraps from the
    /// last track to the album title is one you can overshoot in both
    /// directions at once.
    @Test("The cursor stops at both ends instead of wrapping")
    func clamps() throws {
        var editor = try editor()
        editor.moveCursor(-10)
        #expect(editor.cursor == 0)
        #expect(editor.row == .album)
        editor.moveCursor(1)
        #expect(editor.row == .albumArtist)
        editor.moveCursor(1)
        #expect(editor.row == .year)
        editor.moveCursor(100)
        #expect(editor.cursor == editor.rowCount - 1)
        #expect(editor.row == .track(4))
    }

    /// The cursor follows the track, and a cursor that moved when the track did
    /// not has left the track behind (`burncd:1211`).
    @Test("⇧↓ takes the track and the cursor together, and declines at the end")
    func moving() throws {
        var editor = try editor(3)
        let moved = editor.moveTrack(1)
        #expect(moved)
        #expect(editor.plan.entries.map(\.source) == [1, 0, 2])
        #expect(editor.row == .track(1))

        editor.moveCursor(to: 3)  // first row
        let offTheTop = editor.moveTrack(-1)
        #expect(!offTheTop)
        #expect(editor.row == .track(0))

        editor.moveCursor(to: 5)  // last row
        let offTheBottom = editor.moveTrack(1)
        #expect(!offTheBottom)
        #expect(editor.row == .track(2))
    }

    @Test("A header field cannot be moved")
    func headerDoesNotMove() throws {
        var editor = try editor()
        editor.moveCursor(to: 0)
        let moved = editor.moveTrack(1)
        #expect(!moved)
        #expect(editor.row == .album)
    }

    /// Nothing is pushed onto the undo stack for an edit that changed nothing
    /// (`burncd:1261`): pressing `⏎` and then `⏎` again to keep the title is
    /// how anyone reads a row too long for the column, and it should not cost
    /// an undo that appears to do nothing when it is spent.
    @Test("Renaming to the same thing costs no undo")
    func renameToTheSame() throws {
        var editor = try editor()
        #expect(editor.renamePrompt.label == "TITLE")
        #expect(editor.renamePrompt.value == "Track 1")
        editor.rename(to: "Track 1")
        #expect(editor.undoCount == 0)
        editor.rename(to: "Something Else")
        #expect(editor.undoCount == 1)
        #expect(editor.plan.entries[0].title == "Something Else")
    }

    @Test("The three header fields rename to themselves")
    func headerRenames() throws {
        var editor = try editor()
        editor.moveCursor(to: 0)
        #expect(editor.renamePrompt == ("ALBUM", "A Record"))
        editor.rename(to: "Another Record")
        #expect(editor.draft.album == "Another Record")

        editor.moveCursor(to: 1)
        editor.rename(to: "Somebody")
        #expect(editor.draft.albumArtist == "Somebody")

        editor.moveCursor(to: 2)
        editor.rename(to: "1986")
        #expect(editor.draft.year == "1986")
        #expect(editor.undoCount == 3)
    }

    /// `A` above the tracks means the album's artist (`burncd:1285`): the key
    /// means *the artist of the thing I am looking at*, and above the tracks
    /// the thing you are looking at is the record.
    @Test("A on a header row is the album artist, and on a track is the track's")
    func artistKey() throws {
        var editor = try editor()
        editor.moveCursor(to: 0)
        #expect(editor.artistPrompt == ("ARTIST", "Someone"))
        editor.setArtist(to: "A Band")
        #expect(editor.draft.albumArtist == "A Band")

        editor.moveCursor(to: 4)
        #expect(editor.artistPrompt == ("ARTIST", "Artist 2"))
        editor.setArtist(to: "A Guest")
        #expect(editor.draft.rows[1].artist == "A Guest")
        #expect(editor.draft.albumArtist == "A Band")
    }

    /// Both refusals say why, since a key that silently declines reads as a key
    /// that is broken (`burncd:1231`).
    @Test("S declines on a header row and on the first track, and says why both times")
    func breakRefusals() throws {
        var editor = try editor()
        editor.moveCursor(to: 0)
        editor.toggleBreak()
        #expect(editor.status == Readout.status("SELECT A TRACK TO START A DISC AT"))
        #expect(editor.plan.discCount == 1)

        editor.moveCursor(to: 3)
        editor.toggleBreak()
        #expect(editor.status == Readout.status("THE FIRST TRACK ALREADY STARTS DISC 1"))
        #expect(editor.undoCount == 0)
    }

    @Test("S sets a break, S again clears it, and the layout follows both times")
    func breakToggles() throws {
        var editor = try editor(4, each: 300)
        editor.moveCursor(to: 5)  // the third track
        editor.toggleBreak()
        #expect(editor.status == Readout.status("DISC BREAK SET — A NEW DISC STARTS HERE"))
        #expect(editor.plan.discCount == 2)
        #expect(editor.plan.entries(onDisc: 2).map(\.source) == [2, 3])

        editor.toggleBreak()
        #expect(editor.status == Readout.status("DISC BREAK CLEARED"))
        #expect(editor.plan.discCount == 1)
    }

    @Test("X takes a track out of the running order and offers the undo")
    func drop() throws {
        var editor = try editor(4)
        editor.moveCursor(to: 4)
        editor.drop()
        #expect(editor.status == Readout.status("TRACK DROPPED — PRESS U TO UNDO"))
        #expect(editor.plan.entries.map(\.source) == [0, 2, 3])
        #expect(editor.plan.total == 900)
    }

    /// **D65.** `tui_drop` returns nonzero on a header row and on the last
    /// remaining track, and `burncd:1193` calls it as `tui_drop "$cur" &&
    /// status=…`, which swallows the refusal — so `x` on the last track does
    /// nothing and says nothing. That is the exact failure `tui_break` was
    /// written to avoid, three functions further down and in the script's own
    /// words. The principle is the script's; only this application is new.
    @Test("X on the last track declines out loud, and on a header row too")
    func dropRefusals() throws {
        var editor = try editor(1)
        editor.moveCursor(to: 0)
        editor.drop()
        #expect(editor.status == Readout.status("SELECT A TRACK TO DROP"))
        #expect(editor.plan.entries.count == 1)

        editor.moveCursor(to: 3)
        editor.drop()
        #expect(editor.status == Readout.status("A DISC NEEDS ONE TRACK — THIS IS THE LAST"))
        #expect(editor.plan.entries.count == 1)
        #expect(editor.undoCount == 0)
    }

    /// The whole order goes on the stack first, so a track comes back where it
    /// was rather than on the end — and so does everything else the drop moved
    /// (`burncd:1298`).
    @Test("Undoing a drop puts the track back where it was, not on the end")
    func undoADrop() throws {
        var editor = try editor(4)
        editor.moveCursor(to: 4)
        editor.drop()
        editor.undo()
        #expect(editor.status == Readout.status("TRACK RESTORED"))
        #expect(editor.plan.entries.map(\.source) == [0, 1, 2, 3])
    }

    @Test("Undo says which kind of edit it took back")
    func undoLabels() throws {
        var editor = try editor(4)

        editor.moveCursor(to: 0)
        editor.rename(to: "Another Record")
        editor.undo()
        #expect(editor.status == Readout.status("ALBUM RESTORED"))
        #expect(editor.draft.album == "A Record")

        editor.moveCursor(to: 3)
        editor.rename(to: "Renamed")
        editor.undo()
        #expect(editor.status == Readout.status("TITLE RESTORED"))
        #expect(editor.draft.rows[0].title == "Track 1")

        editor.setArtist(to: "Guest")
        editor.undo()
        #expect(editor.status == Readout.status("ARTIST RESTORED"))

        editor.moveTrack(1)
        editor.undo()
        #expect(editor.status == Readout.status("ORDER RESTORED"))
        #expect(editor.plan.entries.map(\.source) == [0, 1, 2, 3])

        editor.moveCursor(to: 4)
        editor.toggleBreak()
        editor.undo()
        #expect(editor.status == Readout.status("DISC BREAK RESTORED"))
        #expect(editor.plan.discCount == 1)
    }

    /// Succeeds even with nothing to undo, and says so — for the reason
    /// `tui_break` gives about declining silently (`burncd:1324`).
    @Test("U with nothing to undo says so")
    func nothingToUndo() throws {
        var editor = try editor()
        editor.undo()
        #expect(editor.status == Readout.status("NOTHING TO UNDO"))
    }

    /// `UNDO_MAX` (`burncd:1111`). An hour of nudging a running order should not
    /// grow a stack without end, and nobody is undoing ninety edits ago one
    /// keystroke at a time.
    @Test("The stack holds a hundred and then forgets the oldest")
    func undoIsBounded() throws {
        var editor = try editor(2)
        for i in 0..<150 {
            editor.moveCursor(to: 3)
            editor.rename(to: "Title \(i)")
        }
        #expect(editor.undoCount == PlanEditor.undoLimit)
        for _ in 0..<PlanEditor.undoLimit { editor.undo() }
        #expect(editor.undoCount == 0)
        // The oldest hundred are gone, so the first title does not come back.
        #expect(editor.draft.rows[0].title == "Title 49")
        editor.undo()
        #expect(editor.status == Readout.status("NOTHING TO UNDO"))
    }

    /// **D66.** `burncd:1198` restores the order and clears the breaks, and
    /// renames survive it. burncd's README says "Reset to the original tags and
    /// order", which is a wider claim than the code makes, and the standing
    /// rule settles it: where any description conflicts with the script, the
    /// script is right. It is also the better key — a rename is one `U` away
    /// and a shuffled order is not.
    @Test("R restores the order and clears the breaks, and leaves the names alone")
    func reset() throws {
        var editor = try editor(4)
        editor.moveCursor(to: 3)
        editor.rename(to: "Renamed")
        editor.moveTrack(1)
        editor.moveCursor(to: 5)
        editor.toggleBreak()
        #expect(editor.plan.discCount == 2)

        editor.reset()
        #expect(editor.status == Readout.status("ORIGINAL ORDER RESTORED"))
        #expect(editor.plan.entries.map(\.source) == [0, 1, 2, 3])
        #expect(editor.plan.discCount == 1)
        #expect(editor.draft.rows[0].title == "Renamed")
    }

    @Test("The reset itself is one step on the stack")
    func resetIsUndoable() throws {
        var editor = try editor(3)
        editor.moveTrack(1)
        #expect(editor.plan.entries.map(\.source) == [1, 0, 2])
        editor.reset()
        editor.undo()
        #expect(editor.status == Readout.status("PLAN RESTORED"))
        #expect(editor.plan.entries.map(\.source) == [1, 0, 2])
    }

    /// Everything after the running order derives from it, so a reorder is a
    /// rebuild (`burncd:731`). Checked by the thing that would notice: the disc
    /// the tracks land on.
    @Test("The layout is recomputed after every change")
    func replans() throws {
        // Two long tracks and two short ones: which disc the short ones land on
        // depends entirely on the order.
        var editor = try PlanEditor(
            draft: PlanDraft(
                rows: [
                    .init(title: "Long A", artist: "", duration: 3000),
                    .init(title: "Long B", artist: "", duration: 3000),
                    .init(title: "Short", artist: "", duration: 600),
                ],
                order: [0, 1, 2],
                album: "", albumArtist: "", year: "", orderedByFilename: false
            )
        )
        #expect(editor.plan.discCount == 2)
        let before = editor.plan.entries(onDisc: 1).map(\.source)

        editor.moveCursor(to: 5)
        editor.moveTrack(-1)
        #expect(editor.plan.entries.map(\.source) == [0, 2, 1])
        #expect(editor.plan.entries(onDisc: 1).map(\.source) != before)

        editor.moveCursor(to: 4)
        editor.drop()
        #expect(editor.plan.discCount == 2)
        #expect(editor.plan.total == 6000)
    }

    /// The status line is read once by the panel and cleared, exactly as
    /// `tui_edit` clears it after each draw (`burncd:1180`) — a message that
    /// stays up is a message about an edit that already happened.
    @Test("The status line is spent when it is read")
    func statusIsSpent() throws {
        var editor = try editor()
        editor.undo()
        let first = editor.takeStatus()
        let second = editor.takeStatus()
        #expect(first == Readout.status("NOTHING TO UNDO"))
        #expect(second == "")
    }

    /// **Nothing on this screen touches the record on disk.** The editor holds
    /// its own copy of every name, and there is no path from it to the
    /// filesystem — the draft is a value, and this is the assertion that says
    /// the record it came from is unchanged by everything above.
    @Test("Editing the plan does not touch the record it was made from")
    func nothingIsWritten() throws {
        let rows: [PlanDraft.Row] = [
            .init(title: "One", artist: "A", duration: 100),
            .init(title: "Two", artist: "B", duration: 100),
        ]
        let original = PlanDraft(
            rows: rows, order: [0, 1], album: "A Record", albumArtist: "Someone",
            year: "1979", orderedByFilename: false
        )
        var editor = try PlanEditor(draft: original)
        editor.moveCursor(to: 3)
        editor.rename(to: "Something Else")
        editor.setArtist(to: "Nobody")
        editor.drop()
        editor.moveCursor(to: 0)
        editor.rename(to: "Not That Record")

        #expect(original.rows.map(\.title) == ["One", "Two"])
        #expect(original.rows.map(\.artist) == ["A", "B"])
        #expect(original.album == "A Record")
        #expect(original.order == [0, 1])
    }

    /// The untagged note is read off the folder once and left alone
    /// (`burncd:432`): dropping the one untagged track does not turn it off,
    /// because the order on screen was still arrived at by filename and that is
    /// what the note warns about.
    @Test("The filename note survives the editing")
    func noteSurvives() throws {
        var editor = try PlanEditor(
            draft: PlanDraft(
                rows: [
                    .init(title: "One", artist: "", duration: 100),
                    .init(title: "Two", artist: "", duration: 100),
                ],
                order: [0, 1], album: "", albumArtist: "", year: "",
                orderedByFilename: true
            )
        )
        #expect(editor.plan.orderNote == "filename (some files have no track number)")
        editor.moveCursor(to: 3)
        editor.drop()
        #expect(editor.plan.orderNote == "filename (some files have no track number)")
    }
}
