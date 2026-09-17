import MUTHURKit
import SwiftUI

/// **D94** — the record that is playing, at the foot of a screen that is about
/// something else.
///
/// The library, the check and the plan all go over the deck without stopping
/// it, which was the point of each of them — and each of them then left the
/// music with no way to be touched but going back to the deck for it. The strip
/// is the deck's three verbs and enough of the deck to know what they would act
/// on: the sleeve, the track, where the needle is.
///
/// **Five lines, and all of them taken from the screen above**, never drawn
/// over it: a blank, a rule, and three rows standing beside a sleeve three rows
/// tall. `PanelView` hands the screen above a glass five lines shorter, so each
/// screen's own budget does the rest.
struct MiniPlayerView: View {
    let record: Record
    let state: PlaybackEngine.State
    let sleeve: Sleeve?
    let treatment: SleeveImage.Treatment
    let press: (Readout.Press) -> Void

    static let rows = 5
    private static let thumbRows = 3

    /// The sleeve is square in points and the grid is not, so the columns it
    /// stands in are counted up from its side, not assumed.
    private static var thumbColumns: Int {
        Int((Grid.rows(thumbRows) / Theme.cell.width).rounded(.up))
    }

    /// What is left of the panel's width for the words.
    private static var textColumns: Int { PanelGrid.width - thumbColumns - 2 }

    private var track: Track? {
        record.running.indices.contains(state.row) ? record.running[state.row] : nil
    }

    private var paused: Bool { state.mode == .paused }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelBlank()
            Bloom { rule }
            HStack(alignment: .top, spacing: 0) {
                Spacer().frame(width: Grid.margin)
                ThumbView(sleeve: sleeve, treatment: treatment, side: Grid.rows(Self.thumbRows))
                    .frame(width: Grid.columns(Self.thumbColumns), alignment: .leading)
                Spacer().frame(width: Grid.columns(2))
                Bloom { words }
            }
        }
        .frame(width: Theme.panelWidth, alignment: .leading)
    }

    /// `── NOW PLAYING ────`, the way a directory's rule is drawn on the shelf:
    /// the strip is a section of the screen, not a box laid on it.
    private var rule: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            run("── ", Theme.etch).font(Theme.swiftUIFont)
            MatrixText(text: paused ? "HELD" : "NOW PLAYING", colour: Theme.etch)
            run(" ", Theme.etch).font(Theme.swiftUIFont)
            Rectangle().fill(Theme.etch).frame(height: 1)
        }
        .gridLine()
    }

    private var words: some View {
        let columns = Self.textColumns
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                run(paused ? Readout.Mark.held.glyph : Readout.Mark.playing.glyph, Theme.lit)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(2), alignment: .leading)
                run(track?.title ?? "—", Theme.text, columns: columns - 2).font(Theme.swiftUIFont)
            }
            .gridLine()

            run(byline, Theme.dim, columns: columns).font(Theme.swiftUIFont).gridLine()

            HStack(spacing: 0) {
                ForEach(Array(Readout.miniTransport(paused: paused).enumerated()), id: \.offset) {
                    index, cap in
                    if index > 0 { Spacer().frame(width: Grid.columns(1)) }
                    // Four columns each: `◀◀` and `▶▶` with a column either
                    // side, and the middle plate the same whether it is
                    // showing `❚❚` or `▶`.
                    CapView(cap: cap, press: press, plate: 4)
                }
                Spacer(minLength: 0)
                MatrixText(
                    text: Readout.trackLabel(row: state.row, of: record.order.count),
                    colour: Theme.etch)
                Spacer().frame(width: Grid.columns(2))
                SegmentText(text: Readout.mmss(Int(state.positionInTrack)), colour: Theme.lit)
                run(" / ", Theme.etch).font(Theme.swiftUIFont)
                SegmentText(text: Readout.mmss(Int(state.trackDuration)), colour: Theme.dim)
            }
            .gridLine()
        }
        .frame(width: Grid.columns(columns), alignment: .leading)
    }

    /// The track's artist, and the record's name after it — on a compilation
    /// those are two different people, and on everything else the album is
    /// the half that says which of their records this is.
    private var byline: String {
        let artist = track?.artist ?? ""
        let album = record.album
        switch (artist.isEmpty, album.isEmpty) {
        case (false, false): return "\(artist) · \(album)"
        case (false, true): return artist
        case (true, false): return album
        case (true, true): return "—"
        }
    }
}

/// The deck's sleeve, small. The phosphor rendering and its rule, and none of
/// the hover: a cover three rows tall has no true picture worth lifting the
/// glass off, and there is only ever one sleeve the veils may be told about.
private struct ThumbView: View {
    let sleeve: Sleeve?
    let treatment: SleeveImage.Treatment
    let side: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?

    var body: some View {
        Color.clear
            .frame(width: side, height: side)
            .overlay {
                if let image {
                    Image(decorative: image, scale: displayScale)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    // No sleeve yet, or none at all: the square is still the
                    // record's place, and says what is in it.
                    run(Readout.Mark.playing.glyph, Theme.etch).font(Theme.swiftUIFont)
                }
            }
            .overlay { Rectangle().strokeBorder(Theme.amber(.deep), lineWidth: 1) }
            .clipped()
            .task(id: sleeve?.url) { await render() }
    }

    private func render() async {
        guard let url = sleeve?.url else {
            image = nil
            return
        }
        let side = side
        let scale = displayScale
        let treatment = treatment
        let ramp = Theme.sleeveRamp
        let made = await Task.detached(priority: .utility) { () -> CGImage? in
            guard let decoded = SleeveImage.decode(url, side: side, scale: scale) else { return nil }
            switch treatment {
            case .crisp: return decoded
            case .phosphor: return SleeveImage.quantise(decoded, ramp: ramp) ?? decoded
            }
        }.value
        guard !Task.isCancelled else { return }
        image = made
    }
}
