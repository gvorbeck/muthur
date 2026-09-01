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
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--check") {
    // `player --check --no-mb` prints the warned row, because the script merges
    // the flag into `USE_MB` in the same argument loop that sets `RUN_CHECK`
    // (`player:329`) and `run_check` reads the merged value (`player:410`).
    // A parse that fails is left alone deliberately: the gate above is the
    // condition this file has always used, and an unknown option still belongs
    // to the app, which refuses it where every other refusal is printed.
    let options = (try? LaunchOptions.parse(arguments)) ?? LaunchOptions()
    let report = Diagnostics.run(
        Diagnostics.Probes(useMusicBrainz: options.useMusicBrainz)
    )
    FileHandle.standardOutput.write(Data(report.plainText.utf8))
    exit(report.exitCode)
}

MUTHURApp.main()
