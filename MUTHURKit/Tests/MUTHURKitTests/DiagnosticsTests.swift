import Foundation
import Testing

@testable import MUTHURKit

/// §11. Every row and every verdict, on a machine described entirely by its
/// probes — which is what lets the suite ask about a drive that has a disc in
/// it, a machine with no ffprobe, and an unwritable scratch directory without
/// having any of the three.
@Suite("§11 Diagnostics")
struct DiagnosticsTests {

    /// A machine with everything, so a test only has to say what is different
    /// about the one it means.
    static func probes(
        tools: Set<String> = ["ffmpeg", "ffprobe", "drutil", "cdda2wav", "cdrecord"],
        environment: [String: String] = [:],
        drutil: String? = "  Type: CD-ROM\t\t  Name: /dev/disk4\n",
        /// The disc §1.3 finds on that media. Consulted only after `drutil` has
        /// said there is media at all, so a `drutil` above that reports an empty
        /// bay makes this unreachable rather than contradictory.
        disc: DiscFinder.Found? = DiscFinder.Found(
            volume: URL(fileURLWithPath: "/Volumes/Deluxe"), device: "/dev/disk4",
            route: .cddafs, deviceConfirmed: false
        ),
        route: String? = "MacBook Pro Speakers",
        sleeveEnabled: Bool = true,
        useMusicBrainz: Bool = true,
        shelf: Catalogue? = Catalogue(csv: "Title,Artist,Year\nCut,The Slits,1979\n"),
        free: UInt64 = 96 * 1024 * 1024 * 1024
    ) -> Diagnostics.Probes {
        Diagnostics.Probes(
            environment: environment.merging(["MUTHUR_WORK": NSTemporaryDirectory()]) { a, _ in a },
            tool: { tools.contains($0) ? URL(fileURLWithPath: "/opt/homebrew/bin/\($0)") : nil },
            drutil: { drutil },
            disc: { disc },
            outputRoute: { route },
            sleeveEnabled: sleeveEnabled,
            useMusicBrainz: useMusicBrainz,
            catalogue: { (URL(fileURLWithPath: "/x/collection.csv"), shelf) },
            freeSpace: { _ in free }
        )
    }

    static func row(_ report: Diagnostics.Report, _ label: String) -> Check? {
        report.checks.first { $0.label == label }
    }

    // MARK: - The scaffolding (panel.sh:580–panel.sh:606)

    /// `fail` is the only thing that moves the exit code. Ten of the script's
    /// fourteen can only ever warn — the check exists to explain, not to gate.
    @Test func onlyAFailureChangesTheExitCode() {
        let clean = Diagnostics.Report(checks: [Check(.ok, "a", "")])
        #expect(clean.exitCode == 0)

        let warned = Diagnostics.Report(checks: [Check(.ok, "a", ""), Check(.warn, "b", "")])
        #expect(warned.exitCode == 0)

        let failed = Diagnostics.Report(checks: [Check(.warn, "a", ""), Check(.fail, "b", "")])
        #expect(failed.exitCode == 1)
    }

    /// **Three verdicts, not two.** `check_summary` has a middle case
    /// (`panel.sh:602`) that the parity table had missed, and it is the one most
    /// machines land on.
    @Test func thereAreThreeVerdictsAndTheMiddleOneIsTheCommonOne() {
        let clean = Diagnostics.Report(checks: [Check(.ok, "a", "")])
        #expect(clean.verdict == "I CAN PLAY A RECORD.")
        #expect(clean.mark == .ok)

        let warned = Diagnostics.Report(checks: [Check(.warn, "a", "")])
        #expect(warned.verdict == "I CAN PLAY A RECORD. THE ! ITEMS ABOVE ARE USUALLY FINE.")
        #expect(warned.mark == .warn)

        // A failure outranks a warning, and says so about the failure.
        let failed = Diagnostics.Report(checks: [Check(.warn, "a", ""), Check(.fail, "b", "")])
        #expect(failed.verdict == "I CANNOT PLAY A RECORD. THE ✗ ITEMS ABOVE ARE WHY.")
        #expect(failed.mark == .fail)
    }

    /// **D8's boundary, asserted.** The voice is first person in the verdict and
    /// nowhere else: every row is a label and a fact. If this fails, the conceit
    /// has leaked out of the one room it was given.
    @Test func theVoiceIsInTheVerdictAndNowhereElse() {
        let report = Diagnostics.run(DiagnosticsTests.probes())
        for check in report.checks {
            #expect(!check.detail.contains(" I "), "the voice leaked into \(check.label)")
            #expect(!check.detail.hasPrefix("I "), "the voice leaked into \(check.label)")
        }
        #expect(report.verdict.hasPrefix("I "))
    }

    /// `ck` never prints a bare status: the fix is the reason the screen exists
    /// (`panel.sh:587`).
    @Test func noRowIsABareStatus() {
        let report = Diagnostics.run(DiagnosticsTests.probes())
        for check in report.checks {
            #expect(!check.label.isEmpty)
            #expect(check.detail.count > 10, "\(check.label) says nothing useful")
        }
    }

    @Test func theMarksAreTheScriptsMarks() {
        #expect(Check.Mark.ok.glyph == "✓")
        #expect(Check.Mark.warn.glyph == "!")
        #expect(Check.Mark.fail.glyph == "✗")
    }

    // MARK: - The rows that changed stack

    /// The five rows that asked about mpv, `nc`, tar/unzip and the terminal are
    /// gone, and nothing has quietly kept their names.
    @Test func theRowsThatAskedAboutMpvAreGone() {
        let report = Diagnostics.run(DiagnosticsTests.probes())
        let labels = report.checks.map(\.label)
        for absent in ["mpv", "mpv archives", "unix sockets", "terminal", "window size"] {
            #expect(!labels.contains(absent))
        }
        // And the subsystems they were asking about are still reported on.
        #expect(labels.contains("playback"))
        #expect(labels.contains("zips"))
    }

    /// `ffprobe` was a hard failure in bash. Here it is the fallback decoder's
    /// tags, so its absence costs formats rather than everything.
    @Test func noFFprobeIsAWarningAndNotAFailure() {
        let report = Diagnostics.run(DiagnosticsTests.probes(tools: []))
        let row = try? #require(DiagnosticsTests.row(report, "metadata"))
        #expect(row?.mark == .warn)
        #expect(row?.detail.contains("Opus and Ogg") == true)
        // And it says what to install, which is the whole point (`player:363`).
        #expect(row?.detail.contains("brew install ffmpeg") == true)
        #expect(report.exitCode == 0)
    }

    @Test func ffprobeWhereItIsSaysWhereItIs() {
        let report = Diagnostics.run(DiagnosticsTests.probes())
        #expect(DiagnosticsTests.row(report, "metadata")?.mark == .ok)
        #expect(
            DiagnosticsTests.row(report, "metadata")?.detail.contains("/opt/homebrew/bin/ffprobe")
                == true)
    }

    // MARK: - The ffmpeg row, which had gone missing (D40, §17)

    /// **§17's last box, and the reason it was still open.** Bash's ffmpeg row
    /// lived on `analyser` and cost you a pattern instead of columns
    /// (`player:367`, `player:374`). Natively ffmpeg is the *fallback decoder*,
    /// so its absence costs four formats outright — a larger consequence, and
    /// the check has to say the new thing rather than the old one.
    @Test func noFFmpegMeansFourFormatsWillNotPlayAndTheRowSaysSo() throws {
        let report = Diagnostics.run(
            DiagnosticsTests.probes(tools: ["ffprobe", "drutil", "cdda2wav"]))
        let row = try #require(DiagnosticsTests.row(report, "playback"))
        #expect(row.mark == .warn)
        #expect(row.detail.contains("no ffmpeg"))
        #expect(row.detail.contains("will not play"))
        #expect(row.detail.contains("brew install ffmpeg"))
        // The old sentence is gone: nothing here promises a pattern.
        #expect(!row.detail.contains("fall back to a pattern"))
        // Every format the opener actually refuses is named, not just the two
        // §17 happened to write down.
        for format in ["Opus", "Ogg", "APE", "WMA"] {
            #expect(row.detail.contains(format), "\(format) is refused and unnamed")
        }
        // Still a warning: everything that is not one of those four plays.
        #expect(report.exitCode == 0)
    }

    /// The other half of the same guard. `AudioSourceOpener` needs both binaries
    /// (`AudioSource.swift:63`), so a machine with ffmpeg and no ffprobe opens
    /// exactly as little — and a row that only asked after ffmpeg would be the
    /// same hole one binary along.
    @Test func theFallbackNeedsBothBinariesAndTheRowNamesWhicheverIsMissing() throws {
        var report = Diagnostics.run(DiagnosticsTests.probes(tools: ["ffmpeg"]))
        var row = try #require(DiagnosticsTests.row(report, "playback"))
        #expect(row.mark == .warn)
        #expect(row.detail.contains("no ffprobe"))
        #expect(!row.detail.contains("no ffmpeg"))

        report = Diagnostics.run(DiagnosticsTests.probes(tools: []))
        row = try #require(DiagnosticsTests.row(report, "playback"))
        #expect(row.detail.contains("no ffmpeg and ffprobe"))

        // And the two names are the two the opener looks for.
        #expect(AudioSourceOpener.fallbackTools == ["ffmpeg", "ffprobe"])
    }

    /// With both there the row still answers "where did the mpv check go" —
    /// the engine is the system's — and now also says what is behind it.
    @Test func playbackWithEverythingNamesTheEngineAndTheFallback() throws {
        let report = Diagnostics.run(DiagnosticsTests.probes())
        let row = try #require(DiagnosticsTests.row(report, "playback"))
        #expect(row.mark == .ok)
        #expect(row.detail.contains("AVFoundation"))
        #expect(row.detail.contains("part of the system"))
        #expect(row.detail.contains("ffmpeg behind it"))
    }

    /// §9 is a live tap, so the analyser row keeps its `ok` whatever is
    /// installed — the half of bash's ffmpeg row that genuinely did stop being
    /// true (`player:928`).
    @Test func theAnalyserRowNoLongerDependsOnAnything() throws {
        let report = Diagnostics.run(DiagnosticsTests.probes(tools: []))
        let row = try #require(DiagnosticsTests.row(report, "analyser"))
        #expect(row.mark == .ok)
        #expect(row.detail.contains("the audio itself"))
        #expect(!row.detail.contains("pattern"))
    }

    // MARK: - The disc (§1.3)

    /// The script's own `ok` (`player:396`), which this row got back when §1.3
    /// landed: there is media, the disc source opened it, and the row says
    /// where. **It said `the disc source is not built yet` for as long as that
    /// was true and then went on saying it** — a line only a machine with a disc
    /// in the bay could catch lying, which is why it is pinned here.
    @Test func aDiscTheDiscSourceFoundIsAnOkAndSaysWhereItIs() throws {
        let report = Diagnostics.run(DiagnosticsTests.probes())
        let row = try #require(DiagnosticsTests.row(report, "optical drive"))
        #expect(row.mark == .ok)
        #expect(row.detail == "media: CD-ROM — mounted at /Volumes/Deluxe")
        // Nothing about it promises less than it can do.
        #expect(!row.detail.contains("cannot"))
        #expect(report.exitCode == 0)
    }

    /// The other half of the same question, and **the reason the finder is asked
    /// rather than the type string**: a real audio CD reports `CD-ROM` (§19 step
    /// 1), so the same word covers both outcomes and only §1.3 can tell them
    /// apart. Media nothing mounted as an audio CD is a warning — a data disc, a
    /// DVD, or a disc that has not finished mounting.
    @Test func mediaTheDiscSourceCannotOpenStaysAWarning() throws {
        let report = Diagnostics.run(
            DiagnosticsTests.probes(
                drutil: "  Type: DVD-R\t\t  Name: /dev/disk4\n", disc: nil))
        let row = try #require(DiagnosticsTests.row(report, "optical drive"))
        #expect(row.mark == .warn)
        #expect(row.detail.contains("media: DVD-R"))
        #expect(row.detail.contains("--cd has nothing to open"))
        // A disc it will not play is still not a reason to refuse to run.
        #expect(report.exitCode == 0)
    }

    @Test func anEmptyBayIsTheScriptsOwnSentence() {
        let report = Diagnostics.run(DiagnosticsTests.probes(drutil: "  Type: No Media\n"))
        #expect(DiagnosticsTests.row(report, "optical drive")?.detail == "no disc, or no drive")
    }

    @Test func noDrutilMeansCDsCannotBeDetected() {
        let report = Diagnostics.run(
            DiagnosticsTests.probes(tools: ["ffprobe", "cdda2wav"], drutil: nil))
        #expect(
            DiagnosticsTests.row(report, "optical drive")?.detail
                == "drutil not found — CDs cannot be detected")
    }

    /// **D37.** The first *word* after `Type:`, not awk's second colon field.
    /// `drutil` packs two columns onto that line, so `player:396` prints
    /// `media: CD-ROM Name`; `burncd:324` — the same author, the same output —
    /// takes the word and says why.
    @Test func theMediaTypeIsTheFirstWordAfterTheLabel() {
        // The real shape of the line, and the one the awk gets wrong.
        #expect(Diagnostics.mediaType("Vendor: X\n  Type: DVD-R\t  Name: /dev/disk4\n") == "DVD-R")
        #expect(Diagnostics.mediaType("  Type: CD-ROM  ") == "CD-ROM")
        #expect(Diagnostics.mediaType("nothing about media here") == nil)
        #expect(Diagnostics.mediaType(nil) == nil)
        // `No Media Inserted` is a word, so `[ -n "$v" ]` at `player:397` lets
        // it through and bash prints `media: No Media`. Caught the way
        // `burncd:319` catches it — anywhere in the status, case-insensitively.
        #expect(Diagnostics.mediaType("  Type: No Media Inserted\n") == nil)
        #expect(Diagnostics.mediaType("Drive: X\n   Type: no media\n") == nil)
    }

    /// CD-Text is presence only, and **nothing in the check opens the drive** —
    /// `cdrecord -checkdrive` would take the media away from drutil
    /// (`burncd:278`).
    @Test func cdTextPrefersCdda2wavAndFallsBackToCdrecord() {
        var report = Diagnostics.run(DiagnosticsTests.probes(tools: ["cdda2wav", "cdrecord"]))
        #expect(DiagnosticsTests.row(report, "CD-Text")?.detail == "cdda2wav present")

        report = Diagnostics.run(DiagnosticsTests.probes(tools: ["cdrecord"]))
        #expect(DiagnosticsTests.row(report, "CD-Text")?.detail == "cdrecord present")

        report = Diagnostics.run(DiagnosticsTests.probes(tools: []))
        #expect(
            DiagnosticsTests.row(report, "CD-Text")?.detail
                == "no cdrtools — discs fall back to MusicBrainz or numbers")
        #expect(DiagnosticsTests.row(report, "CD-Text")?.mark == .warn)
    }

    // MARK: - MusicBrainz

    @Test func musicBrainzSwitchedOffSaysWhatThatCosts() {
        let report = Diagnostics.run(DiagnosticsTests.probes(environment: ["MUTHUR_NO_MB": "1"]))
        let row = try? #require(DiagnosticsTests.row(report, "MusicBrainz"))
        #expect(row?.mark == .warn)
        #expect(row?.detail.contains("untitled discs stay untitled") == true)
        #expect(row?.detail.contains("MUTHUR_NO_MB") == true)
    }

    /// **`--check --no-mb` warns**, which is the whole reason the flag is
    /// carried this far: `run_check` reads `USE_MB` (`player:410`), the same
    /// merged value the lookup reads, so the row cannot say the lookup is on
    /// while the disc path has it off.
    @Test func theFlagReachesTheRowWithNoVariableSet() {
        let report = Diagnostics.run(DiagnosticsTests.probes(useMusicBrainz: false))
        let row = try? #require(DiagnosticsTests.row(report, "MusicBrainz"))
        #expect(row?.mark == .warn)
        #expect(row?.detail == "disabled with --no-mb — untitled discs stay untitled")
    }

    /// It never reaches out to answer this. A check that hangs on a captive
    /// portal has failed at the one job it has.
    @Test func musicBrainzOnSaysWhenItWillBeAsked() {
        let report = Diagnostics.run(DiagnosticsTests.probes())
        let row = try? #require(DiagnosticsTests.row(report, "MusicBrainz"))
        #expect(row?.mark == .ok)
        #expect(row?.detail.contains("never before") == true)
    }

    // MARK: - Scratch space (player:423), all three outcomes

    @Test func scratchSpaceSaysHowMuchRoomAndWhere() throws {
        let directory = NSTemporaryDirectory() + "muthur-check-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let report = Diagnostics.run(
            DiagnosticsTests.probes(environment: ["MUTHUR_WORK": directory]))
        let row = try #require(DiagnosticsTests.row(report, "scratch space"))
        #expect(row.mark == .ok)
        #expect(row.detail.contains("96.0 GiB free in \(directory)"))
    }

    /// The middle outcome, and the script's comment is the reason it is a
    /// warning: `$TMPDIR` works, and it is the directory the OS may reclaim
    /// under a playing album.
    @Test func theTmpdirFallbackIsAWarningRatherThanAPlainOk() throws {
        // A cache directory that cannot be made forces the fallback.
        let blocked = NSTemporaryDirectory() + "muthur-blocked-\(UUID().uuidString)"
        FileManager.default.createFile(atPath: blocked, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: blocked) }

        let report = Diagnostics.run(
            Diagnostics.Probes(
                environment: ["XDG_CACHE_HOME": blocked, "TMPDIR": NSTemporaryDirectory()],
                tool: { _ in nil }, drutil: { nil }, outputRoute: { nil },
                catalogue: { (URL(fileURLWithPath: "/x"), nil) },
                freeSpace: { _ in 1024 }
            ))
        let row = try #require(DiagnosticsTests.row(report, "scratch space"))
        #expect(row.mark == .warn)
        #expect(row.detail.contains("reclaimed mid-play"))
    }

    // MARK: - The rows bash could not have had

    /// §8 exists now, and a `SHELF` line that is simply absent looks the same
    /// whether the record is not in the catalogue or the catalogue was never
    /// found. That ambiguity is the reason this row was added.
    @Test func theShelfSaysWhetherItFoundTheCatalogueAtAll() throws {
        var report = Diagnostics.run(DiagnosticsTests.probes())
        var row = try #require(DiagnosticsTests.row(report, "the shelf"))
        #expect(row.mark == .ok)
        #expect(row.detail.contains("1 records in /x/collection.csv"))

        report = Diagnostics.run(DiagnosticsTests.probes(shelf: nil))
        row = try #require(DiagnosticsTests.row(report, "the shelf"))
        #expect(row.mark == .warn)
        #expect(row.detail.contains("no catalogue at /x/collection.csv"))
        // And it is explicit that this costs annotation and not playback.
        #expect(row.detail.contains("records play"))
    }

    /// A catalogue that has been re-columned parses fine and looks nothing up,
    /// which §8 is built to survive silently. The check is where it stops being
    /// silent.
    @Test func aCatalogueWithNoTitleColumnIsReportedRatherThanTolerated() throws {
        let report = Diagnostics.run(
            DiagnosticsTests.probes(shelf: Catalogue(csv: "Barcode,Note\n123,x\n")))
        let row = try #require(DiagnosticsTests.row(report, "the shelf"))
        #expect(row.mark == .warn)
        #expect(row.detail.contains("no title column"))
    }

    /// The row that used to be the calm version of `die "nothing to play…"`
    /// (`player:1114`). **D50** took the scan away, and with it both the count
    /// and the warning — a row that cannot look cannot fail to find. It stays
    /// because two readers of `--check` would come looking for it and read its
    /// absence as a bug, and it says instead what the answer is now.
    ///
    /// Never `.warn`: the `zips` row's precedent (a capability, not a state).
    @Test func recordsNoLongerCountsAnythingAndSaysSoInsteadOfWarning() throws {
        for probes in [DiagnosticsTests.probes(), DiagnosticsTests.probes(disc: nil)] {
            let row = try #require(DiagnosticsTests.row(Diagnostics.run(probes), "records"))
            #expect(row.mark == .ok)
            #expect(row.detail.contains("no directory is searched"))
            #expect(row.detail.contains("BROWSE"))
        }
    }

    /// §14's box for route handling is unticked, and the row says so rather than
    /// reporting a route as though it were being followed.
    @Test func theAudioRouteIsReportedAndNotClaimed() throws {
        var report = Diagnostics.run(DiagnosticsTests.probes())
        var row = try #require(DiagnosticsTests.row(report, "audio output"))
        #expect(row.detail.contains("MacBook Pro Speakers"))
        #expect(row.detail.contains("not handled yet"))
        #expect(row.mark == .warn)

        report = Diagnostics.run(DiagnosticsTests.probes(route: nil))
        row = try #require(DiagnosticsTests.row(report, "audio output"))
        #expect(row.mark == .warn)
        #expect(row.detail.contains("no default output device"))
    }

    @Test func theSleeveRowKeepsTheQuestionAndNoneOfBashsAnswers() throws {
        var report = Diagnostics.run(DiagnosticsTests.probes())
        var row = try #require(DiagnosticsTests.row(report, "sleeve"))
        #expect(row.detail.contains("beside the record"))
        // None of the terminal's answers survive.
        #expect(!row.detail.contains("iTerm2"))
        #expect(!row.detail.contains("half blocks"))
        #expect(!row.detail.contains("cols"))

        report = Diagnostics.run(DiagnosticsTests.probes(sleeveEnabled: false))
        row = try #require(DiagnosticsTests.row(report, "sleeve"))
        #expect(row.detail == "off — no picture is looked for")
    }

    // MARK: - Against this machine

    /// The real check, run for real. It asserts nothing about *this* machine —
    /// it asserts that asking is safe: no row is missing, nothing throws, and
    /// the verdict is one of the three.
    @Test func theRealCheckRunsOnThisMachineAndAnswersEveryRow() {
        let report = Diagnostics.run()
        #expect(report.checks.count == 12)
        #expect(Set(report.checks.map(\.label)).count == 12)
        for check in report.checks {
            #expect(!check.detail.isEmpty, "\(check.label) had nothing to say")
        }
        #expect(
            [
                "I CAN PLAY A RECORD.",
                "I CAN PLAY A RECORD. THE ! ITEMS ABOVE ARE USUALLY FINE.",
                "I CANNOT PLAY A RECORD. THE ✗ ITEMS ABOVE ARE WHY.",
            ].contains(report.verdict))
    }

    // MARK: - What it looks like on 69 columns

    /// The measure the panel actually has, which is not the one you get by
    /// forgetting the margin. Two columns out is enough for the layout to eat
    /// the end of every long line.
    @Test func theDetailColumnIsWhatIsLeftAfterTheMarginTheMarkAndTheLabel() {
        #expect(Check.detailWidth == PanelGrid.width - PanelGrid.margin - 23)
        #expect(Check.detailWidth == 44)
    }

    /// The fix survives the panel. This is §11's last requirement and the only
    /// reason `Columns.wrap` exists.
    @Test func aFixTooWideForThePanelTurnsOverInsteadOfBeingCut() {
        let check = Check(
            .warn, "CD-Text",
            "no cdrtools — discs fall back to MusicBrainz or numbers")
        let lines = check.detailLines
        #expect(lines.count == 2)
        #expect(lines.joined(separator: " ") == check.detail)
        #expect(lines.allSatisfy { Columns.width(of: $0) <= Check.detailWidth })
        #expect(!lines.contains { $0.hasSuffix("…") })
    }

    /// A path has nowhere to break, so it is cut — visibly, with the ellipsis
    /// `truncate` puts there, rather than by running off the edge.
    @Test func aWordWiderThanTheMeasureIsCutAndSaysSo() {
        let long = String(repeating: "x", count: Check.detailWidth + 10)
        let lines = Columns.wrap(long, to: Check.detailWidth)
        #expect(lines.count == 1)
        #expect(lines[0].hasSuffix("…"))
        #expect(Columns.width(of: lines[0]) == Check.detailWidth)
    }

    /// A path is one word, so it breaks after a separator rather than losing
    /// its tail — which on the shelf row is the name of the file that was
    /// found, and the only part of the line anybody is looking for.
    @Test func aPathTooWideForThePanelBreaksAtItsSeparators() {
        let path = "/Users/garrett.vorbeck/Sites/cd-collection/data/collection.csv"
        let lines = Columns.wrap(path, to: Check.detailWidth)
        #expect(lines.count > 1)
        #expect(lines.joined() == path)
        #expect(lines.allSatisfy { Columns.width(of: $0) <= Check.detailWidth })
        #expect(!lines.contains { $0.hasSuffix("…") })
        #expect(lines.last == "data/collection.csv")
    }

    /// `--check` on a terminal is not the panel: nothing wraps, because a
    /// terminal is as wide as it is (`panel.sh:588`).
    @Test func theTerminalFormKeepsCkSLayoutAndWrapsNothing() {
        let report = Diagnostics.Report(checks: [
            Check(.ok, "playback", "AVFoundation"),
            Check(.warn, "CD-Text", "no cdrtools — discs fall back to MusicBrainz or numbers"),
        ])
        let lines = report.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(report.plainText.contains("  ✓  playback             AVFoundation"))
        // The long one is on one line, whole.
        #expect(
            lines.contains {
                $0.hasSuffix("no cdrtools — discs fall back to MusicBrainz or numbers")
            })
        #expect(report.plainText.contains(report.verdict))
    }

    /// The legend on the check screen names only what the check screen answers.
    @Test func theCheckLegendOffersOnlyLeavingAndAskingAgain() {
        let presses = Readout.checkLegend.flatMap { $0 }.flatMap(\.presses)
        #expect(presses == [.close, .rescan, .quit])
    }
}
