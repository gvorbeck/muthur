import MUTHURKit
import SwiftUI

/// §13, drawn on the panel (**D105**).
///
/// The script has no such screen and could not have one: `player` reads its
/// settings out of the environment at line 62 and never looks again, because a
/// program you start from a shell already *has* a settings screen — it is the
/// shell. A window has not got one, and every variable §13 lists had therefore
/// become a setting that could only be changed by somebody who already knew it
/// existed.
///
/// **Built like `CheckView` and not like the Import menu**, which is the whole
/// of the answer to *why not a `Settings { }` window*. A native pane would be
/// the first surface in this program that is not the tube: system fonts, system
/// controls, a second window with a second idea of what the app looks like. The
/// panel already knows how to draw a list with a cursor on it, and a screen that
/// goes over the deck and comes off again is what every other screen here does.
///
/// **It scrolls, and it is the first screen on the panel that had to.** Twenty
/// or so settings will not stand in the rows a window this size has, and the
/// list is walked with `↑↓` the way the picker's is — the window follows the
/// cursor and `▾ n MORE` says what is under the fold.
struct SettingsView: View {
    let rows: [SettingRow]
    let cursor: Int
    let visibleRange: Range<Int>
    let below: Int
    let click: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.margin)
                MatrixText(text: "SETTINGS", colour: Theme.lit)
                Spacer(minLength: 0)
            }
            .gridLine()

            PanelBlank()

            ForEach(Array(visibleRange), id: \.self) { index in
                SettingRowView(row: rows[index], cursor: index == cursor)
                    .contentShape(Rectangle())
                    .onTapGesture { click(index) }
            }

            if below > 0 {
                HStack(spacing: 0) {
                    Spacer().frame(width: Grid.columns(PanelGrid.gutter))
                    run(Readout.more(below), Theme.etch).font(Theme.swiftUIFont)
                    Spacer(minLength: 0)
                }
                .gridLine()
            }

            Spacer(minLength: 0)
        }
    }
}

/// One line: a heading, a blank, a note, or a setting with its value.
private struct SettingRowView: View {
    let row: SettingRow
    let cursor: Bool

    var body: some View {
        switch row.kind {
        case .blank:
            PanelBlank()
        case .heading:
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.margin)
                MatrixText(text: row.label, colour: Theme.lit)
                Spacer(minLength: 0)
            }
            .gridLine()
        case .note:
            HStack(spacing: 0) {
                Spacer().frame(width: Grid.columns(PanelGrid.gutter))
                run(
                    Columns.truncate(row.label, to: PanelGrid.width - PanelGrid.gutter),
                    Theme.etch
                )
                .font(Theme.swiftUIFont)
                Spacer(minLength: 0)
            }
            .gridLine()
        default:
            setting
        }
    }

    /// The label column against the value column, `PickerRowView`'s plate under
    /// the cursor. Two flush edges rather than two ragged ones, which is the
    /// argument `Columns.fit` makes about trailing alignment — except that here
    /// both columns lead, because a value that moved sideways as it changed
    /// length would be a value you have to find again after every press.
    private var setting: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: Grid.margin)
            run(cursor ? Readout.cursorGlyph : " ", Theme.lit)
                .font(Theme.swiftUIFont)
                .frame(width: Grid.columns(1), alignment: .leading)
            Spacer().frame(width: Grid.columns(1))
            HStack(spacing: 0) {
                run(row.label, Theme.text, columns: SettingsScreen.labelColumns)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(SettingsScreen.labelColumns), alignment: .leading)
                Spacer().frame(width: Grid.columns(2))
                run(value, ink, columns: SettingsScreen.valueColumns)
                    .font(Theme.swiftUIFont)
                    .frame(width: Grid.columns(SettingsScreen.valueColumns), alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(width: Grid.columns(PanelGrid.width - PanelGrid.gutter), alignment: .leading)
            .background(cursor ? Theme.cursorPlate : Color.clear)
            Spacer(minLength: 0)
        }
        .gridLine()
    }

    /// **The rocker's arrows are drawn on the cursor row and nowhere else.**
    /// A table with `◂ ▸` down every line of it is a table of arrows with some
    /// settings between them; on the one row a press would act on, they are the
    /// affordance the legend is promising.
    private var value: String {
        switch row.kind {
        case .toggle(let on): on ? "ON" : "OFF"
        case .choice(let text): cursor ? "◂ \(text) ▸" : text
        case .chooser(let text): text
        default: ""
        }
    }

    /// A switch that is off says so with current, which is §11's rule on this
    /// screen: `OFF` sits back in the chassis and `ON` stands where the data
    /// does. Nothing here is red, because nothing here is wrong.
    private var ink: Color {
        switch row.kind {
        case .toggle(let on): on ? Theme.text : Theme.etch
        default: cursor ? Theme.text : Theme.dim
        }
    }
}
