import MUTHURKit
import SwiftUI

/// The health check, drawn on the panel (§11).
///
/// `run_check` prints to the terminal and the program exits (`player:345`,
/// `player:531`); there is no panel up when it runs, and it uses colour the
/// panel does not have — `✓` green, `!` yellow, `✗` red (`panel.sh:588`–
/// `panel.sh:591`). A phosphor screen has one colour and says the rest with
/// current: "a brighter character is the same phosphor harder, which is the
/// rule the whole ramp is built on" (§10). So the three marks come off the
/// panel's own amber, climbing — a `✓` sits back in the chassis, a `!` is lit,
/// a `✗` is lit hard. The ramp runs the same way the trouble does, which is
/// what the hues were doing in the terminal.
///
/// **This is the only screen that speaks in MU/TH/UR's voice (D8).** The voice
/// is the verdict line and nothing else on this view: every row above it is a
/// label and a fix, in the same flat register the rest of the panel uses.
struct CheckView: View {
    let report: Diagnostics.Report

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.margin)
                MatrixText(text: "MU/TH/UR HEALTH CHECK", colour: Theme.lit)
                Spacer(minLength: 0)
            }
            .gridLine()

            PanelBlank()

            ForEach(report.checks) { check in
                CheckRowView(check: check)
            }

            PanelBlank()

            // `check_summary` (`panel.sh:598`): the one line that is allowed to
            // talk. Three of them, because eleven of the twelve checks can only
            // ever warn — scratch space is the one that can fail — and
            // `Mostly ready.` is where most machines land.
            ForEach(
                Columns.wrap(report.verdict, to: PanelGrid.width - PanelGrid.margin),
                id: \.self
            ) { line in
                HStack(spacing: 0) {
                    Spacer().frame(width: Grid.margin)
                    run(line, Theme.lit).font(Theme.swiftUIFont)
                    Spacer(minLength: 0)
                }
                .gridLine()
            }
        }
    }
}

/// One `ck` line: mark, label, detail (`panel.sh:587`).
///
/// The detail turns over rather than being cut, indented to the detail column
/// so the label stays a column and not a paragraph. §11's last requirement is
/// that every check carries a fix, and a fix with its tail cut off is the state
/// the person running this was already in.
private struct CheckRowView: View {
    let check: Check

    var body: some View {
        let lines = check.detailLines
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(spacing: 0) {
                    Spacer().frame(width: Grid.margin)
                    run(index == 0 ? check.mark.glyph : " ", ink(check.mark))
                        .font(Theme.swiftUIFont)
                    Spacer().frame(width: Grid.columns(1))
                    MatrixText(
                        text: index == 0 ? check.label : "",
                        colour: Theme.etch, columns: Check.labelWidth)
                    Spacer().frame(width: Grid.columns(1))
                    run(line, check.mark == .ok ? Theme.dim : Theme.text)
                        .font(Theme.swiftUIFont)
                    Spacer(minLength: 0)
                }
                .gridLine()
            }
        }
    }

    /// The three marks up the panel's own ramp instead of across the terminal's
    /// three hues. A check that passed is furniture; a check that did not is
    /// the half of the panel telling you something now.
    private func ink(_ mark: Check.Mark) -> Color {
        switch mark {
        case .ok: Theme.amber(.deep)
        case .warn: Theme.amber(.amber)
        case .fail: Theme.amber(.lit)
        }
    }
}
