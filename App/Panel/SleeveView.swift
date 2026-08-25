import MUTHURKit
import SwiftUI

/// The cover, beside the panel (`player:1738`).
///
/// A record has a front, and a player that never shows it is missing the part of
/// the object you would actually be looking at. There is room for it because the
/// panel's width is fixed: the panel ends at 71, the gutter takes 72 and 73, and
/// the cover goes at column 74, row 3, level with the name of the record.
///
/// **Nothing here waits for anything.** §5 does the finding and the fetching and
/// the caching; by the time a `Sleeve` reaches this view its bytes are already on
/// disk. No cover means no cover, and the panel is exactly the panel it has
/// always been.
struct SleeveView: View {

    /// How the cover is seated. A lit rectangle against the dark reads as a hole
    /// cut in the screen rather than an object on it, and the gutter alone only
    /// keeps it from touching the panel — it does not put it *in* one. A taste
    /// call, and both are built.
    enum Edge: String, Sendable {
        /// One dim rule around the picture, the same amber the analyser's bezel
        /// is drawn in. The instrument's own vocabulary and nothing else.
        case rule
        /// The rule, and the picture darkened toward its own edges — the cover
        /// sitting in a recess rather than lying on the glass.
        case bezel
    }

    let sleeve: Sleeve
    let treatment: SleeveImage.Treatment
    var edge: Edge = .rule
    /// The square the cover has to sit in, worked out by `SleeveFrame`.
    let side: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?

    var body: some View {
        // The square first and the picture over it, rather than the picture and
        // nothing when there is no picture yet. A view that is empty while it
        // waits never appears, and the work that would end the waiting is
        // attached to it appearing — so an empty square is what holds the place
        // open. It draws nothing: the ground shows through it.
        Color.clear
            .frame(width: side, height: side)
            .overlay(alignment: .topLeading) {
                if let image {
                    Image(decorative: image, scale: displayScale)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        // Inside the picture, not around it: the cover is
                        // letterboxed in its square when it is not square, and a
                        // frame drawn on the square would be a frame round
                        // nothing on two sides.
                        .overlay {
                            if edge == .bezel {
                                Rectangle()
                                    .strokeBorder(Theme.ground, lineWidth: 4)
                                    .blur(radius: 3)
                            }
                        }
                        .overlay {
                            Rectangle().strokeBorder(Theme.amber(.deep), lineWidth: 1)
                        }
                        .clipped()
                }
            }
            .task(
                id: Recipe(
                    url: sleeve.url, side: side, treatment: treatment, scale: displayScale)
            ) {
                await render()
            }
    }

    /// Everything that changes what is on screen. A window dragged wider is a new
    /// recipe and the picture is resampled rather than merely stretched — the same
    /// reason `art_tick` throws `ART_STR` away when the geometry changes
    /// (`player:3155`).
    private struct Recipe: Equatable {
        let url: URL
        let side: CGFloat
        let treatment: SleeveImage.Treatment
        let scale: CGFloat
    }

    private func render() async {
        let url = sleeve.url
        let side = side
        let scale = displayScale
        let treatment = treatment
        let ramp = Theme.sleeveRamp

        let made = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let decoded = SleeveImage.decode(url, side: side, scale: scale) else {
                return nil
            }
            switch treatment {
            case .crisp: return decoded
            case .phosphor: return SleeveImage.quantise(decoded, ramp: ramp) ?? decoded
            }
        }.value

        guard !Task.isCancelled else { return }
        image = made
    }
}
