import Foundation
import Testing

@testable import MUTHURKit

/// §4.3 — the table of contents as macOS writes it on the mount. D44.
@Suite("Disc — the volume's own table of contents")
struct VolumeTOCTests {

    /// A `.TOC.plist` in the shape cddafs writes, built rather than captured so
    /// the fields under test are visible in the test.
    static func plist(
        first: Int,
        last: Int,
        leadOut: Int,
        blocks: [(point: Int, start: Int)],
        extraSessions: [[String: Any]] = []
    ) -> Data {
        let session: [String: Any] = [
            "First Track": first,
            "Last Track": last,
            "Leadout Block": leadOut,
            "Session Number": 1,
            "Track Array": blocks.map {
                ["Point": $0.point, "Start Block": $0.start, "Session Number": 1, "Data": 0]
            },
        ]
        let root: [String: Any] = ["Sessions": [session] + extraSessions]
        return try! PropertyListSerialization.data(
            fromPropertyList: root, format: .xml, options: 0
        )
    }

    // MARK: - The shape

    @Test("A three-track disc reads as a table")
    func plainDisc() throws {
        let table = try #require(
            VolumeTOC.parse(
                Self.plist(
                    first: 1, last: 3, leadOut: 60000,
                    blocks: [(1, 150), (2, 20000), (3, 40000)]
                )
            )
        )
        #expect(table.firstTrack == 1)
        #expect(table.lastTrack == 3)
        #expect(table.leadOut == 60000)
        // **Already in TOC form.** Track one is 150 as it lies in the file; if
        // this ever reads 300 somebody has put `fromLBA` in the way.
        #expect(table.offsets == [150, 20000, 40000])
    }

    @Test("The lead-in descriptors are not tracks")
    func leadInPoints() throws {
        // 0xA0, 0xA1, 0xA2 — first track, last track, lead-out — carry the same
        // numbers the session already gave and no start block worth having.
        let table = try #require(
            VolumeTOC.parse(
                Self.plist(
                    first: 1, last: 2, leadOut: 50000,
                    blocks: [(160, 0), (161, 0), (162, 50000), (1, 150), (2, 25000)]
                )
            )
        )
        #expect(table.offsets == [150, 25000])
    }

    @Test("Tracks are ordered by their number, not by their place in the array")
    func outOfOrder() throws {
        let table = try #require(
            VolumeTOC.parse(
                Self.plist(
                    first: 1, last: 3, leadOut: 60000,
                    blocks: [(3, 40000), (1, 150), (2, 20000)]
                )
            )
        )
        #expect(table.offsets == [150, 20000, 40000])
    }

    @Test("A disc that does not start at track one")
    func firstTrackNotOne() throws {
        let table = try #require(
            VolumeTOC.parse(
                Self.plist(first: 2, last: 3, leadOut: 60000, blocks: [(2, 150), (3, 40000)])
            )
        )
        #expect(table.firstTrack == 2)
        #expect(table.offsets == [150, 40000])
    }

    @Test("An enhanced CD is fingerprinted on its audio session alone")
    func enhancedCD() throws {
        // The data session comes second and has a lead-out of its own, much
        // further out. Taking it would fingerprint a disc that does not exist.
        let dataSession: [String: Any] = [
            "First Track": 4,
            "Last Track": 4,
            "Leadout Block": 300_000,
            "Session Number": 2,
            "Track Array": [["Point": 4, "Start Block": 250_000, "Session Number": 2, "Data": 1]],
        ]
        let table = try #require(
            VolumeTOC.parse(
                Self.plist(
                    first: 1, last: 3, leadOut: 60000,
                    blocks: [(1, 150), (2, 20000), (3, 40000)],
                    extraSessions: [dataSession]
                )
            )
        )
        #expect(table.lastTrack == 3)
        #expect(table.leadOut == 60000)
        #expect(table.offsets == [150, 20000, 40000])
    }

    // MARK: - What is not a table

    @Test("A hole in the table is not a table")
    func missingTrack() {
        // Silently dropping track two shifts every offset after it onto the
        // wrong slot, and the disc then fingerprints as some other disc rather
        // than failing to fingerprint. It has to be fatal.
        #expect(
            VolumeTOC.parse(
                Self.plist(first: 1, last: 3, leadOut: 60000, blocks: [(1, 150), (3, 40000)])
            ) == nil
        )
    }

    @Test("Nothing that is a table of contents is nothing")
    func notATable() {
        #expect(VolumeTOC.parse(Data()) == nil)
        #expect(VolumeTOC.parse(Data("not a plist at all".utf8)) == nil)
        // A plist, but not this one — a data DVD's volume has no sessions.
        let empty = try! PropertyListSerialization.data(
            fromPropertyList: ["Sessions": []], format: .xml, options: 0
        )
        #expect(VolumeTOC.parse(empty) == nil)
    }

    @Test("A last track before the first is not a table")
    func backwards() {
        #expect(
            VolumeTOC.parse(Self.plist(first: 5, last: 2, leadOut: 60000, blocks: [(5, 150)]))
                == nil
        )
    }

    // MARK: - Where the file is

    @Test("The file is at the root of the volume")
    func location() {
        let url = VolumeTOC.url(inVolume: URL(fileURLWithPath: "/Volumes/Deluxe"))
        #expect(url.path == "/Volumes/Deluxe/.TOC.plist")
    }

    @Test("A volume with no such file is no table, not a crash")
    func absentFile() async {
        let source = VolumeTableOfContents(
            volume: URL(fileURLWithPath: "/Volumes/nothing-is-mounted-here")
        )
        #expect(await source.tableOfContents() == nil)
    }
}
