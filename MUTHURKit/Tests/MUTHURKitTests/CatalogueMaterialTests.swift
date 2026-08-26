import Foundation
import Testing

@testable import MUTHURKit

/// §8 against the real catalogue — the one in `cd-collection`, which is
/// **read-only, always** (`CLAUDE.md`, D5). Every test here opens that file and
/// nothing here writes to it, near it, or anywhere in that repository.
///
/// The file is maintained, so almost nothing here asserts a value out of it.
/// What it asserts is that the parse *agrees with the file* — that every row
/// finds itself, that the flattening leaves nothing that would bend the panel's
/// grid — plus the handful of rows whose shape is the reason §8 parses CSV
/// properly at all, each guarded on still being there.
@Suite("§8 The catalogue, against the real one", .enabled(if: Fixtures.exists(Fixtures.collection)))
struct CatalogueMaterialTests {

    static var shelf: Catalogue? {
        CatalogueFile.read(CatalogueFile.Location(url: Fixtures.collection))
    }

    /// Whether a particular record is still on the shelf. The tests that name a
    /// row gate on this rather than asserting it, because that file is
    /// maintained and somebody selling a CD is not a broken port.
    static func has(_ album: String, artist: String = "") -> Bool {
        shelf?.look(album: album, albumArtist: artist) != nil
    }

    /// Whether more than one record answers to a title. The duplicate-title
    /// rule needs real duplicates to be worth testing.
    static func duplicates(of title: String) -> [String] {
        guard let shelf, let titleColumn = shelf.columns.title,
            let artistColumn = shelf.columns.artist
        else { return [] }
        let matching = shelf.rows.filter {
            $0.indices.contains(titleColumn)
                && Catalogue.normalise($0[titleColumn]) == Catalogue.normalise(title)
        }
        guard matching.count > 1 else { return [] }
        return matching.compactMap { $0.indices.contains(artistColumn) ? $0[artistColumn] : nil }
            .filter { !$0.isEmpty }
    }

    /// The compilation with a comma inside its title, spelled as the catalogue
    /// spells it — a U+2010 hyphen, not an ASCII one.
    static let commaTitle = "Punk\u{2010}O\u{2010}Rama, Volume 5"

    /// The header the file carries today. If this fails the file has been
    /// re-columned, which is a thing §8 is built to survive — the lookup finds
    /// nothing and the panel is unchanged — so this is a notice, not a fault in
    /// the port.
    @Test func theRealHeaderNamesTheColumnsWeRead() throws {
        let shelf = try #require(CatalogueMaterialTests.shelf)
        #expect(shelf.columns.artist != nil)
        #expect(shelf.columns.title != nil)
        #expect(shelf.columns.year != nil)
        #expect(shelf.columns.genre != nil)
        #expect(shelf.columns.tags != nil)
        #expect(shelf.columns.notes != nil)
    }

    @Test func thereAreRecordsOnTheShelf() throws {
        let shelf = try #require(CatalogueMaterialTests.shelf)
        #expect(shelf.count > 100)
    }

    /// Every row in the file, looked up by its own artist and title, comes back.
    /// The one invariant worth having against live data: whatever it grows to
    /// hold, the lookup can still find it.
    @Test func everyRowFindsItself() throws {
        let shelf = try #require(CatalogueMaterialTests.shelf)
        let titleColumn = try #require(shelf.columns.title)
        let artistColumn = try #require(shelf.columns.artist)

        var missed: [String] = []
        for row in shelf.rows {
            let title = row.indices.contains(titleColumn) ? row[titleColumn] : ""
            let artist = row.indices.contains(artistColumn) ? row[artistColumn] : ""
            guard !title.isEmpty else { continue }
            if shelf.look(album: title, albumArtist: artist) == nil {
                missed.append("\(artist) — \(title)")
            }
        }
        // Today this is zero of 248: the only duplicated title on the shelf is
        // `Greatest Hits`, four times, and every one of those rows has an artist
        // on it. A row can legitimately miss — two compilations with no artist
        // sharing a title are a coin toss and are refused on purpose
        // (`player:1698`) — so the tolerance is for the file growing one, not
        // for the lookup. What would be wrong is many of them.
        #expect(missed.count <= 2, "rows that cannot find themselves: \(missed)")
    }

    /// Nothing that comes off the shelf carries a tab or a newline into the
    /// panel's grid (`player:1712`).
    @Test func nothingComesBackWithControlCharactersInIt() throws {
        let shelf = try #require(CatalogueMaterialTests.shelf)
        let titleColumn = try #require(shelf.columns.title)
        let artistColumn = try #require(shelf.columns.artist)

        for row in shelf.rows {
            let title = row.indices.contains(titleColumn) ? row[titleColumn] : ""
            let artist = row.indices.contains(artistColumn) ? row[artistColumn] : ""
            guard let entry = shelf.look(album: title, albumArtist: artist) else { continue }
            for field in [entry.shelf, entry.note, entry.year] {
                #expect(!field.contains("\t"))
                #expect(!field.contains("\n"))
                #expect(!field.contains("\r"))
            }
        }
    }

    /// **The row that is the reason the CSV is parsed rather than split.** A
    /// title with a comma inside it, in a quoted field, on a compilation with no
    /// artist at all — split on commas and this record is two records and
    /// neither of them exists.
    @Test(.enabled(if: CatalogueMaterialTests.has(CatalogueMaterialTests.commaTitle)))
    func aTitleWithACommaInItIsOneTitle() throws {
        let shelf = try #require(CatalogueMaterialTests.shelf)
        let entry = try #require(
            shelf.look(album: CatalogueMaterialTests.commaTitle, albumArtist: ""))
        #expect(entry.year == "2000")
        #expect(entry.shelf == "Rock · compilation, punk rock")
    }

    /// And it is found with the hyphen a filesystem would actually have. The
    /// catalogue spells it with a U+2010 hyphen; a folder on disk will have an
    /// ASCII one, or none. `normalise` throws away both (`player:1679`), which
    /// is the whole of why this matches.
    @Test(.enabled(if: CatalogueMaterialTests.has(CatalogueMaterialTests.commaTitle)))
    func theCatalogueSHyphenAndAFolderSHyphenAreTheSameRecord() throws {
        let shelf = try #require(CatalogueMaterialTests.shelf)
        let fromDisk = try #require(shelf.look(album: "Punk-O-Rama, Volume 5", albumArtist: ""))
        let fromFile = try #require(
            shelf.look(album: CatalogueMaterialTests.commaTitle, albumArtist: ""))
        #expect(fromDisk == fromFile)
    }

    /// The real duplicate-title material: several records called `Greatest
    /// Hits`. Without an artist it is refused; with one it is answered
    /// (`player:1706`).
    @Test(.enabled(if: CatalogueMaterialTests.duplicates(of: "Greatest Hits").count > 1))
    func greatestHitsNeedsAnArtist() throws {
        let shelf = try #require(CatalogueMaterialTests.shelf)
        #expect(shelf.look(album: "Greatest Hits", albumArtist: "") == nil)
        for artist in CatalogueMaterialTests.duplicates(of: "Greatest Hits") {
            #expect(shelf.look(album: "Greatest Hits", albumArtist: artist) != nil)
        }
    }

    /// An album that is simply not on the shelf. The normal case for anyone who
    /// is not the author, and it has to be silent (`player:1618`).
    @Test func aRecordThatIsNotOnTheShelfIsNothingAtAll() throws {
        let shelf = try #require(CatalogueMaterialTests.shelf)
        #expect(shelf.look(album: "An Album Nobody Owns", albumArtist: "Nobody") == nil)
    }

    /// The default path, resolved with no environment and no bookmark, is where
    /// the file actually is (D5). Skipped when the tests were pointed somewhere
    /// else.
    @Test(
        .enabled(if: ProcessInfo.processInfo.environment["MUTHUR_TEST_COLLECTION"] == nil)
    )
    func theDefaultPathFindsTheRealFile() {
        let location = CatalogueFile.locate(environment: [:], defaults: nil)
        #expect(location.url.path == Fixtures.collection.path)
        #expect(CatalogueFile.read(location) != nil)
    }
}
