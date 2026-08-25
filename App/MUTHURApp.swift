import MUTHURKit
import SwiftUI

@main
struct MUTHURApp: App {
    @State private var model = PanelModel()

    var body: some Scene {
        WindowGroup("MU/TH/UR") {
            PanelView(model: model)
                .task {
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
