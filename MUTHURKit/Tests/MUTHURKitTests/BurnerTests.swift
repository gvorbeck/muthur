import Foundation
import Testing

@testable import MUTHURKit

/// §20 stage 3b — the drive conformance, without the drive.
///
/// The burn itself needs hardware and is asked for in `BurnMaterialTests`. What
/// is asked here is everything around it, which turns out to be most of it: the
/// carriage-return reader, the unmount that has to happen before cdrecord can
/// open anything, the failure message, and — by pointing `Burner` at `/bin/sh`
/// instead of at cdrecord — the whole pipe, panel and log path end to end.
///
/// **The stand-in is a shell script printing a real capture.** Those lines came
/// off this machine's drive during a rehearsal, carriage returns and all, so
/// what the panel is fed here is byte for byte what a burn feeds it. What that
/// cannot prove is that a drive accepts the vector; what it proves is that when
/// one does, its narration arrives intact.
@Suite("§20 The drive that is not pretending")
struct BurnerTests {

    // MARK: - Reading on the carriage returns

    @Test("A chunk is what was between two carriage returns")
    func splitsOnCarriageReturns() {
        var buffer = Data("one\rtwo\rthree\r".utf8)
        #expect(Burner.chunks(from: &buffer) == ["one", "two", "three"])
        #expect(buffer.isEmpty)
    }

    @Test("An unterminated tail stays in the buffer")
    func keepsThePartialChunk() {
        var buffer = Data("Track 01:    1 of   39 MB\rTrack 01:    2 of".utf8)
        #expect(Burner.chunks(from: &buffer) == ["Track 01:    1 of   39 MB"])
        #expect(String(decoding: buffer, as: UTF8.self) == "Track 01:    2 of")
    }

    /// The bug this is here for: a `Data` slice keeps the offsets of the buffer
    /// it was cut from, so a tail that is not rebased makes the *next* append
    /// land past the end and every chunk after it wrong.
    @Test("The tail is rebased, so the next read joins onto it")
    func joinsAcrossReads() {
        var buffer = Data("Track 01:    1 of   39 MB\rTrack 0".utf8)
        _ = Burner.chunks(from: &buffer)
        buffer.append(Data("2:    7 of   31 MB\r".utf8))
        #expect(Burner.chunks(from: &buffer) == ["Track 02:    7 of   31 MB"])
        #expect(buffer.isEmpty)
    }

    @Test("Newlines inside a chunk are left where they are")
    func doesNotSplitOnNewlines() {
        // cdrecord's last progress line and its whole closing summary arrive as
        // one piece, and `BurnPanel.parse` reads that piece by its first three
        // words.
        var buffer = Data("Track 03:   31 of   31 MB written.\nFixating...\n".utf8)
        #expect(Burner.chunks(from: &buffer).isEmpty)
        buffer.append(Data("\r".utf8))
        let chunk = try! #require(Burner.chunks(from: &buffer).first)
        #expect(chunk.contains("Fixating"))
        #expect(BurnPanel.parse(chunk)?.track == 3)
    }

    // MARK: - What it says when the drive says no

    @Test("The failure keeps the drive's own last words")
    func failureQuotesTheLog() {
        let log = """
            Starting to write CD/DVD/BD at speed 8 in real SAO mode for single session.\r\
            Track 01:    3 of   39 MB written (fifo 100%) [buf  99%]   8.1x.\r\

            cdrecord: Input/output error. write_g1: scsi sendcmd: no error\r\
            cdrecord: Cannot write track.\r
            """
        let said = Burner.lastWords(log)
        // The progress chatter is out — fifteen lines of "3 of 39 MB" is fifteen
        // lines saying nothing went wrong — and what is left is what did.
        #expect(!said.contains { $0.contains("MB written") })
        #expect(said.last == "cdrecord: Cannot write track.")
        #expect(said.contains { $0.contains("Input/output error") })
    }

    @Test("Fifteen lines at most, and never a blank one")
    func failureIsTrimmed() {
        let log = (1...40).map { "line \($0)" }.joined(separator: "\n") + "\n\n   \n"
        let said = Burner.lastWords(log)
        #expect(said.count == 15)
        #expect(said.last == "line 40")
    }

    @Test("The failure names the device the vector actually carried")
    func failureNamesTheDevice() {
        let invocation = Cdrecord.write(
            cue: URL(fileURLWithPath: "/w/disc1.cue"), device: "IODVDServices/0",
            cdText: true, directory: URL(fileURLWithPath: "/w"))
        #expect(Burner.device(in: invocation.arguments) == "IODVDServices/0")
        #expect(Burner.device(in: ["-v", "-dao"]) == "?")

        let failure = Burner.Failure.refused(
            disc: 2, status: 255, device: "IODVDServices/0", said: ["cdrecord: Cannot open."])
        let text = failure.description
        #expect(text.contains("disc 2"))
        #expect(text.contains("exit 255"))
        #expect(text.contains("dev=IODVDServices/0"))
        #expect(text.contains("cdrecord: Cannot open."))
        // The script's three remedies, which are the whole of what a person can
        // do next.
        #expect(text.contains("-scanbus"))
        #expect(text.contains("CD-Text"))
    }

    // MARK: - Getting the drive back off macOS

    /// Real output from this machine, taken while the phantom `Audio CD` a
    /// finished rehearsal leaves behind was mounted.
    static let mountOutput = """
        /dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)
        /dev/disk5s2 on /Volumes/My Passport (exfat, local, nodev, nosuid, noowners)
        /dev/disk7 on /Volumes/Audio CD (cddafs, local, nodev, nosuid, read-only, noowners)
        """

    @Test("The volume on the drive's node is the one that is unmounted")
    func findsTheDrivesVolume() {
        let mounts = DiscFinder.MountTable.parse(Self.mountOutput)
        let found = DriveRelease.volumes(of: "/dev/disk7", in: mounts)
        #expect(found.map(\.path) == ["/Volumes/Audio CD"])

        // A node with nothing on it — a genuinely blank disc — has nothing to
        // unmount, which is the ordinary case and must not be an error.
        #expect(DriveRelease.volumes(of: "/dev/disk9", in: mounts).isEmpty)
    }

    /// `/dev/disk1` is a prefix of `/dev/disk10`, and unmounting the wrong
    /// volume because of it would be this port taking a working drive away from
    /// somebody's backup.
    @Test("A node is not its own longer neighbour")
    func doesNotMatchByPrefix() {
        let mounts = DiscFinder.MountTable.parse(
            "/dev/disk10 on /Volumes/Deluxe (cddafs, local)\n"
                + "/dev/disk1s2 on /Volumes/Data (apfs, local)")
        #expect(DriveRelease.volumes(of: "/dev/disk1", in: mounts).map(\.path) == ["/Volumes/Data"])
    }

    @Test("The unmount happens before cdrecord is opened, and only where there is one")
    func unmountsWhatIsMounted() {
        let asked = Asked<[String]>([])
        let burner = Burner(
            probes: Burner.Probes(
                cdrecord: { nil },
                drutil: { MediaCheckTests.burntStatus },
                mounts: { Self.mountOutput },
                unmount: { volume in
                    asked.value.append(volume.path)
                    return true
                }))
        burner.releaseTheDrive()
        #expect(asked.value == ["/Volumes/Audio CD"])
    }

    @Test("An empty drive is not unmounted")
    func leavesAnEmptyDriveAlone() {
        let asked = Asked<[String]>([])
        let burner = Burner(
            probes: Burner.Probes(
                cdrecord: { nil },
                drutil: { MediaCheckTests.emptyStatus },
                mounts: { Self.mountOutput },
                unmount: { volume in
                    asked.value.append(volume.path)
                    return true
                }))
        burner.releaseTheDrive()
        #expect(asked.value.isEmpty)
    }

    // MARK: - The disc's size

    /// The image over 1,048,576 and nothing else — no per-track arrears, which
    /// are the stand-in's business (`burncd:2584`).
    @Test("A real burn's total is the image in whole megabytes")
    func sizesFromTheImage() {
        #expect(Burner().totalMegabytes(bytes: 91_869_164, tracks: 3) == 87)
        #expect(Burner().totalMegabytes(bytes: 0, tracks: 12) == 0)
    }

    // MARK: - End to end, with a shell where the drive goes

    /// Three tracks of a real rehearsal's narration, `\r` for `\r`.
    static func narration() -> String {
        var lines: [String] = []
        for (track, size) in [(1, 39), (2, 17), (3, 31)] {
            for done in stride(from: 0, to: size, by: 4) {
                lines.append(
                    String(
                        format: "Track %02d: %4d of %4d MB written (fifo 100%%) [buf  99%%]   8.1x.",
                        track, done, size))
            }
            // Every track is closed on its own stated size, whatever the step
            // last landed on — a drive that stopped four short of the total is
            // a drive that failed, and that is a different test.
            lines.append(
                String(
                    format: "Track %02d: %4d of %4d MB written (fifo 100%%) [buf  99%%]   8.1x.",
                    track, size, size))
        }
        return lines.joined(separator: "\r") + "\r"
    }

    private func shellBurner(unmount: @escaping @Sendable (URL) -> Bool = { _ in true }) -> Burner {
        Burner(
            probes: Burner.Probes(
                cdrecord: { URL(fileURLWithPath: "/bin/sh") },
                drutil: { nil },
                mounts: { nil },
                unmount: unmount))
    }

    private func panel(tracks: [Int], megabytes: Int) -> BurnPanel {
        BurnPanel(
            disc: 1, of: 1,
            titles: tracks.indices.map { "Track \($0 + 1)" },
            durations: tracks,
            totalMegabytes: megabytes)
    }

    @Test("A whole narration arrives, fills the panel and is kept in the log")
    func readsAWholeBurn() throws {
        let work = try BurnConversionTests.Work()
        let script = "printf '%s' \(Self.narration().shellQuoted); exit 0"
        var burnPanel = panel(tracks: [235, 101, 186], megabytes: 87)
        var frames = 0

        try shellBurner().write(
            Cdrecord(arguments: ["-c", script], directory: work.url),
            into: &burnPanel,
            frame: { _ in frames += 1 })

        // The last thing the drive said was track 3 complete, so the panel is on
        // track 3 and the bar is where the arrears leave it — not necessarily
        // 100, which is the lead-out's business and needs three seconds of quiet
        // this test does not spend.
        #expect(burnPanel.track == 3)
        #expect(burnPanel.trackPercent == 100)
        #expect(burnPanel.doneMegabytes == 87)
        #expect(frames > 1)

        // The log is the whole of what was said, not the part the panel could
        // read — which is the entire reason it is written.
        let log = try String(
            contentsOf: Cdrecord.logURL(work: work.url, disc: 1), encoding: .isoLatin1)
        #expect(log.contains("Track 01:    0 of   39 MB"))
        #expect(log.contains("Track 03:   31 of   31 MB"))
    }

    @Test("A drive that refuses throws with what it said")
    func reportsARefusal() throws {
        let work = try BurnConversionTests.Work()
        let script = """
            printf 'cdrecord: Device or resource busy. Cannot open SCSI driver.\\n'
            printf 'cdrecord: Unable to get exclusive access to device.\\n'
            exit 255
            """
        var burnPanel = panel(tracks: [235], megabytes: 39)

        #expect(throws: Burner.Failure.self) {
            try shellBurner().write(
                Cdrecord(arguments: ["-c", script, "sh", "dev=IODVDServices/0"],
                    directory: work.url),
                into: &burnPanel, frame: { _ in })
        }

        do {
            try shellBurner().write(
                Cdrecord(arguments: ["-c", script, "sh", "dev=IODVDServices/0"],
                    directory: work.url),
                into: &burnPanel, frame: { _ in })
            Issue.record("a non-zero cdrecord has to be a failure")
        } catch let failure as Burner.Failure {
            let text = failure.description
            #expect(text.contains("exclusive access"))
            #expect(text.contains("exit 255"))
            #expect(text.contains("dev=IODVDServices/0"))
        }
    }

    @Test("No cdrecord is a failure that names the remedy")
    func refusesWithoutCdrecord() throws {
        let work = try BurnConversionTests.Work()
        var burnPanel = panel(tracks: [235], megabytes: 39)
        let burner = Burner(
            probes: Burner.Probes(
                cdrecord: { nil }, drutil: { nil }, mounts: { nil }, unmount: { _ in true }))
        do {
            try burner.write(
                Cdrecord(arguments: [], directory: work.url), into: &burnPanel, frame: { _ in })
            Issue.record("a missing cdrecord cannot be a silent success")
        } catch let failure as Burner.Failure {
            #expect(failure.description.contains("cdrtools"))
        }
    }
}

/// Somewhere for a probe closure to write down what it was asked, which is all
/// the mutable state these tests need.
private final class Asked<Value>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) { self.value = value }
}

private extension String {
    /// Single-quoted for `sh -c`, with the one escape single quotes have.
    var shellQuoted: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
