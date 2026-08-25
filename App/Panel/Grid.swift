import MUTHURKit
import SwiftUI

/// The panel is set on a character grid, and this is what makes that literally
/// true on screen rather than nearly true.
///
/// Every measurement below is `Theme.cell` multiplied by a column count that
/// came out of `MUTHURKit/Panel` — so the 52 columns `TrackColumns` handed the
/// titles are 52 columns wide here, and the duration at the end of a row lands
/// on the same edge as the end of the meter three blocks down. Nothing in the
/// views is allowed to guess at a width; it asks for columns.
@MainActor
enum Grid {

    static func columns(_ count: Int) -> CGFloat { CGFloat(count) * Theme.cell.width }

    static func rows(_ count: Int) -> CGFloat { CGFloat(count) * Theme.cell.height }

    /// The two columns of margin every line on the panel starts with
    /// (`player:2325`).
    static var margin: CGFloat { columns(PanelGrid.margin) }
}

extension View {

    /// One line of the panel. Fixed height so a row of glyphs, a row of `Text`
    /// and a `Canvas` bar all occupy exactly one line — which is the only reason
    /// the blocks stay in register with each other as the window changes size.
    func gridLine() -> some View {
        frame(height: Theme.cell.height, alignment: .leading)
    }

    /// A whole line's worth of nothing. The script printed `\n` between blocks
    /// and the rhythm it made is doing work: without them the header, the list
    /// and the meters read as one wall of text.
    func panelRow() -> some View {
        frame(maxWidth: .infinity, alignment: .leading).gridLine()
    }
}

/// A run of grid text in one colour. Returned as `Text` rather than as a view so
/// runs can be concatenated with `+` and stay a single line of type — a row
/// assembled out of separate views would let the layout put its own space
/// between the pieces, and the arithmetic would stop being true.
func run(_ text: String, _ colour: Color) -> Text {
    Text(verbatim: text).foregroundColor(colour)
}

/// The same, padded or cut to an exact column count.
func run(_ text: String, _ colour: Color, columns count: Int, align: Columns.Align = .leading)
    -> Text
{
    run(Columns.fit(text, to: count, align: align), colour)
}

/// The rule down the side of an instrument — `▐` on the left, `▌` on the right
/// (`panel.sh:455`).
///
/// Drawn rather than typed, and this one is not a taste call. The glyph is a
/// half block that fills its *em* box, and a line here is taller than the em
/// box, so a column of them comes out as a dashed line with a gap at every row
/// boundary. The analyser is five lines tall and its bezel has to be one
/// unbroken rule, so the shape the glyph means is filled directly: half a
/// column, the full height of however many lines it is standing beside.
struct Bezel: View {
    enum Side { case left, right }

    let side: Side
    var lines: Int = 1

    var body: some View {
        Canvas { context, size in
            let half = size.width / 2
            context.fill(
                Path(
                    CGRect(
                        x: side == .left ? half : 0, y: 0,
                        width: half, height: size.height)),
                with: .color(Theme.etch))
        }
        .frame(width: Grid.columns(1), height: Grid.rows(lines))
    }
}

/// A blank line.
struct PanelBlank: View {
    var body: some View {
        Color.clear.frame(height: Theme.blank)
    }
}
