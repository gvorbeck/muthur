import MUTHURKit
import SwiftUI

/// What the record is: album, artist, where the titles came from, and what the
/// shelf says about it when it is on the shelf (`player:2325`).
///
/// The labels are the chrome's own lettering and the values are not. That split
/// is the same one the whole panel is built on — `ALBUM` is a word this program
/// chose and can therefore afford to draw itself, and the album's name is
/// somebody else's text in an alphabet the character generator has never heard
/// of.
struct HeaderView: View {
    let block: HeaderBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(block.rows, id: \.label) { row in
                FieldRow(
                    label: row.label, value: row.value,
                    colour: row.annotated ? Theme.lit : Theme.text)
            }
        }
    }
}

/// A label and its value, in the header block's columns (`player:2325`) —
/// wherever a screen has one. The deck's header, the loading screen, the plan
/// editor's three fields and the insert stage's two all put the value at the
/// same column, because they are the same column (D90): a field that starts one
/// place to the left on the next screen reads as the whole panel jumping.
///
/// `cursor` is nil on a row nothing can select, and the plate is drawn only on a
/// row that can be — the same width as a track row's, so the bar does not change
/// size as the cursor walks from the fields into the list.
struct FieldRow: View {
    let label: String
    let value: String
    var colour: Color = Theme.text
    var cursor: Bool? = nil

    var body: some View {
        let selected = cursor == true
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            run(selected ? Readout.cursorGlyph : " ", Theme.lit)
                .font(Theme.swiftUIFont)
                .frame(width: Grid.columns(1), alignment: .leading)
            Spacer().frame(width: Grid.columns(1))
            HStack(spacing: 0) {
                MatrixText(
                    text: label, colour: selected ? Theme.text : Theme.etch,
                    columns: HeaderBlock.labelWidth)
                Spacer().frame(width: Grid.columns(1))
                run(Columns.truncate(value, to: PanelGrid.textWidth), colour)
                    .font(Theme.swiftUIFont)
                Spacer(minLength: 0)
            }
            .frame(width: Grid.columns(PanelGrid.width - PanelGrid.gutter), alignment: .leading)
            .background(selected ? Theme.cursorPlate : Color.clear)
            Spacer(minLength: 0)
        }
        .gridLine()
    }
}
