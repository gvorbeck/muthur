import MUTHURKit
import SwiftUI

/// The wordmark, the rule, and the state of the machine stamped at the far end
/// the way a deck prints its mode (`panel.sh:256`).
///
/// **Nothing on this line is a `Text`, and that is the point.**
///
/// It was, and twice it came out as `MU/TH/UR ━━━━━…  STOPPED`. `faceplate`
/// builds its rule with `repv '━'` and cannot truncate anything; the `…` was
/// SwiftUI's, put there because in an `HStack` that has been proposed less width
/// than it wants, the `Text` with the least resistance gets squeezed and
/// ellipsizes rather than complaining. The first fix moved the width at which
/// that happens, which is not a fix — it is the same bug at a different window
/// size, and it duly came back.
///
/// A `Canvas` has no truncation machinery at all. It draws what the grid
/// arithmetic tells it and clips at its own edge, so an overrun is visible as an
/// overrun. That is also what bash does when the meta is too long: the rule
/// gives way to its floor of two and the *line* runs past the panel, because a
/// mode word is not allowed to lose a letter (`panel.sh:257`).
struct FaceplateView: View {
    let meta: String

    private var rule: Int {
        Faceplate.rule(meta: meta, plate: WordmarkView.columns)
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)

            WordmarkView()

            // Drawn, not typed, for the same reason `Bezel` is: the glyph is a
            // heavy horizontal that fills its em box, and a rule made of them
            // has a seam at every character boundary once the line is taller
            // than the em box.
            Canvas { context, size in
                let y = size.height / 2
                context.fill(
                    Path(
                        CGRect(
                            x: Theme.cell.width, y: y - Theme.ruleWeight / 2,
                            width: size.width - Theme.cell.width * 2,
                            height: Theme.ruleWeight)),
                    with: .color(Theme.etch))
            }
            .frame(width: Grid.columns(rule + 2))
            .gridLine()

            MatrixText(text: meta, colour: Theme.etch)

            Spacer(minLength: 0)
        }
        .gridLine()
    }
}
