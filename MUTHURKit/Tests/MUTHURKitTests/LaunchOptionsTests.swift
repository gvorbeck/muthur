import Foundation
import Testing

@testable import MUTHURKit

/// §1.1 — the argument loop (`player:329`).
struct LaunchOptionsTests {

    @Test func noArgumentsIsThePicker() throws {
        let options = try LaunchOptions.parse([])
        #expect(options.sourcePath == nil)
        #expect(!options.wantCD)
        #expect(options.useMusicBrainz)
    }

    @Test func cdFlag() throws {
        #expect(try LaunchOptions.parse(["--cd"]).wantCD)
    }

    /// **`player:3517`'s precedence.** Asking for a record *and* the disc in the
    /// same breath is not an error — the record wins, and `--cd` is not even
    /// consulted.
    @Test func aPathBeatsTheCDFlagWhicheverOrderTheyArriveIn() throws {
        let first = try LaunchOptions.parse(["--cd", "/albums/Deluxe"])
        #expect(first.sourcePath == "/albums/Deluxe")
        #expect(first.wantCD)

        let second = try LaunchOptions.parse(["/albums/Deluxe", "--cd"])
        #expect(second.sourcePath == "/albums/Deluxe")
        #expect(second.wantCD)
    }

    @Test func theRemainingFlags() throws {
        #expect(try !LaunchOptions.parse(["--no-mb"]).useMusicBrainz)
        #expect(try LaunchOptions.parse(["-n"]).dryRun)
        #expect(try LaunchOptions.parse(["--dry-run"]).dryRun)
        #expect(try LaunchOptions.parse(["-h"]).help)
        #expect(try LaunchOptions.parse(["--help"]).help)
        #expect(try LaunchOptions.parse(["--check"]).check)
    }

    @Test func flagsCombine() throws {
        let options = try LaunchOptions.parse(["--cd", "--no-mb", "-n"])
        #expect(options.wantCD)
        #expect(!options.useMusicBrainz)
        #expect(options.dryRun)
        #expect(options.sourcePath == nil)
    }

    /// **`-*` dies rather than being taken for a path.** Guessing here would
    /// open something nobody asked for.
    @Test func anUnknownFlagDies() {
        #expect(throws: LaunchOptions.Failure.unknownOption("--rip")) {
            try LaunchOptions.parse(["--rip"])
        }
        #expect(throws: LaunchOptions.Failure.unknownOption("-x")) {
            try LaunchOptions.parse(["-x"])
        }
    }

    @Test func twoPathsDie() {
        #expect(throws: LaunchOptions.Failure.severalSources("/b")) {
            try LaunchOptions.parse(["/a", "/b"])
        }
    }

    @Test func theRefusalsSayWhatIsWrong() {
        #expect(
            LaunchOptions.Failure.unknownOption("--rip").description
                == "unknown option: --rip (try --help)"
        )
        #expect(
            LaunchOptions.Failure.severalSources("/b").description
                == "one source at a time, got: /b"
        )
    }

    // MARK: - `--no-mb`'s other half

    /// §11 and the disc path read the environment variable the same way, so the
    /// health check cannot claim the lookup is on while the disc path has it
    /// off.
    @Test func theEnvironmentVariableAgreesWithTheFlag() {
        #expect(!SourceOpener.musicBrainzDisabled(environment: [:]))
        #expect(!SourceOpener.musicBrainzDisabled(environment: ["MUTHUR_NO_MB": "0"]))
        #expect(!SourceOpener.musicBrainzDisabled(environment: ["MUTHUR_NO_MB": ""]))
        #expect(SourceOpener.musicBrainzDisabled(environment: ["MUTHUR_NO_MB": "1"]))
        #expect(SourceOpener.musicBrainzDisabled(environment: ["MUTHUR_NO_MB": "yes"]))
    }

    /// **Either switch alone is enough**, which is `[ "$USE_MB" = 1 ]`
    /// (`player:1839`) read against a variable that both the flag and the
    /// environment can have already set to 0 (`player:81`, `player:334`).
    @Test func theFlagSwitchesItOffWithNoVariableSet() throws {
        let options = try LaunchOptions.parse(["--no-mb", "--cd"])
        #expect(
            SourceOpener.musicBrainzDisabled(
                flag: options.useMusicBrainz, environment: [:]))
    }

    /// **Nothing switches it back on.** There is no `--mb`, and setting the
    /// variable to `0` does not undo the flag — the script has no case that
    /// raises `USE_MB` either.
    @Test func neitherSwitchCanUndoTheOther() throws {
        #expect(
            SourceOpener.musicBrainzDisabled(
                flag: false, environment: ["MUTHUR_NO_MB": "0"]))
        #expect(
            SourceOpener.musicBrainzDisabled(
                flag: true, environment: ["MUTHUR_NO_MB": "1"]))
        #expect(
            !SourceOpener.musicBrainzDisabled(flag: true, environment: [:]))
    }

    /// The report has two names to choose between where the script had one, and
    /// naming the wrong one sends the reader to the wrong switch.
    @Test func theReportNamesTheSwitchThatIsActuallySet() {
        #expect(SourceOpener.musicBrainzSwitch(flag: true, environment: [:]) == .on)
        #expect(
            SourceOpener.musicBrainzSwitch(flag: false, environment: [:]).label == "--no-mb")
        #expect(
            SourceOpener.musicBrainzSwitch(
                flag: true, environment: ["MUTHUR_NO_MB": "1"]
            ).label == "MUTHUR_NO_MB")
    }

    /// `die "no audio CD in the drive"` (`player:3528`) — the script's words.
    @Test func theEmptyDriveRefusalKeepsTheScriptsWords() {
        #expect(SourceOpener.Failure.noDisc.description == "no audio CD in the drive")
    }
}
