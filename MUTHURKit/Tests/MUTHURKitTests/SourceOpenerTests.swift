import Foundation
import Testing

@testable import MUTHURKit

/// §1.1 — resolving and opening sources.
struct SourceOpenerTests {

    // MARK: - resolve

    @Test func resolveFolder() throws {
        let tmp = TempDirectory("opener-folder")
        let (url, kind) = try SourceOpener.resolve(path: tmp.url.path)
        #expect(kind == .folder)
        #expect(url.path == tmp.url.path)
    }

    @Test func resolveZip() throws {
        let tmp = TempDirectory("opener-zip")
        let zip = tmp.appending("album.zip")
        try TestZip.write(
            [TestZip.Member("01.flac", "audio")], to: zip
        )
        let (url, kind) = try SourceOpener.resolve(path: zip.path)
        #expect(kind == .zip)
        #expect(url.path == zip.path)
    }

    @Test func resolveZipUppercase() throws {
        let tmp = TempDirectory("opener-zip-upper")
        let zip = tmp.appending("album.ZIP")
        try TestZip.write(
            [TestZip.Member("01.flac", "audio")], to: zip
        )
        let (_, kind) = try SourceOpener.resolve(path: zip.path)
        #expect(kind == .zip)
    }

    @Test func resolveDirectoryNamedZip() throws {
        let tmp = TempDirectory("opener-dir-zip")
        let dir = tmp.directory("Rumours.zip")
        let (_, kind) = try SourceOpener.resolve(path: dir.path)
        #expect(kind == .folder)
    }

    @Test func resolveNonexistent() throws {
        #expect(throws: SourceOpener.Failure.self) {
            try SourceOpener.resolve(path: "/nonexistent/path/to/nothing")
        }
    }

    @Test func resolveNotASource() throws {
        let tmp = TempDirectory("opener-bad")
        let file = tmp.appending("readme.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data("hi".utf8))
        #expect(throws: SourceOpener.Failure.self) {
            try SourceOpener.resolve(path: file.path)
        }
    }

    // MARK: - open

    @Test func openFolderWithNoAudioThrows() async throws {
        let tmp = TempDirectory("opener-empty")
        await #expect(throws: Record.Failure.self) {
            try await SourceOpener.open(
                url: tmp.url, kind: .folder, progress: nil
            )
        }
    }

    @Test(.enabled(if: Fixtures.exists(Fixtures.musicLibrary)))
    func openRealFolderProducesRecord() async throws {
        let albums = Fixtures.anyTaggedAlbums(limit: 1)
        try #require(!albums.isEmpty)
        let opened = try await SourceOpener.open(
            url: albums[0], kind: .folder, progress: nil
        )
        #expect(opened.source == .folder)
        #expect(opened.titleSource == .tags)
        #expect(opened.scratch == nil)
    }

    @Test func openDiscThrows() async throws {
        await #expect(throws: SourceOpener.Failure.self) {
            try await SourceOpener.open(
                url: URL(fileURLWithPath: "/Volumes/disc"),
                kind: .disc,
                progress: nil
            )
        }
    }

    // MARK: - PickerEntry

    @Test func folderDetail() {
        #expect(PickerEntry.folderDetail(trackCount: 12) == "12 tracks · folder")
        #expect(PickerEntry.folderDetail(trackCount: 1) == "1 track · folder")
    }

    @Test func zipDetail() {
        let detail = PickerEntry.zipDetail(bytes: 4_200_000)
        #expect(detail.contains("MB"))
        #expect(detail.contains("zip"))
    }

    @Test func marks() {
        let folder = PickerEntry(kind: .folder, url: URL(fileURLWithPath: "/a"), label: "A", detail: "")
        let zip = PickerEntry(kind: .zip, url: URL(fileURLWithPath: "/b"), label: "B", detail: "")
        let disc = PickerEntry(kind: .disc, url: URL(fileURLWithPath: "/c"), label: "C", detail: "")
        #expect(folder.mark == "▸")
        #expect(zip.mark == "▤")
        #expect(disc.mark == "⊙")
    }
}
