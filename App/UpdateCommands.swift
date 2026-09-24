import AppKit
import MUTHURKit
import SwiftUI

/// *Check for Updates…* (**D106**), under About with the other questions about
/// the program rather than the record.
///
/// **On demand only.** Nothing is asked of GitHub until somebody picks the
/// item: a program that phones home on launch is a program that has an opinion
/// about your network, and this one already has MusicBrainz for that.
///
/// **The dialogs are `NSAlert`s and not phosphor**, which is the one place this
/// departs from D105's argument on purpose. D105 kept the settings on the tube
/// because they are part of using the instrument. This is a question the menu
/// bar asked, about the application rather than the record, answered in the
/// menu bar's own voice — and it has to be able to speak with the panel on any
/// screen at all, including one that is mid-burn and refusing it.
@MainActor
@Observable
final class Updater {
    private(set) var isBusy = false

    func check(model: PanelModel) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            let current = Self.runningVersion
            do {
                switch try await Update.check(current: current) {
                case .current(let release):
                    say(
                        "MU/TH/UR \(current) is current.",
                        "The newest release is \(release.tag).")
                case .available(let release):
                    await offer(release, over: current, model: model)
                }
            } catch {
                say("Could not check for updates.", error.localizedDescription)
            }
        }
    }

    private func offer(_ release: Update.Release, over current: Update.Version, model: PanelModel) async {
        let alert = NSAlert()
        alert.messageText = "MU/TH/UR \(release.version) is out."
        var detail = "This is \(current)."
        let notes = release.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            // The notes end with `release.sh`'s install instructions, which
            // are for somebody without this menu item. The part above them is
            // the part about the release.
            let above = notes.components(separatedBy: "## Install").first ?? notes
            let trimmed = above.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { detail += "\n\n" + String(trimmed.prefix(800)) }
        }
        if model.record != nil {
            detail += "\n\nThe record will stop. MU/TH/UR reopens when the new one is in place."
        }
        alert.informativeText = detail
        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Later")
        if release.page != nil { alert.addButton(withTitle: "Release Notes") }

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            await install(release, model: model)
        case .alertThirdButtonReturn:
            if let page = release.page { NSWorkspace.shared.open(page) }
        default:
            break
        }
    }

    private func install(_ release: Update.Release, model: PanelModel) async {
        // Asked again rather than trusted from when the menu was opened: a
        // burn can start while the alert is up, and quitting under one is a
        // ruined blank.
        guard !Self.mustNotQuit(model) else {
            say(
                "Not while a disc is being written.",
                "Pick Check for Updates… again once the burn or the import has finished.")
            return
        }
        do {
            let bundle = try await Update.fetch(release)
            guard !Self.mustNotQuit(model) else {
                try? FileManager.default.removeItem(
                    at: bundle.deletingLastPathComponent().deletingLastPathComponent())
                say(
                    "Not while a disc is being written.",
                    "Pick Check for Updates… again once the burn or the import has finished.")
                return
            }
            try Update.handOff(bundle, over: Bundle.main.bundleURL)
            // `AppDelegate`'s ordinary quit — the engine stops and the scratch
            // is torn down exactly as for ⌘Q. The hand-off is waiting on it.
            NSApp.terminate(nil)
        } catch {
            say("The update was not installed.", error.localizedDescription)
        }
    }

    static func mustNotQuit(_ model: PanelModel) -> Bool {
        model.isBurning || model.isImporting
    }

    /// The bundle's own number, which is `MARKETING_VERSION` by way of
    /// `Info.plist` — the same thing `release.sh` checks against the tag.
    static var runningVersion: Update.Version {
        let said = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return said.flatMap(Update.Version.init) ?? Update.Version("0")!
    }

    private func say(_ message: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }
}
