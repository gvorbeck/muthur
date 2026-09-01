import Foundation
import Testing

@testable import MUTHURKit

/// §12 — what `-n` prints, against `player:3540`'s four `printf`s.
///
/// Every expectation here is a byte count as much as a string: the listing's
/// whole value is that it lines up in a terminal nobody is drawing on, and the
/// only thing holding the columns together is `%2d`, `fit … 52` and `%6s`.
@Suite("§12 — inspect mode")
struct InspectTests {

    private func track(_ number: Int, _ title: String, _ seconds: Int) -> Track {
        Track(
            url: URL(fileURLWithPath: "/albums/A/\(number).flac"),
            duration: seconds, title: title, artist: "", number: number, disc: 1
        )
    }

    private func record(
        _ tracks: [Track],
        album: String = "Rumours",
        artist: String = "Fleetwood Mac",
        year: String = "1977"
    ) -> Record {
        Record(
            tracks: tracks, album: album, albumArtist: artist, year: year,
            sourceLabel: "Rumours"
        )
    }

    // MARK: - The two heading lines

    /// `printf '\n  %s — %s (%s)\n'` and `printf '  %d tracks, %s, from %s\n\n'`.
    @Test("The heading is an album line, a summary line and a blank one")
    func heading() {
        let text = Inspect.text(
            record: record([track(1, "Second Hand News", 173), track(2, "Dreams", 257)]),
            titleSource: .tags
        )
        let lines = text.components(separatedBy: "\n")
        #expect(lines[0] == "")
        #expect(lines[1] == "  Rumours — Fleetwood Mac (1977)")
        #expect(lines[2] == "  2 tracks, 7:10, from tags")
        #expect(lines[3] == "")
    }

    /// `$META_SOURCE` is printed raw, and the four things it can be are the four
    /// `TitleSource` cases spelled exactly as the panel spells them
    /// (`player:1414`, `player:2112`, `player:2229`, `player:2237`).
    @Test("The summary line names the title source in the panel's own words")
    func titleSourceIsPrintedRaw() {
        for source in TitleSource.allCases {
            let text = Inspect.text(record: record([track(1, "A", 60)]), titleSource: source)
            #expect(text.contains(", from \(source.rawValue)\n"))
        }
    }

    /// **`%d tracks`, unconditionally.** A single prints `1 tracks`. Kept.
    @Test("A one-track record still says tracks")
    func pluralIsNotConditional() {
        let text = Inspect.text(record: record([track(1, "Alone", 61)]), titleSource: .tags)
        #expect(text.contains("  1 tracks, 1:01, from tags\n"))
    }

    /// **`${X:-—}` three times over, under a separator that is also an em
    /// dash.** An untagged record's heading is four dashes and a pair of
    /// brackets, and it reads as a rule rather than as three absences. Kept.
    @Test("Nothing tagged prints em dashes, including where one is already a separator")
    func absentFieldsBecomeEmDashes() {
        let text = Inspect.text(
            record: record([track(1, "01", 60)], album: "", artist: "", year: ""),
            titleSource: .trackNumbers
        )
        #expect(text.components(separatedBy: "\n")[1] == "  — — — (—)")
    }

    /// **§12's third requirement**: the year here and the year on the panel are
    /// one year, from one precedence (D6). The script could not get this wrong —
    /// it had a single `YEAR` global and both printed it — so the only way to
    /// keep the property is for both to call `HeaderBlock.year`.
    @Test("The year is the panel's year, by the panel's precedence")
    func theYearIsThePanelsYear() {
        let one = record([track(1, "A", 60)], year: "1977")
        let shelf = HeaderBlock.Shelf(shelf: "A3", note: "", year: "1998")

        // MusicBrainz overwrites the tags (`player:2215`) …
        #expect(
            Inspect.text(record: one, titleSource: .tags, releaseYear: "1976")
                .contains("(1976)"))
        // … the tags fill in where it did not answer …
        #expect(
            Inspect.text(record: one, titleSource: .tags, shelf: shelf).contains("(1977)"))
        // … and the shelf is last, reached only when nothing else had a year.
        let untagged = record([track(1, "A", 60)], year: "")
        #expect(
            Inspect.text(record: untagged, titleSource: .tags, shelf: shelf)
                .contains("(1998)"))

        // Whatever the three legs hold, it is the year `HeaderBlock` picked —
        // which is the value the `ARTIST` row is built from. The two *render*
        // it differently and always did: the script's `(%s)` is unconditional
        // (`player:3542`) while `artistLine` drops the brackets when there is
        // no year, so what is compared is the year, not the punctuation.
        for legs in [("1977", "1976", "1998"), ("", "", "1998"), ("", "", "")] {
            let subject = record([track(1, "A", 60)], year: legs.0)
            let mb = legs.1.isEmpty ? nil : legs.1
            let onShelf = HeaderBlock.Shelf(shelf: "A3", note: "", year: legs.2)
            let picked = HeaderBlock.year(
                tags: legs.0, musicBrainz: mb, collection: legs.2)
            let line = Inspect.text(
                record: subject, titleSource: .tags, releaseYear: mb, shelf: onShelf
            ).components(separatedBy: "\n")[1]
            #expect(line.hasSuffix("(\(picked.isEmpty ? "—" : picked))"))

            let artist = HeaderBlock(record: subject, releaseYear: mb, shelf: onShelf)
                .rows.first { $0.label == "ARTIST" }?.value
            #expect(artist == HeaderBlock.artistLine(subject.albumArtist, year: picked))
            if !picked.isEmpty { #expect(artist?.hasSuffix("(\(picked))") == true) }
        }
    }

    // MARK: - The track lines

    /// `printf '   %2d. %s %6s\n'`: three spaces, the row in two, a full stop
    /// and a space, fifty-two of title, a space, six of duration.
    @Test("Every track line is the same width, whatever is in it")
    func trackLinesAreOneWidth() {
        let text = Inspect.text(
            record: record([
                track(1, "Go Your Own Way", 223),
                track(2, "Songbird", 200),
                track(3, "The Chain", 270),
            ]),
            titleSource: .tags
        )
        let rows = text.components(separatedBy: "\n").filter { $0.hasPrefix("   ") }
        #expect(rows.count == 3)
        // 3 + 2 + 2 + 52 + 1 + 6.
        for row in rows { #expect(Columns.width(of: row) == 66) }
        #expect(rows[0].hasPrefix("    1. Go Your Own Way"))
        #expect(rows[0].hasSuffix("  3:43"))
        #expect(rows[1].hasSuffix("  3:20"))
        #expect(rows[2].hasSuffix("  4:30"))
    }

    /// **The number is the row, not the tag.** A record whose tracks are
    /// numbered from three counts from one here, because `i` starts at 1 and
    /// walks `$ORDER` (`player:3544`).
    @Test("The number down the left is the position, not the track number")
    func theNumberIsThePosition() {
        let text = Inspect.text(
            record: record([track(7, "Seventh", 60), track(8, "Eighth", 60)]),
            titleSource: .tags
        )
        let rows = text.components(separatedBy: "\n").filter { $0.hasPrefix("   ") }
        #expect(rows[0].hasPrefix("    1. Seventh"))
        #expect(rows[1].hasPrefix("    2. Eighth"))
    }

    /// **`%2d` is two places and does not grow.** From a hundred on, the line
    /// is a column wider and the whole listing steps right. Kept — a box set is
    /// rare and a silently different format is not.
    @Test("A hundredth track pushes its own line one column right")
    func theRowNumberOverflowsItsField() {
        let hundred = (1...100).map { track($0, "Track \($0)", 60) }
        let text = Inspect.text(record: record(hundred), titleSource: .tags)
        let rows = text.components(separatedBy: "\n").filter { $0.hasPrefix("   ") }
        #expect(Columns.width(of: rows[98]) == 66)
        #expect(rows[99].hasPrefix("   100. "))
        #expect(Columns.width(of: rows[99]) == 67)
    }

    /// A title over the measure is cut visibly, by the same arithmetic the panel
    /// cuts by (`fit`, `panel.sh:368`) — so the ellipsis is inside the 52, not beyond
    /// it.
    @Test("A long title is cut to the measure with the cut showing")
    func longTitlesAreCutVisibly() throws {
        let long = String(repeating: "long ", count: 30)
        let text = Inspect.text(record: record([track(1, long, 60)]), titleSource: .tags)
        let row = try #require(
            text.components(separatedBy: "\n").first { $0.hasPrefix("   ") })
        #expect(row.contains("…"))
        #expect(Columns.width(of: row) == 66)
    }

    /// The listing ends on a blank line of its own — `printf '\n'` after the
    /// loop — so the shell prompt does not land against the last track.
    @Test("It ends with a blank line, the way it began with one")
    func itIsFramedTopAndBottom() {
        let text = Inspect.text(record: record([track(1, "A", 60)]), titleSource: .tags)
        #expect(text.hasPrefix("\n  "))
        #expect(text.hasSuffix("\n\n"))
    }

    // MARK: - Choosing what to inspect

    /// `player:3518` — a path that is not there is the script's own refusal, and
    /// `-n` reaches it before it reaches anything else.
    @Test("A path that does not exist dies with the script's words")
    func aMissingPathDies() async {
        var options = LaunchOptions()
        options.dryRun = true
        options.sourcePath = "/nonexistent/path/to/nothing"
        let outcome = await Inspect.run(options, environment: [:])
        #expect(outcome == .died("no such file or directory: /nonexistent/path/to/nothing"))
    }

    /// `player:3524`, for something that exists and is neither.
    @Test("A file that is not a zip dies with the script's other words")
    func aFileThatIsNotAZipDies() async throws {
        let tmp = TempDirectory("inspect-not-a-source")
        let file = tmp.appending("sleeve-notes.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data("hi".utf8))
        var options = LaunchOptions()
        options.dryRun = true
        options.sourcePath = file.path
        let outcome = await Inspect.run(options, environment: [:])
        #expect(outcome == .died("not a zip or a folder: \(file.path)"))
    }

    /// `player:1114`'s message, including the half of its `:-` that is English
    /// and the half that is a path list. Both are kept; only one is a sentence.
    @Test("Nothing to play says where it looked, in whichever of two voices")
    func nothingToPlayNamesWhereItLooked() {
        #expect(
            Inspect.nothingToPlay(environment: [:])
                == "nothing to play. Put an album in ~/Music or ~/Downloads, or a CD in the drive"
        )
        #expect(
            Inspect.nothingToPlay(environment: ["MUTHUR_DIRS": "/a:/b"])
                == "nothing to play. Put an album in /a:/b, or a CD in the drive"
        )
        // The old name still means it, the way it does everywhere else (D13).
        #expect(
            Inspect.nothingToPlay(environment: ["PLAYER_DIRS": "/c"])
                == "nothing to play. Put an album in /c, or a CD in the drive"
        )
    }

    /// **`-n` with no argument takes the first source it finds.** The picker is
    /// a window and cannot answer a pipe, and `player:1118` already says what a
    /// run with no screen does: `PICKED=${SRC[0]}`.
    @Test("With no argument it inspects the first source rather than asking")
    func noArgumentTakesTheFirstSource() async throws {
        let tmp = TempDirectory("inspect-scan")
        let library = tmp.directory("Music")
        let album = library.appending(path: "Zebra")
        try FileManager.default.createDirectory(at: album, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: album.appending(path: "01 - one.flac").path, contents: Data("x".utf8))

        var options = LaunchOptions()
        options.dryRun = true
        let outcome = await Inspect.run(options, environment: ["MUTHUR_DIRS": library.path])
        // The file is not audio anything can read, so the *read* is what fails —
        // which is itself the proof that the scan chose it without being asked.
        #expect(outcome != .died(Inspect.nothingToPlay(environment: [:])))
        if case .died(let message) = outcome {
            #expect(!message.contains("nothing to play"))
        }
    }

    /// End to end against something somebody really tagged: `-n` on a folder
    /// prints as many track lines as the record has tracks, and the durations on
    /// them are the durations the record was read with. Nothing here asserts a
    /// title or a length — the fixture is whichever album is to hand.
    @Test(
        "a real album inspects to one line a track",
        .enabled(if: Fixtures.exists(Fixtures.musicLibrary))
    )
    func aRealAlbumInspects() async throws {
        let albums = Fixtures.anyTaggedAlbums(limit: 1)
        try #require(!albums.isEmpty)
        var options = LaunchOptions()
        options.dryRun = true
        options.sourcePath = albums[0].path

        let outcome = await Inspect.run(options, environment: [:])
        guard case .printed(let listing) = outcome else {
            Issue.record("`-n` on \(albums[0].path) did not print: \(outcome)")
            return
        }
        let opened = try await SourceOpener.open(url: albums[0], kind: .folder, progress: nil)
        let rows = listing.components(separatedBy: "\n").filter { $0.hasPrefix("   ") }
        #expect(rows.count == opened.record.order.count)
        #expect(listing.contains("  \(opened.record.order.count) tracks, "))
        for (row, track) in zip(rows, opened.record.running) {
            #expect(row.hasSuffix(Readout.mmss(track.duration)))
        }
    }
}
