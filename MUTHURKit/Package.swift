// swift-tools-version: 6.1

import PackageDescription

// The headless half — everything in docs/parity.md §1–§8 that can be decided
// without a screen. It is a package rather than a folder in the app target so
// that the parity suites can reach the fallback chains and the ordering rules
// with `swift test`, and so that nothing in here can quietly import SwiftUI.
let package = Package(
    name: "MUTHURKit",
    // Current macOS and one back, per CLAUDE.md.
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MUTHURKit", targets: ["MUTHURKit"])
    ],
    targets: [
        .target(name: "MUTHURKit"),
        .testTarget(name: "MUTHURKitTests", dependencies: ["MUTHURKit"]),
    ]
)
