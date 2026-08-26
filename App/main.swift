import Foundation
import MUTHURKit

// `--check` is the first thing anyone runs on a new machine (`panel.sh:575`),
// and what makes it useful is that it *ends*: it prints, it sets an exit code,
// and a script downstream can read the code (`player:531`). A window cannot do
// any of that, so this runs before there is one.
//
// Hence `main.swift` and no `@main` on `MUTHURApp`. The argument has to be read
// ahead of `NSApplication`, or the answer arrives after a Dock icon has bounced
// and a panel has opened, which is not what `--check` means. Everything else —
// a path to open, `-n`, `--cd` — belongs to the app and is read there.
if CommandLine.arguments.dropFirst().contains("--check") {
    let report = Diagnostics.run()
    FileHandle.standardOutput.write(Data(report.plainText.utf8))
    exit(report.exitCode)
}

MUTHURApp.main()
