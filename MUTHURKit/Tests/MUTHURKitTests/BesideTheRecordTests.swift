import Foundation
import Testing

@testable import MUTHURKit

/// §5.1 against real files and real pixels — the half of finding a sleeve that
/// only a decoder can answer.
@Suite("Sleeve — beside the record")
struct BesideTheRecordTests {

    // MARK: - The scan

    @Test("Three levels down and no further")
    func maximumDepth() throws {
        let album = TempDirectory("album")
        try album.picture("cover.jpg")
        try album.picture("Scans/front.jpg")
        try album.picture("Artwork/CD1/front.jpg")
        try album.picture("a/b/c/front.jpg")

        let found = BesideTheRecord.scan(album.url).map { $0.path.hasSuffix("c/front.jpg") }
        #expect(BesideTheRecord.scan(album.url).count == 3)
        #expect(!found.contains(true))
    }

    @Test("Only the picture extensions")
    func extensions() throws {
        let album = TempDirectory("album")
        try album.picture("cover.jpg")
        try album.picture("cover2.PNG")
        try album.write("notes.txt", Data("hello".utf8))
        try album.write("01 Track.flac", Data())

        #expect(
            Set(BesideTheRecord.scan(album.url).map(\.lastPathComponent))
                == ["cover.jpg", "cover2.PNG"]
        )
    }

    // MARK: - The floor

    @Test("A picture under 200 px on a side is refused")
    func sizeFloor() throws {
        let album = TempDirectory("album")
        try album.picture("cover.jpg", side: 90)
        let bandcamp = try album.picture("Cake - Comfort Eagle.jpg", side: 1000)

        // `cover.jpg` outranks it on name and loses on pixels, which is the
        // whole reason the probe runs inside the loop rather than after it.
        #expect(samePath(BesideTheRecord.find(in: album.url, probe: ImageIOPictureProbe()), bandcamp))
    }

    @Test("200 px exactly clears the floor")
    func floorIsInclusive() throws {
        let album = TempDirectory("album")
        let cover = try album.picture("cover.jpg", side: 200)
        #expect(samePath(BesideTheRecord.find(in: album.url, probe: ImageIOPictureProbe()), cover))
    }

    @Test("A short side under the floor fails even when the long side clears it")
    func bothSidesCount() throws {
        let album = TempDirectory("album")
        try album.picture("cover.jpg", width: 1500, height: 60)
        #expect(BesideTheRecord.find(in: album.url, probe: ImageIOPictureProbe()) == nil)
    }

    @Test("Bytes that are not a picture are refused whatever they are called")
    func notAPicture() throws {
        let album = TempDirectory("album")
        try album.write("cover.jpg", TestPictures.notAPicture)
        try album.write("front.png", Data())
        let real = try album.picture("zzz.jpg", side: 400)

        #expect(samePath(BesideTheRecord.find(in: album.url, probe: ImageIOPictureProbe()), real))
    }

    @Test("A truncated JPEG passes, because the probe reads the header and stops")
    func truncated() throws {
        let album = TempDirectory("album")
        let whole = TestPictures.jpeg(600)
        let cut = try album.write("cover.jpg", whole.prefix(whole.count / 3))

        // Not the behaviour anybody would design, and exactly the script's:
        // `ffprobe -show_entries stream=width,height` reads the header, and the
        // header of a half-written JPEG is right. Catching it would mean fully
        // decoding every candidate before the panel's first frame, to cover a
        // case the `.part` file already prevents on the cache side. Asserted so
        // that the limit is written down rather than assumed away.
        #expect(ImageIOPictureProbe().size(of: cut) == PictureSize(width: 600, height: 600))
        #expect(samePath(BesideTheRecord.find(in: album.url, probe: ImageIOPictureProbe()), cut))
    }

    // MARK: - The order, end to end

    @Test("The best-ranked readable picture wins")
    func picksTheFront() throws {
        let album = TempDirectory("album")
        try album.picture("back.jpg", side: 1200)
        try album.picture("Cake - Comfort Eagle.jpg", side: 1200)
        let cover = try album.picture("cover.jpg", side: 600)
        try album.picture("Scans/cover.jpg", side: 3000)

        #expect(samePath(BesideTheRecord.find(in: album.url, probe: ImageIOPictureProbe()), cover))
    }

    @Test("An album with nothing but the back of the sleeve has no sleeve")
    func onlyThrownOutNames() throws {
        let album = TempDirectory("album")
        try album.picture("back.jpg", side: 1200)
        try album.picture("cd1.jpg", side: 1200)
        try album.picture("booklet-03.jpg", side: 1200)

        // Not "the best of a bad lot" — the network answer it would displace is
        // more likely to be the front than the disc label is.
        #expect(BesideTheRecord.find(in: album.url, probe: ImageIOPictureProbe()) == nil)
    }

    @Test("A directory with no pictures at all")
    func nothingThere() throws {
        let album = TempDirectory("album")
        try album.write("01 Track.flac", Data())
        #expect(BesideTheRecord.find(in: album.url, probe: ImageIOPictureProbe()) == nil)
        #expect(BesideTheRecord.find(in: album.url.appending(path: "gone"), probe: ImageIOPictureProbe()) == nil)
    }

    // MARK: - The probe on its own

    @Test("The probe reports the real dimensions")
    func probeMeasures() throws {
        let album = TempDirectory("album")
        let file = try album.picture("cover.jpg", width: 640, height: 480)
        #expect(ImageIOPictureProbe().size(of: file) == PictureSize(width: 640, height: 480))
    }

    @Test("A missing file is not a picture")
    func probeMissing() throws {
        let album = TempDirectory("album")
        #expect(ImageIOPictureProbe().size(of: album.url.appending(path: "nope.jpg")) == nil)
    }

    @Test("With no floor asked for, readable is the only question")
    func probeWithoutFloor() throws {
        let album = TempDirectory("album")
        let tiny = try album.picture("tiny.jpg", side: 8)
        #expect(ImageIOPictureProbe().isPicture(tiny))
        #expect(!ImageIOPictureProbe().isPicture(tiny, minimumSide: 200))
    }
}
