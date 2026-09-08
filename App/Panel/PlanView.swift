import MUTHURKit
import SwiftUI

/// §20.4 — the plan editor, drawn on the panel (`tui_frame`, `burncd:936`).
///
/// Three header fields and then the running order, selected by one cursor over
/// one list, with a rule wherever a disc changes hands and a meter under it for
/// whichever disc the cursor is standing on. It is the same furniture the deck
/// uses — `MatrixText`, `Grid`, `MeterView` — because it is the same instrument
/// showing a different thing, not a different instrument.
///
/// **Nothing on this screen writes to the record on disk.** `PlanEditor` says
/// why at more length; it is repeated here because this is the half that looks
/// like a tag editor.
struct PlanView: View {
    let editor: PlanEditor
    let visibleRange: Range<Int>
    let below: Int
    let prompt: PanelModel.PlanPrompt?
    let click: (Int) -> Void
    let typed: (String) -> Void
    let commit: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            fields
            PanelBlank()
            notes
            tracks
            if below > 0 { moreRow }
            PanelBlank()
            meter
            if let prompt {
                PanelBlank()
                PlanPromptView(
                    prompt: prompt, typed: typed, commit: commit, cancel: cancel)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - The three fields

    /// `tui_field` (`burncd:960`). They sit on the same mark-plus-body grid as
    /// the tracks, so the selection bar is the same width wherever the cursor
    /// is — which is the whole reason the header and the list are one cursor.
    private var fields: some View {
        let values = PlanScreen.headerFields(editor.draft)
        return ForEach(Array(values.enumerated()), id: \.offset) { slot, field in
            let selected = editor.cursor == slot
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.margin)
                run(selected ? Readout.cursorGlyph : " ", Theme.lit)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(1), alignment: .leading)
                Spacer().frame(width: Grid.columns(1))
                HStack(spacing: 0) {
                    MatrixText(
                        text: field.label, colour: selected ? Theme.text : Theme.etch,
                        columns: 7)
                    Spacer().frame(width: Grid.columns(1))
                    run(field.value, Theme.text, columns: PlanScreen.Cells.width - 8)
                        .font(Theme.swiftUIFont)
                    Spacer(minLength: 0)
                }
                .frame(width: Grid.columns(PlanScreen.Cells.width), alignment: .leading)
                .background(selected ? Theme.cursorPlate : Color.clear)
                Spacer(minLength: 0)
            }
            .gridLine()
            .contentShape(Rectangle())
            .onTapGesture { click(slot) }
        }
    }

    // MARK: - What the plan has to say (D67)

    private var notes: some View {
        let lines = PlanScreen.notes(editor.plan)
        return Group {
            if !lines.isEmpty {
                ForEach(lines, id: \.self) { line in
                    HStack(spacing: 0) {
                        Spacer().frame(width: Grid.columns(PanelGrid.gutter))
                        run(line, Theme.etch, columns: PanelGrid.width - PanelGrid.gutter)
                            .font(Theme.swiftUIFont)
                        Spacer(minLength: 0)
                    }
                    .gridLine()
                }
                PanelBlank()
            }
        }
    }

    // MARK: - The running order

    /// The list, with a rule wherever the disc changes. The rule is drawn from
    /// the disc the *first* entry of a source landed on, so a track cut across
    /// a boundary belongs to the disc its row says it starts on.
    private var tracks: some View {
        let order = editor.draft.order
        return ForEach(Array(visibleRange), id: \.self) { position in
            let source = order[position]
            let disc = editor.plan.firstDisc(ofSource: source) ?? 1
            let previous =
                position > visibleRange.lowerBound
                ? editor.plan.firstDisc(ofSource: order[position - 1]) ?? 1 : 0
            VStack(alignment: .leading, spacing: 0) {
                if disc != previous {
                    HStack(spacing: 0) {
                        Spacer().frame(width: Grid.margin)
                        run(
                            PlanScreen.discRule(
                                disc,
                                forced: position > 0 && editor.draft.breaks.contains(source)),
                            Theme.etch
                        )
                        .font(Theme.swiftUIFont)
                        Spacer(minLength: 0)
                    }
                    .gridLine()
                }
                PlanRowView(
                    number: position + 1,
                    row: editor.draft.rows[source],
                    cursor: editor.cursor == PlanEditor.headerRows + position
                )
                .contentShape(Rectangle())
                .onTapGesture { click(PlanEditor.headerRows + position) }
            }
        }
    }

    private var moreRow: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.columns(PanelGrid.gutter))
            run(Readout.more(below), Theme.etch).font(Theme.swiftUIFont)
            Spacer(minLength: 0)
        }
        .gridLine()
    }

    // MARK: - The disc meter

    /// `strip` (`burncd:814`) — the disc the cursor is on, against a whole
    /// blank. The bands are the tracks on that disc, so a reorder shows up in
    /// the shape of the bar while you are still doing it.
    ///
    /// It does not seek, because there is nothing here to seek: this is a bar
    /// full of a plan, not of a playhead. The deck's two meters are gone from
    /// this screen for the same reason.
    private var meter: some View {
        let disc = PlanScreen.meteredDisc(editor)
        let plan = editor.plan
        let durations = plan.entries(onDisc: disc).map(\.duration)
        let units = PanelGrid.stripWidth * Meter.unitsPerCell
        let filled = min(units, plan.runtime(onDisc: disc) * units / plan.capacity)
        // The bands share only as much of the bar as the disc is full and the
        // rest is run-out, where the album meter's bands share the whole bar.
        // And the head is at the far end: nothing on a plan is unwritten, so
        // every band is lit rather than half of them (`burncd:836`).
        let bands = Meter.bands(units: filled, durations: durations)
        return MeterView(
            label: PlanScreen.discLabel(disc),
            position: plan.runtime(onDisc: disc),
            length: plan.capacity,
            cells: Meter.cells(head: units, bands: bands, width: PanelGrid.stripWidth),
            seek: { _, _ in }
        )
    }
}

/// One track in the editor's four columns (`track_row`, `burncd:927`).
///
/// The selected row is one reverse bar across all four cells rather than four
/// highlighted cells, which is why the widths are laid out inside a single
/// frame: an inner colour reset would punch a hole in the highlight partway
/// along, and the script says so at `burncd:916`.
private struct PlanRowView: View {
    let number: Int
    let row: PlanDraft.Row
    let cursor: Bool

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            run(cursor ? Readout.cursorGlyph : " ", Theme.lit)
                .font(Theme.swiftUIFont)
                .frame(width: Grid.columns(1), alignment: .leading)
            Spacer().frame(width: Grid.columns(1))
            HStack(spacing: 0) {
                run(String(format: "%02d", number), cursor ? Theme.text : Theme.etch)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(PlanScreen.Cells.number), alignment: .leading)
                Spacer().frame(width: Grid.columns(PlanScreen.Cells.gap))
                run(row.title, Theme.text, columns: PlanScreen.Cells.title)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(PlanScreen.Cells.title), alignment: .leading)
                Spacer().frame(width: Grid.columns(PlanScreen.Cells.gap))
                run(row.artist, cursor ? Theme.text : Theme.dim, columns: PlanScreen.Cells.artist)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(PlanScreen.Cells.artist), alignment: .leading)
                Spacer().frame(width: Grid.columns(PlanScreen.Cells.gap))
                run(
                    Readout.mmss(row.duration), cursor ? Theme.text : Theme.etch,
                    columns: PlanScreen.Cells.time, align: .trailing
                )
                .font(Theme.swiftUIFont)
                .frame(width: Grid.columns(PlanScreen.Cells.time), alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(width: Grid.columns(PlanScreen.Cells.width), alignment: .leading)
            .background(cursor ? Theme.cursorPlate : Color.clear)
            Spacer(minLength: 0)
        }
        .gridLine()
    }
}

/// `tui_prompt` (`burncd:893`) — the one row on the panel you can type into.
///
/// A real text field rather than a hand-rolled key buffer, because the script's
/// prompt is a *cooked-mode* read: the terminal gives it paste, kill-line and
/// whatever the input method wanted to say, and re-implementing a third of a
/// line editor on top of `onKeyPress` would give a worse one. It wears the
/// panel's own font so it is still the panel talking.
///
/// The current value is shown in brackets and dim, as a hint — typing nothing
/// keeps it, which is the script's only way out of the prompt and all it needs.
private struct PlanPromptView: View {
    let prompt: PanelModel.PlanPrompt
    let typed: (String) -> Void
    let commit: () -> Void
    let cancel: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            run(Readout.cursorGlyph, Theme.lit).font(Theme.swiftUIFont)
            Spacer().frame(width: Grid.columns(1))
            MatrixText(text: prompt.label, colour: Theme.etch, columns: 7)
            Spacer().frame(width: Grid.columns(1))
            TextField(
                "",
                text: Binding(get: { prompt.value }, set: typed),
                prompt: Text("[\(prompt.current.isEmpty ? "empty" : prompt.current)]")
                    .foregroundStyle(Theme.dim)
            )
            .textFieldStyle(.plain)
            .font(Theme.swiftUIFont)
            .foregroundStyle(Theme.text)
            .tint(Theme.lit)
            .focused($focused)
            .onSubmit(commit)
            .onExitCommand(perform: cancel)
            .onAppear { focused = true }
            Spacer(minLength: 0)
        }
        .gridLine()
    }
}
