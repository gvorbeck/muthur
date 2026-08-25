import MUTHURKit
import SwiftUI

/// The tube, and the thing it is mounted in (`docs/spec.md:96`).
///
/// Everything here is **atmosphere, not a filter**: it is the same picture with
/// the screen it is on drawn round it, and nothing in it moves. A CRT that
/// flickers is a CRT in a film; a CRT you have been sitting in front of for nine
/// months does not flicker, it just sits there being slightly uneven and
/// slightly burnt.
///
/// Two looks were built and neither won whole (D28). The deep one had the better
/// glass and took the type down with it; the shallow one had the better type and
/// a glass too timid to be worth having. What is here is the half of each that
/// was right: **the deep tube's optics over the console's lettering**, in a
/// chassis with real thickness. The veils are drawn over the panel and the levels
/// are drawn into it, so there was never anything holding the two together.
///
/// What to do with the room under the last track (D26).
///
/// - `runout` — fill it. The list keeps its whole budget and the unused part of
///   it becomes the run-out: the dead groove at the end of a side, grooves
///   tightening as they go, so the panel reaches the bottom of its chassis.
///   **The default, and a deliberate divergence from `player:2341`.**
/// - `deck` — nothing, which is what the script does: `np_frame`'s loop stops at
///   the last track and the meters go on the next line. Faithful to a terminal,
///   where the window *is* the terminal and there is no chassis to reach the
///   bottom of. Kept because the divergence should stay visible.
enum Composition: String, Sendable {
    case deck
    case runout
}

/// The dead groove after the last track.
///
/// Not decoration and not a placeholder — a record that has been played through
/// has this on it, and a panel with the vocabulary this one uses has somewhere
/// obvious to put it.
///
/// **The tightening is the whole of it.** Evenly spaced lines are a table with
/// nothing in it; what says *lead-out* is the pitch closing as the spiral runs
/// in, ending on the dead groove. The first version stepped the pitch down by a
/// constant factor per groove, which tightens in principle and is nearly
/// invisible in practice: over the height this field actually gets, the eye reads
/// it as regular. So the grooves are placed against the height instead — the gap
/// falls away as `(1 − t)^p`, which puts the first one a full line below the last
/// track and packs the last of them against the floor.
struct RunoutField: View {
    let rows: Int

    /// How hard the spiral closes. Two and a bit is where it stops reading as a
    /// ruled field and starts reading as an ending.
    private let closing = 2.4

    var body: some View {
        Canvas { context, size in
            guard size.height > 1 else { return }

            // Enough grooves that the first gap is about a line: the gap at the
            // top is `height · p / count`, so this is that solved for count.
            let count = max(4, Int(size.height * closing / Theme.cell.height))
            var last = 0.0

            for groove in 1...count {
                let t = Double(groove) / Double(count)
                let y = size.height * (1 - pow(1 - t, closing))
                // Once the spiral is closer than the phosphor can resolve, more
                // lines is just a solid block. Stop drawing them.
                if y - last < 2 { continue }
                last = y

                // Fading in, not out. The grooves tighten on the way down, so
                // fading down as well would leave the densest part of the field
                // the faintest — the one place a lead-out is most obviously
                // there. It comes up out from under the last track instead.
                let fade = min(1, y / (Theme.cell.height * 2))
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(Theme.runoutField.opacity(fade)))
            }

            // The dead groove: the one the needle never gets out of. It is the
            // reason the field has a bottom rather than merely running out of
            // room, so it is drawn as a groove and not as a rule — the same
            // colour, twice the weight.
            context.fill(
                Path(
                    CGRect(
                        x: 0, y: size.height - Theme.cell.height * 0.5,
                        width: size.width, height: 2)),
                with: .color(Theme.runoutField))
        }
        .frame(
            width: Grid.columns(PanelGrid.width - PanelGrid.gutter),
            height: Grid.rows(rows)
        )
        .padding(.leading, Grid.columns(PanelGrid.gutter))
        .allowsHitTesting(false)
    }
}

// MARK: - The glow

/// A bright cell glowing into its neighbours (`docs/spec.md:99`).
///
/// The same picture, blurred, added back over itself. Added rather than tinted,
/// which is the whole rule in one line: **a glowing cell does not change hue.**
/// Adding amber to amber runs the core up toward white and leaves the spill the
/// colour it already was. A coloured shadow would do the opposite — one fixed
/// hue haloing everything regardless of what is underneath — and that is a neon
/// sign.
struct Bloom<Content: View>: View {
    var radius: CGFloat = Theme.bloomRadius
    var strength: Double = Theme.bloomStrength
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceTransparency) private var flat

    var body: some View {
        content
            .overlay {
                if !flat {
                    content
                        .blur(radius: radius)
                        .blendMode(.plusLighter)
                        .opacity(strength)
                        .allowsHitTesting(false)
                }
            }
            .compositingGroup()
    }
}

// MARK: - The wear

/// One rectangle of the grid, in columns and rows.
struct GridRect: Equatable {
    let column: Int
    let row: Int
    let columns: Int
    let rows: Int
}

/// Where the chrome has sat without moving (`docs/spec.md:95`).
///
/// The static furniture — the faceplate, the two meter frames, the analyser
/// well, the keycaps — is in the same place in every frame this program has ever
/// drawn, and a phosphor driven at the same level for that long does not go all
/// the way back down. So those rectangles are faintly there whatever is on top
/// of them, softened because a burn has no edge.
///
/// Under the panel and not over it: a burn is the tube being slightly awake, not
/// a stain on the glass.
struct BurnIn: View {
    let marks: [GridRect]

    var body: some View {
        Canvas { context, _ in
            for mark in marks {
                let rect = CGRect(
                    x: Grid.columns(mark.column), y: Grid.rows(mark.row),
                    width: Grid.columns(mark.columns), height: Grid.rows(mark.rows))
                context.fill(
                    Path(roundedRect: rect, cornerRadius: Theme.cell.width * 0.4),
                    with: .color(Theme.burn))
            }
        }
        .blur(radius: Theme.burnSoftness)
        .allowsHitTesting(false)
    }
}

// MARK: - The glass

/// Scanlines, unevenness, vignette and sheen, in that order, over everything.
///
/// Honours Reduce Transparency by simply not being there — every one of these is
/// a veil over the content, which is precisely what that setting is asking about.
struct ScreenEffects: View {
    @Environment(\.accessibilityReduceTransparency) private var flat

    var body: some View {
        if !flat {
            ZStack {
                Scanlines()
                UnevenPhosphor()
                Vignette()
                Sheen()
            }
            .allowsHitTesting(false)
        }
    }
}

/// The raster.
///
/// Bowed, and that is the whole of the curvature. The alternative is to warp the
/// text with it, and a title read at a glance from across a room is worth more
/// than a curved title — so the *glass* curves and the words stay straight. The
/// bow is largest at the top and bottom edges and nothing at all across the
/// middle, which is where a real tube's is and where the eye looks for it.
struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            let pitch = Theme.scanPitch
            var y = 0.0
            while y < size.height {
                let across = (y / size.height) * 2 - 1  // −1 top, +1 bottom
                let sag = -across * Theme.bow * size.height
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addQuadCurve(
                    to: CGPoint(x: size.width, y: y),
                    control: CGPoint(x: size.width / 2, y: y + sag * 2))
                context.stroke(
                    line, with: .color(.black.opacity(Theme.scanDepth)),
                    lineWidth: pitch * 0.5)
                y += pitch
            }
        }
        .blendMode(.multiply)
    }
}

/// The coating, which was never laid down evenly and has not aged evenly either.
///
/// Seeded, so it is the same blotches every launch. A tube that redecorates
/// itself on every window resize is an effect; a tube with a dull patch in the
/// same corner it has always had one is a tube.
struct UnevenPhosphor: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x4D55_5448_5552
            func next() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double((seed >> 33) % 10_000) / 10_000
            }
            for _ in 0..<18 {
                let radius = size.width * (0.10 + next() * 0.26)
                let centre = CGPoint(x: next() * size.width, y: next() * size.height)
                let depth = Theme.unevenness * (0.35 + next() * 0.65)
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: centre.x - radius, y: centre.y - radius,
                            width: radius * 2, height: radius * 2)),
                    with: .radialGradient(
                        Gradient(colors: [.black.opacity(depth), .clear]),
                        center: centre, startRadius: 0, endRadius: radius))
            }
        }
        .blendMode(.multiply)
    }
}

/// The corners going off, the way the corners of a tube do.
///
/// Deep, and it starts late. Those two go together: a heavy vignette that begins
/// near the middle is a filter over the instrument, and the same weight held off
/// until it is outside the column the panel is set in is a tube. What it darkens
/// is glass, not type.
struct Vignette: View {
    var body: some View {
        GeometryReader { geometry in
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: Theme.vignetteClear),
                    .init(color: .black.opacity(Theme.vignette), location: 1),
                ]),
                center: .center,
                startRadius: 0,
                endRadius: max(geometry.size.width, geometry.size.height) * 0.72
            )
            .blendMode(.multiply)
        }
    }
}

/// One weak reflection off the front of the glass, top-left, because that is
/// where the overhead light is. Added, not painted: glass does not tint.
struct Sheen: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .white.opacity(Theme.sheen), location: 0),
                .init(color: .clear, location: 0.45),
            ]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .blendMode(.plusLighter)
    }
}

// MARK: - The box it is in

/// What the tube is mounted in.
///
/// A front panel: brushed metal, an inner bevel that catches the light along its
/// top edge and loses it along its bottom, and four screws that hold it to a
/// bulkhead. The corners are the deep tube's, generously rounded, because that is
/// the shape of the glass the bevel is holding.
///
/// The inset is not styling. The chassis ignores the safe area on purpose, so the
/// surround is the only thing holding the faceplate clear of the title bar; at
/// four points — which is what a screen meant to be nearly all screen wanted —
/// the wordmark was cut in half.
struct Chassis<Content: View>: View {
    @ViewBuilder var content: Content

    private var inset: CGFloat { Theme.cell.width * 2.2 }
    private var radius: CGFloat { 16 }

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            // The screen sits below the surface it is set into.
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.black.opacity(0.9), .black.opacity(0.25)],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: 3
                    )
                    .allowsHitTesting(false)
            }
            .padding(inset)
            .background {
                ZStack {
                    Theme.chassisFace
                    LinearGradient(
                        colors: [.white.opacity(0.055), .clear, .black.opacity(0.35)],
                        startPoint: .top, endPoint: .bottom)
                    Screws(inset: inset)
                }
            }
            .ignoresSafeArea()
    }
}

/// Four of them, which is how many it takes.
private struct Screws: View {
    let inset: CGFloat

    var body: some View {
        Canvas { context, size in
            let r = inset * 0.28
            let margin = inset / 2
            for x in [margin, size.width - margin] {
                for y in [margin, size.height - margin] {
                    let box = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: box), with: .color(Theme.screwHead))
                    context.stroke(
                        Path(ellipseIn: box), with: .color(.black.opacity(0.55)),
                        lineWidth: 0.75)
                    var slot = Path()
                    slot.move(to: CGPoint(x: x - r * 0.6, y: y + r * 0.18))
                    slot.addLine(to: CGPoint(x: x + r * 0.6, y: y - r * 0.18))
                    context.stroke(
                        slot, with: .color(.black.opacity(0.7)), lineWidth: r * 0.32)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
