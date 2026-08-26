import Foundation
import Testing

@testable import MUTHURKit

/// §1.2 — the scanner that finds what there is to play.
struct SourceScannerTests {

    // MARK: - Default directories

    @Test func defaultDirectoriesFromMUTHURDirs() {
        let dirs = SourceScanner.defaultDirectories(
            environment: ["MUTHUR_DIRS": "/a:/b"],
            home: URL(fileURLWithPath: "/Users/test")
        )
        #expect(dirs.map(\.path) == ["/a", "/b"])
    }

    @Test func defaultDirectoriesFallbackToPLAYERDirs() {
        let dirs = SourceScanner.defaultDirectories(
            environment: ["PLAYER_DIRS": "/x"],
            home: URL(fileURLWithPath: "/Users/test")
        )
        #expect(dirs.map(\.path) == ["/x"])
    }

    @Test func defaultDirectoriesExpandsTilde() {
        let home = URL(fileURLWithPath: "/Users/test")
        let dirs = SourceScanner.defaultDirectories(environment: [:], home: home)
        #expect(dirs.contains(where: { $0.path.contains("Music") }))
        #expect(dirs.contains(where: { $0.path.contains("Downloads") }))
    }

    // MARK: - Scanning

    @Test func emptyDirectoryReturnsNothing() {
        let tmp = TempDirectory("scanner-empty")
        let entries = SourceScanner.scan(directories: [tmp.url])
        #expect(entries.isEmpty)
    }

    @Test func oneFolderWithAudioReturnsOneEntry() throws {
        let tmp = TempDirectory("scanner-one")
        let album = tmp.directory("Album")
        FileManager.default.createFile(
            atPath: album.appending(path: "01.flac").path, contents: Data()
        )
        FileManager.default.createFile(
            atPath: album.appending(path: "02.flac").path, contents: Data()
        )

        let entries = SourceScanner.scan(directories: [tmp.url])
        #expect(entries.count == 1)
        #expect(entries[0].kind == .folder)
        #expect(entries[0].label == "Album")
        #expect(entries[0].detail.contains("2 tracks"))
        #expect(entries[0].mark == "▸")
    }

    @Test func zipsBeforeFolders() throws {
        let tmp = TempDirectory("scanner-order")
        let album = tmp.directory("Zeta")
        FileManager.default.createFile(
            atPath: album.appending(path: "01.mp3").path, contents: Data()
        )
        let zip = tmp.appending("Alpha.zip")
        try TestZip.write(
            [TestZip.Member("track.flac", "audio")], to: zip
        )

        let entries = SourceScanner.scan(directories: [tmp.url])
        #expect(entries.count == 2)
        #expect(entries[0].kind == .zip)
        #expect(entries[0].label == "Alpha.zip")
        #expect(entries[1].kind == .folder)
        #expect(entries[1].label == "Zeta")
    }

    @Test func lcAllCSortOrder() throws {
        let tmp = TempDirectory("scanner-sort")
        for name in ["Beta", "Alpha", "Gamma"] {
            let dir = tmp.directory(name)
            FileManager.default.createFile(
                atPath: dir.appending(path: "01.flac").path, contents: Data()
            )
        }

        let entries = SourceScanner.scan(directories: [tmp.url])
        let names = entries.map(\.label)
        #expect(names == names.sorted { AudioFiles.byteOrder($0, $1) == .orderedAscending })
    }

    @Test func anyDepthCountMatchesPlayback() throws {
        let tmp = TempDirectory("scanner-depth")
        let album = tmp.directory("Album")
        let cd1 = album.appending(path: "CD1")
        try FileManager.default.createDirectory(at: cd1, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: cd1.appending(path: "01.flac").path, contents: Data()
        )
        FileManager.default.createFile(
            atPath: cd1.appending(path: "02.flac").path, contents: Data()
        )

        let entries = SourceScanner.scan(directories: [tmp.url])
        #expect(entries.count == 1)
        #expect(entries[0].detail.contains("2 tracks"))
    }

    @Test func rootDirectoryExcluded() throws {
        let tmp = TempDirectory("scanner-root")
        FileManager.default.createFile(
            atPath: tmp.url.appending(path: "01.flac").path, contents: Data()
        )
        let child = tmp.directory("Child")
        FileManager.default.createFile(
            atPath: child.appending(path: "01.flac").path, contents: Data()
        )

        let entries = SourceScanner.scan(directories: [tmp.url])
        #expect(entries.count == 1)
        #expect(entries[0].label == "Child")
    }

    @Test func perRootOrdering() throws {
        let root1 = TempDirectory("scanner-root1")
        let root2 = TempDirectory("scanner-root2")
        let zulu1 = root1.directory("Zulu")
        FileManager.default.createFile(
            atPath: zulu1.appending(path: "01.flac").path, contents: Data()
        )
        let alpha2 = root2.directory("Alpha")
        FileManager.default.createFile(
            atPath: alpha2.appending(path: "01.flac").path, contents: Data()
        )

        let entries = SourceScanner.scan(directories: [root1.url, root2.url])
        #expect(entries.count == 2)
        #expect(entries[0].label == "Zulu")
        #expect(entries[1].label == "Alpha")
    }

    @Test func nonAudioDirectoriesExcluded() throws {
        let tmp = TempDirectory("scanner-noaudio")
        let docs = tmp.directory("Documents")
        FileManager.default.createFile(
            atPath: docs.appending(path: "readme.txt").path, contents: Data()
        )

        let entries = SourceScanner.scan(directories: [tmp.url])
        #expect(entries.isEmpty)
    }

    @Test func zipMarksCorrect() throws {
        let tmp = TempDirectory("scanner-marks")
        let zip = tmp.appending("album.zip")
        try TestZip.write(
            [TestZip.Member("song.mp3", "data")], to: zip
        )

        let entries = SourceScanner.scan(directories: [tmp.url])
        #expect(entries.count == 1)
        #expect(entries[0].mark == "▤")
    }
}
