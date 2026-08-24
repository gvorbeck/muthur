import Foundation
import Testing

@testable import MUTHURKit

/// §4.3 — the fingerprint, and reading a table of contents to compute it from.
///
/// **The expected IDs are not computed here.** Every one of them came out of
/// `libdiscid`, the reference implementation, through `Scripts/discid-oracle.c`
/// — `discid_put()` takes a table of contents and needs no drive, which makes it
/// usable as an oracle on a machine with nothing in the tray. Checking this
/// arithmetic against the same arithmetic written twice would prove nothing, and
/// the one thing worth proving is that a disc this program identifies is the
/// disc MusicBrainz thinks it is.
///
/// The first TOC is the example in `discid.h`'s own documentation, so the
/// primary vector is a published one rather than a shape invented to suit the
/// code.
@Suite("Disc — the MusicBrainz disc ID")
struct DiscIDTests {

    /// `1 7 164900 150 22460 50197 80614 100828 133318 144712`
    static let sevenTrack = TableOfContents(
        firstTrack: 1, lastTrack: 7, leadOut: 164900,
        offsets: [150, 22460, 50197, 80614, 100828, 133318, 144712]
    )!

    static let fifteenTrack = TableOfContents(
        firstTrack: 1, lastTrack: 15, leadOut: 258725,
        offsets: [
            150, 16157, 35932, 54282, 66780, 78952, 97355, 109043,
            122055, 140748, 157068, 175871, 194997, 213504, 244090,
        ]
    )!

    static let singleTrack = TableOfContents(
        firstTrack: 1, lastTrack: 1, leadOut: 180150, offsets: [150]
    )!

    // MARK: - Against libdiscid

    @Test("The documented seven-track table, and the ID libdiscid gives it")
    func published() {
        #expect(DiscIDTests.sevenTrack.discID == "ybYRHGr1rfATUisnRFX8rjrtKec-")
    }

    @Test("Fifteen tracks — long enough that the padding is doing visible work")
    func fifteen() {
        #expect(DiscIDTests.fifteenTrack.discID == "J5VseIjrnogYWZ4AcpTUXMOI.XY-")
    }

    @Test("One track, the shortest table there is")
    func single() {
        #expect(DiscIDTests.singleTrack.discID == "NyB4TAo0fl6yU3tBAcL.jKphZs0-")
    }

    // MARK: - The string it hashes

    @Test("804 characters: two bytes, a lead-out, and 99 slots")
    func hexShape() {
        let hex = DiscIDTests.sevenTrack.hexString
        #expect(hex.count == 2 + 2 + 8 + 99 * 8)
        // Track 1, track 7, lead-out 164900 = 0x28424, then track one at 150.
        #expect(hex.hasPrefix("01070002842400000096"))
        // Slot 8 onwards is a disc with no track there, which is a run of zeroes
        // to the end. Seven tracks means 92 empty slots.
        #expect(hex.hasSuffix(String(repeating: "0", count: 92 * 8)))
        #expect(hex.allSatisfy { $0.isHexDigit && !$0.isLowercase })
    }

    @Test("The digest is over those characters, not over the bytes they spell")
    func hashesTheText() {
        // The whole of D15. `xxd -r -p` between the printf and the shasum
        // (`player:2166`) hashes 402 raw bytes instead of 804 ASCII ones, and
        // produces an ID no catalogue has ever heard of. Pinning the length of
        // what goes in is the cheapest way to keep that from creeping back.
        #expect(Data(DiscIDTests.sevenTrack.hexString.utf8).count == 804)
    }

    @Test("The URL-safe alphabet, and no plain base64 left in it")
    func alphabet() {
        for toc in [DiscIDTests.sevenTrack, DiscIDTests.fifteenTrack, DiscIDTests.singleTrack] {
            let id = toc.discID
            #expect(!id.contains("+"))
            #expect(!id.contains("/"))
            #expect(!id.contains("="))
            // SHA-1 is 20 bytes, which is 28 base64 characters with one pad.
            #expect(id.count == 28)
            #expect(id.hasSuffix("-"))
        }
    }

    @Test("The submission form of the table")
    func tocString() {
        #expect(
            DiscIDTests.sevenTrack.tocString
                == "1 7 164900 150 22460 50197 80614 100828 133318 144712"
        )
    }

    // MARK: - The pre-gap

    @Test("LBAs get the 150-frame pre-gap, in one place")
    func preGap() {
        let fromLBA = TableOfContents.fromLBA(
            firstTrack: 1, lastTrack: 7, leadOutLBA: 164750,
            trackLBAs: [0, 22310, 50047, 80464, 100678, 133168, 144562]
        )
        #expect(fromLBA == DiscIDTests.sevenTrack)
        #expect(fromLBA?.discID == "ybYRHGr1rfATUisnRFX8rjrtKec-")
    }

    @Test("A track beginning before track one still lands in range")
    func negativeLBA() {
        // A hidden track in the pre-gap is addressed backwards from track one.
        // +150 is what puts it back above zero, which is why the guard against
        // negatives runs after the addition and not before it.
        let toc = TableOfContents.fromLBA(
            firstTrack: 1, lastTrack: 2, leadOutLBA: 1000, trackLBAs: [-150, 500]
        )
        #expect(toc?.offsets == [0, 650])
    }

    // MARK: - Tables that are not tables

    @Test("Refused: no first track, a last before the first, a hundredth track")
    func rejected() {
        #expect(TableOfContents(firstTrack: 0, lastTrack: 3, leadOut: 100, offsets: []) == nil)
        #expect(
            TableOfContents(firstTrack: 4, lastTrack: 2, leadOut: 100, offsets: []) == nil
        )
        #expect(
            TableOfContents(
                firstTrack: 1, lastTrack: 100, leadOut: 100,
                offsets: Array(repeating: 0, count: 100)
            ) == nil
        )
    }

    @Test("Refused: an offset for every slot but one")
    func wrongCount() {
        #expect(
            TableOfContents(firstTrack: 1, lastTrack: 3, leadOut: 100, offsets: [150, 200])
                == nil
        )
    }

    @Test("A disc whose first track is not track one")
    func offsetLookup() {
        let toc = TableOfContents(
            firstTrack: 3, lastTrack: 5, leadOut: 9000, offsets: [150, 3000, 6000]
        )!
        #expect(toc.offset(ofTrack: 2) == nil)
        #expect(toc.offset(ofTrack: 3) == 150)
        #expect(toc.offset(ofTrack: 5) == 6000)
        #expect(toc.offset(ofTrack: 6) == nil)
        #expect(toc.trackCount == 3)
        // Slots 1 and 2 are zeroes; slot 3 is where this disc starts.
        #expect(toc.hexString.hasPrefix("030500002328" + "00000000" + "00000000" + "00000096"))
    }

    // MARK: - Reading what cdrecord printed

    static let cdrecordTOC = """
        Cdrecord-ProDVD-ProBD-Clone 3.02a09 (arm64-apple-darwin) Copyright (C) 1995-2016
        scsidev: 'IODVDServices/0'
        TOC Type: 1 = CD-DA
        track:   1 lba:         0 (       0) 00:02:00 adr: 1 control: 0 mode: -1
        track:   2 lba:     22310 (   89240) 04:59:35 adr: 1 control: 0 mode: -1
        track:   3 lba:     50047 (  200188) 11:09:22 adr: 1 control: 0 mode: -1
        track:   4 lba:     80464 (  321856) 17:54:64 adr: 1 control: 0 mode: -1
        track:   5 lba:    100678 (  402712) 22:24:28 adr: 1 control: 0 mode: -1
        track:   6 lba:    133168 (  532672) 29:37:43 adr: 1 control: 0 mode: -1
        track:   7 lba:    144562 (  578248) 32:09:37 adr: 1 control: 0 mode: -1
        track:lout lba:    164750 (  659000) 36:38:50 adr: 1 control: 0 mode: -1
        """

    @Test("The listing produces the table, and the table produces the published ID")
    func parseTOC() {
        let toc = CDRecordTOC.parse(DiscIDTests.cdrecordTOC)
        #expect(toc == DiscIDTests.sevenTrack)
        #expect(toc?.discID == "ybYRHGr1rfATUisnRFX8rjrtKec-")
    }

    @Test("No lead-out line, no table")
    func noLeadOut() {
        let lines = DiscIDTests.cdrecordTOC.split(separator: "\n").filter {
            !$0.contains("lout")
        }
        #expect(CDRecordTOC.parse(lines.joined(separator: "\n")) == nil)
    }

    @Test("No track lines, no table")
    func noTracks() {
        #expect(CDRecordTOC.parse("cdrecord: No disk / Wrong disk!") == nil)
        #expect(CDRecordTOC.parse("") == nil)
    }

    @Test("A gap in the listing is refused rather than filled with a zero")
    func gap() {
        // The script writes a zero into the missing slot, and a zero is a real
        // offset — it would produce a plausible disc ID for a disc that does not
        // exist, and the lookup would quietly miss. A Red Book disc numbers its
        // tracks consecutively, so this cannot happen; refusing it is the
        // cheaper of the two ways to be wrong. D20, `docs/parity.md` §4.3.
        let lines = DiscIDTests.cdrecordTOC.split(separator: "\n").filter {
            !$0.hasPrefix("track:   4")
        }
        #expect(CDRecordTOC.parse(lines.joined(separator: "\n")) == nil)
    }

    @Test("A disc that starts at track two keeps its numbering")
    func firstTrackNotOne() {
        let listing = """
            track:   2 lba:         0 (       0) 00:02:00 adr: 1 control: 0 mode: -1
            track:   3 lba:      1000 (    4000) 00:15:25 adr: 1 control: 0 mode: -1
            track:lout lba:      2000 (    8000) 00:28:50 adr: 1 control: 0 mode: -1
            """
        let toc = CDRecordTOC.parse(listing)
        #expect(toc?.firstTrack == 2)
        #expect(toc?.lastTrack == 3)
        #expect(toc?.offsets == [150, 1150])
        #expect(toc?.leadOut == 2150)
    }
}
