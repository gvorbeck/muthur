import Foundation

/// The picture beside the panel, and where it came from. §5.
public struct Sleeve: Sendable, Equatable {

    /// The three places a sleeve can come from, in the order they are tried.
    /// Worth keeping on the value for the same reason §4 keeps the metadata
    /// source on the faceplate: a picture is only as good as where it came
    /// from, and this one is the difference between the artwork this copy
    /// shipped with and a scan of whichever pressing the album *name* matched.
    public enum Source: String, Sendable, Equatable {
        case besideTheRecord
        case tags
        case coverArtArchive
    }

    public let url: URL
    public let source: Source

    public init(url: URL, source: Source) {
        self.url = url
        self.source = source
    }

    /// What the panel does with a picture that will not decode. §5.2.
    ///
    /// It will not decode next second either, so stop asking — and it is
    /// *cleared*, not deleted, because another player may be part way through
    /// writing that very file (`player:3162`). A function that returns nothing
    /// and touches nothing is the whole of the rule: what it is here to forbid
    /// is the `rm` that looks obvious at the call site.
    public func discarded() -> Sleeve? { nil }
}

/// The resolution order, and it is deliberate. §5.
///
/// 1. A picture **beside the record** — preferred to the network, because it is
///    the artwork this copy shipped with (`player:2020`).
/// 2. A picture **in the tags** — the attached-pic stream, only the first three
///    tracks asked, because a record that tags its artwork tags it on track one
///    (`player:2025`).
/// 3. **The Cover Art Archive**, in the background, cached (`player:2035`).
///
/// **Nothing ever waits for the third.** No cover, no network, no window — the
/// panel is exactly the panel it would have been (`player:1892`). `resolve`
/// touches the filesystem and returns; the fetch is a task nothing joins, and
/// the picture appears when it appears, or never, and either way the record is
/// playing.
public struct SleeveResolver: Sendable {
    public var probe: any PictureProbe
    public var embedded: any EmbeddedPictureReader
    public var transport: any SleeveTransport
    public var cache: SleeveCache
    /// `PLAYER_ART=0` (§13). Off means no picture is looked for at all — not
    /// looked for and hidden.
    public var isEnabled: Bool
    /// Injected so §5.3's "a second apart" can be asserted rather than waited
    /// through.
    public var retryDelay: Duration
    /// Injected so the fortnight in §5.2 can be tested without one.
    public var now: @Sendable () -> Date

    public init(
        probe: any PictureProbe = ImageIOPictureProbe(),
        embedded: any EmbeddedPictureReader = ChainedEmbeddedPictureReader.standard(),
        transport: any SleeveTransport = URLSessionSleeveTransport(),
        cache: SleeveCache = .standard(),
        isEnabled: Bool = true,
        retryDelay: Duration = .seconds(1),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.probe = probe
        self.embedded = embedded
        self.transport = transport
        self.cache = cache
        self.isEnabled = isEnabled
        self.retryDelay = retryDelay
        self.now = now
    }

    // MARK: - What is being asked about

    public struct Request: Sendable {
        /// The album directory, where a picture might be lying. Nil for a
        /// source that has no directory of its own.
        public let directory: URL?
        /// The record's files, in the order they play. Only the first three are
        /// ever opened.
        public let files: [URL]
        public let album: String
        public let albumArtist: String
        /// The release MBID when a disc gave us one. It names a pressing
        /// exactly, which is both the best cache key there is and the only
        /// candidate worth asking the archive about (§4.3).
        public let releaseMBID: String?
        /// Where an embedded picture is written. The scratch directory, which
        /// goes when the app does — a picture out of a tag is not a file
        /// anybody asked to keep.
        public let scratch: URL?

        public init(
            directory: URL?,
            files: [URL],
            album: String,
            albumArtist: String,
            releaseMBID: String? = nil,
            scratch: URL? = nil
        ) {
            self.directory = directory
            self.files = files
            self.album = album
            self.albumArtist = albumArtist
            self.releaseMBID = releaseMBID
            self.scratch = scratch
        }

        /// The record as §3 read it. The running order is what is handed over,
        /// because the three tracks worth asking are the first three you hear.
        public init(
            record: Record,
            directory: URL?,
            releaseMBID: String? = nil,
            scratch: URL? = nil
        ) {
            self.init(
                directory: directory,
                files: record.running.map(\.url),
                album: record.album,
                albumArtist: record.albumArtist,
                releaseMBID: releaseMBID,
                scratch: scratch
            )
        }
    }

    /// What the panel has now, and what may yet turn up.
    public struct Resolution: Sendable {
        /// Drawn on the next frame, or nil and the panel simply has no sleeve.
        public let sleeve: Sleeve?
        /// The archive, running behind. **Nothing joins this** — it is here so
        /// that teardown can cancel it and so that a test can be deliberate
        /// about waiting. Awaiting it from the panel would be the one thing §5
        /// forbids.
        public let pending: Task<Sleeve?, Never>?

        public init(sleeve: Sleeve?, pending: Task<Sleeve?, Never>? = nil) {
            self.sleeve = sleeve
            self.pending = pending
        }
    }

    // MARK: - Resolving

    /// Steps 1 and 2 happen here, on the filesystem, before the panel's first
    /// frame — which is where the script does them too. Step 3 is started and
    /// left running.
    ///
    /// `onArrival` is how a cover that turned up late reaches the panel. It is
    /// a callback rather than a return value because there is nowhere for a
    /// return value to go: by the time the archive answers, the record has been
    /// playing for several seconds.
    public func resolve(
        _ request: Request,
        onArrival: (@Sendable (Sleeve) -> Void)? = nil
    ) async -> Resolution {
        guard isEnabled else { return Resolution(sleeve: nil) }

        // A file beside the record before a picture in its tags, because a
        // folder that has both usually has the scan in the file and the
        // thumbnail in the tag. When it is the other way round the size floor
        // catches it: the small one is refused and the next candidate is tried
        // (`player:2017`).
        if let directory = request.directory,
            let found = BesideTheRecord.find(in: directory, probe: probe)
        {
            return Resolution(sleeve: Sleeve(url: found, source: .besideTheRecord))
        }

        if let found = await embeddedPicture(request) {
            return Resolution(sleeve: Sleeve(url: found, source: .tags))
        }

        // Everything below this line is the network, and none of it is allowed
        // to be waited on.
        guard !request.album.isEmpty,
            let key = SleeveCache.key(
                releaseMBID: request.releaseMBID,
                albumArtist: request.albumArtist,
                album: request.album
            ),
            cache.makeDirectory()
        else { return Resolution(sleeve: nil) }

        // Already on disk from a previous session, or already known not to
        // exist. Either way there is nothing to ask (`player:2032`).
        if cache.hasEntry(forKey: key) {
            return Resolution(sleeve: Sleeve(url: cache.file(forKey: key), source: .coverArtArchive))
        }
        if cache.noneIsFresh(forKey: key, now: now()) {
            return Resolution(sleeve: nil)
        }

        let pending = Task<Sleeve?, Never> {
            let sleeve = await fetch(request, key: key)
            if let sleeve { onArrival?(sleeve) }
            return sleeve
        }
        return Resolution(sleeve: nil, pending: pending)
    }

    // MARK: - The tags

    /// Only the first three tracks are asked. A record that tags its artwork
    /// tags it on track one, and this runs before the panel's first frame,
    /// where opening every file on a long album would be felt (`player:2025`).
    private func embeddedPicture(_ request: Request) async -> URL? {
        guard let scratch = request.scratch else { return nil }
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let out = scratch.appending(path: "embedded")
        for file in request.files.prefix(3) {
            guard let data = await embedded.picture(of: file), !data.isEmpty else { continue }
            try? FileManager.default.removeItem(at: out)
            guard (try? data.write(to: out)) != nil else { continue }
            // The same 200 px floor as a picture beside the record, and for the
            // same reason: a tag holding a 90×90 thumbnail is worse than the
            // archive answer it would displace.
            if probe.isPicture(out, minimumSide: BesideTheRecord.minimumSide) { return out }
        }
        try? FileManager.default.removeItem(at: out)
        return nil
    }

    // MARK: - The archive

    /// 25 s, the longest of the three timeouts in the program, because this is
    /// a redirect chain to an Internet Archive node and nothing is waiting on
    /// it (`player:1915`).
    public static let coverTimeout: Duration = .seconds(25)

    public static func coverURL(releaseID: String) -> URL? {
        URL(string: "https://coverartarchive.org/release/\(releaseID)/front-500")
    }

    /// Every part of this is allowed to fail and none of it is allowed to be
    /// noticed (`player:1888`).
    func fetch(_ request: Request, key: String) async -> Sleeve? {
        let ids: [String]
        // D14. Set the moment anything at the far end says anything, and the
        // only thing that earns the right to write the marker below.
        var heard = false
        if let mbid = request.releaseMBID, !mbid.isEmpty {
            // A disc ID resolves to one release exactly, which is the strongest
            // identification anything here ever gets. Nothing to search for —
            // and so nothing has been heard from yet either.
            ids = [mbid]
        } else {
            let outcome = await ReleaseSearch.releaseIDs(
                albumArtist: request.albumArtist,
                album: request.album,
                transport: transport,
                retryDelay: retryDelay
            )
            ids = outcome.releaseIDs
            heard = outcome.heard
        }

        for id in ids.prefix(ReleaseSearch.limit) {
            guard let url = SleeveResolver.coverURL(releaseID: id) else { continue }
            // Twice per candidate. A first failure is more often a sick archive
            // node than a missing cover, and the redirect lands on a different
            // node next time (`player:1911`).
            for _ in 1...2 {
                if Task.isCancelled {
                    cache.removePart(forKey: key)
                    return nil
                }
                guard case .body(let data) = await transport.get(url, timeout: Self.coverTimeout)
                else { continue }
                // An empty body, an error page, a 404: all of them are the
                // archive answering, and all of them count.
                heard = true
                guard !data.isEmpty, let part = cache.writePart(data, forKey: key) else { continue }
                // No floor here. The archive only ever sends one size, so the
                // only question is whether a decoder can read the bytes — which
                // an nginx error page served under a 200 and labelled
                // `image/jpeg` cannot (`player:1858`).
                guard probe.isPicture(part), let file = cache.commitPart(forKey: key) else {
                    continue
                }
                return Sleeve(url: file, source: .coverArtArchive)
            }
        }

        cache.removePart(forKey: key)
        // §18.4, answered by D14: the marker means "asked, and there is none",
        // not "could not ask". The script writes it whatever happened, so on the
        // script the wifi being off once costs the record its sleeve for a
        // fortnight — a fact about the machine remembered as a fact about the
        // record. Only a far end that actually said something gets to do that,
        // and a cancelled fetch never finished asking.
        if heard, !Task.isCancelled { cache.markNone(forKey: key) }
        return nil
    }
}
