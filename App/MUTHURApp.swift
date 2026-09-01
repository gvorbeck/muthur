import AppKit
import MUTHURKit
import SwiftUI
import UniformTypeIdentifiers

/// The entry point is `main.swift`, not `@main` here — `--check` has to be
/// answered and exited before `NSApplication` starts (§11, `player:531`).
struct MUTHURApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var model = PanelModel()

    var body: some Scene {
        WindowGroup("MU/TH/UR") {
            PanelView(model: model)
                .task {
                    delegate.model = model
                    Scratch.sweepAbandoned()

                    // `player:3517`: a named source first, `--cd` second, the
                    // picker last. Naming a record and asking for the disc in
                    // the same breath is not an error — the record wins.
                    do {
                        let options = try LaunchOptions.parse(
                            Array(CommandLine.arguments.dropFirst())
                        )
                        // Before anything is opened, and not as an argument to
                        // one call: `--no-mb` outlives the launch. A disc put
                        // in later and opened off the picker (`r`, §1.2) is
                        // still this session's disc, and the flag still holds.
                        model.useMusicBrainz = options.useMusicBrainz
                        if let path = options.sourcePath {
                            let (url, kind) = try SourceOpener.resolve(path: path)
                            model.open(source: url, kind: kind)
                        } else if options.wantCD {
                            model.openDisc()
                        } else {
                            model.scan()
                        }
                    } catch {
                        model.die("\(error)")
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            // Under About, where a question about the machine belongs — the
            // same screen `--check` prints, kept reachable by someone who
            // launched this from the Dock and has no command line to type it
            // on (§11).
            CommandGroup(after: .appInfo) {
                Button("Health Check") { model.check() }
                    .keyboardShortcut("k")
            }
            CommandGroup(after: .newItem) {
                Button("Open Record…") { chooseRecord() }
                    .keyboardShortcut("o")
                Button("Collection…") { chooseCollection() }
            }
        }
    }

    /// **⌘O, and the reason it has to exist here.** `EmptyPanelView` promises
    /// this keystroke on the faceplate, and until now nothing bound it.
    ///
    /// The script never needs one: `pick_source` either hands back a record or
    /// dies where it stands — `die "nothing to play…"` (`player:1114`) when the
    /// scan came up empty, `screen_off; exit 0` (`player:3532`) when the user
    /// walked away from the picker — and `open_source` runs before the first
    /// frame is drawn (`player:3535`). There is no state in which that panel is
    /// up with no record in it, so there is nothing for it to offer. **A window
    /// cannot die on the user like that**: an app launched from the Dock with
    /// an empty `~/Music` has to stay on screen and say something, which is why
    /// `EmptyPanelView` exists at all and is marked there as a port invention.
    /// Having invented the state, the port owes it a way out.
    @MainActor
    private func chooseRecord() {
        let panel = NSOpenPanel()
        panel.message = "A folder of tracks, or a zip of one."
        panel.prompt = "Play"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.folder, .zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let (resolved, kind) = try SourceOpener.resolve(path: url.path)
            model.open(source: resolved, kind: kind)
        } catch {
            // `die "not a zip or a folder: %s"` (`player:3524`), in the panel's
            // own voice rather than an alert — the same place every other
            // refusal to open a source is already printed.
            model.die("\(error)")
        }
    }

    /// D5's file picker. There is no Settings screen yet — §11 and §13 are
    /// where one arrives — so the setting is a menu item until there is
    /// somewhere for it to live. What matters about it is not where it is
    /// drawn: it is that the choice leaves a **security-scoped bookmark**
    /// behind rather than a string, so it goes on working the day this is
    /// sandboxed and survives the file being moved.
    @MainActor
    private func chooseCollection() {
        let panel = NSOpenPanel()
        panel.message = "The catalogue this player reads the shelf out of."
        panel.prompt = "Read"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.directoryURL = CatalogueFile.locate().url.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        CatalogueFile.remember(url)
        model.catalogueChanged()
    }
}

/// `trap cleanup EXIT` (`player:324`). The app delegate is where macOS
/// guarantees us a call on every exit path that is not a `SIGKILL`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor weak var model: PanelModel?

    /// `applicationShouldTerminate` rather than `applicationWillTerminate` so the
    /// engine can be stopped asynchronously before the scratch directory is
    /// deleted — the script kills mpv before `rm -rf $WORK` for the same reason
    /// (`player:297`).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { @MainActor in
            await model?.cleanup()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
