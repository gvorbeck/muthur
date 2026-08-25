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
                HStack(spacing: 0) {
                    Spacer().frame(width: Grid.columns(PanelGrid.gutter))
                    MatrixText(
                        text: row.label, colour: Theme.etch,
                        columns: HeaderBlock.labelWidth)
                    Spacer().frame(width: Grid.columns(1))
                    run(
                        Columns.truncate(row.value, to: PanelGrid.textWidth),
                        row.annotated ? Theme.lit : Theme.text
                    )
                    .font(Theme.swiftUIFont)
                    Spacer(minLength: 0)
                }
                .gridLine()
            }
        }
    }
}
