import AppKit
import MUTHURKit
import SwiftUI

/// The panel the app spends its life on (`player:2260`).
///
/// Three blocks under the faceplate: what the album is, what its tracks are, and
/// where in them the playhead has got to. Two meters rather than one, because
/// they answer different questions and each one is the wrong answer to the
/// other's — the track bar is *how much of this song is left*, which is what you
/// want when deciding whether to skip; the album meter is the shape of the
/// record and where in that shape you are.
struct PanelView: View {
    @Bindable var model: PanelModel

    @FocusState private var focused: Bool
    @State private var wheel: Any?

    var body: some View {
        Chassis { screen }
            .frame(minWidth: Theme.panelWidth, minHeight: Grid.rows(28))
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onAppear {
                focused = true
                startWheel()
            }
            .onDisappear { stopWheel() }
            .onKeyPress(phases: [.down, .repeat]) { press in handle(press) }
    }

    /// Everything inside the glass: the burn under the panel, the panel, the
    /// sleeve, and the tube over the lot of it.
    private var screen: some View {
        GeometryReader { geometry in
            let rows = trackRows(in: geometry.size.height)
            HStack(alignment: .top, spacing: 0) {
                Bloom {
                    panel(rows: rows)
                        .background(alignment: .topLeading) {
                            if !model.isPicking {
                                BurnIn(marks: burn(rows: rows))
                            }
                        }
                }

                // The sleeve, when there is one and there is room for one. Both
                // halves of that are `SleeveFrame`'s answer, and a nil is a window
                // too narrow rather than a failure: the panel is unchanged either
                // way (`player:1746`).
                if let sleeve = model.sleeve,
                    let side = sleeveSide(width: geometry.size.width, trackRows: rows)
                {
                    Color.clear.frame(width: Theme.sleeveGutter)
                    SleeveView(
                        sleeve: sleeve, treatment: model.sleeveTreatment,
                        edge: model.sleeveEdge, side: side
                    )
                    // Row 3: the cover starts level with the album title.
                    .padding(.top, Grid.rows(PanelGrid.sleeveRow - 1))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: rows, initial: true) { model.resized(rows: rows) }
        }
        .padding(.vertical, Theme.blank)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.ground)
        .overlay { ScreenEffects() }
    }

    private func panel(rows: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
                FaceplateView(meta: model.faceplateMeta)
                PanelBlank()

                if model.isPicking, let entries = model.pickerEntries {
                    PickerView(
                        entries: entries,
                        cursor: model.pickerCursor,
                        visibleRange: model.pickerVisible,
                        below: model.pickerBelow,
                        click: { model.pickerClick(row: $0) }
                    )
                    .frame(height: Grid.rows(rows + 4))
                } else if let header = model.header, let record = model.record {
                    HeaderView(block: header)
                    PanelBlank()
                    TrackListView(
                        model: model, record: record,
                        runout: Theme.composition == .runout
                            ? listRows(rows: rows) - min(trackCount, rows) : 0
                    )
                    .frame(height: Grid.rows(listRows(rows: rows)))
                } else {
                    EmptyPanelView(stage: model.stage)
                        .frame(height: Grid.rows(rows + 4))
                }

                if !model.isPicking {
                    PanelBlank()
                    MeterView(
                        label: Readout.trackLabel(row: model.state.row, of: trackCount),
                        position: Int(model.state.positionInTrack),
                        length: Int(model.state.trackDuration),
                        cells: Meter.trackCells(
                            done: Int(model.state.positionInTrack * 1000),
                            total: Int(model.state.trackDuration * 1000),
                            width: PanelGrid.stripWidth),
                        seek: { cell, dragging in
                            if !dragging { model.seekTrack(cell: cell) }
                        }
                    )

                    PanelBlank()
                    MeterView(
                        label: Readout.albumLabel,
                        position: Int(model.state.positionInRecord),
                        length: Int(model.state.recordDuration),
                        cells: albumCells,
                        seek: { cell, dragging in
                            model.seekRecord(cell: cell, dragging: dragging)
                        }
                    )
                    AnalyserView(grid: analyserGrid)
                }

                PanelBlank()
                KeycapsView(
                    legend: model.isPicking ? Readout.pickerLegend : Readout.legend,
                    press: tapped
                )

                if let status = model.statusLine {
                    PanelBlank()
                    StatusView(text: status)
                }

                Spacer(minLength: 0)
            }
            .frame(width: Theme.panelWidth, alignment: .leading)
    }

    // MARK: - How big the sleeve may be (§5)

    /// `art_tick`'s arithmetic, with the two bounds it needs worked out here
    /// because here is where they are known (`player:3133`).
    private func sleeveSide(width: CGFloat, trackRows rows: Int) -> CGFloat? {
        let spare = width - Theme.panelWidth - Theme.sleeveGutter
        guard
            let tall = SleeveFrame.rows(
                availableColumns: Int((spare / Theme.cell.width).rounded(.down)),
                rowsToAnalyser: rowsToAnalyser(trackRows: rows),
                cellAspect: Theme.cell.height / Theme.cell.width)
        else { return nil }
        return Grid.rows(tall)
    }

    /// bash's `spec_row - ART_ROW0`: the rows between the top of the sleeve and
    /// the top of the analyser (`player:3145`).
    ///
    /// Counted rather than measured. Asking the layout where it put the analyser
    /// and keeping the answer in `@State` is the obvious way and it does not
    /// work: the write lands after the pass that would have used it, so the
    /// sleeve reads a height of zero on every frame and is never drawn. The rows
    /// above the analyser are the same ones `trackRows` is already subtracting,
    /// so they are added up instead — which is what `art_tick` does too.
    private func rowsToAnalyser(trackRows rows: Int) -> Int {
        // Faceplate 1, blank 1, header, blank 1, the list, blank 1, meter 2,
        // blank 1, meter 2 — and the sleeve starts two rows down from the top.
        9 + headerRows + listRows(rows: rows) - (PanelGrid.sleeveRow - 1)
    }

    private var headerRows: Int { model.header?.rows.count ?? 3 }

    // MARK: - The composition (§10)

    /// **How many rows the list block stands in, which is the whole of the
    /// lopsided-panel question.**
    ///
    /// `deck` gives it the rows it actually uses and lets everything below close
    /// up under it. That is also what the script does — `np_frame`'s loop stops
    /// at the last track and prints the meters on the next line (`player:2340`),
    /// so `np_rows` is a *budget*, not a height. The port had been reserving the
    /// whole budget whether the record filled it or not, which is where the hole
    /// between the last track and the meters came from; and because the sleeve's
    /// height is measured down to the analyser, the hole also made the sleeve
    /// taller than the panel it was standing beside. One number fixes both.
    ///
    /// `runout` keeps the budget and fills what is left of it, on the argument
    /// that an instrument should reach the bottom of its own chassis. It is the
    /// divergence of the two, and it is here to be looked at rather than argued
    /// about.
    private func listRows(rows: Int) -> Int {
        let more = model.below > 0 ? 1 : 0
        switch Theme.composition {
        case .deck: return min(trackCount, rows) + more
        case .runout: return rows + more
        }
    }

    // MARK: - Where the chrome has sat (§10)

    /// The rectangles the furniture has never moved out of. Counted off the same
    /// arithmetic as everything else, so a burn cannot drift away from the thing
    /// that burnt it.
    private func burn(rows: Int) -> [GridRect] {
        let panel = PanelGrid.width
        let margin = PanelGrid.margin
        let list = 3 + headerRows
        let track = list + listRows(rows: rows) + 1
        let album = track + 3
        let analyser = album + 2
        let keycaps = analyser + AnalyserColumns.rows + 1
        return [
            GridRect(column: margin, row: 0, columns: panel, rows: 1),
            GridRect(column: margin, row: track + 1, columns: panel, rows: 1),
            GridRect(column: margin, row: album + 1, columns: panel, rows: 1),
            GridRect(column: margin, row: analyser, columns: panel, rows: AnalyserColumns.rows),
            GridRect(column: margin, row: keycaps, columns: 34, rows: 2),
        ]
    }

    private var trackCount: Int { model.record?.order.count ?? 0 }

    /// The album meter's bands, and the one thing about it that is not obvious:
    /// a record with nothing playing still draws its bands. The shape of the
    /// record is a fact about the record, not about the needle.
    private var albumCells: [Meter.Cell] {
        guard let record = model.record, record.total > 0 else {
            return [Meter.Cell](repeating: .runout, count: PanelGrid.stripWidth)
        }
        let bands = Meter.bands(
            for: record.running.map(\.duration), cells: PanelGrid.stripWidth)
        let units = PanelGrid.stripWidth * Meter.unitsPerCell
        let head = Int(model.state.positionInRecord / Double(record.total) * Double(units))
        return Meter.cells(head: min(head, units), bands: bands, width: PanelGrid.stripWidth)
    }

    /// It stops dead when the music is paused, which is the one thing the
    /// analyser has to say that the numbers do not say faster (`player:588`).
    private var analyserGrid: [[AnalyserColumns.Cell]] {
        model.state.mode == .playing && !model.analyser.isIdle
            ? model.analyser.grid
            : AnalyserColumns.idle
    }

    // MARK: - How many track rows fit

    /// Counted rather than assumed, for the same reason `np_fit_rows` counts
    /// (`player:2443`): a panel that draws more rows than it has room for pushes
    /// its own top off the screen, and after that every block is one line out
    /// from where the last frame left it.
    ///
    /// The one difference from bash is that here the window can change size
    /// while the record plays, so this is arithmetic on every frame rather than
    /// on every `SIGWINCH`.
    private func trackRows(in height: CGFloat) -> Int {
        let lines = Int((height / Theme.cell.height).rounded(.down))
        var chrome = 17 + (model.header?.rows.count ?? 3)
        if model.statusLine != nil { chrome += 2 }
        if trackCount > lines - chrome { chrome += 1 }
        return max(1, lines - chrome)
    }

    // MARK: - The keys (§6.1)

    /// **The one place that knows what a cap means** (D30). Every key the legend
    /// names goes through here and so does every press of the drawn cap beside
    /// it, which is the only way the two can be guaranteed to stay the same
    /// switch. A binding added to one is added to both or to neither.
    ///
    /// Shift is carried rather than assumed, so a shift-click on `←→` seeks the
    /// thirty seconds a shift-arrow does. The cap is the key, including the parts
    /// of the key that are not printed on it.
    private func perform(_ press: Readout.Press, shift: Bool = false) {
        if model.isPicking {
            performPicker(press)
            return
        }
        switch press {
        case .play: model.space()
        case .seekBack: model.seek(by: shift ? -30 : -5)
        case .seekForward: model.seek(by: shift ? 30 : 5)
        case .selectUp: model.step(by: -1)
        case .selectDown: model.step(by: 1)
        case .jump: model.jump()
        case .next: model.next()
        case .previous: model.previous()
        case .shuffle: model.toggleShuffle()
        case .repeatMode: model.cycleRepeat()
        case .rescan: break
        case .quit: NSApplication.shared.terminate(nil)
        }
    }

    private func performPicker(_ press: Readout.Press) {
        switch press {
        case .selectUp: model.pickerStep(by: -1)
        case .selectDown: model.pickerStep(by: 1)
        case .jump: model.openPicked()
        case .rescan: model.rescan()
        case .quit: NSApplication.shared.terminate(nil)
        default: break
        }
    }

    /// A cap under the pointer. The modifier is read off the event stream rather
    /// than carried by the gesture, because a `DragGesture` does not report one.
    private func tapped(_ press: Readout.Press) {
        perform(press, shift: NSEvent.modifierFlags.contains(.shift))
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        if model.isPicking { return handlePicker(press) }
        let shift = press.modifiers.contains(.shift)
        switch press.key {
        case .space:
            perform(.play)
        case .leftArrow:
            perform(.seekBack, shift: shift)
        case .rightArrow:
            perform(.seekForward, shift: shift)
        case .upArrow:
            perform(.selectUp)
        case .downArrow:
            perform(.selectDown)
        case .pageUp:
            model.step(by: -model.visibleRows)
        case .pageDown:
            model.step(by: model.visibleRows)
        case .return:
            perform(.jump)
        default:
            return letter(press)
        }
        return .handled
    }

    private func handlePicker(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow: model.pickerStep(by: -1)
        case .downArrow: model.pickerStep(by: 1)
        case .pageUp: model.pickerPageStep(by: -1)
        case .pageDown: model.pickerPageStep(by: 1)
        case .return: model.openPicked()
        default: return pickerLetter(press)
        }
        return .handled
    }

    private func pickerLetter(_ press: KeyPress) -> KeyPress.Result {
        switch press.characters.lowercased() {
        case "k": model.pickerStep(by: -1)
        case "j": model.pickerStep(by: 1)
        case "r": model.rescan()
        case "q": NSApplication.shared.terminate(nil)
        default: return .ignored
        }
        return .handled
    }

    private func letter(_ press: KeyPress) -> KeyPress.Result {
        let shift = press.modifiers.contains(.shift)
        switch press.characters.lowercased() {
        // The vi pair, which the script bound for the same reason it bound the
        // arrows: whichever hand is already there.
        case "h": perform(.seekBack, shift: shift)
        case "l": perform(.seekForward, shift: shift)
        case "k": perform(.selectUp)
        case "j": perform(.selectDown)
        case "n": perform(.next)
        case "p": perform(.previous)
        case "s": perform(.shuffle)
        case "r": perform(.repeatMode)
        // Bound only while there is an offer to take (`player:2720`). A key that
        // does nothing most of the time is worse than no key at all, so it is
        // the offer on screen that makes it live.
        case "u": if model.offer != nil { model.takeOffer() } else { return .ignored }
        case "q": perform(.quit)
        // New (D1). The hardware volume keys stay the system's — macOS handles
        // them above the app and they never arrive here.
        case "-", "_": model.nudgeVolume(by: -0.05)
        case "=", "+": model.nudgeVolume(by: 0.05)
        case "m": model.toggleMute()
        default: return .ignored
        }
        return .handled
    }

    // MARK: - The wheel (§6.4)

    /// The wheel walks the track list (`player:3188`).
    ///
    /// A local event monitor rather than a view that catches scrolls, because a
    /// view that catches scrolls has to sit over the panel and would then be in
    /// the way of every click on it. There is one panel and one window; a scroll
    /// anywhere in it means the list.
    private func startWheel() {
        guard wheel == nil else { return }
        var carried: CGFloat = 0
        wheel = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            carried += event.scrollingDeltaY
            let step = Theme.cell.height
            while abs(carried) >= step {
                let up = carried > 0
                MainActor.assumeIsolated { model.wheel(up ? -1 : 1) }
                carried += up ? -step : step
            }
            return event
        }
    }

    private func stopWheel() {
        if let wheel { NSEvent.removeMonitor(wheel) }
        wheel = nil
    }
}

/// What the panel says before there is a record in it. Deliberately not a
/// mock-up of the list: an empty instrument that looks full is the one thing a
/// panel this literal must not do.
struct EmptyPanelView: View {
    let stage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.columns(PanelGrid.gutter))
                run(stage ?? "NO RECORD ON THE DECK — ⌘O", Theme.etch)
                    .font(Theme.swiftUIFont)
                Spacer(minLength: 0)
            }
            .gridLine()
            Spacer(minLength: 0)
        }
    }
}
