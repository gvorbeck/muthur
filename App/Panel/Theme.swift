import AppKit
import MUTHURKit
import SwiftUI

/// Everything the panel knows about how it looks, in one file on purpose.
///
/// This is the **first pass** and it is deliberately plain: the amber, the
/// glyphs and the type are a separate pass. What matters here is that nothing
/// else in the views names a colour or a size, so tuning any of it means
/// editing this and nothing else.
///
/// The one rule already settled and not up for tuning: **amber is the chrome —
/// rules, labels, the badge — and never the data, so the titles stay the
/// brightest thing on the screen** (`panel.sh:84`).
///
/// Main-actor throughout: the cell is measured from a live `NSFont`, and
/// everything else here is read while drawing, which is the same place.
/// One stop of the phosphor ramp. A value type rather than a `Color` because it
/// has to cross to a background task to be written into pixels, and because a
/// `Color` cannot be asked what it is made of. Outside `Theme` because `Theme` is
/// main-actor and the pixels are not drawn there.
struct Ink: Sendable, Equatable {
    let r: Double
    let g: Double
    let b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    var color: Color { Color(red: r, green: g, blue: b) }
}

@MainActor
enum Theme {

    // MARK: - The grid

    /// The panel is set on a character grid because the columns have jobs: so
    /// many for a title, so many for an artist. Monospaced type is what makes
    /// the arithmetic in `MUTHURKit/Panel` true on screen.
    static let fontSize: CGFloat = 13

    /// The face the cell is measured from. Nothing else asks for it — the views
    /// draw with the SwiftUI font below, and the two have to be the same face or
    /// the measurement is of something that is not on the screen.
    static let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

    static var swiftUIFont: Font { .system(size: fontSize, weight: .regular, design: .monospaced) }

    /// One cell. Measured rather than assumed, so a change of size or face does
    /// not silently bend the grid.
    static let cell: CGSize = {
        let advance = ("0" as NSString).size(withAttributes: [.font: font]).width
        return CGSize(width: advance, height: (fontSize * 1.55).rounded())
    }()

    /// A blank line between blocks. The script printed `\n`; here it is the
    /// same height so the vertical rhythm survives.
    static var blank: CGFloat { cell.height }

    /// The whole panel: two columns of margin and `PANEL` of grid, 71 in all.
    /// One margin, not two — the panel's right-hand edge is where the gutter and
    /// then the sleeve begin (`player:504`).
    static var panelWidth: CGFloat { Grid.columns(PanelGrid.line) }

    /// The gap between the panel and the sleeve.
    static var sleeveGutter: CGFloat { Grid.columns(PanelGrid.gutterToSleeve) }

    // MARK: - The amber

    /// **The whole palette, once, as numbers.** Dark to bright, and monotonic in
    /// luminance all the way up — which is what lets the sleeve be quantised to it
    /// (`SleeveImage.quantise`) and what makes the meters' bands separate for
    /// somebody who cannot see the hues apart.
    ///
    /// Numbers rather than `Color`s because a per-pixel map needs components, and
    /// there must not be two lists: `amber(_:)` below reads from this one.
    static let phosphorRamp: [Ink] = [
        Ink(0.043, 0.035, 0.027),  // the dark the tube goes when nothing drives it
        Ink(0.11, 0.09, 0.07),  // 236
        Ink(0.34, 0.20, 0.03),  // 94
        Ink(0.68, 0.31, 0.02),  // 130
        Ink(0.83, 0.44, 0.05),  // 172
        Ink(1.00, 0.69, 0.10),  // 214
        Ink(1.00, 0.85, 0.36),  // 220
        Ink(1.00, 0.98, 0.93),  // 231
    ]

    private static func ink(_ index: Int) -> Color { phosphorRamp[index].color }

    // MARK: - The wear

    /// What happens to the room under the last track (D26).
    static let composition =
        Composition(rawValue: ProcessInfo.processInfo.environment["MUTHUR_COMPOSITION"] ?? "")
        ?? .runout

    /// **The character generator, for the chrome and for the figures.**
    ///
    /// Type by default. The dotted labels and the segmented figures are still
    /// here and still one word away — they are the period-correct answer and
    /// they cost legibility at 13pt, which is a trade to be looked at rather
    /// than assumed. Nothing downstream cares which is on: both are laid on the
    /// same cell and both are drawn in a canvas, so the columns land in the same
    /// place and neither can be truncated.
    static let lettering =
        Lettering(rawValue: ProcessInfo.processInfo.environment["MUTHUR_LETTERING"] ?? "")
        ?? .type

    static let numerals =
        Numerals(rawValue: ProcessInfo.processInfo.environment["MUTHUR_NUMERALS"] ?? "")
        ?? .type

    /// **The resting level, after nine months on.**
    ///
    /// Not a filter over the panel — the chrome's own colours, taken down and
    /// warmed. What comes down is the furniture: the rules, the labels, the
    /// bezels, the plate. What does not is the data — the titles, the readouts,
    /// the analyser, the head of a meter. That gap is the whole of the aging
    /// brief: the instrument at rest is dim and warm, and the thing it is
    /// telling you is bright against it.
    /// **The glass is the deep one and the text is the bright one** (D28).
    ///
    /// The two looks that were built were each internally consistent and each
    /// wrong in one half: the deep tube had the better glass and took the type
    /// down with it, the console had the better type and a timid glass. They are
    /// not a package — the veils are drawn over the panel and the levels are
    /// drawn into it, so the deep raster, the heavy vignette and the bowed glass
    /// can sit over lettering at the bright end of the ramp. The glass goes
    /// *around* the text, not on it.
    static var chromeDim: Double { 0.84 }

    /// Old amber goes redder, not browner: the blue end of the phosphor gives up
    /// first and the green follows it slowly.
    private static let chromeWarm = 0.12

    static func aged(_ stop: Ink, by dim: Double = chromeDim) -> Ink {
        Ink(
            stop.r * dim,
            stop.g * dim * (1 - chromeWarm * 0.5),
            stop.b * dim * (1 - chromeWarm))
    }

    private static func rest(_ index: Int) -> Color { aged(phosphorRamp[index]).color }

    /// **The sleeve is not allowed to be the brightest thing on the panel.**
    ///
    /// The rule that rejects a photograph beside an instrument is that the data
    /// is the brightest thing on the screen; a cover with a cream ground breaks
    /// it just as surely as a full-colour JPEG does, only more quietly. So the
    /// picture gets the same phosphor and the same number of levels, and the top
    /// of its range stops two steps below the panel's — the cover can be as
    /// bright as the badge and no brighter.
    ///
    /// Sampled along the ramp rather than truncated to six of its stops: the
    /// levels are what stop a sky becoming stripes, and throwing two away to buy
    /// the ceiling would pay for it in banding.
    /// Aged with everything else, and that is not a detail: the cap is a
    /// *relation* — the cover may be as bright as the plate and no brighter —
    /// and the plate has just come down by `chromeDim`. A ceiling left at its
    /// absolute value would have quietly become a cap two steps above the badge
    /// the moment the chrome aged.
    static let sleeveRamp: [Ink] = ramp(steps: phosphorRamp.count, ceiling: sleeveCeiling)
        .map { aged($0) }

    /// Level with the plate — settled, and the number the ramp is cut at.
    static let sleeveCeiling =
        Double(ProcessInfo.processInfo.environment["MUTHUR_SLEEVE_TOP"] ?? "") ?? 5

    /// The phosphor ramp resampled: `steps` stops evenly spaced from the dark up
    /// to `ceiling`, which is a position along the existing ramp and may sit
    /// between two of its stops. A blend of two neighbours is the same phosphor
    /// at a level between them — nothing here invents a colour.
    private static func ramp(steps: Int, ceiling: Double) -> [Ink] {
        let top = min(max(ceiling, 1), Double(phosphorRamp.count - 1))
        return (0..<steps).map { step in
            let at = top * Double(step) / Double(steps - 1)
            let low = phosphorRamp[Int(at)]
            let high = phosphorRamp[min(Int(at) + 1, phosphorRamp.count - 1)]
            let mix = at - at.rounded(.down)
            return Ink(
                low.r + (high.r - low.r) * mix,
                low.g + (high.g - low.g) * mix,
                low.b + (high.b - low.b) * mix)
        }
    }

    /// A phosphor screen: the field is not black, it is the dark the tube goes
    /// when nothing is driving it.
    static var ground: Color { ink(0) }

    /// The steps of the ramp, bright to dark, matching `AnalyserColumns.Shade`
    /// and `panel.sh`'s 256-colour indices.
    static func amber(_ shade: AnalyserColumns.Shade) -> Color {
        switch shade {
        case .head: ink(7)  // 231
        case .lit: ink(6)  // 220
        case .amber: ink(5)  // 214
        case .etch: ink(4)  // 172
        case .deep: ink(3)  // 130
        case .runout: ink(2)  // 94
        case .field: ink(1)  // 236
        }
    }

    /// `AMBER` — the readout, the keycap legend, the status line. **Live**, so
    /// it does not age: this is the half of the panel that is telling you
    /// something now.
    static var lit: Color { amber(.amber) }
    /// `ETCH` — paint on a metal panel: labels, rules, bezels, the row numbers.
    /// Furniture, so it wears.
    static var etch: Color { rest(4) }
    /// `RUNOUT` — the tail of a meter, dark but still part of the instrument.
    static var runout: Color { rest(2) }

    /// The data. Titles are the brightest thing on the screen and they are not
    /// amber, which is the whole point of the rule.
    static let text = Color(red: 0.93, green: 0.92, blue: 0.89)
    /// The same, one step down: an artist beside a title, a duration.
    static let dim = Color(red: 0.64, green: 0.62, blue: 0.58)

    /// The four band shades of a meter, zigzagging light and dark round the
    /// panel's own amber so neighbours separate on brightness even where the
    /// hues are cousins — and so the edges survive without colour vision
    /// (`panel.sh:92`). `SHADES=(214 130 220 166)`.
    static func band(_ index: Int) -> Color {
        switch index % Meter.shades {
        case 0: amber(.amber)  // 214
        case 1: amber(.deep)  // 130
        case 2: amber(.lit)  // 220
        default: Color(red: 0.85, green: 0.36, blue: 0.05)  // 166
        }
    }

    /// A backlit keycap.
    static var capPlate: Color { rest(1) }
    static var capInk: Color { amber(.amber) }

    /// The same cap with the switch closed. **It lights, it does not sink** — a
    /// pushbutton on an instrument is illuminated, and the thing that says the
    /// contact has been made is more current through it. One step up the plate
    /// and one step up the ink, both off the panel's own ramp, so the phosphor
    /// rule holds: the cap does not change colour, it runs harder.
    static var capPlateDown: Color { rest(2) }
    static var capInkDown: Color { amber(.lit) }

    /// The cursor row, which is the terminal's reverse video.
    static var cursorPlate: Color { Color(red: 0.20, green: 0.16, blue: 0.11) }

    // MARK: - The lettering

    /// How much of a dot's pitch the dot itself takes. Below about 0.8 the run
    /// stops reading as letters and starts reading as texture.
    static let dotFill = 0.82

    /// A segment's thickness as a fraction of the digit's width. Fat enough to
    /// be a segment, thin enough that the nicks between them survive.
    static let segmentWeight = 0.19

    /// The dark `8` behind every digit. Barely there, and always there.
    static var segmentGhost: Color { aged(phosphorRamp[1], by: chromeDim * 1.6).color }

    /// The faceplate rule, in points rather than a glyph.
    static var ruleWeight: CGFloat { 1.5 }

    // MARK: - The tube

    /// The burn: the chrome faintly still there under whatever is drawn over it.
    static var burn: Color { aged(phosphorRamp[3], by: 0.16).color }
    static var burnSoftness: CGFloat { 3.5 }

    /// Tight, because a wide bloom is the thing that turns a letter into a smear
    /// and this has to survive an hour of being looked at.
    static var bloomRadius: CGFloat { 2.4 }
    static var bloomStrength: Double { 0.5 }

    /// The raster. Three points is about a scanline at this size — fine enough
    /// that a 13pt letter still has its counters, coarse enough to see.
    static var scanPitch: CGFloat { 3 }
    static var scanDepth: Double { 0.26 }

    /// How far the raster bows at the top and bottom edges, as a fraction of the
    /// screen's height. Small even at the deep setting: the glass curves, the
    /// words do not (D29).
    static var bow: Double { 0.008 }

    static var unevenness: Double { 0.17 }
    static var vignette: Double { 0.55 }
    static var sheen: Double { 0.030 }

    /// How far out the vignette stays completely clear, as a fraction of its
    /// radius. This is the number that lets the corners go deep without the
    /// track list paying for it — the fall-off starts outside the column the
    /// panel is set in, so what the vignette darkens is glass and not type.
    static var vignetteClear: Double { 0.62 }

    // MARK: - The box

    static var chassisFace: Color { Color(red: 0.145, green: 0.137, blue: 0.125) }
    static var screwHead: Color { Color(red: 0.30, green: 0.28, blue: 0.26) }

    /// The wordmark driven onto the tube. Live, not furniture — it is the thing
    /// whose name it is.
    static var wordmarkInk: Color { amber(.lit) }

    // MARK: - The floor

    /// The run-out: the dead groove at the end of a side. Dark, striated, still
    /// unmistakably part of the record.
    static var runoutField: Color { aged(phosphorRamp[2], by: 0.7).color }
}
