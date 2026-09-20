import MUTHURKit
import SwiftUI

/// §21 — the screen an import happens on.
///
/// `BurnView`'s furniture, deliberately: the faceplate, the record, the log and
/// the foot are the same instrument, and somebody who has watched a disc being
/// written should recognise a disc being read without having to learn a second
/// screen. What changes is the body, which is what `ImportStage` carries.
///
/// **There is no write screen here.** The burn's fifth state is `BurnPanel`,
/// which exists because the drive talks while it writes and a bar that has not
/// moved in forty seconds is indistinguishable from a hang. ffmpeg talks too —
/// `-progress` is read all the way through — so the bar under the track moves
/// on its own, and there is nothing to lamp.
struct ImportView: View {
    /// Named `job` and not `run`, because `run(_:_:)` is the panel's own
    /// text helper (`Grid.swift`) and a property of that name shadows it on
    /// every line of this file.
    let job: ImportRun
    /// How many rows the body may spend. The log takes its share off the top,
    /// as the burn's insert stage does.
    let rows: Int
    let press: (Readout.Press) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stageBody
            Spacer(minLength: 0)
            log
            foot
        }
    }

    // MARK: - The body, per stage

    @ViewBuilder
    private var stageBody: some View {
        switch job.stage {
        case .preparing(let into):
            preparing(into: into)
        case .importing(let track, let ofTracks, let title, let head):
            importing(track: track, of: ofTracks, title: title, head: head)
        case .done(_, let written, let folder):
            done(written: written, folder: folder)
        }
    }

    /// Before a byte is decoded. It says the two things that were just decided
    /// and cannot be changed afterwards — where it is going and what it is
    /// being written as — because this is the last frame before the first file
    /// exists, and the burn's insert stage makes exactly that argument about
    /// the last frame before a lead-in.
    private func preparing(into: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelBlank()
            field("INTO", into)
            field("FORMAT", format)
            field("TRACKS", "\(job.plan.entries.count)")
            PanelBlank()
            line("", "PREPARING…")
        }
    }

    /// A track being written. The bar is the burn's bar, drawn against the same
    /// bands — from the outside these are the same operation pointed the other
    /// way, and watching the head cross the record is a truer picture of the
    /// wait than a spinner.
    private func importing(track: Int, of ofTracks: Int, title: String, head: Int)
        -> some View
    {
        VStack(alignment: .leading, spacing: 0) {
            PanelBlank()
            field("INTO", job.plan.folder.lastPathComponent)
            field("FORMAT", format)
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
                run(Columns.fit(title, to: ImportStage.titleWidth), Theme.text)
                    .font(Theme.swiftUIFont)
                Spacer(minLength: 0)
            }
            .gridLine()
            PanelBlank()
            StripView(
                cells: ImportStage.cells(
                    head: head, bands: ImportStage.bands(durations: job.plan.durations)),
                seek: { _, _ in })
        }
    }

    /// The summary. The meter is the record, whole and lit, because that is
    /// what a finished import is — and the folder is named on its own row
    /// because it is the one thing somebody needs out of a job that is over.
    private func done(written: Int, folder: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelBlank()
            if written > 0 {
                let units = PanelGrid.stripWidth * Meter.unitsPerCell
                MeterView(
                    label: "RECORD",
                    position: job.plan.runtime,
                    length: job.plan.runtime,
                    cells: Meter.cells(
                        head: units,
                        bands: ImportStage.bands(durations: job.plan.durations),
                        width: PanelGrid.stripWidth),
                    seek: { _, _ in })
                PanelBlank()
            }
            if !folder.isEmpty {
                field("INTO", folder)
            }
        }
    }

    // MARK: - The furniture

    private var format: String {
        let name = job.plan.format.name
        // Said on the one screen where it is still worth knowing, and said the
        // short way: `FLAC · LOSSLESS`. An archive's whole question.
        return job.plan.format.isLossless ? "\(name) · LOSSLESS" : name
    }

    private func field(_ label: String, _ value: String) -> some View {
        FieldRow(label: label, value: value.isEmpty ? "—" : value)
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            MatrixText(text: label, colour: Theme.etch, columns: 8)
            Spacer().frame(width: Grid.columns(1))
            run(value, Theme.etch).font(Theme.swiftUIFont)
            Spacer(minLength: 0)
        }
        .gridLine()
    }

    /// The last rows of what has happened.
    ///
    /// **Longer than the burn's four**, and that is the one place this screen
    /// argues with the one it is copied from. A burn's log is four lines
    /// because a burn has four things to say — a disc written, a disc verified
    /// — and the frame it sits in is mostly a track listing. An import says one
    /// line per track as it lands, so the log *is* the progress: the four most
    /// recent of thirteen would hide the whole record to leave space for a bar
    /// that is already saying the same thing.
    static let logLimit = 10

    private var log: some View {
        let room = max(1, min(ImportView.logLimit, rows - 9))
        let lines = job.log.suffix(room)
        return Group {
            if !lines.isEmpty {
                PanelBlank()
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 0) {
                        Spacer().frame(width: Grid.columns(PanelGrid.gutter))
                        run(
                            Columns.fit(line, to: PanelGrid.width - PanelGrid.gutter),
                            // A skipped track is the one line on this screen
                            // worth finding at a glance, so it is lit and the
                            // rest is etched. Not a colour — the panel has one
                            // (D38) — a brightness.
                            line.hasPrefix("✗") ? Theme.lit : Theme.etch
                        )
                        .font(Theme.swiftUIFont)
                        Spacer(minLength: 0)
                    }
                    .gridLine()
                }
            }
        }
    }

    private var foot: some View {
        let keys = job.stage.keys
        return Group {
            if !keys.isEmpty {
                PanelBlank()
                KeycapsView(legend: keys, press: press)
            }
        }
    }
}
