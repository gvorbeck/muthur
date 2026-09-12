import Foundation
import Testing

@testable import MUTHURKit

/// **D85** — corrections kept beside the program rather than written into files.
@Suite("D85 — corrections")
struct CorrectionsTests {

    private func scratch() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "muthur-corrections-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func record(year: String = "2017") -> Record {
        Record(
            tracks: [
                Track(
                    url: URL(fileURLWithPath: "/x/01 Jynweythek.mp3"), duration: 144,
                    title: "Jynweythek", artist: "Aphex Twin", number: 1, disc: 1),
                Track(
                    url: URL(fileURLWithPath: "/x/02 Vordhosbn.mp3"), duration: 292,
                    title: "Vordhosbn", artist: "Aphex Twin", number: 2, disc: 1),
            ],
            album: "Drukqs", albumArtist: "Aphex Twin", year: year,
            sourceLabel: "2001 - Drukqs.zip", unreadableCount: 0)
    }

    // MARK: - The round trip

    /// The whole point, in one test: type a year, quit, come back, still there.
    @Test("a corrected year survives being written and read again")
    func yearSurvives() throws {
        let url = try scratch().appending(path: "corrections.json")
        let key = "/Volumes/My Passport/Music/Aphex Twin/2001 - Drukqs.zip"

        var store = Corrections(at: url)
        store.set(.year, to: "2001", was: "2017", for: key)
        store.save()

        var read = record()
        Corrections(at: url).entry(for: key).map { read.correct(with: $0) }
        #expect(read.year == "2001")
        // And nothing else was touched.
        #expect(read.album == "Drukqs")
        #expect(read.albumArtist == "Aphex Twin")
    }

    /// A correction reaches the record, which is what everything downstream
    /// reads — including the CD-Text that goes into a lead-in.
    @Test("the correction lands on the record and so on the burn's draft")
    func correctionReachesTheDraft() throws {
        var read = record()
        read.correct(with: Corrections.Entry(year: "2001"))
        #expect(PlanDraft(record: read).year == "2001")
    }

    /// Titles are keyed by filename, so a reorder cannot hand one track's
    /// correction to another.
    @Test("a title correction follows its file, not its position")
    func titlesFollowTheFile() throws {
        var read = record()
        read.correct(
            with: Corrections.Entry(titles: ["02 Vordhosbn.mp3": "Vordhösbn"]))
        #expect(read.tracks[0].title == "Jynweythek")
        #expect(read.tracks[1].title == "Vordhösbn")
    }

    /// **Every field the plan editor can type into, and all of them together.**
    ///
    /// Written as one test on purpose: the bug it exists for was a *missing*
    /// field, and a per-field test suite would have had exactly the same hole in
    /// it as the code. `PlanEditor` can change five things — the three header
    /// fields, a track's title, and a track's artist — and this asserts all five
    /// survive a round trip at once.
    @Test("every field the editor can change survives the round trip")
    func everyFieldSurvives() throws {
        let url = try scratch().appending(path: "corrections.json")
        let key = "/x/2001 - Drukqs.zip"
        let original = record()

        var store = Corrections(at: url)
        store.set(.album, to: "drukQs", was: original.album, for: key)
        store.set(.albumArtist, to: "AFX", was: original.albumArtist, for: key)
        store.set(.year, to: "2001", was: original.year, for: key)
        store.set(
            .title(file: "02 Vordhosbn.mp3"), to: "Vordhösbn",
            was: original.tracks[1].title, for: key)
        store.set(
            .artist(file: "02 Vordhosbn.mp3"), to: "Richard D. James",
            was: original.tracks[1].artist, for: key)
        store.save()

        var read = record()
        read.correct(with: Corrections(at: url).entry(for: key))
        #expect(read.album == "drukQs")
        #expect(read.albumArtist == "AFX")
        #expect(read.year == "2001")
        #expect(read.tracks[1].title == "Vordhösbn")
        #expect(read.tracks[1].artist == "Richard D. James")
        // And the track nobody touched is untouched, in both of its fields.
        #expect(read.tracks[0].title == "Jynweythek")
        #expect(read.tracks[0].artist == "Aphex Twin")
    }

    /// A track's artist is not the record's artist. Correcting one track on a
    /// compilation must not restate the album artist, and must not be mistaken
    /// for it.
    @Test("a track's artist is stored apart from the record's")
    func trackArtistIsNotAlbumArtist() throws {
        let url = try scratch().appending(path: "corrections.json")
        var store = Corrections(at: url)
        store.set(
            .artist(file: "02 Vordhosbn.mp3"), to: "Richard D. James",
            was: "Aphex Twin", for: "/x.zip")
        store.save()

        let entry = try #require(Corrections(at: url).entry(for: "/x.zip"))
        #expect(entry.albumArtist == nil)
        #expect(entry.artists["02 Vordhosbn.mp3"] == "Richard D. James")

        var read = record()
        read.correct(with: entry)
        #expect(read.albumArtist == "Aphex Twin")
        #expect(read.tracks[1].artist == "Richard D. James")
    }

    // MARK: - What is not stored

    /// Typing the year the file already carries is not a correction. A store
    /// that kept those would become a second copy of everyone's tags, and would
    /// go on asserting them after the tags were fixed elsewhere.
    @Test("a correction that agrees with the tags is not kept")
    func agreementIsNotStored() throws {
        let url = try scratch().appending(path: "corrections.json")
        var store = Corrections(at: url)
        store.set(.year, to: "2017", was: "2017", for: "/x.zip")
        store.save()
        #expect(!Corrections(at: url).corrects("/x.zip"))
    }

    /// And a correction taken back the same way removes the entry rather than
    /// leaving an empty one behind.
    @Test("correcting back to the tag's value clears the entry")
    func revertingClearsIt() throws {
        let url = try scratch().appending(path: "corrections.json")
        var store = Corrections(at: url)
        store.set(.year, to: "2001", was: "2017", for: "/x.zip")
        store.set(.year, to: "2017", was: "2017", for: "/x.zip")
        store.save()
        #expect(!Corrections(at: url).corrects("/x.zip"))
    }

    /// A disc has no path worth keeping: `/Volumes/Audio CD` belongs to whatever
    /// is in the drive this minute, so keying on it would hand one disc's
    /// correction to the next one that mounted there.
    @Test("a disc is not keyed, and so is not corrected")
    func discsAreNotKeyed() {
        let volume = URL(fileURLWithPath: "/Volumes/Audio CD")
        #expect(Corrections.key(source: volume, kind: .disc) == nil)
        #expect(Corrections.key(source: volume, kind: .folder) != nil)
    }

    // MARK: - When it cannot be written

    /// A store that cannot be saved is a program that shows the tag's year,
    /// which is where it started. It is not an error and says nothing.
    @Test("an unwritable store fails quietly")
    func unwritableIsQuiet() {
        var store = Corrections(at: URL(fileURLWithPath: "/no/such/place/corrections.json"))
        store.set(.year, to: "2001", was: "2017", for: "/x.zip")
        store.save()
        // The correction is still live for this session, which is the whole of
        // what was lost.
        #expect(store.corrects("/x.zip"))
    }

    /// A file full of nonsense is discarded rather than repaired, because the
    /// alternative is a program that will not start over a file nobody has
    /// heard of.
    @Test("a corrupt store is discarded, not fatal")
    func corruptIsDiscarded() throws {
        let url = try scratch().appending(path: "corrections.json")
        try Data("{not json".utf8).write(to: url)
        // Not a whole-value comparison: two stores differ by the path they came
        // from whatever is in them. What is asserted is the behaviour — nothing
        // was read, and the store is still usable.
        let store = Corrections(at: url)
        #expect(store.entry(for: "/x.zip") == nil)
        #expect(!store.corrects("/x.zip"))
    }

    /// Nothing said is different from something cleared. An absent field leaves
    /// the tag's value alone; an empty one is a deliberate blank.
    @Test("an absent field and an empty one are different")
    func absentIsNotEmpty() {
        var read = record()
        read.correct(with: Corrections.Entry(album: nil))
        #expect(read.album == "Drukqs")
        read.correct(with: Corrections.Entry(album: ""))
        #expect(read.album == "")
    }
}
