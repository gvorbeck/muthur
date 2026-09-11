import Foundation
import Testing

@testable import MUTHURKit

/// D80, D81 and D82 — the three things a disc in the drive turned up.
///
/// One suite because they are one disc's worth of findings: the lead-in could
/// not be read while macOS held the mount, the catalogue answered *busy* rather
/// than *no* often enough to matter, and a record nothing had named went to the
/// archive wearing the name of its volume and came back with somebody else's
/// cover.
struct BorrowedDriveTests {

    /// The machine as it was, with a disc in it. `/dev/disk7` is the drive.
    static let mounts = """
        /dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)
        /dev/disk7 on /Volumes/Audio CD (cddafs, local, nodev, nosuid, read-only, noowners)
        """

    static let drutil = MediaCheckTests.burntStatus

    // MARK: - D80, the borrowing itself

    /// The device and not the mount point. `diskutil mount` is given a node, and
    /// a `/Volumes/…` path that has just been unmounted is a path to nothing.
    @Test("What is given back is the device that was taken")
    func remembersTheDevice() {
        let release = DriveRelease(
            probes: DriveRelease.Probes(
                drutil: { Self.drutil }, mounts: { Self.mounts },
                unmount: { _ in true }, mount: { _ in true }))
        #expect(release.take().devices == ["/dev/disk7"])
    }

    /// A volume that would not unmount is not owed back — nothing took it.
    @Test("An unmount that failed leaves nothing owed")
    func failedUnmountOwesNothing() {
        let release = DriveRelease(
            probes: DriveRelease.Probes(
                drutil: { Self.drutil }, mounts: { Self.mounts },
                unmount: { _ in false }, mount: { _ in true }))
        #expect(release.take().isEmpty)
    }

    @Test("Unmount, read, remount — in that order, and it says the disc came back")
    func putsTheDiscBack() async {
        let machine = PretendDrive()
        let release = machine.release()

        let outcome = await release.around { () -> String in
            machine.log.note("read")
            return "Album title: 'Slippery When Wet'"
        }

        #expect(outcome.disc == .back)
        #expect(outcome.value.contains("Slippery"))
        #expect(
            machine.log.lines == ["unmount /Volumes/Audio CD", "read", "mount /dev/disk7"])
    }

    /// **The bug D80 shipped with, and the reason `giveBack` waits.**
    ///
    /// `cdda2wav`'s exclusive open makes the kernel re-enumerate the device, so
    /// for about a second there is no `/dev/disk7` and `diskutil mount` exits 1
    /// with `Failed to find disk`. Asked once, at that instant, it always failed
    /// — so the panel warned that the disc was gone after every read that
    /// worked. Here the node is missing for five looks and the disc is back on
    /// the sixth.
    @Test("A node that has not re-enumerated yet is waited for, not given up on")
    func waitsOutTheNode() async {
        let machine = PretendDrive(nodeMissingForLooks: 5)
        let outcome = await machine.release().around { 1 }

        #expect(outcome.disc == .back)
        // It looked more than once, which is the whole of the fix. It did *not*
        // ask more than once: there is nothing to ask while the node is away,
        // and a `diskutil mount` against a device that does not exist is the
        // call that made the old version report a lost disc every time.
        #expect(machine.looks > 1)
        #expect(machine.mountAttempts == 1)
        #expect(machine.isMounted)
    }

    /// **The other half: macOS puts the disc back without being asked.**
    ///
    /// Timed on this drive, `diskarbitrationd` re-mounted the volume at
    /// 1.29–1.39 s of its own accord, a third of a second after the node came
    /// back. So `diskutil mount` failing every time is *not* evidence the disc
    /// is gone, and a `giveBack` that read its exit status said the opposite of
    /// the truth. What is reported is the mount table.
    @Test("A disc macOS remounted by itself came back, whatever diskutil said")
    func theMachineCanBeatUsToIt() async {
        let machine = PretendDrive(remountsItselfAfterLooks: 6, deafToMount: true)
        let outcome = await machine.release().around { 1 }

        #expect(outcome.disc == .back)
        #expect(machine.isMounted)
    }

    /// The one outcome the user cannot diagnose: the disc is out of Finder, out
    /// of the record's own file URLs, and nothing on screen would say why.
    @Test("A disc that never comes back is reported, once the patience is spent")
    func saysWhenTheDiscStaysAway() async {
        let machine = PretendDrive(deafToMount: true)
        let outcome = await machine.release(patience: 1).around { 1 }

        #expect(outcome.disc == .stillAway)
        // One look per step through the patience, plus the first and the last.
        // The exact number is arithmetic and not a promise; that it kept asking
        // rather than giving up on the first refusal is the claim.
        #expect(machine.mountAttempts > 1)
    }

    /// An empty drive, or a disc macOS never mounted. Nothing was taken, so
    /// nothing failed — and a warning here would land on the panel of every
    /// machine without a disc in it.
    ///
    /// **It is `nothingTaken` and not `back`, and that distinction is the fix to
    /// the flag's quiet direction.** The two used to be one `true`. They are not
    /// the same claim: this one is *we did not look*, and the program has no way
    /// to tell a disc the user put away from one an earlier borrow lost.
    @Test("Taking nothing is not a failure to give it back, and not a homecoming")
    func nothingTakenIsNotAFailure() async {
        let machine = PretendDrive(mounted: false)
        let outcome = await machine.release().around { 1 }

        #expect(outcome.disc == .nothingTaken)
        #expect(outcome.disc != .back)
        #expect(machine.mountAttempts == 0)
    }

    /// Read twice in a row. The first read is the one that has to work, because
    /// the second cannot warn about a disc it never took.
    @Test("A second read finds the disc the first one gave back")
    func twoReadsInARow() async {
        let machine = PretendDrive(nodeMissingForLooks: 5)

        let first = await machine.release().around { 1 }
        #expect(first.disc == .back)

        let second = await machine.release().around { 1 }
        #expect(second.disc == .back)
        #expect(machine.isMounted)
    }

    @Test("The lead-in is read with the mount out of the way")
    func readsWithTheMountAway() async {
        let machine = PretendDrive()
        let inner = WatchingCDText(log: machine.log, output: "Album title: 'Slippery When Wet'")
        let borrowed = BorrowedCDText(inner, release: machine.release())

        let out = await borrowed.cdTextOutput()
        #expect(out?.contains("Slippery") == true)
        #expect(!borrowed.discStayedAway)
        #expect(borrowed.borrow == .back)
        #expect(
            machine.log.lines == ["unmount /Volumes/Audio CD", "cdTextOutput", "mount /dev/disk7"])
    }

    /// The notice the panel draws, and the condition it is drawn on.
    @Test("A lead-in read that lost the disc is the one thing that warns")
    func theNoticeIsForTheLostDisc() async {
        let away = PretendDrive(deafToMount: true)
        let borrowed = BorrowedCDText(
            WatchingCDText(log: away.log, output: "Album title: 'Slippery When Wet'"),
            release: away.release(patience: 1))
        _ = await borrowed.cdTextOutput()
        #expect(borrowed.discStayedAway)

        // And a drive with nothing on it does not warn, however the read went.
        let empty = PretendDrive(mounted: false)
        let quiet = BorrowedCDText(
            WatchingCDText(log: empty.log, output: nil), release: empty.release())
        _ = await quiet.cdTextOutput()
        #expect(!quiet.discStayedAway)
    }

    /// A lead-in with nothing in it is not a failure — §4.3 answers better than
    /// CD-Text does, and the fall-through is meant to be silent.
    @Test("An empty lead-in is not a notice")
    func silentWhenThereIsNoCDText() async {
        let machine = PretendDrive()
        let borrowed = BorrowedCDText(
            WatchingCDText(log: machine.log, output: nil), release: machine.release())
        #expect(await borrowed.cdTextOutput() == nil)
        #expect(!borrowed.discStayedAway)
    }

    // MARK: - D81, busy is not missing

    /// `{"error": "The MusicBrainz web server is currently busy. …"}` — valid
    /// JSON, no `releases` key, and until D81 it was a disc nobody had heard of.
    static let busy = Data(
        #"{"error": "The MusicBrainz web server is currently busy. Please try again later."}"#
            .utf8)

    static let found = Data(
        """
        {"releases":[{"id":"r-1","title":"Slippery When Wet",
          "artist-credit":[{"name":"Bon Jovi"}],"date":"1986-08-18",
          "media":[{"discs":[{"id":"tbonDFn643nTGHTHA1pMedaG3ZI-"}],
                    "tracks":[{"title":"Let It Rock"},{"title":"You Give Love a Bad Name"}]}]}]}
        """.utf8)

    static let discID = "tbonDFn643nTGHTHA1pMedaG3ZI-"

    @Test("A busy server is asked again, and the second answer is taken")
    func retriesABusyServer() async {
        let transport = QueuedTransport([.body(Self.busy), .body(Self.found)])
        let answer = await MusicBrainzDisc.look(
            up: Self.discID, transport: transport, retryDelay: .zero)
        #expect(answer?.album == "Slippery When Wet")
        #expect(answer?.albumArtist == "Bon Jovi")
        #expect(transport.count == 2)
    }

    /// The cost of the retry, stated: one spare request on a disc that was never
    /// going to be named.
    @Test("A disc the catalogue really does not have is asked twice and no more")
    func stopsAtTwo() async {
        let transport = QueuedTransport([.body(Self.busy), .body(Self.busy)])
        let answer = await MusicBrainzDisc.look(
            up: Self.discID, transport: transport, retryDelay: .zero)
        #expect(answer == nil)
        #expect(transport.count == 2)
    }

    /// A release list that came back first time is not asked about again.
    @Test("An answer on the first ask is one request")
    func oneRequestWhenItAnswers() async {
        let transport = QueuedTransport([.body(Self.found)])
        _ = await MusicBrainzDisc.look(up: Self.discID, transport: transport, retryDelay: .zero)
        #expect(transport.count == 1)
    }

    /// The whole of it through §4: a disc whose first lookup came back busy is
    /// named anyway, and the faceplate says MusicBrainz.
    @Test("A disc named on the second ask reaches the panel")
    func theChainSurvivesABusyServer() async throws {
        var record = DiscTitlesTests.mounted(2)
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD",
            tableOfContents: StubTOC(toc: DiscIDTests.sevenTrack),
            transport: QueuedTransport([.body(Self.busy), .body(Self.found)]),
            retryDelay: .zero
        )
        #expect(outcome.source == .musicBrainz)
        #expect(record.album == "Slippery When Wet")
        #expect(!outcome.albumIsPlaceholder)
    }

    // MARK: - D82, a placeholder is not a title

    /// The failure as it stood: `ALBUM "Audio CD"` went to §5.3 as a search
    /// term, and the archive answered with an Elton John sampler.
    @Test("A disc nothing named does not go looking for a cover by name")
    func doesNotSearchForThePlaceholder() async {
        let temp = TempDirectory()
        let transport = QueuedTransport([])
        let resolver = Self.resolver(transport: transport, cache: temp)

        let resolution = await resolver.resolve(
            SleeveResolver.Request(
                directory: nil, files: [], album: "Audio CD", albumArtist: "",
                albumIsPlaceholder: true))

        #expect(resolution.sleeve == nil)
        #expect(resolution.pending == nil)
        #expect(transport.count == 0)
    }

    /// A disc §4.3 *did* identify has a release MBID, which is not a name and is
    /// not a guess. It goes through.
    @Test("A release MBID goes to the archive even when nothing named the album")
    func theMBIDStillAsks() async {
        let temp = TempDirectory()
        let transport = QueuedTransport([])
        let resolver = Self.resolver(transport: transport, cache: temp)

        let resolution = await resolver.resolve(
            SleeveResolver.Request(
                directory: nil, files: [], album: "Audio CD", albumArtist: "",
                releaseMBID: "r-1", albumIsPlaceholder: true))

        // Nothing was found — the transport has nothing to give — but the fetch
        // was started, which is the difference being asserted.
        #expect(resolution.sleeve == nil)
        #expect(resolution.pending != nil)
        await resolution.pending?.value
    }

    /// Every folder and every zip. The flag defaults false and must not have
    /// quietly switched the archive off for the ordinary case.
    @Test("A tagged record is unaffected")
    func aNamedRecordStillAsks() async {
        let temp = TempDirectory()
        let resolver = Self.resolver(transport: QueuedTransport([]), cache: temp)
        let resolution = await resolver.resolve(
            SleeveResolver.Request(
                directory: nil, files: [], album: "Rumours", albumArtist: "Fleetwood Mac"))
        #expect(resolution.pending != nil)
        await resolution.pending?.value
    }

    /// Where the flag comes from. Nothing named the disc, so §4.1's stand-in is
    /// still on the faceplate and D82 has to know it.
    @Test("Nothing named it, so the album is a placeholder")
    func theChainSaysWhenNothingNamedIt() async {
        var record = DiscTitlesTests.mounted(2)
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD", useMusicBrainz: false, retryDelay: .zero)
        #expect(outcome.source == .trackNumbers)
        #expect(record.album == "Audio CD")
        #expect(outcome.albumIsPlaceholder)
    }

    /// **The album and the track list are different questions.** A lead-in that
    /// gave a title and no track names leaves the source at `track numbers`
    /// (§18.11, D19) and the record genuinely named — so the sleeve may still be
    /// searched for.
    @Test("CD-Text that named only the album is still a name")
    func anAlbumWithoutTracksIsStillAName() async {
        var record = DiscTitlesTests.mounted(2)
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD",
            cdText: StubCDText(output: "Album title: 'Slippery When Wet'"),
            useMusicBrainz: false, retryDelay: .zero
        )
        #expect(outcome.source == .trackNumbers)
        #expect(record.album == "Slippery When Wet")
        #expect(!outcome.albumIsPlaceholder)
    }

    static func resolver(transport: QueuedTransport, cache temp: TempDirectory) -> SleeveResolver {
        SleeveResolver(
            probe: StubPictureProbe(everythingIs: PictureSize(width: 600, height: 600)),
            embedded: NoEmbeddedPictures(),
            transport: transport,
            cache: SleeveCache(directory: temp.url.appending(path: "cache")),
            retryDelay: .zero
        )
    }
}

// MARK: - Fixtures

/// What happened, in the order it happened. The ordering is the assertion in
/// half of D80's tests: a read that ran before the unmount would have read the
/// same page of refusal the mounted disc always gave.
final class Recorded: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String] = []

    var lines: [String] { lock.withLock { entries } }

    func note(_ line: String) { lock.withLock { entries.append(line) } }

    /// Records and succeeds, for the probes whose answer is a `Bool`.
    func append(_ line: String) -> Bool {
        note(line)
        return true
    }
}

/// A drive that changes under the program, which is the only way to test D80.
///
/// The old fixtures handed `DriveRelease` a mount table that said the same thing
/// however the borrow went, so the one thing that mattered — *the machine moves
/// while you are not looking* — was the one thing they could not express. This
/// is that machine, with the three behaviours measured off the real drive:
///
/// - `nodeMissingForLooks` — the exclusive open re-enumerates the device, so
///   `/dev/disk7` is absent for about a second (1.03–1.08 s, seven runs) and
///   `diskutil mount` on it exits 1 in the meantime.
/// - `remountsItselfAfterLooks` — `diskarbitrationd` puts the volume back
///   unasked, at 1.29–1.39 s, whatever the program did or failed to do.
/// - `deafToMount` — `diskutil mount` never works. On its own that is a lost
///   disc; with the line above it is not, and telling those apart is the fix.
///
/// A "look" is one `drutil status`, which is once round `giveBack`'s loop.
/// Counting polls rather than seconds keeps the suite instant and keeps the
/// assertions off the wall clock, which is not a thing a test may depend on.
final class PretendDrive: @unchecked Sendable {
    let log = Recorded()

    private let lock = NSLock()
    private var mounted: Bool
    private let deaf: Bool
    private let nodeMissing: Int
    private let selfRemount: Int?
    private var borrowing = false
    private var looks_ = 0
    private var attempts = 0

    init(
        mounted: Bool = true,
        nodeMissingForLooks: Int = 0,
        remountsItselfAfterLooks: Int? = nil,
        deafToMount: Bool = false
    ) {
        self.mounted = mounted
        self.nodeMissing = nodeMissingForLooks
        self.selfRemount = remountsItselfAfterLooks
        self.deaf = deafToMount
    }

    var isMounted: Bool { lock.withLock { mounted } }
    var mountAttempts: Int { lock.withLock { attempts } }
    /// Looks taken since the disc came off — one per turn of `giveBack`'s loop.
    var looks: Int { lock.withLock { looks_ } }

    /// Spends no time: what is being asserted is that it kept asking, never how
    /// long it took.
    func release(patience: Double = 5) -> DriveRelease {
        DriveRelease(
            probes: DriveRelease.Probes(
                drutil: { [self] in drutil() },
                mounts: { [self] in mounts() },
                unmount: { [self] in unmount($0) },
                mount: { [self] in mount($0) },
                pause: { _ in }),
            patience: patience)
    }

    private func drutil() -> String {
        lock.withLock {
            looks_ += 1
            if let after = selfRemount, looks_ >= after { mounted = true }
            // The node the exclusive open took away. `drutil` naming nothing is
            // how a torn-down device reads from up here.
            if borrowing, looks_ <= nodeMissing { return MediaCheckTests.emptyStatus }
            return MediaCheckTests.burntStatus
        }
    }

    private func mounts() -> String {
        lock.withLock {
            let root = "/dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)"
            guard mounted else { return root }
            return """
                \(root)
                /dev/disk7 on /Volumes/Audio CD (cddafs, local, nodev, nosuid, read-only, noowners)
                """
        }
    }

    private func unmount(_ volume: URL) -> Bool {
        lock.withLock {
            log.note("unmount \(volume.path)")
            mounted = false
            // The borrow's clock starts when the disc comes off, so a second
            // read through the same drive gets the same second of absence.
            borrowing = true
            looks_ = 0
            return true
        }
    }

    private func mount(_ device: String) -> Bool {
        lock.withLock {
            attempts += 1
            log.note("mount \(device)")
            guard !deaf else { return false }
            // `Failed to find disk /dev/disk7` — not a refusal, and not the disc
            // being gone. There is simply no node yet.
            guard !(borrowing && looks_ <= nodeMissing) else { return false }
            mounted = true
            return true
        }
    }
}

final class WatchingCDText: CDTextSource, @unchecked Sendable {
    let log: Recorded
    let output: String?

    init(log: Recorded, output: String?) {
        self.log = log
        self.output = output
    }

    func cdTextOutput() async -> String? {
        log.note("cdTextOutput")
        return output
    }
}

/// Answers in order, and counts. `StubSleeveTransport` answers the same thing
/// however often it is asked, which is exactly the property D81 is about —
/// a server that said one thing and then another.
final class QueuedTransport: SleeveTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [SleeveAnswer]
    private var asked = 0

    init(_ queue: [SleeveAnswer]) { self.queue = queue }

    var count: Int { lock.withLock { asked } }

    func get(_ url: URL, timeout: Duration) async -> SleeveAnswer {
        lock.withLock {
            asked += 1
            guard !queue.isEmpty else { return .body(Data()) }
            return queue.removeFirst()
        }
    }
}
