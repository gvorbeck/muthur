import Foundation
import Testing

@testable import MUTHURKit

/// The readers, against files that were tagged by somebody else.
///
/// The rules tier proves §3's arithmetic; this proves that the arithmetic is
/// being fed the right numbers, which is the half no stub can tell you. It is
/// what turned up that an MP4 writes its track number as a binary atom and not
/// a string, and that AVFoundation reports an MP4's *trimmed* duration where
/// ffprobe reports the container's.
///
/// Nothing here is copied into the repository. See `Fixtures` for where it
/// comes from and how to point it somewhere else.
@Suite("§3 — against real material")
struct RealMaterialTests {

    // MARK: - Tagged MP4s, from the library

    @Test(
        "an MP4's binary trkn and disk atoms are read as numbers",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func readsTaggedMP4() async throws {
        let files = AudioFiles.scan(Fixtures.rumours)
        let track = try #require(files.first { $0.lastPathComponent.hasPrefix("03 ") })

        let raw = await AVFoundationMetadataReader().read(track)
        // `trkn` comes back as eight bytes, not a string: 3 of 11.
        #expect(raw.track == "3/11")
        #expect(raw.disc == "1/1")
        #expect(raw.title == "Never Going Back Again")
        #expect(raw.album == "Rumours")
        #expect(raw.artist == "Fleetwood Mac")
        #expect(raw.albumArtist == "Fleetwood Mac")
        #expect(raw.date == "1977-02-04T08:00:00Z")

        // And §3 turns all of that into one row.
        let parsed = Track(url: track, raw: raw)
        #expect(parsed.number == 3)
        #expect(parsed.disc == 1)
        #expect(Track.year(from: raw.date) == "1977")
        // Rounded up from something with a fraction on it.
        #expect(parsed.duration == 135)
    }

    @Test(
        "a real album reads and orders end to end",
        .enabled(if: Fixtures.exists(Fixtures.rumours))
    )
    func readsARealAlbum() async throws {
        let record = try await Record.read(
            directory: Fixtures.rumours, sourceLabel: "Rumours"
        )
        #expect(record.album == "Rumours")
        #expect(record.albumArtist == "Fleetwood Mac")
        #expect(record.year == "1977")
        #expect(record.running.map(\.number) == Array(1...record.tracks.count))
        #expect(record.running.first?.title == "Second Hand News")
        #expect(record.unnumberedCount == 0)
        #expect(record.unreadableCount == 0)
        #expect(record.total == record.tracks.reduce(0) { $0 + $1.duration })
    }

    @Test(
        "the invariants hold of any album on this machine",
        .enabled(if: !Fixtures.anyTaggedAlbums().isEmpty)
    )
    func invariantsHoldEverywhere() async throws {
        for album in Fixtures.anyTaggedAlbums() {
            let label = album.lastPathComponent
            let record = try await Record.read(directory: album, sourceLabel: label)

            // The running order is non-decreasing in (disc, track). This is the
            // one property the whole section exists to produce.
            var previous = (disc: Int.min, number: Int.min)
            for track in record.running {
                #expect(
                    (track.disc, track.number) >= (previous.disc, previous.number),
                    "\(label): \(track.url.lastPathComponent) is out of order"
                )
                previous = (track.disc, track.number)
            }

            // Every row is a whole number of seconds, rounded up, so nothing
            // ends before the meter says it does.
            #expect(record.running.allSatisfy { $0.duration >= 1 })
            #expect(record.total == record.running.reduce(0) { $0 + $1.duration })

            // Nothing that reaches the panel carries a character that would
            // bend the frame or split a resume record.
            for text in record.running.flatMap({ [$0.title, $0.artist] })
                + [record.album, record.albumArtist, record.year]
            {
                let bent = text.contains("\t") || text.contains("\n") || text.contains("\r")
                #expect(!bent)
            }

            // An album never comes back nameless: the tags, or the folder.
            #expect(!record.album.isEmpty)
            // Every row keeps its file, and the order is a permutation of them.
            #expect(record.order.sorted() == Array(record.tracks.indices))
        }
    }

    // MARK: - Untagged AIFFs, out of a zip

    @Test(
        "a zip's own name is the album, because an untagged rip has no other",
        .enabled(if: !Fixtures.audioZips().isEmpty)
    )
    func zipNameIsTheAlbum() throws {
        for zip in Fixtures.audioZips() {
            let label = zip.lastPathComponent
            let album = Record.albumFromSourceLabel(label)
            #expect(!album.hasSuffix(".zip"))
            #expect(album == zip.deletingPathExtension().lastPathComponent)
        }
    }

    @Test(
        "an untagged AIFF rip lands on 9999 and orders by its filenames",
        .enabled(if: !Fixtures.audioZips().isEmpty)
    )
    func untaggedZippedAlbumOrdersByName() async throws {
        let zip = try #require(Fixtures.audioZips().first)
        let unpacked = try #require(Fixtures.headsOfZippedAlbum(zip))

        let record = try await Record.read(
            directory: unpacked, sourceLabel: zip.lastPathComponent
        )

        // These rips carry a duration and nothing else — no track, no album,
        // no artist. Exactly the case 9999 and the natural sort are for.
        #expect(record.unnumberedCount == record.tracks.count)
        #expect(record.running.allSatisfy { $0.number == 9999 })

        // With nothing in the tags, the album is the zip's name.
        #expect(record.album == Record.albumFromSourceLabel(zip.lastPathComponent))

        // The titles are the filenames, extension and all, because that is
        // what the script falls back to.
        #expect(record.running.allSatisfy { $0.title == $0.url.lastPathComponent })

        // And the order is the natural filename order — which for a rip named
        // `… - 01 Title.aiff` through `… - 06 Title.aiff` is the album order,
        // arrived at without ever consulting a tag that is not there.
        let names = record.running.map { $0.url.lastPathComponent }
        let expected = names.sorted { NaturalOrder.compare($0, $1) == .orderedAscending }
        #expect(names == expected)
        #expect(record.total > 0)
    }
}

/// So the ordering invariant reads as one comparison rather than four.
private func >= (lhs: (Int, Int), rhs: (Int, Int)) -> Bool {
    lhs.0 != rhs.0 ? lhs.0 > rhs.0 : lhs.1 >= rhs.1
}
