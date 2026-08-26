import Foundation
import Testing

@testable import MUTHURKit

/// §8 — the collection annotation, the rules tier.
///
/// Every catalogue here is a string written by the test. The real one is read
/// in `CatalogueMaterialTests` and is never written to by anything in this
/// suite — `cd-collection` is read-only, always (`CLAUDE.md`, D5).
struct CatalogueTests {

    /// The header as the file carries it today (§8). Recorded as a fact about
    /// the file rather than as an assumption: columns are still found by name,
    /// and a renamed or missing one still means the panel is exactly what it
    /// would have been.
    static let header = "Number,Book,Artist,Title,Year,Parent Genre,Tags,Art URL,Notes,Barcode"

    static func catalogue(_ rows: String...) -> Catalogue {
        Catalogue(csv: ([header] + rows).joined(separator: "\n") + "\n")
    }

    /// A one-track record with no year in its tags, so the shelf's year is the
    /// only one in play.
    static func record(album: String = "Cut", artist: String = "The Slits", year: String = "")
        -> Record
    {
        Record(
            tracks: [
                Track(
                    url: URL(fileURLWithPath: "/x/1.flac"), duration: 100, title: "One",
                    artist: artist, number: 1, disc: 1)
            ],
            album: album, albumArtist: artist, year: year, sourceLabel: album)
    }

    // MARK: - The CSV walk (`player:1663`)

    @Test func quotedFieldKeepsItsCommas() {
        let rows = CSV.rows("a,\"riot grrrl, compilation, punk rock\",b")
        #expect(rows == [["a", "riot grrrl, compilation, punk rock", "b"]])
    }

    @Test func doubledQuoteInsideQuotesIsOneQuote() {
        let rows = CSV.rows("\"say \"\"when\"\"\",x")
        #expect(rows == [["say \"when\"", "x"]])
    }

    @Test func emptyFieldsSurviveInThemiddle() {
        #expect(CSV.rows("a,,c") == [["a", "", "c"]])
        #expect(CSV.rows(",,") == [["", "", ""]])
    }

    @Test func trailingNewlineIsNotAnExtraRecord() {
        #expect(CSV.rows("a,b\nc,d\n") == [["a", "b"], ["c", "d"]])
        #expect(CSV.rows("a,b\nc,d") == [["a", "b"], ["c", "d"]])
    }

    /// The catalogue is a CRLF file, and `"\r\n"` is one `Character` in Swift
    /// rather than two. A walk watching only for `"\n"` reads the whole file as
    /// a single record — which is exactly what this did until this test was
    /// written.
    @Test func crlfEndsARecordWithoutLeavingACarriageReturn() {
        #expect(CSV.rows("a,b\r\nc,d\r\n") == [["a", "b"], ["c", "d"]])
    }

    @Test func aBareCarriageReturnEndsARecordToo() {
        #expect(CSV.rows("a,b\rc,d\r") == [["a", "b"], ["c", "d"]])
    }

    @Test func aLineEndingInsideQuotesIsStillJustText() {
        #expect(CSV.rows("a,\"two\r\nlines\"\r\nc,d\r\n") == [["a", "two\r\nlines"], ["c", "d"]])
    }

    /// A whole CRLF catalogue, read the way the real one is.
    @Test func aCRLFCatalogueIsReadRowByRow() {
        let shelf = Catalogue(
            csv: [
                CatalogueTests.header,
                "1,1,Bikini Kill,The Singles,1998,Rock,\"riot grrrl, punk rock\",,skips on 7,",
                "2,1,The Slits,Cut,1979,Rock,\"proto-punk, dub\",,,",
            ].joined(separator: "\r\n") + "\r\n")
        #expect(shelf.count == 2)
        #expect(shelf.look(album: "Cut", albumArtist: "The Slits")?.year == "1979")
        #expect(
            shelf.look(album: "The Singles", albumArtist: "Bikini Kill")?.shelf
                == "Rock · riot grrrl, punk rock")
    }

    @Test func emptyFileIsNoRecords() {
        #expect(CSV.rows("").isEmpty)
    }

    /// The one place this goes past `csvsplit`, which is handed a line at a
    /// time and says so (`player:1651`). A newline inside quotes belongs to the
    /// field.
    @Test func newlineInsideQuotesBelongsToTheField() {
        let rows = CSV.rows("a,\"two\nlines\",c\nd,e,f\n")
        #expect(rows == [["a", "two\nlines", "c"], ["d", "e", "f"]])
    }

    // MARK: - Normalising (`player:1679`)

    @Test func leadingTheIsDropped() {
        #expect(Catalogue.normalise("The Beatles") == "beatles")
        #expect(Catalogue.normalise("the  Beatles") == "beatles")
    }

    @Test func theInsideAWordIsNotDropped() {
        #expect(Catalogue.normalise("Theory of Everything") == "theoryofeverything")
        #expect(Catalogue.normalise("Therapy?") == "therapy")
    }

    @Test func punctuationAndCaseNeverDecideIt() {
        #expect(Catalogue.normalise("Don't Stop Me Now!") == Catalogue.normalise("dont stop me now"))
        #expect(Catalogue.normalise("Sgt. Pepper's") == "sgtpeppers")
    }

    /// `[^a-z0-9]` throws away every non-ASCII letter too, which is what awk
    /// does. Both sides of a comparison go through here, so it still matches
    /// itself.
    @Test func nonASCIIIsStrippedRatherThanFolded() {
        #expect(Catalogue.normalise("Björk") == "bjrk")
        #expect(Catalogue.normalise("Björk") == Catalogue.normalise("bjÖrk"))
    }

    @Test func digitsSurvive() {
        #expect(Catalogue.normalise("The 2nd Law") == "2ndlaw")
    }

    // MARK: - Columns by name, not by number (`player:1645`)

    @Test func columnsAreFoundByName() {
        let shelf = CatalogueTests.catalogue(
            "1,1,Bikini Kill,The Singles,1998,Rock,\"riot grrrl, punk rock\",,skips on 7,"
        )
        let entry = shelf.look(album: "The Singles", albumArtist: "Bikini Kill")
        #expect(entry?.year == "1998")
        #expect(entry?.genre == "Rock")
        #expect(entry?.tags == "riot grrrl, punk rock")
        #expect(entry?.note == "skips on 7")
    }

    /// The wishlist's order, which is the whole reason the script does not read
    /// by number: no `Number` or `Book` at all, and `Notes` before `Art URL`.
    @Test func aDifferentColumnOrderReadsTheSameFields() {
        let shelf = Catalogue(
            csv: """
                Artist,Title,Year,Parent Genre,Tags,Notes,Art URL,Barcode
                The Slits,Cut,1979,Rock,"proto-punk, dub",bought used at Amoeba,,
                """
        )
        let entry = shelf.look(album: "Cut", albumArtist: "The Slits")
        #expect(entry?.year == "1979")
        #expect(entry?.genre == "Rock")
        #expect(entry?.tags == "proto-punk, dub")
        #expect(entry?.note == "bought used at Amoeba")
    }

    /// A renamed header is not an error, it is a lookup that finds nothing —
    /// and the panel is exactly what it would have been (`player:1618`).
    @Test func aRenamedTitleColumnFindsNothing() {
        let shelf = Catalogue(
            csv: """
                Artist,Album,Year,Parent Genre,Tags,Notes
                The Slits,Cut,1979,Rock,dub,a note
                """
        )
        #expect(shelf.look(album: "Cut", albumArtist: "The Slits") == nil)
    }

    @Test func aMissingGenreColumnLeavesThatFieldEmptyAndNothingElse() {
        let shelf = Catalogue(
            csv: """
                Artist,Title,Year,Tags,Notes
                The Slits,Cut,1979,dub,a note
                """
        )
        let entry = shelf.look(album: "Cut", albumArtist: "The Slits")
        #expect(entry?.genre == "")
        #expect(entry?.tags == "dub")
        #expect(entry?.shelf == "dub")
    }

    @Test func aRowShorterThanTheHeaderIsReadAsFarAsItGoes() {
        let shelf = Catalogue(
            csv: """
                Artist,Title,Year,Parent Genre,Tags,Notes
                The Slits,Cut,1979
                """
        )
        let entry = shelf.look(album: "Cut", albumArtist: "The Slits")
        #expect(entry?.year == "1979")
        #expect(entry?.note == "")
    }

    @Test func aFileWithNothingInItIsACatalogueThatMatchesNothing() {
        let shelf = Catalogue(csv: "")
        #expect(shelf.count == 0)
        #expect(shelf.look(album: "Cut", albumArtist: "The Slits") == nil)
    }

    // MARK: - Matching (`player:1697`)

    @Test func theArticleAndThePunctuationBothGiveWay() {
        let shelf = CatalogueTests.catalogue("1,1,Beatles,Abbey Road,1969,Rock,rock,,,")
        #expect(shelf.look(album: "abbey road!", albumArtist: "The Beatles") != nil)
    }

    @Test func aDifferentArtistIsNotAMatch() {
        let shelf = CatalogueTests.catalogue("1,1,Bikini Kill,The Singles,1998,Rock,punk,,,")
        #expect(shelf.look(album: "The Singles", albumArtist: "Sleater-Kinney") == nil)
    }

    @Test func noAlbumNameIsNoLookup() {
        let shelf = CatalogueTests.catalogue("1,1,Bikini Kill,The Singles,1998,Rock,punk,,,")
        #expect(shelf.look(album: "", albumArtist: "Bikini Kill") == nil)
    }

    /// With no album artist at all, a title on its own is accepted only if
    /// exactly one record answers to it — two would be a coin toss
    /// (`player:1698`).
    @Test func aTitleAloneIsAcceptedWhenOnlyOneRecordAnswersToIt() {
        let shelf = CatalogueTests.catalogue(
            "1,1,Bikini Kill,The Singles,1998,Rock,punk,,used at Amoeba,"
        )
        #expect(shelf.look(album: "The Singles", albumArtist: "")?.note == "used at Amoeba")
    }

    @Test func aTitleAloneIsRefusedWhenTwoRecordsAnswerToIt() {
        let shelf = CatalogueTests.catalogue(
            "40,2,Lenny Kravitz,Greatest Hits,2000,Rock,soft rock,,,",
            "90,4,Journey,Greatest Hits,1988,Rock,classic rock,,,"
        )
        #expect(shelf.look(album: "Greatest Hits", albumArtist: "") == nil)
    }

    @Test func anArtistSettlesWhatATitleAloneCouldNot() {
        let shelf = CatalogueTests.catalogue(
            "40,2,Lenny Kravitz,Greatest Hits,2000,Rock,soft rock,,,",
            "90,4,Journey,Greatest Hits,1988,Rock,classic rock,,,"
        )
        #expect(shelf.look(album: "Greatest Hits", albumArtist: "Journey")?.year == "1988")
    }

    /// awk's body overwrites its captured fields on every hit and `END` prints
    /// what was left in them, so on more than one match the last row wins
    /// (`player:1703`, `player:1706`). Arbitrary, but arbitrary in a way you
    /// can predict — which is worth more here than being arbitrary twice.
    @Test func twoRowsMatchingBothTitleAndArtistTakeTheLast() {
        let shelf = CatalogueTests.catalogue(
            "1,1,Journey,Greatest Hits,1988,Rock,first,,the first row,",
            "2,1,Journey,Greatest Hits,1988,Rock,second,,the second row,"
        )
        #expect(shelf.look(album: "Greatest Hits", albumArtist: "Journey")?.note == "the second row")
    }

    /// The script tests `want_a!=""` on the album artist as it arrived, not on
    /// its normalised form. A name that normalises away is still a name, and
    /// the artist gate stays on — which is a lookup that finds nothing rather
    /// than one that quietly widens.
    @Test func anAlbumArtistThatNormalisesToNothingStillGatesOnTheArtist() {
        let shelf = CatalogueTests.catalogue(
            "40,2,Lenny Kravitz,Greatest Hits,2000,Rock,soft rock,,,",
            "90,4,Journey,Greatest Hits,1988,Rock,classic rock,,,"
        )
        #expect(shelf.look(album: "Greatest Hits", albumArtist: "???") == nil)
    }

    /// No `Artist` column and a record that has an album artist: the gate can
    /// never be satisfied, so nothing matches (`player:1701`).
    @Test func noArtistColumnAndAnAlbumArtistFindsNothing() {
        let shelf = Catalogue(
            csv: """
                Title,Year,Parent Genre,Tags,Notes
                Cut,1979,Rock,dub,a note
                """
        )
        #expect(shelf.look(album: "Cut", albumArtist: "The Slits") == nil)
        #expect(shelf.look(album: "Cut", albumArtist: "")?.note == "a note")
    }

    // MARK: - The two lines (`player:1725`, `player:2333`)

    /// **D6 took the year out of `SHELF`.** The script assembles year · genre ·
    /// tags; here the year goes up beside the artist and this line keeps the
    /// other two.
    @Test func theShelfLineIsGenreAndTagsAndNotTheYear() {
        let entry = Catalogue.Entry(
            year: "1979", genre: "Rock", tags: "proto-punk, dub", note: "")
        #expect(entry.shelf == "Rock · proto-punk, dub")
    }

    @Test func aMissingHalfDoesNotLeaveASeparator() {
        #expect(Catalogue.Entry(genre: "Rock").shelf == "Rock")
        #expect(Catalogue.Entry(tags: "dub").shelf == "dub")
        #expect(Catalogue.Entry().shelf == "")
    }

    /// A row that matched and had nothing on it. The script's `COLL_HIT` is 1
    /// and its `COLL_ROWS` is 0, so nothing prints (`player:1731`) — here the
    /// entry is empty and the panel gets no shelf at all, which is the same
    /// panel.
    @Test func aMatchWithEveryFieldBlankIsAnEmptyEntry() {
        let shelf = CatalogueTests.catalogue("1,1,Bikini Kill,The Singles,,,,,,")
        let entry = shelf.look(album: "The Singles", albumArtist: "Bikini Kill")
        #expect(entry != nil)
        #expect(entry?.isEmpty == true)
    }

    /// A tab in a note would bend the grid the panel works to keep square, and
    /// now that a quoted field may span lines a newline could too
    /// (`player:1712`).
    @Test func tabsAndNewlinesInAFieldAreFlattenedToSpaces() {
        let shelf = Catalogue(
            csv: "Artist,Title,Notes\nThe Slits,Cut,\"one\ttwo\nthree\"\n"
        )
        #expect(shelf.look(album: "Cut", albumArtist: "The Slits")?.note == "one two three")
    }

    // MARK: - The header rows it produces (§10)

    @Test func theShelfBecomesTwoHeaderRows() {
        let entry = Catalogue.Entry(
            year: "1979", genre: "Rock", tags: "dub", note: "skips on 7")
        let block = HeaderBlock(record: CatalogueTests.record(), shelf: HeaderBlock.Shelf(entry))
        #expect(block.rows.map(\.label) == ["ALBUM", "ARTIST", "SOURCE", "SHELF", "NOTE"])
        #expect(block.rows[3].value == "Rock · dub")
        #expect(block.rows[4].value == "skips on 7")
        // The note is the half you wrote down yourself, and it is the one line
        // here in amber (`player:2336`).
        #expect(block.rows[4].annotated)
        #expect(block.rows[3].annotated == false)
    }

    @Test func aShelfWithNoNoteIsOneRow() {
        let entry = Catalogue.Entry(year: "1979", genre: "Rock", tags: "dub")
        let block = HeaderBlock(record: CatalogueTests.record(), shelf: HeaderBlock.Shelf(entry))
        #expect(block.rows.map(\.label) == ["ALBUM", "ARTIST", "SOURCE", "SHELF"])
    }

    /// **§10's third open box.** The year now has three sources and the
    /// collection is the last of them, which is the whole of what §8 unblocks
    /// here (D6).
    @Test func theCollectionIsTheLastPlaceTheYearComesFrom() {
        #expect(HeaderBlock.year(tags: "1977", musicBrainz: "1979", collection: "1998") == "1977")
        #expect(HeaderBlock.year(tags: "", musicBrainz: "1979", collection: "1998") == "1979")
        #expect(HeaderBlock.year(tags: "", musicBrainz: "", collection: "1998") == "1998")
        #expect(HeaderBlock.year(tags: "", musicBrainz: "", collection: "") == "")
    }

    @Test func aRecordWithNoYearInItsTagsWearsTheShelfsYear() {
        let block = HeaderBlock(
            record: CatalogueTests.record(),
            shelf: HeaderBlock.Shelf(Catalogue.Entry(year: "1979", genre: "Rock")))
        #expect(block.rows[1].value == "The Slits (1979)")
        // And it is not repeated on the shelf line.
        #expect(block.rows[3].value == "Rock")
    }

    /// The tag year is still first: the shelf's is a fallback, not an override
    /// (D6).
    @Test func aRecordThatCarriesItsOwnYearKeepsIt() {
        let block = HeaderBlock(
            record: CatalogueTests.record(year: "1977"),
            shelf: HeaderBlock.Shelf(Catalogue.Entry(year: "1979", genre: "Rock")))
        #expect(block.rows[1].value == "The Slits (1977)")
    }

    // MARK: - Where the file lives (D5)

    @Test func theEnvironmentNamesTheFile() {
        let location = CatalogueFile.locate(
            environment: ["MUTHUR_COLLECTION": "/tmp/mine.csv"], defaults: nil,
            home: URL(fileURLWithPath: "/Users/test"))
        #expect(location.url.path == "/tmp/mine.csv")
        #expect(location.scoped == false)
    }

    @Test func theScriptsVariableIsStillReadBehindOurs() {
        let location = CatalogueFile.locate(
            environment: ["PLAYER_COLLECTION": "/tmp/theirs.csv"], defaults: nil,
            home: URL(fileURLWithPath: "/Users/test"))
        #expect(location.url.path == "/tmp/theirs.csv")
    }

    @Test func oursWinsOverTheirs() {
        let location = CatalogueFile.locate(
            environment: [
                "MUTHUR_COLLECTION": "/tmp/mine.csv", "PLAYER_COLLECTION": "/tmp/theirs.csv",
            ],
            defaults: nil, home: URL(fileURLWithPath: "/Users/test"))
        #expect(location.url.path == "/tmp/mine.csv")
    }

    @Test func theDefaultIsD5s() {
        let location = CatalogueFile.locate(
            environment: [:], defaults: nil, home: URL(fileURLWithPath: "/Users/test"))
        #expect(location.url.path == "/Users/test/Sites/cd-collection/data/collection.csv")
    }

    @Test func aFileThatIsNotThereIsNotACatalogue() {
        #expect(
            CatalogueFile.read(
                CatalogueFile.Location(url: URL(fileURLWithPath: "/nowhere/at/all.csv"))) == nil)
    }

    @Test func aFileThatIsThereIsRead() throws {
        let tmp = TempDirectory("catalogue")
        let file = tmp.appending("collection.csv")
        try (CatalogueTests.header + "\n1,1,The Slits,Cut,1979,Rock,dub,,a note,\n")
            .write(to: file, atomically: true, encoding: .utf8)
        let shelf = CatalogueFile.read(CatalogueFile.Location(url: file))
        #expect(shelf?.look(album: "Cut", albumArtist: "The Slits")?.note == "a note")
    }
}
