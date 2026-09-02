import Foundation
import Testing

@testable import MUTHURKit

/// §7 — what survives a quit, and what it is allowed to do when you come back.
@Suite("Resume")
struct ResumeTests {

    // MARK: - Scaffolding

    /// A resume file in a throwaway directory. Nothing in this suite goes near
    /// `~/.local/state`.
    private struct Scratch: ~Copyable {
        let root: URL
        let file: ResumeFile

        init() {
            root = FileManager.default.temporaryDirectory
                .appending(path: "muthur-resume/\(UUID().uuidString)")
            file = ResumeFile(url: root.appending(path: "player/resume"))
        }

        var text: String { (try? String(contentsOf: file.url, encoding: .utf8)) ?? "" }
        var lines: [String] { text.split(separator: "\n").map(String.init) }

        func plant(_ body: String) {
            try? FileManager.default.createDirectory(
                at: file.url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try? Data(body.utf8).write(to: file.url)
        }

        deinit { try? FileManager.default.removeItem(at: root) }
    }

    private static func record(
        albumArtist: String = "Cake", album: String = "Comfort Eagle", tracks: Int = 3,
        seconds: Int = 200
    ) -> Record {
        Record(
            tracks: (0..<tracks).map {
                Track(
                    url: URL(fileURLWithPath: "/tmp/\($0).flac"), duration: seconds,
                    title: "T\($0)", artist: albumArtist, number: $0 + 1, disc: 1
                )
            },
            album: album, albumArtist: albumArtist, year: "2001", sourceLabel: "Comfort Eagle"
        )
    }

    // MARK: - The key

    @Test("A disc says what it is outright, so it is the key when there is one")
    func discKey() {
        let record = Self.record()
        #expect(ResumeFile.key(for: record, discID: "abc-123") == "d:abc-123")
        // `-n "${DISCID:-}"` — an empty disc ID is no disc ID.
        #expect(ResumeFile.key(for: record, discID: "").hasPrefix("a:"))
        #expect(ResumeFile.key(for: record, discID: nil).hasPrefix("a:"))
    }

    @Test("Otherwise: artist, album, how many, how long — sixteen hex characters")
    func hashedKey() {
        let key = ResumeFile.key(albumArtist: "Cake", album: "Comfort Eagle", trackCount: 3, total: 600)
        #expect(key.hasPrefix("a:"))
        #expect(key.count == 18)
        #expect(key.dropFirst(2).allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    /// This is the whole reason the key is not a path.
    @Test("A moved folder and a re-unpacked zip are the same record")
    func keyIgnoresWhereItLives() {
        let one = Record(
            tracks: Self.record().tracks, album: "Comfort Eagle", albumArtist: "Cake",
            year: "2001", sourceLabel: "/Users/x/Music/Comfort Eagle"
        )
        let two = Record(
            tracks: Self.record().tracks, album: "Comfort Eagle", albumArtist: "Cake",
            year: "2001", sourceLabel: "/var/folders/T/abc123/Comfort Eagle"
        )
        #expect(ResumeFile.key(for: one) == ResumeFile.key(for: two))
    }

    @Test("Any of the four facts changing is a different record")
    func keyIsSensitive() {
        let base = ResumeFile.key(albumArtist: "a", album: "b", trackCount: 3, total: 600)
        #expect(ResumeFile.key(albumArtist: "z", album: "b", trackCount: 3, total: 600) != base)
        #expect(ResumeFile.key(albumArtist: "a", album: "z", trackCount: 3, total: 600) != base)
        #expect(ResumeFile.key(albumArtist: "a", album: "b", trackCount: 4, total: 600) != base)
        #expect(ResumeFile.key(albumArtist: "a", album: "b", trackCount: 3, total: 601) != base)
    }

    /// `printf '%s|%s|%s|%s' | shasum | cut -c1-16`, run by hand:
    /// `Cake|Comfort Eagle|3|600` → `36ff81d1d8adbb64…`.
    @Test("The digest is the script's digest, not merely a digest")
    func keyMatchesTheScript() throws {
        let subject = "Cake|Comfort Eagle|3|600"
        guard let shasum = Fixtures.locate("shasum") else { return }
        let process = Process()
        process.executableURL = shasum
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(Data(subject.utf8))
        try input.fileHandleForWriting.close()
        let data = try output.fileHandleForReading.readToEnd() ?? Data()
        process.waitUntilExit()

        let expected = "a:" + String(String(decoding: data, as: UTF8.self).prefix(16))
        #expect(
            ResumeFile.key(albumArtist: "Cake", album: "Comfort Eagle", trackCount: 3, total: 600)
                == expected
        )
    }

    // MARK: - Where it lives

    @Test("XDG_STATE_HOME is respected; otherwise ~/.local/state")
    func location() {
        let home = URL(fileURLWithPath: "/Users/nobody")
        #expect(
            ResumeFile.standard(environment: [:], home: home).url.path
                == "/Users/nobody/.local/state/player/resume"
        )
        #expect(
            ResumeFile.standard(environment: ["XDG_STATE_HOME": "/s"], home: home).url.path
                == "/s/player/resume"
        )
        // An empty variable is not a directory called "".
        #expect(
            ResumeFile.standard(environment: ["XDG_STATE_HOME": ""], home: home).url.path
                == "/Users/nobody/.local/state/player/resume"
        )
    }

    // MARK: - The offer

    @Test("Where it left off, when there is somewhere worth going")
    func offered() {
        let scratch = Scratch()
        scratch.plant("k\t2\t95\tComfort Eagle\n")
        #expect(scratch.file.offer(key: "k", rows: 3) == ResumeFile.Offer(row: 2, position: 95))
    }

    @Test("Nothing at all when there is no file")
    func noFile() {
        let scratch = Scratch()
        #expect(scratch.file.offer(key: "k", rows: 3) == nil)
    }

    @Test("Row nought under thirty seconds is where the record starts anyway")
    func notOfferedAtTheTop() {
        let scratch = Scratch()
        scratch.plant("k\t0\t29\tx\n")
        #expect(scratch.file.offer(key: "k", rows: 3) == nil)

        scratch.plant("k\t0\t30\tx\n")
        #expect(scratch.file.offer(key: "k", rows: 3) == ResumeFile.Offer(row: 0, position: 30))

        // Any other row is a real listening session however far in it is.
        scratch.plant("k\t1\t0\tx\n")
        #expect(scratch.file.offer(key: "k", rows: 3) == ResumeFile.Offer(row: 1, position: 0))
    }

    @Test("A row the record no longer has is not offered")
    func rowOutOfRange() {
        let scratch = Scratch()
        scratch.plant("k\t7\t95\tx\n")
        #expect(scratch.file.offer(key: "k", rows: 3) == nil)
        #expect(scratch.file.offer(key: "k", rows: 8) == ResumeFile.Offer(row: 7, position: 95))
    }

    @Test("A malformed line for this record is no offer, not a search for a better one")
    func malformedIsNoOffer() {
        let scratch = Scratch()
        scratch.plant("k\tnine\t95\tx\nk\t1\t95\tx\n")
        #expect(scratch.file.offer(key: "k", rows: 3) == nil)

        scratch.plant("k\t1\tages\tx\n")
        #expect(scratch.file.offer(key: "k", rows: 3) == nil)
    }

    @Test("Other albums are stepped over, not stumbled on")
    func otherAlbums() {
        let scratch = Scratch()
        scratch.plant("a\t1\t10\tx\nb\tbroken\tx\tx\nk\t2\t95\tx\n")
        #expect(scratch.file.offer(key: "k", rows: 3) == ResumeFile.Offer(row: 2, position: 95))
    }

    @Test("The offer counts the row and the minutes, and asks")
    func offerText() {
        #expect(ResumeFile.Offer(row: 4, position: 95).text == "▪ RESUME AT 5 · 1:35 — PRESS U")
        #expect(ResumeFile.Offer(row: 0, position: 605).text == "▪ RESUME AT 1 · 10:05 — PRESS U")
    }

    /// D25. A folder of untagged rips is every row at 9999, and the script
    /// offered that number for all of them alike (§18.20).
    @Test("It never says 9999, whatever the tags failed to say")
    func offerNeverSaysTheSentinel() {
        for row in 0..<12 {
            #expect(!ResumeFile.Offer(row: row, position: 30).text.contains("9999"))
        }
        #expect(ResumeFile.Offer(row: 3, position: 30).text.contains("RESUME AT 4"))
    }

    // MARK: - Writing

    @Test("An upsert with no database under it")
    func upsert() {
        let scratch = Scratch()
        scratch.file.save(key: "k", row: 1, position: 10, sourceLabel: "Kin")
        #expect(scratch.lines == ["k\t1\t10\tKin"])

        scratch.file.save(key: "k", row: 1, position: 15, sourceLabel: "Kin")
        #expect(scratch.lines == ["k\t1\t15\tKin"])

        scratch.file.save(key: "j", row: 0, position: 44, sourceLabel: "Other")
        #expect(scratch.lines == ["k\t1\t15\tKin", "j\t0\t44\tOther"])

        // This one back on the bottom, which is what keeps the file in
        // least-recently-played order for the cap to work on.
        scratch.file.save(key: "k", row: 2, position: 3, sourceLabel: "Kin")
        #expect(scratch.lines == ["j\t0\t44\tOther", "k\t2\t3\tKin"])
    }

    @Test("Two hundred other albums, and the oldest goes off the top")
    func cap() {
        let scratch = Scratch()
        scratch.plant((1...250).map { "k\($0)\t0\t99\tx" }.joined(separator: "\n") + "\n")
        scratch.file.save(key: "mine", row: 1, position: 5, sourceLabel: "Mine")

        let lines = scratch.lines
        #expect(lines.count == 201)
        #expect(lines.first == "k51\t0\t99\tx")
        #expect(lines.last == "mine\t1\t5\tMine")
    }

    @Test("A record played to the end has nowhere to be resumed from")
    func cleared() {
        let scratch = Scratch()
        scratch.file.save(key: "j", row: 0, position: 44, sourceLabel: "Other")
        scratch.file.save(key: "k", row: 2, position: 95, sourceLabel: "Kin")
        scratch.file.clear(key: "k")

        #expect(scratch.lines == ["j\t0\t44\tOther"])
        #expect(scratch.file.offer(key: "k", rows: 3) == nil)
    }

    @Test("Clearing does not take two hundred other albums with it")
    func clearHasNoCap() {
        let scratch = Scratch()
        scratch.plant(
            (1...250).map { "k\($0)\t0\t99\tx" }.joined(separator: "\n") + "\nmine\t1\t5\tx\n"
        )
        scratch.file.clear(key: "mine")
        #expect(scratch.lines.count == 250)
    }

    @Test("The last album out leaves an empty file, not a blank line")
    func clearToNothing() {
        let scratch = Scratch()
        scratch.file.save(key: "k", row: 1, position: 10, sourceLabel: "Kin")
        scratch.file.clear(key: "k")
        #expect(scratch.text.isEmpty)
    }

    @Test("A tab in the source label stays in the source label")
    func labelWithTabs() {
        let scratch = Scratch()
        scratch.file.save(key: "k", row: 1, position: 10, sourceLabel: "od\td")
        #expect(scratch.file.entries().first?.sourceLabel == "od\td")
        #expect(scratch.file.offer(key: "k", rows: 3) == ResumeFile.Offer(row: 1, position: 10))
    }

    @Test("What is written is what is offered back")
    func roundTrip() {
        let scratch = Scratch()
        let key = ResumeFile.key(for: Self.record())
        scratch.file.save(key: key, row: 2, position: 95, sourceLabel: "Comfort Eagle")
        #expect(
            scratch.file.offer(key: key, rows: 3) == ResumeFile.Offer(row: 2, position: 95)
        )
    }

    // MARK: - The watch

    @Test("A new track is written before a note of it has played")
    func writesOnTrackChange() {
        let scratch = Scratch()
        var watch = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)

        watch.observe(mode: .playing, row: 0, positionInTrack: 0)
        #expect(scratch.lines == ["k\t0\t0\tKin"])

        watch.observe(mode: .playing, row: 1, positionInTrack: 0)
        #expect(scratch.lines == ["k\t1\t0\tKin"])
    }

    @Test("Then every five seconds of position, and not every one of them")
    func writesEveryFiveSeconds() {
        let scratch = Scratch()
        var watch = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)
        watch.observe(mode: .playing, row: 0, positionInTrack: 0)

        // Twenty ticks a second for four seconds: still where it started.
        for tick in 0..<80 {
            watch.observe(mode: .playing, row: 0, positionInTrack: Double(tick) * 0.05)
        }
        #expect(scratch.lines == ["k\t0\t0\tKin"])

        watch.observe(mode: .playing, row: 0, positionInTrack: 5.0)
        #expect(scratch.lines == ["k\t0\t5\tKin"])

        watch.observe(mode: .playing, row: 0, positionInTrack: 9.9)
        #expect(scratch.lines == ["k\t0\t5\tKin"])

        watch.observe(mode: .playing, row: 0, positionInTrack: 10.0)
        #expect(scratch.lines == ["k\t0\t10\tKin"])
    }

    @Test("A seek backwards is caught too — the rule is symmetric on purpose")
    func writesOnBackwardSeek() {
        let scratch = Scratch()
        var watch = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)
        watch.observe(mode: .playing, row: 1, positionInTrack: 0)
        watch.observe(mode: .playing, row: 1, positionInTrack: 120)
        #expect(scratch.lines == ["k\t1\t120\tKin"])

        watch.observe(mode: .playing, row: 1, positionInTrack: 40)
        #expect(scratch.lines == ["k\t1\t40\tKin"])
    }

    @Test("A stopped deck has not got anywhere yet and says nothing")
    func stoppedWritesNothing() {
        let scratch = Scratch()
        var watch = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)
        watch.observe(mode: .stopped, row: 0, positionInTrack: 0)
        #expect(scratch.text.isEmpty)
    }

    @Test("A paused deck keeps its place and does not keep rewriting it")
    func pausedIsQuiet() {
        let scratch = Scratch()
        var watch = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)
        watch.observe(mode: .playing, row: 1, positionInTrack: 61)
        #expect(scratch.lines == ["k\t1\t0\tKin"])
        watch.observe(mode: .playing, row: 1, positionInTrack: 61)
        #expect(scratch.lines == ["k\t1\t61\tKin"])

        for _ in 0..<40 { watch.observe(mode: .paused, row: 1, positionInTrack: 61) }
        #expect(scratch.lines == ["k\t1\t61\tKin"])
    }

    @Test("The end of the record takes the entry with it, once")
    func finishClears() {
        let scratch = Scratch()
        scratch.file.save(key: "j", row: 0, position: 44, sourceLabel: "Other")
        var watch = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)
        watch.observe(mode: .playing, row: 2, positionInTrack: 0)
        watch.observe(mode: .playing, row: 2, positionInTrack: 190)
        #expect(scratch.lines.count == 2)

        watch.observe(mode: .finished, row: 2, positionInTrack: 200)
        #expect(scratch.lines == ["j\t0\t44\tOther"])

        // A finished record stays finished; the file is not rewritten for the
        // rest of the session to say the same nothing.
        scratch.file.save(key: "z", row: 1, position: 9, sourceLabel: "Z")
        for _ in 0..<20 { watch.observe(mode: .finished, row: 2, positionInTrack: 200) }
        #expect(scratch.lines == ["j\t0\t44\tOther", "z\t1\t9\tZ"])
    }

    @Test("The offer goes up once, after the first track has started")
    func offerIsShownOnce() {
        let scratch = Scratch()
        scratch.plant("k\t2\t95\tKin\n")
        var watch = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)

        #expect(watch.offer == ResumeFile.Offer(row: 2, position: 95))
        #expect(watch.offerToShow(mode: .stopped) == nil)
        #expect(watch.offerToShow(mode: .playing) == ResumeFile.Offer(row: 2, position: 95))
        #expect(watch.offerToShow(mode: .playing) == nil)
    }

    /// The first box of §7, as a test: the watch has no way to move the needle.
    @Test("It is offered and never applied, and stays pressable until it is pressed")
    func offerSurvivesUntilSpent() {
        let scratch = Scratch()
        scratch.plant("k\t2\t95\tKin\n")
        var watch = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)

        _ = watch.offerToShow(mode: .playing)
        watch.observe(mode: .playing, row: 0, positionInTrack: 0)
        watch.observe(mode: .playing, row: 0, positionInTrack: 30)
        // The record has been playing from the top the whole time — the offer
        // never touched it.
        #expect(scratch.lines == ["k\t0\t30\tKin"])
        #expect(watch.offer == ResumeFile.Offer(row: 2, position: 95))

        #expect(watch.spend() == ResumeFile.Offer(row: 2, position: 95))
        #expect(watch.spend() == nil)
        #expect(watch.offer == nil)
    }

    // MARK: - Against autoplay (D51)

    /// **The thing D51 could have broken.** A record now starts the moment it is
    /// opened, and it starts at the top — so the deck's very first observation
    /// writes row nought over the line that says where you had got to. If the
    /// watch read the file lazily, the saved position would be gone before
    /// anybody could be offered it, and a record opened at a saved position
    /// would simply restart.
    ///
    /// It does not, because the file is read in `init` and the answer is kept in
    /// memory for the session. This is the assertion that keeps that true, and
    /// it is why `PanelModel.adopt` builds the watch *above* the load, not
    /// inside it.
    @Test("Autoplay overwrites the file and the offer survives it anyway")
    func theOfferOutlivesTheRecordStartingItself() {
        let scratch = Scratch()
        scratch.plant("k\t2\t95\tKin\n")

        // Opened. Everything the panel knows about resume, it knows by now.
        var watch = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)

        // And immediately started, the way `append-play` starts it.
        watch.observe(mode: .playing, row: 0, positionInTrack: 0)
        watch.observe(mode: .playing, row: 0, positionInTrack: 6)

        // The file has been rewritten to the top of the record.
        #expect(scratch.lines == ["k\t0\t6\tKin"])
        // The offer is still where it was, and still pressable.
        #expect(watch.offerToShow(mode: .playing) == ResumeFile.Offer(row: 2, position: 95))
        #expect(watch.spend() == ResumeFile.Offer(row: 2, position: 95))
    }

    /// The same thing from the other side: reading the file *after* the deck has
    /// started finds row nought, which is exactly the restart the ordering above
    /// exists to prevent. Not a rule anything follows — a demonstration of the
    /// one that is being followed, so that reordering `adopt` fails here.
    @Test("A watch built after the deck started would find only the restart")
    func readingLateWouldLoseThePlace() {
        let scratch = Scratch()
        scratch.plant("k\t2\t95\tKin\n")

        var early = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)
        early.observe(mode: .playing, row: 0, positionInTrack: 0)

        let late = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)
        // Row nought at nought seconds is not worth offering, so the late reader
        // has nothing at all — the place is not merely wrong, it is gone.
        #expect(late.offer == nil)
        #expect(early.offer == ResumeFile.Offer(row: 2, position: 95))
    }

    @Test("No offer means nothing to show and nothing to spend")
    func noOfferNoShow() {
        let scratch = Scratch()
        var watch = ResumeWatch(file: scratch.file, key: "k", sourceLabel: "Kin", rows: 3)
        #expect(watch.offerToShow(mode: .playing) == nil)
        #expect(watch.spend() == nil)
    }
}
