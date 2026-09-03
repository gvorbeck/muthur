import MUTHURKit
import SwiftUI

/// The name, at the top left of every screen this program draws
/// (`panel.sh:256`).
///
/// Not a label — the thing that has to carry the name. Which is also the reason
/// it is drawn from shapes rather than imported as a picture: a picture is the
/// one object on this panel that could not bloom, could not burn into the
/// phosphor behind it, and would stay factory-fresh while everything round it
/// aged. A wordmark made of the same dots as the rest of the instrument gets old
/// with it.
///
/// **It is driven onto the tube, not screwed to the front of it** (D27). The
/// alternative — a stamped metal nameplate, the name cut into it, lit from above
/// — was built and rejected: a plate does not glow and cannot burn in, because
/// it is not part of the display, and on a screen it reads as a chip stuck on
/// the glass rather than as something the machine drew. So the name is the
/// character generator's own dots at twice the pitch, made of the same light as
/// the track titles. MU/TH/UR is the thing that is *running*, and the panel is
/// what it says.
/// **And once in a while the tube loses its line across it** (D54). Rare — a
/// minute or so between, from `Tube`, seeded — and brief, seven to seventeen
/// hundredths, which is two or three frames. Long enough to have happened, short
/// enough that you are not sure it did.
///
/// **A slice tear, not a colour split and not corruption.** The three obvious
/// glitch vocabularies were all available and two of them are wrong here. An RGB
/// split needs three channels to pull apart and this panel has one colour by
/// rule, so it would not read as a fault in the machine — it would read as a
/// different machine. Character corruption — the badge briefly spelling something
/// that is not the name — is a lie about state on a panel whose whole job is not
/// to lie about state, and on eight glyphs it is far too legible to be a
/// hundredth-of-a-second event; you would read the wrong word. A horizontal slice
/// offset is the one that says *the beam did not get back to the left edge in
/// time*, which is a thing a failing tube does and is not a thing the program is
/// claiming.
///
/// It cannot move the layout. Everything happens inside the same fixed-width
/// canvas the badge already had, the bands displace within it, and the rule and
/// the meta beside them never hear about it (`panel.sh:257`).
struct WordmarkView: View {
    /// Whether the tube is allowed to misbehave: playing, on screen, Reduce Motion
    /// off, `MUTHUR_CRT` not `0`.
    var glitching = false
    /// Nil takes the system generator, as `PlaybackEngine.load` does.
    var seed: UInt64?

    @State private var torn: Tube.Slip?

    /// How many columns of the faceplate it takes, so the rule can be given the
    /// rest. Twice the pitch is twice the width, and the rule gives way for it
    /// the same way it gives way for a long mode word (`panel.sh:257`).
    static var columns: Int { Columns.width(of: Faceplate.badge) * 2 + 2 }

    private var pitch: CGFloat { Theme.cell.width * 2 / CGFloat(DotMatrix.columns + 1) }

    var body: some View {
        Canvas { context, size in
            guard let torn else {
                badge(in: &context, height: size.height, by: 0)
                return
            }
            // Once per band, clipped to it. Nine draws of eight glyphs at the
            // very worst, and only for a tenth of a second — against the
            // alternative of keeping a second rendering of the badge around all
            // the time for something that happens once a minute.
            for band in bands(torn, height: size.height) {
                context.drawLayer { layer in
                    layer.clip(
                        to: Path(
                            CGRect(
                                x: 0, y: band.top, width: size.width,
                                height: band.depth)))
                    badge(in: &layer, height: size.height, by: band.shift * pitch)
                }
            }
        }
        .frame(width: Grid.columns(WordmarkView.columns))
        .gridLine()
        .task(id: glitching) { await tear() }
    }

    private func badge(in context: inout GraphicsContext, height: CGFloat, by shift: CGFloat) {
        // The same character generator as the labels, at twice the pitch.
        // The slashes are in the table, so the stylised form costs nothing
        // here — eight glyphs like any other eight, and never a filename.
        DotMatrix.draw(
            Faceplate.badge, in: &context,
            origin: CGPoint(x: Theme.cell.width + shift, y: 0),
            pitch: pitch, colour: Theme.wordmarkInk, height: height)
    }

    /// The slices, and the parts of the badge between them, as one list of bands
    /// that covers the whole height exactly once.
    ///
    /// The slices arrive sorted and may still overlap each other, and two bands
    /// over the same rows would draw the badge twice there — a doubled letter,
    /// which reads as a ghost rather than as a tear. So the list is walked with a
    /// cursor and each slice takes only what is left below the last one.
    private func bands(_ slip: Tube.Slip, height: CGFloat)
        -> [(top: CGFloat, depth: CGFloat, shift: CGFloat)]
    {
        var bands: [(top: CGFloat, depth: CGFloat, shift: CGFloat)] = []
        var cursor: CGFloat = 0
        for slice in slip.slices {
            let top = max(cursor, slice.top * height)
            let bottom = min(height, (slice.top + slice.depth) * height)
            guard bottom > top else { continue }
            if top > cursor { bands.append((cursor, top - cursor, 0)) }
            bands.append((top, bottom - top, slice.shift))
            cursor = bottom
        }
        if cursor < height { bands.append((cursor, height - cursor, 0)) }
        return bands
    }

    /// Wait, tear, put it back. Never animated — a tear that eases in is a
    /// transition, and the point of this one is that it was already over by the
    /// time you looked up.
    @MainActor
    private func tear() async {
        guard glitching else { return }
        var tube = Tube(seed: seed)
        var snap = Transaction()
        snap.disablesAnimations = true

        while !Task.isCancelled {
            let slip = tube.nextSlip()
            guard await wait(slip.wait) else { return }
            withTransaction(snap) { torn = slip }
            guard await wait(slip.hold) else {
                // Cancelled mid-tear: the badge is not left broken.
                withTransaction(snap) { torn = nil }
                return
            }
            withTransaction(snap) { torn = nil }
        }
    }

    private func wait(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}
