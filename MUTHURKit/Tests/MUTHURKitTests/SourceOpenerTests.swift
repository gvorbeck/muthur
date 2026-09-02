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

    // MARK: - Which archives are records (D47, now at the door)

    // These were `SourceScannerTests`. **D50** deleted the scan, and D47's rule
    // came with them into `resolve`, which is now the only place a zip is ever
    // judged. The rule is the same rule; what changed is who it is answering —
    // the picker was choosing what to *offer*, and this is answering a file
    // somebody has just pointed at. `droppingArchivesKeepsOrder` did not come
    // over: it asserted that the filter ran after the `LC_ALL=C` sort, and there
    // is no longer a list for anything to be in order in.

    /// The reason the rule exists: `~/Downloads` is where zips go, and most of
    /// them are not albums. Picking one off `BROWSE` should say so rather than
    /// open an empty record.
    @Test func archiveWithoutAudioIsRefused() throws {
        let tmp = TempDirectory("opener-zip-pdf")
        let zip = tmp.appending("Rules.zip")
        try TestZip.write(
            [
                TestZip.Member("Rulebook.pdf", "%PDF"),
                TestZip.Member("Errata.docx", "PK"),
            ],
            to: zip
        )

        #expect(throws: SourceOpener.Failure.noAudioInArchive(path: zip.path)) {
            try SourceOpener.resolve(path: zip.path)
        }
        // And it says which file, in `Record.Failure.noAudio`'s words.
        #expect(
            SourceOpener.Failure.noAudioInArchive(path: zip.path).description
                == "no audio in Rules.zip")
    }

    /// One audio member is enough — the folder rule is `audio_count > 0`
    /// (`player:1039`) and this is that rule, not a stricter one.
    @Test func archiveWithOneAudioMemberIsLetThrough() throws {
        let tmp = TempDirectory("opener-zip-mixed")
        let zip = tmp.appending("Album.zip")
        try TestZip.write(
            [
                TestZip.Member("Album/cover.jpg", "jpeg"),
                TestZip.Member("Album/notes.txt", "hello"),
                TestZip.Member("Album/01 Track.FLAC", "audio"),
            ],
            to: zip
        )

        let (url, kind) = try SourceOpener.resolve(path: zip.path)
        #expect(kind == .zip)
        #expect(url.path == zip.path)
    }

    /// The AppleDouble case. `AudioFiles.scan` walks with `.skipsHiddenFiles`,
    /// so `__MACOSX/._Song.flac` is not a track once it is on disk; an archive
    /// holding only those would open as an empty record.
    @Test func appleDoubleStubIsNotAudio() throws {
        let tmp = TempDirectory("opener-zip-appledouble")
        let zip = tmp.appending("Ghost.zip")
        try TestZip.write(
            [
                TestZip.Member("__MACOSX/._Song.flac", "stub"),
                TestZip.Member("readme.txt", "hello"),
            ],
            to: zip
        )

        #expect(throws: SourceOpener.Failure.noAudioInArchive(path: zip.path)) {
            try SourceOpener.resolve(path: zip.path)
        }
    }

    /// **The one that inverted.** A `.zip` whose central directory will not read
    /// was dropped by the scan, because the scan was listing what would play. At
    /// the door the answer is the other way round: `BROWSE` exists precisely so
    /// that the archive the central directory would not read can still be tried,
    /// and the unzip is a better judge of a damaged archive than a probe that
    /// only ever peeked at the end of it. It is let through, and fails — with
    /// whatever the unzip actually found — when it is opened.
    @Test func unreadableArchiveIsLetThroughToFailOnOpening() throws {
        let tmp = TempDirectory("opener-zip-broken")
        let zip = tmp.appending("Broken.zip")
        try Data("this is not an archive".utf8).write(to: zip)

        let (_, kind) = try SourceOpener.resolve(path: zip.path)
        #expect(kind == .zip)
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

    /// **This used to assert `discNotImplemented`, and §1.3 is why it no longer
    /// can.** A `.disc` source is now read like any other directory of audio, so
    /// a mount point with nothing playable on it fails where a folder would —
    /// `Record.Failure`, from the read — rather than being refused at the door.
    ///
    /// The disc's own refusal moved to where the disc is *looked for*:
    /// `--cd` with an empty drive is `SourceOpener.Failure.noDisc`, raised by
    /// the caller before there is a URL to open at all (`player:3528`).
    @Test func openingADiscPathWithNoAudioFailsLikeAnyOtherRead() async throws {
        let tmp = TempDirectory("disc-empty")
        await #expect(throws: Record.Failure.self) {
            try await SourceOpener.open(url: tmp.url, kind: .disc, progress: nil)
        }
    }

    // MARK: - PickerEntry

    // `folderDetail` and `zipDetail` — and the `du -h` arithmetic under the
    // second, which was five assertions of its own — went with the scan (D50).
    // Their strings were for rows nothing builds now.

    @Test func discDetail() {
        #expect(PickerEntry.discDetail(trackCount: 12) == "12 tracks · in the drive")
        #expect(PickerEntry.discDetail(trackCount: 1) == "1 track · in the drive")
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
