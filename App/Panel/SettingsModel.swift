import AppKit
import MUTHURKit
import SwiftUI

/// One line of the settings screen (**D105**).
///
/// **A row is a label, a value and a way to move it**, and the four kinds below
/// are the four ways a value can move rather than four ways of drawing one. A
/// switch flips, a choice cycles, a chooser opens a panel, and a heading or a
/// note does nothing at all — which is what `act == nil` means, and what keeps
/// the cursor off them without a second list saying which rows are skippable.
struct SettingRow: Identifiable {
    enum Kind {
        case heading
        case blank
        /// The small print under a section: what a setting will not do, or when
        /// it will start doing it. Not a row you can land on, because there is
        /// nothing there to change.
        case note
        case toggle(Bool)
        case choice(String)
        /// A file or a folder, shown as a path and changed through an open
        /// panel. Three of these and nineteen of the others, which is why `⏎`
        /// is its own cap on this screen.
        case chooser(String)
    }

    let id: Int
    let label: String
    let kind: Kind
    /// `-1` and `+1` from the rocker, `0` from `⏎`. Nil on a row that is not a
    /// setting, which is the same thing as *the cursor does not stop here*.
    let act: (@MainActor (Int) -> Void)?

    var selectable: Bool { act != nil }
}

/// §13's table, built fresh every time it is asked for.
///
/// **Nothing here is stored, and that is what keeps the screen honest.** The
/// settings live in three values — `Preferences`, `ImportOptions`,
/// `BurnOptions` — each with its own home and its own rules about what
/// persists, and this assembles a view of all three. A copy kept in a model
/// would be a fourth answer to *what is the format*, out of date the moment the
/// Import menu was used instead.
///
/// **The menu bar keeps every switch that is on this screen**, which is
/// deliberate: this is a second way to the same settings and not a replacement
/// for the first. A menu is where a Mac user looks and a `,` is where somebody
/// living in the panel looks, and both go through the same `PanelModel`
/// functions — D30's rule about the caps and the keys, one layer up.
@MainActor
enum SettingsScreen {

    /// The label column. The longest label on the screen is
    /// `Look Up on MusicBrainz` at twenty-two, and the two spare columns are
    /// there so the next setting does not force a relayout of the whole table.
    static let labelColumns = 24

    static var valueColumns: Int {
        PanelGrid.width - PanelGrid.gutter - labelColumns - 2
    }

    static func rows(_ model: PanelModel) -> [SettingRow] {
        var sheet = Sheet()
        let settings = SettingsStore.shared

        // **The tube first**, because it is the section somebody opens this
        // screen to change: it is the only one whose effect is on the glass in
        // front of them while they are changing it.
        sheet.heading("THE TUBE")
        sheet.choice("Lettering", Lettering.allCases, settings.preferences.lettering, \.label) {
            face in settings.edit { $0.lettering = face }
        }
        sheet.choice("Numerals", Numerals.allCases, settings.preferences.numerals, \.label) {
            figures in settings.edit { $0.numerals = figures }
        }
        sheet.choice(
            "Under the Last Track", Composition.allCases, settings.preferences.composition, \.label
        ) { composition in settings.edit { $0.composition = composition } }
        sheet.toggle("Let the Tube Fault", settings.preferences.faults) { on in
            settings.edit { $0.faults = on }
        }
        sheet.note("A failing tube is a picture, never a sound.")

        sheet.blank()
        sheet.heading("THE SHELF")
        sheet.chooser("Catalogue", path(CatalogueFile.locate().url)) { step in
            // `←` off the picked file, anything else onto a new one. The kit's
            // `forget` is the only reason the left end does anything: without
            // it a file chosen once could never be unchosen.
            if step < 0 {
                CatalogueFile.forget()
            } else {
                model.chooseCatalogue()
            }
            model.catalogueChanged()
        }
        sheet.toggle("Look Up on MusicBrainz", model.useMusicBrainz) { on in
            model.setUseMusicBrainz(on)
        }
        sheet.note("The shelf is read, never written.")

        sheet.blank()
        sheet.heading("IMPORTING A DISC")
        sheet.choice("Format", ImportFormat.allCases, model.importOptions.format, \.label) {
            format in model.setImportOptions { $0.format = format }
        }
        sheet.toggle("Embed the Sleeve", model.importOptions.sleeve) { on in
            model.setImportOptions { $0.sleeve = on }
        }
        sheet.choice(
            "Folder", ImportNames.FolderStyle.allCases, model.importOptions.folder, \.label
        ) { style in model.setImportOptions { $0.folder = style } }
        sheet.choice(
            "Track Names", ImportNames.TrackStyle.allCases, model.importOptions.trackStyle, \.label
        ) { style in model.setImportOptions { $0.trackStyle = style } }
        sheet.toggle("Eject When Done", model.importOptions.ejectWhenDone) { on in
            model.setImportOptions { $0.ejectWhenDone = on }
        }

        sheet.blank()
        sheet.heading("BURNING A DISC")
        sheet.toggle("Verify After Burning", model.burnOptions.verify) { on in
            model.setBurnOptions { $0.verify = on }
        }
        sheet.toggle("Write CD-Text", model.burnOptions.cdText) { on in
            model.setBurnOptions { $0.cdText = on }
        }
        sheet.toggle("Split Long Tracks", model.burnOptions.splitLong) { on in
            model.setSplitLong(on)
        }
        sheet.choice("Level Loudness", LevelMode.allCases, model.burnOptions.level, \.label) {
            level in model.setBurnOptions { $0.level = level }
        }
        sheet.toggle("Check the Blank First", model.burnOptions.mediaCheck) { on in
            model.setBurnOptions { $0.mediaCheck = on }
        }
        // **The three that are not here, said out loud.** They are on the Burn
        // menu and nowhere else, and a person who has found this screen and not
        // found them is owed the reason rather than left to conclude the port
        // forgot (D105).
        //
        // It says it in sixty characters because a note gets `PanelGrid.width`
        // less the gutter — sixty-five — and `SettingRowView` truncates rather
        // than wraps. The first draft of this line ran to seventy-four and the
        // tube ate the last four words, which is a note that explains nothing
        // and looks like a fault. Anything written here is counted first.
        sheet.note("Rehearse, Demo and Start at Disc are this run's — Burn menu.")

        sheet.blank()
        sheet.heading("THE SCRATCH")
        sheet.toggle("Keep the Scratch", settings.preferences.keepScratch) { on in
            settings.edit { $0.keepScratch = on }
        }
        sheet.chooser("Work Directory", work(settings.preferences.work)) { step in
            if step < 0 {
                settings.edit { $0.work = nil }
            } else if let chosen = model.chooseWorkDirectory() {
                settings.edit { $0.work = chosen.path }
            }
        }
        // **Both of them, not just the directory.** The scratch is made once at
        // start-up and the two variables are applied once at start-up with it,
        // so neither switch can reach the directory this session is already
        // using — and a switch that looks like it did something and did not is
        // the one thing this screen must not do (D105).
        sheet.note("Both take effect at the next launch.")

        return sheet.rows
    }

    // MARK: - What a path looks like on a 69-column panel

    /// Shown from its **tail**, which is the opposite of everything else on the
    /// panel and is `Columns.wrap`'s own reasoning: the end of a path is the
    /// half worth reading, and `…/cd-collection/…` says nothing about which
    /// file was found. The home directory goes back to `~` first, which is
    /// usually enough on its own.
    static func path(_ url: URL) -> String { shorten(url.path) }

    private static func work(_ chosen: String?) -> String {
        // Nil is what `Scratch.workBase` does with no variable set, written out
        // rather than left as an empty row — a blank value reads as broken.
        shorten(chosen ?? "~/.cache/muthur/work")
    }

    private static func shorten(_ path: String) -> String {
        let home = NSHomeDirectory()
        var shown = path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path[...]
        let columns = valueColumns
        guard columns > 1, Columns.width(of: String(shown)) > columns else { return String(shown) }
        while !shown.isEmpty, Columns.width(of: String(shown)) > columns - 1 {
            shown = shown.dropFirst()
        }
        return "…" + shown
    }

    // MARK: - Building the table

    /// The rows under construction, and the only place an id is handed out.
    ///
    /// The ids are positions in this array, which is what lets the cursor be an
    /// index and what lets a click land on a row without the view being told
    /// twice what order the rows are in.
    private struct Sheet {
        var rows: [SettingRow] = []

        mutating func heading(_ text: String) { add(text, .heading, nil) }
        mutating func blank() { add("", .blank, nil) }
        mutating func note(_ text: String) { add(text, .note, nil) }

        mutating func toggle(
            _ label: String, _ on: Bool, _ set: @escaping @MainActor (Bool) -> Void
        ) {
            // Every end of the rocker flips it, and so does `⏎`. A switch has
            // two states, so *the other one* is the only answer any of the three
            // could honestly give — a `←` that meant *off* would be a key that
            // does nothing half the time it is pressed.
            add(label, .toggle(on)) { _ in set(!on) }
        }

        // `Sendable` as well as `Equatable`, because the value is captured by a
        // closure the main actor will run later. Every enum that reaches here
        // is one already — they are frozen sets of cases — so this is the
        // compiler naming a fact rather than a constraint anybody has to meet.
        mutating func choice<Value: Equatable & Sendable>(
            _ label: String,
            _ options: [Value],
            _ current: Value,
            _ text: KeyPath<Value, String>,
            _ set: @escaping @MainActor (Value) -> Void
        ) {
            let shown = options.first(where: { $0 == current }).map { $0[keyPath: text] } ?? ""
            add(label, .choice(shown)) { step in
                guard !options.isEmpty else { return }
                let here = options.firstIndex(where: { $0 == current }) ?? 0
                // `⏎` is a step forward, which makes it the same key as `→` on
                // these rows — the alternative was for it to do nothing, and a
                // cap that is dead on two thirds of the screen is worse.
                let by = step == 0 ? 1 : step
                let next = (here + by + options.count) % options.count
                set(options[next])
            }
        }

        mutating func chooser(
            _ label: String, _ shown: String, _ act: @escaping @MainActor (Int) -> Void
        ) {
            add(label, .chooser(shown), act)
        }

        private mutating func add(
            _ label: String, _ kind: SettingRow.Kind, _ act: (@MainActor (Int) -> Void)?
        ) {
            rows.append(SettingRow(id: rows.count, label: label, kind: kind, act: act))
        }
    }
}
