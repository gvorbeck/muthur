import Foundation
import Testing

@testable import MUTHURKit

/// §2.1 and §2.2 — whether it fits, one pass over it, and what to say when it
/// goes wrong.
@Suite("§2.1, §2.2 — opening a zip")
struct UnpackerTests {

    /// Enough that the fit check is never what a test is about unless it says
    /// it is.
    static let roomy: @Sendable (URL) -> UInt64 = { _ in 64 * 1024 * 1024 * 1024 }

    // MARK: - The ordinary case

    @Test("the whole zip comes out, not just the audio (player:1181)")
    func unpacksEverything() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Rumours.zip")
        let out = temp.directory("album")
        try TestZip.write(
            [
                .init("01 Second Hand News.flac", "one"),
                .init("02 Dreams.flac", "two"),
                .init("cover.jpg", "a sleeve"),
                .init("booklet/scan.png", "a page"),
            ],
            to: zip
        )

        let result = try Unpacker.unpack(zip: zip, into: out, freeSpace: Self.roomy)

        #expect(result.written == 4)
        #expect(result.skipped.isEmpty)
        // The cover art is the reason the whole archive is taken.
        #expect(contents(of: out.appending(path: "cover.jpg")) == "a sleeve")
        #expect(contents(of: out.appending(path: "booklet/scan.png")) == "a page")
        #expect(contents(of: out.appending(path: "01 Second Hand News.flac")) == "one")
    }

    @Test("a deflated entry comes out as it went in")
    func inflatesDeflatedEntries() throws {
        let temp = TempDirectory()
        let zip = temp.appending("big.zip")
        let out = temp.directory("album")
        // Bigger than one read of the archive, so the streaming path is the one
        // under test and not a single-chunk shortcut of it.
        let text = String(repeating: "the needle goes anywhere in the record. ", count: 40_000)
        var member = TestZip.Member("01 Long.flac", text)
        member.deflate = true
        try TestZip.write([member], to: zip)

        let result = try Unpacker.unpack(zip: zip, into: out, freeSpace: Self.roomy)
        #expect(result.written == 1)
        #expect(contents(of: out.appending(path: "01 Long.flac")) == text)
    }

    @Test("the name bytes reach the filesystem as the archive stores them (player:256)")
    func keepsTheArchivesNameBytes() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Costes.zip")
        let out = temp.directory("album")
        // A decomposed ô — an o followed by a combining circumflex, which is how
        // a Mac writes Hôtel, and the exact name Apple's unzip turns into two
        // bytes no filesystem will take.
        let decomposed = "H\u{006F}\u{0302}tel Costes.flac"
        try TestZip.write([.init(decomposed, "one")], to: zip)

        let result = try Unpacker.unpack(zip: zip, into: out, freeSpace: Self.roomy)
        #expect(result.written == 1)
        #expect(result.skipped.isEmpty)

        let written = try #require(
            try FileManager.default.contentsOfDirectory(atPath: out.path).first
        )
        // Same bytes, whatever the filesystem chose to normalise them to on the
        // way in — which is the filesystem's business and not this program's.
        #expect(Array(written.utf8) == Array(decomposed.utf8))
        #expect(contents(of: out.appending(path: written)) == "one")
    }

    @Test("progress is per entry and reaches 100 exactly once (player:1290)")
    func reportsProgressPerEntry() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Rumours.zip")
        let out = temp.directory("album")
        try TestZip.write(
            (1...4).map { .init("0\($0) Track.flac", "x") }, to: zip
        )

        var seen: [Unpacker.Progress] = []
        _ = try Unpacker.unpack(
            zip: zip, into: out, freeSpace: Self.roomy, progress: { seen.append($0) }
        )

        #expect(seen.map(\.percent) == [25, 50, 75, 100])
        #expect(seen.map(\.name) == (1...4).map { "0\($0) Track.flac" })
    }

    // MARK: - One bad entry is not a bad album

    @Test("a corrupt booklet scan is skipped and the record still plays (player:1298)")
    func oneBadEntryIsNotABadAlbum() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Rumours.zip")
        let out = temp.directory("album")
        var rotten = TestZip.Member("booklet/scan.png", "half a page")
        rotten.corruptCRC = true
        var exotic = TestZip.Member("notes.txt", "bzip2, of all things")
        exotic.method = 12
        try TestZip.write(
            [
                .init("01 Second Hand News.flac", "one"),
                rotten,
                exotic,
                .init("02 Dreams.flac", "two"),
            ],
            to: zip
        )

        let result = try Unpacker.unpack(zip: zip, into: out, freeSpace: Self.roomy)

        #expect(result.written == 2)
        #expect(result.skipped.map(\.name) == ["booklet/scan.png", "notes.txt"])
        #expect(contents(of: out.appending(path: "02 Dreams.flac")) == "two")
        // And nothing half-written is left where the album is about to be read.
        #expect(!FileManager.default.fileExists(atPath: out.appending(path: "booklet/scan.png").path))
    }

    @Test("a name that climbs out of the album is skipped, not obeyed")
    func refusesToWriteOutsideTheAlbum() throws {
        let temp = TempDirectory()
        let zip = temp.appending("hostile.zip")
        let out = temp.directory("album")
        try TestZip.write(
            [
                .init("../../escaped.flac", "not here"),
                .init("/etc/absolute.flac", "nor here"),
                .init("01 Track.flac", "one"),
            ],
            to: zip
        )

        let result = try Unpacker.unpack(zip: zip, into: out, freeSpace: Self.roomy)
        #expect(result.written == 1)
        #expect(result.skipped.count == 2)
        #expect(!FileManager.default.fileExists(atPath: temp.appending("escaped.flac").path))
    }

    @Test("an archive that yielded nothing is the end of the album (player:1308)")
    func nothingCameOut() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Rumours.zip")
        let out = temp.directory("album")
        var rotten = TestZip.Member("01 Track.flac", "one")
        rotten.corruptCRC = true
        try TestZip.write([rotten], to: zip)

        #expect(throws: UnpackFailure.yieldedNothing(label: "Rumours.zip")) {
            try Unpacker.unpack(zip: zip, into: out, freeSpace: Self.roomy)
        }
    }

    // MARK: - §2.1, before a byte is written

    @Test("it does not fit, and finding out costs nothing (player:1381)")
    func refusesWhatWillNotFit() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Kin.zip")
        let out = temp.directory("album")
        try TestZip.write([.init("01 Track.flac", String(repeating: "x", count: 4096))], to: zip)

        let failure = try #require(
            captureFailure {
                try Unpacker.unpack(
                    zip: zip, into: out, work: "/Users/x/.cache/muthur/work",
                    freeSpace: { _ in 2048 }
                )
            }
        )
        #expect(failure == .doesNotFit(label: "Kin.zip", need: 4096, have: 2048, work: "/Users/x/.cache/muthur/work"))
        // Named: the unpacked size, the free space, and the way out.
        let message = failure.description
        #expect(message.contains("4.0 KiB"))
        #expect(message.contains("2.0 KiB"))
        #expect(message.contains("MUTHUR_WORK"))
        // And not a byte of it written.
        #expect(try FileManager.default.contentsOfDirectory(atPath: out.path).isEmpty)
    }

    @Test("32 MiB of headroom, so a record that only just fits does not wedge the Mac")
    func keepsThirtyTwoMebibytesBack() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Kin.zip")
        let out = temp.directory("album")
        let size = 4096
        try TestZip.write([.init("01 Track.flac", String(repeating: "x", count: size))], to: zip)

        #expect(Unpacker.headroom == 33_554_432)
        // Exactly the margin, and no more: one byte under is a refusal.
        #expect(throws: UnpackFailure.self) {
            try Unpacker.unpack(
                zip: zip, into: out, freeSpace: { _ in UInt64(size) + Unpacker.headroom - 1 }
            )
        }
        let result = try Unpacker.unpack(
            zip: zip, into: out, freeSpace: { _ in UInt64(size) + Unpacker.headroom }
        )
        #expect(result.written == 1)
    }

    @Test("bytes as somebody who has just been told no can read them (player:1189)")
    func readableSizes() {
        #expect(UnpackFailure.room(0) == "0 B")
        #expect(UnpackFailure.room(512) == "512 B")
        #expect(UnpackFailure.room(1024) == "1.0 KiB")
        #expect(UnpackFailure.room(33_554_432) == "32.0 MiB")
        #expect(UnpackFailure.room(1_610_612_736) == "1.5 GiB")
        #expect(UnpackFailure.room(2 << 50) == "2048.0 TiB")
    }

    // MARK: - §2.2, the failure taxonomy

    @Test("encrypted: one sentence, not a prompt (player:1339)")
    func encryptedIsRefusedOutright() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Locked.zip")
        let out = temp.directory("album")
        var locked = TestZip.Member("01 Track.flac", "one")
        locked.encrypted = true
        try TestZip.write([locked, .init("02 Track.flac", "two")], to: zip)

        #expect(throws: UnpackFailure.encrypted(label: "Locked.zip")) {
            try Unpacker.unpack(zip: zip, into: out, freeSpace: Self.roomy)
        }
        // Refused before anything was written, so there is nothing to clean up.
        #expect(try FileManager.default.contentsOfDirectory(atPath: out.path).isEmpty)
    }

    @Test("truncated: it stops partway through (player:1353)")
    func truncatedArchive() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Half.zip")
        let out = temp.directory("album")
        var short = TestZip.Member("01 Track.flac", "one")
        short.overclaim = 100_000
        try TestZip.write([short], to: zip)

        let failure = try #require(
            captureFailure { try Unpacker.unpack(zip: zip, into: out, freeSpace: Self.roomy) }
        )
        #expect(failure == .truncated(label: "Half.zip", entry: "01 Track.flac"))
        #expect(failure.description.contains("ends partway through 01 Track.flac"))
    }

    @Test("not a zip: nothing that can be read as one (player:1246)")
    func notAZip() throws {
        let temp = TempDirectory()
        let out = temp.directory("album")
        let notAZip = temp.appending("sleeve.jpg")
        try Data(repeating: 0x41, count: 4096).write(to: notAZip)

        #expect(throws: UnpackFailure.notAZip(label: "sleeve.jpg")) {
            try Unpacker.unpack(zip: notAZip, into: out, freeSpace: Self.roomy)
        }
    }

    @Test("unreadable: it is there and it will not open (player:1248)")
    func unreadableArchive() throws {
        let temp = TempDirectory()
        let out = temp.directory("album")
        let zip = temp.appending("Rumours.zip")
        try TestZip.write([.init("01 Track.flac", "one")], to: zip)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: zip.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: zip.path
            )
        }

        let failure = try #require(
            captureFailure { try Unpacker.unpack(zip: zip, into: out, freeSpace: Self.roomy) }
        )
        guard case .unreadable(let label, _) = failure else {
            Issue.record("expected unreadable, got \(failure)")
            return
        }
        #expect(label == "Rumours.zip")
    }

    @Test("the source went away while it was being unpacked (player:1354)")
    func sourceVanishes() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Rumours.zip")
        let out = temp.directory("album")
        var short = TestZip.Member("02 Track.flac", "two")
        short.overclaim = 100_000
        try TestZip.write([.init("01 Track.flac", "one"), short], to: zip)

        // The open descriptor keeps reading after the file is unlinked, so the
        // second entry still comes back short — and *then* the filesystem is
        // asked which of the two it was. That question is the whole test: the
        // script's version of this once inferred a full disk from an exit code
        // on a volume with a hundred gigabytes free.
        let failure = try #require(
            captureFailure {
                try Unpacker.unpack(
                    zip: zip, into: out, freeSpace: Self.roomy,
                    progress: { _ in try? FileManager.default.removeItem(at: zip) }
                )
            }
        )
        #expect(failure == .sourceVanished(path: zip.path))
    }

    @Test("interrupted while unpacking (player:1355)")
    func interrupted() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Rumours.zip")
        let out = temp.directory("album")
        try TestZip.write((1...4).map { .init("0\($0) Track.flac", "x") }, to: zip)

        var done = 0
        #expect(throws: UnpackFailure.interrupted(label: "Rumours.zip")) {
            try Unpacker.unpack(
                zip: zip, into: out,
                freeSpace: Self.roomy,
                isCancelled: { done >= 2 }
            ) { _ in done += 1 }
        }
    }

    @Test("nothing inside it at all (player:1379)")
    func emptyArchive() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Empty.zip")
        let out = temp.directory("album")
        try TestZip.write([.init("booklet/", "")], to: zip)

        #expect(throws: UnpackFailure.empty(label: "Empty.zip")) {
            try Unpacker.unpack(zip: zip, into: out, freeSpace: Self.roomy)
        }
    }

    // MARK: - Room is asked of the disk, never inferred (player:1226)

    @Test("a write that fails on a full disk stops the album")
    func writeFailureOnAFullDiskStops() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Rumours.zip")
        let out = temp.directory("album")
        try TestZip.write([.init("01 Track.flac", "one")], to: zip)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: out.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: out.path
            )
        }

        // The fit check passes and the write still fails. Asked of the disk:
        // no room left, so this is the disk and not the name.
        var asked = 0
        let failure = try #require(
            captureFailure {
                try Unpacker.unpack(zip: zip, into: out, work: "/work") { _ in
                    asked += 1
                    return asked == 1 ? 64 * 1024 * 1024 * 1024 : 1024
                }
            }
        )
        #expect(failure == .outOfRoom(label: "Rumours.zip", free: 1024, work: "/work"))
        #expect(failure.description.contains("1.0 KiB left in /work"))
    }

    @Test("the same failure with room left is one entry, not the album (player:1345)")
    func writeFailureWithRoomLeftIsJustAnEntry() throws {
        let temp = TempDirectory()
        let zip = temp.appending("Rumours.zip")
        let out = temp.directory("album")
        let locked = temp.directory("album/booklet")
        try TestZip.write(
            [.init("booklet/scan.png", "a page"), .init("01 Track.flac", "one")], to: zip
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: locked.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: locked.path
            )
        }

        let result = try Unpacker.unpack(zip: zip, into: out, freeSpace: Self.roomy)
        #expect(result.written == 1)
        #expect(result.skipped.map(\.name) == ["booklet/scan.png"])
        #expect(contents(of: out.appending(path: "01 Track.flac")) == "one")
    }

    // MARK: -

    private func contents(of url: URL) -> String? {
        (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }
    }

    private func captureFailure(_ body: () throws -> some Any) -> UnpackFailure? {
        do {
            _ = try body()
            return nil
        } catch let failure as UnpackFailure {
            return failure
        } catch {
            Issue.record("expected an UnpackFailure, got \(error)")
            return nil
        }
    }
}
