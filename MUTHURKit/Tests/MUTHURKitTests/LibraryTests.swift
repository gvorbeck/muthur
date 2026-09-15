import Foundation
import Testing

@testable import MUTHURKit

/// D91 — the library: what the walk calls a record, what is remembered between
/// walks, and the sleeve that is fetched once.
@Suite("D91 — the library")
struct LibraryTests {

    private func audio(_ temp: TempDirectory, _ path: String) throws {
        try temp.write(path, Data("not really audio".utf8))
    }

    private func zip(_ temp: TempDirectory, _ path: String, _ members: [TestZip.Member]) throws {
        let url = temp.appending(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try TestZip.write(members, to: url)
    }

    // MARK: - The walk

    @Test("a folder with audio in it is a record, and nothing under it is looked at")
    func folderStopsTheWalk() throws {
        let temp = TempDirectory()
        try audio(temp, "ABBA/Gold/01.flac")
        try audio(temp, "ABBA/Gold/Bonus/01.flac")
        let found = LibraryWalk.albums(in: temp.url)
        #expect(found.map(\.path) == ["ABBA/Gold"])
        #expect(found.first?.kind == .folder)
    }

    @Test("a zip is a record when its central directory holds audio, at any depth")
    func zipsAtAnyDepth() throws {
        let temp = TempDirectory()
        try zip(temp, "Agriculture - Agriculture.zip", [.init("01.flac", "x")])
        try zip(temp, "070 Shake/Modus Vivendi.zip", [.init("Modus/01.mp3", "x")])
        try zip(temp, "Scans.zip", [.init("front.jpg", "x")])
        let found = LibraryWalk.albums(in: temp.url)
        #expect(found.map(\.path) == ["070 Shake/Modus Vivendi.zip", "Agriculture - Agriculture.zip"])
        #expect(found.allSatisfy { $0.kind == .zip })
    }

    @Test("hidden entries and AppleDouble stubs are not records")
    func hiddenIsSkipped() throws {
        let temp = TempDirectory()
        try zip(temp, "Real.zip", [.init("01.flac", "x")])
        try temp.write("._Real.zip", Data([0, 5, 22, 7]))
        try audio(temp, ".Trashes/Old/01.flac")
        #expect(LibraryWalk.albums(in: temp.url).map(\.path) == ["Real.zip"])
    }

    @Test("a folder of disc folders is one record")
    func multiDisc() throws {
        let temp = TempDirectory()
        try audio(temp, "Pink Floyd/The Wall/CD1/01.flac")
        try audio(temp, "Pink Floyd/The Wall/Disc 2/01.flac")
        try temp.picture("Pink Floyd/The Wall/Scans/front.jpg")
        #expect(LibraryWalk.albums(in: temp.url).map(\.path) == ["Pink Floyd/The Wall"])
    }

    @Test("an artist's folder of albums is not mistaken for a double album")
    func artistFolderIsWalked() throws {
        let temp = TempDirectory()
        try audio(temp, "ABBA/Arrival/01.flac")
        try audio(temp, "ABBA/CD1/01.flac")
        #expect(LibraryWalk.albums(in: temp.url).map(\.path) == ["ABBA/Arrival", "ABBA/CD1"])
    }

    @Test("a directory that is itself a record is one", arguments: [false, true])
    func rootIsARecord(multiDisc: Bool) throws {
        let temp = TempDirectory()
        try audio(temp, multiDisc ? "CD1/01.flac" : "01.flac")
        #expect(LibraryWalk.albums(in: temp.url).map(\.path) == [""])
    }

    @Test("a symlink is not followed")
    func symlinksAreNotFollowed() throws {
        let temp = TempDirectory()
        try audio(temp, "Real/Album/01.flac")
        try FileManager.default.createSymbolicLink(
            at: temp.appending("Loop"), withDestinationURL: temp.appending("Real"))
        #expect(LibraryWalk.albums(in: temp.url).map(\.path) == ["Real/Album"])
    }

    @Test(
        "what counts as a disc folder",
        arguments: [
            ("CD1", true), ("cd 2", true), ("Disc_03", true), ("Disk 1", true),
            ("Disc", false), ("Discovery", false), ("CD Singles", false), ("Bonus", false),
        ])
    func discNames(name: String, isDisc: Bool) {
        #expect(LibraryWalk.isADisc(name) == isDisc)
    }

    // MARK: - Names and filing

    @Test(
        "a record is named off its path until its tags say otherwise",
        arguments: [
            ("070 Shake/Modus Vivendi.zip", LibraryWalk.Kind.zip, "070 Shake", "Modus Vivendi"),
            ("Agriculture - Agriculture.zip", .zip, "Agriculture", "Agriculture"),
            ("ABBA/Gold - Greatest Hits", .folder, "ABBA", "Gold - Greatest Hits"),
            ("Untitled", .folder, "", "Untitled"),
            ("KMRU - Kin.ZIP", .zip, "KMRU", "Kin"),
        ])
    func naming(path: String, kind: LibraryWalk.Kind, artist: String, title: String) {
        let name = Library.named(path, kind: kind)
        #expect(name.artist == artist)
        #expect(name.title == title)
    }

    @Test("filed by artist without the article, then by title")
    func filing() {
        let albums = [
            Library.Album(path: "a", kind: .zip, title: "Wish", artist: "The Cure"),
            Library.Album(path: "b", kind: .zip, title: "Arrival", artist: "ABBA"),
            Library.Album(path: "c", kind: .zip, title: "Disintegration", artist: "The Cure"),
            Library.Album(path: "d", kind: .zip, title: "Kin", artist: "KMRU"),
            Library.Album(path: "e", kind: .zip, title: "Mesopotamia", artist: "B-52's, The"),
        ]
        #expect(Library.filed(albums).map(\.title) == ["Arrival", "Mesopotamia", "Disintegration", "Wish", "Kin"])
    }

    // MARK: - Between walks

    @Test("a record found again keeps its sleeve and its names; one not found is dropped")
    func merge() {
        let known = [
            Library.Album(
                path: "Kept.zip", kind: .zip, title: "Tagged", artist: "Tags", cover: "x.jpg",
                coverSource: .tags, coverAsked: true),
            Library.Album(path: "Gone.zip", kind: .zip, title: "Gone", artist: "", cover: "y.jpg", coverAsked: true),
        ]
        let found = [
            LibraryWalk.Found(url: URL(fileURLWithPath: "/d/Kept.zip"), kind: .zip, path: "Kept.zip"),
            LibraryWalk.Found(url: URL(fileURLWithPath: "/d/New - One"), kind: .folder, path: "New - One"),
        ]
        let merged = Library.merge(known, with: found)
        #expect(merged.albums.map(\.path) == ["Kept.zip", "New - One"])
        #expect(merged.albums[0] == known[0])
        #expect(merged.albums[1].artist == "New" && merged.albums[1].title == "One")
        #expect(!merged.albums[1].coverAsked)
        #expect(merged.dropped.map(\.path) == ["Gone.zip"])
    }

    @Test("the same directory, or one inside or around it, is refused")
    func refusals() throws {
        var library = Library()
        try library.add(URL(fileURLWithPath: "/Volumes/My Passport/Music"), bookmark: nil)
        #expect(throws: Library.Refusal.self) {
            try library.add(URL(fileURLWithPath: "/Volumes/My Passport/Music/"), bookmark: nil)
        }
        #expect(throws: Library.Refusal.self) {
            try library.add(URL(fileURLWithPath: "/Volumes/My Passport/Music/ABBA"), bookmark: nil)
        }
        #expect(throws: Library.Refusal.self) {
            try library.add(URL(fileURLWithPath: "/Volumes/My Passport"), bookmark: nil)
        }
        // A sibling that merely shares a prefix is not inside it.
        try library.add(URL(fileURLWithPath: "/Volumes/My Passport/Music 2"), bookmark: nil)
        #expect(library.directories.count == 2)
        let removed = library.remove(library.directories[0].id)
        #expect(removed?.path == "/Volumes/My Passport/Music")
        #expect(library.directories.map(\.path) == ["/Volumes/My Passport/Music 2"])
    }

    @Test("the file round-trips, and a damaged one is moved aside rather than overwritten")
    func file() throws {
        let temp = TempDirectory()
        let file = LibraryFile(url: temp.appending("library/library.json"))
        #expect(file.read() == Library())

        var library = Library()
        try library.add(temp.url, bookmark: Data([1, 2, 3]))
        library.directories[0].scanned = Date(timeIntervalSince1970: 1_700_000_000)
        library.directories[0].albums = [
            Library.Album(path: "A.zip", kind: .zip, title: "A", artist: "B", cover: "c.jpg", coverSource: .coverArtArchive, coverAsked: true)
        ]
        file.write(library)
        #expect(file.read() == library)

        try Data("{ not json".utf8).write(to: file.url)
        #expect(file.read() == Library())
        #expect(FileManager.default.fileExists(atPath: file.url.path + ".damaged"))
    }

    @Test("standard location is XDG_DATA_HOME's, beside the corrections")
    func location() {
        let file = LibraryFile.standard(environment: ["XDG_DATA_HOME": "/x"])
        #expect(file.url.path == "/x/muthur/library/library.json")
        #expect(file.covers.path == "/x/muthur/library/covers")
    }

    @Test("a directory that is not there cannot be reached, bookmark or no bookmark")
    func reach() throws {
        let temp = TempDirectory()
        let here = Library.Directory(path: temp.url.path)
        #expect(LibraryFile.reach(here) != nil)
        let gone = Library.Directory(path: temp.url.path + "/not-plugged-in", bookmark: Data([9, 9]))
        #expect(LibraryFile.reach(gone) == nil)
    }

    @Test("sleeve filenames are stable and do not collide on paths that fold alike")
    func coverNames() {
        let id = UUID()
        #expect(Library.coverName(directory: id, path: "Live/1.zip") == Library.coverName(directory: id, path: "Live/1.zip"))
        #expect(Library.coverName(directory: id, path: "Live/1.zip") != Library.coverName(directory: id, path: "Live 1.zip"))
    }

    // MARK: - The sleeve, once

    private func covers(_ temp: TempDirectory, transport: StubSleeveTransport) -> LibraryCovers {
        LibraryCovers(
            resolver: SleeveResolver(
                embedded: NoEmbeddedPictures(),
                transport: transport,
                cache: SleeveCache(directory: temp.appending("cache")),
                retryDelay: .zero),
            metadata: StubMetadataReader([:]),
            work: temp.appending("work"))
    }

    @Test("a folder's own picture is kept, cut down to the tile's size")
    func folderSleeve() async throws {
        let temp = TempDirectory()
        try audio(temp, "Album/01.flac")
        try temp.picture("Album/cover.jpg", side: 1400)
        let album = Library.Album(path: "Album", kind: .folder, title: "Album", artist: "")
        let out = temp.appending("covers/a.jpg")
        let outcome = await covers(temp, transport: StubSleeveTransport([], otherwise: .couldNotAsk))
            .find(album, at: temp.appending("Album"), storingAt: out)
        #expect(outcome.source == .besideTheRecord)
        #expect(!outcome.askedTheArchive)
        let size = try #require(ImageIOPictureProbe().size(of: out))
        #expect(max(size.width, size.height) == LibraryCovers.side)
    }

    @Test("a zip's picture is taken out of the archive by §5.1's ranking, without unpacking the record")
    func zipSleeve() async throws {
        let temp = TempDirectory()
        try zip(
            temp, "Album.zip",
            [
                .init("__MACOSX/._cover.jpg", bytes: [0, 5, 22, 7]),
                .init("back.jpg", bytes: Array(TestPictures.jpeg(800))),
                .init("Artist - Album.jpg", bytes: Array(TestPictures.jpeg(300))),
                .init("tiny cover.jpg", bytes: Array(TestPictures.jpeg(90))),
                .init("01.flac", "x"),
            ])
        let album = Library.Album(path: "Album.zip", kind: .zip, title: "Album", artist: "")
        let out = temp.appending("covers/z.jpg")
        let transport = StubSleeveTransport([], otherwise: .couldNotAsk)
        let outcome = await covers(temp, transport: transport).find(album, at: temp.appending("Album.zip"), storingAt: out)
        #expect(outcome.source == .besideTheRecord)
        // `back` is thrown out and the 90-pixel `cover` is under the floor, so
        // the Bandcamp name is what is left.
        let size = try #require(ImageIOPictureProbe().size(of: out))
        #expect(size.width == 300)
        #expect(transport.asked.isEmpty)
        // Nothing left in the work directory.
        let left = try FileManager.default.contentsOfDirectory(atPath: temp.appending("work").path)
        #expect(left.isEmpty)
    }

    @Test("with nothing beside it and nothing in its tags, the archive is asked and awaited")
    func archiveIsAwaited() async throws {
        let temp = TempDirectory()
        try zip(temp, "Album.zip", [.init("01.flac", "x")])
        let album = Library.Album(path: "Album.zip", kind: .zip, title: "Album", artist: "Artist")
        let out = temp.appending("covers/n.jpg")
        let outcome = await covers(temp, transport: StubSleeveTransport([], otherwise: .couldNotAsk))
            .find(album, at: temp.appending("Album.zip"), storingAt: out)
        #expect(outcome.askedTheArchive)
        #expect(outcome.source == nil)
        #expect(!FileManager.default.fileExists(atPath: out.path))

        var asked = album
        asked.apply(outcome, coverName: "n.jpg")
        #expect(asked.coverAsked)
        #expect(asked.cover == nil)
    }

    // MARK: - The shelf

    /// Two directories of five and three records, and one empty between them.
    private func shelf() -> LibraryShelf {
        func albums(_ n: Int) -> [Library.Album] {
            (0..<n).map { Library.Album(path: "\($0)", kind: .zip, title: "T\($0)", artist: "A") }
        }
        return LibraryShelf(
            Library(directories: [
                .init(path: "/one", albums: albums(5)),
                .init(path: "/empty"),
                .init(path: "/two", albums: albums(3)),
            ]))
    }

    @Test("every directory is a section, and an empty one is still a slot the cursor can stand on")
    func shelfSlots() {
        let shelf = shelf()
        #expect(shelf.count == 9)
        #expect(shelf.records == 8)
        #expect(shelf.sections.map(\.first) == [0, 5, 6])
        #expect(shelf.slot(5) == .empty(section: 1))
        #expect(shelf.slot(6)?.album?.title == "T0")
        #expect(shelf.slot(6)?.section == 2)
        #expect(shelf.slot(9) == nil)
        #expect(shelf.index(directory: shelf.sections[2].id, path: "2") == 8)
    }

    @Test("lines are a rule, then rows of sleeves or the empty line, per directory")
    func shelfLines() {
        let shelf = shelf()
        let lines = shelf.lines(perRow: 2)
        #expect(
            lines == [
                .rule(section: 0), .tiles(section: 0, row: 0), .tiles(section: 0, row: 1),
                .tiles(section: 0, row: 2), .rule(section: 1), .empty(section: 1), .rule(section: 2),
                .tiles(section: 2, row: 0), .tiles(section: 2, row: 1),
            ])
        #expect(shelf.slots(on: lines[3], perRow: 2) == 4..<5)
        #expect(shelf.slots(on: lines[5], perRow: 2) == 5..<6)
        for index in 0..<shelf.count {
            let line = shelf.line(of: index, perRow: 2)!
            #expect(shelf.slots(on: lines[line], perRow: 2).contains(index))
        }
    }

    @Test("←→ run along the shelf and stop at its ends; ↑↓ keep the column and cross directories")
    func shelfCursor() {
        let shelf = shelf()
        #expect(shelf.moved(0, .left, perRow: 3) == 0)
        #expect(shelf.moved(2, .right, perRow: 3) == 3)
        #expect(shelf.moved(4, .right, perRow: 3) == 5)
        #expect(shelf.moved(8, .right, perRow: 3) == 8)
        // Column 1 of the first row, down to the short second row's column 1.
        #expect(shelf.moved(1, .down, perRow: 3) == 4)
        // Column 2 of the first row: the second row has no column 2.
        #expect(shelf.moved(2, .down, perRow: 3) == 4)
        // Off the last row of a section, across its rule, onto the empty line.
        #expect(shelf.moved(4, .down, perRow: 3) == 5)
        #expect(shelf.moved(5, .down, perRow: 3) == 6)
        #expect(shelf.moved(7, .up, perRow: 3) == 5)
        #expect(shelf.moved(5, .up, perRow: 3) == 3)
        #expect(shelf.moved(0, .up, perRow: 3) == 0)
        #expect(shelf.moved(8, .down, perRow: 3) == 8)
        #expect(LibraryShelf(Library()).moved(0, .down, perRow: 3) == 0)
    }

    @Test("the window moves only as far as the cursor makes it, and never past the foot")
    func shelfWindow() {
        let heights = [1, 7, 7, 7, 1, 1]
        // Everything fits: the top is pulled back to the start.
        #expect(LibraryShelf.window(heights: heights, top: 3, budget: 40, keeping: 5) == (0, 0..<6))
        // The cursor on the top line leaves the window where it is.
        #expect(LibraryShelf.window(heights: heights, top: 0, budget: 16, keeping: 1) == (0, 0..<3))
        // Down to line 3 moves the top only far enough to show all of it.
        #expect(LibraryShelf.window(heights: heights, top: 0, budget: 16, keeping: 3) == (2, 2..<6))
        // Back up above the window brings the top to the cursor.
        #expect(LibraryShelf.window(heights: heights, top: 2, budget: 16, keeping: 1) == (1, 1..<3))
        // A line taller than the screen is still drawn.
        #expect(LibraryShelf.window(heights: heights, top: 0, budget: 4, keeping: 2) == (2, 2..<3))
        #expect(LibraryShelf.window(heights: [], top: 3, budget: 4, keeping: nil) == (0, 0..<0))
    }

    @Test("the library's plate counts records and says how many are away")
    func libraryMeta() {
        #expect(Faceplate.libraryMeta(count: 1, offline: 0) == "LIBRARY · 1 RECORD")
        #expect(Faceplate.libraryMeta(count: 219, offline: 170) == "LIBRARY · 219 RECORDS · 170 OFFLINE")
    }
}
