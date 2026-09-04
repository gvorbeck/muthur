import MUTHURKit
import Observation
import SwiftUI

/// The tube, and the thing it is mounted in (`docs/spec.md:96`).
///
/// Everything here is **atmosphere, not a filter**: it is the same picture with
/// the screen it is on drawn round it. A CRT that flickers is a CRT in a film; a
/// CRT you have been sitting in front of for nine months does not flicker, it just
/// sits there being slightly uneven and slightly burnt.
///
/// **This file used to say "and nothing in it moves", and that is now wrong on
/// purpose (D52).** The tube is old *and slightly failing*, which is one more
/// thing than it was and not two: a deflection fault that walks a soft band down
/// the raster every several seconds, and a wordmark that tears for a tenth of a
/// second every minute or so. The distinction the old sentence was defending still
/// holds and is the reason those are the only two — an effect that runs
/// continuously is a filter, and a fault you see four times an hour is a fault.
/// Both are gated on the record playing, on the window being on screen, on Reduce
/// Motion being off and on `MUTHUR_CRT` not being `0`; the schedule they run to
/// is `Tube`, in the kit, so it can be asserted instead of watched.
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

/// The one rectangle the tube is told to leave alone, and how far open it is
/// (D56).
///
/// Two numbers rather than a `Bool` because the opening has to be gradual. A veil
/// that switches off the moment the pointer crosses the edge of the sleeve is a
/// light coming on; what is wanted is the glass being taken away, which takes a
/// quarter of a second in both directions.
struct Hole: Equatable {
    let rect: CGRect
    /// 0 is the veil untouched, 1 is nothing over that rectangle at all.
    let open: Double
}

extension View {
    /// Lift a veil off one rectangle **before** it is blended, never after.
    ///
    /// The order is the whole of it. Every veil in this file ends in a blend mode
    /// that composites it against the panel underneath, and masking the blended
    /// result would isolate it into its own group — where `.multiply` has nothing
    /// but transparency to multiply with and the veil turns into an opaque smear.
    /// Masked first, the blend still meets the panel; the mask has only decided
    /// how much veil there was to blend.
    @ViewBuilder
    func punched(by hole: Hole?) -> some View {
        if let hole {
            mask {
                Rectangle()
                    .overlay(alignment: .topLeading) {
                        Rectangle()
                            .frame(width: hole.rect.width, height: hole.rect.height)
                            .offset(x: hole.rect.minX, y: hole.rect.minY)
                            .opacity(hole.open)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
        } else {
            self
        }
    }

    /// Bulge the glass toward the deflection fault (D53), rather than only
    /// lighting up where it is (D61).
    ///
    /// `fault` is the same object `ScanSweep` is animating `fallen` on, so the
    /// two move on one transaction instead of two views each guessing where the
    /// other currently is. `active` is `faulting` at the call site — the record
    /// playing, the window on screen, Reduce Motion off, `MUTHUR_CRT` not `0` —
    /// the same four gates D52 already settled, asked again here rather than
    /// threaded through as a fifth argument to the shader.
    @ViewBuilder
    func tubeBulge(fault: TubeFault, size: CGSize, active: Bool) -> some View {
        if active, size.width > 0, size.height > 0 {
            let bandY = fault.fallen
                ? size.height + Theme.sweepDepth / 2
                : -Theme.sweepDepth / 2
            distortionEffect(
                ShaderLibrary.default.tubeBulge(
                    .float2(size),
                    .float(Float(bandY)),
                    .float(Float(Theme.warpDepth)),
                    .float(Float(Theme.warpAmplitude)),
                    .float(Float(Theme.sweepDepth / 2))
                ),
                maxSampleOffset: CGSize(width: Theme.warpAmplitude, height: Theme.warpAmplitude)
            )
        } else {
            self
        }
    }
}

/// Scanlines, unevenness, vignette, sheen and the drifting band, in that order,
/// over everything.
///
/// Honours Reduce Transparency by simply not being there — every one of these is
/// a veil over the content, which is precisely what that setting is asking about.
struct ScreenEffects: View {
    /// Whether the deflection fault is allowed to run at all: the record playing,
    /// the window on screen, Reduce Motion off, `MUTHUR_CRT` not `0`.
    var sweeping = false
    /// The sleeve, while the pointer is on it (§5, D56). **The band is in the
    /// list**: a scan line still crossing the cover would mean the cover is still
    /// behind glass, and then it is not the true artwork, it is the artwork with
    /// one effect left on.
    var hole: Hole?
    /// Where the fault actually is, shared with whoever is warping the picture
    /// under it (D61). Owned by the caller, not here — `PanelView` reads the
    /// same object to drive `tubeBulge(fault:size:active:)`, and a fault this
    /// view kept to itself would have nothing for that to read.
    var fault = TubeFault()

    @Environment(\.accessibilityReduceTransparency) private var flat

    var body: some View {
        if !flat {
            ZStack {
                Scanlines(hole: hole)
                UnevenPhosphor(hole: hole)
                Vignette(hole: hole)
                Sheen(hole: hole)
                ScanSweep(running: sweeping, hole: hole, fault: fault)
            }
            .allowsHitTesting(false)
        }
    }
}

/// The one continuously-moving number the band and the bulge it drags with it
/// both read (D61). Neither owns it — `ScanSweep` writes it, from inside the
/// same `fall()` loop D53 already ran, and anything else that wants to move in
/// step with the fault reads the same instance rather than keeping a copy that
/// could drift out of phase with it.
@Observable
final class TubeFault {
    /// Where the band is: false is just above the top edge, true is just past
    /// the bottom. Read by `ScanSweep`'s own offset and by `tubeBulge`'s Y
    /// uniform — the same value, so the two are never two frames apart.
    var fallen = false
}

/// The raster.
///
/// Bowed, and that is the whole of the curvature. The alternative is to warp the
/// text with it, and a title read at a glance from across a room is worth more
/// than a curved title — so the *glass* curves and the words stay straight. The
/// bow is largest at the top and bottom edges and nothing at all across the
/// middle, which is where a real tube's is and where the eye looks for it.
struct Scanlines: View {
    var hole: Hole?

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
        .punched(by: hole)
        .blendMode(.multiply)
    }
}

/// The coating, which was never laid down evenly and has not aged evenly either.
///
/// Seeded, so it is the same blotches every launch. A tube that redecorates
/// itself on every window resize is an effect; a tube with a dull patch in the
/// same corner it has always had one is a tube.
struct UnevenPhosphor: View {
    var hole: Hole?

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
        .punched(by: hole)
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
    var hole: Hole?

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
        }
        .punched(by: hole)
        .blendMode(.multiply)
    }
}

/// One weak reflection off the front of the glass, top-left, because that is
/// where the overhead light is. Added, not painted: glass does not tint.
struct Sheen: View {
    var hole: Hole?

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .white.opacity(Theme.sheen), location: 0),
                .init(color: .clear, location: 0.45),
            ]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .punched(by: hole)
        .blendMode(.plusLighter)
    }
}

/// The fault the tube has developed: one soft band, falling (D53).
///
/// A deflection or supply fault on a real set walks a bar down the raster at the
/// beat between the mains and the field rate, and it is the least dramatic failure
/// a CRT has — you notice it at the end of an evening, not at the start of one.
/// That is the whole brief: **it must never be the reason a title took longer to
/// read**. So it is added rather than painted, at `Theme.sweep`, over five lines,
/// soft at both ends.
///
/// **One layer that translates, and nothing else repaints.** The panel is already
/// redrawing at the analyser's rate off an FFT tap, and a band drawn *into* that
/// pass would have made every frame of it more expensive for the whole of the
/// record. This is a gradient of its own with an animated offset: Core Animation
/// moves it, the panel underneath never hears about it, and between passes there
/// is not so much as a timer — the schedule is a task that sleeps.
///
/// It runs only while there is something playing and the window is on screen. Both
/// are the same argument the 20 Hz ticker makes at `player:2643`: work done for a
/// window nobody is looking at is not free, it is queued.
///
/// **Owns `fault.fallen` rather than a `@State` of its own kind, since D61.**
/// `PanelView` warps the picture off the same value, so the write has to land
/// somewhere a second view can read it — a private `@State` here would have
/// been the band moving and the bulge finding out about it a frame late, if at
/// all.
struct ScanSweep: View {
    var running = false
    var hole: Hole?
    var fault = TubeFault()
    /// Production leaves this nil and takes the system generator, the way
    /// `PlaybackEngine.load(_:source:seed:)` does. A number is for a suite, or for
    /// standing two windows side by side and having them fault in step.
    var seed: UInt64?

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Theme.amber(.lit).opacity(Theme.sweep), location: 0.5),
                    .init(color: .clear, location: 1),
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: Theme.sweepDepth)
            .offset(y: fault.fallen ? geometry.size.height : -Theme.sweepDepth)
        }
        .punched(by: hole)
        .blendMode(.plusLighter)
        .task(id: running) { await fall() }
    }

    /// Rest, fall, rest, fall — and the rests are the part that matters.
    ///
    /// The snap back to the top happens at the *start* of a rest rather than at
    /// the end of a fall, so there are whole seconds between the unanimated write
    /// and the animated one. Done in the other order the two land in the same
    /// frame and SwiftUI has every right to animate the return journey, which
    /// looks like the band going back up for another go.
    private func fall() async {
        guard running else { return }
        var tube = Tube(seed: seed)
        var snap = Transaction()
        snap.disablesAnimations = true

        while !Task.isCancelled {
            let sweep = tube.nextSweep()
            withTransaction(snap) { fault.fallen = false }
            guard await rest(sweep.rest) else { return }
            withAnimation(.linear(duration: sweep.travel)) { fault.fallen = true }
            guard await rest(sweep.travel) else { return }
        }
    }

    private func rest(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return !Task.isCancelled
        } catch {
            return false
        }
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
/// The inset is not styling. It is the surround the screws are set in, and it is
/// what holds the faceplate off the glass; at four points — which is what a screen
/// meant to be nearly all screen wanted — the wordmark was cut in half.
///
/// **Three edges bleed, the top does not** (D55). A chassis that stopped at the
/// safe area on all four sides would be a picture of a chassis, floating with a
/// margin round it; a chassis that ignores it on all four is what was here, and
/// it put the top pair of screws underneath the title bar, where a screw is not
/// a screw.
/// So the top edge is the one that gives: the window's own top inset holds it
/// down, and the surround then holds the wordmark clear of it exactly as it always
/// did. The alternative was to pad the top by however tall a title bar is, which
/// is a number this program does not know and macOS is free to change.
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
            .ignoresSafeArea(.all, edges: [.horizontal, .bottom])
    }
}

/// Four of them, which is how many it takes.
///
/// **Four angles, and they are written down** (D55). Nobody drives four slotted
/// screws home and lands them all on the same degree — each one stops where its
/// thread stops it — and the two loops that used to compute all four heads from
/// one expression gave the game away: a panel whose fasteners agree perfectly
/// was printed, not assembled.
///
/// Constants rather than a draw from a generator, and that is not laziness. This
/// canvas is re-run on every resize and every time the window changes backing
/// scale, so a random tilt would be a screw that turns itself while you drag the
/// corner of the window. Read once, that is uncanny; read twice, it is a bug
/// report. A screw is allowed to be crooked and is not allowed to move.
///
/// The spread is about a dozen degrees either side of where the single angle used
/// to be. Enough to notice with two of them in view at once, not enough to read as
/// a head somebody has chewed with the wrong driver.
private struct Screws: View {
    let inset: CGFloat

    /// Clockwise from the top left: which end of each axis the screw sits at, and
    /// how far off level its slot came to rest.
    private static let corners: [(x: CGFloat, y: CGFloat, tilt: Angle)] = [
        (0, 0, .degrees(-27)),
        (1, 0, .degrees(-4)),
        (1, 1, .degrees(-19)),
        (0, 1, .degrees(-11)),
    ]

    var body: some View {
        Canvas { context, size in
            let r = inset * 0.28
            let margin = inset / 2
            for corner in Self.corners {
                let x = margin + corner.x * (size.width - margin * 2)
                let y = margin + corner.y * (size.height - margin * 2)
                let box = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: box), with: .color(Theme.screwHead))
                context.stroke(
                    Path(ellipseIn: box), with: .color(.black.opacity(0.55)),
                    lineWidth: 0.75)
                let reach = CGPoint(
                    x: cos(corner.tilt.radians) * r * 0.6,
                    y: sin(corner.tilt.radians) * r * 0.6)
                var slot = Path()
                slot.move(to: CGPoint(x: x - reach.x, y: y - reach.y))
                slot.addLine(to: CGPoint(x: x + reach.x, y: y + reach.y))
                context.stroke(
                    slot, with: .color(.black.opacity(0.7)), lineWidth: r * 0.32)
            }
        }
        .allowsHitTesting(false)
    }
}
