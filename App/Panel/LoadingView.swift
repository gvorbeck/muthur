import MUTHURKit
import SwiftUI

/// §10's loading stage: the seconds a zip takes to come out of its archive, on
/// the same panel as everything else (`player:1152`).
///
/// Two labelled lines in the header's own column and one bar under them. The
/// bar is `trackbar` — a single band and one head — and it advances one file at
/// a time, which is the argument for the whole screen: an album that takes eight
/// seconds to open is not a spinner, it is forty-one files, and the thing that
/// knows how many have landed should say so.
///
/// **The bar is not seekable and there is nothing to seek in.** `StripView`
/// wants a `seek`, so it is handed one that does nothing rather than being given
/// a second drawing path — a needle put down in a zip that is still coming out
/// of its archive has nowhere to land.
struct LoadingView: View {
    let stage: LoadingStage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // `SOURCE`, and **not cut** — `player:1169` prints `$SRC_LABEL`
            // whole where `np_frame` fits the same field to 52
            // (`player:2330`). Kept: a name too long for the panel overruns
            // here and nowhere else, and it has always done so.
            row(label: "SOURCE", value: stage.source)
            PanelBlank()
            // Always `READING`, whatever the stage says at the top
            // (`player:1170`). It reads as the machine reading the file it is
            // opening, which is nearly true and is what has always been on
            // screen.
            row(label: LoadingStage.detailLabel, value: stage.line)
            PanelBlank()
            StripView(cells: stage.cells(), seek: { _, _ in })
            Spacer(minLength: 0)
        }
    }

    /// `printf '    %b%-8s%b %s\n'` — the header block's own column, because it
    /// is the same column and a loading screen that indented differently would
    /// read as a different instrument for the two seconds it is up.
    private func row(label: String, value: String) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.columns(PanelGrid.gutter))
            MatrixText(text: label, colour: Theme.etch, columns: HeaderBlock.labelWidth)
            Spacer().frame(width: Grid.columns(1))
            run(value, Theme.text).font(Theme.swiftUIFont)
            Spacer(minLength: 0)
        }
        .gridLine()
    }
}
