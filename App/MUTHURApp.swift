import AppKit
import MUTHURKit
import SwiftUI

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
