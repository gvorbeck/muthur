import Foundation
import Testing

@testable import MUTHURKit

/// §20 stage 3b — `--verify`, without a disc (`verify_disc`, `burncd:2195`).
///
/// The material tier is in `BurnMaterialTests`, where a real drive reads a real
/// disc back. What is here is everything that decision is made *of*: counting
/// tracks out of a listing, telling a bad disc from a busy one, and the three
/// asymmetries the script is careful about — a missing `cdda2wav` that does not
/// fail the disc, a CD-Text field that does not fail the disc, and a sector the
/// drive could not read that does.
///
/// Every capture below came off the drive in this building.
@Suite("§20 Reading the disc back")
struct DiscVerifyTests {

    // MARK: - What the drive actually said

    /// `cdrecord -toc dev=IODVDServices/0` against the disc §20 burnt, unmounted.
    /// Thirteen tracks and a lead-out, which is what step 4 of §19 captured.
    static let thirteenTracks = """
        Cdrecord-ProDVD-ProBD-Clone 3.02a09 (x86_64-apple-darwin24.6.0) Copyright (C) 1995-2019 Joerg Schilling
        scsidev: 'IODVDServices/0'
        Using libscg version 'schily-0.9'.
        first: 1 last 13
        track:   1 lba:         0 (       0) 00:02:00 adr: 1 control: 0 mode: -1
        track:   2 lba:     15547 (   62188) 03:29:22 adr: 1 control: 0 mode: -1
        track:   3 lba:     33163 (  132652) 07:24:13 adr: 1 control: 0 mode: -1
        track:   4 lba:     50390 (  201560) 11:13:65 adr: 1 control: 0 mode: -1
        track:   5 lba:     69072 (  276288) 15:23:72 adr: 1 control: 0 mode: -1
        track:   6 lba:     87335 (  349340) 19:27:35 adr: 1 control: 0 mode: -1
        track:   7 lba:    106404 (  425616) 23:41:54 adr: 1 control: 0 mode: -1
        track:   8 lba:    123561 (  494244) 27:30:36 adr: 1 control: 0 mode: -1
        track:   9 lba:    142862 (  571448) 31:47:62 adr: 1 control: 0 mode: -1
        track:  10 lba:    161038 (  644152) 35:50:13 adr: 1 control: 0 mode: -1
        track:  11 lba:    180633 (  722532) 40:11:33 adr: 1 control: 0 mode: -1
        track:  12 lba:    200295 (  801180) 44:33:45 adr: 1 control: 0 mode: -1
        track:  13 lba:    221390 (  885560) 49:14:65 adr: 1 control: 0 mode: -1
        track:lout lba:    265318 ( 1061272) 59:00:43 adr: 1 control: 0 mode: -1
        """

    /// The same command against the same disc while macOS had it mounted, which
    /// on macOS is an audio CD's normal state. This is what a verify sees if the
    /// unmount was refused (D77, §19 step 4).
    static let refused = """
        Cdrecord-ProDVD-ProBD-Clone 3.02a09 (x86_64-apple-darwin24.6.0) Copyright (C) 1995-2019 Joerg Schilling
        scsidev: 'IODVDServices/0'
        Warning, 'diskarbitrationd' is running and does not allow us to
        send SCSI commands to the drive.
        cdrecord: No such file or directory. Unable to get exclusive access to device.
        """

    // MARK: - Counting the listing

    @Test("Thirteen track lines are thirteen tracks, and the lead-out is not one")
    func countsTheTracks() {
        #expect(DiscVerify.trackCount(Self.thirteenTracks) == 13)
    }

    /// `grep -c` over a capture with no listing in it is zero, and zero is the
    /// number of tracks a disc that would not open reports.
    @Test("A refused open counts as no tracks at all")
    func countsNothingOnARefusal() {
        #expect(DiscVerify.trackCount(Self.refused) == 0)
    }

    /// The anchor is `^track:`, so a line that merely says the word does not
    /// count — and the lead-out is excluded by its `l` rather than by name.
    @Test("Only lines that begin track: and go on to a digit are counted")
    func countsOnlyTheListing() {
        let noise = """
            reading track: 4
            track:lout lba:    265318 ( 1061272) 59:00:43 adr: 1 control: 0 mode: -1
            track:   1 lba:         0 (       0) 00:02:00 adr: 1 control: 0 mode: -1
              track:   2 lba:     15547 (   62188) 03:29:22 adr: 1 control: 0 mode: -1
            """
        // The indented line goes too: `grep '^track:'` is anchored, and a port
        // that trimmed first would be reading a shape the tool never promised.
        #expect(DiscVerify.trackCount(noise) == 1)
    }

    // MARK: - Telling a bad disc from a busy one

    @Test("The daemon's refusal is recognised in both of the phrases it prints")
    func spotsTheRefusal() {
        #expect(DiscVerify.refusedTheOpen(Self.refused))
        #expect(DiscVerify.refusedTheOpen("cdda2wav: Unable to get exclusive access to device."))
        #expect(!DiscVerify.refusedTheOpen(Self.thirteenTracks))
    }

    /// The message a verify gives when its own unmount was dissented — by this
    /// app, playing the disc it just burnt, which is the likeliest way to meet
    /// it (§19 step 4).
    @Test("A disc macOS still holds is reported as the drive, not as a bad burn")
    func saysWhyRatherThanBlamingTheDisc() {
        let report = Self.verifier(toc: Self.refused).look(
            disc: 1, want: 13, device: "IODVDServices/0", album: "", cdText: false,
            log: Self.scratch())

        #expect(!report.passed)
        #expect(report.notes.contains { $0.contains("would not open") })
        #expect(report.notes.contains { $0.contains("Stop playing it") })
        // The count is *not* said, because saying `disc reports 0` about a disc
        // nothing looked at is the one wrong answer available here.
        #expect(!report.notes.contains { $0.contains("disc reports") })
    }

    // MARK: - The three checks

    @Test("A sound disc passes on all three and says so once each")
    func passesASoundDisc() {
        let report = Self.verifier(
            toc: Self.thirteenTracks, status: 0, titles: "Album title: 'Slippery When Wet'"
        ).look(
            disc: 1, want: 13, device: "IODVDServices/0", album: "Slippery When Wet",
            cdText: true, log: Self.scratch())

        #expect(report.passed)
        #expect(report.notes.first == "VERIFYING disc 1...")
        #expect(report.notes.contains("  ✓ table of contents — 13 tracks"))
        #expect(report.notes.contains("  ✓ full read — every sector came back"))
        #expect(report.notes.contains("  ✓ CD-Text — album title reads back"))
    }

    @Test("A disc with the wrong number of tracks fails, and both numbers are said")
    func failsAShortTOC() {
        let report = Self.verifier(toc: Self.thirteenTracks, status: 0).look(
            disc: 2, want: 12, device: "IODVDServices/0", album: "", cdText: false,
            log: Self.scratch())

        #expect(!report.passed)
        #expect(report.notes.contains { $0.contains("expected 12 tracks, disc reports 13") })
    }

    /// The check that is the point of the flag: a sector the drive cannot get
    /// through is a disc that will stop mid-record, and the drive's own
    /// complaint is the only place the reason is written down.
    @Test("A read error fails the disc and the drive's last words come with it")
    func failsAnUnreadableDisc() throws {
        let log = Self.scratch()
        try """
            cdda2wav: Input/output error. read_g1: scsi sendcmd: retryable error
            CDB:  BE 04 00 01 5A 3F 00 00 1B 10 00 00
            cdda2wav: Cannot read sector 88639
            """.write(to: log, atomically: true, encoding: .isoLatin1)

        let report = Self.verifier(toc: Self.thirteenTracks, status: 1).look(
            disc: 1, want: 13, device: "IODVDServices/0", album: "", cdText: false, log: log)

        #expect(!report.passed)
        #expect(report.notes.contains { $0.contains("full read failed (exit 1)") })
        #expect(report.notes.contains { $0.contains("Cannot read sector 88639") })
        // Indented under the failure, so the complaint reads as part of it
        // rather than as the next thing that happened.
        #expect(report.notes.contains { $0.hasPrefix("      cdda2wav:") })
    }

    /// **Never fails the disc** (`burncd:2231`). `-J` asks for information only,
    /// and a field that did not come back is not proof it is missing — which is
    /// truer here than the script knew, since on this machine `-J` cannot open a
    /// mounted disc at all.
    @Test("CD-Text that does not read back warns and passes")
    func warnsAboutCDTextAndPassesAnyway() {
        let report = Self.verifier(
            toc: Self.thirteenTracks, status: 0, titles: "no CD-Text information"
        ).look(
            disc: 1, want: 13, device: "IODVDServices/0", album: "Slippery When Wet",
            cdText: true, log: Self.scratch())

        #expect(report.passed)
        #expect(report.notes.contains { $0.contains("! CD-Text") })
        #expect(report.notes.contains { $0.contains("check on a player") })
    }

    /// A disc whose lead-in was written without text has no text to read back,
    /// so nothing is said about it at all — asking would warn about a disc that
    /// is exactly as intended.
    @Test("A disc written without CD-Text is not asked about it")
    func saysNothingWhereNothingWasWritten() {
        let report = Self.verifier(toc: Self.thirteenTracks, status: 0).look(
            disc: 1, want: 13, device: "IODVDServices/0", album: "Slippery When Wet",
            cdText: false, log: Self.scratch())

        #expect(report.passed)
        #expect(!report.notes.contains { $0.contains("CD-Text") })
    }

    /// The other half of that: `--no-cdtext` is off but the ladder shed the
    /// album title down to nothing, so there is no string to look for.
    @Test("An empty album title is not looked for")
    func saysNothingWithoutATitle() {
        let report = Self.verifier(toc: Self.thirteenTracks, status: 0).look(
            disc: 1, want: 13, device: "IODVDServices/0", album: "", cdText: true,
            log: Self.scratch())

        #expect(!report.notes.contains { $0.contains("CD-Text") })
    }

    /// `command -v cdda2wav` failing downgrades the verify rather than failing
    /// the disc: a TOC that was checked is worth more than a refusal to answer
    /// (`burncd:2241`).
    @Test("No cdda2wav means the TOC was checked and the sectors were not")
    func downgradesWithoutCdda2wav() {
        var probes = Self.probes(toc: Self.thirteenTracks)
        probes.hasCdda2wav = { false }
        let report = DiscVerify(probes: probes).look(
            disc: 1, want: 13, device: "IODVDServices/0", album: "Slippery When Wet",
            cdText: true, log: Self.scratch())

        #expect(report.passed)
        #expect(report.notes.contains { $0.contains("cdda2wav not installed") })
        #expect(!report.notes.contains { $0.contains("full read") })
        // And it does not go on to ask about CD-Text with the tool it just said
        // it does not have.
        #expect(!report.notes.contains { $0.contains("CD-Text") })
    }

    /// `command -v` said yes and the spawn failed anyway. The script has no
    /// branch for it because a shell hands back 127 and fails the disc, which is
    /// what this does — under its own sentence, so nobody goes looking for a
    /// read error that never happened.
    @Test("A cdda2wav that will not run fails the disc and says so")
    func failsWhenTheToolWillNotRun() {
        var probes = Self.probes(toc: Self.thirteenTracks)
        probes.read = { _, _, _ in nil }
        let report = DiscVerify(probes: probes).look(
            disc: 1, want: 13, device: "IODVDServices/0", album: "", cdText: false,
            log: Self.scratch())

        #expect(!report.passed)
        #expect(report.notes.contains { $0.contains("would not run") })
    }

    // MARK: - The drive, before either tool touches it

    /// D77, and it is the difference between a verify and a false alarm: the
    /// disc a verify reads is one `cdrecord` has just written, which is one
    /// macOS has just mounted.
    @Test("The drive is taken off macOS before anything opens it")
    func releasesTheDriveFirst() {
        let watched = Watched()
        var probes = Self.probes(toc: Self.thirteenTracks)
        probes.release = { watched.order.append("release") }
        probes.toc = { _ in
            watched.order.append("toc")
            return Self.thirteenTracks
        }
        probes.read = { _, _, _ in
            watched.order.append("read")
            return 0
        }
        _ = DiscVerify(probes: probes).look(
            disc: 1, want: 13, device: "IODVDServices/0", album: "", cdText: false,
            log: Self.scratch())

        #expect(watched.order == ["release", "toc", "read"])
    }

    // MARK: - The log

    @Test("The tail is the last six lines with the blanks taken out")
    func tailsTheLog() throws {
        let log = Self.scratch()
        try (1...10).map { "line \($0)" }.joined(separator: "\n\n")
            .write(to: log, atomically: true, encoding: .isoLatin1)
        #expect(DiscVerify.tail(of: log) == (5...10).map { "line \($0)" })
    }

    /// A log that was never written is not a crash. cdda2wav failing to start is
    /// exactly the case where there is no file, and the note above it has
    /// already said what happened.
    @Test("A missing log tails to nothing")
    func tailsNothing() {
        #expect(DiscVerify.tail(of: Self.scratch()).isEmpty)
    }

    // MARK: - Where the log goes

    @Test("The log sits beside the image under the disc's number")
    func namesTheLog() {
        let work = URL(fileURLWithPath: "/tmp/work")
        #expect(DiscVerify.logURL(work: work, disc: 2).lastPathComponent == "verify-2.log")
        #expect(
            DiscVerify.logURL(work: work, disc: 2).deletingLastPathComponent().path == work.path)
    }

    // MARK: - Fixtures

    /// A probe set that answers without a drive. `toc` is what the listing
    /// reads, `status` what the full read exited with, `titles` what `-J`
    /// printed.
    static func probes(
        toc: String = "", status: Int32 = 0, titles: String = ""
    ) -> DiscVerify.Probes {
        DiscVerify.Probes(
            release: {},
            toc: { _ in toc },
            hasCdda2wav: { true },
            read: { _, _, _ in status },
            titles: { _, _ in titles },
            eject: { _ in })
    }

    static func verifier(
        toc: String = "", status: Int32 = 0, titles: String = ""
    ) -> DiscVerify {
        DiscVerify(probes: probes(toc: toc, status: status, titles: titles))
    }

    /// A path of its own per call. The suite runs in parallel and two tests
    /// writing one `verify-1.log` is one of them reading the other's.
    static func scratch() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "muthur-verify-\(UUID().uuidString).log")
    }

    /// Somewhere for a closure to record what it was asked, since `look` is not
    /// `async` and its probes are not `Sendable` boxes.
    final class Watched: @unchecked Sendable {
        var order: [String] = []
    }
}
