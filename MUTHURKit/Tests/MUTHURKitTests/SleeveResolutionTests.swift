import Foundation
import Testing

@testable import MUTHURKit

/// A transport that takes its time, for the one property §5 cares about more
/// than any other: that nothing is waiting for it.
private final class SlowSleeveTransport: SleeveTransport {
    let seconds: Double
    init(seconds: Double = 30) { self.seconds = seconds }
    func get(_ url: URL, timeout: Duration) async -> SleeveAnswer {
        try? await Task.sleep(for: .seconds(seconds))
        return .couldNotAsk
    }
}

/// Somewhere for a background task to put an answer nobody is awaiting.
private final class Box<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value
    init(_ value: Value) { stored = value }
    var value: Value {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }
}

/// §5 read whole — the order, and the promise about the network.
@Suite("Sleeve — resolution")
struct SleeveResolutionTests {

    private func releases(_ ids: [String]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["releases": ids.map { ["id": $0] }])
    }

    private func resolver(
        transport: any SleeveTransport = StubSleeveTransport([], otherwise: .couldNotAsk),
        embedded: any EmbeddedPictureReader = NoEmbeddedPictures(),
        cache: SleeveCache,
        isEnabled: Bool = true,
        now: @escaping @Sendable () -> Date = Date.init
    ) -> SleeveResolver {
        SleeveResolver(
            probe: ImageIOPictureProbe(), embedded: embedded, transport: transport,
            cache: cache, isEnabled: isEnabled, retryDelay: .zero, now: now
        )
    }

    private func request(
        directory: URL? = nil,
        files: [URL] = [],
        album: String = "Comfort Eagle",
        albumArtist: String = "Cake",
        releaseMBID: String? = nil,
        scratch: URL? = nil
    ) -> SleeveResolver.Request {
        SleeveResolver.Request(
            directory: directory, files: files, album: album, albumArtist: albumArtist,
            releaseMBID: releaseMBID, scratch: scratch
        )
    }

    // MARK: - The order

    @Test("A picture beside the record beats everything, and asks nothing")
    func besideTheRecordFirst() async throws {
        let album = TempDirectory("album")
        let art = TempDirectory("art")
        let cover = try album.picture("cover.jpg", side: 600)

        let transport = StubSleeveTransport([], otherwise: .body(releases(["r1"])))
        let embedded = StubEmbeddedPictureReader(["01.flac": TestPictures.jpeg(1000)])
        let resolution = await resolver(
            transport: transport, embedded: embedded, cache: SleeveCache(directory: art.url)
        ).resolve(
            request(
                directory: album.url, files: [album.url.appending(path: "01.flac")],
                scratch: art.url.appending(path: "scratch")
            )
        )

        #expect(samePath(resolution.sleeve?.url, cover))
        #expect(resolution.sleeve?.source == .besideTheRecord)
        #expect(resolution.pending == nil)
        // The artwork this copy shipped with, and not one request made to find
        // out whether the catalogue agrees.
        #expect(transport.asked.isEmpty)
    }

    @Test("Then the tags")
    func thenTheTags() async throws {
        let album = TempDirectory("album")
        let art = TempDirectory("art")
        let scratch = art.url.appending(path: "scratch")

        let transport = StubSleeveTransport([], otherwise: .couldNotAsk)
        let embedded = StubEmbeddedPictureReader(["01.flac": TestPictures.jpeg(1000)])
        let resolution = await resolver(
            transport: transport, embedded: embedded, cache: SleeveCache(directory: art.url)
        ).resolve(
            request(
                directory: album.url, files: [album.url.appending(path: "01.flac")],
                scratch: scratch
            )
        )

        #expect(resolution.sleeve?.source == .tags)
        #expect(resolution.pending == nil)
        #expect(transport.asked.isEmpty)
        // Written where the scratch goes, because a picture out of a tag is not
        // a file anybody asked to keep.
        #expect(resolution.sleeve?.url.deletingLastPathComponent().path == scratch.path)
    }

    @Test("A thumbnail in the tags does not count as a sleeve")
    func embeddedFloor() async throws {
        let art = TempDirectory("art")
        let scratch = art.url.appending(path: "scratch")
        let embedded = StubEmbeddedPictureReader([
            "01.flac": TestPictures.jpeg(90),
            "02.flac": TestPictures.jpeg(400),
        ])
        let resolution = await resolver(embedded: embedded, cache: SleeveCache(directory: art.url))
            .resolve(
                request(
                    files: ["01.flac", "02.flac"].map {
                        URL(fileURLWithPath: "/album").appending(path: $0)
                    },
                    scratch: scratch
                )
            )
        // The 90×90 is refused and the next track is asked, rather than the
        // record being declared to have artwork it does not have.
        #expect(resolution.sleeve?.source == .tags)
        #expect(ImageIOPictureProbe().size(of: resolution.sleeve!.url)?.width == 400)
    }

    @Test("Only the first three tracks are opened")
    func firstThreeOnly() async throws {
        let art = TempDirectory("art")
        let embedded = StubEmbeddedPictureReader(["04.flac": TestPictures.jpeg(1000)])
        let files = (1...9).map {
            URL(fileURLWithPath: "/album").appending(path: String(format: "%02d.flac", $0))
        }
        let resolution = await resolver(embedded: embedded, cache: SleeveCache(directory: art.url))
            .resolve(request(files: files, scratch: art.url.appending(path: "scratch")))

        // A record that tags its artwork tags it on track one; opening every
        // file on a long album before the first frame would be felt.
        #expect(resolution.sleeve == nil)
    }

    @Test("With no artwork anywhere, no scratch file is left behind")
    func noScratchLeftBehind() async throws {
        let art = TempDirectory("art")
        let scratch = art.url.appending(path: "scratch")
        let embedded = StubEmbeddedPictureReader(["01.flac": TestPictures.notAPicture])
        _ = await resolver(embedded: embedded, cache: SleeveCache(directory: art.url))
            .resolve(
                request(files: [URL(fileURLWithPath: "/album/01.flac")], scratch: scratch)
            )
        #expect(
            (try? FileManager.default.contentsOfDirectory(atPath: scratch.path))?.isEmpty == true
        )
    }

    // MARK: - Nothing waits on the network

    @Test("resolve returns while the archive is still being asked")
    func nothingWaits() async throws {
        let art = TempDirectory("art")
        let resolver = resolver(
            transport: SlowSleeveTransport(), cache: SleeveCache(directory: art.url)
        )

        let started = ContinuousClock.now
        let resolution = await resolver.resolve(request())
        let elapsed = ContinuousClock.now - started

        // The panel is drawn on the next frame whatever the network is doing.
        #expect(elapsed < .seconds(2))
        #expect(resolution.sleeve == nil)
        #expect(resolution.pending != nil)
        resolution.pending?.cancel()
    }

    @Test("A cover that turns up late arrives by callback")
    func lateArrival() async throws {
        let art = TempDirectory("art")
        let transport = StubSleeveTransport([
            (match: "ws/2/release", answer: .body(releases(["r1"]))),
            (match: "front-500", answer: .body(TestPictures.jpeg(500))),
        ])
        let arrived = Box<Sleeve?>(nil)
        let resolution = await resolver(transport: transport, cache: SleeveCache(directory: art.url))
            .resolve(request()) { arrived.value = $0 }

        // Nothing is on the panel yet, and the record is already playing.
        #expect(resolution.sleeve == nil)

        let late = await resolution.pending?.value
        #expect(late?.source == .coverArtArchive)
        #expect(arrived.value == late)
        #expect(SleeveCache(directory: art.url).hasEntry(forKey: "cake-comfort-eagle"))
    }

    // MARK: - The cache

    @Test("An album already in the cache costs nothing")
    func cacheHit() async throws {
        let art = TempDirectory("art")
        let cache = SleeveCache(directory: art.url)
        cache.writePart(TestPictures.jpeg(500), forKey: "cake-comfort-eagle")
        let entry = cache.commitPart(forKey: "cake-comfort-eagle")!

        let transport = StubSleeveTransport([], otherwise: .body(releases(["r1"])))
        let resolution = await resolver(transport: transport, cache: cache).resolve(request())

        #expect(resolution.sleeve == Sleeve(url: entry, source: .coverArtArchive))
        #expect(resolution.pending == nil)
        #expect(transport.asked.isEmpty)
    }

    @Test("A fresh marker means the network is not asked at all")
    func markerStops() async throws {
        let art = TempDirectory("art")
        let cache = SleeveCache(directory: art.url)
        cache.markNone(forKey: "cake-comfort-eagle")

        let transport = StubSleeveTransport([], otherwise: .body(releases(["r1"])))
        let resolution = await resolver(transport: transport, cache: cache).resolve(request())

        #expect(resolution.sleeve == nil)
        #expect(resolution.pending == nil)
        // Without this, an album with no scan costs two lookups every play.
        #expect(transport.asked.isEmpty)
    }

    @Test("A marker a fortnight old is ignored, so a scan uploaded since turns up")
    func staleMarkerAsksAgain() async throws {
        let art = TempDirectory("art")
        let cache = SleeveCache(directory: art.url)
        cache.markNone(forKey: "cake-comfort-eagle")

        let transport = StubSleeveTransport([
            (match: "ws/2/release", answer: .body(releases(["r1"]))),
            (match: "front-500", answer: .body(TestPictures.jpeg(500))),
        ])
        let later = Date().addingTimeInterval(SleeveCache.noneLifetime + 60)
        let resolution = await resolver(transport: transport, cache: cache, now: { later })
            .resolve(request())

        #expect(resolution.pending != nil)
        #expect(await resolution.pending?.value != nil)
    }

    @Test("A record with no name is not filed under one")
    func noKeyNoFetch() async throws {
        let art = TempDirectory("art")
        let transport = StubSleeveTransport([], otherwise: .body(releases(["r1"])))
        let resolution = await resolver(transport: transport, cache: SleeveCache(directory: art.url))
            .resolve(request(album: "", albumArtist: ""))

        #expect(resolution.sleeve == nil)
        #expect(resolution.pending == nil)
        #expect(transport.asked.isEmpty)
    }

    // MARK: - The fetch

    @Test("A release MBID names a pressing, so nothing is searched for")
    func mbidSkipsTheSearch() async throws {
        let art = TempDirectory("art")
        let mbid = "8f4b1c8e-1f9a-4d3e-9d2c-000000000000"
        let transport = StubSleeveTransport([
            (match: "front-1200", answer: .body(TestPictures.jpeg(1200)))
        ])
        let resolution = await resolver(transport: transport, cache: SleeveCache(directory: art.url))
            .resolve(request(releaseMBID: mbid))

        let late = await resolution.pending?.value
        #expect(late?.source == .coverArtArchive)
        // One request, and it is the large one: an entry the archive has a
        // 1200 px thumbnail for never asks for the 500.
        #expect(transport.asked.count == 1)
        #expect(transport.asked.first?.absoluteString.contains("ws/2") == false)
        #expect(late?.url.lastPathComponent == "mbid-\(mbid).jpg")
    }

    @Test("An entry that predates the large thumbnail still gets its sleeve")
    func fallsBackToTheSmallerSize() async throws {
        let art = TempDirectory("art")
        // The archive's 1200 px size was added years after the 500 and there is
        // no promise every entry has one. A 404 for the large one is not the
        // record having no cover, and must not be read as one.
        let transport = StubSleeveTransport([
            (match: "ws/2/release", answer: .body(releases(["r1"]))),
            (match: "front-500", answer: .body(TestPictures.jpeg(500))),
        ])
        let resolution = await resolver(transport: transport, cache: SleeveCache(directory: art.url))
            .resolve(request())

        #expect(await resolution.pending?.value?.source == .coverArtArchive)
        // The search, the 1200 that is not there, and the 500 that is — the
        // fallback happens on the same pass rather than after a second round.
        #expect(transport.asked.count == 3)
        #expect(transport.asked.last?.absoluteString.hasSuffix("front-500") == true)
    }

    @Test("An answer that is not a picture is not a cover, whatever the status line said")
    func rubbishIsNotACover() async throws {
        let art = TempDirectory("art")
        let transport = StubSleeveTransport([
            (match: "ws/2/release", answer: .body(releases(["r1", "r2"]))),
            (match: "/r1/", answer: .body(TestPictures.notAPicture)),
            (match: "/r2/", answer: .body(TestPictures.jpeg(500))),
        ])
        let resolution = await resolver(transport: transport, cache: SleeveCache(directory: art.url))
            .resolve(request())

        // The first release is the one nobody ever scanned, or the node serving
        // it is sick; either way the list is walked.
        #expect(await resolution.pending?.value != nil)
        // The search, then r1 twice over at two sizes each, and then r2 answers
        // on its first and largest.
        #expect(transport.asked.count == 6)
    }

    @Test("Five candidates, twice each, and then it gives up")
    func boundedWork() async throws {
        let art = TempDirectory("art")
        let transport = StubSleeveTransport(
            [(match: "ws/2/release", answer: .body(releases(["r1", "r2", "r3", "r4", "r5", "r6"])))],
            otherwise: .body(TestPictures.notAPicture)
        )
        let resolution = await resolver(transport: transport, cache: SleeveCache(directory: art.url))
            .resolve(request())

        #expect(await resolution.pending?.value == nil)
        // One search, then five candidates twice over at two sizes each — the
        // sixth is never asked, because a record with no scan must cost a
        // bounded number of requests. Twenty-one is that bound, and asking for
        // the large size raised it from eleven; it is still a fixed number that
        // no album can make grow.
        #expect(transport.asked.count == 21)
    }

    @Test("Nothing is left half-written")
    func noPartLeftBehind() async throws {
        let art = TempDirectory("art")
        let cache = SleeveCache(directory: art.url)
        let transport = StubSleeveTransport(
            [(match: "ws/2/release", answer: .body(releases(["r1"])))],
            otherwise: .body(TestPictures.notAPicture)
        )
        _ = await resolver(transport: transport, cache: cache).resolve(request()).pending?.value

        #expect(!FileManager.default.fileExists(atPath: cache.part(forKey: "cake-comfort-eagle").path))
        #expect(!cache.hasEntry(forKey: "cake-comfort-eagle"))
    }

    @Test("A record the archive does not have is remembered as not having one")
    func marksNone() async throws {
        let art = TempDirectory("art")
        let cache = SleeveCache(directory: art.url)
        let transport = StubSleeveTransport([], otherwise: .body(Data()))
        _ = await resolver(transport: transport, cache: cache).resolve(request()).pending?.value

        #expect(cache.noneIsFresh(forKey: "cake-comfort-eagle"))
    }

    @Test("§18.4 → D14: a machine that could not ask is not remembered as an answer")
    func offlineIsNotAnAnswer() async throws {
        let art = TempDirectory("art")
        let cache = SleeveCache(directory: art.url)
        _ = await resolver(transport: OfflineSleeveTransport(), cache: cache)
            .resolve(request()).pending?.value

        // Where the script writes the marker regardless, so that the wifi being
        // off once costs the record its sleeve for a fortnight. Nothing on this
        // machine ever reached the catalogue, and a fact about the machine is
        // not a fact about the record.
        #expect(!cache.noneIsFresh(forKey: "cake-comfort-eagle"))
        #expect(!FileManager.default.fileExists(atPath: cache.noneMarker(forKey: "cake-comfort-eagle").path))
    }

    @Test("A search that failed but a cover fetch that answered still counts as an answer")
    func archiveAnswerCounts() async throws {
        let art = TempDirectory("art")
        let cache = SleeveCache(directory: art.url)
        // The disc ID path: no search at all, so only the archive can speak —
        // and it does, with something that is not a picture.
        let transport = StubSleeveTransport([], otherwise: .body(TestPictures.notAPicture))
        _ = await resolver(transport: transport, cache: cache)
            .resolve(request(releaseMBID: "a-release-id")).pending?.value

        #expect(cache.noneIsFresh(forKey: "mbid-a-release-id"))
    }

    @Test("A cancelled fetch never finished asking, so it marks nothing")
    func cancellationMarksNothing() async throws {
        let art = TempDirectory("art")
        let cache = SleeveCache(directory: art.url)
        let resolution = await resolver(
            transport: SlowSleeveTransport(), cache: cache
        ).resolve(request())

        resolution.pending?.cancel()
        _ = await resolution.pending?.value
        #expect(!cache.noneIsFresh(forKey: "cake-comfort-eagle"))
    }

    @Test("A cancelled fetch leaves nothing behind")
    func cancellation() async throws {
        let art = TempDirectory("art")
        let cache = SleeveCache(directory: art.url)
        let resolution = await resolver(
            transport: SlowSleeveTransport(), cache: cache
        ).resolve(request())

        resolution.pending?.cancel()
        #expect(await resolution.pending?.value == nil)
        #expect(!FileManager.default.fileExists(atPath: cache.part(forKey: "cake-comfort-eagle").path))
    }

    // MARK: - Switched off

    @Test("PLAYER_ART=0 looks for nothing at all")
    func disabled() async throws {
        let album = TempDirectory("album")
        let art = TempDirectory("art")
        try album.picture("cover.jpg", side: 600)

        let transport = StubSleeveTransport([], otherwise: .body(releases(["r1"])))
        let resolution = await resolver(
            transport: transport, cache: SleeveCache(directory: art.url), isEnabled: false
        ).resolve(request(directory: album.url))

        #expect(resolution.sleeve == nil)
        #expect(resolution.pending == nil)
        #expect(transport.asked.isEmpty)
    }
}
