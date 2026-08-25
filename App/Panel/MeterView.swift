import MUTHURKit
import SwiftUI

/// A meter: its label row, and the strip in its bezels.
///
/// The label sits on the left and the counter on the right, with the pad between
/// them worked out from the finished `0:00 / 0:00` string — the same arithmetic
/// `burncd`'s capacity meter uses, so both readouts land on the same right-hand
/// edge as the bars under them (`player:2380`).
struct MeterView: View {
    let label: String
    let position: Int
    let length: Int
    let cells: [Meter.Cell]
    /// What to do when the needle is put somewhere. `dragging` is false for the
    /// press that starts it and true for every position it reports on the way.
    let seek: (Int, Bool) -> Void

    private var counter: String { Readout.counter(position, length) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The label is the chrome's lettering and the counter is a readout,
            // so they are made of different things — dots and segments — and the
            // pad between them is still the pad `burncd` worked out, so both
            // land on the same right-hand edge as the bar underneath.
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.margin)
                MatrixText(text: label, colour: Theme.etch)
                Spacer().frame(
                    width: Grid.columns(
                        max(
                            0,
                            PanelGrid.width - Columns.width(of: label)
                                - Columns.width(of: counter))))
                SegmentText(text: Readout.mmss(position), colour: Theme.lit)
                run(" / ", Theme.etch).font(Theme.swiftUIFont)
                SegmentText(text: Readout.mmss(length), colour: Theme.dim)
                Spacer(minLength: 0)
            }
            .gridLine()

            StripView(cells: cells, seek: seek)
        }
    }
}

/// The strip itself, in its bezels.
///
/// Drawn rather than typed. The script had eighth-cell partial blocks because a
/// terminal gave it nothing finer, and the reason it wanted them — that a few
/// cells should still be able to say a 3:14 is longer than a 2:58 — is better
/// served here by drawing the boundary where it actually falls. The eighths
/// still arrive from `Meter`, because that is the arithmetic that decides which
/// band a column belongs to; what changes is that they are no longer rounded to
/// a glyph on the way to the screen.
struct StripView: View {
    let cells: [Meter.Cell]
    let seek: (Int, Bool) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            Bezel(side: .left)

            Canvas { context, size in
                let cellWidth = size.width / CGFloat(PanelGrid.stripWidth)
                for (index, cell) in cells.enumerated() {
                    let x = CGFloat(index) * cellWidth
                    let whole = CGRect(x: x, y: 0, width: cellWidth + 0.5, height: size.height)
                    switch cell {
                    case .runout:
                        // Dithered in the darkest amber on the ramp rather than
                        // left blank, so it still reads as part of the meter.
                        context.fill(Path(whole), with: .color(Theme.runout.opacity(0.45)))
                    case .band(let shade):
                        context.fill(Path(whole), with: .color(Theme.band(shade)))
                    case .boundary(let eighths, let shade, let under):
                        let ground = under.map(Theme.band) ?? Theme.runout.opacity(0.45)
                        context.fill(Path(whole), with: .color(ground))
                        let cut = cellWidth * CGFloat(eighths) / CGFloat(Meter.unitsPerCell)
                        context.fill(
                            Path(CGRect(x: x, y: 0, width: cut, height: size.height)),
                            with: .color(Theme.band(shade)))
                    case .head(let eighths):
                        context.fill(Path(whole), with: .color(Theme.runout.opacity(0.45)))
                        let cut = cellWidth * CGFloat(eighths) / CGFloat(Meter.unitsPerCell)
                        context.fill(
                            Path(CGRect(x: x, y: 0, width: max(cut, 1), height: size.height)),
                            with: .color(Theme.amber(.head)))
                    }
                }
            }
            .frame(width: Grid.columns(PanelGrid.stripWidth), height: Theme.cell.height)
            .contentShape(Rectangle())
            // A `DragGesture` of no minimum distance is a press that also
            // reports every position it crosses, which is exactly the two
            // things §6.4 needs and no more: the left button only, so the
            // middle and right ones go on meaning nothing.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        seek(cell(at: value.location.x), value.translation.width != 0)
                    }
            )

            Bezel(side: .right)
            Spacer(minLength: 0)
        }
        .gridLine()
    }

    private func cell(at x: CGFloat) -> Int {
        let cellWidth = Grid.columns(PanelGrid.stripWidth) / CGFloat(PanelGrid.stripWidth)
        return min(PanelGrid.stripWidth - 1, max(0, Int(x / cellWidth)))
    }
}
