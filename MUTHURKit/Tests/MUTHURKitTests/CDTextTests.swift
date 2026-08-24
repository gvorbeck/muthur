import Foundation
import Testing

@testable import MUTHURKit

/// §4.2 — what the disc's lead-in said, and the one rule that makes reading it
/// hard.
@Suite("Disc — CD-Text")
struct CDTextTests {

    // MARK: - The quote rule

    @Test("The shape with an artist")
    func fromShape() {
        let value = CDTextParser.quoted(" 'Robot Stop' from 'King Gizzard'")
        #expect(value == .init(value: "Robot Stop", from: "King Gizzard"))
    }

    @Test("The shape without one")
    func plainShape() {
        let value = CDTextParser.quoted(" 'Robot Stop'")
        #expect(value == .init(value: "Robot Stop", from: nil))
    }

    @Test("An apostrophe in a title, in the shape with an artist")
    func apostropheWithArtist() {
        // The whole reason this is not a scan for the next quote. Taking the
        // next one along gives `Don`, which is a title the disc does not have —
        // and nothing downstream could tell it from a disc that really is called
        // that.
        let value = CDTextParser.quoted("'Don't Stop Me Now' from 'Queen'")
        #expect(value == .init(value: "Don't Stop Me Now", from: "Queen"))
    }

    @Test("An apostrophe in a title, in the shape without one")
    func apostropheAlone() {
        let value = CDTextParser.quoted("'Don't Stop Me Now'")
        #expect(value == .init(value: "Don't Stop Me Now", from: nil))
    }

    @Test("An apostrophe in the artist as well as the title")
    func apostropheBothSides() {
        let value = CDTextParser.quoted("'Rock'n'Roll' from 'Guns N' Roses'")
        #expect(value == .init(value: "Rock'n'Roll", from: "Guns N' Roses"))
    }

    @Test("A title that contains the words ' from ' but has no artist clause")
    func fromInsideTheTitle() {
        // `from` in the middle of a title only ends the value if a well-formed
        // `'…'` follows it to the end of the line. Here nothing does.
        let value = CDTextParser.quoted("'A Message from the Country'")
        #expect(value == .init(value: "A Message from the Country", from: nil))
    }

    @Test("A title that contains a whole quoted from-clause of its own")
    func fromClauseInsideTheTitle() {
        // Greedy, as sed is: the *last* well-formed clause wins, so the earlier
        // one stays inside the title where it belongs.
        let value = CDTextParser.quoted("'Songs from 'Ally McBeal'' from 'Vonda Shepard'")
        #expect(value == .init(value: "Songs from 'Ally McBeal'", from: "Vonda Shepard"))
    }

    @Test("Trailing spaces, which cdrtools pads its columns with")
    func trailingSpaces() {
        #expect(CDTextParser.quoted("  'Robot Stop'   ")?.value == "Robot Stop")
        #expect(CDTextParser.quoted("'X' from 'Y'  ") == .init(value: "X", from: "Y"))
    }

    @Test("An empty value is a value, and an empty artist is an empty artist")
    func empties() {
        #expect(CDTextParser.quoted("''") == .init(value: "", from: nil))
        #expect(CDTextParser.quoted("'X' from ''") == .init(value: "X", from: ""))
    }

    @Test("Nothing quoted at all is not a value")
    func unquoted() {
        #expect(CDTextParser.quoted("Robot Stop") == nil)
        #expect(CDTextParser.quoted("'Robot Stop") == nil)
        #expect(CDTextParser.quoted("") == nil)
        #expect(CDTextParser.quoted("'") == nil)
    }

    // MARK: - Whole listings

    static let withArtists = """
        Album title: 'Nonagon Infinity' from 'King Gizzard'
        Track  1 title: 'Robot Stop' from 'King Gizzard'
        Track  2 title: 'Big Fig Wasp' from 'King Gizzard'
        Track 10 title: 'Road Train' from 'King Gizzard'
        """

    static let withoutArtists = """
        Album title: 'Nonagon Infinity'
        Track  1 title: 'Robot Stop'
        Track  2 title: 'Big Fig Wasp'
        """

    @Test("Both printed shapes, over a whole listing")
    func bothShapes() {
        let a = CDTextParser.parse(CDTextTests.withArtists)
        #expect(a.album == "Nonagon Infinity")
        #expect(a.albumArtist == "King Gizzard")
        #expect(a.titles == [1: "Robot Stop", 2: "Big Fig Wasp", 10: "Road Train"])
        #expect(a.artists[10] == "King Gizzard")

        let b = CDTextParser.parse(CDTextTests.withoutArtists)
        #expect(b.album == "Nonagon Infinity")
        #expect(b.albumArtist == "")
        #expect(b.titles == [1: "Robot Stop", 2: "Big Fig Wasp"])
        #expect(b.artists.isEmpty)
    }

    @Test("Track numbers are read in base ten, leading zeros and all")
    func leadingZeros() {
        let text = CDTextParser.parse("Track 08 title: 'Eight'\nTrack 09 title: 'Nine'")
        #expect(text.titles == [8: "Eight", 9: "Nine"])
    }

    @Test("The noise cdrtools prints around the titles is ignored")
    func noise() {
        let listing = """
            Cdrecord-ProDVD-ProBD-Clone 3.02a09 (arm64-apple-darwin)
            scsidev: 'IODVDServices/0'
            Sectorsize: 2048 Blocks: 164750
            Album title: 'Nonagon Infinity'
            Track  1 title: 'Robot Stop'
            Leadout at sector 164750
            """
        let text = CDTextParser.parse(listing)
        #expect(text.album == "Nonagon Infinity")
        #expect(text.titles == [1: "Robot Stop"])
    }

    @Test("A line with no number is not a track")
    func noNumber() {
        let text = CDTextParser.parse("Track title: 'Nameless'\nTrackXY title: 'Also nameless'")
        #expect(text.titles.isEmpty)
    }

    @Test("Lower-case `track` never gets a number out, so it is not one")
    func caseMatters() {
        // `grep -i` only chooses the lines; every sed that then reads one is
        // case-sensitive, so this is dropped by the script too.
        #expect(CDTextParser.parse("track  1 title: 'Robot Stop'").titles.isEmpty)
    }

    @Test("A shape that does not parse leaves the row alone")
    func unparseableShape() {
        // No quotes at all — the script reads into a local first for exactly
        // this, so the tidy `Track 07` §4.1 already put there is not blanked.
        let text = CDTextParser.parse("Track  1 title: Robot Stop\nTrack  2 title: 'Big Fig Wasp'")
        #expect(text.titles == [2: "Big Fig Wasp"])
    }

    @Test("An empty title is not a title")
    func emptyTitle() {
        #expect(CDTextParser.parse("Track  1 title: ''").titles.isEmpty)
    }

    @Test("The last line wins for a track named twice")
    func duplicateTrack() {
        let text = CDTextParser.parse("Track  1 title: 'First'\nTrack  1 title: 'Second'")
        #expect(text.titles == [1: "Second"])
    }

    @Test("The first Album line settles it, blank or not")
    func firstAlbumLineWins() {
        // `head -1` runs before the emptiness check, so a first line with a
        // blank title leaves the album blank rather than sending the search on.
        let text = CDTextParser.parse("Album title: ''\nAlbum title: 'Nonagon Infinity'")
        #expect(text.album == "")
    }

    @Test("Album and album artist are settled independently")
    func albumArtistFromLaterLine() {
        // The script runs two separate `sed | head -1` pipelines: the album's
        // sees both shapes, the artist's only the one with a `from`.
        let text = CDTextParser.parse(
            "Album title: 'Nonagon Infinity'\nAlbum title: 'Nonagon' from 'King Gizzard'"
        )
        #expect(text.album == "Nonagon Infinity")
        #expect(text.albumArtist == "King Gizzard")
    }

    @Test("Tabs and newlines inside a value are flattened on the way in")
    func flattened() {
        let text = CDTextParser.parse("Track  1 title: 'Robot\tStop'")
        #expect(text.titles == [1: "Robot Stop"])
    }

    @Test("Nothing that looks like CD-Text is nothing")
    func nothing() {
        #expect(CDTextParser.parse("").isEmpty)
        #expect(CDTextParser.parse("cdrecord: No disk / Wrong disk!").isEmpty)
    }
}
