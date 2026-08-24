import Foundation
import Testing

@testable import MUTHURKit

/// §5.2 — what is kept, under what name, and for how long.
@Suite("Sleeve — the cache")
struct SleeveCacheTests {

    // MARK: - The key

    @Test("A release MBID names a pressing, so it is the key when there is one")
    func mbidKey() {
        #expect(
            SleeveCache.key(
                releaseMBID: "8f4b1c8e-1f9a-4d3e-9d2c-000000000000",
                albumArtist: "Cake", album: "Comfort Eagle"
            ) == "mbid-8f4b1c8e-1f9a-4d3e-9d2c-000000000000"
        )
    }

    @Test("Otherwise the artist and the title, folded down to letters and digits")
    func foldedKey() {
        #expect(SleeveCache.key(albumArtist: "Cake", album: "Comfort Eagle") == "cake-comfort-eagle")
    }

    @Test("Two taggings of the same record land on one file")
    func foldingIsForgiving() {
        let a = SleeveCache.key(albumArtist: "Godspeed You! Black Emperor", album: "F♯A♯∞")
        let b = SleeveCache.key(albumArtist: "godspeed you black emperor", album: "F A ")
        #expect(a == b)
        #expect(a == "godspeed-you-black-emperor-f-a")
    }

    @Test("Runs of punctuation squeeze to one dash and the ends are trimmed")
    func foldingShape() {
        #expect(SleeveCache.fold("  ...Hello!!! World...  ") == "hello-world")
        #expect(SleeveCache.fold("---") == "")
    }

    @Test("Cut to eighty characters, and never left ending in a dash")
    func keyLength() {
        let key = SleeveCache.key(albumArtist: String(repeating: "a", count: 60), album: "b")!
        #expect(key.count <= 80)
        #expect(!key.hasSuffix("-"))

        // The cut landing exactly on a separator is the case that would leave a
        // trailing dash behind.
        let awkward = SleeveCache.fold(String(repeating: "a", count: 79) + " tail")
        #expect(awkward == String(repeating: "a", count: 79))
    }

    @Test("A record with nothing to fold has no key rather than a shared one")
    func noKey() {
        #expect(SleeveCache.key(albumArtist: "", album: "") == nil)
        #expect(SleeveCache.key(albumArtist: "...", album: "!!!") == nil)
        #expect(SleeveCache.key(releaseMBID: "", albumArtist: "Cake", album: "x") == "cake-x")
    }

    // MARK: - Where it lives

    @Test("Our own cache root, not the script's")
    func standardDirectory() {
        let cache = SleeveCache.standard(
            environment: [:], home: URL(fileURLWithPath: "/Users/nostromo")
        )
        #expect(cache.directory.path == "/Users/nostromo/.cache/muthur/art")
    }

    @Test("XDG_CACHE_HOME is honoured")
    func xdg() {
        let cache = SleeveCache.standard(
            environment: ["XDG_CACHE_HOME": "/elsewhere"],
            home: URL(fileURLWithPath: "/Users/nostromo")
        )
        #expect(cache.directory.path == "/elsewhere/muthur/art")
    }

    // MARK: - The part file

    @Test("A download lands on the part file and only then on the cache entry")
    func partThenCommit() throws {
        let temp = TempDirectory("art")
        let cache = SleeveCache(directory: temp.url)

        let part = cache.writePart(TestPictures.jpeg(500), forKey: "k")
        #expect(part == cache.part(forKey: "k"))
        // Nothing in the cache yet — a half-written entry must never be a
        // findable one.
        #expect(!cache.hasEntry(forKey: "k"))

        #expect(cache.commitPart(forKey: "k") == cache.file(forKey: "k"))
        #expect(cache.hasEntry(forKey: "k"))
        #expect(!FileManager.default.fileExists(atPath: cache.part(forKey: "k").path))
    }

    @Test("The part file is named after the record, so a killed fetch leaves one file")
    func partIsNamedAfterTheRecord() throws {
        let temp = TempDirectory("art")
        let cache = SleeveCache(directory: temp.url)

        cache.writePart(Data("first try".utf8), forKey: "k")
        cache.writePart(Data("second try".utf8), forKey: "k")

        let listing = try FileManager.default.contentsOfDirectory(atPath: temp.url.path)
        #expect(listing == ["k.jpg.part"])
        // And the previous try's bytes are gone rather than underneath.
        #expect(try Data(contentsOf: cache.part(forKey: "k")) == Data("second try".utf8))
    }

    @Test("An abandoned part file is swept up")
    func removePart() throws {
        let temp = TempDirectory("art")
        let cache = SleeveCache(directory: temp.url)
        cache.writePart(Data("half a jpeg".utf8), forKey: "k")
        cache.removePart(forKey: "k")
        #expect(try FileManager.default.contentsOfDirectory(atPath: temp.url.path).isEmpty)
    }

    @Test("An empty file is not an entry")
    func emptyIsNotAnEntry() throws {
        let temp = TempDirectory("art")
        let cache = SleeveCache(directory: temp.url)
        FileManager.default.createFile(atPath: cache.file(forKey: "k").path, contents: Data())
        #expect(!cache.hasEntry(forKey: "k"))
    }

    // MARK: - The marker

    @Test("A fresh marker means do not ask again")
    func freshMarker() throws {
        let temp = TempDirectory("art")
        let cache = SleeveCache(directory: temp.url)
        #expect(!cache.noneIsFresh(forKey: "k"))

        cache.markNone(forKey: "k")
        #expect(cache.noneIsFresh(forKey: "k"))
        #expect(cache.noneIsFresh(forKey: "k", now: Date().addingTimeInterval(13 * 86_400)))
    }

    @Test("A marker a fortnight old expires, so a scan uploaded since still turns up")
    func staleMarker() throws {
        let temp = TempDirectory("art")
        let cache = SleeveCache(directory: temp.url)
        cache.markNone(forKey: "k")

        let later = Date().addingTimeInterval(SleeveCache.noneLifetime + 60)
        #expect(!cache.noneIsFresh(forKey: "k", now: later))
        // Swept up on the way past, as the script's `find … -mtime +14 && rm`
        // does — otherwise it is re-read and re-expired on every play.
        #expect(!FileManager.default.fileExists(atPath: cache.noneMarker(forKey: "k").path))
    }

    @Test("Fourteen days, to the second")
    func markerLifetime() throws {
        #expect(SleeveCache.noneLifetime == 14 * 24 * 60 * 60)

        let temp = TempDirectory("art")
        let cache = SleeveCache(directory: temp.url)
        cache.markNone(forKey: "k")
        let marker = cache.noneMarker(forKey: "k")
        // Backdate it precisely rather than trusting the clock to move.
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-SleeveCache.noneLifetime + 30)],
            ofItemAtPath: marker.path
        )
        #expect(cache.noneIsFresh(forKey: "k"))

        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-SleeveCache.noneLifetime - 30)],
            ofItemAtPath: marker.path
        )
        #expect(!cache.noneIsFresh(forKey: "k"))
    }

    @Test("Asked again and refused again, the fortnight starts again")
    func markerIsRewritten() throws {
        let temp = TempDirectory("art")
        let cache = SleeveCache(directory: temp.url)
        cache.markNone(forKey: "k")
        let marker = cache.noneMarker(forKey: "k")
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-10 * 86_400)],
            ofItemAtPath: marker.path
        )

        cache.markNone(forKey: "k")
        let modified = try marker.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate!
        #expect(Date().timeIntervalSince(modified) < 60)
    }

    // MARK: - Cleared, not deleted

    @Test("A sleeve that will not decode is dropped without touching the file")
    func discardedDeletesNothing() throws {
        let temp = TempDirectory("art")
        let cache = SleeveCache(directory: temp.url)
        cache.writePart(TestPictures.jpeg(500), forKey: "k")
        let file = cache.commitPart(forKey: "k")!

        let sleeve = Sleeve(url: file, source: .coverArtArchive)
        #expect(sleeve.discarded() == nil)
        // Another player may be part way through writing that very name
        // (`player:3162`), so the panel forgets it and the file stays.
        #expect(FileManager.default.fileExists(atPath: file.path))
    }
}
