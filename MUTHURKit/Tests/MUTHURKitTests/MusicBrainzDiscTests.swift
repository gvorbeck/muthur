import Foundation
import Testing

@testable import MUTHURKit

/// §4.3, §4.4 — asking the catalogue what disc this is, and which of its answers
/// to believe.
@Suite("Disc — the MusicBrainz lookup")
struct MusicBrainzDiscTests {

    static let discID = "ybYRHGr1rfATUisnRFX8rjrtKec-"
    static let otherDiscID = "J5VseIjrnogYWZ4AcpTUXMOI.XY-"

    static func medium(discIDs: [String], titles: [String]) -> [String: Any] {
        [
            "discs": discIDs.map { ["id": $0] },
            "tracks": titles.map { ["title": $0] },
        ]
    }

    static func release(
        id: String, title: String, artist: String = "King Gizzard", date: String = "2016-04-29",
        media: [[String: Any]]
    ) -> [String: Any] {
        [
            "id": id,
            "title": title,
            "artist-credit": [["name": artist]],
            "date": date,
            "media": media,
        ]
    }

    static func json(_ releases: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["releases": releases])
    }

    // MARK: - The request

    @Test("The disc-ID endpoint, with recordings and artist credits")
    func url() {
        let url = MusicBrainzDisc.url(discID: MusicBrainzDiscTests.discID).absoluteString
        #expect(
            url == "https://musicbrainz.org/ws/2/discid/ybYRHGr1rfATUisnRFX8rjrtKec-"
                + "?fmt=json&inc=recordings+artist-credits"
        )
    }

    @Test("Twelve seconds, because the panel is waiting on this one")
    func timeout() {
        #expect(MusicBrainzDisc.timeout == .seconds(12))
        // Shorter than the release search and much shorter than the cover fetch,
        // deliberately and per-endpoint.
        #expect(MusicBrainzDisc.timeout < ReleaseSearch.timeout)
    }

    @Test("Asked twice and no more, whatever the unusable answer was — D81")
    func askedTwice() async {
        // This read "asked exactly once" until a MusicBrainz shedding load
        // answered five of ten hand-run queries with a 503 and the disc played
        // as Track 01 … Track 13. Two tries, and the second is the whole point;
        // a third would be the first one that makes a disc nobody knows feel
        // slow. An empty body and a refusal are the same thing from here — see
        // D81 on why the status line is not consulted.
        let empty = StubSleeveTransport([], otherwise: .body(Data()))
        _ = await MusicBrainzDisc.look(
            up: MusicBrainzDiscTests.discID, transport: empty, retryDelay: .zero
        )
        #expect(empty.asked.count == 2)

        let unreachable = StubSleeveTransport([], otherwise: .couldNotAsk)
        _ = await MusicBrainzDisc.look(
            up: MusicBrainzDiscTests.discID, transport: unreachable, retryDelay: .zero
        )
        #expect(unreachable.asked.count == 2)
    }

    @Test("An answer that parses is not asked for twice")
    func askedOnceWhenAnswered() async {
        let transport = StubSleeveTransport(
            [],
            otherwise: .body(
                MusicBrainzDiscTests.json([
                    MusicBrainzDiscTests.release(
                        id: "rel-1", title: "Nonagon Infinity",
                        media: [
                            MusicBrainzDiscTests.medium(
                                discIDs: [MusicBrainzDiscTests.discID], titles: ["Robot Stop"]
                            )
                        ]
                    )
                ])
            )
        )
        let answer = await MusicBrainzDisc.look(
            up: MusicBrainzDiscTests.discID, transport: transport, retryDelay: .zero
        )
        #expect(answer?.album == "Nonagon Infinity")
        #expect(transport.asked.count == 1)
    }

    @Test("A machine that could not ask gets the same nothing as one that did")
    func offline() async {
        let answer = await MusicBrainzDisc.look(
            up: MusicBrainzDiscTests.discID, transport: OfflineSleeveTransport(),
            retryDelay: .zero
        )
        #expect(answer == nil)
    }

    // MARK: - Parsing

    @Test("Title, artist credit, date and the release MBID")
    func fields() {
        let data = MusicBrainzDiscTests.json([
            MusicBrainzDiscTests.release(
                id: "rel-1", title: "Nonagon Infinity",
                media: [
                    MusicBrainzDiscTests.medium(
                        discIDs: [MusicBrainzDiscTests.discID],
                        titles: ["Robot Stop", "Big Fig Wasp"]
                    )
                ]
            )
        ])
        let answer = MusicBrainzDisc.parse(data, discID: MusicBrainzDiscTests.discID)
        #expect(answer?.album == "Nonagon Infinity")
        #expect(answer?.albumArtist == "King Gizzard")
        #expect(answer?.year == "2016")
        #expect(answer?.releaseID == "rel-1")
        #expect(answer?.titles == ["Robot Stop", "Big Fig Wasp"])
    }

    @Test("The medium is the one the disc ID asked about, not all of them")
    func mediumByDiscID() {
        // A release is one entry per disc in the box. Taking them all
        // concatenates disc two's track list onto disc one's, and the chain then
        // hands disc one's titles to whichever disc is in the drive.
        let data = MusicBrainzDiscTests.json([
            MusicBrainzDiscTests.release(
                id: "box", title: "The Box",
                media: [
                    MusicBrainzDiscTests.medium(
                        discIDs: [MusicBrainzDiscTests.otherDiscID], titles: ["One", "Two"]
                    ),
                    MusicBrainzDiscTests.medium(
                        discIDs: [MusicBrainzDiscTests.discID], titles: ["Three", "Four"]
                    ),
                ]
            )
        ])
        let answer = MusicBrainzDisc.parse(data, discID: MusicBrainzDiscTests.discID)
        #expect(answer?.titles == ["Three", "Four"])
    }

    @Test("A medium carrying the same ID twice is still one medium")
    func mediumListedOnce() {
        // Bracketed and indexed rather than `select`-piped: one medium carries
        // several disc IDs for the same pressing, and `select` would emit it
        // once per ID (`player:2198`).
        let data = MusicBrainzDiscTests.json([
            MusicBrainzDiscTests.release(
                id: "rel", title: "Album",
                media: [
                    MusicBrainzDiscTests.medium(
                        discIDs: [
                            MusicBrainzDiscTests.discID, "other", MusicBrainzDiscTests.discID,
                        ],
                        titles: ["One", "Two"]
                    )
                ]
            )
        ])
        #expect(MusicBrainzDisc.parse(data, discID: MusicBrainzDiscTests.discID)?.titles == [
            "One", "Two",
        ])
    }

    @Test("D16 — the release that holds the matched medium is the release")
    func releaseHoldingTheMedium() {
        // The script takes the medium by disc ID and everything else from
        // `.releases[0]`, so this answer would come back titled `The Wrong One`
        // with the wrong cover-art key, and a track list off a different entry.
        let data = MusicBrainzDiscTests.json([
            MusicBrainzDiscTests.release(
                id: "wrong", title: "The Wrong One", date: "1999-01-01",
                media: [
                    MusicBrainzDiscTests.medium(discIDs: ["nope"], titles: ["Not this"])
                ]
            ),
            MusicBrainzDiscTests.release(
                id: "right", title: "Nonagon Infinity",
                media: [
                    MusicBrainzDiscTests.medium(
                        discIDs: [MusicBrainzDiscTests.discID], titles: ["Robot Stop"]
                    )
                ]
            ),
        ])
        let answer = MusicBrainzDisc.parse(data, discID: MusicBrainzDiscTests.discID)
        #expect(answer?.album == "Nonagon Infinity")
        #expect(answer?.releaseID == "right")
        #expect(answer?.year == "2016")
        #expect(answer?.titles == ["Robot Stop"])
    }

    @Test("One medium with no disc IDs listed is still that medium")
    func singleMediumFallback() {
        let data = MusicBrainzDiscTests.json([
            MusicBrainzDiscTests.release(
                id: "rel", title: "Album",
                media: [MusicBrainzDiscTests.medium(discIDs: [], titles: ["One", "Two"])]
            )
        ])
        #expect(MusicBrainzDisc.parse(data, discID: MusicBrainzDiscTests.discID)?.titles == [
            "One", "Two",
        ])
    }

    @Test("Several media and none of them ours is no track list")
    func noMediumMatched() {
        let data = MusicBrainzDiscTests.json([
            MusicBrainzDiscTests.release(
                id: "box", title: "The Box",
                media: [
                    MusicBrainzDiscTests.medium(discIDs: ["a"], titles: ["One"]),
                    MusicBrainzDiscTests.medium(discIDs: ["b"], titles: ["Two"]),
                ]
            )
        ])
        let answer = MusicBrainzDisc.parse(data, discID: MusicBrainzDiscTests.discID)
        // Named, because album and artist are still worth having.
        #expect(answer?.album == "The Box")
        #expect(answer?.titles.isEmpty == true)
    }

    @Test("An empty title is dropped rather than left as a hole")
    func emptyTitles() {
        let data = MusicBrainzDiscTests.json([
            MusicBrainzDiscTests.release(
                id: "rel", title: "Album",
                media: [
                    MusicBrainzDiscTests.medium(
                        discIDs: [MusicBrainzDiscTests.discID], titles: ["One", "", "Three"]
                    )
                ]
            )
        ])
        // The script's counter moves only for non-empty titles, so `Three`
        // becomes track two. Ported as found — MusicBrainz tracks have titles,
        // and this has never arisen.
        #expect(MusicBrainzDisc.parse(data, discID: MusicBrainzDiscTests.discID)?.titles == [
            "One", "Three",
        ])
    }

    @Test("Anything that is not a release list is not an answer")
    func rubbish() {
        #expect(MusicBrainzDisc.parse(Data(), discID: "x") == nil)
        #expect(MusicBrainzDisc.parse(Data("<html>503</html>".utf8), discID: "x") == nil)
        #expect(MusicBrainzDisc.parse(Data(#"{"error":"not found"}"#.utf8), discID: "x") == nil)
    }

    @Test("A release list with nothing in it is an answer with nothing in it")
    func noReleases() {
        // Distinct from the line above: the catalogue answered, in the right
        // shape, about a disc it has never been told about.
        #expect(MusicBrainzDisc.parse(Data(#"{"releases":[]}"#.utf8), discID: "x") == .init())
    }
}
