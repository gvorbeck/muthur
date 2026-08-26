import AppKit
import MUTHURKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct MUTHURApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var model = PanelModel()

    var body: some Scene {
        WindowGroup("MU/TH/UR") {
            PanelView(model: model)
                .task {
                    delegate.model = model
                    Scratch.sweepAbandoned()

                    if CommandLine.arguments.count > 1 {
                        let path = CommandLine.arguments[1]
                        do {
                            let (url, kind) = try SourceOpener.resolve(path: path)
                            model.open(source: url, kind: kind)
                        } catch {
                            model.die("\(error)")
                        }
                    } else {
                        model.scan()
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Collection…") { chooseCollection() }
            }
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
