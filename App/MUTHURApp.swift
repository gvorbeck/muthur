import MUTHURKit
import SwiftUI

// Nothing stands between launching and sound (docs/parity.md D8), so this
// stays a bare window until there is a record to put in it.
@main
struct MUTHURApp: App {
    var body: some Scene {
        WindowGroup("MU/TH/UR") {
            Color.black
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
    }
}
