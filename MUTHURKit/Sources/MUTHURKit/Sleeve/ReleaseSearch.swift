import Foundation

/// Candidate releases for a record that did not come out of the drive. §5.3.
///
/// A zip or a folder has tags and nothing else, so there is no disc ID to be
/// exact with and the archive has to be asked by name. What comes back is a
/// list rather than an answer, because an album is in MusicBrainz once per
/// pressing — the original, the remaster, the European issue — and cover art is
/// filed against a pressing rather than against an album. The first hit is
/// quite often the one nobody ever scanned, which is why the fetch walks the
/// list (`player:1794`).
public enum ReleaseSearch {

    /// `--data 'limit=5'`. Five pressings is enough to find a scan and few
    /// enough that a record with none costs a bounded number of requests.
    public static let limit = 5

    /// 15 s. Longer than the disc-ID lookup, which the panel is waiting on, and
    /// shorter than the cover fetch, which nothing is (`player:1827`).
    public static let timeout: Duration = .seconds(15)

    public static let endpoint = URL(string: "https://musicbrainz.org/ws/2/release")!

    // MARK: - The query

    /// A quoted-phrase Lucene query, and strict on purpose: asked for an artist
    /// and an album that do not belong together, the catalogue answers with
    /// nothing rather than with its best guess. That is the property this
    /// depends on — a wrong cover drawn confidently beside the panel would be
    /// worse than none (`player:1803`).
    ///
    /// Nil when there is no album, which is the one term that cannot be
    /// dropped.
    public static func lucene(artist: String, album: String) -> String? {
        // The quotes are the syntax holding the phrase together, so a title
        // containing one of its own would close the phrase early and leave the
        // rest of it parsed as query operators (`player:1809`).
        let a = artist.replacingOccurrences(of: "\"", with: "")
        let b = album.replacingOccurrences(of: "\"", with: "")
        guard !b.isEmpty else { return nil }
        return a.isEmpty ? "release:\"\(b)\"" : "artist:\"\(a)\" AND release:\"\(b)\""
    }

    /// `curl -G --data-urlencode` — encoded, not pasted in. Titles carry
    /// ampersands, spaces and question marks, every one of which means
    /// something else in a query string.
    public static func url(query: String) -> URL {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        return URL(string: "\(endpoint.absoluteString)?query=\(encoded)&fmt=json&limit=\(limit)")!
    }

    // MARK: - The ladder

    public struct Attempt: Sendable, Equatable {
        public let artist: String
        public let album: String
    }

    /// What to ask, in order, and only as far as the first answer
    /// (`player:1842`).
    ///
    /// The second and third rungs exist because an untagged folder or zip has
    /// no title, only the name whoever made the file gave it — `Comfort Eagle
    /// (1998) [FLAC]`, `OK_Computer_(Remastered)`. The catalogue is matching a
    /// phrase against a real title, and none of that is in the title, so the
    /// whole query misses on one bracket.
    public static func ladder(albumArtist: String, album: String) -> [Attempt] {
        guard !album.isEmpty else { return [] }
        var rungs = [Attempt(artist: albumArtist, album: album)]

        let bare = stripDecoration(album)
        if !bare.isEmpty, bare != album {
            rungs.append(Attempt(artist: albumArtist, album: bare))
        }
        // The other half of the same convention: the folder is `Artist - Album`,
        // which is both fields inside the one meant to be the title. Only worth
        // trying when there is no album-artist tag standing to contradict it.
        if albumArtist.isEmpty, let separator = bare.range(of: " - ") {
            rungs.append(
                Attempt(
                    artist: String(bare[bare.startIndex..<separator.lowerBound]),
                    album: String(bare[separator.upperBound...])
                )
            )
        }
        return rungs
    }

    /// `sed -E 's/[[({][^])}]*[])}]//g; s/_+/ /g; s/  +/ /g; s/^ +//; s/ +$//'`.
    ///
    /// Bracketed anything goes, underscores become spaces, and the runs the
    /// first two leave behind are collapsed. An opening bracket with no closer
    /// after it is left alone, exactly as the pattern leaves it.
    public static func stripDecoration(_ album: String) -> String {
        var out = ""
        let characters = Array(album)
        var i = 0
        while i < characters.count {
            let c = characters[i]
            if c == "[" || c == "(" || c == "{" {
                var j = i + 1
                while j < characters.count, !")]}".contains(characters[j]) { j += 1 }
                if j < characters.count {
                    i = j + 1
                    continue
                }
            }
            out.append(c)
            i += 1
        }

        var collapsed = ""
        var spaces = 0
        for c in out {
            if c == "_" || c == " " {
                spaces += 1
            } else {
                if spaces > 0 { collapsed.append(" ") }
                spaces = 0
                collapsed.append(c)
            }
        }
        if spaces > 0 { collapsed.append(" ") }
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: " "))
    }

    // MARK: - Asking

    /// What came back, and whether anything came back at all.
    ///
    /// The two are different questions and §18.4 is the whole reason they are
    /// kept apart: a catalogue that answered "no such release" has told us
    /// something about the record, and a machine whose wifi is off has told us
    /// something about the machine. Both arrive as no release IDs.
    public struct Outcome: Sendable, Equatable {
        public let releaseIDs: [String]
        /// True once anything at the far end has said anything — including a
        /// rate-limit page or an error document, because those are the far end
        /// and they did answer. False only where nothing on this machine ever
        /// reached it (D14).
        public let heard: Bool

        public init(releaseIDs: [String], heard: Bool) {
            self.releaseIDs = releaseIDs
            self.heard = heard
        }
    }

    /// Release IDs, best first, or empty.
    ///
    /// Each rung is asked **twice, a second apart**. An empty answer is at
    /// least as often the rate limiter or a timed-out search index as it is the
    /// catalogue: MusicBrainz allows about a request a second and says so with
    /// a 503 whose body is an error rather than a release list, and both of
    /// those arrive here as no results and are usually gone a second later
    /// (`player:1815`). A pairing that genuinely is not in the catalogue
    /// answers twice over, which costs one spare request on a record that was
    /// never going to have a cover anyway.
    public static func releaseIDs(
        albumArtist: String,
        album: String,
        transport: some SleeveTransport,
        retryDelay: Duration = .seconds(1)
    ) async -> Outcome {
        var heard = false
        for attempt in ladder(albumArtist: albumArtist, album: album) {
            guard let query = lucene(artist: attempt.artist, album: attempt.album) else {
                continue
            }
            for _ in 1...2 {
                if Task.isCancelled { return Outcome(releaseIDs: [], heard: heard) }
                let answer = await transport.get(url(query: query), timeout: timeout)
                if case .body(let data) = answer {
                    // Anything at all, even an empty body or an error document:
                    // the catalogue is there and it is talking to us.
                    heard = true
                    let ids = parse(data)
                    if !ids.isEmpty { return Outcome(releaseIDs: ids, heard: true) }
                }
                // The script sleeps after the *second* try as well, so the
                // second falls a second after the first and the next rung falls
                // a second after that. Both are the same second, and the
                // catalogue's rate limiter is the reason for both.
                if retryDelay > .zero { try? await Task.sleep(for: retryDelay) }
            }
        }
        return Outcome(releaseIDs: [], heard: heard)
    }

    /// `jq -r '.releases[]?.id // empty'`. Anything that is not that shape —
    /// an error document, a rate-limit page, half a response — is no results,
    /// which is the same thing as no releases and is handled the same way.
    public static func parse(_ data: Data) -> [String] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let releases = root["releases"] as? [[String: Any]]
        else { return [] }
        return releases.compactMap { $0["id"] as? String }.filter { !$0.isEmpty }
    }
}
