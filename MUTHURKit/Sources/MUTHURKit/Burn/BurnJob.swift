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
/// **Stage 3a moved the burn itself inside.** `.throughTheBurn` runs the panel
/// past a `Drive`, and because the drive is a parameter, the real one arriving
/// is a different argument and not a different `run`. That is exactly what
/// happened at stage 3b: `Burner` went in where `FakeDrive` was, and nothing in
/// this file changed to let it.
///
/// **What did change here is the order.** Stage 3a built every disc and then
/// burnt every disc, which cost nothing while no disc was ever really burnt. The
/// script does not: it prompts, looks at the blank, converts, and writes, one
/// disc at a time (`burncd:2398`) — and `media_check` is *only* worth having in
/// that order. Its whole claim is to refuse the wrong blank before the minutes
/// are spent converting into an image it cannot hold, and a job that converts
/// disc 3 before anyone has been asked to insert disc 1 has already spent them.
/// So the loop is the script's loop now, and `.afterBuilding` is the same job
/// with the burning taken out.
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

        /// The whole thing: every disc built and then written by whatever
        /// `drive` is (`burncd:2591`). With `FakeDrive` that is `--demo` —
        /// nothing spawned, no blank in the machine, and a finished burn screen
        /// at the end of it. With `Burner` it is a burn.
        ///
        /// **One case and not two, on purpose.** The stop is where the job
        /// stops; *what writes the disc* is the drive, and a job that had to be
        /// told both would be a job that could be told the wrong pair.
        case throughTheBurn
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
        /// to `.throughTheBurn`.
        public let burns: [BurnPanel]
        /// The discs `--verify` read back and would not pass (`VERIFY_FAILED`,
        /// `burncd:2669`). Empty for a job that did not verify, and empty for a
        /// job where every disc was sound — the two are told apart by whether
        /// anything was asked, not by this.
        public let verifyFailures: [Int]
        /// Everything the job would have said on its way past, in order: the
        /// split note, the level note, each disc's CD-Text shedding. The panel
        /// prints these; the tests read them.
        public let notes: [String]
    }

    public enum Failure: Error, CustomStringConvertible {
        /// The source list and the draft disagree about how many tracks there
        /// are. Not survivable: every index in the plan points into one of them.
        case sourceMismatch(files: Int, rows: Int)

        /// `--from-disc 4` on a three-disc job (`burncd:2385`). Caught before
        /// anything is converted, because the number came from a person and the
        /// answer is a different number.
        case resumePastTheEnd(from: Int, discs: Int)

        /// The operator left the insert prompt rather than putting a disc in.
        /// `q` in the script, which `die`s with the same word.
        case cancelled

        public var description: String {
            switch self {
            case .sourceMismatch(let files, let rows):
                "\(files) files for \(rows) rows — the plan and the record disagree"
            case .resumePastTheEnd(let from, let discs):
                "resuming at disc \(from), but this job is only \(discs) discs"
            case .cancelled:
                "cancelled"
            }
        }
    }

    // MARK: - The blank, and the person putting it in

    /// The insert prompt and the look at what arrives (`burncd:2425`).
    ///
    /// **The two travel together or not at all.** `media_check` answers *put a
    /// different disc in*, and that answer is only useful to something that can
    /// ask again — in the script a `while :;` around `stage_insert`, here a
    /// closure that blocks until a person has done something. A check with no
    /// prompt behind it could only refuse a job it was written to rescue, so
    /// there is one optional and not two: nil is `--demo`, which never goes near
    /// a drive and is never asked (`burncd:2262`).
    public struct Insert {
        /// The look at the blank. Carried across discs rather than made per
        /// disc, because `atipWarned` is a property of the *drive* having
        /// stopped answering and saying so five times in a five-disc job is
        /// exactly what the script's global prevents.
        public var check: MediaCheck

        /// Put the prompt up for this disc and block until it is answered.
        /// False cancels the job — `q` at the prompt.
        ///
        /// The note from a refused disc has already been said by the time this
        /// is called again, so the prompt does not carry it: `note()` redraws
        /// the stage around the reason and the retry costs no display machinery
        /// of its own (`burncd:2422`).
        public var wait: (Int) -> Bool

        public init(check: MediaCheck = MediaCheck(), wait: @escaping (Int) -> Bool) {
            self.check = check
            self.wait = wait
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

    /// `--dummy`: the whole burn with the write laser off (`burncd:2606`).
    ///
    /// It changes three things and no more — the verb on the panel, `-dummy` on
    /// the vector, and the disc not being ejected afterwards, because a
    /// rehearsed blank is still blank and is about to be written for real. The
    /// media check is *not* skipped: a rehearsal on a disc too small to hold the
    /// job tells you nothing you wanted to know.
    public var rehearsal: Bool

    /// `--from-disc n`: pick a multi-disc job back up at disc `n`
    /// (`burncd:2384`).
    ///
    /// The discs before it are planned exactly as they were — the layout has to
    /// be identical or the disc numbers mean nothing — and then not built and
    /// not written. That is the whole feature, and it is why the layout is fixed
    /// before this is consulted rather than after.
    public var from: Int

    /// What one blank is assumed to hold, in seconds (`BURNCD_MINUTES`, D75).
    ///
    /// Carried on the job rather than read at the point of use so that the plan
    /// and the look at the blank are cut against the same number — a job planned
    /// for 80 minutes and checked against 74 would refuse every disc it had just
    /// laid out.
    public var capacity: Int

    /// Whether a written image survives the disc it was written to (D79).
    ///
    /// Carried on the job for the same reason `capacity` is: it is read once,
    /// where the job is set up, rather than once per disc deep inside the loop —
    /// so a five-disc job cannot change its mind halfway, and a test can say
    /// what it means without reaching for `setenv` in a suite that runs in
    /// parallel.
    public var keepImages: Bool

    public init(
        draft: PlanDraft,
        files: [URL],
        work: URL,
        stop: Stop,
        splitLong: Bool = false,
        cdText: Bool = true,
        level: LevelMode = .off,
        targets: LevelTargets = LevelTargets(),
        rehearsal: Bool = false,
        from: Int = 1,
        capacity: Int = BurnLimits.capacity,
        keepImages: Bool = BurnJob.keepImagesRequested()
    ) {
        self.draft = draft
        self.files = files
        self.work = work
        self.stop = stop
        self.splitLong = splitLong
        self.cdText = cdText
        self.level = level
        self.targets = targets
        self.rehearsal = rehearsal
        self.from = from
        self.capacity = capacity
        self.keepImages = keepImages
    }

    /// Whether anybody asked for the images to be left where they are
    /// (`BURNCD_KEEP_WORK`, D79).
    ///
    /// `MUTHUR_KEEP` is honoured beside it on D13's terms — the script's name
    /// still works and this program's name works too — and it means the same
    /// thing in both directions: somebody who asked for the scratch directory to
    /// survive asked for what is *in* it, and handing them an empty one would be
    /// answering a different question.
    public static func keepImagesRequested(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if let asked = environment["BURNCD_KEEP_WORK"], !asked.isEmpty { return true }
        return Scratch.keepRequested(environment: environment)
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
    ///
    /// **`verify` is the flag and the seam in one value, the way `insert` is.**
    /// `--verify` is a thing that can only be done to a disc, so handing over the
    /// thing that reads one back *is* asking for it — a job told both would be a
    /// job that could be told the wrong pair. A rehearsal is never asked:
    /// `--dummy` leaves the blank blank, and there is nothing on it to read
    /// (`burncd:2655`).
    public func run(
        ffmpeg: URL? = nil,
        measure: LevelPass.Measure? = nil,
        cache: LevelCache? = nil,
        drive: Drive = FakeDrive(),
        insert: Insert? = nil,
        verify: DiscVerify? = nil,
        frame: (BurnPanel) -> Void = { _ in },
        note: (String) -> Void = { _ in },
        stage: (BurnStage) -> Void = { _ in }
    ) throws -> Outcome {
        guard files.count == draft.rows.count else {
            throw Failure.sourceMismatch(files: files.count, rows: draft.rows.count)
        }
        var insert = insert

        var notes: [String] = []
        func say(_ line: String) {
            notes.append(line)
            note(line)
        }

        let plan = try BurnPlan.make(draft: draft, capacity: capacity, splitLong: splitLong)
        for line in plan.splitNotes { say(line) }

        // Both said before a second of audio is decoded. A rehearsal's two lines
        // are what stop the operator waiting for a disc that is never going to
        // come out, and a resume that is out of range is a typo, answered in a
        // millisecond rather than after the conversion (`burncd:2379`).
        if rehearsal {
            say("TEST BURN — the laser stays off and nothing is written.")
            say("The disc is not ejected, so you can burn it for real straight after.")
        }
        if from > 1 {
            guard from <= plan.discCount else {
                throw Failure.resumePastTheEnd(from: from, discs: plan.discCount)
            }
            say("Resuming at disc \(from) of \(plan.discCount), skipping \(from - 1) already burned.")
        }

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
            return Outcome(
                plan: plan, level: decision, discs: [], burns: [], verifyFailures: [],
                notes: notes)
        }

        guard let ffmpeg else { throw Converter.Failure.noFFmpeg }

        // Read once for the whole job, not once a disc: the speed is a setting
        // and the drive does not move between discs, and a junk `MUTHUR_SPEED`
        // said five times is D74 being annoying rather than helpful.
        let (speed, speedNote) = Cdrecord.speed()
        if let speedNote, stop == .throughTheBurn { say(speedNote) }
        let device = OpticalDrive.detect().device

        // One disc at a time, as the script does it: ask for the blank, look at
        // what arrived, convert into an image, write it. Every step of that
        // order is load-bearing — the prompt before the look because there is
        // nothing to look at until someone has put it in, the look before the
        // conversion because that is the whole of what the look is for.
        var discs: [Disc] = []
        var burns: [BurnPanel] = []
        var verifyFailures: [Int] = []
        for number in max(1, from)...max(1, plan.discCount) {
            if stop == .throughTheBurn {
                try waitForBlank(
                    disc: number, of: plan.discCount, want: plan.runtime(onDisc: number),
                    device: device, insert: &insert, say: say, stage: stage)
            }

            let disc = try build(
                disc: number, plan: plan, text: texts[number - 1],
                level: decision, ffmpeg: ffmpeg, note: say, stage: stage
            )
            discs.append(disc)
            guard stop == .throughTheBurn else { continue }

            let entries = plan.entries(onDisc: number)
            var panel = BurnPanel(
                disc: number,
                of: plan.discCount,
                titles: entries.map(\.title),
                durations: entries.map(\.duration),
                totalMegabytes: drive.totalMegabytes(
                    bytes: disc.bytes, tracks: entries.count),
                rehearsal: rehearsal
            )
            try drive.write(
                Cdrecord.write(
                    cue: disc.cue,
                    device: device,
                    speed: speed,
                    cdText: disc.text.writesCDText,
                    rehearsal: rehearsal,
                    // The disc has to still be in the drive to be read back, so
                    // cdrecord's own `-eject` comes off the vector and is issued
                    // by hand once the verify is done (`burncd:2607`).
                    verify: verify != nil,
                    directory: work
                ),
                into: &panel,
                frame: frame
            )
            burns.append(panel)
            say(
                BurnStage.writtenNote(
                    disc: number, of: plan.discCount, rehearsal: rehearsal))
            // A stage of its own so the burn screen's last frame is not left
            // sitting at 100% while the next disc is being asked for
            // (`burncd:2680`, and `BurnStage.written` says the same).
            stage(.written(disc: number, of: plan.discCount, rehearsal: rehearsal))

            // The image has been written to a disc and is now the largest thing
            // in the scratch directory by three orders of magnitude (D79). It
            // goes, and the cue sheet stays: the cue is a kilobyte and it is
            // what somebody reads afterwards to see what was burnt. **After the
            // write and not before it**, which is where the script differs.
            if !rehearsal && !keepImages {
                try? FileManager.default.removeItem(at: disc.image)
            }

            // And before the read-back rather than after it, which is worth a
            // sentence: a verify is the length of the record again, and the
            // image is not part of it — `verify_disc` is deliberately not a
            // comparison against the file. So the next disc's conversion gets
            // the space back while the drive is still busy with this one.
            if let verify, !rehearsal {
                let report = verify.look(
                    disc: number,
                    want: entries.count,
                    device: device,
                    // The title as it went into the lead-in, after §20.3's
                    // shedding — not the folder's, which is what the disc would
                    // be looked for under if the ladder had shortened it.
                    album: disc.text.discTitle,
                    cdText: disc.text.writesCDText,
                    log: DiscVerify.logURL(work: work, disc: number))
                for line in report.notes { say(line) }
                if !report.passed { verifyFailures.append(number) }
                say(BurnStage.verifiedNote(disc: number, passed: report.passed))
                // The eject the write was not allowed to do. It is how a
                // multi-disc job cues the next disc, so it happens either way.
                verify.probes.eject(device)
            }
        }
        if !verifyFailures.isEmpty { say(BurnStage.verifyFailedNote(discs: verifyFailures)) }
        return Outcome(
            plan: plan, level: decision, discs: discs, burns: burns,
            verifyFailures: verifyFailures, notes: notes)
    }

    /// The insert prompt, looped until something acceptable is in the drive
    /// (`burncd:2425`).
    ///
    /// A refusal is a swap and a keypress, not a dead job — which is why this is
    /// a `while` and not a `guard`. The only ways out are a disc the check will
    /// take and a person who has stopped putting them in.
    private func waitForBlank(
        disc: Int, of discs: Int, want: Int, device: String, insert: inout Insert?,
        say: (String) -> Void, stage: (BurnStage) -> Void
    ) throws {
        guard insert != nil else { return }
        while true {
            // Going back is only offered on the first disc of the job, and only
            // when the job started there (`burncd:1541`). Once a disc is written
            // the plan it came from is a fact about a physical object, and
            // re-cutting the running order underneath it would renumber discs
            // that are already in a sleeve.
            stage(.insert(disc: disc, of: discs, canEdit: disc == 1 && from <= 1))
            guard insert!.wait(disc) else { throw Failure.cancelled }
            let verdict = insert!.check.look(
                disc: disc, want: want, capacity: capacity, device: device)
            if let line = verdict.note { say(line) }
            if verdict.isGo { return }
        }
    }

    /// One disc: check there is room, convert every track into one image, and
    /// write the cue that points at it.
    private func build(
        disc: Int,
        plan: BurnPlan,
        text: DiscText,
        level decision: LevelDecision,
        ffmpeg: URL,
        note say: (String) -> Void,
        stage: (BurnStage) -> Void = { _ in }
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

        // The head is where the seconds already converted put it, not where the
        // track count does (`burncd:1556`): a long track moves the bar the way
        // it moves the number, which is the whole reason the conversion and the
        // burn are drawn against the same bands.
        let total = entries.reduce(0) { $0 + $1.duration }
        let units = PanelGrid.stripWidth * Meter.unitsPerCell
        var converted = 0

        let writer = try ImageWriter(at: image)
        for (index, entry) in entries.enumerated() {
            say("Converting \(index + 1) of \(entries.count) — \(entry.title)")
            stage(
                .converting(
                    disc: disc, of: plan.discCount, track: index + 1,
                    ofTracks: entries.count, title: entry.title,
                    head: total > 0 ? converted * units / total : 0))
            converted += entry.duration
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
