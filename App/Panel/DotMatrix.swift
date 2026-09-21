import MUTHURKit
import SwiftUI

/// The lettering on the chrome: labels, legends, the mode stamped on the
/// faceplate (`docs/spec.md:104`).
///
/// A 5×7 cell, which is the shape every character generator of the period had,
/// built as a table here because the alternative is a file of pixels and there
/// is not going to be one. The table only has to cover the chrome — the words
/// this program chose for itself, which are all capitals and punctuation. A
/// track title is somebody else's text in somebody else's alphabet and stays
/// real type; the moment a Korean album arrives, a 5×7 table has nothing to say
/// about it and would have to invent something.
///
/// **Nothing drawn through here can be truncated.** A `Text` given less width
/// than it wants ellipsizes, silently, and that is what put a `…` on the end of
/// the faceplate rule twice. Dots in a `Canvas` have no such machinery: they are
/// drawn where the grid says and clipped if there is no room, which is a fact
/// you can see rather than a lie about the content.
enum Lettering: String, Sendable {
    /// The face the grid is measured from. The panel's own type, aged and
    /// bloomed with everything else — a character generator is a character
    /// generator, and this one has the advantage of knowing every alphabet.
    case type
    /// The 5×7 table below.
    case matrix
}

enum DotMatrix {

    static let columns = 5
    static let rows = 7

    /// Row masks, top to bottom, bit 4 leftmost.
    static let glyphs: [Character: [UInt8]] = [
        "A": [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
        "B": [0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110],
        "C": [0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110],
        "D": [0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110],
        "E": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111],
        "F": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000],
        "G": [0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01111],
        "H": [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
        "I": [0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
        "J": [0b00111, 0b00010, 0b00010, 0b00010, 0b00010, 0b10010, 0b01100],
        "K": [0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001],
        "L": [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111],
        "M": [0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001],
        "N": [0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001],
        "O": [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
        "P": [0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000],
        "Q": [0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101],
        "R": [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001],
        "S": [0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110],
        "T": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100],
        "U": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
        "V": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100],
        "W": [0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b11011, 0b10001],
        "X": [0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001],
        "Y": [0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100],
        "Z": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111],
        "0": [0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110],
        "1": [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
        "2": [0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111],
        "3": [0b11111, 0b00010, 0b00100, 0b00010, 0b00001, 0b10001, 0b01110],
        "4": [0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010],
        "5": [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110],
        "6": [0b00110, 0b01000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110],
        "7": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000],
        "8": [0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110],
        "9": [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00010, 0b01100],
        " ": [0, 0, 0, 0, 0, 0, 0],
        "·": [0, 0, 0, 0b00100, 0, 0, 0],
        "/": [0b00001, 0b00010, 0b00010, 0b00100, 0b01000, 0b01000, 0b10000],
        "\\": [0b10000, 0b01000, 0b01000, 0b00100, 0b00010, 0b00010, 0b00001],
        "-": [0, 0, 0, 0b11111, 0, 0, 0],
        "—": [0, 0, 0, 0b11111, 0, 0, 0],
        "_": [0, 0, 0, 0, 0, 0, 0b11111],
        ":": [0, 0b00100, 0b00100, 0, 0b00100, 0b00100, 0],
        ".": [0, 0, 0, 0, 0, 0b01100, 0b01100],
        ",": [0, 0, 0, 0, 0b00110, 0b00100, 0b01000],
        "'": [0b00100, 0b00100, 0, 0, 0, 0, 0],
        "\"": [0b01010, 0b01010, 0, 0, 0, 0, 0],
        "(": [0b00010, 0b00100, 0b01000, 0b01000, 0b01000, 0b00100, 0b00010],
        ")": [0b01000, 0b00100, 0b00010, 0b00010, 0b00010, 0b00100, 0b01000],
        "+": [0, 0b00100, 0b00100, 0b11111, 0b00100, 0b00100, 0],
        "=": [0, 0, 0b11111, 0, 0b11111, 0, 0],
        "%": [0b11001, 0b11010, 0b00010, 0b00100, 0b01000, 0b01011, 0b10011],
        "!": [0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0, 0b00100],
        "?": [0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0, 0b00100],
        "#": [0b01010, 0b01010, 0b11111, 0b01010, 0b11111, 0b01010, 0b01010],
        "&": [0b01100, 0b10010, 0b10100, 0b01000, 0b10101, 0b10010, 0b01101],
        "*": [0, 0b00100, 0b10101, 0b01110, 0b10101, 0b00100, 0],
        "×": [0, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0],
        "♪": [0b00011, 0b00010, 0b00010, 0b00010, 0b01110, 0b11110, 0b01100],
        "‖": [0b11011, 0b11011, 0b11011, 0b11011, 0b11011, 0b11011, 0b11011],
        "▶": [0b11000, 0b11100, 0b11110, 0b11111, 0b11110, 0b11100, 0b11000],
        "␣": [0, 0, 0, 0b10001, 0b10001, 0b11111, 0],
        "←": [0, 0b00100, 0b01000, 0b11111, 0b01000, 0b00100, 0],
        "→": [0, 0b00100, 0b00010, 0b11111, 0b00010, 0b00100, 0],
        "↑": [0, 0b00100, 0b01110, 0b10101, 0b00100, 0b00100, 0],
        "↓": [0, 0b00100, 0b00100, 0b10101, 0b01110, 0b00100, 0],
        "⏎": [0b00001, 0b00001, 0b00101, 0b01101, 0b11111, 0b01100, 0b00100],
    ]

    /// Whether the table can say this at all. Everything it cannot is drawn as
    /// ordinary type inside the same canvas — still uncuttable, just not dotted.
    static func has(_ text: String) -> Bool {
        text.uppercased().allSatisfy { glyphs[$0] != nil }
    }

    /// One glyph's advance at a given dot pitch: five dots and the gap.
    static func advance(pitch: CGFloat) -> CGFloat { pitch * CGFloat(columns + 1) }

    /// Lay a run of dots into a context. Shared because the wordmark is the same
    /// lettering at twice the pitch, and two copies of a character generator is
    /// how two of them end up disagreeing.
    /// The same run set in the panel's own type, on the same baseline and in the
    /// same canvas.
    ///
    /// **In a canvas, and that is the point.** Everything the first pass bought
    /// by dotting the chrome — a line that cannot ellipsize, a label that cannot
    /// quietly lose its tail — was bought by drawing rather than by the dots.
    /// Type drawn here keeps all of it.
    @MainActor
    static func set(
        _ string: String, in context: inout GraphicsContext, origin: CGPoint,
        colour: Color, height: CGFloat
    ) {
        context.draw(
            run(string, colour).font(Theme.swiftUIFont),
            at: CGPoint(x: origin.x, y: origin.y + height / 2), anchor: .leading)
    }

    @MainActor
    static func draw(
        _ string: String, in context: inout GraphicsContext, origin: CGPoint,
        pitch: CGFloat, colour: Color, height: CGFloat
    ) {
        let dot = pitch * Theme.dotFill
        let top = origin.y + (height - pitch * CGFloat(rows)) / 2 + pitch * 0.5

        for (index, character) in string.uppercased().enumerated() {
            let x0 = origin.x + CGFloat(index) * advance(pitch: pitch) + pitch * 0.5
            guard let bitmap = glyphs[character] else {
                context.draw(
                    run(String(character), colour).font(Theme.swiftUIFont),
                    at: CGPoint(x: x0, y: origin.y + height / 2), anchor: .leading)
                continue
            }
            for (row, mask) in bitmap.enumerated() {
                for column in 0..<columns where mask & (1 << (4 - column)) != 0 {
                    let rect = CGRect(
                        x: x0 + CGFloat(column) * pitch, y: top + CGFloat(row) * pitch,
                        width: dot, height: dot)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: dot * 0.35),
                        with: .color(colour))
                }
            }
        }
    }
}

/// A run of chrome lettering, laid on the character grid one glyph per column.
///
/// The dot pitch comes out of the cell rather than out of a taste: five columns
/// of dots and a gap in `Theme.cell.width`, seven rows of the same pitch, sat on
/// the baseline the real type uses — so a dotted label and a typed title on the
/// same line agree about where the line is.
struct MatrixText: View {
    let text: String
    let colour: Color
    /// Padded to this many columns when it is standing in a column of its own.
    var columns: Int?
    var align: Columns.Align = .leading

    private var laid: String {
        guard let columns else { return text }
        return Columns.fit(text, to: columns, align: align)
    }

    var body: some View {
        let string = laid
        let width = Grid.columns(Columns.width(of: string))
        Canvas { context, size in
            switch Theme.lettering {
            case .type:
                DotMatrix.set(
                    string, in: &context, origin: .zero, colour: colour,
                    height: size.height)
            case .matrix:
                // The pitch comes out of the cell: one glyph is one column, so a
                // dotted label and a typed title on the same line agree about
                // where the columns are.
                DotMatrix.draw(
                    string, in: &context, origin: .zero,
                    pitch: Theme.cell.width / CGFloat(DotMatrix.columns + 1),
                    colour: colour, height: size.height)
            }
        }
        .frame(width: width)
        .gridLine()
    }
}

/// The figure that has just gone, still faintly on the glass (D100).
///
/// A seven-segment readout and a phosphor do the same thing when the number
/// under them changes: the old figure does not vanish, it stops being driven,
/// and what you see for the next third of a second is it giving up. `TRACK 04
/// OF 11` becoming `TRACK 05 OF 11` is the one mechanical event in a gapless
/// record — the music deliberately gives you nothing at that moment — and a
/// readout that snapped to it threw the only mark there was.
///
/// **Not a cross-fade, and the two halves are why.** The new figure strikes in
/// a fifth of a second and the old takes twice that to go, which is the
/// asymmetry a phosphor actually has — struck hard, released slowly — and is
/// what stops the two readings ever being equally legible at the same moment.
/// Equal durations either way would be a dissolve between two numbers, which is
/// a transition somebody wrote; this is one number arriving while the last one
/// is still warm.
///
/// Held still by Reduce Motion and **not** by `MUTHUR_CRT`. That variable names
/// D52's two *faults*, and this is the tube working correctly, the same
/// distinction `Tube.faultsAllowed` already draws about the screws and the
/// surround.
struct Afterglow: View {
    let text: String
    let colour: Color

    @Environment(\.accessibilityReduceMotion) private var still

    /// The figure that is on its way out, or nil when there is only one reading
    /// on the glass.
    @State private var going: String?
    @State private var rising = 1.0
    @State private var falling = 0.0

    var body: some View {
        ZStack(alignment: .leading) {
            if let going, !still {
                MatrixText(text: going, colour: colour)
                    .opacity(falling * Theme.afterglowDim)
            }
            MatrixText(text: text, colour: colour)
                .opacity(still ? 1 : rising)
        }
        // Pinned to the live reading rather than left to the stack. A `ZStack`
        // sizes to its largest child, so a label one column wider on its way out
        // would push whatever is beside it sideways for a third of a second —
        // and the one thing a meter must not do while the track changes is move.
        .frame(width: Grid.columns(Columns.width(of: text)), alignment: .leading)
        .onChange(of: text) { old, _ in
            guard !still else { return }
            going = old
            // The two levels have to *start* where the event starts them, and
            // an unanimated write is the only way to say so: animated, the
            // reset would itself be a fade and the figure would arrive twice.
            var snap = Transaction()
            snap.disablesAnimations = true
            withTransaction(snap) {
                rising = 0
                falling = 1
            }
            withAnimation(.easeOut(duration: Theme.afterglowIn)) { rising = 1 }
            withAnimation(.easeIn(duration: Theme.afterglowOut)) { falling = 0 } completion: {
                // A second change inside the first one's tail restarts `falling`,
                // and this completion is the *old* animation's. Clearing on it
                // regardless would take the newly-dying figure off the glass
                // mid-decay; the level itself is the only honest test of whether
                // there is still something fading.
                if falling == 0 { going = nil }
            }
        }
    }
}
