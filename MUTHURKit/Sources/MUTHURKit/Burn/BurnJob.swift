import Foundation

/// §20 stage 2 — the whole of a burn that happens before the drive is involved.
///
/// The script reaches this by flags: `-n` stops after the plan
/// (`burncd:1380`), `--demo` runs every one of these steps and then hands a
/// finished image to a `cdrecord` that is only pretending. There is no command
/// line here to carry either of them, so they are what they always really
/// were — **where the job stops** — and saying so out loud is what makes stage
/// 2 exercisable end to end on a machine with no drive in it. That is not a
/// testing convenience bolted on afterwards; `--demo` is how the script's own
/// conversion path has always been worked on.
///
/// **Stage 3a moved the burn itself inside.** `.afterDemoBurn` runs the panel
/// past a `Drive` that is only pretending, which is what `--demo` has always
/// done — and because the drive is a parameter, the real one arriving is a
/// different argument and not a different `run`. What is still outside is the
/// media check, `--dummy` and `--verify`: those need a disc in a drive, and stay
/// open in §20.
public struct BurnJob: Sendable {

    /// Where the job stops.
    public enum Stop: Sendable, Equatable {
        /// `-n`. The plan, the layout, the level pass and the CD-Text
        /// measurement — everything that can be *said* about the burn — and
        /// then nothing. No file is written and no second of audio is decoded.
        case afterPlan

        /// Every disc converted, imaged and cue'd, in the scratch directory, and
        /// then stop. What is left on disk is exactly what would have been
        /// handed to the burner.
        case afterBuilding

        /// `--demo` in full: build every disc, then run each one past the burn
        /// panel through a drive that is only pretending. Nothing is written to
        /// a blank and nothing is spawned; what it proves is that the pipeline
        /// runs from a folder of files to a finished burn screen without a
        /// hardware gap in the middle (`burncd:2591`).
        case afterDemoBurn
    }

    /// One disc, built.
    public struct Disc: Sendable, Equatable {
        public let number: Int
        public let image: URL
        public let cue: URL
        /// `INDEX 01` per track, in sectors.
        public let starts: [Int]
        /// The names that survived, as §20.3 settled them.
        public let text: DiscText
        /// The image's size on disk, header included.
        public let bytes: Int
    }

    public struct Outcome: Sendable {
        public let plan: BurnPlan
        public let level: LevelDecision
        /// Empty for `.afterPlan`.
        public let discs: [Disc]
        /// The last frame of each disc's burn screen. Empty unless the job ran
        /// to `.afterDemoBurn`.
        public let burns: [BurnPanel]
        /// Everything the job would have said on its way past, in order: the
        /// split note, the level note, each disc's CD-Text shedding. The panel
        /// prints these; the tests read them.
        public let notes: [String]
    }

    public enum Failure: Error, CustomStringConvertible {
        /// The source list and the draft disagree about how many tracks there
        /// are. Not survivable: every index in the plan points into one of them.
        case sourceMismatch(files: Int, rows: Int)

        public var description: String {
            switch self {
            case .sourceMismatch(let files, let rows):
                "\(files) files for \(rows) rows — the plan and the record disagree"
            }
        }
    }

    // MARK: - The job

    /// The running order and the names, as the editor left them.
    public var draft: PlanDraft

    /// One file per `draft.rows` entry, in the same order. Kept beside the
    /// draft rather than in it because a `PlanDraft` deliberately holds no
    /// files: the editor renames and reorders, and nothing on that screen is
    /// allowed to be a path.
    public var files: [URL]

    /// Where the images and cue sheets land — §2's scratch directory, which
    /// already sweeps itself.
    public var work: URL

    public var stop: Stop
    public var splitLong: Bool
    public var cdText: Bool
    public var level: LevelMode
    public var targets: LevelTargets

    public init(
        draft: PlanDraft,
        files: [URL],
        work: URL,
        stop: Stop,
        splitLong: Bool = false,
        cdText: Bool = true,
        level: LevelMode = .off,
        targets: LevelTargets = LevelTargets()
    ) {
        self.draft = draft
        self.files = files
        self.work = work
        self.stop = stop
        self.splitLong = splitLong
        self.cdText = cdText
        self.level = level
        self.targets = targets
    }

    /// `disc1.wav`, `disc1.cue`, `ffmpeg-1.log` (`burncd:2459`).
    public func imageURL(disc: Int) -> URL { work.appending(path: "disc\(disc).wav") }
    public func cueURL(disc: Int) -> URL { work.appending(path: "disc\(disc).cue") }
    public func logURL(disc: Int) -> URL { work.appending(path: "ffmpeg-\(disc).log") }

    /// Build as far as `stop` says.
    ///
    /// `measure` and `ffmpeg` are handed in rather than located here so a
    /// caller can run the arithmetic without a decoder, and so every test that
    /// is not about ffmpeg still runs on a machine without it. `nil` for either
    /// is only an error if the job actually needs it: `-n` on an unlevelled
    /// record needs neither.
    public func run(
        ffmpeg: URL? = nil,
        measure: LevelPass.Measure? = nil,
        cache: LevelCache? = nil,
        drive: Drive = FakeDrive(),
        frame: (BurnPanel) -> Void = { _ in },
        note: (String) -> Void = { _ in }
    ) throws -> Outcome {
        guard files.count == draft.rows.count else {
            throw Failure.sourceMismatch(files: files.count, rows: draft.rows.count)
        }

        var notes: [String] = []
        func say(_ line: String) {
            notes.append(line)
            note(line)
        }

        let plan = try BurnPlan.make(draft: draft, splitLong: splitLong)
        for line in plan.splitNotes { say(line) }

        // The loudness pass runs against the *source* files and before the
        // layout matters, because a measurement belongs to a file and not to a
        // position: reordering the record, or cutting a track in half across
        // two discs, must not cost a second decode. Only the album gain is
        // derived from the playlist, and that is arithmetic (`replan`,
        // `burncd:735`).
        var readings: [Loudness] = []
        if level != .off {
            guard let measure = measure ?? ffmpeg.map(LevelPass.ffmpegMeasure) else {
                throw LevelPass.Failure.noFFmpeg
            }
            var store = cache ?? LevelCache(at: LevelCache.location())
            readings = try LevelPass.run(
                files: files, cache: &store, measure: measure, note: say
            ).readings
        }
        let decision = LevelDecision.make(
            mode: level, targets: targets, readings: readings, entries: plan.entries
        )
        if let line = decision.note { say(line) }

        // The names are settled for every disc even when nothing will be
        // written, because the shedding ladder is something `-n` is *for*: a
        // record whose titles will not fit in the lead-in should say so while
        // there is still time to shorten one.
        var texts: [DiscText] = []
        for disc in 1...max(1, plan.discCount) {
            let text = DiscText.make(
                disc: disc,
                entries: plan.entries(onDisc: disc),
                album: draft.album,
                albumArtist: draft.albumArtist,
                year: draft.year,
                enabled: cdText
            )
            texts.append(text)
            for line in text.notes { say(line) }
        }

        guard stop != .afterPlan else {
            return Outcome(plan: plan, level: decision, discs: [], burns: [], notes: notes)
        }

        guard let ffmpeg else { throw Converter.Failure.noFFmpeg }

        var discs: [Disc] = []
        for disc in 1...max(1, plan.discCount) {
            discs.append(
                try build(
                    disc: disc, plan: plan, text: texts[disc - 1],
                    level: decision, ffmpeg: ffmpeg, note: say
                )
            )
        }
        guard stop == .afterDemoBurn else {
            return Outcome(plan: plan, level: decision, discs: discs, burns: [], notes: notes)
        }

        // The burn, with a drive that is pretending. Everything from here on is
        // exactly what a real one does: the same vector built, the same panel
        // filled, the same note written into the log when the disc is done.
        let (speed, speedNote) = Cdrecord.speed()
        if let speedNote { say(speedNote) }
        let device = OpticalDrive.detect().device

        var burns: [BurnPanel] = []
        for disc in discs {
            let entries = plan.entries(onDisc: disc.number)
            var panel = BurnPanel(
                disc: disc.number,
                of: plan.discCount,
                titles: entries.map(\.title),
                durations: entries.map(\.duration),
                totalMegabytes: drive.totalMegabytes(
                    bytes: disc.bytes, tracks: entries.count)
            )
            try drive.write(
                Cdrecord.write(
                    cue: disc.cue,
                    device: device,
                    speed: speed,
                    cdText: disc.text.writesCDText,
                    directory: work
                ),
                into: &panel,
                frame: frame
            )
            burns.append(panel)
            say(
                BurnStage.writtenNote(
                    disc: disc.number, of: plan.discCount, rehearsal: false))
        }
        return Outcome(plan: plan, level: decision, discs: discs, burns: burns, notes: notes)
    }

    /// One disc: check there is room, convert every track into one image, and
    /// write the cue that points at it.
    private func build(
        disc: Int,
        plan: BurnPlan,
        text: DiscText,
        level decision: LevelDecision,
        ffmpeg: URL,
        note say: (String) -> Void
    ) throws -> Disc {
        let entries = plan.entries(onDisc: disc)

        // Before a byte is decoded, not after five minutes of it
        // (`burncd:2405`).
        try TempSpace.check(disc: disc, seconds: plan.runtime(onDisc: disc), in: work)

        let image = imageURL(disc: disc)
        let log = logURL(disc: disc)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let logHandle = try? FileHandle(forWritingTo: log)
        defer { try? logHandle?.close() }

        let writer = try ImageWriter(at: image)
        for (index, entry) in entries.enumerated() {
            say("Converting \(index + 1) of \(entries.count) — \(entry.title)")
            try Converter.convert(
                entry,
                file: files[entry.source],
                gain: decision.gain(for: entry),
                into: writer,
                ffmpeg: ffmpeg,
                log: logHandle
            )
        }
        try writer.finish()

        let cue = cueURL(disc: disc)
        try CueSheet.text(text, imageName: image.lastPathComponent, starts: writer.starts)
            .write(to: cue, atomically: true, encoding: .isoLatin1)

        return Disc(
            number: disc,
            image: image,
            cue: cue,
            starts: writer.starts,
            text: text,
            bytes: writer.dataBytes + DiscImage.headerBytes
        )
    }
}
