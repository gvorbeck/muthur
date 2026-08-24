import Foundation
import Testing

@testable import MUTHURKit

/// §5.3 — asking the catalogue by name, which is what a record that did not come
/// out of the drive has to do.
@Suite("Sleeve — the release search")
struct ReleaseSearchTests {

    private func releases(_ ids: [String]) -> Data {
        let objects = ids.map { ["id": $0, "title": "whatever"] }
        return try! JSONSerialization.data(withJSONObject: ["releases": objects])
    }

    // MARK: - The query

    @Test("A quoted-phrase Lucene query over both fields")
    func lucene() {
        #expect(
            ReleaseSearch.lucene(artist: "Cake", album: "Comfort Eagle")
                == "artist:\"Cake\" AND release:\"Comfort Eagle\""
        )
    }

    @Test("With no artist, the title alone")
    func luceneWithoutArtist() {
        #expect(ReleaseSearch.lucene(artist: "", album: "Kid A") == "release:\"Kid A\"")
    }

    @Test("With no title there is nothing to ask")
    func luceneWithoutAlbum() {
        #expect(ReleaseSearch.lucene(artist: "Cake", album: "") == nil)
    }

    @Test("A quote in a title is stripped, not escaped")
    func luceneQuotes() {
        // The quotes are the syntax holding the phrase together; one of its own
        // would close the phrase early and leave the rest parsed as operators.
        #expect(
            ReleaseSearch.lucene(artist: "Weezer", album: "\"The Blue Album\"")
                == "artist:\"Weezer\" AND release:\"The Blue Album\""
        )
    }

    @Test("Everything but the unreserved set is percent-encoded")
    func encoding() {
        let url = ReleaseSearch.url(query: "artist:\"Simon & Garfunkel\" AND release:\"Bookends?\"")
        let string = url.absoluteString
        #expect(string.hasPrefix("https://musicbrainz.org/ws/2/release?query="))
        #expect(string.contains("%26"))  // the ampersand, which would end the parameter
        #expect(string.contains("%22"))  // the quotes
        #expect(string.contains("%20"))  // the spaces
        #expect(string.contains("%3F"))  // the question mark
        #expect(string.hasSuffix("&fmt=json&limit=5"))
    }

    @Test("Five candidates, and fifteen seconds to find them")
    func settings() {
        #expect(ReleaseSearch.limit == 5)
        #expect(ReleaseSearch.timeout == .seconds(15))
    }

    // MARK: - Decoration

    @Test("Brackets, underscores and the runs they leave behind")
    func stripDecoration() {
        #expect(ReleaseSearch.stripDecoration("Comfort Eagle (1998) [FLAC]") == "Comfort Eagle")
        #expect(ReleaseSearch.stripDecoration("OK_Computer_(Remastered)") == "OK Computer")
        #expect(ReleaseSearch.stripDecoration("{Deluxe} Kid A") == "Kid A")
        #expect(ReleaseSearch.stripDecoration("A  B") == "A B")
    }

    @Test("An opening bracket with no closer is left alone")
    func unbalanced() {
        #expect(ReleaseSearch.stripDecoration("Comfort Eagle (1998") == "Comfort Eagle (1998")
    }

    // MARK: - The ladder

    @Test("A tagged record asks once")
    func oneRung() {
        #expect(
            ReleaseSearch.ladder(albumArtist: "Cake", album: "Comfort Eagle")
                == [.init(artist: "Cake", album: "Comfort Eagle")]
        )
    }

    @Test("A decorated title is asked again bare")
    func secondRung() {
        #expect(
            ReleaseSearch.ladder(albumArtist: "Cake", album: "Comfort Eagle (1998) [FLAC]")
                == [
                    .init(artist: "Cake", album: "Comfort Eagle (1998) [FLAC]"),
                    .init(artist: "Cake", album: "Comfort Eagle"),
                ]
        )
    }

    @Test("An untagged folder called Artist - Album is split, on the first dash")
    func thirdRung() {
        let rungs = ReleaseSearch.ladder(albumArtist: "", album: "Cake - Comfort Eagle [FLAC]")
        #expect(rungs.count == 3)
        #expect(rungs.last == .init(artist: "Cake", album: "Comfort Eagle"))
    }

    @Test("Splitting on the first dash, so a hyphenated title survives")
    func splitsOnce() {
        let rungs = ReleaseSearch.ladder(albumArtist: "", album: "Godflesh - Pure - Live")
        #expect(rungs.last == .init(artist: "Godflesh", album: "Pure - Live"))
    }

    @Test("An album-artist tag stands, so the folder name is not second-guessed")
    func noSplitWhenTagged() {
        // `Cake - Comfort Eagle` tagged to Cake would otherwise be re-read as
        // artist `Cake`, album `Comfort Eagle`, which is right — and as artist
        // `Nine Inch Nails`, album `The Downward Spiral` for a record actually
        // called `Nine Inch Nails - The Downward Spiral`, which is not the risk
        // worth taking against a tag that says otherwise.
        let rungs = ReleaseSearch.ladder(albumArtist: "Cake", album: "Cake - Comfort Eagle")
        #expect(rungs == [.init(artist: "Cake", album: "Cake - Comfort Eagle")])
    }

    @Test("No title, no ladder")
    func noAlbum() {
        #expect(ReleaseSearch.ladder(albumArtist: "Cake", album: "").isEmpty)
    }

    // MARK: - Parsing

    @Test("Release IDs in the order the catalogue ranked them")
    func parse() {
        #expect(ReleaseSearch.parse(releases(["a", "b", "c"])) == ["a", "b", "c"])
    }

    @Test("Anything that is not a release list is no results")
    func parseRubbish() {
        #expect(ReleaseSearch.parse(Data()).isEmpty)
        #expect(ReleaseSearch.parse(Data("<html>503 Service Unavailable</html>".utf8)).isEmpty)
        #expect(ReleaseSearch.parse(Data(#"{"error":"rate limited"}"#.utf8)).isEmpty)
        #expect(ReleaseSearch.parse(Data(#"{"releases":[{"title":"no id"}]}"#.utf8)).isEmpty)
    }

    // MARK: - Asking

    @Test("Each rung is asked twice before the next is tried")
    func askedTwice() async {
        let transport = StubSleeveTransport([], otherwise: .body(Data()))
        let outcome = await ReleaseSearch.releaseIDs(
            albumArtist: "", album: "Cake - Comfort Eagle [FLAC]",
            transport: transport, retryDelay: .zero
        )
        #expect(outcome.releaseIDs.isEmpty)
        // Empty, but answered — six times over.
        #expect(outcome.heard)
        // Three rungs, twice each. The retry is there because a rate-limit 503
        // and a genuinely absent record are the same empty answer here, and one
        // of the two is usually gone a second later.
        #expect(transport.asked.count == 6)
    }

    @Test("The first answer stops the ladder")
    func firstAnswerWins() async {
        let transport = StubSleeveTransport([], otherwise: .body(releases(["found"])))
        let outcome = await ReleaseSearch.releaseIDs(
            albumArtist: "", album: "Cake - Comfort Eagle [FLAC]",
            transport: transport, retryDelay: .zero
        )
        #expect(outcome.releaseIDs == ["found"])
        #expect(outcome.heard)
        #expect(transport.asked.count == 1)
    }

    @Test("A rung that misses falls through to the next, which hits")
    func secondRungHits() async {
        // The decorated title is not what the catalogue calls the record; the
        // bare one is.
        let transport = StubSleeveTransport(
            [(match: "FLAC", answer: .body(Data()))],
            otherwise: .body(releases(["bare"]))
        )
        let outcome = await ReleaseSearch.releaseIDs(
            albumArtist: "Cake", album: "Comfort Eagle [FLAC]",
            transport: transport, retryDelay: .zero
        )
        #expect(outcome.releaseIDs == ["bare"])
        #expect(transport.asked.count == 3)
    }

    @Test("A machine with its wifi off never gets as far as asking")
    func offline() async {
        let outcome = await ReleaseSearch.releaseIDs(
            albumArtist: "Cake", album: "Comfort Eagle",
            transport: OfflineSleeveTransport(), retryDelay: .zero
        )
        #expect(outcome.releaseIDs.isEmpty)
        // The distinction D14 rests on: no results, and nothing said them.
        #expect(!outcome.heard)
    }

    @Test("One rung answering is enough to have been heard, even if the rest cannot")
    func partlyHeard() async {
        // The wifi comes back for one request and goes again. Something at the
        // far end did speak, and D14 only asks whether anything did.
        let transport = StubSleeveTransport(
            [(match: "FLAC", answer: .body(Data()))],
            otherwise: .couldNotAsk
        )
        let outcome = await ReleaseSearch.releaseIDs(
            albumArtist: "Cake", album: "Comfort Eagle [FLAC]",
            transport: transport, retryDelay: .zero
        )
        #expect(outcome.releaseIDs.isEmpty)
        #expect(outcome.heard)
    }

    // MARK: - The header

    @Test("One User-Agent string, and it identifies this program")
    func userAgent() {
        // §4.3 — MusicBrainz refuses an anonymous client, and the archive is
        // entitled to know who is asking.
        #expect(MUTHUR.userAgent.hasPrefix("MUTHUR/"))
        #expect(MUTHUR.userAgent.contains(MUTHUR.contact))
    }
}
