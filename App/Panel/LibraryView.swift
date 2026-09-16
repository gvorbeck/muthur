import MUTHURKit
import SwiftUI

/// **D91** — the library: every directory you keep records in, a rule for each,
/// and the sleeves under it.
///
/// **The panel's column above and below, the shelf across the whole glass in
/// between.** The faceplate, the three fields and the keys stay on the panel's
/// grid, where every other screen keeps them, so that pressing ⌘L does not move
/// the place your eye goes to for the keys. The sleeves do not, because a shelf
/// seventy columns wide is four records to a row and the window is usually
/// wider than that.
///
/// The sleeves are drawn the way the one beside the deck is (D56): the phosphor
/// rendering, and the true picture brought up under the pointer.
struct LibraryView: View {
    let library: LibraryModel
    let meta: String
    let treatment: SleeveImage.Treatment
    let glitching: Bool
    let legend: [[Readout.Cap]]
    let status: String?
    /// The slot under the pointer, whose sleeve is lit. Stays set for the
    /// length of the fade out, which is why it is not the same as `pointing`.
    let lit: Int?
    /// The slot the fields describe while the pointer is on the shelf.
    let pointing: Int?
    let reveal: Double
    let press: (Readout.Press) -> Void
    let hover: (Int, Bool) -> Void

    // MARK: - The arithmetic

    /// Six lines square, which is the smallest a sleeve can be and still be
    /// recognised from across a room, and a line of blank under each row.
    static var side: CGFloat { Grid.rows(LibraryModel.tileRows) }
    static var gap: CGFloat { Grid.columns(2) }

    /// The bar down the right-hand edge and the slop beside it. Two columns of
    /// glass the sleeves do not get: one the bar is drawn in, one so a thing a
    /// column wide can still be caught by a hand aiming at it.
    static var barWidth: CGFloat { Grid.columns(2) }

    static func perRow(width: CGFloat) -> Int {
        let glass = width - 2 * Grid.margin - barWidth
        return max(1, Int(((glass + gap) / (side + gap)).rounded(.down)))
    }

    /// The lines the shelf may stand in: the screen, less the faceplate and its
    /// blank, the three fields and their blank, the `MORE` line, a blank and two
    /// rows of keys, and a blank and a status line.
    ///
    /// **All of it reserved, whether or not it is drawn.** The status line comes
    /// and goes with every key and the legend loses a row when the library is
    /// empty, and a shelf that grew and shrank a row of sleeves with them would
    /// move the record you were looking at out from under the pointer.
    static func budget(height: CGFloat) -> Int {
        let lines = Int((height / Theme.cell.height).rounded(.down))
        return max(1, lines - 12)
    }

    // MARK: - The screen

    var body: some View {
        let shelf = library.shelf
        let lines = library.lines
        let visible = library.visible
        VStack(alignment: .leading, spacing: 0) {
            Bloom {
                VStack(alignment: .leading, spacing: 0) {
                    FaceplateView(meta: meta, glitching: glitching)
                    PanelBlank()
                    fields(shelf)
                    PanelBlank()
                }
                .frame(width: Theme.panelWidth, alignment: .leading)
            }

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(visible, id: \.self) { index in
                        line(lines[index], shelf: shelf)
                    }
                }
                // The first line on the glass may be half off the top of it:
                // the shelf moves a row at a time and a row of sleeves is
                // seven rows tall, so the fold falls where it falls.
                .offset(y: -Grid.rows(library.window.above))
                .frame(maxWidth: .infinity, alignment: .topLeading)

                ShelfBarView(library: library)
            }
            .frame(height: Grid.rows(library.budget), alignment: .top)
            .clipped()

            Bloom {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer().frame(width: Grid.margin)
                        if library.below > 0 {
                            run(Readout.more(library.below), Theme.etch).font(Theme.swiftUIFont)
                        }
                        Spacer(minLength: 0)
                    }
                    .gridLine()
                    PanelBlank()
                    KeycapsView(legend: legend, press: press)
                    if let status {
                        PanelBlank()
                        StatusView(text: status)
                    }
                }
                .frame(width: Theme.panelWidth, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - The fields

    /// The record the pointer is on, or the cursor's when the pointer is not on
    /// the shelf — the header's three rows, about a record that is not playing.
    @ViewBuilder
    private func fields(_ shelf: LibraryShelf) -> some View {
        let index = pointing ?? library.cursor
        if let slot = shelf.slot(index) {
            let section = shelf.sections[slot.section]
            let offline = library.isOnline(section) ? "" : " · OFFLINE"
            if let album = slot.album {
                FieldRow(label: "ALBUM", value: dash(album.title))
                FieldRow(label: "ARTIST", value: dash(album.artist))
                FieldRow(label: "SOURCE", value: album.path + offline, colour: Theme.dim)
            } else {
                FieldRow(label: "ALBUM", value: "—", colour: Theme.dim)
                FieldRow(label: "ARTIST", value: "—", colour: Theme.dim)
                FieldRow(
                    label: "SOURCE",
                    value: (section.directory.scanned == nil ? "NOT WALKED YET" : "NOTHING IN IT") + offline,
                    colour: Theme.dim)
            }
        } else {
            FieldRow(label: "ALBUM", value: "NO DIRECTORIES IN THE LIBRARY", colour: Theme.etch)
            FieldRow(label: "ARTIST", value: "—", colour: Theme.dim)
            FieldRow(label: "SOURCE", value: "—", colour: Theme.dim)
        }
    }

    private func dash(_ value: String) -> String { value.isEmpty ? "—" : value }

    // MARK: - The lines

    @ViewBuilder
    private func line(_ line: LibraryShelf.Line, shelf: LibraryShelf) -> some View {
        switch line {
        case .rule(let index):
            rule(shelf.sections[index])
        case .empty(let index):
            empty(shelf.sections[index])
        case .tiles:
            let slots = shelf.slots(on: line, perRow: library.perRow)
            HStack(alignment: .top, spacing: Self.gap) {
                ForEach(slots, id: \.self) { index in
                    if let slot = shelf.slot(index), let album = slot.album {
                        let section = shelf.sections[slot.section]
                        TileView(
                            album: album,
                            cover: album.cover.map { library.file.covers.appending(path: $0) },
                            treatment: treatment,
                            cursor: index == library.cursor,
                            online: library.isOnline(section),
                            lit: index == lit,
                            reveal: reveal,
                            play: { library.play(index) },
                            hover: { hover(index, $0) })
                    }
                }
            }
            .padding(.leading, Grid.margin)
            .frame(height: Grid.rows(LibraryModel.tileRows + 1), alignment: .topLeading)
        }
    }

    /// The directory's rule, the way `burncd`'s disc rules divide a plan: a run
    /// of etch with the name in it, and the one fact about the directory that
    /// changes what you can do with the records under it.
    private func rule(_ section: LibraryShelf.Section) -> some View {
        let online = library.isOnline(section)
        let count = section.albums.count
        return Bloom {
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.margin)
                (run("── ", Theme.etch)
                    + run(Columns.truncate(section.directory.path, to: PanelGrid.textWidth), Theme.dim)
                    + run(" · \(count) RECORD\(count == 1 ? "" : "S")", Theme.etch)
                    + run(online ? " " : " · OFFLINE ", online ? Theme.etch : Theme.lit))
                    .font(Theme.swiftUIFont)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Rectangle().fill(Theme.etch).frame(height: 1)
                Spacer().frame(width: Grid.margin)
            }
            .gridLine()
        }
    }

    /// A directory with nothing on its shelf still has a place for the cursor,
    /// so that `X` can reach it (`LibraryShelf`).
    private func empty(_ section: LibraryShelf.Section) -> some View {
        let cursor = library.cursor == section.first
        let what =
            section.directory.scanned == nil
            ? (library.isOnline(section) ? "NOT WALKED YET" : "NOT WALKED YET · PLUG IT IN")
            : "NOTHING IN IT"
        return Bloom {
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.margin)
                run(cursor ? Readout.cursorGlyph : " ", Theme.lit)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(2), alignment: .leading)
                run(what, cursor ? Theme.text : Theme.etch).font(Theme.swiftUIFont)
                Spacer(minLength: 0)
            }
            .gridLine()
            .contentShape(Rectangle())
            .onTapGesture { library.point(at: section.first) }
        }
    }
}

// MARK: - The bar

/// How far down the shelf you are, and a handle to take it somewhere else.
///
/// **Neither script has one** — a terminal shows you `MORE` and nothing else,
/// and `MORE` is still here under the shelf, because it says how many records
/// are below rather than how far down a wall of them you have come. A window
/// has a pointer, and a wall of four hundred sleeves is the first thing in this
/// port long enough that dragging it is faster than any key.
///
/// It is drawn in the panel's own rows, a column wide, and only when there is
/// more shelf than glass. The space it stands in is kept whether or not it is
/// drawn, so a shelf does not change width the moment it grows past the fold.
private struct ShelfBarView: View {
    let library: LibraryModel

    /// Rows between the pointer and the head of the thumb, held for the length
    /// of a drag so the thumb does not jump under the finger that took it.
    @State private var grab: CGFloat?

    var body: some View {
        let rows = CGFloat(library.rows)
        let budget = CGFloat(library.budget)
        let height = Grid.rows(library.budget)
        ZStack(alignment: .topTrailing) {
            if rows > budget {
                // The thumb is the screen's share of the shelf, never smaller
                // than a row, so it is still a thing you can take hold of on a
                // library of four hundred records.
                let thumb = max(Grid.rows(1), height * budget / rows)
                let travel = height - thumb
                let at = travel * CGFloat(library.offset) / (rows - budget)
                Rectangle()
                    .fill(Theme.amber(.field))
                    .frame(width: Grid.columns(1))
                Rectangle()
                    .fill(grab == nil ? Theme.etch : Theme.lit)
                    .frame(width: Grid.columns(1), height: thumb)
                    .offset(y: at)
            }
        }
        .frame(width: LibraryView.barWidth, height: height, alignment: .topTrailing)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard rows > budget else { return }
                    let thumb = max(Grid.rows(1), height * budget / rows)
                    let travel = height - thumb
                    guard travel > 0 else { return }
                    let at = travel * CGFloat(library.offset) / (rows - budget)
                    let grab =
                        grab
                        // A press on the thumb takes it where it was held; a
                        // press anywhere else on the bar brings it to the
                        // pointer, which is the one place it was asked for.
                        ?? ((value.location.y >= at && value.location.y <= at + thumb)
                            ? value.location.y - at : thumb / 2)
                    self.grab = grab
                    let head = min(max(0, value.location.y - grab), travel)
                    library.scroll(to: Int((head / travel * (rows - budget)).rounded()))
                }
                .onEnded { _ in grab = nil }
        )
    }
}

// MARK: - A sleeve on the shelf

/// One record: its sleeve, or its name where it has none.
private struct TileView: View {
    let album: Library.Album
    let cover: URL?
    let treatment: SleeveImage.Treatment
    let cursor: Bool
    let online: Bool
    let lit: Bool
    let reveal: Double
    let play: () -> Void
    let hover: (Bool) -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var rendered: TileImages.Rendered?
    /// The decode came back empty — no file, or not a picture.
    @State private var failed = false

    private var side: CGFloat { LibraryView.side }

    private var recipe: TileImages.Recipe? {
        cover.map { TileImages.Recipe(url: $0, side: side, scale: displayScale, treatment: treatment) }
    }

    var body: some View {
        // Looked up in the body as well as fetched by the task, so a row that
        // scrolls back on to the screen is drawn with its sleeves in the frame
        // it arrives in, rather than as a row of empty squares for one.
        let images = rendered ?? recipe.flatMap { TileImages.cache.object(forKey: $0.key) }
        Color.clear
            .frame(width: side, height: side)
            .overlay {
                if let images {
                    Image(decorative: images.shown, scale: displayScale)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay {
                            if lit, let truth = images.truth {
                                Image(decorative: truth, scale: displayScale)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .opacity(reveal)
                            }
                        }
                } else if cover == nil || failed {
                    name
                }
            }
            .overlay { Rectangle().strokeBorder(Theme.amber(.deep), lineWidth: 1) }
            .overlay {
                if cursor { Rectangle().strokeBorder(Theme.lit, lineWidth: 2) }
            }
            .clipped()
            .contentShape(Rectangle())
            // **Dimmed, and deaf.** A record on a drive that is not plugged in is
            // still on the shelf — it is yours, and it will be back — but a click
            // on it would be a click that could only fail.
            .opacity(online ? 1 : 0.35)
            .allowsHitTesting(online)
            .onTapGesture(perform: play)
            .onHover(perform: hover)
            // The one lit sleeve tells the veils where it is, as the deck's does
            // (`SleeveBounds`). Only the lit one, and only with a picture under
            // it: a hole cut over a name would lift the veils off text that has
            // no truer form to show.
            .anchorPreference(key: SleeveBounds.self, value: .bounds) {
                lit && online && images?.truth != nil ? $0 : nil
            }
            .task(id: recipe) { await render() }
    }

    /// A record with no sleeve is its name, which is all anyone has to go on.
    private var name: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: album.title).foregroundColor(Theme.text).lineLimit(3)
            Text(verbatim: album.artist).foregroundColor(Theme.dim).lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(Theme.swiftUIFont)
        .padding(Grid.columns(1))
        .frame(width: side, height: side, alignment: .topLeading)
    }

    private func render() async {
        guard let recipe else {
            rendered = nil
            failed = false
            return
        }
        if let hit = TileImages.cache.object(forKey: recipe.key) {
            rendered = hit
            failed = false
            return
        }
        rendered = nil
        failed = false
        let ramp = Theme.sleeveRamp
        let made = await Task.detached(priority: .userInitiated) {
            () -> (shown: CGImage, truth: CGImage?)? in
            guard let decoded = SleeveImage.decode(recipe.url, side: recipe.side, scale: recipe.scale) else {
                return nil
            }
            switch recipe.treatment {
            case .crisp: return (decoded, nil)
            case .phosphor: return (SleeveImage.quantise(decoded, ramp: ramp) ?? decoded, decoded)
            }
        }.value
        guard !Task.isCancelled else { return }
        guard let made else {
            failed = true
            return
        }
        let images = TileImages.Rendered(shown: made.shown, truth: made.truth)
        TileImages.cache.setObject(images, forKey: recipe.key)
        rendered = images
    }
}

/// The shelf's decoded sleeves, kept while they are likely to scroll back.
///
/// Decoded from the library's own 600-pixel copies, which is quick — but a
/// screenful of them at once, every time the wheel brings a row back, is a
/// stutter under the pointer. A few screens' worth, and no more: the copies on
/// disk are the cache that matters.
@MainActor
enum TileImages {
    final class Rendered {
        let shown: CGImage
        let truth: CGImage?
        init(shown: CGImage, truth: CGImage?) {
            self.shown = shown
            self.truth = truth
        }
    }

    struct Recipe: Equatable, Sendable {
        let url: URL
        let side: CGFloat
        let scale: CGFloat
        let treatment: SleeveImage.Treatment

        var key: NSString { "\(url.lastPathComponent)|\(side)|\(scale)|\(treatment.rawValue)" as NSString }
    }

    static let cache: NSCache<NSString, Rendered> = {
        let cache = NSCache<NSString, Rendered>()
        cache.countLimit = 96
        return cache
    }()
}
