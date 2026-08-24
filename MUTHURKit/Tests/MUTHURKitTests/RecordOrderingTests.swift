import Foundation
import Testing

@testable import MUTHURKit

/// §3 and §3.1 read whole: a folder of names, a set of tags, and the order it
/// comes out in.
///
/// The files on disk are zero bytes — the names are the only thing about them
/// that matters, and `StubMetadataReader` says what the tags would have been.
/// This is how the degenerate cases get built exactly rather than approximately.
@Suite("§3 — reading a folder and ordering it")
struct RecordOrderingTests {

    /// Every file the same length, so that TOTAL and the ordering can be read
    /// independently of one another.
    static func tagged(
        track: String? = nil, disc: String? = nil, title: String? = nil,
        album: String? = nil, artist: String? = nil, albumArtist: String? = nil,
        date: String? = nil, duration: Double = 10
    ) -> RawMetadata {
        RawMetadata(
            duration: duration, track: track, disc: disc, title: title, album: album,
            artist: artist, albumArtist: albumArtist, date: date
        )
    }

    // MARK: - The ordinary case

    @Test("order is disc, then track, and not the filename")
    func metadataDecidesTheOrder() async throws {
        // Named backwards on purpose: if this comes out in filename order the
        // rule that matters most in the whole program has been lost.
        let folder = try NamedFolder(
            "Unknown Pleasures",
            files: ["a.flac", "b.flac", "c.flac"]
        )
        let record = try await Record.read(
            directory: folder.url,
            sourceLabel: "Unknown Pleasures",
            reader: StubMetadataReader([
                "a.flac": Self.tagged(track: "3", title: "Third"),
                "b.flac": Self.tagged(track: "1", title: "First"),
                "c.flac": Self.tagged(track: "2", title: "Second"),
            ])
        )
        #expect(record.running.map(\.title) == ["First", "Second", "Third"])
        #expect(record.running.map(\.number) == [1, 2, 3])
    }

    @Test("disc sorts above track")
    func discComesFirst() async throws {
        let folder = try NamedFolder("Set", files: ["a.flac", "b.flac", "c.flac", "d.flac"])
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Set",
            reader: StubMetadataReader([
                "a.flac": Self.tagged(track: "1", disc: "2", title: "2-1"),
                "b.flac": Self.tagged(track: "2", disc: "1", title: "1-2"),
                "c.flac": Self.tagged(track: "1", disc: "1", title: "1-1"),
                "d.flac": Self.tagged(track: "2", disc: "2", title: "2-2"),
            ])
        )
        #expect(record.running.map(\.title) == ["1-1", "1-2", "2-1", "2-2"])
    }

    @Test("TOTAL is the sum of the ordered durations (player:1513)")
    func totalIsTheSum() async throws {
        let folder = try NamedFolder("Sums", files: ["a.flac", "b.flac"])
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Sums",
            reader: StubMetadataReader([
                // Both round up before they are summed, so this is 135 + 199
                // and not 332.
                "a.flac": Self.tagged(track: "1", duration: 134.466757),
                "b.flac": Self.tagged(track: "2", duration: 198.2),
            ])
        )
        #expect(record.running.map(\.duration) == [135, 199])
        #expect(record.total == 334)
    }

    // MARK: - §3.1, the degenerate cases

    @Test("missing track numbers land on 9999 together, then sort naturally")
    func untaggedFallsToNaturalFilenameOrder() async throws {
        // The case the natural sort exists for: no tags at all, and a plain
        // sort would put track10 between track1 and track2.
        let folder = try NamedFolder(
            "Untagged",
            files: ["track1.flac", "track2.flac", "track3.flac", "track10.flac", "track20.flac"]
        )
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Untagged",
            reader: StubMetadataReader([
                "track1.flac": Self.tagged(),
                "track2.flac": Self.tagged(),
                "track3.flac": Self.tagged(),
                "track10.flac": Self.tagged(),
                "track20.flac": Self.tagged(),
            ])
        )
        #expect(record.running.allSatisfy { $0.number == 9999 })
        #expect(
            record.running.map { $0.url.lastPathComponent } == [
                "track1.flac", "track2.flac", "track3.flac", "track10.flac", "track20.flac",
            ]
        )
        #expect(record.unnumberedCount == 5)
    }

    @Test("9999 sorts after every real number, so one untagged file cannot displace an album")
    func untaggedGoesLast() async throws {
        let folder = try NamedFolder(
            "Mixed", files: ["aaa bonus.flac", "one.flac", "two.flac"]
        )
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Mixed",
            reader: StubMetadataReader([
                // Sorts first by name and has no number: it must still go last.
                "aaa bonus.flac": Self.tagged(title: "Bonus"),
                "one.flac": Self.tagged(track: "1", title: "One"),
                "two.flac": Self.tagged(track: "2", title: "Two"),
            ])
        )
        #expect(record.running.map(\.title) == ["One", "Two", "Bonus"])
        #expect(record.unnumberedCount == 1)
    }

    @Test("a duplicate (disc, track) is not an error — both copies play")
    func duplicateTrackNumbersBothPlay() async throws {
        // What a folder holding `03 Song.flac` and `03 Song (alt take).flac`
        // produces. A record that plays a bonus take twice in a row is
        // self-evidently what is happening; a record that refuses to play is
        // not.
        let folder = try NamedFolder(
            "Alts",
            files: ["03 Song (alt take).flac", "03 Song.flac", "04 Next.flac"]
        )
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Alts",
            reader: StubMetadataReader([
                "03 Song.flac": Self.tagged(track: "3", title: "Song"),
                "03 Song (alt take).flac": Self.tagged(track: "3", title: "Song (alt take)"),
                "04 Next.flac": Self.tagged(track: "4", title: "Next"),
            ])
        )
        // Three rows for an album whose tags claim two, ordered by name where
        // the numbers tied — `03 Song (alt take).flac` before `03 Song.flac`,
        // because a space sorts under a full stop.
        #expect(record.running.count == 3)
        #expect(record.running.map(\.title) == ["Song (alt take)", "Song", "Next"])
        #expect(record.total == 30)
    }

    @Test("a duplicate track number resolves to the first file, and only that one")
    func fileIndexTakesTheFirstMatch() async throws {
        let folder = try NamedFolder("Alts", files: ["a.flac", "b.flac"])
        var record = try await Record.read(
            directory: folder.url, sourceLabel: "Alts",
            reader: StubMetadataReader([
                "a.flac": Self.tagged(track: "3", title: "First three"),
                "b.flac": Self.tagged(track: "3", title: "Second three"),
            ])
        )
        let index = try #require(record.fileIndex(ofTrackNumber: 3))
        #expect(record.tracks[index].title == "First three")

        // §4 will write through this. The other copy keeps what it had, which
        // is better than refusing to label either.
        record.tracks[index].title = "From CD-Text"
        #expect(record.tracks.map(\.title) == ["From CD-Text", "Second three"])
        #expect(record.fileIndex(ofTrackNumber: 99) == nil)
    }

    @Test("a track number is not a row number (player:1518)")
    func trackNumbersAreNotRowNumbers() async throws {
        // Scan order is alphabetical; the running order is not. Indexing track
        // 1 as `n - 1` would land on the wrong file, which is the whole reason
        // the lookup exists.
        let folder = try NamedFolder("Skew", files: ["a.flac", "b.flac", "c.flac"])
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Skew",
            reader: StubMetadataReader([
                "a.flac": Self.tagged(track: "12", title: "Twelve"),
                "b.flac": Self.tagged(track: "1", title: "One"),
                "c.flac": Self.tagged(track: "7", title: "Seven"),
            ])
        )
        // Scan order.
        #expect(record.tracks.map(\.title) == ["Twelve", "One", "Seven"])
        // Running order.
        #expect(record.running.map(\.title) == ["One", "Seven", "Twelve"])
        // The file carrying track 12 is scan index 0 and row 2. Both answers
        // are available and they are different numbers.
        #expect(record.fileIndex(ofTrackNumber: 12) == 0)
        #expect(record.row(ofTrackNumber: 12) == 2)
        #expect(record.fileIndex(ofTrackNumber: 1) == 1)
        #expect(record.row(ofTrackNumber: 1) == 0)
    }

    @Test("`08` survives the whole read, not just the parser")
    func octalLookingTagsOrderCorrectly() async throws {
        let folder = try NamedFolder(
            "Zeroes", files: ["g.flac", "h.flac", "i.flac", "j.flac"]
        )
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Zeroes",
            reader: StubMetadataReader([
                "g.flac": Self.tagged(track: "07", title: "Seven"),
                "h.flac": Self.tagged(track: "08", title: "Eight"),
                "i.flac": Self.tagged(track: "09", title: "Nine"),
                "j.flac": Self.tagged(track: "10", title: "Ten"),
            ])
        )
        // In bash, 08 and 09 are rejected as bad octal and land on 9999 —
        // which puts two tracks of every correctly tagged album at the end.
        #expect(record.running.map(\.number) == [7, 8, 9, 10])
        #expect(record.running.map(\.title) == ["Seven", "Eight", "Nine", "Ten"])
        #expect(record.unnumberedCount == 0)
    }

    @Test("`3/12` keeps the 3 through a whole album")
    func slashedTagsOrderCorrectly() async throws {
        let folder = try NamedFolder("Slashes", files: ["a.flac", "b.flac", "c.flac"])
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Slashes",
            reader: StubMetadataReader([
                "a.flac": Self.tagged(track: "3/12", disc: "1/2", title: "Three"),
                "b.flac": Self.tagged(track: "11/12", disc: "1/2", title: "Eleven"),
                "c.flac": Self.tagged(track: "2/9", disc: "2/2", title: "Disc two, two"),
            ])
        )
        #expect(record.running.map(\.number) == [3, 11, 2])
        #expect(record.running.map(\.disc) == [1, 1, 2])
        #expect(record.running.map(\.title) == ["Three", "Eleven", "Disc two, two"])
    }

    @Test("tab and newline are gone before anything is ordered or labelled")
    func flattenedThroughTheRead() async throws {
        let folder = try NamedFolder("Flat", files: ["a.flac"])
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Flat",
            reader: StubMetadataReader([
                "a.flac": Self.tagged(
                    track: "1", title: "Sunday\tBloody\nSunday",
                    album: "War\ttime", artist: "U\n2", albumArtist: "U\r2"
                )
            ])
        )
        #expect(record.running[0].title == "Sunday Bloody Sunday")
        #expect(record.running[0].artist == "U 2")
        #expect(record.album == "War time")
        #expect(record.albumArtist == "U 2")
        for text in [record.album, record.albumArtist, record.running[0].title] {
            #expect(!text.contains("\t"))
            #expect(!text.contains("\n"))
            #expect(!text.contains("\r"))
        }
    }

    // MARK: - Album, artist, year

    @Test("album, album artist and year come from the first file that carries each")
    func albumFieldsComeFromTheFirstFileThatHasThem() async throws {
        let folder = try NamedFolder("Partly", files: ["a.flac", "b.flac", "c.flac"])
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Partly",
            reader: StubMetadataReader([
                // Nothing but a track number.
                "a.flac": Self.tagged(track: "1"),
                "b.flac": Self.tagged(track: "2", album: "Rumours", artist: "Fleetwood Mac"),
                "c.flac": Self.tagged(
                    track: "3", album: "Ignored", albumArtist: "Ignored too",
                    date: "1977-02-04T08:00:00Z"
                ),
            ])
        )
        #expect(record.album == "Rumours")
        // Album artist falls back to the artist on the same file.
        #expect(record.albumArtist == "Fleetwood Mac")
        // The year came from the third file, because the first two had no date
        // at all — each field is chased independently.
        #expect(record.year == "1977")
    }

    @Test("album falls back to the folder's own name (player:1497)")
    func albumFallsBackToFolderName() async throws {
        let folder = try NamedFolder("Selected Ambient Works 85-92", files: ["a.flac"])
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Selected Ambient Works 85-92",
            reader: StubMetadataReader(["a.flac": Self.tagged(track: "1")])
        )
        #expect(record.album == "Selected Ambient Works 85-92")
        #expect(record.albumArtist == "")
        #expect(record.year == "")
    }

    @Test("album falls back to the zip's name with the .zip taken off")
    func albumFallsBackToZipName() {
        #expect(Record.albumFromSourceLabel("KMRU - Kin.zip") == "KMRU - Kin")
        #expect(
            Record.albumFromSourceLabel("Yui Onodera + Celer - Generic City.zip")
                == "Yui Onodera + Celer - Generic City"
        )
        #expect(Record.albumFromSourceLabel("Rumours") == "Rumours")
        // §18.16, resolved: `${SRC_LABEL%.zip}` matches the suffix exactly while
        // §1.1 accepts a `.ZIP` source, so a zip named in capitals used to put
        // its extension across the top of the panel.
        #expect(Record.albumFromSourceLabel("KMRU - Kin.ZIP") == "KMRU - Kin")
        #expect(Record.albumFromSourceLabel("KMRU - Kin.Zip") == "KMRU - Kin")
        // Nothing else comes off. A folder is its own name entire.
        #expect(Record.albumFromSourceLabel("zip") == "zip")
        #expect(Record.albumFromSourceLabel(".zip") == "")
    }

    // MARK: - What is missing, and what is fatal

    @Test("a file nothing can read is skipped, not fatal (player:1443)")
    func unreadableFilesAreSkipped() async throws {
        let folder = try NamedFolder("Twelve", files: (1...12).map { "\($0).flac" })
        var answers: [String: RawMetadata] = [:]
        for n in 1...12 {
            // One bad track in a zip, and eleven good ones are still an album
            // worth playing.
            answers["\(n).flac"] =
                n == 5
                ? RawMetadata()
                : Self.tagged(track: "\(n)", title: "Track \(n)")
        }
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Twelve",
            reader: StubMetadataReader(answers)
        )
        #expect(record.tracks.count == 11)
        #expect(record.unreadableCount == 1)
        #expect(!record.running.contains { $0.number == 5 })
        #expect(record.total == 110)
    }

    @Test("the loading meter counts a file it could not read (player:1445, §18.12)")
    func skippedFilesStillAdvanceTheMeter() async throws {
        let folder = try NamedFolder("Meter", files: ["a.flac", "b.flac", "c.flac", "d.flac"])
        let seen = Progress()
        _ = try await Record.read(
            directory: folder.url, sourceLabel: "Meter",
            reader: StubMetadataReader([
                "a.flac": Self.tagged(track: "1"),
                "b.flac": RawMetadata(),
                "c.flac": Self.tagged(track: "3"),
                "d.flac": Self.tagged(track: "4"),
            ]),
            progress: { seen.append($0) }
        )
        // Three reports for four files, because the skipped one does not draw
        // a line — but it advanced the count, so the meter still arrives at
        // 100% rather than stopping at 75%.
        #expect(seen.percents == [25, 75, 100])
        #expect(seen.last?.total == 4)
    }

    @Test("no audio at all, and nothing readable, are different failures")
    func theTwoFailures() async throws {
        let empty = try NamedFolder("Empty", files: ["sleeve.jpg", "notes.txt"])
        await #expect(throws: Record.Failure.noAudio(source: "Empty")) {
            try await Record.read(
                directory: empty.url, sourceLabel: "Empty", reader: StubMetadataReader([:])
            )
        }

        let unreadable = try NamedFolder("Broken", files: ["a.flac", "b.flac"])
        await #expect(throws: Record.Failure.noReadableAudio(source: "Broken")) {
            try await Record.read(
                directory: unreadable.url, sourceLabel: "Broken",
                reader: StubMetadataReader(["a.flac": RawMetadata(), "b.flac": RawMetadata()])
            )
        }
    }

    // MARK: - The scan itself

    @Test("audio is found at any depth, and the non-audio ignored (§1.4)")
    func scanReachesAnyDepth() async throws {
        let folder = try NamedFolder(
            "Deep",
            files: [
                "CD1/01.flac", "CD1/02.flac", "CD2/01.flac",
                "scans/booklet.jpg", "cover.jpg", "notes.txt",
            ]
        )
        let found = AudioFiles.scan(folder.url)
        #expect(found.count == 3)
        #expect(found.allSatisfy { $0.pathExtension == "flac" })
        // Byte order over the whole path, so the scan is the same on any
        // machine.
        #expect(
            found.map { $0.lastPathComponent } == ["01.flac", "02.flac", "01.flac"]
        )
    }

    @Test("every accepted extension is accepted, in any case (player:1046)")
    func acceptedExtensions() {
        for ext in ["aif", "aiff", "flac", "mp3", "ogg", "opus", "wav", "m4a", "wma", "ape", "alac", "mp4"] {
            #expect(AudioFiles.isAudio(URL(fileURLWithPath: "/x/song.\(ext)")))
            #expect(AudioFiles.isAudio(URL(fileURLWithPath: "/x/song.\(ext.uppercased())")))
        }
        #expect(!AudioFiles.isAudio(URL(fileURLWithPath: "/x/cover.jpg")))
        #expect(!AudioFiles.isAudio(URL(fileURLWithPath: "/x/notes.txt")))
        #expect(!AudioFiles.isAudio(URL(fileURLWithPath: "/x/flac")))
    }
}

/// Somewhere for the progress callback to land, since it is handed across a
/// concurrency boundary.
final class Progress: @unchecked Sendable {
    private let lock = NSLock()
    private var reports: [Record.Progress] = []

    func append(_ report: Record.Progress) {
        lock.lock()
        defer { lock.unlock() }
        reports.append(report)
    }

    var percents: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return reports.map(\.percent)
    }

    var last: Record.Progress? {
        lock.lock()
        defer { lock.unlock() }
        return reports.last
    }
}
