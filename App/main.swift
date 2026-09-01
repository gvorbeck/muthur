import Foundation
import MUTHURKit

// Three flags print and end, and none of them can be answered by a window:
// `--check` (§11), `--help` (§1.1) and `-n` (§12). What makes them useful is
// that they *finish* — they print, they set an exit code, and a script
// downstream can read the code (`player:531`). A window cannot do any of that.
//
// Hence `main.swift` and no `@main` on `MUTHURApp`. Everything else — a path to
// open, `--cd`, `--no-mb` — belongs to the app and is read there.
//
// The order below is the script's own, and it is not alphabetical. `usage`
// exits from inside the argument loop (`player:335`), so `--help` beats
// everything; `CHECK` is tested at `player:531` and `DRY_RUN` at `player:3540`,
// so `--check` beats `-n`.
let arguments = Array(CommandLine.arguments.dropFirst())
let program = CommandLine.arguments.first ?? Usage.program

// The script's `die()` (`panel.sh:265`): a blank line, the tool's name, the
// message, stderr, exit 1. The panel has its own way of refusing (D36) because
// a window cannot die on the user; a command line has not got that problem.
func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\n\(Usage.program): \(message)\n".utf8))
    exit(1)
}

func say(_ text: String) {
    FileHandle.standardOutput.write(Data(text.utf8))
}

// **A parse that fails ends the program here, and nothing downstream sees it.**
// The script's argument loop is the first thing that runs and `-*` dies inside
// it (`player:336`), before `CHECK` is tested at 531 and long before there is
// anything on screen. This used to be a `try?`, which meant a refusal fell
// through to the panel: `MUTHUR --rip` opened a window and sat there, waiting
// to be told which record it was about, because a window is not a thing that
// can decline to exist. The message and the code are the script's own.
let parsed: LaunchOptions
do {
    parsed = try LaunchOptions.parse(arguments)
} catch {
    die("\(error)")
}

if parsed.help {
    say(Usage.text(invokedAs: program))
    exit(0)
}

if parsed.check {
    // `player --check --no-mb` prints the warned row, because the script merges
    // the flag into `USE_MB` in the same argument loop that sets `CHECK`
    // (`player:329`) and `run_check` reads the merged value (`player:410`).
    //
    // Read off the parse rather than off the raw arguments, which is a
    // distinction `--help` created: `--help --check` never sets `CHECK` in the
    // script either, because `usage` exits from inside the loop.
    let options = parsed
    let report = Diagnostics.run(
        Diagnostics.Probes(useMusicBrainz: options.useMusicBrainz)
    )
    say(report.plainText)
    exit(report.exitCode)
}

if parsed.dryRun {
    let options = parsed
    // `Inspect.run` is async because opening a source is — a zip is unpacked, a
    // disc is asked who it is — and there is no async main to hang it off. So
    // the main thread waits on a gate while the work runs on the cooperative
    // pool. Nothing in `MUTHURKit` is main-actor-isolated, which is the whole
    // reason this is safe rather than a deadlock, and is a property of the kit
    // being headless rather than a coincidence.
    final class Held: @unchecked Sendable {
        var outcome: Inspect.Outcome?
        var notes: [String] = []
    }
    let held = Held()
    let gate = DispatchSemaphore(value: 0)
    Task.detached {
        held.outcome = await Inspect.run(options, note: { held.notes.append($0) })
        gate.signal()
    }
    gate.wait()

    // `player:317` prints the kept-scratch line from the exit trap, so it lands
    // *after* whatever the run printed and on the other stream. Both of those
    // are kept — hence the notes are held and flushed here rather than as they
    // arrive.
    func flush() {
        for note in held.notes {
            FileHandle.standardError.write(Data("\(Usage.program): \(note)\n".utf8))
        }
    }
    switch held.outcome {
    case .printed(let listing):
        say(listing)
        flush()
        exit(0)
    case .died(let message):
        flush()
        die(message)
    case nil:
        die("nothing came back from the read")
    }
}

MUTHURApp.main()
