import MUTHURKit
import SwiftUI

/// The analyser, under the album meter where `burncd` puts its minute scale.
///
/// Sixteen bars of three columns with a column between them is 63 of the 67
/// inside the rules, and two columns of margin either side make up the rest
/// (`player:653`). Kept to the column exactly, because the analyser and the two
/// meters share their bezels and a bar half a column out of true would show.
struct AnalyserView: View {
    let grid: [[AnalyserColumns.Cell]]

    static let barColumns = 3
    static let gapColumns = 1
    static let sideColumns = 2

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            Bezel(side: .left, lines: AnalyserColumns.rows)

            Canvas { context, size in
                let column = size.width / CGFloat(PanelGrid.stripWidth)
                let rowHeight = size.height / CGFloat(AnalyserColumns.rows)

                for (row, cells) in grid.enumerated() {
                    let top = CGFloat(row) * rowHeight
                    for (band, cell) in cells.enumerated() {
                        let left =
                            column
                            * CGFloat(
                                Self.sideColumns
                                    + band * (Self.barColumns + Self.gapColumns))
                        let bar = column * CGFloat(Self.barColumns)

                        switch cell {
                        case .field:
                            // `···` in the field colour rather than nothing: a
                            // blank panel is what a broken one shows.
                            let dot = max(1, column * 0.18)
                            for pip in 0..<Self.barColumns {
                                let x = left + column * (CGFloat(pip) + 0.5) - dot / 2
                                context.fill(
                                    Path(
                                        ellipseIn: CGRect(
                                            x: x, y: top + rowHeight / 2 - dot / 2,
                                            width: dot, height: dot)),
                                    with: .color(Theme.amber(.field)))
                            }

                        case .floor:
                            // The power on and nothing moving.
                            let lip = rowHeight / 8
                            context.fill(
                                Path(
                                    CGRect(
                                        x: left, y: top + rowHeight - lip,
                                        width: bar, height: lip)),
                                with: .color(Theme.amber(.deep)))

                        case .fill(let eighths, let shade):
                            let height = rowHeight * CGFloat(eighths) / 8
                            context.fill(
                                Path(
                                    CGRect(
                                        x: left, y: top + rowHeight - height,
                                        width: bar, height: height)),
                                with: .color(Theme.amber(shade)))

                        case .trail(let shade, let density):
                            let alpha: Double =
                                switch density {
                                case .dense: 0.75
                                case .medium: 0.45
                                case .light: 0.22
                                }
                            context.fill(
                                Path(
                                    CGRect(x: left, y: top, width: bar, height: rowHeight)),
                                with: .color(Theme.amber(shade).opacity(alpha)))
                        }
                    }
                }
            }
            .frame(
                width: Grid.columns(PanelGrid.stripWidth),
                height: Grid.rows(AnalyserColumns.rows))

            Bezel(side: .right, lines: AnalyserColumns.rows)
            Spacer(minLength: 0)
        }
        .frame(height: Grid.rows(AnalyserColumns.rows))
    }
}
