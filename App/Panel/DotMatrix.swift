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
