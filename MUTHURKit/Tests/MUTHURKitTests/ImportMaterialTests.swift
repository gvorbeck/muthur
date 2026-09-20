import Foundation
import Testing

@testable import MUTHURKit

/// §21, material tier — an import that really runs, read back with ffprobe.
///
/// The material is synthesised, for `BurnConversionTests`' reason: a disc is
/// not available on demand and lavfi can make one in a tenth of a second. What
/// stands in for the CDDA mount is a directory of `pcm_s16be` AIFFs at 44.1 kHz
/// stereo, which is byte-for-byte the shape cddafs presents — so everything
/// below is the real path with the drive taken out of it.
///
/// **The assertions are about what landed on disk**, not about what the job
/// said it did. A job that reports thirteen tracks and wrote twelve is the
/// failure this tier exists to catch, and only the filesystem can tell you.
@Suite("§21 — import, really run", .enabled(if: Fixtures.locate("ffmpeg") != nil))
struct ImportMaterialTests {

    static let ffmpeg = Fixtures.locate("ffmpeg")
    static let ffprobe = Fixtures.locate("ffprobe")

    /// A directory that cleans up after itself.
    final class Work {
        let url: URL
        init() throws {
            url = FileManager.default.temporaryDirectory
                .appending(path: "muthur-import-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        deinit { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: - Standing in for a disc

    /// One track as a CDDA mount presents it: 16-bit big-endian, 44.1, stereo.
    @discardableResult
    static func aiff(
        _ name: String, in work: URL, seconds: Double = 1, frequency: Int = 440
    ) throws -> URL {
        let url = work.appending(path: name)
        let result = Tooling.run(
            try #require(ffmpeg),
            [
                "-nostdin", "-v", "error", "-y", "-f", "lavfi",
                "-i", "sine=frequency=\(frequency):duration=\(seconds):sample_rate=44100",
                "-ac", "2", "-c:a", "pcm_s16be", url.path,
            ])
        try #require(result?.status == 0, "could not synthesise \(name)")
        return url
    }

    /// A one-pixel JPEG, for the cover tests. Made by ffmpeg so the suite needs
    /// no binary in the repository.
    static func cover(in work: URL) throws -> URL {
        let url = work.appending(path: "cover.jpg")
        let result = Tooling.run(
            try #require(ffmpeg),
            [
                "-nostdin", "-v", "error", "-y", "-f", "lavfi",
                "-i", "color=c=red:s=64x64:d=1", "-frames:v", "1", url.path,
            ])
        try #require(result?.status == 0)
        return url
    }

    /// A record over those files, with the titles §4 would have written back.
    static func record(
        _ titles: [String], in work: URL, album: String = "Slippery When Wet",
        artist: String = "Bon Jovi", seconds: Double = 1
    ) throws -> Record {
        var tracks: [Track] = []
        for (index, title) in titles.enumerated() {
            // The name macOS gives them, which is also §3's `numberFromFilename`
            // case.
            let url = try aiff(
                "\(index + 1) Audio Track.aiff", in: work,
                seconds: seconds, frequency: 220 * (index + 1))
            tracks.append(
                Track(
                    url: url, duration: Int(seconds.rounded(.up)), title: title,
                    artist: "", number: index + 1, disc: 1))
        }
        return Record(
            tracks: tracks, album: album, albumArtist: artist, year: "1986",
            sourceLabel: "Audio CD", unreadableCount: 0)
    }

    /// One tag, off the file.
    static func tag(_ key: String, of url: URL) throws -> String? {
        let out = Tooling.output(
            try #require(ffprobe),
            [
                "-v", "error", "-show_entries", "format_tags=\(key)",
                "-of", "default=noprint_wrappers=1:nokey=1", url.path,
            ])
        let value = (out ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static func streams(_ url: URL, kind: String) throws -> [String] {
        let out = Tooling.output(
            try #require(ffprobe),
            [
                "-v", "error", "-select_streams", kind, "-show_entries", "stream=codec_name",
                "-of", "default=noprint_wrappers=1:nokey=1", url.path,
            ])
        return (out ?? "").split(separator: "\n").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        .filter { !$0.isEmpty }
    }

    static func run(
        _ record: Record, into destination: URL, options: ImportOptions,
        sleeve: URL? = nil, stop: ImportJob.Stop = ImportJob.Stop()
    ) throws -> ImportJob.Outcome {
        let plan = try ImportPlan.make(
            record: record, destination: destination, format: options.format,
            folderStyle: options.folder, trackStyle: options.trackStyle)
        return try ImportJob(plan: plan, options: options, sleeve: sleeve)
            .run(ffmpeg: ffmpeg, stop: stop)
    }

    // MARK: - The whole thing

    @Test("a record lands as a folder of named, numbered, tagged files")
    func wholeImport() throws {
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(
            ["Let It Rock", "You Give Love a Bad Name"], in: disc)
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let outcome = try ImportMaterialTests.run(
            record, into: out, options: ImportOptions(format: .flac, sleeve: false))

        #expect(outcome.written.count == 2)
        #expect(outcome.skipped.isEmpty)
        #expect(outcome.folder.lastPathComponent == "Slippery When Wet")

        // What is on disk, which is the only thing that counts.
        let landed = try FileManager.default
            .contentsOfDirectory(atPath: outcome.folder.path).sorted()
        #expect(landed == ["01 - Let It Rock.flac", "02 - You Give Love a Bad Name.flac"])

        let first = outcome.folder.appending(path: "01 - Let It Rock.flac")
        #expect(try ImportMaterialTests.tag("title", of: first) == "Let It Rock")
        #expect(try ImportMaterialTests.tag("album", of: first) == "Slippery When Wet")
        #expect(try ImportMaterialTests.tag("album_artist", of: first) == "Bon Jovi")
        #expect(try ImportMaterialTests.tag("date", of: first) == "1986")
        #expect(try ImportMaterialTests.tag("track", of: first) == "1/2")
        #expect(try ImportMaterialTests.streams(first, kind: "a") == ["flac"])
    }

    @Test("a lossless import is bit-identical to what came off the disc")
    func lossless() throws {
        // The claim FLAC is chosen for, put to the machine rather than
        // asserted. Both files are decoded to raw PCM and compared.
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(["Tone"], in: disc, seconds: 2)
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let outcome = try ImportMaterialTests.run(
            record, into: out, options: ImportOptions(format: .flac, sleeve: false))
        let imported = try #require(outcome.written.first)

        func pcm(_ url: URL) throws -> Data {
            let raw = work.url.appending(path: "\(UUID().uuidString).raw")
            let result = Tooling.run(
                try #require(ImportMaterialTests.ffmpeg),
                [
                    "-nostdin", "-v", "error", "-y", "-i", url.path,
                    "-map", "a:0", "-f", "s16le", "-c:a", "pcm_s16le", raw.path,
                ])
            try #require(result?.status == 0)
            return try Data(contentsOf: raw)
        }

        let before = try pcm(record.tracks[0].url)
        let after = try pcm(imported)
        #expect(!before.isEmpty)
        #expect(before == after)
    }

    @Test("the source's own tags do not survive into the import")
    func metadataIsReplaced() throws {
        // `-map_metadata -1` doing its job. The rule: what the panel says is
        // what goes in the file — a corrected record (D85) must not land
        // carrying the file's own wrong tags.
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let source = disc.appending(path: "1 Audio Track.flac")
        let made = Tooling.run(
            try #require(ImportMaterialTests.ffmpeg),
            [
                "-nostdin", "-v", "error", "-y", "-f", "lavfi",
                "-i", "sine=frequency=440:duration=1:sample_rate=44100", "-ac", "2",
                "-metadata", "title=WRONG", "-metadata", "comment=STALE",
                "-metadata", "album=WRONG ALBUM", source.path,
            ])
        try #require(made?.status == 0)
        #expect(try ImportMaterialTests.tag("title", of: source) == "WRONG")

        let record = Record(
            tracks: [
                Track(
                    url: source, duration: 1, title: "Let It Rock", artist: "",
                    number: 1, disc: 1)
            ],
            album: "Slippery When Wet", albumArtist: "Bon Jovi", year: "1986",
            sourceLabel: "x", unreadableCount: 0)
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let outcome = try ImportMaterialTests.run(
            record, into: out, options: ImportOptions(format: .flac, sleeve: false))
        let imported = try #require(outcome.written.first)
        #expect(try ImportMaterialTests.tag("title", of: imported) == "Let It Rock")
        #expect(try ImportMaterialTests.tag("album", of: imported) == "Slippery When Wet")
        // The tag we never wrote is gone rather than carried.
        #expect(try ImportMaterialTests.tag("comment", of: imported) == nil)
    }

    @Test("the sleeve goes in where the container takes one")
    func coverEmbedded() throws {
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(["Tone"], in: disc)
        let art = try ImportMaterialTests.cover(in: work.url)
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let outcome = try ImportMaterialTests.run(
            record, into: out, options: ImportOptions(format: .flac, sleeve: true),
            sleeve: art)
        let imported = try #require(outcome.written.first)
        // A video stream in an audio file is the cover.
        #expect(!(try ImportMaterialTests.streams(imported, kind: "v").isEmpty))
        #expect(try ImportMaterialTests.streams(imported, kind: "a") == ["flac"])
    }

    @Test("a format that cannot hold a cover is written without one, and says so")
    func coverDeclinedAloud() throws {
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(["Tone"], in: disc)
        let art = try ImportMaterialTests.cover(in: work.url)
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let outcome = try ImportMaterialTests.run(
            record, into: out, options: ImportOptions(format: .wav, sleeve: true),
            sleeve: art)
        let imported = try #require(outcome.written.first)
        #expect(try ImportMaterialTests.streams(imported, kind: "v").isEmpty)
        // Somebody who asked for the sleeve and chose a format that cannot hold
        // one is owed the reason.
        #expect(outcome.notes.contains { $0.contains("cannot carry a cover") })
    }

    @Test("a second import of the same record does not overwrite the first")
    func noClobber() throws {
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(["Tone"], in: disc)
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let options = ImportOptions(format: .flac, sleeve: false)

        let first = try ImportMaterialTests.run(record, into: out, options: options)
        let second = try ImportMaterialTests.run(record, into: out, options: options)

        #expect(first.folder.path != second.folder.path)
        #expect(second.folder.lastPathComponent.hasSuffix("(2)"))
        // Both are still there. Losing the first is the thing that is not
        // recoverable in a second.
        #expect(FileManager.default.fileExists(atPath: first.folder.path))
        for url in first.written + second.written {
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("a track that will not read is stepped over, not fatal")
    func badTrack() throws {
        // §6.3's rule applied to writing. The second file is not audio at all.
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        var record = try ImportMaterialTests.record(["Good", "Bad", "Also Good"], in: disc)
        let broken = record.tracks[1].url
        try Data("this is not audio".utf8).write(to: broken)

        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let outcome = try ImportMaterialTests.run(
            record, into: out, options: ImportOptions(format: .flac, sleeve: false))

        #expect(outcome.written.count == 2)
        #expect(outcome.skipped.map(\.number) == [2])
        // The part-written file is swept: a half-track in the folder is
        // indistinguishable from a whole one to everything downstream.
        let landed = try FileManager.default
            .contentsOfDirectory(atPath: outcome.folder.path).sorted()
        #expect(landed == ["01 - Good.flac", "03 - Also Good.flac"])
        #expect(outcome.notes.contains { $0.hasPrefix("✗ 02") })
        _ = record
    }

    @Test("a disc where nothing reads is a failure, not a cheerful zero")
    func nothingReads() throws {
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(["A", "B"], in: disc)
        for track in record.tracks {
            try Data("not audio".utf8).write(to: track.url)
        }
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        #expect(throws: ImportJob.Failure.self) {
            try ImportMaterialTests.run(
                record, into: out, options: ImportOptions(format: .flac, sleeve: false))
        }
        // And the empty folder it made does not stay behind.
        let left = try FileManager.default.contentsOfDirectory(atPath: out.path)
        #expect(left.isEmpty)
    }

    @Test("a cancel takes back everything it wrote")
    func cancelUndoes() throws {
        // The whole justification for the key being live all the way through:
        // an import leaves no coaster, and cancelling really does undo it.
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(["A", "B", "C"], in: disc)
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let stop = ImportJob.Stop()
        stop.ask()

        #expect(throws: ImportJob.Failure.self) {
            try ImportMaterialTests.run(
                record, into: out, options: ImportOptions(format: .flac, sleeve: false),
                stop: stop)
        }
        // Not one byte, and not an empty folder either.
        let left = try FileManager.default.contentsOfDirectory(atPath: out.path)
        #expect(left.isEmpty)
    }

    @Test("a cancel part-way leaves nothing behind either")
    func cancelMidRun() throws {
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(["A", "B", "C"], in: disc, seconds: 2)
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let plan = try ImportPlan.make(record: record, destination: out, format: .flac)
        let stop = ImportJob.Stop()
        let job = ImportJob(plan: plan, options: ImportOptions(format: .flac, sleeve: false))

        // Asked once the first track has landed, so there is really something
        // on disk to take back.
        #expect(throws: ImportJob.Failure.self) {
            try job.run(
                ffmpeg: ImportMaterialTests.ffmpeg, stop: stop,
                note: { line in if line.hasPrefix("✓") { stop.ask() } })
        }
        let left = try FileManager.default.contentsOfDirectory(atPath: out.path)
        #expect(left.isEmpty)
    }

    @Test("the bar is driven by the seconds converted, and reaches the end")
    func progress() throws {
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(["A", "B"], in: disc, seconds: 2)
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let plan = try ImportPlan.make(record: record, destination: out, format: .flac)
        var heads: [Int] = []
        _ = try ImportJob(plan: plan, options: ImportOptions(format: .flac, sleeve: false))
            .run(
                ffmpeg: ImportMaterialTests.ffmpeg,
                stage: { stage in
                    if case .importing(_, _, _, let head) = stage { heads.append(head) }
                })

        let units = PanelGrid.stripWidth * Meter.unitsPerCell
        #expect(!heads.isEmpty)
        // It only ever goes forward, and never past the end of the strip. Both
        // are the things a bar can get wrong that look like a bug.
        #expect(zip(heads, heads.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(heads.allSatisfy { $0 >= 0 && $0 <= units })
        // And it actually moved — a bar stuck at nought is the failure this
        // whole seam exists to prevent.
        #expect((heads.max() ?? 0) > 0)
    }

    @Test("every format this program offers can really be written")
    func everyFormat() throws {
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(["Tone"], in: disc)

        for format in ImportFormat.allCases {
            // A format whose library this ffmpeg lacks is a skip, not a
            // failure — which is exactly the case `noEncoder` exists for.
            if let library = format.library,
                !ImportJob.hasEncoder(library, ffmpeg: try #require(ImportMaterialTests.ffmpeg))
            {
                continue
            }
            let out = work.url.appending(path: "out-\(format.rawValue)")
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let outcome = try ImportMaterialTests.run(
                record, into: out, options: ImportOptions(format: format, sleeve: false))
            let imported = try #require(outcome.written.first)
            #expect(imported.pathExtension == format.fileExtension)
            // It is a real audio file, and ffprobe will say what is in it.
            #expect(!(try ImportMaterialTests.streams(imported, kind: "a").isEmpty))
            let size = (try FileManager.default.attributesOfItem(atPath: imported.path)[.size]
                as? Int) ?? 0
            #expect(size > 0)
        }
    }

    @Test("a format whose encoder is missing is refused before anything is written")
    func missingEncoder() throws {
        // Asked with a library name no ffmpeg has, which is the same code path
        // a minimal build takes for libmp3lame.
        #expect(
            !ImportJob.hasEncoder(
                "libnothingatall", ffmpeg: try #require(ImportMaterialTests.ffmpeg)))
        #expect(
            ImportJob.hasEncoder("flac", ffmpeg: try #require(ImportMaterialTests.ffmpeg)))
    }

    @Test("without a record folder the files land in the chosen directory")
    func flatImport() throws {
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(["A", "B"], in: disc)
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        // Something already there, which only this setting can happen beside.
        try Data("mine".utf8).write(to: out.appending(path: "notes.txt"))

        let outcome = try ImportMaterialTests.run(
            record, into: out,
            options: ImportOptions(format: .flac, sleeve: false, folder: .none))
        #expect(outcome.folder.path == out.path)
        let landed = try FileManager.default.contentsOfDirectory(atPath: out.path).sorted()
        #expect(landed == ["01 - A.flac", "02 - B.flac", "notes.txt"])
    }

    @Test("a cancel in a directory that was not ours takes only our files")
    func cancelSpares() throws {
        let work = try Work()
        let disc = work.url.appending(path: "disc")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        let record = try ImportMaterialTests.record(["A", "B"], in: disc, seconds: 2)
        let out = work.url.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try Data("mine".utf8).write(to: out.appending(path: "notes.txt"))

        let plan = try ImportPlan.make(
            record: record, destination: out, format: .flac, folderStyle: .none)
        let stop = ImportJob.Stop()
        #expect(throws: ImportJob.Failure.self) {
            try ImportJob(plan: plan, options: ImportOptions(format: .flac, sleeve: false))
                .run(
                    ffmpeg: ImportMaterialTests.ffmpeg, stop: stop,
                    note: { line in if line.hasPrefix("✓") { stop.ask() } })
        }
        // Everything else in that directory belongs to somebody else.
        let left = try FileManager.default.contentsOfDirectory(atPath: out.path)
        #expect(left == ["notes.txt"])
    }
}
