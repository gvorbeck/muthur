import Foundation
import Testing

@testable import MUTHURKit

/// §20 stage 2, material tier — the conversion, really run.
///
/// **`-n` and `--demo` are the way in.** The script's own conversion path has
/// always been worked on through `--demo`, and here it is the only way it can
/// be: the drive is stage 3 and there is nothing in the machine to burn to. So
/// these tests do exactly what `--demo` does — build every disc, image and cue
/// into a scratch directory and stop — and then read the results back with the
/// same ffmpeg that wrote them.
///
/// The material is synthesised rather than borrowed. A record is whatever
/// mixture of formats somebody's shelf actually is, and lavfi can make one of
/// those in a tenth of a second without needing anybody's music library to be
/// present.
@Suite("§20 stage 2 — conversion", .enabled(if: Fixtures.locate("ffmpeg") != nil))
struct BurnConversionTests {

    static let ffmpeg = Fixtures.locate("ffmpeg")
    static let ffprobe = Fixtures.locate("ffprobe")

    // MARK: - Making a shelf

    /// A directory that cleans up after itself, standing in for §2's scratch.
    final class Work {
        let url: URL
        init() throws {
            url = FileManager.default.temporaryDirectory
                .appending(path: "muthur-burn-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        deinit { try? FileManager.default.removeItem(at: url) }
    }

    /// One synthetic track. `codec` and `rate` vary on purpose: mixed input
    /// formats are not an edge case, they are what a folder of music is.
    @discardableResult
    static func make(
        _ name: String, in work: URL,
        seconds: Double = 2, frequency: Int = 440, rate: Int = 44100,
        codec: [String], level: String? = nil
    ) throws -> URL {
        let url = work.appending(path: name)
        var filters = ["aformat=sample_fmts=fltp"]
        if let level { filters.append("volume=\(level)") }
        let arguments =
            [
                "-nostdin", "-v", "error", "-y",
                "-f", "lavfi",
                "-i", "sine=frequency=\(frequency):duration=\(seconds):sample_rate=\(rate)",
                "-af", filters.joined(separator: ","),
                "-ac", "2",
            ] + codec + [url.path]
        let result = Tooling.run(try #require(ffmpeg), arguments)
        try #require(result?.status == 0, "could not synthesise \(name)")
        return url
    }

    /// A silent source, which is the only way to prove the dither is real.
    @discardableResult
    static func silence(_ name: String, in work: URL, seconds: Double = 1) throws -> URL {
        let url = work.appending(path: name)
        let result = Tooling.run(
            try #require(ffmpeg),
            [
                "-nostdin", "-v", "error", "-y",
                "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo",
                "-t", String(seconds), "-c:a", "pcm_s24le", url.path,
            ]
        )
        try #require(result?.status == 0)
        return url
    }

    static func draft(_ names: [String], durations: [Int]) -> PlanDraft {
        PlanDraft(
            rows: names.enumerated().map { index, name in
                PlanDraft.Row(
                    title: name, artist: "The Somebodies", duration: durations[index]
                )
            },
            order: Array(names.indices),
            album: "A Test Record", albumArtist: "The Somebodies", year: "1979",
            orderedByFilename: false
        )
    }

    /// What ffprobe says one stream is, as `key=value` lines.
    static func probe(_ url: URL) throws -> [String: String] {
        let result = Tooling.run(
            try #require(ffprobe),
            [
                "-v", "error", "-select_streams", "a:0",
                "-show_entries", "stream=sample_rate,channels,sample_fmt,codec_name",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1", url.path,
            ]
        )
        var fields: [String: String] = [:]
        for line in (result?.output ?? "").split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { fields[String(parts[0])] = String(parts[1]) }
        }
        return fields
    }

    // MARK: - -n

    /// `-n` stops after the plan (`burncd:1380`): everything that can be
    /// *said* about the burn, and then nothing on disk.
    @Test("-n builds the plan and writes nothing")
    func dryRun() throws {
        let work = try Work()
        let files = [
            try Self.make("a.flac", in: work.url, codec: ["-c:a", "flac"]),
            try Self.make("b.flac", in: work.url, codec: ["-c:a", "flac"]),
        ]
        let job = BurnJob(
            draft: Self.draft(["One", "Two"], durations: [200, 300]),
            files: files, work: work.url, stop: .afterPlan
        )

        let outcome = try job.run(ffmpeg: Self.ffmpeg)
        #expect(outcome.plan.discCount == 1)
        #expect(outcome.plan.entries.count == 2)
        #expect(outcome.discs.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: job.imageURL(disc: 1).path))
        #expect(!FileManager.default.fileExists(atPath: job.cueURL(disc: 1).path))
    }

    /// The names are settled even when nothing will be written, because the
    /// shedding ladder is something `-n` is *for*: a record whose titles will
    /// not fit in the lead-in should say so while there is still time.
    @Test("-n still measures the lead-in")
    func dryRunSheds() throws {
        let work = try Work()
        let files = [try Self.make("a.flac", in: work.url, codec: ["-c:a", "flac"])]
        // A title long enough to be approximated into ISO-8859-1 and said so.
        var draft = Self.draft(["Καλημέρα"], durations: [200])
        draft.album = "Καλημέρα"
        let job = BurnJob(draft: draft, files: files, work: work.url, stop: .afterPlan)

        let outcome = try job.run(ffmpeg: Self.ffmpeg)
        #expect(outcome.notes.contains { $0.contains("approximated") })
    }

    // MARK: - --demo

    /// The whole of stage 2, end to end, on a folder of four different
    /// formats at four different sample rates — which is not an edge case,
    /// it is what a shelf is.
    @Test("--demo converts mixed formats into one continuous image")
    func demo() throws {
        let work = try Work()
        let files = [
            try Self.make("a.flac", in: work.url, rate: 48000, codec: ["-c:a", "flac"]),
            try Self.make("b.wav", in: work.url, rate: 96000, codec: ["-c:a", "pcm_s24le"]),
            try Self.make("c.mp3", in: work.url, rate: 44100, codec: ["-c:a", "libmp3lame"]),
            try Self.make("d.aiff", in: work.url, rate: 22050, codec: ["-c:a", "pcm_s16be"]),
        ]
        let job = BurnJob(
            draft: Self.draft(["One", "Two", "Three", "Four"], durations: [2, 2, 2, 2]),
            files: files, work: work.url, stop: .afterBuilding
        )

        let outcome = try job.run(ffmpeg: Self.ffmpeg)
        let disc = try #require(outcome.discs.first)
        #expect(outcome.discs.count == 1)
        #expect(disc.starts.count == 4)

        // One image, and it is a Red Book WAV.
        let stream = try Self.probe(disc.image)
        #expect(stream["sample_rate"] == "44100")
        #expect(stream["channels"] == "2")
        #expect(stream["codec_name"] == "pcm_s16le")

        // Sector-aligned throughout, which is what makes the index marks exact.
        let bytes = try #require(
            try FileManager.default.attributesOfItem(atPath: disc.image.path)[.size] as? Int
        )
        #expect(bytes == disc.bytes)
        #expect((bytes - DiscImage.headerBytes) % BurnLimits.sector == 0)
        #expect(disc.starts == disc.starts.sorted())
        #expect(disc.starts.first == 0)

        // Eight seconds of audio went in; eight seconds came out, give or take
        // the sector each track is rounded up to.
        let seconds = Double(bytes - DiscImage.headerBytes) / Double(BurnLimits.bytesPerSecond)
        #expect(seconds > 7.9 && seconds < 8.2)
    }

    /// **The gap is not a flag that was turned off.** There is nowhere for one
    /// to be: a track boundary is an index mark in one continuous stream, so
    /// each start is exactly where the last track ended.
    @Test("Track boundaries are index marks in one stream, with nothing between")
    func gapless() throws {
        let work = try Work()
        let files = try (0..<3).map {
            try Self.make("t\($0).flac", in: work.url, seconds: 1.5, codec: ["-c:a", "flac"])
        }
        let job = BurnJob(
            draft: Self.draft(["One", "Two", "Three"], durations: [2, 2, 2]),
            files: files, work: work.url, stop: .afterBuilding
        )
        let disc = try #require(try job.run(ffmpeg: Self.ffmpeg).discs.first)

        // A second and a half is 112.5 sectors, so each track is padded by half
        // a sector — and the next one starts on the very next sector, not one
        // beyond it.
        #expect(disc.starts == [0, 113, 226])
        let total = (disc.bytes - DiscImage.headerBytes) / BurnLimits.sector
        #expect(total == 339)
    }

    /// **ffmpeg does not dither by default**, and the difference is not
    /// theoretical: digital silence truncated to 16-bit is all zeros, and
    /// digital silence *dithered* to 16-bit is noise. If the image of a silent
    /// track has anything in it at all, the dither the README calls out as
    /// deliberate is genuinely being applied.
    @Test("The dither is real, and silence proves it")
    func ditherIsApplied() throws {
        let work = try Work()
        let files = [try Self.silence("quiet.wav", in: work.url)]
        let job = BurnJob(
            draft: Self.draft(["Silence"], durations: [1]),
            files: files, work: work.url, stop: .afterBuilding
        )
        let disc = try #require(try job.run(ffmpeg: Self.ffmpeg).discs.first)

        let image = try Data(contentsOf: disc.image)
        let audio = image.dropFirst(DiscImage.headerBytes)
        #expect(audio.contains { $0 != 0 })

        // And it is dither and not signal: a handful of bits at the bottom,
        // nowhere near anything audible. Asserted as "small" rather than as a
        // particular level, because the exact noise a triangular PDF produces
        // is ffmpeg's business and not this port's to pin down.
        let samples = stride(from: 0, to: audio.count - 1, by: 2).map { offset -> Int in
            let index = audio.startIndex + offset
            return Int(Int16(bitPattern: UInt16(audio[index]) | UInt16(audio[index + 1]) << 8))
        }
        #expect(samples.allSatisfy { abs($0) < 8 })
    }

    // MARK: - The cue

    /// The cue sheet's index marks are the image's track starts, and there is
    /// only one place either of them comes from.
    @Test("The cue sheet points into the image it was written beside")
    func cue() throws {
        let work = try Work()
        let files = try (0..<2).map {
            try Self.make("t\($0).flac", in: work.url, codec: ["-c:a", "flac"])
        }
        let job = BurnJob(
            draft: Self.draft(["First Thing", "Second Thing"], durations: [2, 2]),
            files: files, work: work.url, stop: .afterBuilding
        )
        let disc = try #require(try job.run(ffmpeg: Self.ffmpeg).discs.first)

        let cue = try String(contentsOf: disc.cue, encoding: .isoLatin1)
        #expect(cue.contains("REM DATE 1979"))
        #expect(cue.contains("PERFORMER \"The Somebodies\""))
        #expect(cue.contains("TITLE \"A Test Record\""))
        #expect(cue.contains("FILE \"disc1.wav\" WAVE"))
        #expect(cue.contains("    TITLE \"First Thing\""))
        for (index, start) in disc.starts.enumerated() {
            #expect(cue.contains("  TRACK 0\(index + 1) AUDIO"))
            #expect(cue.contains("    INDEX 01 \(DiscImage.msf(sectors: start))"))
        }
    }

    /// Two discs are two images and two cue sheets, each naming its own.
    @Test("A record that needs two discs builds two of everything")
    func twoDiscs() throws {
        let work = try Work()
        let files = try (0..<2).map {
            try Self.make("t\($0).flac", in: work.url, codec: ["-c:a", "flac"])
        }
        // Two tracks that cannot share a disc: the layout is the plan's
        // business (§20.2) and this only checks that stage 2 follows it.
        var draft = Self.draft(["One", "Two"], durations: [3000, 3000])
        draft.breaks = [1]
        let job = BurnJob(draft: draft, files: files, work: work.url, stop: .afterBuilding)

        let outcome = try job.run(ffmpeg: Self.ffmpeg)
        #expect(outcome.discs.count == 2)
        #expect(outcome.discs.map(\.number) == [1, 2])
        for disc in outcome.discs {
            #expect(FileManager.default.fileExists(atPath: disc.image.path))
            let cue = try String(contentsOf: disc.cue, encoding: .isoLatin1)
            #expect(cue.contains("FILE \"disc\(disc.number).wav\" WAVE"))
            #expect(disc.starts == [0])
        }
    }

    // MARK: - The level

    /// The gain is applied, in float, ahead of the dither — and the proof is
    /// that the image comes back louder than the record went in.
    @Test("A quiet record is raised, and only as far as it said it would be")
    func level() throws {
        let work = try Work()
        // Twenty dB down: quiet enough that the loudness target, not the
        // ceiling, is what stops it.
        let files = [
            try Self.make(
                "quiet.flac", in: work.url, seconds: 4,
                codec: ["-c:a", "flac"], level: "-20dB"
            )
        ]
        var job = BurnJob(
            draft: Self.draft(["Quiet"], durations: [4]),
            files: files, work: work.url, stop: .afterBuilding
        )
        job.level = .album

        var cache = LevelCache(at: nil)
        let outcome = try job.run(
            ffmpeg: Self.ffmpeg,
            measure: LevelPass.ffmpegMeasure(try #require(Self.ffmpeg)),
            cache: cache
        )
        _ = cache

        let note = try #require(outcome.level.note)
        #expect(note.hasPrefix("Level: +"))
        #expect(outcome.level.albumGain > 0)

        // Measured back off the image with the same tool that measured the
        // source: whatever gain the plan promised is the gain the audio got.
        let before = try LevelPass.ffmpegMeasure(try #require(Self.ffmpeg))(files[0])
        let after = try LevelPass.ffmpegMeasure(try #require(Self.ffmpeg))(
            try #require(outcome.discs.first).image
        )
        #expect(abs((after.lufs - before.lufs) - outcome.level.albumGain) < 0.5)
    }

    /// Off is off: no filter, no gain, and an image identical to the one the
    /// plain conversion makes.
    @Test("Level off changes nothing at all")
    func levelOff() throws {
        let work = try Work()
        let files = [
            try Self.make(
                "quiet.flac", in: work.url, seconds: 2,
                codec: ["-c:a", "flac"], level: "-20dB"
            )
        ]
        let job = BurnJob(
            draft: Self.draft(["Quiet"], durations: [2]),
            files: files, work: work.url, stop: .afterBuilding
        )
        let outcome = try job.run(ffmpeg: Self.ffmpeg)
        #expect(outcome.level.note == nil)
        #expect(outcome.level.gain(for: outcome.plan.entries[0]) == "0.0")

        let source = try LevelPass.ffmpegMeasure(try #require(Self.ffmpeg))(files[0])
        let image = try LevelPass.ffmpegMeasure(try #require(Self.ffmpeg))(
            try #require(outcome.discs.first).image
        )
        #expect(abs(image.lufs - source.lufs) < 0.5)
    }

    /// ffmpeg says what the port expects it to say. The parser is anchored on
    /// two lines of a summary block, and this is the check that those two lines
    /// are still shaped the way they were when it was written.
    @Test("ebur128 still prints the two lines the parser is anchored on")
    func measurement() throws {
        let work = try Work()
        let file = try Self.make(
            "tone.flac", in: work.url, seconds: 3, codec: ["-c:a", "flac"], level: "-6dB"
        )
        let reading = try LevelPass.ffmpegMeasure(try #require(Self.ffmpeg))(file)
        // What this asserts is that both lines were found: a reading that fell
        // through to the -70 floor is an anchor that stopped matching, which is
        // the only failure this test exists to catch. The dBFS a lavfi sine
        // actually arrives at is ffmpeg's business — it is not the amplitude
        // anybody would guess, and it has no promise attached to it — so the
        // window is only "louder than silence, not above full scale".
        #expect(reading.lufs > Loudness.floor && reading.lufs < 0)
        #expect(reading.peak > Loudness.floor && reading.peak <= 0)
    }

    /// A file ffmpeg cannot decode fails loudly, with what ffmpeg said about it
    /// — which is what the log is for (`burncd:2534`).
    @Test("A file that will not convert says why")
    func badFile() throws {
        let work = try Work()
        let broken = work.url.appending(path: "broken.flac")
        try Data("this is not a flac".utf8).write(to: broken)

        let job = BurnJob(
            draft: Self.draft(["Broken"], durations: [2]),
            files: [broken], work: work.url, stop: .afterBuilding
        )
        #expect(throws: Converter.Failure.self) {
            try job.run(ffmpeg: Self.ffmpeg)
        }
        // And the log is on disk beside the image, which is where the error
        // message came from.
        #expect(FileManager.default.fileExists(atPath: job.logURL(disc: 1).path))
    }

    // MARK: - The whole thing, with the drive taken out

    /// **§20 stage 3a, end to end.** Four files on disk, through the plan, the
    /// level pass, the conversion, the image, the cue sheet and the burn panel,
    /// to a disc that reports itself written — with nothing in the machine to
    /// burn to and nothing spawned.
    ///
    /// This is the test the stage exists to make possible. What it does not
    /// cover is the one thing left: a drive that answers. When that arrives it
    /// arrives as a different value for `drive:` on this same call.
    @Test("A record goes from a folder to a finished burn screen")
    func demoBurn() throws {
        let work = try Work()
        let files = [
            try Self.make("a.flac", in: work.url, codec: ["-c:a", "flac"]),
            try Self.make("b.wav", in: work.url, codec: ["-c:a", "pcm_s16le"]),
            try Self.make("c.mp3", in: work.url, codec: ["-c:a", "libmp3lame"]),
        ]
        let job = BurnJob(
            draft: Self.draft(["One", "Two", "Three"], durations: [2, 2, 2]),
            files: files, work: work.url, stop: .afterDemoBurn
        )

        var frames = 0
        var phases: [BurnPanel.Phase] = []
        let outcome = try job.run(
            ffmpeg: Self.ffmpeg,
            frame: { panel in
                frames += 1
                if phases.last != panel.phase { phases.append(panel.phase) }
            })

        #expect(outcome.discs.count == 1)
        let burn = try #require(outcome.burns.first)
        #expect(outcome.burns.count == 1)
        #expect(frames > 0)
        #expect(phases == [.lead, .write, .tail])

        // The panel is looking at the disc that was actually built.
        #expect(burn.disc == 1)
        #expect(burn.titles == ["One", "Two", "Three"])
        #expect(burn.track == 3)
        #expect(burn.phase == .tail)
        #expect(burn.percent == 100)
        #expect(!burn.cells().contains(.runout))

        // And the log says so, in the words the script uses.
        #expect(outcome.notes.contains("✓ Disc 1 of 1 written"))
    }

    /// The panel's bands are the disc's own tracks, not the record's — which is
    /// the difference that only shows up on a record that needs two discs.
    @Test("Each disc's burn screen is banded with that disc's tracks")
    func demoBurnPerDisc() throws {
        let work = try Work()
        let files = try (1...3).map {
            try Self.make("t\($0).wav", in: work.url, codec: ["-c:a", "pcm_s16le"])
        }
        var draft = Self.draft(["One", "Two", "Three"], durations: [1200, 1200, 600])
        draft.breaks = [2]
        let job = BurnJob(
            draft: draft, files: files, work: work.url, stop: .afterDemoBurn)
        let outcome = try job.run(ffmpeg: Self.ffmpeg)
        #expect(outcome.burns.count == outcome.discs.count)
        #expect(outcome.burns.count > 1)
        for (index, burn) in outcome.burns.enumerated() {
            let entries = outcome.plan.entries(onDisc: index + 1)
            #expect(burn.disc == index + 1)
            #expect(burn.titles == entries.map(\.title))
            #expect(burn.bands == Meter.bands(for: entries.map(\.duration), cells: PanelGrid.stripWidth))
            #expect(burn.phase == .tail)
        }
    }
}
