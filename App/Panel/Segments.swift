import MUTHURKit
import SwiftUI

/// The numerals: track numbers, durations, the two counters over the meters
/// (`docs/spec.md:103`).
///
/// Seven segments, because a number on a deck was made of seven segments and
/// because the shape carries one thing ordinary digits do not — **the unlit
/// segments are still there**. A dark `8` sits behind every digit, which is what
/// makes a readout look like a readout rather than like text that happens to be
/// numeric, and on an instrument that has been on for years it is also the
/// honest picture: the segments do not go away when they stop being driven.
///
/// Drawn as paths on the same cell the type uses, so `2:58` under a title still
/// lands where the column arithmetic says it does.
enum Numerals: String, Sendable {
    /// Figures in the panel's own face. Monospaced type is already a readout on
    /// a character grid — the column arithmetic was written for it — and at 13pt
    /// it keeps the one thing seven segments give away: a `1` that cannot be
    /// mistaken for anything else.
    case type
    /// Seven bars and the dark `8` behind them.
    case segment
}

enum Segments {

    /// a top, b top-right, c bottom-right, d bottom, e bottom-left, f top-left,
    /// g middle.
    static let digits: [Character: UInt8] = [
        "0": 0b0111111, "1": 0b0000110, "2": 0b1011011, "3": 0b1001111,
        "4": 0b1100110, "5": 0b1101101, "6": 0b1111101, "7": 0b0000111,
        "8": 0b1111111, "9": 0b1101111, "-": 0b1000000,
    ]

    /// One digit's worth of segment shapes in a unit box, 0…1 across and down.
    /// Hexagonal bars with mitred ends, which is the shape a real segment is and
    /// the reason a seven-segment `8` has those diagonal nicks in it.
    static func path(_ segment: Int, in rect: CGRect, thickness t: CGFloat) -> Path {
        let x0 = rect.minX
        let y0 = rect.minY
        let w = rect.width
        let h = rect.height
        let mid = y0 + h / 2

        func horizontal(_ y: CGFloat) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: x0 + t, y: y))
            path.addLine(to: CGPoint(x: x0 + w - t, y: y))
            path.addLine(to: CGPoint(x: x0 + w - t / 2, y: y + t / 2))
            path.addLine(to: CGPoint(x: x0 + w - t, y: y + t))
            path.addLine(to: CGPoint(x: x0 + t, y: y + t))
            path.addLine(to: CGPoint(x: x0 + t / 2, y: y + t / 2))
            path.closeSubpath()
            return path
        }

        func vertical(_ x: CGFloat, _ top: CGFloat, _ bottom: CGFloat) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: x, y: top + t))
            path.addLine(to: CGPoint(x: x + t / 2, y: top + t / 2))
            path.addLine(to: CGPoint(x: x + t, y: top + t))
            path.addLine(to: CGPoint(x: x + t, y: bottom - t))
            path.addLine(to: CGPoint(x: x + t / 2, y: bottom - t / 2))
            path.addLine(to: CGPoint(x: x, y: bottom - t))
            path.closeSubpath()
            return path
        }

        switch segment {
        case 0: return horizontal(y0)
        case 1: return vertical(x0 + w - t, y0, mid + t / 2)
        case 2: return vertical(x0 + w - t, mid - t / 2, y0 + h)
        case 3: return horizontal(y0 + h - t)
        case 4: return vertical(x0, mid - t / 2, y0 + h)
        case 5: return vertical(x0, y0, mid + t / 2)
        default: return horizontal(mid - t / 2)
        }
    }
}

/// A readout: digits in segments, everything else — the colon, a space, a slash
/// — left to the type it already was.
struct SegmentText: View {
    let text: String
    let colour: Color
    /// Padded to this many columns, so a duration still ends on the column the
    /// track list put it on.
    var columns: Int?
    var align: Columns.Align = .trailing
    /// Whether the dark `8` shows behind. Off for a number sitting on a lit
    /// plate, where a ghost segment reads as dirt rather than as a segment.
    var ghosts = true

    private var laid: String {
        guard let columns else { return text }
        return Columns.fit(text, to: columns, align: align)
    }

    var body: some View {
        let string = laid
        Canvas { context, size in
            guard Theme.numerals == .segment else {
                DotMatrix.set(
                    string, in: &context, origin: .zero, colour: colour,
                    height: size.height)
                return
            }

            // Inset from the cell: a digit is not as wide as the box it sits in,
            // and the gap either side is what stops `11` from reading as a fence.
            let inset = Theme.cell.width * 0.16
            let box = CGSize(
                width: Theme.cell.width - inset * 2,
                height: min(size.height * 0.72, Theme.cell.height * 0.72))
            let top = (size.height - box.height) / 2
            let thickness = box.width * Theme.segmentWeight

            for (index, character) in string.enumerated() {
                let origin = CGPoint(x: CGFloat(index) * Theme.cell.width + inset, y: top)
                let rect = CGRect(origin: origin, size: box)

                guard let mask = Segments.digits[character] else {
                    if character != " " {
                        context.draw(
                            run(String(character), colour).font(Theme.swiftUIFont),
                            at: CGPoint(x: origin.x, y: size.height / 2), anchor: .leading)
                    }
                    continue
                }

                for segment in 0..<7 {
                    let lit = mask & (1 << segment) != 0
                    if !lit && !ghosts { continue }
                    context.fill(
                        Segments.path(segment, in: rect, thickness: thickness),
                        with: .color(lit ? colour : Theme.segmentGhost))
                }
            }
        }
        .frame(width: Grid.columns(Columns.width(of: string)))
        .gridLine()
    }
}
