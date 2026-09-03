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

    /// **How much of the true artwork is showing** (D56). 0 is the cover as the
    /// tube renders it — quantised to the phosphor ramp, in its recess, under
    /// every veil in `ScreenEffects`. 1 is the picture the record actually came
    /// with, at full colour, with nothing over it.
    ///
    /// The knockout of the veils is not done here — it cannot be, they are drawn
    /// above this — but it is driven by the same number, and the anchor below is
    /// how the panel learns which rectangle to take them off.
    var reveal: Double = 0
    /// The pointer arriving on the artwork and leaving it. Reported from the
    /// picture rather than from the square, so that hovering the empty band beside
    /// a cover that is not square does nothing: the thing you are pointing at has
    /// to be the thing that changes.
    var hover: (Bool) -> Void = { _ in }

    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?
    /// The same decode without the phosphor treatment, and nil when the treatment
    /// was never applied — with `.crisp` the cover on the panel is already true
    /// and there is nothing to fade to.
    @State private var truth: CGImage?

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
                        // The true cover over the rendered one, same decode and
                        // therefore same shape, brought up on its opacity. A
                        // cross-fade and not a swap: the picture that arrives is
                        // the one that was already there, so nothing jumps and
                        // nothing has to be re-laid-out at the moment the pointer
                        // crosses the edge.
                        .overlay {
                            if let truth {
                                Image(decorative: truth, scale: displayScale)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .opacity(reveal)
                            }
                        }
                        // Inside the picture, not around it: the cover is
                        // letterboxed in its square when it is not square, and a
                        // frame drawn on the square would be a frame round
                        // nothing on two sides.
                        .overlay {
                            if edge == .bezel {
                                Rectangle()
                                    .strokeBorder(Theme.ground, lineWidth: 4)
                                    .blur(radius: 3)
                                    // The recess is a lighting effect on the
                                    // picture and goes with the rest of them.
                                    .opacity(1 - reveal)
                            }
                        }
                        // The rule stays. It is the edge of the object, not
                        // something the tube is doing to it — a cover with no
                        // border at all stops being mounted in anything and
                        // becomes a hole cut in the screen, which is the thing
                        // `Edge` exists to prevent.
                        .overlay {
                            Rectangle().strokeBorder(Theme.amber(.deep), lineWidth: 1)
                        }
                        .clipped()
                        .onHover(perform: hover)
                        // **How the veils above learn where the cover is.** The
                        // obvious route — measure it, keep the rect in `@State`,
                        // read it back next frame — is the one `rowsToAnalyser`
                        // has a paragraph about not taking: the write lands after
                        // the pass that wanted it. A preference anchor is resolved
                        // in the same pass by whoever reads it, which is what
                        // makes it the right tool and not merely the tidier one.
                        .anchorPreference(key: SleeveBounds.self, value: .bounds) { $0 }
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

        // One decode, two pictures. The treated cover and the true one are the
        // same bytes read once and quantised twice as far, so the hover costs a
        // second image in memory and no second trip to the file.
        let made = await Task.detached(priority: .userInitiated) {
            () -> (shown: CGImage, truth: CGImage?)? in
            guard let decoded = SleeveImage.decode(url, side: side, scale: scale) else {
                return nil
            }
            switch treatment {
            case .crisp: return (decoded, nil)
            case .phosphor: return (SleeveImage.quantise(decoded, ramp: ramp) ?? decoded, decoded)
            }
        }.value

        guard !Task.isCancelled else { return }
        image = made?.shown
        truth = made?.truth
    }
}

/// Where the cover ended up, for the veils that are drawn over it.
///
/// One and only one sleeve is ever on the panel, so the reduce keeps the first
/// anchor it is given rather than combining anything — and a `nil` is the ordinary
/// case, not a failure: no record, no room for a cover, or a cover that has not
/// finished decoding.
struct SleeveBounds: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}
