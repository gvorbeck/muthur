import MUTHURKit
import SwiftUI

/// §20 stage 3 — the screen a burn happens on (`stage`, `burncd:1386`).
///
/// One instrument in five states and not five screens, which is `BurnStage`'s
/// own argument: the faceplate, the album and the log are the same throughout
/// and only the body changes. The fifth is the write screen, which is
/// `BurnPanel` rather than a `BurnStage` because it is the one state the drive
/// is talking during — so it is switched on separately, and everything around
/// it stays put.
struct BurnView: View {
    let burn: BurnRun
    /// How many rows the body may spend. The log takes its share off the top of
    /// this, as `stage_insert` does (`burncd:1501`).
    let rows: Int
    let press: (Readout.Press) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let panel = burn.panel {
                writing(panel)
            } else {
                stageBody
            }
            Spacer(minLength: 0)
            log
            foot
        }
    }

    // MARK: - The body, per stage

    @ViewBuilder
    private var stageBody: some View {
        switch burn.stage {
        case .insert(let disc, _, _):
            insert(disc: disc)
        case .converting(_, _, let track, let ofTracks, let title, let head):
            converting(track: track, of: ofTracks, title: title, head: head)
        case .written:
            // No body in the script either (`burncd:2680`): the stage exists so
            // the burn screen's last frame is not left at 100% while the next
            // disc is being asked for, and a stage that says one thing says it
            // on the faceplate.
            EmptyView()
        case .done(_, let discs):
            done(discs: discs)
        }
    }

    /// `stage_insert` (`burncd:1495`) — the last look at what is about to be
    /// permanent, which is why it is the listing and not a summary of one.
    private func insert(disc: Int) -> some View {
        let entries = burn.plan.entries(onDisc: disc)
        let room = max(1, rows - 8 - logRows)
        let shown = entries.count > room ? room - 1 : entries.count
        return VStack(alignment: .leading, spacing: 0) {
            field("ARTIST", burn.albumArtist)
            field("YEAR", burn.year)
            PanelBlank()
            ForEach(Array(entries.prefix(max(1, shown)).enumerated()), id: \.offset) {
                index, entry in
                BurnRowView(number: index + 1, entry: entry)
            }
            if shown < entries.count {
                HStack(spacing: 0) {
                    Spacer().frame(width: Grid.columns(PanelGrid.gutter))
                    run(Readout.more(entries.count - max(1, shown)), Theme.etch)
                        .font(Theme.swiftUIFont)
                    Spacer(minLength: 0)
                }
                .gridLine()
            }
            PanelBlank()
            strip(disc: disc)
        }
    }

    /// `stage_convert` (`burncd:1543`). The bar is the burn's bar — same bands,
    /// same head — because from the outside these are one process with two
    /// halves.
    private func converting(track: Int, of ofTracks: Int, title: String, head: Int)
        -> some View
    {
        let durations = burn.plan.entries(onDisc: burn.disc).map(\.duration)
        return VStack(alignment: .leading, spacing: 0) {
            PanelBlank()
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.margin)
                MatrixText(text: "TRACK", colour: Theme.etch, columns: 8)
                Spacer().frame(width: Grid.columns(1))
                run(
                    "\(String(format: "%02d", track)) OF \(String(format: "%02d", ofTracks))",
                    Theme.text
                )
                .font(Theme.swiftUIFont)
                Spacer().frame(width: Grid.columns(2))
                run(Columns.fit(title, to: BurnStage.titleWidth), Theme.text)
                    .font(Theme.swiftUIFont)
                Spacer(minLength: 0)
            }
            .gridLine()
            PanelBlank()
            StripView(
                cells: BurnStage.cells(
                    head: head, bands: BurnStage.bands(durations: durations)),
                seek: { _, _ in })
        }
    }

    /// `stage_done` (`burncd:1560`) — every disc gets its meter.
    private func done(discs: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelBlank()
            ForEach(discs, id: \.self) { disc in
                strip(disc: disc)
                PanelBlank()
            }
        }
    }

    // MARK: - The write screen

    /// `burn_frame` (`burncd:1706`). The layout is identical in all three
    /// phases, with `--` standing in for the fields the drive has not filled in,
    /// so nothing on screen moves when a phase changes hands.
    private func writing(_ panel: BurnPanel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelBlank()
            line("TRACK", panel.trackLine)
            line("WRITTEN", panel.writtenLine)
            PanelBlank()
            StripView(cells: panel.cells(), seek: { _, _ in })
            LampView(cells: panel.lamp())
            PanelBlank()
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.margin)
                MatrixText(text: "BUFFER", colour: Theme.etch, columns: 8)
                Spacer().frame(width: Grid.columns(1))
                run(panel.bufferField, Theme.text).font(Theme.swiftUIFont)
                Spacer().frame(width: Grid.columns(3))
                MatrixText(text: "ELAPSED", colour: Theme.etch, columns: 8)
                Spacer().frame(width: Grid.columns(1))
                run(panel.elapsedField, Theme.text).font(Theme.swiftUIFont)
                Spacer().frame(width: Grid.columns(3))
                MatrixText(text: "REMAINING", colour: Theme.etch, columns: 10)
                Spacer().frame(width: Grid.columns(1))
                run(panel.remainingField, Theme.text).font(Theme.swiftUIFont)
                Spacer(minLength: 0)
            }
            .gridLine()
        }
    }

    // MARK: - The furniture

    private func field(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.columns(PanelGrid.gutter))
            MatrixText(text: label, colour: Theme.etch, columns: 8)
            Spacer().frame(width: Grid.columns(1))
            run(value.isEmpty ? "—" : value, Theme.text).font(Theme.swiftUIFont)
            Spacer(minLength: 0)
        }
        .gridLine()
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            MatrixText(text: label, colour: Theme.etch, columns: 8)
            Spacer().frame(width: Grid.columns(1))
            run(value, Theme.text).font(Theme.swiftUIFont)
            Spacer(minLength: 0)
        }
        .gridLine()
    }

    private func strip(disc: Int) -> some View {
        let plan = burn.plan
        let durations = plan.entries(onDisc: disc).map(\.duration)
        let units = PanelGrid.stripWidth * Meter.unitsPerCell
        let filled = min(units, plan.runtime(onDisc: disc) * units / plan.capacity)
        return MeterView(
            label: PlanScreen.discLabel(disc),
            position: plan.runtime(onDisc: disc),
            length: plan.capacity,
            cells: Meter.cells(
                head: units, bands: Meter.bands(units: filled, durations: durations),
                width: PanelGrid.stripWidth),
            seek: { _, _ in })
    }

    /// The last four lines of what has happened (`burncd:1501`) — a disc prompt
    /// with the last disc's result hidden is the one place the log has something
    /// to say.
    private var logRows: Int { min(4, burn.log.count) }

    private var log: some View {
        let lines = burn.log.suffix(4)
        return Group {
            if !lines.isEmpty {
                PanelBlank()
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 0) {
                        Spacer().frame(width: Grid.columns(PanelGrid.gutter))
                        run(
                            Columns.fit(line, to: PanelGrid.width - PanelGrid.gutter),
                            Theme.etch
                        )
                        .font(Theme.swiftUIFont)
                        Spacer(minLength: 0)
                    }
                    .gridLine()
                }
            }
        }
    }

    @ViewBuilder
    private var foot: some View {
        if case .insert(let disc, let of, _) = burn.stage, !burn.finished {
            PanelBlank()
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.columns(PanelGrid.gutter))
                run(BurnStage.insertPrompt(disc: disc, of: of), Theme.lit)
                    .font(Theme.swiftUIFont)
                Spacer(minLength: 0)
            }
            .gridLine()
        }
        let keys = burn.finished ? [[Readout.Cap("Q", "DONE", .quit)]] : burn.stage.keys
        if !keys.isEmpty {
            PanelBlank()
            KeycapsView(legend: keys, press: press)
        }
    }
}

/// The lamp under the bar (`lamp_row`, `burncd:1625`) — the one thing on the
/// burn screen that moves while the drive is silent.
///
/// It exists for the two phases cdrecord says nothing during. A bar that has not
/// changed in forty seconds is indistinguishable from a hang; a lamp sweeping
/// under it is the instrument saying it is still there. The trail is five cells
/// and falls off behind the head, which `Lamp.cells` has already worked out —
/// this only decides how bright each answer is drawn.
private struct LampView: View {
    let cells: [Lamp.Cell]

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            Spacer().frame(width: Grid.columns(1))
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                Rectangle()
                    .fill(colour(cell))
                    .frame(width: Theme.cell.width, height: Theme.cell.height)
            }
            Spacer(minLength: 0)
        }
        .gridLine()
    }

    private func colour(_ cell: Lamp.Cell) -> Color {
        switch cell {
        case .head: Theme.lit
        // Five steps down from the head to the field, which is the trail's
        // length doing the arithmetic rather than a table of five colours.
        case .trail(let behind):
            Theme.text.opacity(
                max(0, Double(Lamp.trailLength - behind)) / Double(Lamp.trailLength))
        case .dark: Color.clear
        }
    }
}

/// One track on the insert stage's listing — the editor's row, with no cursor on
/// it. Nothing here is selectable: this is the listing being checked, not
/// edited (`burncd:1517`).
private struct BurnRowView: View {
    let number: Int
    let entry: BurnPlan.Entry

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            Spacer().frame(width: Grid.columns(2))
            run(String(format: "%02d", number), Theme.etch)
                .font(Theme.swiftUIFont)
                .frame(width: Grid.columns(PlanScreen.Cells.number), alignment: .leading)
            Spacer().frame(width: Grid.columns(PlanScreen.Cells.gap))
            run(entry.title, Theme.text, columns: PlanScreen.Cells.title)
                .font(Theme.swiftUIFont)
                .frame(width: Grid.columns(PlanScreen.Cells.title), alignment: .leading)
            Spacer().frame(width: Grid.columns(PlanScreen.Cells.gap))
            run(entry.artist, Theme.dim, columns: PlanScreen.Cells.artist)
                .font(Theme.swiftUIFont)
                .frame(width: Grid.columns(PlanScreen.Cells.artist), alignment: .leading)
            Spacer().frame(width: Grid.columns(PlanScreen.Cells.gap))
            run(
                Readout.mmss(entry.duration), Theme.etch,
                columns: PlanScreen.Cells.time, align: .trailing
            )
            .font(Theme.swiftUIFont)
            Spacer(minLength: 0)
        }
        .gridLine()
    }
}
