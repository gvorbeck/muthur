import Foundation

/// Asking the catalogue what disc this is. §4.3.
///
/// Deliberately forgiving: no network, a disc nobody has ever submitted, a rate
/// limit, half a JSON document — all of them mean the same thing here, which is
/// that the track numbers stay and the panel says so. There is no error, no
/// retry prompt and no diagnostic; the one place any of this is ever reported is
/// `--check` (§11).
public enum MusicBrainzDisc {

    /// 12 s — the shortest of the three, because this is the one the panel is
    /// waiting on (`player:2180`).
    public static let timeout: Duration = .seconds(12)

    public static let endpoint = URL(string: "https://musicbrainz.org/ws/2/discid")!

    public static func url(discID: String) -> URL {
        // A disc ID is base64 in MusicBrainz's own alphabet — `A–Za–z0–9._-`,
        // every character of which is already URL-safe. Nothing to encode, and
        // an ID that somehow is not that shape produces a 404, which is a miss
        // like any other.
        URL(string: "\(endpoint.absoluteString)/\(discID)?fmt=json&inc=recordings+artist-credits")
            ?? endpoint
    }

    // MARK: - The answer

    /// What came back, flattened to the four things anything downstream wants.
    ///
    /// The titles are in **track order**, so the nth is track n — which is not
    /// row n, and the chain is where that gets straightened out.
    public struct Answer: Sendable, Equatable {
        public var album = ""
        public var albumArtist = ""
        public var year = ""
        /// Kept for the sleeve. The Cover Art Archive is keyed on a release, and
        /// a disc ID resolves to one exactly — the strongest identification
        /// anything here ever gets, and worth writing down while we hold it
        /// (`player:2190`).
        public var releaseID = ""
        public var titles: [String] = []
    }

    /// One request, and only one. Nothing is retried on a timeout, and an empty
    /// answer is not retried either: unlike the release search (§5.3), a disc ID
    /// either resolves or it does not, and asking twice cannot change that
    /// (`player:2180`).
    public static func look(up discID: String, transport: some SleeveTransport) async -> Answer? {
        guard case .body(let data) = await transport.get(url(discID: discID), timeout: timeout)
        else { return nil }
        return parse(data, discID: discID)
    }

    // MARK: - Parsing

    /// The jq pipeline at `player:2186`, with D16 applied to which release it
    /// reads from.
    ///
    /// Nil means the document was not a release list at all — the script's
    /// `qgrep '"releases"'` guard. An answer that *is* a release list but has
    /// nothing usable in it comes back as an `Answer` with no titles, which the
    /// chain treats as a failure. The difference matters because album, artist
    /// and year are applied either way, exactly as `player:2213` applies them
    /// before it ever counts the titles.
    public static func parse(_ data: Data, discID: String) -> Answer? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let releases = root["releases"] as? [[String: Any]]
        else { return nil }
        guard let choice = choose(from: releases, discID: discID) else { return Answer() }

        var answer = Answer()
        answer.album = Track.flatten(choice.release["title"] as? String)
        answer.releaseID = (choice.release["id"] as? String) ?? ""
        if let credits = choice.release["artist-credit"] as? [[String: Any]],
            let name = credits.first?["name"] as? String
        {
            answer.albumArtist = Track.flatten(name)
        }
        answer.year = Track.year(from: choice.release["date"] as? String)

        if let medium = choice.medium, let tracks = medium["tracks"] as? [[String: Any]] {
            // `[ -n "$t" ] || continue` before the counter moves, so an empty
            // title is dropped rather than left as a hole and the titles after
            // it shift up a track. That is the script's arithmetic and it has
            // never mattered, because MusicBrainz tracks have titles.
            answer.titles = tracks.compactMap { $0["title"] as? String }
                .map(Track.flatten)
                .filter { !$0.isEmpty }
        }
        return answer
    }

    struct Choice {
        let release: [String: Any]
        let medium: [String: Any]?
    }

    /// Which release, and which of its discs.
    ///
    /// **D16.** The script takes the medium by disc ID and everything else from
    /// `.releases[0]` (`player:2187`, `player:2194`), so a disc ID resolving to
    /// several releases — a reissue sharing a pressing, which is the common case
    /// for a box set — takes its album name and its cover-art key from whichever
    /// one MusicBrainz happened to list first, while its track list comes from a
    /// different entry entirely. Here the release that *contains* the matched
    /// medium is the release, and the whole answer comes out of it.
    ///
    /// The disc IDs are collected and searched rather than filtered through
    /// `select`, because one medium carries several disc IDs for the same
    /// pressing and `select` would emit it once per ID (`player:2198`).
    static func choose(from releases: [[String: Any]], discID: String) -> Choice? {
        for release in releases {
            let media = release["media"] as? [[String: Any]] ?? []
            for medium in media where discIDs(of: medium).contains(discID) {
                return Choice(release: release, medium: medium)
            }
        }
        // Nothing claimed the ID. Fall back to the first release, and to its one
        // medium if it has exactly one — a release with a single medium and no
        // disc IDs listed against it is still that medium, and a single-disc
        // answer is worth taking on its own (`player:2204`). Two or more media
        // and no match is a box set we cannot place this disc in, and taking
        // them all would concatenate disc two's track list onto disc one's.
        guard let first = releases.first else { return nil }
        let media = first["media"] as? [[String: Any]] ?? []
        return Choice(release: first, medium: media.count == 1 ? media[0] : nil)
    }

    private static func discIDs(of medium: [String: Any]) -> [String] {
        (medium["discs"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
    }
}
