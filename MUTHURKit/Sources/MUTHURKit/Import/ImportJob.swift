import Foundation

/// §21 — the import itself: a plan, an ffmpeg, and a folder at the end of it.
///
/// **The whole of it happens in one blocking call with three seams out**, which
/// is `BurnJob`'s shape and is deliberate. The job knows nothing about a window
/// and the window knows nothing about a thread; `ImportRun` is the pair of
/// them, exactly as `BurnRun` is.
///
/// ### What this actually reads
///
/// The files on the **mounted disc**, which on macOS is what an audio CD is:
/// `diskarbitrationd` mounts it with cddafs and the tracks appear as AIFF. Not
/// the device — D44 is the same decision one layer up, and the reasoning
/// carries: cdrtools insists on an exclusive open, the kernel will not give one
/// up for a mounted disc, and taking the mount away to get it (D80's borrow) is
/// a liberty worth taking for two seconds of CD-Text and not for forty minutes
/// of audio with the disc missing from Finder the whole time.
///
/// **The honest consequence, said out loud:** this is the kernel's read, not a
/// paranoid one. There is no re-read of a doubtful sector and no jitter
/// correction, because cddafs offers neither. On a clean disc that is a
/// bit-perfect copy; on a scratched one, cdparanoia would do better and this
/// will not. The disc that made this worth writing is a disc somebody owns and
/// looked after, and a program that refused to import it until a second toolkit
/// was installed would be refusing the common case to defend the rare one.
public struct ImportJob: Sendable {

    public let plan: ImportPlan
    public let options: ImportOptions
    /// §5's cover, where there is one and the format takes it. A *file* and not
    /// a picture: everything this does with it is hand it to ffmpeg by path.
    public let sleeve: URL?

    public init(plan: ImportPlan, options: ImportOptions, sleeve: URL? = nil) {
        self.plan = plan
        self.options = options
        self.sleeve = sleeve
    }

    public struct Outcome: Sendable {
        public let plan: ImportPlan
        /// What landed, in the order it landed.
        public let written: [URL]
        /// Tracks stepped over, by number, with what went wrong.
        public let skipped: [Skip]
        public let folder: URL
        /// Everything the job said on its way past. The panel prints these as
        /// they arrive; the tests read them afterwards.
        public let notes: [String]

        public struct Skip: Sendable, Equatable {
            public let number: Int
            public let why: String
        }
    }

    public enum Failure: Error, CustomStringConvertible {
        case noFFmpeg
        /// The format needs an encoder this ffmpeg was not built with. Asked
        /// once, before anything is decoded, because the alternative is finding
        /// out on track one and having to explain a folder with nothing in it.
        case noEncoder(format: ImportFormat, library: String)
        /// Somebody pressed `Q`. Everything written has been taken back by the
        /// time this is thrown — see `cancelled`.
        case cancelled
        /// Not one track of the disc could be read. Distinct from skipping
        /// some: a disc where every track fails is a disc that is not being
        /// read at all, and saying "0 tracks imported" cheerfully would be the
        /// program reporting success at having done nothing.
        case nothingRead(folder: String)
        case cannotCreate(path: String, reason: String)

        public var description: String {
            switch self {
            case .noFFmpeg:
                "ffmpeg is needed to import a disc and is not installed"
            case .noEncoder(let format, let library):
                """
                this ffmpeg cannot write \(format.name) — it was built without \
                \(library).
                  Choose another format, or reinstall ffmpeg with it.
                """
            case .cancelled:
                "cancelled"
            case .nothingRead(let folder):
                "nothing on this disc could be read — \(folder) is empty"
            case .cannotCreate(let path, let reason):
                "could not make \(path) — \(reason)"
            }
        }
    }

    // MARK: - Being called off

    /// The stop button, from the job's side.
    ///
    /// **A burn has nothing like this and should not.** `BurnJob` offers a
    /// cancel at the insert prompt and refuses one afterwards, because a
    /// `cdrecord` stopped halfway has already spoiled a blank and there is no
    /// undoing it. An import has an undo: every byte it has written is in a
    /// folder it made, and deleting that folder puts the machine back exactly
    /// where it started. So the key is live for the whole run.
    ///
    /// It holds the running child so the stop is immediate rather than "after
    /// this track". A forty-minute record has tracks in it that take a while,
    /// and a cancel that waits for one to finish is a cancel that looks broken.
    public final class Stop: @unchecked Sendable {
        private let lock = NSLock()
        private var asked = false
        private var child: Process?

        public init() {}

        public var isAsked: Bool { lock.withLock { asked } }

        /// Ask, and kill whatever is running.
        public func ask() {
            lock.lock()
            asked = true
            let running = child
            lock.unlock()
            // `terminate` and not `interrupt`: ffmpeg traps SIGINT and tries to
            // finalise the file it is writing, which on a cancel is the one
            // outcome nobody wants — a playable track from a job that was
            // stopped. SIGTERM leaves a partial file, and a partial file is
            // deleted with the rest of the folder a moment later.
            running?.terminate()
        }

        func running(_ process: Process?) {
            lock.lock()
            child = process
            // A child handed over after the stop was already asked would never
            // be killed, because `ask` has been and gone. This is the race, and
            // closing it here is the only place it can be closed.
            let already = asked
            lock.unlock()
            if already { process?.terminate() }
        }
    }

    // MARK: - The run

    /// Import the whole record.
    ///
    /// `note` and `stage` are the seams out; neither returns anything.
    /// `ffmpeg` is passed in rather than located here so the suite can point at
    /// a known one, and so §11's single answer about where ffmpeg is stays the
    /// single answer.
    ///
    /// **Both are `@escaping`, and that is a fact about the progress seam
    /// rather than a formality.** `stage` is called from ffmpeg's own progress
    /// pipe, which Dispatch reads on a queue of its own — so the closure really
    /// does outlive the call that handed it over. This was first written with
    /// `withoutActuallyEscaping`, on the reasoning that the handler is cleared
    /// before the track returns; the runtime check disagreed and was right, as
    /// clearing a `readabilityHandler` does not promise the last reference has
    /// gone by the next line. Declaring the truth is cheaper than arranging for
    /// a convenient lie to hold.
    public func run(
        ffmpeg: URL?,
        stop: Stop = Stop(),
        note: @escaping (String) -> Void = { _ in },
        stage: @escaping (ImportStage) -> Void = { _ in }
    ) throws -> Outcome {
        guard let ffmpeg else { throw Failure.noFFmpeg }
        var notes: [String] = []
        func say(_ line: String) {
            notes.append(line)
            note(line)
        }

        stage(.preparing(into: plan.folder.lastPathComponent))

        if let library = plan.format.library, !ImportJob.hasEncoder(library, ffmpeg: ffmpeg) {
            throw Failure.noEncoder(format: plan.format, library: library)
        }

        // The folder is made here and not by the plan, which is a description
        // and leaves nothing behind when it is refused.
        do {
            try FileManager.default.createDirectory(
                at: plan.folder, withIntermediateDirectories: true)
        } catch {
            throw Failure.cannotCreate(
                path: plan.folder.path, reason: (error as NSError).localizedDescription)
        }

        // Room is checked against the folder rather than the chosen directory,
        // because on a volume with a firmlink or a mount underneath them they
        // are not always the same filesystem.
        do {
            try plan.checkRoom(in: plan.folder)
        } catch let failure as ImportPlan.Failure {
            try cancelled(stop: stop)  // sweeps the folder we just made
            throw failure
        }

        let cover = coverToEmbed()
        if options.sleeve && cover == nil && !plan.format.takesCoverArt {
            // Said once, and only when it is a *refusal* rather than an
            // absence: somebody who asked for the sleeve and chose a format
            // that cannot hold one is owed the reason, and somebody whose
            // record simply has no cover is not owed a complaint about it.
            say("· \(plan.format.name) cannot carry a cover — the sleeve is not embedded")
        }

        var written: [URL] = []
        var skipped: [Outcome.Skip] = []
        var secondsDone = 0.0
        let runtime = plan.runtime

        for (index, entry) in plan.entries.enumerated() {
            if stop.isAsked {
                try cancelled(stop: stop)
                throw Failure.cancelled
            }

            let base = secondsDone
            stage(
                .importing(
                    track: index + 1, ofTracks: plan.entries.count, title: entry.title,
                    head: ImportStage.head(seconds: base, runtime: runtime)))

            do {
                try write(
                    entry, cover: cover, ffmpeg: ffmpeg, stop: stop,
                    progress: { seconds in
                        // The head is the record's, not the track's: seconds
                        // already finished plus how far into this one ffmpeg
                        // says it is. Capped at the track's own duration so a
                        // container that over-reports cannot push the bar past
                        // the tracks behind it.
                        let into = min(seconds, Double(entry.duration))
                        stage(
                            .importing(
                                track: index + 1, ofTracks: plan.entries.count,
                                title: entry.title,
                                head: ImportStage.head(
                                    seconds: base + into, runtime: runtime)))
                    })
                written.append(entry.destination)
                say(ImportStage.wroteNote(number: entry.number, title: entry.title))
            } catch is CancellationError {
                try cancelled(stop: stop)
                throw Failure.cancelled
            } catch {
                // §6.3's rule, applied to writing: a track that will not read
                // is said, stepped over, and the rest of the record still
                // lands. A disc with one bad track is not a disc you can do
                // nothing with.
                let why = ImportJob.short("\(error)")
                skipped.append(Outcome.Skip(number: entry.number, why: why))
                say(ImportStage.skippedNote(number: entry.number, why: why))
                // The part-written file is swept now rather than left for the
                // summary, because a half-track sitting in the folder is
                // indistinguishable from a whole one to everything downstream.
                try? FileManager.default.removeItem(at: entry.destination)
            }

            secondsDone += Double(entry.duration)
        }

        guard !written.isEmpty else {
            try? FileManager.default.removeItem(at: plan.folder)
            throw Failure.nothingRead(folder: plan.folder.lastPathComponent)
        }

        return Outcome(
            plan: plan, written: written, skipped: skipped, folder: plan.folder, notes: notes)
    }

    /// Put the machine back where it started.
    ///
    /// **A folder we made goes entirely**, which is the clean case and the one
    /// the cancel key promises. Where the user chose to write into a directory
    /// that was already there (`folder` set to `.none`), only the files this job
    /// planned are removed — the plan's own list and nothing wider, because
    /// everything else in that directory belongs to somebody else.
    func cancelled(stop: Stop) throws {
        if plan.folderIsOurs {
            try? FileManager.default.removeItem(at: plan.folder)
        } else {
            for entry in plan.entries {
                try? FileManager.default.removeItem(at: entry.destination)
            }
        }
        _ = stop
    }

    // MARK: - One track

    /// The command line for one track.
    ///
    /// **`-map_metadata -1` is the load-bearing flag.** Without it ffmpeg
    /// copies whatever the source carried, and then the tags written below go
    /// on top of a mixture — so a record whose titles came from MusicBrainz, or
    /// that the user corrected by hand (**D85**), could land on disk still
    /// carrying the file's own wrong ones in the fields MusicBrainz had nothing
    /// to say about. The rule this keeps is the plain one: **what the panel
    /// says is what goes in the file.** Off a CDDA mount there is nothing to
    /// discard anyway; it matters for the folder and zip sources this same path
    /// serves.
    ///
    /// `-map a:0` and not `-map 0:a`, for `Converter.arguments`' reason: the
    /// first audio stream and only it, because a source with cover art in it is
    /// a source with a video stream in it.
    ///
    /// The cover, when there is one, is a second input mapped in as an attached
    /// picture and copied rather than re-encoded — the sleeve cache holds JPEG,
    /// which every container here takes as it stands.
    func arguments(for entry: ImportPlan.Entry, cover: URL?) -> [String] {
        var arguments = ["-nostdin", "-v", "error", "-y"]
        arguments += ["-i", entry.source.path]
        if let cover {
            arguments += ["-i", cover.path]
        }
        arguments += ["-map", "a:0"]
        if cover != nil {
            arguments += ["-map", "1:v:0", "-c:v", "copy", "-disposition:v", "attached_pic"]
            arguments += ["-metadata:s:v", "title=Album cover"]
            arguments += ["-metadata:s:v", "comment=Cover (front)"]
        }
        arguments += ["-map_metadata", "-1"]
        arguments += plan.format.codecArguments
        arguments += metadata(for: entry)
        // Progress on stdout, which is free here because the audio is going to
        // a file. `-nostats` so the human-readable line does not interleave
        // with the machine-readable one on the same descriptor.
        arguments += ["-nostats", "-progress", "pipe:1"]
        arguments += [entry.destination.path]
        return arguments
    }

    /// The tags. One shape for every container — `ImportFormat.keepsFullMetadata`
    /// records which of them will actually keep all of it.
    ///
    /// `track` is `n/total` because that is the form every tagger writes and
    /// every player reads, and because the total is the thing a bare number
    /// cannot say. `disc` is written only when the record has more than one,
    /// since `1/1` on a single disc is the machine talking.
    func metadata(for entry: ImportPlan.Entry) -> [String] {
        var out: [String] = []
        func tag(_ key: String, _ value: String) {
            guard !value.isEmpty else { return }
            out += ["-metadata", "\(key)=\(value)"]
        }
        tag("title", entry.title)
        // The track's own artist where it has one, and the record's otherwise.
        // A compilation is the case this exists for: every row has a different
        // artist and the album artist is `Various Artists`.
        tag("artist", entry.artist.isEmpty ? plan.albumArtist : entry.artist)
        tag("album", plan.album)
        tag("album_artist", plan.albumArtist)
        tag("date", plan.year)
        out += ["-metadata", "track=\(entry.number)/\(plan.entries.count)"]
        return out
    }

    /// The sleeve, if it is wanted, exists, and the container will hold it.
    func coverToEmbed() -> URL? {
        guard options.sleeve, plan.format.takesCoverArt, let sleeve else { return nil }
        guard FileManager.default.fileExists(atPath: sleeve.path) else { return nil }
        return sleeve
    }

    /// Run ffmpeg over one track, reporting how far in it has got.
    ///
    /// **Both pipes are drained and the order matters**: stdout is read by a
    /// handler on a queue of its own while stderr is read to the end on this
    /// thread. A full pipe with nobody reading it is a process that never
    /// exits — `Converter.convert` makes the same point about the one pipe it
    /// has — and with two of them the deadlock is available in both directions.
    private func write(
        _ entry: ImportPlan.Entry,
        cover: URL?,
        ffmpeg: URL,
        stop: Stop,
        progress: @escaping (Double) -> Void
    ) throws {
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = arguments(for: entry, cover: cover)
        process.standardInput = FileHandle.nullDevice

        let out = Pipe()
        let errors = Pipe()
        process.standardOutput = out
        process.standardError = errors

        // The handler runs on a Dispatch-owned queue, so the seconds it reads
        // cross a thread to get to `progress`. A lock and not an actor: this is
        // one `Double` written by one reader and read by one loop, and the
        // whole of the contention is a number.
        let ticker = Ticker(progress)
        out.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            ticker.feed(String(decoding: data, as: UTF8.self))
        }

        do {
            try process.run()
        } catch {
            out.fileHandleForReading.readabilityHandler = nil
            throw Converter.Failure.failed(path: entry.source.path, log: "")
        }
        stop.running(process)

        let said = (try? errors.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        out.fileHandleForReading.readabilityHandler = nil
        stop.running(nil)
        // Anything the handler was still holding, now that the child is gone
        // and nothing more can arrive.
        ticker.drain()

        if stop.isAsked { throw CancellationError() }

        guard process.terminationStatus == 0 else {
            throw Converter.Failure.failed(
                path: entry.source.path,
                log: Converter.tail(String(decoding: said, as: UTF8.self)))
        }
    }

    // MARK: - Asking ffmpeg what it can do

    /// Whether this build has the named encoder.
    ///
    /// `-encoders` and a substring, rather than `-h encoder=…`: the help form
    /// exits zero for a name it does not know and says so only in prose, which
    /// is a test that passes when it should fail. The listing either has the
    /// line or it does not.
    static func hasEncoder(_ library: String, ffmpeg: URL) -> Bool {
        guard let listing = Tooling.output(ffmpeg, ["-hide_banner", "-encoders"]) else {
            // Could not ask. Not a refusal — `TempSpace.check`'s rule, that the
            // check is a courtesy and the attempt is the authority. Better to
            // try and fail with ffmpeg's own words than to decline on a
            // question that never got asked.
            return true
        }
        return listing.contains(" \(library) ")
    }

    /// The first line of what went wrong, for a log that has one row per track.
    ///
    /// The whole of an ffmpeg failure is eight indented lines (`Converter.tail`)
    /// and the log on this screen gives each track one, so this takes the last
    /// line with anything in it — ffmpeg's real complaint is the last thing it
    /// says, which is the same observation `tail` is built on.
    static func short(_ text: String, to width: Int = 52) -> String {
        let line =
            text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty } ?? "could not be read"
        return Columns.fit(line, to: width)
    }
}

/// ffmpeg's `-progress` stream, turned into seconds.
///
/// The format is `key=value`, one per line, in blocks ending `progress=continue`
/// — and a read off a pipe lands wherever it lands, so a line can arrive in two
/// pieces. The tail is kept for the next read, which is the whole reason this is
/// a type rather than a closure.
final class Ticker: @unchecked Sendable {
    private let lock = NSLock()
    private var tail = ""
    private let report: (Double) -> Void

    init(_ report: @escaping (Double) -> Void) {
        self.report = report
    }

    func feed(_ text: String) {
        var lines: [String] = []
        lock.lock()
        tail += text
        // Everything up to the last newline is whole; what is after it is not.
        if let last = tail.lastIndex(of: "\n") {
            lines = tail[..<last].split(separator: "\n").map(String.init)
            tail = String(tail[tail.index(after: last)...])
        }
        lock.unlock()
        for line in lines {
            if let seconds = Ticker.seconds(line) { report(seconds) }
        }
    }

    /// The last partial line, once nothing more is coming.
    func drain() {
        lock.lock()
        let rest = tail
        tail = ""
        lock.unlock()
        if let seconds = Ticker.seconds(rest) { report(seconds) }
    }

    /// `out_time=00:02:14.960000`, in seconds.
    ///
    /// **`out_time` and not `out_time_ms`**, which is the trap in this format:
    /// despite the name ffmpeg writes microseconds into `out_time_ms`, and has
    /// for years, so anything dividing it by a thousand is a thousand times
    /// wrong. `out_time_us` is right and is newer than some builds. The
    /// timestamp is unambiguous in every version there has ever been, so it is
    /// the one parsed.
    ///
    /// `N/A` appears in the first block before any frame has been written, and
    /// is not a number — the guard is not decoration.
    static func seconds(_ line: String) -> Double? {
        guard let split = line.firstIndex(of: "=") else { return nil }
        let key = line[..<split].trimmingCharacters(in: .whitespaces)
        guard key == "out_time" else { return nil }
        let value = line[line.index(after: split)...].trimmingCharacters(in: .whitespaces)
        let parts = value.split(separator: ":")
        guard parts.count == 3,
            let hours = Double(parts[0]), let minutes = Double(parts[1]),
            let secs = Double(parts[2])
        else { return nil }
        return hours * 3600 + minutes * 60 + secs
    }
}
