import Foundation
import Testing

@testable import MUTHURKit

/// §19 — the checks that need a disc, run against one.
///
/// Everything §4 does is proved elsewhere against tables and listings typed out
/// by hand. What no stub can tell you is whether *this machine's* cdrtools
/// prints the shape the parsers expect, and whether the fingerprint computed off
/// a real disc is the fingerprint that disc actually has. Those are the two
/// questions here, and both need material this suite cannot invent.
///
/// Nothing is committed and nothing is assumed present: every test is
/// `.enabled(if:)` on an environment variable, so a clone with an empty drive is
/// green rather than red. `docs/parity.md` §19 is the checklist that produces the
/// material, one command per variable.
///
/// - `MUTHUR_TEST_TOC` — a file holding `cdrecord dev=… -toc` output.
/// - `MUTHUR_TEST_DISCID` — the ID `libdiscid` read off that same disc.
/// - `MUTHUR_TEST_CDTEXT` — a file holding `cdda2wav -J -v titles` output.
/// - `MUTHUR_TEST_CDDA` — the mount point of the audio CD, `/Volumes/Audio CD`.
@Suite("§19 — with a disc in the drive")
struct DiscMaterialTests {

    static func setting(_ name: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
            return nil
        }
        return value
    }

    static func file(_ name: String) -> String? {
        guard let path = setting(name),
            let contents = try? String(contentsOfFile: path, encoding: .utf8)
        else { return nil }
        return contents
    }

    static var toc: String? { file("MUTHUR_TEST_TOC") }
    static var cdText: String? { file("MUTHUR_TEST_CDTEXT") }
    static var volume: URL? { setting("MUTHUR_TEST_CDDA").map { URL(fileURLWithPath: $0) } }

    // MARK: - The table of contents this drive prints

    @Test(
        "A real cdrecord listing reads as a table",
        .enabled(if: DiscMaterialTests.toc != nil)
    )
    func realListing() throws {
        let table = try #require(
            CDRecordTOC.parse(DiscMaterialTests.toc!),
            "cdrecord printed a shape this parser does not know — keep the file"
        )
        // A disc with one track is legal and a disc with none is not.
        #expect(table.trackCount >= 1)
        #expect(table.firstTrack >= 1)
        // Every offset inside the disc, in order. A listing that parses but is
        // not monotonic has been misread rather than being a strange disc.
        #expect(table.offsets == table.offsets.sorted())
        #expect(table.leadOut > table.offsets.last!)
    }

    @Test(
        "The fingerprint off a real disc is the one libdiscid gets",
        .enabled(if: DiscMaterialTests.toc != nil
            && DiscMaterialTests.setting("MUTHUR_TEST_DISCID") != nil)
    )
    func realDiscID() throws {
        // The whole of §4.3 in one line: our arithmetic, over a table read off a
        // drive by one tool, against the reference implementation reading the
        // same disc for itself. D15 is what this is guarding.
        let table = try #require(CDRecordTOC.parse(DiscMaterialTests.toc!))
        #expect(table.discID == DiscMaterialTests.setting("MUTHUR_TEST_DISCID"))
    }

    // MARK: - The CD-Text this machine's tools print

    @Test(
        "Every title line this disc printed produced a title",
        .enabled(if: DiscMaterialTests.cdText != nil)
    )
    func realCDText() throws {
        let output = DiscMaterialTests.cdText!
        let text = CDTextParser.parse(output)

        // The failure this is looking for is silent by design: a shape the
        // parser does not know leaves the tidy `Track 07` in place (§4.2), so a
        // disc whose CD-Text is printed some other way looks exactly like a disc
        // with no CD-Text on it. Counting the lines the tool printed against the
        // titles that came out is the only way to tell those apart.
        let printed = output.split(separator: "\n").filter {
            $0.hasPrefix("Track") && $0.contains("title:")
        }
        try #require(!printed.isEmpty, "no track title lines in this file at all")
        #expect(text.titles.count == printed.count)
        #expect(text.titles.values.allSatisfy { !$0.isEmpty })

        // An apostrophe in a title is the case the quote rule exists for, and it
        // is worth knowing when the disc in the drive happens to carry one.
        for title in text.titles.values where title.contains("'") {
            #expect(!title.hasSuffix("'"))
        }
    }

    // MARK: - The volume macOS mounted

    @Test(
        "A mounted CDDA volume numbers its own tracks",
        .enabled(if: DiscMaterialTests.volume != nil)
    )
    func mountedVolume() async throws {
        let volume = DiscMaterialTests.volume!
        let record = try await Record.read(
            directory: volume,
            sourceLabel: volume.lastPathComponent,
            numbersFromFilenames: true
        )
        // Without the filename rescue every row is 9999, and every title §4
        // learns lands on the wrong one — which is the whole reason that rescue
        // is CD-only rather than general (§3, `player:1454`).
        #expect(record.unnumberedCount == 0)
        #expect(record.tracks.map(\.number) == Array(1...record.tracks.count))
        #expect(record.tracks.allSatisfy { $0.duration > 0 })
    }

    @Test(
        "§4.1 leaves a tidy list on a disc nothing can name",
        .enabled(if: DiscMaterialTests.volume != nil)
    )
    func tidyDefaults() async throws {
        let volume = DiscMaterialTests.volume!
        var record = try await Record.read(
            directory: volume,
            sourceLabel: volume.lastPathComponent,
            numbersFromFilenames: true
        )
        DiscTitles.applyDefaults(to: &record, volumeName: volume.lastPathComponent)
        // macOS writes `1 Audio Track.aiff`, so this is the real input to the
        // rule rather than a filename invented to match it.
        #expect(record.running.first?.title == "Track 01")
        #expect(record.running.allSatisfy { !$0.title.contains("Audio Track") })
        #expect(!record.album.isEmpty)
    }
}
