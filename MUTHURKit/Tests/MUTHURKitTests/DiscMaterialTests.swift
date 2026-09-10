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
/// green rather than red. `docs/hardware.md` — which is §19, moved whole out of
/// `docs/parity.md` and still numbered §19 — is the checklist that produces the
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

    /// libdiscid's own `toc` line, which is `tocString`'s format exactly:
    /// first track, last track, lead-out, then this disc's offsets. Already in
    /// TOC form — track one is 150, not 0 — so no pre-gap goes on here.
    static func libdiscidTable() -> TableOfContents? {
        guard let line = setting("MUTHUR_TEST_DISCID_TOC") else { return nil }
        let n = line.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
        guard n.count >= 4 else { return nil }
        return TableOfContents(
            firstTrack: n[0], lastTrack: n[1], leadOut: n[2], offsets: Array(n[3...])
        )
    }

    /// **D15 against the reference implementation, by the route that works.**
    ///
    /// The `cdrecord` half of this comparison cannot run on this machine at all
    /// — `diskarbitrationd` holds the mounted disc and cdrtools cannot get the
    /// exclusive open it insists on (D44). libdiscid can, so the oracle supplies
    /// both halves: it reads the table off the drive, and it says what ID that
    /// table has. What is being checked is our arithmetic over the same numbers.
    @Test(
        "The fingerprint off a real disc is the one libdiscid gets — via libdiscid",
        .enabled(if: DiscMaterialTests.libdiscidTable() != nil
            && DiscMaterialTests.setting("MUTHUR_TEST_DISCID") != nil)
    )
    func realDiscIDViaLibdiscid() throws {
        let table = try #require(DiscMaterialTests.libdiscidTable())
        #expect(table.discID == DiscMaterialTests.setting("MUTHUR_TEST_DISCID"))
        // The table round-trips into the form the submission URL wants, which is
        // the form it arrived in.
        #expect(table.tocString == DiscMaterialTests.setting("MUTHUR_TEST_DISCID_TOC"))
    }

    /// **D44's condition, and the comparison D42 was held open on.**
    ///
    /// §18.18 asked which reader survives into the app, and this is the one that
    /// does: macOS's own `.TOC.plist`, off the mount. What has to be true for
    /// that to be safe is that it agrees with the reference implementation field
    /// for field on a real disc — the same table, and therefore the same
    /// fingerprint. A disagreement here is not a failing test; it is D44 taken
    /// on an assumption that turned out to be false, and §18.18 comes back open.
    @Test(
        "The volume's own table is the table libdiscid reads off the device",
        .enabled(if: DiscMaterialTests.volume != nil
            && DiscMaterialTests.libdiscidTable() != nil)
    )
    func volumeTableMatchesLibdiscid() async throws {
        let volume = DiscMaterialTests.volume!
        let table = try #require(
            await VolumeTableOfContents(volume: volume).tableOfContents(),
            "no readable .TOC.plist on \(volume.path) — is this a mounted audio CD?"
        )
        let oracle = try #require(DiscMaterialTests.libdiscidTable())
        #expect(table.firstTrack == oracle.firstTrack)
        #expect(table.lastTrack == oracle.lastTrack)
        #expect(table.leadOut == oracle.leadOut)
        #expect(table.offsets == oracle.offsets)
        // The one that matters, stated separately so a failure says so outright.
        #expect(table.discID == DiscMaterialTests.setting("MUTHUR_TEST_DISCID"))
    }

    /// The mount and the drive have to be talking about the same disc: the
    /// volume §3 scanned should have as many rows as the table has tracks.
    @Test(
        "The volume's table agrees with the volume's own track list",
        .enabled(if: DiscMaterialTests.volume != nil)
    )
    func volumeTableMatchesScan() async throws {
        let volume = DiscMaterialTests.volume!
        let table = try #require(await VolumeTableOfContents(volume: volume).tableOfContents())
        let record = try await Record.read(
            directory: volume,
            sourceLabel: volume.lastPathComponent,
            numbersFromFilenames: true
        )
        #expect(table.trackCount == record.tracks.count)
        #expect(record.running.map(\.number) == Array(table.firstTrack...table.lastTrack))
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
        // `title:` is a version and not a guarantee — cdda2wav 3.02a09 prints
        // `Track  1: 'x'` — so the line is selected on what every shape has:
        // `Track`, a number, a colon, and a quoted value after it. Requiring
        // `title:` here meant this test could only ever have run against output
        // the parser was already known to read.
        let printed = output.split(separator: "\n").filter {
            guard $0.hasPrefix("Track") else { return false }
            let after = $0.dropFirst("Track".count).drop { $0 == " " }
            let digits = after.prefix { $0.isASCII && $0.isNumber }
            guard !digits.isEmpty else { return false }
            let rest = after.dropFirst(digits.count).drop { $0 == " " }
            return (rest.hasPrefix("title:") || rest.hasPrefix(":")) && rest.contains("'")
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

        // **Scan order is not track order, and this is the disc that proves it.**
        // `tracks` is the byte-order scan (§3), and macOS numbers a CDDA mount
        // without padding — so a disc with ten or more tracks lists
        // `1, 10, 11, 12, 13, 2, …` and always has. This assertion used to read
        // `record.tracks.map(\.number) == Array(1...count)`, which is only true
        // of a disc with nine tracks or fewer; it had never run, because it
        // needed a disc. What the rescue actually promises is that every row
        // got its own number, and §3.1 is what puts them in order.
        #expect(record.tracks.map(\.number).sorted() == Array(1...record.tracks.count))
        #expect(record.running.map(\.number) == Array(1...record.tracks.count))
        #expect(record.tracks.allSatisfy { $0.duration > 0 })
    }

    @Test(
        "§4.1 leaves a tidy list wherever nothing could name the track",
        .enabled(if: DiscMaterialTests.volume != nil)
    )
    func tidyDefaults() async throws {
        let volume = DiscMaterialTests.volume!
        var record = try await Record.read(
            directory: volume,
            sourceLabel: volume.lastPathComponent,
            numbersFromFilenames: true
        )
        // Which rows the rule is even about has to be read off the disc before
        // the rule runs, because afterwards they are indistinguishable from rows
        // that were always named.
        let nameless = Set(
            record.tracks.filter { $0.title.contains("Audio Track") }.map(\.number)
        )
        DiscTitles.applyDefaults(to: &record, volumeName: volume.lastPathComponent)

        // **Which disc this is, is not something §19 gets to choose.** macOS
        // resolves the track names on plenty of discs — CD-Text in the lead-in,
        // or its own lookup — and hands them over as `1 In The Blood.aiff`
        // rather than `1 Audio Track.aiff`. On such a disc §4.1 is *supposed* to
        // do nothing, so asserting `Track 01` outright tested the material and
        // not the rule. This asserts the rule on exactly the rows it governs,
        // and holds on either kind of disc.
        for track in record.running where nameless.contains(track.number) {
            #expect(track.title == String(format: "Track %02d", track.number))
        }
        #expect(record.running.allSatisfy { !$0.title.contains("Audio Track") })
        #expect(record.running.allSatisfy { !$0.title.isEmpty })
        #expect(!record.album.isEmpty)
    }

    // MARK: - §1.3 against the drive itself

    /// **The one test in the suite that uses the real probes.** Everything else
    /// in `DiscFinderTests` hands `find_cd` a string; this hands it the machine.
    /// What it proves is the thing no stub can: that `mount` and `drutil` on
    /// *this* macOS print the shapes those parsers were written against, and
    /// that the disc the operator named in `MUTHUR_TEST_CDDA` is the one the
    /// finder lands on.
    ///
    /// Still opens nothing. `find_cd` reads the mount table and asks the drive
    /// for its status; neither is a conversation with the device, which is why
    /// this can sit in a suite that otherwise refuses to touch it.
    @Test(
        "find_cd finds the disc that is actually mounted",
        .enabled(if: DiscMaterialTests.volume != nil)
    )
    func realFind() throws {
        let expected = DiscMaterialTests.volume!
        let found = try #require(
            DiscFinder.find(),
            "there is a disc at \(expected.path) and find_cd did not see it"
        )
        #expect(found.volume.path == expected.path)
        // macOS mounts an audio CD `cddafs`, so the kernel route is the one a
        // real disc takes and the `/Volumes` fallback is never reached. If this
        // ever comes back `.shape`, the fallback is load-bearing after all and
        // §17 wants to know.
        #expect(found.route == .cddafs)
        #expect(found.device != nil)
    }

    /// The device gate's premise, checked against hardware rather than assumed:
    /// the node `drutil` names really does back the volume the CD is mounted on.
    /// D17 is worthless if these two disagree.
    @Test(
        "drutil's node is the node the disc is mounted from",
        .enabled(if: DiscMaterialTests.volume != nil)
    )
    func realDeviceGate() throws {
        let node = try #require(
            Diagnostics.mediaDevice(Diagnostics.drutilStatus()),
            "drutil named no device with a disc in the drive"
        )
        let table = DiscFinder.MountTable.parse(DiscFinder.mountOutput() ?? "")
        let device = try #require(table.device(for: DiscMaterialTests.volume!))
        #expect(DiscFinder.device(device, belongsTo: node))
    }

    /// The picker row, off the real mount. The count is D18's — `AudioFiles`
    /// over the volume — and on a CDDA mount it should be the track count the
    /// drive reports, which is the only place those two numbers are ever
    /// checked against each other.
    @Test(
        "the disc's picker row is built off the real mount",
        .enabled(if: DiscMaterialTests.volume != nil)
    )
    func realPickerRow() throws {
        let found = try #require(DiscFinder.find())
        let row = PickerEntry.disc(found)
        #expect(row.kind == .disc)
        #expect(row.mark == "⊙")
        #expect(row.label == found.volume.lastPathComponent)
        #expect(row.detail.hasSuffix(" · in the drive"))

        let counted = AudioFiles.scan(found.volume, maxDepth: 1).count
        #expect(row.detail == PickerEntry.discDetail(trackCount: counted))
        // The drive's own count, for the one comparison that needs a disc.
        if let table = VolumeTOC.parse(
            (try? Data(contentsOf: VolumeTOC.url(inVolume: found.volume))) ?? Data()
        ) {
            #expect(counted == table.trackCount)
        }
    }
}
