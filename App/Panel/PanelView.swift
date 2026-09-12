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

    @Environment(\.accessibilityReduceMotion) private var still
    /// Whether this window is actually on somebody's screen. See `faulting`.
    @State private var onscreen = NSApplication.shared.occlusionState.contains(.visible)

    /// The pointer on the cover, and how far the truth has come up (D56). Three
    /// pieces of state for one gesture, and the third is the one that is not
    /// obvious: `reveal` is the animated number, `over` is where the pointer
    /// actually is, and `revealing` says the veils still need a hole in them —
    /// which stays true for the whole of the fade *out*, because dropping the
    /// mask the instant the pointer leaves would put every veil back in one frame,
    /// which is the snap this is meant not to have.
    @State private var over = false
    @State private var reveal = 0.0
    @State private var revealing = false

    /// Where the deflection fault is right now, shared between the band
    /// (`ScreenEffects`) and the bulge it drags through the panel (D61). One
    /// instance for the window, owned here rather than by either view, since
    /// both need to read the same fall in the same frame.
    @State private var tubeFault = TubeFault()

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
            // The prompt *borrows* the focus; it does not get to keep it.
            //
            // `PlanPromptView` takes the focus on appearing, because a field you
            // have to click into first is not a prompt. But when it goes away
            // SwiftUI does not hand the focus back — the first responder becomes
            // the window itself, and a panel that is not the first responder
            // never sees `onKeyPress` at all. Every key then falls through to
            // AppKit, which has nothing to do with it and beeps. The program is
            // not wedged, it is deaf, which from the outside is worse: it looks
            // wedged the moment you finish typing a year, and the next key you
            // try is the `B` that was the whole point.
            //
            // ⏎ and ⎋ both end up here, since both are the prompt going nil.
            .onChange(of: model.planPrompt == nil) { _, noPrompt in
                if noPrompt { focused = true }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSApplication.didChangeOcclusionStateNotification)
            ) { _ in
                onscreen = NSApplication.shared.occlusionState.contains(.visible)
            }
    }

    // MARK: - Whether the tube is allowed to misbehave (D52)

    /// Four gates, and every one of them can close on its own.
    ///
    /// `Theme.faults` is `MUTHUR_CRT`; `still` is Reduce Motion, which
    /// `docs/spec.md:127` requires to be honoured and which is a person saying the
    /// same thing as the variable with more authority. The other two are about
    /// work rather than taste: a stopped record has nothing to be a symptom of,
    /// and a window behind another window is the case `player:2643` already
    /// worries about — effort spent on a picture nobody can see is not saved, it
    /// is queued, and it comes back as catch-up lag. Both faults are driven by
    /// `.task(id:)`, so a closed gate does not slow them down, it cancels them.
    private var faulting: Bool {
        Theme.faults && !still && onscreen && model.state.mode == .playing
    }

    /// The pointer arriving on the cover and leaving it.
    ///
    /// The completion is what keeps the mask alive until the fade has finished,
    /// and it asks `over` rather than trusting its own argument — a pointer that
    /// left and came back inside a quarter of a second would otherwise have the
    /// first exit's completion turn the hole off underneath the second entry.
    private func hover(_ inside: Bool) {
        over = inside
        if inside { revealing = true }
        withAnimation(.easeInOut(duration: Theme.reveal)) {
            reveal = inside ? 1 : 0
        } completion: {
            if !over { revealing = false }
        }
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
                            // The burn is the rectangles the *now-playing*
                            // furniture has never moved out of. Any other screen
                            // would be showing a ghost of chrome that is not
                            // above it.
                            if deck {
                                BurnIn(marks: burn(rows: rows))
                            }
                        }
                }
                // The bulge, not the sleeve (D61): the cover is `SleeveView`,
                // a sibling of this `Bloom`, not a child of it, so scoping the
                // shader here is what keeps the sleeve at its true form (D56)
                // without threading its reveal hole through a second effect.
                .tubeBulge(fault: tubeFault, size: geometry.size, active: faulting)

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
                        edge: model.sleeveEdge, side: side,
                        reveal: reveal, hover: hover
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
        // The veils, and the one rectangle they are told to leave alone. The
        // anchor comes up from the cover itself and is resolved here, in the
        // overlay's own space, which is why this is `overlayPreferenceValue` and
        // not `overlay`: the sleeve's square is arithmetic that only exists inside
        // the reader above, and the glass is drawn outside it.
        .overlayPreferenceValue(SleeveBounds.self) { anchor in
            GeometryReader { proxy in
                ScreenEffects(
                    sweeping: faulting,
                    hole: revealing
                        ? anchor.map { Hole(rect: proxy[$0], open: reveal) } : nil,
                    fault: tubeFault)
            }
        }
    }

    private func panel(rows: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
                FaceplateView(meta: model.faceplateMeta, glitching: faulting)
                PanelBlank()

                // No fixed height, unlike the picker: how tall this screen is
                // depends on how much the machine had to say, and a check that
                // is clipped at the bottom loses its verdict.
                if let report = model.report {
                    CheckView(report: report)
                } else if let burning = model.burning {
                    BurnView(
                        burn: burning, rows: rows,
                        press: { performBurn($0) }
                    )
                    .frame(height: Grid.rows(rows + 4))
                } else if let editor = model.plan {
                    PlanView(
                        editor: editor,
                        visibleRange: model.planVisible,
                        below: model.planBelow,
                        prompt: model.planPrompt,
                        correction: model.correctionNote,
                        click: { model.planClick(row: $0) },
                        typed: { model.planPrompt?.value = $0 },
                        commit: { model.planCommit() },
                        cancel: { model.planCancel() }
                    )
                } else if model.isPicking, let entries = model.pickerEntries {
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
                } else if let loading = model.loading {
                    LoadingView(stage: loading)
                        .frame(height: Grid.rows(rows + 4))
                } else {
                    EmptyPanelView(stage: model.stage)
                        .frame(height: Grid.rows(rows + 4))
                }

                if deck {
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

                // No legend while a source is coming open. `load_stage` prints
                // no keys (`player:1162`) and there are none to print: the
                // panel is not answering anything until it has a record, and a
                // row of caps that light up and do nothing is the same lie the
                // dead ⌘O was.
                // Nor while a burn is up: its prompt and its caps are one foot
                // and `BurnView` draws them together, because `stage` takes them
                // as one string for the same reason (`burncd:1546`) — the prompt
                // is what the keys are answering, and a legend that drifted a row
                // away from it would be answering nothing.
                if !model.isLoading && !model.isBurning {
                    PanelBlank()
                    KeycapsView(
                        legend: legend,
                        press: tapped
                    )
                }

                if let status = model.statusLine {
                    PanelBlank()
                    StatusView(text: status)
                }

                Spacer(minLength: 0)
            }
            .frame(width: Theme.panelWidth, alignment: .leading)
    }

    /// The row of caps belongs to whatever screen is up. A legend naming keys
    /// the current screen does not answer is the same lie the dead ⌘O was.
    private var legend: [[Readout.Cap]] {
        if model.isChecking { return Readout.checkLegend }
        if model.isPlanning { return Readout.planLegend }
        if model.isPicking { return Readout.pickerLegend(hasDisc: model.pickerHasDisc) }
        return Readout.legend
    }

    /// Whether the deck's own furniture is up — the two meters, the analyser,
    /// and the burn under them. Every other screen has neither the room nor the
    /// use for them, and a ghost of chrome that is not above it is worse than
    /// no ghost at all.
    private var deck: Bool {
        !model.isPicking && !model.isChecking && !model.isLoading && !model.isPlanning
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
            GridRect(column: margin, row: keycaps, columns: 34, rows: 3),
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
        if model.isPlanning { return planRows(lines: lines) }
        var chrome = 17 + (model.header?.rows.count ?? 3)
        if model.statusLine != nil { chrome += 2 }
        if trackCount > lines - chrome { chrome += 1 }
        return max(1, lines - chrome)
    }

    /// `tui_fit_rows` (`burncd:1041`), counted the same way and for the same
    /// reason: everything except the track list is fixed, so the list gets what
    /// is left rather than a guess.
    ///
    /// The faceplate and its blank, three header fields, a blank, the blank
    /// before the meter and the meter's two rows, a blank and two keycap rows —
    /// eleven. A status message adds a blank and itself, a prompt the same, and
    /// D67's notes add themselves and a blank. The disc rules are the one thing
    /// not counted here: they depend on where the window starts, which is
    /// `planWalk`'s business and is settled after this.
    private func planRows(lines: Int) -> Int {
        guard let editor = model.plan else { return 1 }
        var chrome = 11
        if model.statusLine != nil { chrome += 2 }
        if model.planPrompt != nil { chrome += 2 }
        let notes = PlanScreen.notes(editor.plan).count
        if notes > 0 { chrome += notes + 1 }
        if editor.draft.order.count > lines - chrome { chrome += 1 }
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
        if model.isChecking {
            performCheck(press)
            return
        }
        if model.isPlanning {
            performPlan(press, shift: shift)
            return
        }
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
        // New (D58): the keys already existed (D1); only the cap is new. Same
        // switch either way, which is the whole of what D30 asks for.
        case .volumeDown: model.nudgeVolume(by: -0.05)
        case .volumeUp: model.nudgeVolume(by: 0.05)
        case .mute: model.toggleMute()
        case .rescan: break
        // Not bound on the playing panel, and not because it could not be: `b`
        // there would be a second way to change record while one is spinning,
        // and the transport legend (§14) has no room to say so. The cap lives on
        // the picker, where choosing a record is what you are already doing.
        case .browse: break
        // §20 — the plan for the record already on the deck. `b` on the picker
        // is BROWSE and `b` here is BURN, which is the two screens naming their
        // own key and not a collision: neither is ever drawn beside the other.
        case .burn: model.openPlan()
        // Everything the plan screen answers, and nothing the deck does. They
        // are in `Press` because one enum names every key the program has, not
        // because every screen has to have an opinion about all of them.
        case .moveUp, .moveDown, .rename, .artist, .drop, .split, .undo, .reset:
            break
        // The way back to the start screen, and it is bound here rather than
        // only under `FINISHED` on purpose (D57): a record you have decided
        // against ten seconds in is exactly when you want the next one.
        case .eject: model.eject()
        case .close: break
        case .quit: NSApplication.shared.terminate(nil)
        }
    }

    /// Everything on the check screen either leaves it or runs it again. A cap
    /// that is not one of those two is not silently ignored — the screen comes
    /// off, which is what the person pressing `␣` under a diagnosis wants.
    private func performCheck(_ press: Readout.Press) {
        switch press {
        case .rescan: model.check()
        case .quit: NSApplication.shared.terminate(nil)
        default: model.closeCheck()
        }
    }

    /// `tui_edit`'s key table (`burncd:1157`).
    ///
    /// `⇧↑↓` is the same two caps as `↑↓` with the modifier carried, which is
    /// why the shift arrives here rather than being read again: the cap is the
    /// key, including the parts of it that are not printed on it.
    private func performPlan(_ press: Readout.Press, shift: Bool) {
        switch press {
        case .selectUp: shift ? model.planMove(by: -1) : model.planStep(by: -1)
        case .selectDown: shift ? model.planMove(by: 1) : model.planStep(by: 1)
        case .moveUp: model.planMove(by: -1)
        case .moveDown: model.planMove(by: 1)
        case .rename, .jump: model.planRename()
        case .artist: model.planArtist()
        case .drop: model.planDrop()
        case .split: model.planToggleBreak()
        case .undo: model.planUndo()
        case .reset: model.planReset()
        case .burn: model.burn()
        // D68 — the eleventh cap, and the only way back to the deck. `q` is
        // still the program, here as everywhere (`burncd:1203` makes it the
        // program too, by way of `die`).
        case .close: model.closePlan()
        case .quit: NSApplication.shared.terminate(nil)
        default: break
        }
    }

    private func performPicker(_ press: Readout.Press) {
        switch press {
        case .selectUp: model.pickerStep(by: -1)
        case .selectDown: model.pickerStep(by: 1)
        case .jump: model.openPicked()
        case .rescan: model.rescan()
        case .browse: model.browse()
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
        if model.isChecking { return handleCheck(press) }
        if model.isBurning { return handleBurn(press) }
        if model.isPlanning { return handlePlan(press) }
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

    private func handleCheck(_ press: KeyPress) -> KeyPress.Result {
        switch press.characters.lowercased() {
        case "r": model.check()
        case "q": NSApplication.shared.terminate(nil)
        default: model.closeCheck()
        }
        return .handled
    }

    /// `stage_insert`'s key loop (`burncd:2425`), and the summary's one key.
    ///
    /// **Almost everything is ignored on purpose.** A burn has exactly two
    /// moments that take an answer — the prompt before each disc, and the
    /// summary at the end — and the conversion and the write are not among them:
    /// there is no safe way to stop a `cdrecord` halfway and the script does not
    /// offer one either. A key pressed at those moments does nothing, which is
    /// what `BurnStage.keys` says by handing back no caps at all.
    private func handleBurn(_ press: KeyPress) -> KeyPress.Result {
        guard let burning = model.burning else { return .ignored }
        if burning.finished {
            // The summary is dismissed by anything, the way the check screen is:
            // a person reading `2 DISCS · 78:12` is done, and making them find
            // the one right key is the machine being precious.
            model.closeBurn()
            return .handled
        }
        guard burning.isWaitingForDisc else { return .handled }
        switch press.key {
        case .return: performBurn(.burn)
        case .escape: performBurn(.close)
        default:
            switch press.characters.lowercased() {
            case "e": performBurn(.close)
            case "q": performBurn(.quit)
            default: return .handled
            }
        }
        return .handled
    }

    /// The burn screen's caps, which are the same three the legend prints.
    private func performBurn(_ press: Readout.Press) {
        guard let burning = model.burning else { return }
        switch press {
        case .burn: burning.go()
        // `E EDIT` is the plan screen's `ESC BACK` — the same movement backwards
        // out of a screen, arriving at the editor it came from. The job is told
        // no first, so the thread unwinds rather than being left on a semaphore.
        case .close:
            burning.cancel()
            model.closeBurn()
        // `Q CANCEL` stops the job and stays where it is, so the reason it gives
        // can be read. `Q` on the summary is the program, as everywhere else.
        case .quit:
            if burning.finished {
                NSApplication.shared.terminate(nil)
            } else {
                burning.cancel()
            }
        default: break
        }
    }

    /// `tui_edit`'s `read_key` (`burncd:1181`).
    ///
    /// While a field is being typed into, every key belongs to the field — the
    /// script is in cooked mode for the whole of `tui_prompt` and the editor
    /// sees none of it (`burncd:895`). The text field has the focus, so nothing
    /// arrives here anyway; the guard is what makes that a rule rather than a
    /// coincidence of where the focus happened to be.
    private func handlePlan(_ press: KeyPress) -> KeyPress.Result {
        guard model.planPrompt == nil else { return .ignored }
        let shift = press.modifiers.contains(.shift)
        switch press.key {
        case .upArrow: perform(shift ? .moveUp : .selectUp)
        case .downArrow: perform(shift ? .moveDown : .selectDown)
        // The cursor by a screenful, which is the one thing the plan screen's
        // legend has no room to name and the script binds anyway
        // (`burncd:1186`).
        case .pageUp: model.planStep(by: -model.visibleRows)
        case .pageDown: model.planStep(by: model.visibleRows)
        case .return: perform(.rename)
        case .escape: perform(.close)
        // `b|B|␣` is one case in the script (`burncd:1201`) and stays one here.
        // It is not a burn: `tui_edit` breaks out to the disc prompt, and the
        // prompt is what asks. Until stage 3 there is no prompt and it declines.
        case .space: perform(.burn)
        default: return planLetter(press)
        }
        return .handled
    }

    private func planLetter(_ press: KeyPress) -> KeyPress.Result {
        let shift = press.modifiers.contains(.shift)
        switch press.characters.lowercased() {
        // The vi pair, shifted to move — `K` and `J` in the script, which is
        // the same shift the arrows take (`burncd:1184`).
        case "k": perform(shift ? .moveUp : .selectUp)
        case "j": perform(shift ? .moveDown : .selectDown)
        case "a": perform(.artist)
        case "s": perform(.split)
        // `d` as well as `x`, unbound on the legend and bound in the script
        // for whichever hand is already there (`burncd:1189`).
        case "x", "d": perform(.drop)
        case "u": perform(.undo)
        case "r": perform(.reset)
        case "b": perform(.burn)
        case "q": perform(.quit)
        default: return .ignored
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
        case "b": model.browse()
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
        case "e": perform(.eject)
        // §20 — the plan for what is on the deck. Nothing is scanned and
        // nothing is chosen: the record is already here.
        case "b": perform(.burn)
        // Bound only while there is an offer to take (`player:2720`). A key that
        // does nothing most of the time is worse than no key at all, so it is
        // the offer on screen that makes it live.
        case "u": if model.offer != nil { model.takeOffer() } else { return .ignored }
        case "q": perform(.quit)
        // New (D1). The hardware volume keys stay the system's — macOS handles
        // them above the app and they never arrive here. `-` `=` `m` do, and go
        // through `perform` like every other bound key now that they have a cap
        // beside them too (D58).
        case "-", "_": perform(.volumeDown)
        case "=", "+": perform(.volumeUp)
        case "m": perform(.mute)
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
///
/// **This state is a port invention — the script has no equivalent.** There,
/// `pick_source` either returns a record or ends the program: `die "nothing to
/// play…"` (`player:1114`) with nothing to scan, `screen_off; exit 0`
/// (`player:3532`) if the user walks away from the picker, and `open_source`
/// runs before a frame is ever drawn (`player:3535`). A terminal program is
/// allowed to say one line and stop. An app launched from the Dock is not, so
/// the empty panel exists here and nowhere else, and ⌘O — bound in
/// `MUTHURApp.chooseRecord` — is the way out of it that the script never had to
/// provide.
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
