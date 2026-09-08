import Foundation
import Testing

@testable import MUTHURKit

// MARK: - §20.5 What the plan screen says

@Suite("§20.5 — the plan screen")
struct PlanScreenTests {

    private func draft(
        _ count: Int, each: Int = 300, byFilename: Bool = false
    ) -> PlanDraft {
        PlanDraft(
            rows: (0..<count).map {
                PlanDraft.Row(
                    title: "Track \($0 + 1)", artist: "Artist \($0 + 1)", duration: each
                )
            },
            order: Array(0..<count),
            album: "A Record", albumArtist: "Someone", year: "1979",
            orderedByFilename: byFilename
        )
    }

    // MARK: The faceplate

    /// Both plurals are worked out rather than written `(S)`: a one-track plan
    /// on one disc reads `1 TRACK · 3:07 · 1 DISC` and anything else is a
    /// machine talking (`burncd:947`).
    @Test("Both plurals are counted, and a plan of one says so")
    func meta() throws {
        let one = try BurnPlan.make(draft: draft(1, each: 187))
        #expect(PlanScreen.meta(one) == "1 TRACK · 3:07 · 1 DISC")
        let many = try BurnPlan.make(draft: draft(11, each: 300))
        #expect(PlanScreen.meta(many) == "11 TRACKS · 55:00 · 1 DISC")
        let two = try BurnPlan.make(draft: draft(30, each: 300))
        #expect(PlanScreen.meta(two).hasSuffix("· 2 DISCS"))
    }

    // MARK: The header fields

    /// An empty field shows an em dash rather than nothing (`burncd:961`): a
    /// blank where a value goes reads as a screen that failed to draw, and a
    /// dash reads as a record with no year on it, which is what it is.
    @Test("An empty header field is a dash, not a gap")
    func emptyFieldsAreDashed() {
        var bare = draft(2)
        bare.album = ""
        bare.year = ""
        let fields = PlanScreen.headerFields(bare)
        #expect(fields.map(\.label) == ["ALBUM", "ARTIST", "YEAR"])
        #expect(fields[0].value == "—")
        #expect(fields[1].value == "Someone")
        #expect(fields[2].value == "—")
    }

    // MARK: The disc rules

    /// The rule is shortened by exactly what the label costs, which keeps every
    /// disc rule the same sixty-nine columns as the rest of the grid
    /// (`burncd:980`).
    @Test("Every disc rule is the full width of the panel, label or no label")
    func discRulesAreOneWidth() {
        for disc in [1, 2, 9, 10, 99] {
            for forced in [false, true] {
                let rule = PlanScreen.discRule(disc, forced: forced)
                #expect(Columns.width(of: rule) == PanelGrid.width - 2)
            }
        }
    }

    /// A boundary you set reads differently from one the balancer worked out,
    /// so it says so — without that, `S` is a key whose whole effect is to move
    /// a line that was going to be somewhere anyway.
    @Test("A forced break is named on the rule and a balanced one is not")
    func forcedRulesSaySo() {
        #expect(PlanScreen.discRule(2, forced: true).hasPrefix("━━ DISC 2 · SPLIT "))
        #expect(PlanScreen.discRule(2, forced: false).hasPrefix("━━ DISC 2 ━"))
    }

    // MARK: The row

    /// The four cells add up to the panel less the two columns the cursor mark
    /// stands in, which is why the selected row's reverse bar is exactly that
    /// wide (`burncd:919`).
    @Test("A track row is exactly as wide as the bar that highlights it")
    func cellsFillTheRow() {
        #expect(PlanScreen.Cells.width == 67)
        #expect(
            PlanScreen.Cells.width == PanelGrid.width - (PanelGrid.gutter - PanelGrid.margin))
    }

    // MARK: The meter

    /// The disc the cursor is standing on, so the effect of a reorder on disc
    /// fullness is visible while you are doing it. On a header field there is
    /// no track to follow, and a gauge that disappears is worse than one that
    /// idles (`burncd:1005`).
    @Test("The meter follows the cursor, and idles on disc 1 above the tracks")
    func meterFollowsTheCursor() throws {
        var editor = try PlanEditor(draft: draft(30, each: 300))
        #expect(editor.plan.discCount == 2)
        editor.moveCursor(to: 0)
        #expect(PlanScreen.meteredDisc(editor) == 1)
        editor.moveCursor(to: editor.rowCount - 1)
        #expect(PlanScreen.meteredDisc(editor) == 2)
        editor.moveCursor(to: PlanEditor.headerRows)
        #expect(PlanScreen.meteredDisc(editor) == 1)
    }

    /// A cut track is on two discs and the row on screen belongs to the one it
    /// starts on.
    @Test("A source that was cut is metered against the disc it starts on")
    func firstDiscOfACutTrack() throws {
        let long = PlanDraft(
            rows: [PlanDraft.Row(title: "The Set", artist: "", duration: 5700)],
            order: [0], album: "", albumArtist: "", year: "", orderedByFilename: false
        )
        let plan = try BurnPlan.make(draft: long, splitLong: true)
        #expect(plan.entries.count == 2)
        #expect(plan.discCount == 2)
        #expect(plan.firstDisc(ofSource: 0) == 1)
        #expect(plan.firstDisc(ofSource: 9) == nil)
    }

    // MARK: D67 — what `plan_header` would have said

    /// An ordinary album says nothing and spends no rows saying it.
    @Test("A plan with nothing wrong with it carries no notes")
    func quietPlan() throws {
        let plan = try BurnPlan.make(draft: draft(11))
        #expect(PlanScreen.notes(plan).isEmpty)
    }

    /// The two things `plan_header` says that nothing else says, on a panel
    /// that always has a screen (`burncd:740`).
    @Test("A split and a filename order are both said out loud")
    func loudPlan() throws {
        let split = try BurnPlan.make(draft: draft(30, each: 300))
        let notes = PlanScreen.notes(split)
        #expect(notes.contains { $0.contains("Splitting across 2 discs") })
        #expect(notes.contains { $0.contains("too long for one disc") })

        let guessed = try BurnPlan.make(draft: draft(4, byFilename: true))
        #expect(
            PlanScreen.notes(guessed) == [
                "Ordered by filename (some files have no track number)"
            ])
    }

    /// Kept inside the panel's own columns like every other line on it: a note
    /// too long for the frame wraps, which costs the frame a row it did not
    /// budget for.
    @Test("Every note fits the panel it is printed on")
    func notesFit() throws {
        let plan = try BurnPlan.make(draft: draft(120, each: 30, byFilename: true))
        let notes = PlanScreen.notes(plan)
        #expect(!notes.isEmpty)
        for note in notes {
            #expect(Columns.width(of: note) <= PanelGrid.width - PanelGrid.gutter)
        }
    }

    // MARK: The two refusals

    /// One line, in the panel's voice, and only the half this screen can act
    /// on — `--split-long` is a flag on a command line the panel does not have.
    @Test("A plan that cannot be made is refused in one line that fits")
    func refusals() {
        let long = PlanScreen.refusal(
            .trackLongerThanDisc(title: "The Set", duration: 5700, capacity: 4797))
        #expect(long == "A TRACK IS 1:35:00 — LONGER THAN A 1:19:57 DISC")
        #expect(Columns.width(of: Readout.status(long)) <= PanelGrid.width)

        let empty = PlanScreen.refusal(.nothingToBurn)
        #expect(Columns.width(of: Readout.status(empty)) <= PanelGrid.width)
    }

    /// The key stays live and answers, because dimming it would be the same lie
    /// the dead ⌘O was.
    @Test("The burn refusal fits the status row it is printed on")
    func burnRefusalFits() {
        #expect(
            Columns.width(of: Readout.status(PlanScreen.burnNotYet)) <= PanelGrid.width)
    }
}
