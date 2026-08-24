import Foundation
import Testing

@testable import MUTHURKit

/// D12 — a zip's subdirectories are its discs.
///
/// The decision has two halves and they pull opposite ways, so both are pinned
/// here: nothing is ever read off what a directory is *called*, and the fact
/// that there is more than one of them is read.
@Suite("D12 — a zip's subdirectories are its discs")
struct DiscsFromDirectoriesTests {

    /// Keyed on the whole path, because the case this is about is two discs
    /// holding a `01 Track.flac` each.
    struct PathReader: MetadataReader {
        let answers: [String: RawMetadata]
        func read(_ url: URL) async -> RawMetadata {
            answers[url.path] ?? RawMetadata(duration: 10)
        }
    }

    // MARK: - The rule on its own

    @Test("one directory is one disc, and the map is empty")
    func flatArchiveIsUnchanged() {
        let files = ["/a/01.flac", "/a/02.flac"].map(URL.init(fileURLWithPath:))
        #expect(Record.discsByDirectory(of: files).isEmpty)
    }

    @Test("directories are numbered in scan order, not by their names")
    func ordinalsComeFromScanOrder() {
        // Named so that anything parsing the *name* gets the opposite answer:
        // byte order puts `A-disc-two` first, and byte order is what decides.
        let files = [
            "/album/A-disc-two/01.flac",
            "/album/A-disc-two/02.flac",
            "/album/B-disc-one/01.flac",
        ].map(URL.init(fileURLWithPath:))
        #expect(
            Record.discsByDirectory(of: files) == [
                "/album/A-disc-two": 1, "/album/B-disc-one": 2,
            ]
        )
    }

    // MARK: - The sibling guard (§18.17)

    @Test("a stray file at the top of the zip is not disc one")
    func strayAtTheTopIsNotADisc() {
        // The archive this guard is for: one loose track beside the album
        // proper. Audio in two directories, but they are a parent and its
        // child, and D12 used to call that a two-disc set — stray first.
        let files = [
            "/zip/bonus.flac",
            "/zip/Rumours/01.flac",
            "/zip/Rumours/02.flac",
        ].map(URL.init(fileURLWithPath:))
        #expect(Record.discsByDirectory(of: files).isEmpty)
    }

    @Test("a wrapper folder around the discs is the wrapper, not a disc")
    func theWrapperIsDiscarded() {
        // The same shape one level down, which is what any rule about the
        // *top* level misses: `Set` holds a stray and the two discs.
        let files = [
            "/zip/Set/read me.flac",
            "/zip/Set/CD1/01.flac",
            "/zip/Set/CD2/01.flac",
        ].map(URL.init(fileURLWithPath:))
        // The two siblings are the discs; the stray in the wrapper falls back
        // to the literal 1 the script would have given it anyway.
        #expect(Record.discsByDirectory(of: files) == ["/zip/Set/CD1": 1, "/zip/Set/CD2": 2])
    }

    @Test("directories that are not siblings are not discs")
    func cousinsAreNotDiscs() {
        let files = [
            "/zip/one/CD1/01.flac",
            "/zip/two/CD2/01.flac",
        ].map(URL.init(fileURLWithPath:))
        #expect(Record.discsByDirectory(of: files).isEmpty)
    }

    @Test("a disc of one long track is still a disc")
    func aSingleTrackDiscSurvives() {
        // What a count threshold would have thrown away: disc two is one
        // forty-minute mix, and dropping it would take the whole rule down
        // with it and interleave the set.
        let files = [
            "/zip/CD1/01.flac",
            "/zip/CD1/02.flac",
            "/zip/CD2/01 The Mix.flac",
        ].map(URL.init(fileURLWithPath:))
        #expect(Record.discsByDirectory(of: files) == ["/zip/CD1": 1, "/zip/CD2": 2])
    }

    @Test("disc one loose at the root is not detected, and says so")
    func discOneAtTheRootIsDeclined() {
        // The cost of the guard, pinned so it is a decision and not a
        // surprise: this archive is indistinguishable from the stray-file one
        // above, so nothing is guessed and both fall back to disc 1.
        let files = (1...9).map { "/zip/0\($0).flac" } + ["/zip/CD2/01.flac"]
        #expect(Record.discsByDirectory(of: files.map(URL.init(fileURLWithPath:))).isEmpty)
    }

    // MARK: - Read through

    @Test("a two-disc rip with no disc tags stops interleaving")
    func untaggedTwoDiscSetSeparates() async throws {
        let temp = TempDirectory()
        let album = temp.directory("album")
        let discs = ["CD1", "CD2"]
        var answers: [String: RawMetadata] = [:]
        for disc in discs {
            let folder = temp.directory("album/\(disc)")
            for track in 1...3 {
                let file = folder.appending(path: "0\(track) Track.flac")
                FileManager.default.createFile(atPath: file.path, contents: Data())
                answers[file.path] = RawMetadata(
                    duration: 10, track: "\(track)", title: "\(disc) track \(track)"
                )
            }
        }

        let record = try await Record.read(
            directory: album, sourceLabel: "Set.zip",
            discsFromSubdirectories: true, reader: PathReader(answers: answers)
        )

        #expect(record.running.map(\.disc) == [1, 1, 1, 2, 2, 2])
        #expect(record.running.map(\.number) == [1, 2, 3, 1, 2, 3])
        #expect(record.running.map(\.title).first == "CD1 track 1")
        #expect(record.running.map(\.title).last == "CD2 track 3")
    }

    @Test("without the rule the same folder interleaves, which is what it used to do")
    func offByDefault() async throws {
        let temp = TempDirectory()
        let album = temp.directory("album")
        var answers: [String: RawMetadata] = [:]
        for disc in ["CD1", "CD2"] {
            let folder = temp.directory("album/\(disc)")
            for track in 1...2 {
                let file = folder.appending(path: "0\(track) Track.flac")
                FileManager.default.createFile(atPath: file.path, contents: Data())
                answers[file.path] = RawMetadata(duration: 10, track: "\(track)")
            }
        }

        let record = try await Record.read(
            directory: album, sourceLabel: "Set", reader: PathReader(answers: answers)
        )
        // Two track 1s in a row, then two track 2s — §18.14's complaint, intact
        // for a folder source, which D12 deliberately does not reach.
        #expect(record.running.map(\.disc) == [1, 1, 1, 1])
        #expect(record.running.map(\.number) == [1, 1, 2, 2])
    }

    @Test("a disc tag always wins over the directory it sits in")
    func tagsBeatDirectories() async throws {
        let temp = TempDirectory()
        let album = temp.directory("album")
        var answers: [String: RawMetadata] = [:]
        // Correctly tagged and put in folders whose order disagrees: `bonus`
        // sorts after `Album`, and disc 1 is inside it. The tags decide.
        let placements: [(folder: String, disc: String, track: String)] = [
            ("Album", "2", "1"),
            ("bonus", "1", "1"),
        ]
        for placement in placements {
            let folder = temp.directory("album/\(placement.folder)")
            let file = folder.appending(path: "0\(placement.track) Track.flac")
            FileManager.default.createFile(atPath: file.path, contents: Data())
            answers[file.path] = RawMetadata(
                duration: 10, track: placement.track, disc: placement.disc,
                title: "disc \(placement.disc)"
            )
        }

        let record = try await Record.read(
            directory: album, sourceLabel: "Set.zip",
            discsFromSubdirectories: true, reader: PathReader(answers: answers)
        )
        #expect(record.running.map(\.disc) == [1, 2])
        #expect(record.running.map(\.title) == ["disc 1", "disc 2"])
    }

    @Test("the rule fills the gap the script fills with a literal 1, and only that")
    func fillsOnlyTheGap() async throws {
        let temp = TempDirectory()
        let album = temp.directory("album")
        var answers: [String: RawMetadata] = [:]
        let first = temp.directory("album/one").appending(path: "01 Track.flac")
        let second = temp.directory("album/two").appending(path: "01 Track.flac")
        FileManager.default.createFile(atPath: first.path, contents: Data())
        FileManager.default.createFile(atPath: second.path, contents: Data())
        // One tagged, one not. The tagged file keeps its 1; the untagged one
        // takes the ordinal of the directory it came out of.
        answers[first.path] = RawMetadata(duration: 10, track: "1", disc: "1")
        answers[second.path] = RawMetadata(duration: 10, track: "1")

        let record = try await Record.read(
            directory: album, sourceLabel: "Set.zip",
            discsFromSubdirectories: true, reader: PathReader(answers: answers)
        )
        #expect(record.running.map(\.disc) == [1, 2])
    }

    // MARK: - Out of an actual archive

    @Test("out of a zip, end to end")
    func throughTheUnpacker() async throws {
        let temp = TempDirectory()
        let zip = temp.appending("Set.zip")
        let out = temp.directory("album")
        try TestZip.write(
            [
                .init("CD1/01 Track.flac", "a"),
                .init("CD1/02 Track.flac", "b"),
                .init("CD2/01 Track.flac", "c"),
                .init("cover.jpg", "a sleeve"),
            ],
            to: zip
        )

        let unpacked = try Unpacker.unpack(
            zip: zip, into: out, freeSpace: { _ in 64 * 1024 * 1024 * 1024 }
        )
        // The sleeve is not audio, so it is not a disc — the directories the
        // rule counts are the ones the *scan* found audio in.
        #expect(unpacked.directories.count == 3)

        let record = try await Record.read(
            directory: out, sourceLabel: "Set.zip",
            discsFromSubdirectories: true,
            reader: UntaggedReader()
        )
        #expect(record.running.map(\.disc) == [1, 1, 2])
        #expect(record.album == "Set")
    }
}

/// Every file readable and nothing tagged at all, which is the rip D12 is for.
struct UntaggedReader: MetadataReader {
    var duration: Double = 10
    func read(_ url: URL) async -> RawMetadata { RawMetadata(duration: duration) }
}
