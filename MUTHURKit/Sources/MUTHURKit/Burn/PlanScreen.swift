import Foundation

/// §20.4 — the fixed words on the plan screen.
///
/// The drawing is in `App/`; the strings are here, where they can be measured
/// against the 69 columns without a window.
public enum PlanScreen {

    /// The faceplate's line (`burncd:947`): `11 TRACKS · 41:53 · 1 DISC`.
    ///
    /// Both plurals are worked out rather than written `(S)`, because a
    /// one-track plan on one disc reads `1 TRACK · 3:07 · 1 DISC` and anything
    /// else is a machine talking.
    public static func meta(_ plan: BurnPlan) -> String {
        let tracks = plan.entries.count
        let discs = plan.discCount
        return
            "\(tracks) TRACK\(tracks == 1 ? "" : "S") · \(Readout.mmss(plan.total)) "
            + "· \(discs) DISC\(discs == 1 ? "" : "S")"
    }

    /// The three header fields, in the order they are drawn and selected.
    ///
    /// An empty field shows an em dash rather than nothing (`burncd:961`): a
    /// blank where a value goes reads as a screen that failed to draw, and a
    /// dash reads as a record with no year on it, which is what it is.
    public static func headerFields(_ draft: PlanDraft) -> [(label: String, value: String)] {
        [
            ("ALBUM", draft.album.isEmpty ? "—" : draft.album),
            ("ARTIST", draft.albumArtist.isEmpty ? "—" : draft.albumArtist),
            ("YEAR", draft.year.isEmpty ? "—" : draft.year),
        ]
    }

    /// The rule that opens a disc (`burncd:980`).
    ///
    /// **A boundary you set reads differently from one the balancer worked
    /// out**, so it says so. Without that, `S` is a key whose whole effect is
    /// to move a line that was going to be somewhere anyway, and there is no
    /// way to tell your break from the arithmetic's.
    ///
    /// The rule is shortened by exactly what the label costs, which keeps every
    /// disc rule the same 69 columns as the rest of the grid.
    public static func discRule(_ disc: Int, forced: Bool, width: Int = PanelGrid.width) -> String {
        let label = forced ? " · SPLIT" : ""
        let head = "━━ DISC \(disc)\(label) "
        let rule = max(0, width - 2 - Columns.width(of: head))
        return head + String(repeating: "━", count: rule)
    }

    /// Which disc's meter to show — the one the cursor is sitting on, so the
    /// effect of a reorder on disc fullness is visible while you are doing it.
    ///
    /// On the header fields there is no track to follow, so it falls back to
    /// disc 1 rather than going blank (`burncd:1005`): a gauge that disappears
    /// is worse than one that idles.
    public static func meteredDisc(_ editor: PlanEditor) -> Int {
        guard let source = editor.selectedSource,
            let disc = editor.plan.firstDisc(ofSource: source)
        else { return 1 }
        return disc
    }

    /// `DISC 2` — the label over that meter.
    public static func discLabel(_ disc: Int) -> String { "DISC \(disc)" }

    /// **D67 — the two lines `plan_header` would have said, on a panel that
    /// always has a screen.**
    ///
    /// `plan_header` is "the static plan, printed instead of the panel when
    /// there is no screen to draw one on" — the script's own comment at
    /// `burncd:740` — so in a window it never runs at all, and the things it
    /// says that no other part of the program says would simply be lost. Two of
    /// them matter here: which limit forced a second disc, and that the running
    /// order was arrived at by filename because some files carry no track
    /// number. Both are facts about an order that is a moment away from being
    /// burnt into a lead-in permanently, and the editor is the last place
    /// anyone can act on them.
    ///
    /// The rest of that header is not lost and is not here: the counts and the
    /// runtime are on the faceplate, and the level pass and the CD-Text switch
    /// belong to stages 2 and 3.
    ///
    /// Empty for the ordinary album, which is the point — a plan with nothing
    /// wrong with it says nothing and spends no rows saying it.
    public static func notes(_ plan: BurnPlan) -> [String] {
        var lines: [String] = []
        if let sentence = plan.splitSentence { lines.append(sentence) }
        lines.append(contentsOf: plan.splitNotes)
        if plan.orderedByFilename { lines.append("Ordered by \(plan.orderNote)") }
        return lines
    }

    /// A plan that could not be made at all, in one line, for the status row.
    ///
    /// `PlanFailure.description` is two lines — the refusal and its remedy —
    /// and the remedy is `--split-long`, a flag on `burncd`'s command line that
    /// this panel has no switch for. Printing a fix nobody on this screen can
    /// reach is the dead ⌘O again, so the panel says the half it can act on, in
    /// the panel's voice; the whole message is still what the command line
    /// prints when there is a command line to print it.
    public static func refusal(_ failure: PlanFailure) -> String {
        switch failure {
        case .trackLongerThanDisc(_, let duration, let capacity):
            "A TRACK IS \(Readout.mmss(duration)) — LONGER THAN A \(Readout.mmss(capacity)) DISC"
        case .nothingToBurn:
            "NOTHING ON THE DECK TO BURN"
        }
    }

    /// **The refusal at the end of the editor, until stage 3.**
    ///
    /// Worded the way `LaunchOptions.Failure` refuses a flag it does not have:
    /// what is true, in one line, with no apology and no offer to do it later.
    /// The drive is not connected and there is no `cdrecord` here — dimming the
    /// cap instead would be the same lie the dead ⌘O was, so the key stays live
    /// and answers.
    ///
    /// In the panel's voice rather than the command line's, because this is
    /// printed on the status row beside `TRACK DROPPED — PRESS U TO UNDO` and
    /// not to a terminal.
    public static let burnNotYet =
        "BURNING IS NOT WIRED UP YET — THE PLAN IS RIGHT, THE DRIVE IS NOT"

    /// The four columns a track row is laid out in (`track_cells`,
    /// `burncd:919`).
    ///
    /// Fixed, where the deck's `TrackColumns` are worked out from the record.
    /// The editor and the disc prompt are showing the same list on purpose —
    /// "the prompt is where the editor's work gets checked, and a listing you
    /// cannot compare at a glance is not a check" — so the widths are one fact
    /// in one place and the two screens move together.
    public enum Cells {
        public static let number = 2
        public static let title = 34
        public static let artist = 20
        public static let time = 5
        public static let gap = 2

        /// 67 — the panel less the two columns the cursor mark stands in, which
        /// is why the selected row's reverse bar is exactly this wide.
        public static var width: Int { number + gap + title + gap + artist + gap + time }
    }
}
