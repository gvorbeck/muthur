import Foundation
import Testing

@testable import MUTHURKit

/// §21, rules tier — everything an import decides before it touches a disk.
///
/// No ffmpeg and no filesystem: `ImportPlan.make` takes its `exists` closure so
/// the collision arithmetic can be put against a volume that is not there,
/// which is the only way the interesting cases are ever reached. The tier that
/// really writes files is `ImportMaterialTests`.
@Suite("§21 — import rules")
struct ImportTests {

    // MARK: - Names

    @Test("a slash cannot reach the filesystem")
    func slashes() {
        // The one character the kernel refuses. A title with one in it is not
        // rare — `AC/DC` and `Faith/Void` are records.
        #expect(ImportNames.component("AC/DC") == "AC-DC")
        #expect(!ImportNames.component("9/11 was an inside job").contains("/"))
        // A slash between spaces is a separator like the colon; a bare one is
        // part of the name.
        #expect(ImportNames.component("Hello / Goodbye") == "Hello - Goodbye")
        #expect(ImportNames.component("AC/DC Live") == "AC-DC Live")
    }

    @Test("a colon goes too, because Finder draws it as a slash")
    func colons() {
        // A colon that separates two phrases becomes a spaced dash, which is
        // what every hand-filed shelf already does: `Gold: Greatest Hits` is
        // filed as `Gold - Greatest Hits`. A bare one is still a bare dash.
        #expect(ImportNames.component("Tago Mago: Disc One") == "Tago Mago - Disc One")
        #expect(
            ImportNames.component("American IV: The Man Comes Around")
                == "American IV - The Man Comes Around")
        #expect(ImportNames.component("10:15 Saturday Night") == "10-15 Saturday Night")
    }

    @Test("the punctuation other systems dislike is kept")
    func punctuationKept() {
        // Deliberately not sanitised — see `ImportNames.component`. These are
        // legal here, and removing them would be guessing about a disk this
        // program has not been told about.
        for name in ["Where Is My Mind?", "*Fazer*", "Q: Are We Not Men?", #"A\B"#] {
            let out = ImportNames.component(name)
            #expect(!out.isEmpty)
        }
        #expect(ImportNames.component("Where Is My Mind?") == "Where Is My Mind?")
        #expect(
            ImportNames.component("Q: Are We Not Men?") == "Q - Are We Not Men?")
    }

    @Test("control characters become one space, not several")
    func controls() {
        #expect(ImportNames.component("A\u{0}\u{1}B") == "A B")
        #expect(ImportNames.component("A\r\nB") == "A B")
    }

    @Test("a name never begins with a dot or ends in one")
    func dots() {
        #expect(ImportNames.component(".hidden") == "hidden")
        #expect(ImportNames.component("Etc...") == "Etc")
        #expect(ImportNames.component("  spaced  ") == "spaced")
    }

    @Test("a long title is cut on a character boundary and stays valid UTF-8")
    func clamping() {
        // Four-byte scalars, so a naive byte cut lands inside one.
        let long = String(repeating: "𝄞", count: 200)
        let out = ImportNames.component(long)
        #expect(out.utf8.count <= ImportNames.byteBudget)
        // The real assertion: it is still a string, and every scalar in it is
        // one that went in. A truncation inside a scalar would not round-trip.
        #expect(out.allSatisfy { $0 == "𝄞" })
        #expect(String(decoding: Array(out.utf8), as: UTF8.self) == out)
    }

    @Test("a title that sanitises to nothing still gets a filename")
    func emptyTitle() {
        // `...` is a title made entirely of characters the rules remove.
        let name = ImportNames.trackFile(number: 7, title: "...", format: .flac)
        #expect(name == "07 - Track 07.flac")
    }

    @Test("the track file is numbered to two places so it sorts")
    func numbering() {
        #expect(
            ImportNames.trackFile(number: 2, title: "Let It Rock", format: .flac)
                == "02 - Let It Rock.flac")
        #expect(
            ImportNames.trackFile(number: 10, title: "Wanted", format: .mp3)
                == "10 - Wanted.mp3")
    }

    @Test("the record folder is artist then album, and neither half is required")
    func folderNames() {
        // The default is the album alone: the directory you choose is usually
        // already an artist's, and `Johnny Cash/Johnny Cash - …` stutters.
        #expect(
            ImportNames.recordFolder(album: "Slippery When Wet", albumArtist: "Bon Jovi")
                == "Slippery When Wet")
        #expect(
            ImportNames.recordFolder(
                album: "Slippery When Wet", albumArtist: "Bon Jovi", style: .artistAndAlbum)
                == "Bon Jovi - Slippery When Wet")
        #expect(ImportNames.recordFolder(album: "Untitled", albumArtist: "") == "Untitled")
        // Either style falls back to the artist when the record has no name.
        #expect(ImportNames.recordFolder(album: "", albumArtist: "Bon Jovi") == "Bon Jovi")
        #expect(
            ImportNames.recordFolder(
                album: "", albumArtist: "Bon Jovi", style: .artistAndAlbum) == "Bon Jovi")
        #expect(ImportNames.recordFolder(album: "", albumArtist: "") == "Untitled Record")
    }

    // MARK: - Not writing over anything

    @Test("a taken name gets a number, and the extension stays last")
    func vacancy() {
        let root = URL(fileURLWithPath: "/tmp/x")
        let taken: Set<String> = ["/tmp/x/01 Song.flac", "/tmp/x/01 Song (2).flac"]
        let url = ImportNames.vacant(
            "01 Song.flac", in: root, exists: { taken.contains($0.path) })
        // `01 Song (3).flac` — the suffix goes on the stem, never after the
        // extension, or nothing downstream knows what kind of file it is.
        #expect(url?.lastPathComponent == "01 Song (3).flac")
    }

    @Test("a folder has no extension and keeps its whole name")
    func vacantFolder() {
        let root = URL(fileURLWithPath: "/tmp/x")
        let taken: Set<String> = ["/tmp/x/Bon Jovi - Slippery When Wet"]
        let url = ImportNames.vacant(
            "Bon Jovi - Slippery When Wet", in: root, exists: { taken.contains($0.path) })
        #expect(url?.lastPathComponent == "Bon Jovi - Slippery When Wet (2)")
    }

    @Test("a filesystem that says everything exists is an answer, not a hang")
    func vacancyBounded() {
        // The defence against an unbounded loop. Every candidate is taken, so
        // this must come back nil rather than counting forever.
        let url = ImportNames.vacant(
            "x.flac", in: URL(fileURLWithPath: "/tmp"), exists: { _ in true }, limit: 20)
        #expect(url == nil)
    }

    // MARK: - The plan

    /// A record with no files behind it. Nothing in the plan reads one.
    static func record(
        titles: [String], numbers: [Int]? = nil, album: String = "Slippery When Wet",
        artist: String = "Bon Jovi"
    ) -> Record {
        let tracks = titles.enumerated().map { index, title in
            Track(
                url: URL(fileURLWithPath: "/Volumes/Audio CD/\(index + 1) Audio Track.aiff"),
                duration: 180 + index,
                title: title,
                artist: "",
                number: numbers?[index] ?? index + 1,
                disc: 1)
        }
        return Record(
            tracks: tracks, album: album, albumArtist: artist, year: "1986",
            sourceLabel: "Audio CD", unreadableCount: 0)
    }

    @Test("every track gets a destination under one folder")
    func planLayout() throws {
        let plan = try ImportPlan.make(
            record: ImportTests.record(titles: ["Let It Rock", "You Give Love a Bad Name"]),
            destination: URL(fileURLWithPath: "/tmp/rips"),
            format: .flac,
            exists: { _ in false })
        #expect(plan.folder.lastPathComponent == "Slippery When Wet")
        #expect(plan.folderIsOurs)
        #expect(plan.entries.count == 2)
        #expect(plan.entries[0].destination.lastPathComponent == "01 - Let It Rock.flac")
        #expect(
            plan.entries[1].destination.lastPathComponent
                == "02 - You Give Love a Bad Name.flac")
        // Every file is inside the folder and not beside it.
        //
        // By `path` and not by `URL` equality, which asserts more than the
        // platform promises: `deletingLastPathComponent()` hands back a URL
        // marked as a directory and `appending(path:)` infers that it is not,
        // so two URLs naming the same folder compare unequal. The path is the
        // thing the write actually uses.
        #expect(
            plan.entries.allSatisfy {
                $0.destination.deletingLastPathComponent().path == plan.folder.path
            })
    }

    @Test("with no record folder the tracks land in the chosen directory")
    func planFlat() throws {
        let root = URL(fileURLWithPath: "/tmp/rips")
        let plan = try ImportPlan.make(
            record: ImportTests.record(titles: ["Let It Rock"]),
            destination: root, format: .aiff, folderStyle: .none, exists: { _ in false })
        #expect(plan.folder == root)
        // Not ours, so a cancel must not take the directory with it.
        #expect(!plan.folderIsOurs)
    }

    @Test("two tracks with the same title do not plan onto each other")
    func duplicateTitles() throws {
        // A reprise, or an untitled disc where §4.1 gave every row the same
        // name. The leading number makes this rare rather than impossible —
        // these two share both.
        let plan = try ImportPlan.make(
            record: ImportTests.record(titles: ["Reprise", "Reprise"], numbers: [4, 4]),
            destination: URL(fileURLWithPath: "/tmp/rips"),
            format: .flac, exists: { _ in false })
        let names = plan.entries.map(\.destination.lastPathComponent)
        #expect(names == ["04 - Reprise.flac", "04 - Reprise (2).flac"])
        #expect(Set(names).count == 2)
    }

    @Test("a track with no number of its own is numbered by its place")
    func unnumbered() throws {
        // 9999 is a sort key, not a fact, and it must never reach a filename.
        let track = Track(
            url: URL(fileURLWithPath: "/x/a.aiff"), duration: 100, title: "Untitled",
            artist: "", number: Track.noNumber, disc: 1)
        #expect(ImportPlan.number(for: track, at: 6) == 7)
        let plan = try ImportPlan.make(
            record: ImportTests.record(
                titles: ["A", "B"], numbers: [Track.noNumber, Track.noNumber]),
            destination: URL(fileURLWithPath: "/tmp/rips"), format: .flac,
            exists: { _ in false })
        #expect(plan.entries.map(\.number) == [1, 2])
        #expect(!plan.entries.contains { $0.destination.lastPathComponent.contains("9999") })
    }

    @Test("the plan creates nothing")
    func planIsInert() throws {
        // A description that left a directory behind when it was refused would
        // be a side effect nobody asked for.
        let root = FileManager.default.temporaryDirectory
            .appending(path: "muthur-import-inert-\(UUID().uuidString)")
        _ = try ImportPlan.make(
            record: ImportTests.record(titles: ["A"]), destination: root, format: .flac)
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test("an empty record is refused rather than planned")
    func nothingToImport() {
        let empty = Record(
            tracks: [], album: "", albumArtist: "", year: "", sourceLabel: "x",
            unreadableCount: 0)
        #expect(throws: ImportPlan.Failure.nothingToImport) {
            try ImportPlan.make(
                record: empty, destination: URL(fileURLWithPath: "/tmp"), format: .flac,
                exists: { _ in false })
        }
    }

    // MARK: - Room

    @Test("the size estimate is above the truth for every format")
    func estimates() {
        // The number only ever refuses a job, so erring high is the safe
        // direction. Uncompressed is the floor everything else is judged by.
        let minute = 60
        let pcm = minute * BurnLimits.bytesPerSecond
        #expect(ImportPlan.bytes(seconds: minute, format: .wav) >= pcm)
        #expect(ImportPlan.bytes(seconds: minute, format: .aiff) >= pcm)
        // Lossless compression never doubles, and never gets below a third on
        // this material — the allowance is between.
        #expect(ImportPlan.bytes(seconds: minute, format: .flac) < pcm)
        #expect(ImportPlan.bytes(seconds: minute, format: .flac) > pcm / 3)
        // Lossy is an order of magnitude smaller, and Opus smaller than MP3.
        #expect(ImportPlan.bytes(seconds: minute, format: .mp3) < pcm / 4)
        #expect(ImportPlan.bytes(seconds: minute, format: .opus)
            < ImportPlan.bytes(seconds: minute, format: .mp3))
    }

    @Test("a volume that will not say how much room it has is not refused")
    func unknownRoom() throws {
        // `TempSpace.check`'s rule: the check is a courtesy, the write is the
        // authority. A path that does not exist reports no capacity.
        let plan = try ImportPlan.make(
            record: ImportTests.record(titles: ["A"]),
            destination: URL(fileURLWithPath: "/tmp/rips"), format: .flac,
            exists: { _ in false })
        let nowhere = URL(fileURLWithPath: "/nonexistent-volume-\(UUID().uuidString)")
        #expect(throws: Never.self) { try plan.checkRoom(in: nowhere) }
    }

    // MARK: - Formats

    @Test("every format names an extension and a codec")
    func formats() {
        for format in ImportFormat.allCases {
            #expect(!format.fileExtension.isEmpty)
            #expect(!format.codecArguments.isEmpty)
            #expect(!format.label.isEmpty)
        }
        #expect(ImportOptions().format == .flac)
    }

    @Test("AIFF is written big-endian")
    func aiffEndianness() {
        // ffmpeg will happily write a little-endian AIFF-C if asked. A CDDA
        // mount hands over `pcm_s16be`, so this is also the case where nothing
        // is re-encoded at all.
        #expect(ImportFormat.aiff.codecArguments.contains("pcm_s16be"))
        #expect(ImportFormat.wav.codecArguments.contains("pcm_s16le"))
    }

    @Test("only the containers that really carry a cover claim to")
    func coverSupport() {
        #expect(ImportFormat.flac.takesCoverArt)
        #expect(ImportFormat.alac.takesCoverArt)
        #expect(ImportFormat.mp3.takesCoverArt)
        // Opus is the one worth asserting: ffmpeg's ogg muxer writes no
        // picture and says nothing about it, which is worse than declining.
        #expect(!ImportFormat.opus.takesCoverArt)
        #expect(!ImportFormat.wav.takesCoverArt)
        #expect(!ImportFormat.aiff.takesCoverArt)
    }

    @Test("only the two lossy formats need a library that may be absent")
    func libraries() {
        #expect(ImportFormat.mp3.library == "libmp3lame")
        #expect(ImportFormat.opus.library == "libopus")
        for format in [ImportFormat.flac, .alac, .aiff, .wav] {
            #expect(format.library == nil)
        }
    }

    // MARK: - The command line

    static func job(format: ImportFormat, sleeve: URL? = nil, embed: Bool = true) throws
        -> (ImportJob, ImportPlan.Entry)
    {
        let plan = try ImportPlan.make(
            record: ImportTests.record(titles: ["Let It Rock", "Wanted"]),
            destination: URL(fileURLWithPath: "/tmp/rips"), format: format,
            exists: { _ in false })
        let job = ImportJob(
            plan: plan, options: ImportOptions(format: format, sleeve: embed), sleeve: sleeve)
        return (job, plan.entries[0])
    }

    @Test("the source's own tags are discarded before ours are written")
    func metadataIsOurs() throws {
        // The rule this keeps: what the panel says is what goes in the file.
        // Without `-map_metadata -1` a corrected record (D85) could land still
        // carrying the file's wrong tags in the fields we had nothing to say
        // about.
        let (job, entry) = try ImportTests.job(format: .flac)
        let arguments = job.arguments(for: entry, cover: nil)
        let at = try #require(arguments.firstIndex(of: "-map_metadata"))
        #expect(arguments[at + 1] == "-1")
        // And it comes before the tags, or it would erase them.
        let firstTag = try #require(arguments.firstIndex(of: "-metadata"))
        #expect(at < firstTag)
    }

    @Test("the first audio stream, and only it")
    func mapsOneStream() throws {
        // A source with cover art in it is a source with a video stream in it.
        let (job, entry) = try ImportTests.job(format: .flac)
        let arguments = job.arguments(for: entry, cover: nil)
        let at = try #require(arguments.firstIndex(of: "-map"))
        #expect(arguments[at + 1] == "a:0")
        #expect(!arguments.contains("0:a"))
    }

    @Test("the track tag carries the total, and disc is left off a single disc")
    func trackTag() throws {
        let (job, entry) = try ImportTests.job(format: .flac)
        let tags = job.metadata(for: entry)
        #expect(tags.contains("track=1/2"))
        #expect(tags.contains("album=Slippery When Wet"))
        #expect(tags.contains("album_artist=Bon Jovi"))
        #expect(tags.contains("date=1986"))
        #expect(!tags.contains { $0.hasPrefix("disc=") })
    }

    @Test("an empty tag is not written as an empty tag")
    func emptyTags() throws {
        let plan = try ImportPlan.make(
            record: ImportTests.record(titles: ["A"], album: "", artist: ""),
            destination: URL(fileURLWithPath: "/tmp/rips"), format: .flac,
            exists: { _ in false })
        let job = ImportJob(plan: plan, options: ImportOptions())
        let tags = job.metadata(for: plan.entries[0])
        // `album=` would be a field that exists and is blank, which reads
        // differently from a field that was never written.
        #expect(!tags.contains { $0 == "album=" || $0 == "album_artist=" || $0 == "date=" })
    }

    @Test("a track with no artist of its own falls back to the record's")
    func compilationArtists() throws {
        let (job, entry) = try ImportTests.job(format: .flac)
        #expect(job.metadata(for: entry).contains("artist=Bon Jovi"))
    }

    @Test("the cover is a second input, copied and marked attached")
    func coverArguments() throws {
        let cover = URL(fileURLWithPath: "/tmp/cover.jpg")
        let (job, entry) = try ImportTests.job(format: .flac, sleeve: cover)
        let arguments = job.arguments(for: entry, cover: cover)
        #expect(arguments.contains("attached_pic"))
        #expect(arguments.contains("1:v:0"))
        // Copied and not re-encoded: the cache holds JPEG and every container
        // that takes a picture here takes it as it stands.
        let at = try #require(arguments.firstIndex(of: "-c:v"))
        #expect(arguments[at + 1] == "copy")
    }

    @Test("no cover is offered to a container that cannot hold one")
    func coverDeclined() throws {
        let cover = URL(fileURLWithPath: "/tmp/cover.jpg")
        for format in [ImportFormat.opus, .wav, .aiff] {
            let (job, _) = try ImportTests.job(format: format, sleeve: cover)
            #expect(job.coverToEmbed() == nil)
        }
    }

    @Test("a cover that is not on disk is not passed to ffmpeg")
    func coverMissing() throws {
        let (job, _) = try ImportTests.job(
            format: .flac, sleeve: URL(fileURLWithPath: "/nope/\(UUID().uuidString).jpg"))
        #expect(job.coverToEmbed() == nil)
    }

    @Test("the sleeve is not embedded when it was not asked for")
    func coverNotWanted() throws {
        let (job, _) = try ImportTests.job(
            format: .flac, sleeve: URL(fileURLWithPath: "/tmp/cover.jpg"), embed: false)
        #expect(job.coverToEmbed() == nil)
    }

    // MARK: - Progress

    @Test("out_time is what is parsed, and out_time_ms is the trap")
    func progressParsing() {
        #expect(Ticker.seconds("out_time=00:02:14.960000") == 134.96)
        #expect(Ticker.seconds("out_time=01:00:00.000000") == 3600)
        // `out_time_ms` holds microseconds despite its name, and anything
        // dividing it by a thousand is a thousand times wrong. Not parsed.
        #expect(Ticker.seconds("out_time_ms=134960000") == nil)
        // The first block, before any frame has been written.
        #expect(Ticker.seconds("out_time=N/A") == nil)
        #expect(Ticker.seconds("progress=continue") == nil)
        #expect(Ticker.seconds("") == nil)
    }

    @Test("a line split across two reads is still one line")
    func progressSplit() {
        // A read off a pipe lands wherever it lands. This is the whole reason
        // the ticker keeps a tail.
        var seen: [Double] = []
        let ticker = Ticker { seen.append($0) }
        ticker.feed("out_time=00:00:0")
        #expect(seen.isEmpty)
        ticker.feed("1.000000\nprogress=continue\n")
        #expect(seen == [1.0])
    }

    @Test("the last partial line is not lost when the child goes")
    func progressDrain() {
        var seen: [Double] = []
        let ticker = Ticker { seen.append($0) }
        ticker.feed("out_time=00:00:02.000000")
        #expect(seen.isEmpty)
        ticker.drain()
        #expect(seen == [2.0])
    }

    @Test("the head is clamped at both ends of the strip")
    func head() {
        let units = PanelGrid.stripWidth * Meter.unitsPerCell
        #expect(ImportStage.head(seconds: 0, runtime: 100) == 0)
        #expect(ImportStage.head(seconds: -5, runtime: 100) == 0)
        // ffmpeg can report a few milliseconds past the duration §3 rounded up.
        #expect(ImportStage.head(seconds: 101, runtime: 100) == units)
        #expect(ImportStage.head(seconds: 50, runtime: 100) == units / 2)
        // A record with no runtime cannot divide by it.
        #expect(ImportStage.head(seconds: 5, runtime: 0) == 0)
    }

    // MARK: - What the screen says

    @Test("the summary names the format, because that is the result")
    func summary() {
        let line = ImportStage.summary(
            written: 13, of: 13, format: .flac, runtime: 2661, elapsed: 188)
        #expect(line.contains("13 TRACKS"))
        #expect(line.contains("FLAC"))
        // Only when they differ — `13 OF 13` is a machine talking.
        #expect(!line.contains("NOT IMPORTED"))
        let short = ImportStage.summary(
            written: 12, of: 13, format: .flac, runtime: 2400, elapsed: 180)
        #expect(short.contains("1 NOT IMPORTED"))
        #expect(ImportStage.summary(written: 1, of: 1, format: .mp3, runtime: 60, elapsed: 4)
            .contains("1 TRACK ·"))
    }

    @Test("cancel is offered for the whole run, unlike a burn")
    func cancellable() {
        // The difference that matters: an import leaves no coaster, so the key
        // is live throughout and really does undo it.
        for stage in [
            ImportStage.preparing(into: "x"),
            ImportStage.importing(track: 1, ofTracks: 2, title: "A", head: 0),
        ] {
            #expect(stage.keys.first?.first?.label == "CANCEL")
        }
        // `Q` stays last, where the hand already looks for it, so the finished
        // legend reads REVEAL then DONE.
        let done = ImportStage.done(summary: "x", written: 2, folder: "y")
        #expect(done.keys.first?.map(\.label) == ["REVEAL", "DONE"])
        #expect(done.keys.first?.last?.presses == [.quit])
        // Nothing to reveal when nothing landed, and then `DONE` is the row.
        let empty = ImportStage.done(summary: "CANCELLED", written: 0, folder: "")
        #expect(empty.keys.first?.map(\.label) == ["DONE"])
    }

    // MARK: - The menu, saved

    @Test("the format survives a relaunch and the defaults stand without one")
    func optionsRoundTrip() throws {
        let store = try #require(UserDefaults(suiteName: "muthur.test.\(UUID().uuidString)"))
        defer { store.removePersistentDomain(forName: store.description) }

        #expect(ImportOptions.load(from: store, environment: [:]) == ImportOptions())
        var options = ImportOptions(format: .alac, sleeve: false)
        options.save(to: store)
        let back = ImportOptions.load(from: store, environment: [:])
        #expect(back.format == .alac)
        #expect(back.sleeve == false)
        #expect(back.folder == .album)
        #expect(back.trackStyle == .dash)
    }

    @Test("a variable beats what was saved, and is not written back")
    func environmentWins() throws {
        let store = try #require(UserDefaults(suiteName: "muthur.test.\(UUID().uuidString)"))
        defer { store.removePersistentDomain(forName: store.description) }
        ImportOptions(format: .alac).save(to: store)

        let named = ImportOptions.load(
            from: store, environment: ["MUTHUR_IMPORT_FORMAT": "opus"])
        #expect(named.format == .opus)
        // Still ALAC underneath — a variable exported in a shell profile that
        // silently became the saved setting would be a preference nobody chose.
        #expect(ImportOptions.load(from: store, environment: [:]).format == .alac)
        // A name this build has never heard of leaves the saved one alone.
        #expect(
            ImportOptions.load(from: store, environment: ["MUTHUR_IMPORT_FORMAT": "wma"])
                .format == .alac)
    }

    @Test("a settings blob from a version with fewer switches still decodes")
    func forwardCompatible() throws {
        // Only `format`, as an older build would have written it.
        let data = try #require(#"{"format":"opus"}"#.data(using: .utf8))
        let options = try JSONDecoder().decode(ImportOptions.self, from: data)
        #expect(options.format == .opus)
        #expect(options.sleeve)
        #expect(options.folder == .album)
        #expect(options.trackStyle == .dash)
        #expect(!options.ejectWhenDone)
    }

    @Test("a format this build has never heard of falls back rather than refusing")
    func unknownFormat() throws {
        let data = try #require(#"{"format":"wma","sleeve":false}"#.data(using: .utf8))
        let options = try JSONDecoder().decode(ImportOptions.self, from: data)
        // The whole set is kept and only the unreadable field defaults, which
        // is the point of decoding field by field.
        #expect(options.format == .flac)
        #expect(!options.sleeve)
    }
}
