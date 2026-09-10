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

    // MARK: - The shapes a real cdda2wav actually printed

    /// The shape that was missing, and the reason a disc with 742 bytes of
    /// CD-Text on it read as a disc with none.
    @Test("cdda2wav's own track shape, which carries no `title:` at all")
    func bareColonShape() {
        let text = CDTextParser.parse(
            """
            Album title: 'Slippery When Wet (Special Edition)'\t[from Bon Jovi]
            Track  1: 'Let It Rock'
            Track  3: 'Livin' On A Prayer'
            Track 13: 'Wanted Dead Or Alive (Acoutisc Live Version)'
            """)

        #expect(text.album == "Slippery When Wet (Special Edition)")
        #expect(text.albumArtist == "Bon Jovi")
        #expect(text.titles[1] == "Let It Rock")
        // The quote rule holds in this shape too, and this is the title on the
        // disc that proves it: a lazy match gives `Livin`.
        #expect(text.titles[3] == "Livin' On A Prayer")
        #expect(text.titles[13] == "Wanted Dead Or Alive (Acoutisc Live Version)")
    }

    /// The bracket is only an artist clause when it says it is. `[Untitled]` is
    /// a name macOS really writes, and it is the title, not a performer.
    @Test("A title that merely ends in a bracket keeps it")
    func bracketThatIsNotAnArtist() {
        // The body comes back with its leading space still on: trimming the
        // front is the quote rule's job and doing it twice would be two places
        // that have to agree about what a space is.
        let (body, from) = CDTextParser.bracketFrom(" '[Untitled]'")
        #expect(body == " '[Untitled]'")
        #expect(from == nil)

        let text = CDTextParser.parse("Track  8: '[Untitled]'")
        #expect(text.titles[8] == "[Untitled]")
        #expect(text.artists[8] == nil)
    }

    @Test("A bracketed artist on a track line, not just the album line")
    func bracketOnATrack() {
        let text = CDTextParser.parse("Track  2: 'Under Pressure'\t[from Queen]")
        #expect(text.titles[2] == "Under Pressure")
        #expect(text.artists[2] == "Queen")
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

    // MARK: - §18.28, the fallback condition — D43

    /// The three shapes the script and the port agree on, asserted so the
    /// divergence below is known to be the only one.
    @Test("The fallback agrees with the script wherever the script was right")
    func fallbackAgrees() {
        // A capture with real CD-Text in it: neither asks cdrecord.
        let real = "Album title: 'Nonagon Infinity'\nTrack  1 title: 'Robot Stop'"
        #expect(real.lowercased().contains("title"))
        #expect(!DriveCDText.wantsFallback(real))

        // A blank capture — cdda2wav absent, or a disc with nothing to say.
        #expect(DriveCDText.wantsFallback(""))

        // A capture that never says the word at all.
        let quiet = "cdda2wav: No disk / Wrong disk!"
        #expect(!quiet.lowercased().contains("title"))
        #expect(DriveCDText.wantsFallback(quiet))

        // An album title and no tracks still suppresses it, exactly as the grep
        // does. This is the case the narrowing deliberately does *not* widen.
        let albumOnly = "Album title: 'Nonagon Infinity'"
        #expect(!DriveCDText.wantsFallback(albumOnly))
    }

    /// The fault itself. `cdda2wav … -v titles 2>&1` folds stderr in, and the
    /// keyword being passed is the word the grep looks for — so a tool that
    /// failed satisfies the test that exists to notice it failed
    /// (`player:2073`). The script then never asks a working cdrecord, and the
    /// disc degrades exactly as though it had no CD-Text.
    @Test("An error that echoes the keyword no longer suppresses cdrecord")
    func fallbackNarrowed() {
        let banner = """
            cdda2wav: Usage: cdda2wav [options] [-v verbose-level]
            verbose levels: disable, all, toc, summary, titles, sectors
            cdda2wav: Cannot open SCSI driver.
            """
        // The script's test is satisfied, which is the bug.
        #expect(banner.lowercased().contains("title"))
        // Ours is not: nothing in it parses as a CD-Text line, so cdrecord —
        // which may well be working — gets asked after all.
        #expect(DriveCDText.wantsFallback(banner))
    }
}
