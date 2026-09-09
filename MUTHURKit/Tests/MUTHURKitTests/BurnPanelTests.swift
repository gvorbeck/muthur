import Foundation
import Testing

@testable import MUTHURKit

/// §20 stage 3a — the burn screen, the invocation, and the stand-in that drives
/// both.
///
/// **Nothing here needs a drive, and that is the point of the stage.** The panel
/// is drawing, the invocation is a value, and `FakeDrive` is a schedule; the
/// only thing missing is the machine that would answer, and when it arrives the
/// work is swapping one implementation for another rather than designing
/// anything.
@Suite("§20 stage 3a — the burn panel")
struct BurnPanelTests {

    private static let titles = [
        "Sixty Eight Grand", "Reptile Room", "Bicycle Race", "Kettle Whistle",
    ]
    private static let durations = [214, 187, 305, 141]

    private static func panel(totalMegabytes: Int = 200) -> BurnPanel {
        BurnPanel(
            disc: 1, of: 2, titles: titles, durations: durations,
            totalMegabytes: totalMegabytes)
    }

    // MARK: - Reading the drive

    /// The line as cdrecord actually pads it.
    @Test("A progress line is read as words")
    func parseLine() throws {
        let progress = try #require(
            BurnPanel.parse("Track 03:  12 of  45 MB written (fifo 100%) [buf  98%]  8.0x."))
        #expect(progress.track == 3)
        #expect(progress.done == 12)
        #expect(progress.total == 45)
        #expect(progress.buffer == "98")
        #expect(progress.speed == "8.0")
    }

    /// A full buffer puts the word and the number in one token, an emptying one
    /// in two, because the figure is padded into a fixed column. Both are the
    /// same line and both have to read.
    @Test("The buffer is read whether or not the padding split it off")
    func parseBuffer() throws {
        let full = try #require(
            BurnPanel.parse("Track 01:   0 of  55 MB written (fifo 100%) [buf 100%]  8.0x."))
        #expect(full.buffer == "100")
        let filling = try #require(
            BurnPanel.parse("Track 01:   0 of  55 MB written (fifo  12%) [buf   4%]  4.0x."))
        #expect(filling.buffer == "4")
        #expect(filling.speed == "4.0")
    }

    /// **Only what was observed.** cdrecord says a great deal besides its
    /// progress line — capability dumps, warnings, the table of contents it is
    /// about to write — and every one of those has to fall through without
    /// leaving a number on the panel.
    @Test("Everything that is not a progress line is dropped")
    func parseRejects() {
        let noise = [
            "",
            "Track 03:",
            "cdrecord: Operation not permitted. Cannot open '/dev/rdisk3'.",
            "Starting to write CD/DVD/BD at speed 8 in real SAO mode for single session.",
            "Track 03: Total bytes read/written: 12345/12345 (5 sectors).",
            "Track xx:  12 of  45 MB written",
            "Track 03:  12 of  45 GB written",
        ]
        for line in noise {
            #expect(BurnPanel.parse(line) == nil, "parsed something out of: \(line)")
        }
    }

    /// A drive that names no buffer and no speed still names its megabytes, and
    /// the panel says dashes for the two it was not told rather than keeping the
    /// last track's.
    @Test("A line without the trimmings is still a line")
    func parseBare() throws {
        var burn = Self.panel()
        burn.receive("Track 01: 10 of 50 MB written (fifo 100%) [buf  90%]  8.0x.", at: 5)
        burn.receive("Track 01: 20 of 50 MB written", at: 6)
        #expect(burn.doneMegabytes == 20)
        #expect(burn.buffer == BurnPanel.unknown)
        #expect(burn.speed == BurnPanel.unknown)
    }

    // MARK: - The running total

    /// cdrecord counts megabytes per track; the disc's figure is the tracks
    /// already closed plus this one's progress, and a closed track counts for its
    /// **stated** size rather than the last figure before the drive moved on.
    @Test("Finished tracks count for what the track said it was")
    func runningTotal() {
        var burn = Self.panel(totalMegabytes: 200)
        burn.receive("Track 01:  10 of  50 MB written", at: 1)
        #expect(burn.doneMegabytes == 10)
        // The drive falls silent at 48 and moves on: the track is still 50.
        burn.receive("Track 01:  48 of  50 MB written", at: 2)
        burn.receive("Track 02:   5 of  60 MB written", at: 3)
        #expect(burn.doneMegabytes == 55)
        #expect(burn.track == 2)
    }

    /// Our megabytes and cdrecord's are roundings of different numbers of the
    /// same bytes, so its sum can land past our total. Clamped **for the readout
    /// only** — the unclamped running total is kept, so the overshoot cannot be
    /// paid back out of the next track.
    @Test("An overshoot is clamped without losing the megabytes underneath it")
    func overshootIsClampedNotSubtracted() {
        var burn = Self.panel(totalMegabytes: 100)
        burn.receive("Track 01:  60 of  60 MB written", at: 1)
        burn.receive("Track 02:  50 of  50 MB written", at: 2)
        #expect(burn.doneMegabytes == 100)
        #expect(burn.percent == 100)
        burn.receive("Track 03:   5 of  40 MB written", at: 3)
        #expect(burn.doneMegabytes == 100)
    }

    // MARK: - The three phases

    /// The layout is identical in all three and the dashes stand in for what the
    /// drive has not filled in, so nothing on screen moves when a phase changes
    /// hands.
    @Test("The lead-in says so, and says nothing it has not been told")
    func leadIn() {
        let burn = Self.panel()
        #expect(burn.phase == .lead)
        #expect(burn.percentField == "LEAD-IN")
        #expect(burn.trackField == "--")
        #expect(burn.bufferField == "--%")
        #expect(burn.remainingField == "--:--")
        #expect(burn.meta == "WRITING · DISC 1 OF 2 · LEAD-IN")
    }

    /// Three seconds of silence with the disc all but full is the lead-out — the
    /// bar goes to the end, and the two figures the drive is no longer producing
    /// go back to dashes.
    @Test("Silence at the end of a full disc is the lead-out")
    func leadOut() {
        var burn = Self.panel(totalMegabytes: 100)
        burn.receive("Track 04:  96 of  96 MB written (fifo 100%) [buf  97%]  8.0x.", at: 100)
        #expect(burn.phase == .write)
        #expect(burn.percent == 96)

        burn.tick(at: 102)  // two seconds: not yet.
        #expect(burn.phase == .write)
        burn.tick(at: 103)
        #expect(burn.phase == .tail)
        #expect(burn.percentField == "LEAD-OUT")
        #expect(burn.percent == 100)
        #expect(burn.doneMegabytes == 100)
        #expect(burn.buffer == "--")
        #expect(burn.speed == "--")
        #expect(burn.remainingField == "--:--")
    }

    /// The disc's own percentage has a ceiling below 100 that a disc of many
    /// short tracks never reaches, so the last track's own progress is the other
    /// reading — and it is the one that saves that disc.
    @Test("A disc held under 95% by its rounding still finds its lead-out")
    func leadOutOnTheLastTrack() {
        var burn = BurnPanel(
            disc: 1, of: 1, titles: Self.titles, durations: Self.durations,
            totalMegabytes: 200)
        // Four short tracks: 44 of 200 megabytes is 22% of the disc.
        for track in 1...4 {
            burn.receive("Track 0\(track):  11 of  11 MB written", at: track)
        }
        #expect(burn.percent == 22)
        #expect(burn.trackPercent == 100)
        burn.tick(at: 10)
        #expect(burn.phase == .tail)
    }

    /// A drive that stalls early in a long last track is on the last track and
    /// nowhere near done, and neither reading calls that a lead-out.
    @Test("A stall in the middle of the last track is not a lead-out")
    func aStallIsNotALeadOut() {
        var burn = Self.panel(totalMegabytes: 200)
        burn.receive("Track 04:   3 of  90 MB written", at: 40)
        burn.tick(at: 60)
        #expect(burn.phase == .write)
        #expect(burn.percentField == "  1%")
    }

    /// Reversible on purpose: a drive that was only pausing takes the panel
    /// straight back to the figures in its next message.
    @Test("The lead-out gives way to the drive speaking again")
    func theLeadOutIsReversible() {
        var burn = Self.panel(totalMegabytes: 100)
        burn.receive("Track 04:  96 of  96 MB written (fifo 100%) [buf  97%]  8.0x.", at: 100)
        burn.tick(at: 104)
        #expect(burn.phase == .tail)
        burn.receive("Track 04:  96 of  96 MB written (fifo 100%) [buf  40%]  8.0x.", at: 110)
        #expect(burn.phase == .write)
        #expect(burn.percent == 96)
        #expect(burn.buffer == "40")
    }

    // MARK: - The clock

    /// Through every silence the clock is the one number that can move, and a
    /// clock that moves is the difference between a drive still working and a
    /// drive that has died.
    @Test("The clock runs on ticks as well as on messages")
    func theClockRunsThroughSilence() {
        var burn = Self.panel()
        burn.tick(at: 41)
        #expect(burn.elapsedField == "0:41")
        burn.tick(at: 221)
        #expect(burn.elapsedField == "3:41")
    }

    /// Under three percent there is not enough of a burn behind us to divide by,
    /// and the estimate then **keeps its last value** rather than blinking back
    /// to dashes, which would read as a drive that had stopped.
    @Test("The estimate waits for three percent and then does not un-say itself")
    func theEstimate() {
        var burn = Self.panel(totalMegabytes: 100)
        burn.receive("Track 01:   1 of  50 MB written", at: 10)
        #expect(burn.remainingField == "--:--")
        // A quarter of the disc in a hundred seconds: three hundred to go.
        burn.receive("Track 01:  25 of  50 MB written", at: 100)
        #expect(burn.remainingField == "5:00")
    }

    /// The lamp keeps its own time, so it is the tick that moves it and nothing
    /// else.
    @Test("The lamp steps once per tick and not once per message")
    func theLampKeepsItsOwnTime() {
        var burn = Self.panel()
        burn.receive("Track 01:   1 of  50 MB written", at: 1)
        burn.receive("Track 01:   3 of  50 MB written", at: 1)
        #expect(burn.frame == 0)
        burn.tick(at: 1)
        #expect(burn.frame == Lamp.step)
    }

    // MARK: - The fields

    @Test("The written line and the track line say what they were told")
    func fields() {
        var burn = Self.panel(totalMegabytes: 806)
        burn.receive("Track 02: 100 of 200 MB written (fifo 100%) [buf  98%]  8.0x.", at: 30)
        #expect(burn.writtenLine == "100 OF 806 MB AT 8.0x")
        #expect(burn.trackLine.hasPrefix("02 OF 04  Reptile Room"))
        #expect(burn.bufferField == "98%")
        #expect(burn.elapsedField == "0:30")
    }

    /// `%3d%%` and not `%d%%`: the rule beside it is sized from what is left, so
    /// a percentage that grew a digit would shorten the rule and shift the header
    /// twice a burn.
    @Test("The percentage keeps its columns")
    func thePercentageIsPadded() {
        var burn = Self.panel(totalMegabytes: 100)
        burn.receive("Track 01:   4 of  50 MB written", at: 1)
        #expect(burn.percentField == "  4%")
        burn.receive("Track 01:  40 of  50 MB written", at: 2)
        #expect(burn.percentField == " 40%")
        for field in ["  4%", " 40%", "LEAD-IN", "LEAD-OUT"] {
            #expect(Columns.width(of: field) <= Columns.width(of: "LEAD-OUT"))
        }
    }

    /// The title is cut to 46 and not to the panel's own 52: the line ahead of it
    /// carries `TRACK`, `01 OF 11` and two gaps.
    @Test("The title is fitted to the room the TRACK line leaves it")
    func theTitleIsFitted() {
        var burn = BurnPanel(
            disc: 1, of: 1,
            titles: ["A Title Considerably Longer Than The Line It Is Being Put On"],
            durations: [200], totalMegabytes: 50)
        burn.receive("Track 01:   1 of  50 MB written", at: 1)
        #expect(Columns.width(of: burn.title) == BurnStage.titleWidth)
        #expect(burn.title.hasPrefix("A Title Considerably"))
    }

    /// `--dummy` changes the verb and nothing else.
    @Test("A rehearsal says it is rehearsing")
    func theRehearsalVerb() {
        let burn = BurnPanel(
            disc: 2, of: 3, titles: Self.titles, durations: Self.durations,
            totalMegabytes: 200, rehearsal: true)
        #expect(burn.verb == "REHEARSING")
        #expect(burn.meta == "REHEARSING · DISC 2 OF 3 · LEAD-IN")
    }

    // MARK: - One instrument

    /// **The plan's meter and the burn's bar are the same two functions.** The
    /// bands are this disc's tracks either way; only the numerator under the head
    /// changes — seconds converted in one, megabytes written in the other. If
    /// this ever stops holding, the two screens have quietly become two pictures.
    @Test("The bar is the plan's meter with a different numerator")
    func oneInstrument() {
        var burn = Self.panel(totalMegabytes: 200)
        burn.receive("Track 02:  50 of 100 MB written", at: 10)

        #expect(burn.bands == Meter.bands(for: Self.durations, cells: PanelGrid.stripWidth))
        let head = Meter.head(done: 50, of: 200)
        #expect(
            burn.cells()
                == Meter.cells(head: head, bands: burn.bands, width: PanelGrid.stripWidth))
        // And the conversion, at the same point of the same disc, draws the same
        // row — which is the whole claim.
        #expect(burn.cells() == BurnStage.cells(head: head, bands: burn.bands))
        #expect(burn.cells().count == PanelGrid.stripWidth)
        #expect(burn.lamp().count == PanelGrid.stripWidth)
    }

    /// The lead-out takes the bar to the end, so the picture agrees with the word
    /// above it.
    @Test("The lead-out's bar has no run-out left in it")
    func theLeadOutFillsTheBar() {
        var burn = Self.panel(totalMegabytes: 100)
        burn.receive("Track 04: 100 of 100 MB written", at: 50)
        burn.tick(at: 60)
        #expect(!burn.cells().contains(.runout))
    }

    // MARK: - The invocation

    /// A missing `-dao` is a disc with two-second gaps mastered into it and a
    /// missing `-text` is a disc with no titles, and both are only discoverable
    /// by playing the coaster you just made. So the vector is a value, and this
    /// reads it back argument by argument.
    @Test("The ordinary burn")
    func theInvocation() {
        let work = URL(filePath: "/tmp/muthur-work")
        let job = Cdrecord.write(
            cue: work.appending(path: "disc1.cue"), device: "IODVDServices/0",
            cdText: true, directory: work)
        #expect(
            job.arguments == [
                "-v", "-dao", "-text", "-eject",
                "dev=IODVDServices/0", "speed=8", "driveropts=burnfree",
                "cuefile=disc1.cue",
            ])
        #expect(job.directory == work)
    }

    /// The cue sheet goes in by bare filename and cdrecord resolves it against
    /// its own working directory, which is why the directory is part of the
    /// value: a path with a space in it never has to reach a shell.
    @Test("The cue sheet is named, not pathed")
    func theCueIsABareName() {
        let work = URL(filePath: "/Users/somebody/Music/A Record (1979)/work")
        let job = Cdrecord.write(
            cue: work.appending(path: "disc2.cue"), device: "IOBDServices/1",
            cdText: false, directory: work)
        #expect(job.arguments.contains("cuefile=disc2.cue"))
        #expect(!job.arguments.contains(where: { $0.contains("/") && $0.hasPrefix("cuefile") }))
        #expect(!job.arguments.contains("-text"))
    }

    /// Ejecting is how the next disc gets asked for — but not when the disc has
    /// to be read back, and not after a rehearsal, whose blank is still blank and
    /// is about to be written for real.
    @Test("The disc is only popped when nothing else wants it")
    func ejecting() {
        let work = URL(filePath: "/tmp/muthur-work")
        func arguments(rehearsal: Bool, verify: Bool) -> [String] {
            Cdrecord.write(
                cue: work.appending(path: "disc1.cue"), device: "d", cdText: false,
                rehearsal: rehearsal, verify: verify, directory: work
            ).arguments
        }
        #expect(arguments(rehearsal: false, verify: false).contains("-eject"))
        #expect(!arguments(rehearsal: true, verify: false).contains("-eject"))
        #expect(!arguments(rehearsal: false, verify: true).contains("-eject"))
        #expect(arguments(rehearsal: true, verify: false).contains("-dummy"))
    }

    @Test("The speed is the one that was asked for")
    func theSpeed() {
        let work = URL(filePath: "/tmp/w")
        let job = Cdrecord.write(
            cue: work.appending(path: "d.cue"), device: "d", speed: 16, cdText: false,
            directory: work)
        #expect(job.arguments.contains("speed=16"))
    }

    // MARK: - The environment

    /// D74 — junk falls back and says so, where the script dies. An app read its
    /// environment at launch, from whatever launched it; there is no line to
    /// retype, and refusing to burn is the worse answer.
    @Test("A speed that is not a whole number falls back and is written down")
    func theSpeedFallsBack() {
        #expect(Cdrecord.speed([:]).speed == 8)
        #expect(Cdrecord.speed([:]).note == nil)
        #expect(Cdrecord.speed(["MUTHUR_SPEED": "16"]) == (16, nil))
        #expect(Cdrecord.speed(["BURNCD_SPEED": "4"]) == (4, nil))
        // Its own name wins where both are set, the way every other pair does.
        #expect(Cdrecord.speed(["MUTHUR_SPEED": "24", "BURNCD_SPEED": "4"]).speed == 24)

        for junk in ["8x", "-8", "8.0", "fast", "0"] {
            let read = Cdrecord.speed(["MUTHUR_SPEED": junk])
            #expect(read.speed == Cdrecord.defaultSpeed)
            #expect(read.note?.contains(junk) == true, "the note does not name \(junk)")
        }
    }

    /// A hand-set device is never second-guessed — its failure is reported
    /// against the name that was asked for, not against a name we substituted.
    @Test("BURNCD_DEV names the same drive MUTHUR_DEV does")
    func theDevice() {
        #expect(OpticalDrive.detect(environment: ["MUTHUR_DEV": "IOBDServices/1"]).device
            == "IOBDServices/1")
        #expect(OpticalDrive.detect(environment: ["BURNCD_DEV": "IOBDServices/1"]).device
            == "IOBDServices/1")
        let both = OpticalDrive.detect(
            environment: ["MUTHUR_DEV": "IODVDServices/1", "BURNCD_DEV": "IOBDServices/0"])
        #expect(both.device == "IODVDServices/1")
        #expect(both.answered)
        // An empty export is not a device, and must not stop the probe.
        #expect(OpticalDrive.detect(override: "IOCompactDiscServices/0", environment: [:]).device
            == "IOCompactDiscServices/0")
    }

    // MARK: - End to end

    /// The stand-in's schedule: the two silences either side, a line every
    /// thirtieth of a second between them, and every track closed on its own
    /// stated size.
    @Test("The stand-in is shaped like a burn")
    func theSchedule() {
        let messages = FakeDrive.messages(tracks: 4)
        #expect(messages.first?.at == FakeDrive.leadIn)
        #expect(messages.first?.text.hasPrefix("Track 01:    0 of   55 MB") == true)
        // 0, 2 … 54 is twenty-eight, plus the closing line.
        #expect(messages.count == 4 * 29)
        for track in 1...4 {
            let closing = messages.last { BurnPanel.parse($0.text)?.track == track }
            let progress = BurnPanel.parse(closing?.text ?? "")
            #expect(progress?.done == FakeDrive.megabytesPerTrack)
            #expect(progress?.total == FakeDrive.megabytesPerTrack)
        }
        // A megabyte a track more than the tracks add up to: the arrears a real
        // burn has and a tidy stand-in would not.
        #expect(FakeDrive.totalMegabytes(tracks: 4) == 224)
        #expect(FakeDrive.totalMegabytes(tracks: 4) > 4 * FakeDrive.megabytesPerTrack)
    }

    /// **The whole panel and the whole pipeline, end to end.** Every frame of a
    /// burn, through the real parser and the real phase machine, with the drive
    /// taken out and nothing else changed.
    @Test("A whole burn, driven by the stand-in")
    func endToEnd() {
        var phases: [BurnPanel.Phase] = []
        var lastPercent = 0
        var monotonic = true
        var frames = 0

        let burn = FakeDrive.play(titles: Self.titles, durations: Self.durations) { panel in
            frames += 1
            if phases.last != panel.phase { phases.append(panel.phase) }
            // The bar never runs backwards, in any phase — which is the failure
            // the clamp and the stated-size total exist to prevent.
            if panel.percent < lastPercent { monotonic = false }
            lastPercent = panel.percent
            #expect(panel.cells().count == PanelGrid.stripWidth)
        }

        #expect(monotonic)
        // Lead-in, writing, lead-out, in that order and once each.
        #expect(phases == [.lead, .write, .tail])
        #expect(frames > 0)

        #expect(burn.phase == .tail)
        #expect(burn.percent == 100)
        #expect(burn.percentField == "LEAD-OUT")
        #expect(burn.doneMegabytes == burn.totalMegabytes)
        #expect(burn.track == Self.titles.count)
        #expect(burn.buffer == "--")
        #expect(!burn.cells().contains(.runout))
        // The lead-in and the lead-out are seconds of real silence, so the clock
        // has to have covered both.
        #expect(burn.elapsed >= Int(FakeDrive.leadIn + FakeDrive.leadOut))
    }

    /// The disc's own percentage never reaches 100 on the way — the arrears see
    /// to that — so it is the lead-out that closes the gap, which is what the
    /// lead-out is for.
    @Test("The stand-in's disc comes up short until the lead-out closes it")
    func theArrearsAreReal() {
        var highestWhileWriting = 0
        let burn = FakeDrive.play(titles: Self.titles, durations: Self.durations) { panel in
            if panel.phase == .write { highestWhileWriting = max(highestWhileWriting, panel.percent) }
        }
        #expect(highestWhileWriting < 100)
        #expect(highestWhileWriting >= BurnPanel.tailPercent)
        #expect(burn.percent == 100)
    }

    /// A one-track disc is the shortest burn there is, and its lead-out is found
    /// on the track's own reading rather than the disc's.
    @Test("One track is still a burn")
    func oneTrack() {
        let burn = FakeDrive.play(titles: ["Solo"], durations: [400])
        #expect(burn.phase == .tail)
        #expect(burn.track == 1)
        #expect(burn.trackLine.hasPrefix("01 OF 01  Solo"))
    }
}
