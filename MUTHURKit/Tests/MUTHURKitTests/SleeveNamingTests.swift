import Foundation
import Testing

@testable import MUTHURKit

/// §5.1's ranking, which is all name and no file — the part of finding a sleeve
/// that can be decided without opening anything.
@Suite("Sleeve — what a picture is called")
struct SleeveNamingTests {

    private func rank(_ basename: String) -> Int? {
        BesideTheRecord.rank(of: URL(fileURLWithPath: "/album/\(basename)"))
    }

    // MARK: - Folding

    @Test("Separators fold to spaces so words can be matched as words")
    func folding() {
        #expect(BesideTheRecord.fold("Front_Cover") == "front cover")
        #expect(BesideTheRecord.fold("front-cover") == "front cover")
        #expect(BesideTheRecord.fold("FRONT   COVER") == "front cover")
        // Runs of mixed separators collapse to one space, not to one each.
        #expect(BesideTheRecord.fold("a_ -b") == "a b")
        // Not trimmed — the script does not trim, and the ends are what
        // separate a bare `cover` from a decorated one.
        #expect(BesideTheRecord.fold("-cover-") == " cover ")
    }

    @Test("Lowercasing is ASCII-only, as tr is in the C locale")
    func asciiFolding() {
        #expect(BesideTheRecord.fold("Æther") == "Æther")
        #expect(BesideTheRecord.fold("COVER") == "cover")
    }

    // MARK: - The four ranks

    @Test("The bare known names rank first")
    func exactNames() {
        for name in ["cover", "front", "folder", "album", "albumart", "artwork", "sleeve"] {
            #expect(rank("\(name).jpg") == 1, "\(name) should be rank 1")
            #expect(rank("\(name.uppercased()).PNG") == 1, "\(name) uppercased should be rank 1")
        }
    }

    @Test("A known word inside a longer name ranks second")
    func wholeWord() {
        #expect(rank("front cover.jpg") == 2)
        #expect(rank("Front_Cover.png") == 2)
        #expect(rank("album cover scan.jpg") == 2)
        // Decoration on the ends is not the bare word, so this is 2 and not 1.
        #expect(rank("-cover-.jpg") == 2)
    }

    @Test("A known word buried in a word ranks third")
    func substring() {
        #expect(rank("albumcover.jpg") == 3)
        #expect(rank("frontal.jpg") == 3)
    }

    @Test("Everything else is still allowed, last")
    func everythingElse() {
        // The whole reason rank 4 exists: Bandcamp names its picture after the
        // record and after nothing else.
        #expect(rank("Cake - Comfort Eagle.jpg") == 4)
        #expect(rank("00000001.jpg") == 4)
        #expect(rank("scan.jpg") == 4)
    }

    // MARK: - Thrown out

    @Test("The scans that are definitely not the front are thrown out, not ranked last")
    func thrownOut() {
        for name in [
            "back", "inlay", "booklet", "tray", "obi", "spine", "label", "matrix",
            "inside", "thumb", "thumbnail",
        ] {
            #expect(rank("\(name).jpg") == nil, "\(name) should be thrown out")
        }
        #expect(rank("cover back.jpg") == nil)
        #expect(rank("Booklet_01.jpg") == nil)
    }

    @Test("A disc label is thrown out, with or without a number")
    func discLabels() {
        for name in ["disc", "cd", "dvd", "cd1", "disc2", "dvd9", "disc 3"] {
            #expect(rank("\(name).jpg") == nil, "\(name) should be thrown out")
        }
    }

    @Test("A word that merely starts with a disc label survives")
    func discoveryIsNotADisc() {
        // The entire point of folding separators before matching: `discovery`
        // is one word and is not a disc, and `cdr` is not `cd`. (`discovery`
        // then lands on rank 3 for containing `cover`, which is comic and
        // harmless — it is still a candidate, still behind every real one.)
        #expect(rank("Discovery.jpg") == 3)
        #expect(rank("cdr.jpg") == 4)
        #expect(rank("labelled.jpg") == 4)
        // But a real disc label in a longer name still goes.
        #expect(rank("front cd2.jpg") == nil)
    }

    @Test("Non-ASCII digits do not make a disc label")
    func nonASCIIDigits() {
        #expect(rank("cd٢.jpg") == 4)
    }

    // MARK: - The sort

    @Test("Rank first, then the shallowest path, then byte order")
    func ordering() {
        let files = [
            "/a/Scans/cover.jpg",
            "/a/zzz.jpg",
            "/a/cover.jpg",
            "/a/front cover.jpg",
            "/a/back.jpg",
            "/a/aaa.jpg",
        ].map(URL.init(fileURLWithPath:))

        #expect(
            BesideTheRecord.ranked(files).map(\.lastPathComponent) == [
                "cover.jpg",  // rank 1, depth 3
                "cover.jpg",  // rank 1, depth 4 — same name, deeper
                "front cover.jpg",  // rank 2
                "aaa.jpg",  // rank 4, byte order
                "zzz.jpg",
            ]
        )
        // And the back of the sleeve is not at the end of that list; it is not
        // in it.
        #expect(!BesideTheRecord.ranked(files).contains { $0.lastPathComponent == "back.jpg" })
    }

    @Test("Byte order, not a locale's idea of alphabetical")
    func byteOrder() {
        let files = ["/a/Zebra.jpg", "/a/apple.jpg"].map(URL.init(fileURLWithPath:))
        // Capitals sort before lowercase under LC_ALL=C, which is what the
        // script runs under.
        #expect(BesideTheRecord.ranked(files).first?.lastPathComponent == "Zebra.jpg")
    }
}
