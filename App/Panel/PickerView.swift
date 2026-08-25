import MUTHURKit
import SwiftUI

/// The source picker, shown inside the panel when `model.isPicking`.
///
/// Same design primitives as the playing panel: `MatrixText`, `Grid`,
/// `PanelGrid`, `Theme`. The list uses the same cursor-highlight treatment
/// `TrackListView` does — a reverse bar with a `▶` glyph in the gutter.
struct PickerView: View {
    let entries: [PickerEntry]
    let cursor: Int
    let visibleRange: Range<Int>
    let below: Int
    let click: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.margin)
                MatrixText(text: "SELECT A SOURCE", colour: Theme.lit)
                Spacer(minLength: 0)
            }
            .gridLine()

            PanelBlank()

            // Source list
            ForEach(Array(visibleRange), id: \.self) { index in
                PickerRowView(
                    entry: entries[index],
                    cursor: index == cursor
                )
                .contentShape(Rectangle())
                .onTapGesture { click(index) }
            }

            if below > 0 {
                HStack(spacing: 0) {
                    Spacer().frame(width: Grid.columns(PanelGrid.gutter))
                    run(Readout.more(below), Theme.etch).font(Theme.swiftUIFont)
                    Spacer(minLength: 0)
                }
                .gridLine()
            }

            Spacer(minLength: 0)
        }
    }
}

/// One row in the picker: mark, label, detail.
private struct PickerRowView: View {
    let entry: PickerEntry
    let cursor: Bool

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            run(cursor ? Readout.cursorGlyph : " ", Theme.lit)
                .font(Theme.swiftUIFont)
                .frame(width: Grid.columns(1), alignment: .leading)
            Spacer().frame(width: Grid.columns(1))
            HStack(spacing: 0) {
                run(entry.mark, cursor ? Theme.text : Theme.lit)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(2), alignment: .leading)
                Spacer().frame(width: Grid.columns(1))
                run(entry.label, Theme.text, columns: labelColumns)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(labelColumns), alignment: .leading)
                Spacer().frame(width: Grid.columns(2))
                run(entry.detail, cursor ? Theme.dim : Theme.etch, columns: detailColumns, align: .trailing)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(detailColumns), alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(
                width: Grid.columns(PanelGrid.width - PanelGrid.gutter), alignment: .leading
            )
            .background(cursor ? Theme.cursorPlate : Color.clear)
            Spacer(minLength: 0)
        }
        .gridLine()
    }

    // mark(2) + gap(1) + label + gap(2) + detail = width - gutter
    private var labelColumns: Int { 35 }
    private var detailColumns: Int {
        PanelGrid.width - PanelGrid.gutter - 2 - 1 - labelColumns - 2
    }
}
