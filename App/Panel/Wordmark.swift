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
struct WordmarkView: View {

    /// How many columns of the faceplate it takes, so the rule can be given the
    /// rest. Twice the pitch is twice the width, and the rule gives way for it
    /// the same way it gives way for a long mode word (`panel.sh:257`).
    static var columns: Int { Columns.width(of: Faceplate.badge) * 2 + 2 }

    var body: some View {
        Canvas { context, size in
            // The same character generator as the labels, at twice the pitch.
            // The slashes are in the table, so the stylised form costs nothing
            // here — eight glyphs like any other eight, and never a filename.
            DotMatrix.draw(
                Faceplate.badge, in: &context,
                origin: CGPoint(x: Theme.cell.width, y: 0),
                pitch: Theme.cell.width * 2 / CGFloat(DotMatrix.columns + 1),
                colour: Theme.wordmarkInk, height: size.height)
        }
        .frame(width: Grid.columns(WordmarkView.columns))
        .gridLine()
    }
}
