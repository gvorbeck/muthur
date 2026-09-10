import Foundation
import Testing

@testable import MUTHURKit

/// §20 stage 3b — the look at the blank (`media_check`, `burncd:2257`).
///
/// Every captured string below came off the drive in §19: a MATSHITA DVD-RAM
/// UJ8E2 S with a CMC Magnetics CD-R in it. The point of the `Probes` seam is
/// that the branches the drive cannot be made to take on demand — an empty tray
/// mid-loop, a CD-RW, a drive that will not give up its ATIP — are reachable
/// here anyway, and are the branches that decide whether a blank is spent.
@Suite("§20 The look at the blank")
struct MediaCheckTests {

    // MARK: - What the drive actually said

    /// `drutil status`, verbatim, blank CD-R in the tray.
    static let blankStatus = """
         Vendor   Product           Rev\u{20}
         MATSHITA DVD-RAM UJ8E2 S   1.00

                   Type: CD-R                 Name: /dev/disk7
           Write Speeds: 8x, 24x
           Overwritable:   79:57:69         blocks:   359844 / 736.96MB / 702.82MiB
             Space Free:   79:57:69         blocks:   359844 / 736.96MB / 702.82MiB
             Space Used:   00:00:00         blocks:        0 /   0.00MB /   0.00MiB
            Writability: appendable, blank, overwritable

        """

    /// The same drive with nothing in it. `drutil` still prints a perfectly good
    /// `Type:` line, which is exactly why `no media` is tested before the field
    /// is parsed — §11 learned that once already (`burncd:319`).
    static let emptyStatus = """
         Vendor   Product           Rev\u{20}
         MATSHITA DVD-RAM UJ8E2 S   1.00

                   Type: No Media Inserted

        """

    /// A written disc: a CD-ROM, and nowhere in it the word `blank`.
    static let burntStatus = """
         Vendor   Product           Rev\u{20}
         MATSHITA DVD-RAM UJ8E2 S   1.00

                   Type: CD-ROM               Name: /dev/disk7
            Writability:

        """

    /// `cdrecord -atip dev=IODVDServices/0`, verbatim, trimmed to the block that
    /// matters — including the `lead in` line above it, which is the one thing
    /// the parse must not read. The six privilege warnings and the drive
    /// inventory above it are dropped only for length; nothing in them carries
    /// the phrase.
    static let atipCapture = """
        ATIP info from disk:
          Indicated writing power: 5
        Disk Is not unrestricted
        Disk Is not erasable
          Disk sub type: Medium Type A, high Beta category (A+) (3)
          ATIP start of lead in:  -11634 (97:26/66)
          ATIP start of lead out: 359846 (79:59/71)
        Disk type:    Short strategy type (Phthalocyanine or similar)
        Manuf. index: 3
        Manufacturer: CMC Magnetics Corporation
        """

    /// What the drive says when it has been asked something else a moment ago:
    /// everything it knows about itself and nothing about the disc.
    static let atipSilent = """
        cdrecord: No disk / Wrong disk!
        """

    // MARK: - The seam

    /// A machine with a blank in it, so a test only has to say what is different
    /// about the one it means. `pause` spends nothing and counts instead — the
    /// second between readings is the script's, and a suite that actually slept
    /// it would cost four seconds a run for nothing.
    ///
    /// `release` is stubbed for the same reason and a sharper one: its default
    /// runs `diskutil unmount` against whatever is really in this machine's
    /// drive, and a unit test is not allowed to take somebody's disc away.
    static func check(
        enabled: Bool = true,
        hasDrutil: Bool = true,
        drutil: [String?] = [blankStatus],
        atip: [String?] = [atipCapture],
        pauses: Counter = Counter(),
        releases: Counter = Counter()
    ) -> MediaCheck {
        let drutilAnswers = Answers(drutil)
        let atipAnswers = Answers(atip)
        return MediaCheck(
            enabled: enabled,
            probes: MediaCheck.Probes(
                hasDrutil: { hasDrutil },
                drutil: { drutilAnswers.next() },
                atip: { _ in atipAnswers.next() },
                pause: { _ in pauses.bump() },
                release: { releases.bump() }
            )
        )
    }

    /// One answer per call, the last one repeating — a drive does not run out of
    /// opinions, it just keeps giving the same one.
    final class Answers: @unchecked Sendable {
        private let values: [String?]
        private var index = 0
        private let lock = NSLock()
        init(_ values: [String?]) { self.values = values }
        func next() -> String? {
            lock.lock()
            defer { lock.unlock() }
            let value = values[min(index, values.count - 1)]
            index += 1
            return value
        }
        var asked: Int { lock.withLock { index } }
    }

    final class Counter: @unchecked Sendable {
        private var value = 0
        private let lock = NSLock()
        func bump() { lock.withLock { value += 1 } }
        var count: Int { lock.withLock { value } }
    }

    // MARK: - Reading what the drive said

    @Test("The captured blank reads as media, and as blank")
    func realCaptureParses() {
        #expect(!MediaCheck.saysNoMedia(Self.blankStatus))
        #expect(MediaCheck.saysBlank(Self.blankStatus))
        #expect(Diagnostics.mediaType(Self.blankStatus) == "CD-R")

        #expect(MediaCheck.saysNoMedia(Self.emptyStatus))
        #expect(!MediaCheck.saysNoMedia(Self.burntStatus))
        #expect(!MediaCheck.saysBlank(Self.burntStatus))
        #expect(Diagnostics.mediaType(Self.burntStatus) == "CD-ROM")
    }

    /// A `drutil` that could not be run counts as saying nothing, which keeps
    /// the loop going rather than being mistaken for a disc.
    @Test("Nothing at all is not a disc")
    func nilStatusIsNoMedia() {
        #expect(MediaCheck.saysNoMedia(nil))
    }

    /// The number the whole check turns on, off the real capture — and the
    /// sanity signal the script names: 359846 over 75 is 4797, which is the
    /// default capacity exactly.
    @Test("The lead-out off the real ATIP is the capacity the plan assumes")
    func leadOutOffTheRealCapture() {
        #expect(MediaCheck.leadOut(Self.atipCapture) == 359_846)
        #expect(359_846 / BurnLimits.framesPerSecond == BurnLimits.capacity)
    }

    /// `lead in` sits on the line above and carries a negative number. Reading
    /// it would make an 80-minute blank look like a disc that ends before it
    /// starts, and the refusal would name a duration nobody could act on.
    @Test("The lead-in above it is a different phrase")
    func leadInIsNotLeadOut() {
        #expect(MediaCheck.leadOut("  ATIP start of lead in:  -11634 (97:26/66)") == nil)
    }

    @Test("A drive with nothing to say about the lead-out says nothing")
    func silentAtip() {
        #expect(MediaCheck.leadOut(Self.atipSilent) == nil)
        #expect(MediaCheck.leadOut("") == nil)
    }

    // MARK: - The empty tray

    /// The drive has to say it is empty three times before it is believed, with
    /// a second between each — because the ATIP read that ran a moment ago is an
    /// exclusive open, and for as long as that lasts macOS reports `No Media
    /// Inserted` about a disc that never moved (`burncd:278`). Getting this
    /// wrong tells the operator the tray is empty while they are looking
    /// straight at the disc in it.
    @Test("An empty drive has to say so more than once")
    func emptyDriveIsAskedAgain() {
        let pauses = Counter()
        var media = Self.check(drutil: [Self.emptyStatus], pauses: pauses)
        let verdict = media.look(disc: 1, want: 2400, device: "IODVDServices/0")

        #expect(verdict == .swap(note: "! The drive is empty — put a blank CD-R in it and press ⏎ again"))
        // Three readings, two waits: `tries` starts at zero and stops at two, so
        // the third answer is taken and believed.
        #expect(pauses.count == MediaCheck.readings - 1)
    }

    /// The disowned disc: the first reading is taken while the drive is still
    /// letting go of media that never moved, the second is the truth.
    @Test("A disc the drive is still disowning is found on the second ask")
    func disownedDiscIsFoundAgain() {
        let pauses = Counter()
        var media = Self.check(
            drutil: [Self.emptyStatus, Self.blankStatus], pauses: pauses)

        #expect(media.look(disc: 1, want: 2400, device: "IODVDServices/0") == .go(note: nil))
        #expect(pauses.count == 1)
    }

    // MARK: - The wrong disc

    /// Refused by its own type name, because that is the only word the operator
    /// can act on: "that CD-RW" and "that DVD-R" are two different mistakes with
    /// two different discs to go and find.
    @Test("A disc that is not blank is refused by its type name")
    func notBlankIsRefusedByName() {
        var media = Self.check(drutil: [Self.burntStatus])
        let verdict = media.look(disc: 1, want: 2400, device: "IODVDServices/0")

        #expect(
            verdict
                == .swap(
                    note: "! That CD-ROM is not blank — MU/TH/UR writes blanks only. "
                        + "Swap it and press ⏎ again"))
    }

    /// A `Type:` line the parse cannot make a word of still refuses, and still
    /// reads as English — the script's `${mtype:-disc}`.
    @Test("A disc with no type name is still refused")
    func unnamedTypeStillRefused() {
        var media = Self.check(drutil: ["  Writability: appendable\n"])
        #expect(
            media.look(disc: 1, want: 2400, device: "IODVDServices/0").note?
                .contains("That disc is not blank") == true)
    }

    // MARK: - Where drutil is not the authority

    /// No drive visible to `drutil` at all. cdrecord is the authority anyway, and
    /// refusing here would refuse every machine whose drive `drutil` does not
    /// enumerate.
    @Test("A drutil that lists no drive is not a refusal")
    func emptyDrutilFallsThrough() {
        var media = Self.check(drutil: [""])
        #expect(media.look(disc: 1, want: 2400, device: "IODVDServices/0") == .go(note: nil))

        var missing = Self.check(drutil: [nil, nil, nil])
        // Nil reads as `no media` and is asked again, but an answer that never
        // arrives is not a disc that is absent — the loop ends and the ATIP read
        // decides.
        #expect(missing.look(disc: 1, want: 2400, device: "IODVDServices/0") == .go(note: nil))
    }

    /// A machine without `drutil` skips straight to the ATIP read, which is the
    /// script's own shape: `drutil` is wrapped in `command -v` and `cdrecord` is
    /// not.
    @Test("Without drutil the ATIP read is the whole check")
    func noDrutilGoesStraightToAtip() {
        var media = Self.check(hasDrutil: false, drutil: [Self.emptyStatus])
        #expect(media.look(disc: 1, want: 2400, device: "IODVDServices/0") == .go(note: nil))
    }

    // MARK: - The ATIP

    /// A drive that has been sitting idle answers the first request with
    /// everything it knows about itself and nothing about the disc, and is
    /// forthcoming a second later. Taking the first answer at face value would
    /// put "could not read the capacity" in front of half the burns on this
    /// machine.
    @Test("The ATIP is asked up to three times")
    func atipIsAskedAgain() {
        let pauses = Counter()
        var media = Self.check(
            atip: [Self.atipSilent, Self.atipSilent, Self.atipCapture], pauses: pauses)

        #expect(media.look(disc: 1, want: 2400, device: "IODVDServices/0") == .go(note: nil))
        #expect(pauses.count == MediaCheck.readings - 1)
    }

    /// A false negative that blocks a good burn is worse than the problem being
    /// solved, so an unreadable ATIP goes ahead — and says so once for the whole
    /// job, not once per disc, because a drive that cannot read one disc's ATIP
    /// will not read the next one's either.
    @Test("An unreadable ATIP proceeds on trust, and warns once")
    func unreadableAtipWarnsOnce() {
        var media = Self.check(atip: [Self.atipSilent])

        let first = media.look(disc: 1, want: 2400, device: "IODVDServices/0")
        #expect(first.isGo)
        #expect(
            first.note
                == "! Could not read the disc's capacity from its ATIP; going ahead on trust")
        #expect(media.atipWarned)

        let second = media.look(disc: 2, want: 2400, device: "IODVDServices/0")
        #expect(second == .go(note: nil))
    }

    // MARK: - The size of it

    /// The refusal that pays for the whole check: minutes of converting not
    /// spent on an image the disc cannot hold. Both durations, so the operator
    /// knows how far off it is, and the remedy — which names a variable this
    /// port actually reads (D75).
    @Test("A blank too small for the disc is refused with both durations")
    func tooSmallIsRefused() {
        // A 74-minute blank: 333,000 sectors, 4440 seconds.
        var media = Self.check(
            atip: ["  ATIP start of lead out: 333000 (74:00/00)"])
        let verdict = media.look(disc: 2, want: 4700, device: "IODVDServices/0")

        #expect(
            verdict
                == .swap(
                    note: "! This blank holds 74:00 and disc 2 is 78:20. "
                        + "Use an 80-minute disc, or set MUTHUR_MINUTES and start again"))
        #expect(BurnLimits.capacity(["MUTHUR_MINUTES": "74"]).seconds == 4440)
    }

    /// A blank exactly as long as the disc is not too small. The script's test is
    /// `-lt`, and a record that fills the disc to the second is the normal
    /// outcome of a plan cut against that disc.
    @Test("A blank exactly the length of the disc goes ahead")
    func exactFitGoesAhead() {
        var media = Self.check()
        #expect(media.look(disc: 1, want: 4797, device: "IODVDServices/0") == .go(note: nil))
    }

    /// A longer blank than the plan assumed is not a problem, only a waste: the
    /// layout is fixed by now, and renumbering discs under a job already in
    /// progress is the thing `--from-disc` exists to avoid.
    @Test("A blank longer than the plan says so and goes ahead")
    func oversizedBlankIsANote() {
        // A 90-minute blank against a plan cut for 74 minutes.
        var media = Self.check(atip: ["  ATIP start of lead out: 405000 (90:00/00)"])
        let verdict = media.look(
            disc: 1, want: 4000, capacity: 4440, device: "IODVDServices/0")

        #expect(
            verdict
                == .go(
                    note: "! This blank holds 90:00, more than the 74:00 planned for "
                        + "— MUTHUR_MINUTES would use all of it"))
    }

    /// The minute of slack: a blank inside a minute of the planned capacity is
    /// the ordinary case and says nothing at all.
    @Test("A minute of slack is not worth mentioning")
    func slackIsSilent() {
        var media = Self.check()
        #expect(
            media.look(disc: 1, want: 2400, capacity: 4797 - 60, device: "IODVDServices/0")
                == .go(note: nil))
    }

    // MARK: - The drive that lies

    @Test("BURNCD_NO_MEDIA_CHECK switches it off, under either name")
    func theEnvironmentCanSwitchItOff() {
        #expect(MediaCheck.enabled([:]))
        #expect(!MediaCheck.enabled(["BURNCD_NO_MEDIA_CHECK": "1"]))
        #expect(!MediaCheck.enabled(["MUTHUR_NO_MEDIA_CHECK": "yes"]))
        // `[ -n … ]`: set to anything, and an empty string is not anything.
        #expect(MediaCheck.enabled(["BURNCD_NO_MEDIA_CHECK": ""]))
    }

    /// Switched off means switched off — not one probe, not one second. It
    /// exists for the drive whose reporting lies, and a drive that lies is not
    /// improved by being asked politely.
    @Test("Switched off, the drive is not asked anything")
    func disabledAsksNothing() {
        let pauses = Counter()
        let releases = Counter()
        let drutil = Answers([Self.emptyStatus])
        var media = MediaCheck(
            enabled: false,
            probes: MediaCheck.Probes(
                hasDrutil: { true },
                drutil: { drutil.next() },
                atip: { _ in nil },
                pause: { _ in pauses.bump() },
                release: { releases.bump() }
            )
        )

        #expect(media.look(disc: 1, want: 2400, device: "IODVDServices/0") == .go(note: nil))
        #expect(drutil.asked == 0)
        #expect(pauses.count == 0)
        // Including the unmount: a check that is off must not take the drive off
        // macOS on its way past doing nothing.
        #expect(releases.count == 0)
    }

    /// The failure this exists to stop, in the order it happens: something
    /// writes the disc, macOS mounts the table of contents that left behind, and
    /// the next ATIP read is an exclusive open against a mounted device.
    /// cdrecord prints its `diskarbitrationd` warning, the capacity comes back
    /// unknown, and the check's answer to a drive that will not say is *go ahead
    /// on trust* — so the capacity check is off for the rest of the session and
    /// nothing says so (**D77**). Both halves were watched happen on this
    /// machine, with `mount` and `cdrecord -atip` at a prompt.
    @Test("The drive is taken off macOS before the ATIP is read")
    func releasesTheDriveBeforeReadingATIP() {
        let releases = Counter()
        var media = Self.check(releases: releases)

        let verdict = media.look(disc: 1, want: 2400, device: "IODVDServices/0")

        #expect(verdict.isGo)
        #expect(releases.count == 1)
    }

    /// `drutil status` is not an exclusive open — it answered from a mounted
    /// drive on this machine while `cdrecord -atip` would not — so a disc the
    /// drive has already refused costs no unmount at all.
    @Test("A disc drutil refuses outright is refused without touching the mounts")
    func doesNotReleaseWhenDrutilAlreadyDecided() {
        let releases = Counter()
        var media = Self.check(drutil: [Self.burntStatus], releases: releases)

        #expect(!media.look(disc: 1, want: 2400, device: "IODVDServices/0").isGo)
        #expect(releases.count == 0)
    }

    // MARK: - Against the drive itself (§19)

    /// The two states no capture can stand in for, run with the real probes on
    /// the real drive — because every string above is one this port *believes*
    /// the drive prints, and the whole point of §19 is that believing is not
    /// knowing. `docs/hardware.md` step 14 is the procedure; both are
    /// `.enabled(if:)` so a clone with no drive stays green.
    ///
    /// - `MUTHUR_TEST_BLANK` — set with a blank CD-R in the drive.
    /// - `MUTHUR_TEST_EMPTY` — set with the tray empty.
    static func setting(_ name: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
            return nil
        }
        return value
    }

    @Test(
        "A real blank in the real drive is taken", .timeLimit(.minutes(1)),
        .enabled(if: MediaCheckTests.setting("MUTHUR_TEST_BLANK") != nil))
    func realBlankIsTaken() {
        var media = MediaCheck(enabled: true)
        let device = OpticalDrive.detect().device
        // A short record, so this is about the disc and not about the plan.
        let verdict = media.look(disc: 1, want: 600, device: device)

        #expect(verdict.isGo)
        // Silent is the right answer for a standard blank under a standard plan:
        // the ATIP warning would mean the drive would not say, and the oversize
        // note would mean this is not the disc the port thinks it is.
        #expect(verdict.note == nil)
        #expect(!media.atipWarned)
    }

    @Test(
        "A real empty tray is refused, and asked more than once",
        .timeLimit(.minutes(1)),
        .enabled(if: MediaCheckTests.setting("MUTHUR_TEST_EMPTY") != nil))
    func realEmptyTrayIsRefused() {
        var media = MediaCheck(enabled: true)
        let verdict = media.look(
            disc: 1, want: 600, device: OpticalDrive.detect().device)

        #expect(
            verdict == .swap(note: "! The drive is empty — put a blank CD-R in it and press ⏎ again")
        )
    }
}
