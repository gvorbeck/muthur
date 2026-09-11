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
        let log = Recorded()
        let release = DriveRelease(
            probes: DriveRelease.Probes(
                drutil: { Self.drutil }, mounts: { Self.mounts },
                unmount: { log.append("unmount \($0.path)") },
                mount: { log.append("mount \($0)") }))

        let outcome = await release.around { () -> String in
            log.note("read")
            return "Album title: 'Slippery When Wet'"
        }

        #expect(outcome.remounted)
        #expect(outcome.value.contains("Slippery"))
        #expect(log.lines == ["unmount /Volumes/Audio CD", "read", "mount /dev/disk7"])
    }

    /// The one outcome the user cannot diagnose: the disc is out of Finder, out
    /// of the record's own file URLs, and nothing on screen would say why.
    @Test("A disc that does not come back is reported")
    func saysWhenTheDiscStaysAway() async {
        let release = DriveRelease(
            probes: DriveRelease.Probes(
                drutil: { Self.drutil }, mounts: { Self.mounts },
                unmount: { _ in true }, mount: { _ in false }))
        let outcome = await release.around { 1 }
        #expect(!outcome.remounted)
    }

    /// An empty drive, or a disc macOS never mounted. Nothing was taken, so
    /// nothing failed — and a false here would put a warning on the panel of
    /// every machine without a disc in it.
    @Test("Taking nothing is not a failure to give it back")
    func nothingTakenIsNotAFailure() async {
        let release = DriveRelease(
            probes: DriveRelease.Probes(
                drutil: { MediaCheckTests.emptyStatus }, mounts: { Self.mounts },
                unmount: { _ in true }, mount: { _ in false }))
        let outcome = await release.around { 1 }
        #expect(outcome.remounted)
    }

    @Test("The lead-in is read with the mount out of the way")
    func readsWithTheMountAway() async {
        let log = Recorded()
        let inner = WatchingCDText(log: log, output: "Album title: 'Slippery When Wet'")
        let borrowed = BorrowedCDText(
            inner,
            release: DriveRelease(
                probes: DriveRelease.Probes(
                    drutil: { Self.drutil }, mounts: { Self.mounts },
                    unmount: { log.append("unmount \($0.path)") },
                    mount: { log.append("mount \($0)") })))

        let out = await borrowed.cdTextOutput()
        #expect(out?.contains("Slippery") == true)
        #expect(!borrowed.remountFailed)
        #expect(log.lines == ["unmount /Volumes/Audio CD", "cdTextOutput", "mount /dev/disk7"])
    }

    /// A lead-in with nothing in it is not a failure — §4.3 answers better than
    /// CD-Text does, and the fall-through is meant to be silent.
    @Test("An empty lead-in is not a notice")
    func silentWhenThereIsNoCDText() async {
        let borrowed = BorrowedCDText(
            WatchingCDText(log: Recorded(), output: nil),
            release: DriveRelease(
                probes: DriveRelease.Probes(
                    drutil: { Self.drutil }, mounts: { Self.mounts },
                    unmount: { _ in true }, mount: { _ in true })))
        #expect(await borrowed.cdTextOutput() == nil)
        #expect(!borrowed.remountFailed)
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
