import AppKit
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// **The placeholder icon, and it is meant to be replaced.**
///
/// §14 asks for a Dock icon and a Cmd-Tab identity. `LSUIElement` already
/// declared the app regular; what was missing was artwork, and an app with no
/// artwork gets the blank sheet of paper macOS hands anything it cannot draw.
/// This is a stand-in so that the Dock, Cmd-Tab and Spotlight have something of
/// the program's own to show — **not** a designed mark, and replacing it is an
/// ordinary edit rather than a change of direction. Drop a real `MUTHUR.icns`
/// into `App/` and this script and its wrapper can go.
///
/// **Nothing here invents a colour or a letterform.** It is compiled against
/// `App/Panel/Theme.swift` and `App/Panel/DotMatrix.swift` — the ground, the
/// bezel, the wordmark's ink and the dot fill are read out of `Theme`, and the
/// glyphs are the panel's own 5×7 character generator. That is the whole reason
/// the wrapper goes to the trouble of building the kit and compiling five App
/// files rather than pasting eight RGB triples in here: a second palette is how
/// two palettes end up disagreeing, and the one on the Dock would be the one
/// nobody looks at closely enough to notice.
///
/// **The one design decision, and it is mine, not the script's.** `player` has
/// no icon and could not have one, so there is nothing to port here (D27's
/// argument for drawing the wordmark rather than importing it is the nearest
/// thing, and it is about the panel). The badge is `MU/TH/UR`, eight glyphs on
/// one line, and eight glyphs across a square is a hairline of dots with empty
/// screen above and below it. So it is set on three lines, **broken at its own
/// slashes** — `MU/`, `TH/`, `UR` — which keeps the slashes that are the whole
/// of the stylisation and makes a block roughly the shape of the thing it is
/// sitting in. Below about 32 px the dots fuse and it reads as texture rather
/// than as letters; see `fill` for the one concession made to that, and note
/// that a placeholder is allowed to lose that argument.
@main
struct MakeIcon {

    /// The three lines, and the widest of them, which is what the block is set
    /// against. Broken at the slashes — see the note above.
    static let lines = ["MU/", "TH/", "UR"]

    /// Every distinct pixel size an `.iconset` can be asked for, and the names
    /// each one is written under. 16 and 32 appear twice because a 32 px image
    /// is both `16x16@2x` and `32x32`, and `iconutil` wants both files.
    static let sheet: [(pixels: Int, names: [String])] = [
        (16, ["icon_16x16.png"]),
        (32, ["icon_16x16@2x.png", "icon_32x32.png"]),
        (64, ["icon_32x32@2x.png"]),
        (128, ["icon_128x128.png"]),
        (256, ["icon_128x128@2x.png", "icon_256x256.png"]),
        (512, ["icon_256x256@2x.png", "icon_512x512.png"]),
        (1024, ["icon_512x512@2x.png"]),
    ]

    static func main() {
        let directory = URL(fileURLWithPath: CommandLine.arguments.count > 1
            ? CommandLine.arguments[1] : "MUTHUR.iconset")
        MainActor.assumeIsolated {
            do { try write(into: directory) } catch {
                FileHandle.standardError.write(Data("make-icon: \(error)\n".utf8))
                exit(1)
            }
        }
    }

    @MainActor
    static func write(into directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        for (pixels, names) in sheet {
            guard let image = draw(pixels: pixels) else {
                throw Failure.couldNotDraw(pixels)
            }
            for name in names {
                let url = directory.appending(path: name)
                guard
                    let sink = CGImageDestinationCreateWithURL(
                        url as CFURL, UTType.png.identifier as CFString, 1, nil)
                else { throw Failure.couldNotWrite(name) }
                CGImageDestinationAddImage(sink, image, nil)
                guard CGImageDestinationFinalize(sink) else {
                    throw Failure.couldNotWrite(name)
                }
            }
        }
    }

    enum Failure: Error, CustomStringConvertible {
        case couldNotDraw(Int)
        case couldNotWrite(String)

        var description: String {
            switch self {
            case .couldNotDraw(let pixels): "could not draw at \(pixels) px"
            case .couldNotWrite(let name): "could not write \(name)"
            }
        }
    }

    // MARK: - Drawing

    @MainActor
    static func draw(pixels: Int) -> CGImage? {
        let side = CGFloat(pixels)
        guard
            let context = CGContext(
                data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        // Top-left origin, so the arithmetic below reads the same way the
        // panel's own canvas code does rather than upside down.
        context.translateBy(x: 0, y: side)
        context.scaleBy(x: 1, y: -1)
        context.setAllowsAntialiasing(true)

        // macOS sets an app icon's body in 824 of a 1024 canvas and leaves the
        // rest to the shadow it draws itself. Kept as a proportion so every size
        // in the sheet is the same picture.
        let inset = side * 100 / 1024
        let plate = CGRect(
            x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
        let screen = CGPath(
            roundedRect: plate, cornerWidth: plate.width * 0.225,
            cornerHeight: plate.width * 0.225, transform: nil)

        // The tube, at the dark it goes when nothing is driving it.
        context.addPath(screen)
        context.setFillColor(cg(Theme.ground))
        context.fillPath()

        // The bezel it is mounted in. `etch` is the panel's furniture colour —
        // paint on a metal panel — which is what a bezel is.
        context.addPath(screen)
        context.setStrokeColor(cg(Theme.etch))
        context.setLineWidth(max(side * 6 / 1024, 0.75))
        context.strokePath()

        wordmark(in: context, plate: plate)

        return context.makeImage()
    }

    /// The name, in the panel's own dots.
    @MainActor
    static func wordmark(in context: CGContext, plate: CGRect) {
        let widest = lines.map(\.count).max() ?? 1
        // A glyph is five dots and the gap after it; the last one on a line has
        // no gap to spare. One blank dot-row between lines.
        let across = widest * (DotMatrix.columns + 1) - 1
        let down = lines.count * DotMatrix.rows + (lines.count - 1)

        // Whichever bound binds. The block is taller than it is wide — three
        // rows of at most three 5×7 glyphs — so on a square plate it is nearly
        // always the height.
        let pitch = min(
            plate.width * 0.56 / CGFloat(across),
            plate.height * 0.64 / CGFloat(down))
        guard pitch > 0 else { return }

        // **The one concession to 16 px.** `Theme.dotFill` is 0.82 because below
        // about 0.8 a run of dots stops reading as letters and starts reading as
        // texture — an argument about a screen you are sitting in front of. In a
        // 16 px icon the dots are already sub-pixel and the gaps are what make
        // the mark vanish into dust, so the fill is walked up to solid as the
        // pitch falls under two device pixels. Above that it is `Theme`'s number
        // untouched.
        let fill = min(1, Theme.dotFill + max(0, (2 - pitch) / 2) * (1 - Theme.dotFill))
        let dot = pitch * fill

        let blockWidth = CGFloat(across) * pitch
        let left = plate.midX - blockWidth / 2
        let top = plate.midY - CGFloat(down) * pitch / 2

        let ink = cg(Theme.wordmarkInk)
        context.setFillColor(ink)

        for (index, line) in lines.enumerated() {
            // Each line centred on the block rather than flushed left: `UR` is a
            // glyph shorter than the two above it, and hanging it off the left
            // edge reads as a mistake rather than as a wordmark.
            let lineWidth = CGFloat(line.count * (DotMatrix.columns + 1) - 1) * pitch
            let x0 = left + (blockWidth - lineWidth) / 2
            let y0 = top + CGFloat(index * (DotMatrix.rows + 1)) * pitch

            for (column, character) in line.enumerated() {
                // The panel's own character generator. A glyph it cannot say
                // would be a glyph nobody put in the name.
                guard let bitmap = DotMatrix.glyphs[character] else { continue }
                let glyphX = x0 + CGFloat(column * (DotMatrix.columns + 1)) * pitch
                for (row, mask) in bitmap.enumerated() {
                    for bit in 0..<DotMatrix.columns where mask & (1 << (4 - bit)) != 0 {
                        let rect = CGRect(
                            x: glyphX + CGFloat(bit) * pitch,
                            y: y0 + CGFloat(row) * pitch,
                            width: dot, height: dot)
                        context.addPath(
                            CGPath(
                                roundedRect: rect, cornerWidth: dot * 0.35,
                                cornerHeight: dot * 0.35, transform: nil))
                    }
                }
            }
        }
        context.fillPath()
    }

    /// A `Theme` colour as pixels. Through `NSColor` rather than off
    /// `phosphorRamp` by index, so what lands in the icon is what the accessor
    /// returns and not a guess about which stop it reads.
    @MainActor
    static func cg(_ colour: Color) -> CGColor {
        NSColor(colour).usingColorSpace(.sRGB)?.cgColor ?? NSColor.black.cgColor
    }
}
