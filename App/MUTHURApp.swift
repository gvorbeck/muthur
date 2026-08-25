import MUTHURKit
import SwiftUI

// Nothing stands between launching and sound (docs/parity.md D8). Until §1 gives
// the app a way to be handed a record — an argument, a picker, a zip, the disc
// in the drive — that promise is the one thing here that cannot be kept, and
// `OpenRecord` is a placeholder standing where §1 goes.
@main
struct MUTHURApp: App {
    @State private var model = PanelModel()

    var body: some Scene {
        WindowGroup("MU/TH/UR") {
            PanelView(model: model)
                .task {
                    if let preset = OpenRecord.preset { model.open(folder: preset) }
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Record…") {
                    if let folder = OpenRecord.ask() { model.open(folder: folder) }
                }
                .keyboardShortcut("o")
            }
        }
    }
}
