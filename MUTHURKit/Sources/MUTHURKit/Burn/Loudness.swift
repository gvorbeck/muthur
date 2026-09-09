import Foundation

/// §20 stage 2 — `--level` (`burncd:490–605`).
///
/// **Gain and nothing else.** The script says so twice and means it: matching a
/// modern master's loudness needs compression, compression changes the sound,
/// and a program that quietly changed the sound of a record on its way to a
/// disc would be worse than one that left it quiet. So the gain applied is the
/// smaller of two numbers — what it would take to reach the loudness target,
/// and what is left before true peak reaches the ceiling — and where those two
/// disagree, the ceiling wins and the disc stays quiet. `levelNote` is what
/// makes that a stated outcome rather than a mystery.
public enum LevelMode: String, Sendable, CaseIterable {
    case off
    case album
    case track

    /// `BURNCD_LEVEL` (`burncd:81`), under the port's own name first.
    ///
    /// Anything unrecognised is `off` rather than an error: this is read once,
    /// before a plan exists, and refusing to open a record because a shell
    /// profile has a typo in it is not the trade the script makes anywhere else.
    public static func from(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> LevelMode {
        let raw = environment["MUTHUR_LEVEL"] ?? environment["BURNCD_LEVEL"] ?? ""
        return LevelMode(rawValue: raw.lowercased()) ?? .off
    }
}

/// Where the level pass is aiming, and where it is not allowed to go
/// (`burncd:83–88`).
public struct LevelTargets: Sendable, Equatable {

    /// −11 LUFS, about where a normal commercial CD sits. Chasing much louder
    /// than this needs compression, which this deliberately will not do.
    public static let defaultLUFS = -11.0

    /// −1 dBTP. Inter-sample peaks can exceed the highest sample, and some DACs
    /// clip reconstructing them even when the PCM itself is legal — so a dB is
    /// left unused on purpose.
    public static let defaultPeak = -1.0

    public var lufs: Double
    public var peak: Double

    public init(lufs: Double = LevelTargets.defaultLUFS, peak: Double = LevelTargets.defaultPeak) {
        self.lufs = lufs
        self.peak = peak
    }

    /// `BURNCD_LUFS` and `BURNCD_PEAK`, under the port's names first.
    ///
    /// Junk falls back to the default. The script runs these through arithmetic
    /// in `awk`, where a non-number silently becomes zero — a target of 0 LUFS
    /// being about as wrong as a target can be — and the port would rather be
    /// quietly right than loudly faithful about that one.
    public static func from(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> LevelTargets {
        LevelTargets(
            lufs: number(environment, "MUTHUR_LUFS", "BURNCD_LUFS") ?? defaultLUFS,
            peak: number(environment, "MUTHUR_PEAK", "BURNCD_PEAK") ?? defaultPeak
        )
    }

    private static func number(
        _ environment: [String: String], _ first: String, _ second: String
    ) -> Double? {
        guard let raw = environment[first] ?? environment[second] else { return nil }
        return Double(raw.trimmingCharacters(in: .whitespaces))
    }
}

/// One file's loudness, as EBU R128 reads it.
public struct Loudness: Sendable, Equatable, Codable {

    /// Integrated loudness, LUFS.
    public let lufs: Double

    /// True peak, dBTP.
    public let peak: Double

    /// Low enough to contribute no energy, and a number, which `-inf` is not
    /// (`burncd:502`).
    ///
    /// Digital silence reads as `-inf` on both fields, and every arithmetic
    /// step downstream — the energy sum, the two subtractions — would carry it
    /// through to a gain nothing can be done with. A silent track is a track
    /// with nothing to say about how loud the disc should be, and −70 is how it
    /// says nothing.
    public static let floor = -70.0

    public init(lufs: Double, peak: Double) {
        self.lufs = lufs
        self.peak = peak
    }

    /// Pull the two summary figures out of `ffmpeg -af ebur128=peak=true`
    /// (`measure_file`, `burncd:504`).
    ///
    /// The two anchors are the script's, and they are anchored for a reason:
    /// the summary block prints `    I:         -41.8 LUFS` and
    /// `    Peak:      -41.1 dBFS` with leading spaces and nothing before them,
    /// while every per-frame progress line begins `[Parsed_ebur128_0 @ …]`. A
    /// line that merely *contains* `I:` would match a filename. Verified
    /// against the ffmpeg on this machine rather than assumed.
    ///
    /// Last match wins, as `awk`'s repeated assignment does: ebur128 prints its
    /// summary once, and if a future build printed it twice the second one
    /// would be the one that counted anyway.
    public static func parse(_ output: String) -> Loudness {
        var lufs: Double?
        var peak: Double?
        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.drop { $0 == " " }
            if trimmed.hasPrefix("I: ") {
                lufs = field(after: "I:", in: trimmed)
            } else if trimmed.hasPrefix("Peak: ") {
                peak = field(after: "Peak:", in: trimmed)
            }
        }
        return Loudness(lufs: lufs ?? floor, peak: peak ?? floor)
    }

    /// `awk`'s `$2` — the next whitespace-separated word — and nil for anything
    /// that is not a plain number, which is how `-inf` and `nan` reach the
    /// floor above.
    private static func field(after label: String, in line: Substring) -> Double? {
        let rest = line.dropFirst(label.count)
        guard let word = rest.split(separator: " ", omittingEmptySubsequences: true).first
        else { return nil }
        // The script's own test: an optional sign, digits and dots, nothing
        // else. `Double("-inf")` parses, which is exactly the value that must
        // not get through.
        guard word.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }),
              word.contains(where: \.isNumber),
              let value = Double(word)
        else { return nil }
        return value
    }
}

// MARK: - The gains

public extension Loudness {

    /// Which of the two limits stopped the gain where it did (`burncd:585`).
    enum Bound: String, Sendable, Equatable {
        /// It reached the loudness target.
        case loudness
        /// It ran out of headroom first, and this is all there is.
        case peak
    }

    /// The gain for one track on its own (`burncd:556`).
    ///
    /// **This one may attenuate.** `--level=track` is for a compilation of
    /// unrelated masters, where matching them to each other is the entire
    /// point, and that means bringing the loud ones down.
    func trackGain(_ targets: LevelTargets) -> Double {
        min(targets.lufs - lufs, targets.peak - peak)
    }

    /// Which limit stopped that gain. D73.
    ///
    /// The same `gl < gh` test `compute_album_gain` uses, applied one track at
    /// a time — a tie counts as `peak`, because the script's comparison is
    /// strict and a gain that satisfies both limits exactly is still a gain the
    /// ceiling would not have let past.
    func trackBound(_ targets: LevelTargets) -> Bound {
        (targets.lufs - lufs) < (targets.peak - peak) ? .loudness : .peak
    }

    /// One gain for the whole playlist (`compute_album_gain`, `burncd:570`).
    ///
    /// Energy-weighted by duration, which is how album gain has always been
    /// computed — averaging the dB figures would let a short quiet intro drag
    /// the whole record up. The peak is the loudest single peak anywhere in the
    /// job, because one gain has to be safe for all of it.
    ///
    /// **Never negative.** Turning a loud record down is not what "this disc
    /// plays quiet" asks for, and cutting to hit a loudness target would need a
    /// limiter, which would change the sound.
    static func albumGain(
        tracks: [(duration: Int, loudness: Loudness)], targets: LevelTargets
    ) -> (gain: Double, bound: Bound?) {
        var energy = 0.0
        var duration = 0.0
        var loudestPeak = -Double.infinity
        for track in tracks {
            energy += Double(track.duration) * pow(10, track.loudness.lufs / 10)
            duration += Double(track.duration)
            loudestPeak = max(loudestPeak, track.loudness.peak)
        }
        // A playlist of nothing, or one that is silence all the way down: there
        // is no loudness to read off it, so there is no gain and nothing to say
        // about why (`burncd:578`).
        guard duration > 0, energy > 0 else { return (0, nil) }

        let integrated = 10 * log10(energy / duration)
        let toLoudness = targets.lufs - integrated
        let toCeiling = targets.peak - loudestPeak
        let bound: Bound = toLoudness < toCeiling ? .loudness : .peak
        return (max(0, min(toLoudness, toCeiling)), bound)
    }

    /// The gain as the script writes it, to one decimal (`burncd:558`).
    ///
    /// The *string* is what matters downstream and not the number: the
    /// conversion picks its filter by comparing this text to `"0.0"`
    /// (`burncd:2519`), so a gain of −0.04 dB prints `-0.0`, fails that
    /// comparison and takes the `volume=` path. That is a no-op filter applied
    /// for nothing, and it is kept because it is what the script does — the
    /// output is identical either way, and diverging here would mean the two
    /// programs could write different images from the same record.
    static func format(_ gain: Double) -> String {
        String(format: "%.1f", gain)
    }

    /// A target, as it was written down rather than as arithmetic sees it.
    ///
    /// `level_note` interpolates `$LUFS_TARGET` straight from the environment,
    /// so the default reads `-11 LUFS` and not `-11.0 LUFS`. The trailing zero
    /// would be a claim of precision the number does not have — nobody chose
    /// −11.0 over −11.1 — so an integral target prints as an integer and
    /// anything the operator actually typed a decimal into keeps it.
    static func formatTarget(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e9
            ? String(Int(value))
            : String(format: "%g", value)
    }
}

// MARK: - The cache

/// Measured loudness, remembered (`burncd:492`).
///
/// **Not the script's TSV, and not `hash_str`.** That file is keyed by an md5
/// of `path:size:mtime` because a shell can only look a line up with `grep`,
/// and it is appended to forever: re-tag an album and every one of its old rows
/// stays in the file, unreachable and permanent. Here the key is the path and
/// the size and mtime are fields beside the reading, so a file that changed
/// replaces its own entry instead of growing a second one. D69.
public struct LevelCache: Sendable {

    struct Entry: Codable, Sendable {
        var size: Int
        var modified: Double
        var lufs: Double
        var peak: Double
    }

    private var entries: [String: Entry]
    private let url: URL?

    /// Where the cache lives. `XDG_CACHE_HOME` is honoured because the script
    /// honours it, under `muthur` rather than `burncd` — the two programs
    /// measure the same files the same way, but a cache is a private format and
    /// sharing one would make either program's change to it the other's bug.
    public static func location(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let base: URL
        if let xdg = environment["XDG_CACHE_HOME"], !xdg.isEmpty {
            base = URL(fileURLWithPath: xdg)
        } else {
            base = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".cache")
        }
        return base.appendingPathComponent("muthur/levels.json")
    }

    /// Read what is there, if anything is, and if anything can be.
    ///
    /// **The cache is an optimisation, never a requirement** (`burncd:521`). A
    /// read-only home, a sandbox, odd permissions — any of them means measuring
    /// every time, and none of them is worth a word to the operator, who did
    /// not ask for a cache and cannot do anything about it. A corrupt file is
    /// the same case: it is discarded and rewritten.
    public init(at url: URL?) {
        self.url = url
        guard
            let url,
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        else {
            entries = [:]
            return
        }
        entries = decoded
    }

    /// What was measured for this file, if it is still the same file.
    public func reading(for url: URL) -> Loudness? {
        guard
            let entry = entries[url.path],
            let stamp = LevelCache.stamp(of: url),
            entry.size == stamp.size,
            entry.modified == stamp.modified
        else { return nil }
        return Loudness(lufs: entry.lufs, peak: entry.peak)
    }

    public mutating func record(_ loudness: Loudness, for url: URL) {
        guard let stamp = LevelCache.stamp(of: url) else { return }
        entries[url.path] = Entry(
            size: stamp.size, modified: stamp.modified,
            lufs: loudness.lufs, peak: loudness.peak
        )
    }

    /// Best effort, silent on failure, for the reasons in `init`.
    public func save() {
        guard let url else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Size and mtime, as `file_size` and `stat -f%m` read them
    /// (`burncd:539`). Both, rather than mtime alone: a tag rewrite that
    /// preserves the timestamp still changes the size, and a copy that
    /// preserves the size still changes the timestamp.
    ///
    /// `FileManager` and not `URL.resourceValues`, which **caches on the URL
    /// instance**: ask the same `URL` value twice and the second answer is the
    /// first one, however much the file changed in between. A cache key read
    /// out of a cache is not a cache key.
    static func stamp(of url: URL) -> (size: Int, modified: Double)? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? Int,
            let modified = attributes[.modificationDate] as? Date
        else { return nil }
        return (size, modified.timeIntervalSince1970)
    }
}

// MARK: - The pass

/// Measuring every file in the job (`measure_all`, `burncd:518`).
public struct LevelPass: Sendable {

    /// What the operator is told before the wait starts (`burncd:544`).
    ///
    /// Measuring means decoding everything an extra time, end to end, and on an
    /// album of lossless files that is minutes. It is said once, on the first
    /// file that misses the cache, and not at all when every file hits — the
    /// second burn of the same record is free and should look it.
    public static let firstRunNote = "Measuring loudness (first time for these files)"

    /// One line of progress while it runs (`burncd:549`).
    public static func progressNote(_ index: Int, of total: Int, name: String) -> String {
        "\(index) of \(total) — \(name.prefix(40))"
    }

    public struct Result: Sendable {
        /// One reading per file, in the order they were handed over.
        public var readings: [Loudness]
        /// Whether anything actually had to be decoded.
        public var measuredAnything: Bool
    }

    public enum Failure: Error, CustomStringConvertible {
        case noFFmpeg
        case failed(path: String)

        public var description: String {
            switch self {
            case .noFFmpeg:
                "ffmpeg is needed to measure loudness and is not installed"
            case .failed(let path):
                "could not measure the loudness of \(path)"
            }
        }
    }

    /// Where the readings come from. Injectable so the arithmetic above can be
    /// tested without ten minutes of decoding, and so a machine with no ffmpeg
    /// still runs every test that is not about ffmpeg.
    public typealias Measure = (URL) throws -> Loudness

    /// `ffmpeg -nostdin -nostats -i FILE -map a:0 -af ebur128=peak=true -f null -`
    /// (`burncd:505`), with stdout and stderr together because ebur128 reports
    /// on stderr.
    public static func ffmpegMeasure(_ ffmpeg: URL) -> Measure {
        { url in
            let arguments = [
                "-nostdin", "-nostats", "-i", url.path,
                "-map", "a:0", "-af", "ebur128=peak=true", "-f", "null", "-",
            ]
            guard let result = Tooling.run(ffmpeg, arguments), result.status == 0 else {
                throw Failure.failed(path: url.path)
            }
            return Loudness.parse(result.output)
        }
    }

    /// Measure every file, using and updating the cache.
    ///
    /// `note` is called with `firstRunNote` once, before the first file that
    /// has to be decoded, and with `progressNote` for each of them after —
    /// which is the script's order, and the order matters: the sentence
    /// explaining the wait has to arrive before the wait does.
    public static func run(
        files: [URL],
        cache: inout LevelCache,
        measure: Measure,
        note: (String) -> Void = { _ in }
    ) throws -> Result {
        var readings: [Loudness] = []
        var fresh = false
        for (index, file) in files.enumerated() {
            if let hit = cache.reading(for: file) {
                readings.append(hit)
                continue
            }
            if !fresh {
                note(firstRunNote)
                fresh = true
            }
            note(progressNote(index + 1, of: files.count, name: file.lastPathComponent))
            let reading = try measure(file)
            cache.record(reading, for: file)
            readings.append(reading)
        }
        if fresh { cache.save() }
        return Result(readings: readings, measuredAnything: fresh)
    }
}

// MARK: - What it decided

/// The level pass's answer for one job: the mode, and the gain per playlist
/// entry (`gain_for`, `burncd:595`).
public struct LevelDecision: Sendable, Equatable {

    public let mode: LevelMode
    public let targets: LevelTargets

    /// Album mode's single gain, and what stopped it there.
    public let albumGain: Double
    public let albumBound: Loudness.Bound?

    /// Track mode's gains, one per **source file**, indexed as `BurnPlan.Entry`
    /// indexes its `source` — a track cut across two discs is one measurement
    /// and one gain, and both halves get it.
    public let trackGains: [Double]

    /// How the playlist's tracks divided between the two limits, in track mode.
    /// D73 — without this the note could only claim the target had been reached.
    public let trackTally: TrackTally

    /// The count behind track mode's note.
    ///
    /// Counted over the **playlist**, not the source list, and each source once
    /// however many discs it spans: album mode averages over what is actually
    /// being burned (`compute_album_gain` walks `P_SRC`), and a sentence about
    /// the same job should be counted over the same set.
    public struct TrackTally: Sendable, Equatable {

        /// Tracks the peak ceiling stopped short of the loudness target.
        public var peakHeld: Int

        /// Tracks in the playlist.
        public var total: Int

        public init(peakHeld: Int = 0, total: Int = 0) {
            self.peakHeld = peakHeld
            self.total = total
        }
    }

    /// Settle every gain the job will need, once.
    ///
    /// Album gain is computed from the playlist rather than the source list
    /// because the playlist is what is actually being burned: drop a track in
    /// the editor and the album it averages over is a track shorter. The script
    /// recomputes it after every edit for the same reason (`replan`,
    /// `burncd:735`), and so must anything here that edits a plan.
    public static func make(
        mode: LevelMode,
        targets: LevelTargets,
        readings: [Loudness],
        entries: [BurnPlan.Entry]
    ) -> LevelDecision {
        guard mode != .off else {
            return LevelDecision(
                mode: .off, targets: targets, albumGain: 0, albumBound: nil,
                trackGains: [], trackTally: TrackTally()
            )
        }
        let tracks = entries.compactMap { entry -> (duration: Int, loudness: Loudness)? in
            guard readings.indices.contains(entry.source) else { return nil }
            return (entry.duration, readings[entry.source])
        }
        let album = Loudness.albumGain(tracks: tracks, targets: targets)

        var counted = Set<Int>()
        var tally = TrackTally()
        for entry in entries where readings.indices.contains(entry.source) {
            guard counted.insert(entry.source).inserted else { continue }
            tally.total += 1
            if readings[entry.source].trackBound(targets) == .peak { tally.peakHeld += 1 }
        }

        return LevelDecision(
            mode: mode,
            targets: targets,
            albumGain: album.gain,
            albumBound: album.bound,
            trackGains: readings.map { $0.trackGain(targets) },
            trackTally: tally
        )
    }

    /// The gain for one playlist entry, as the bare dB text the filter is built
    /// from (`gain_for`, `burncd:595`).
    public func gain(for entry: BurnPlan.Entry) -> String {
        switch mode {
        case .off:
            Loudness.format(0)
        case .album:
            Loudness.format(albumGain)
        case .track:
            Loudness.format(
                trackGains.indices.contains(entry.source) ? trackGains[entry.source] : 0
            )
        }
    }

    /// What the pass decided and — just as important — why it stopped where it
    /// did, so a disc that stays quiet is explained rather than mysterious
    /// (`level_note`, `burncd:787`).
    ///
    /// **Track mode names its limit too. D73.** The script's track branch prints
    /// one unconditional sentence claiming every track was matched to the
    /// target, but `TRACK_GAIN` is `min(gl, gh)` with no clamp — a hot master is
    /// peak-bound and was never matched to anything. Album mode, five lines
    /// below in the same function, already distinguishes its three cases; this
    /// is that distinction made in the branch that was missing it.
    public var note: String? {
        switch mode {
        case .off:
            nil
        case .track where trackTally.peakHeld == 0:
            "Level: each track matched to \(Loudness.formatTarget(targets.lufs)) LUFS"
        case .track where trackTally.peakHeld == trackTally.total:
            "Level: every track held by its peak, "
                + "short of \(Loudness.formatTarget(targets.lufs)) LUFS"
        // Both counts are in the first clause, so the second one needs no
        // number and cannot disagree with itself about "1 tracks".
        case .track:
            "Level: \(trackTally.total - trackTally.peakHeld) of \(trackTally.total) "
                + "matched to \(Loudness.formatTarget(targets.lufs)) LUFS, "
                + "the rest held by peaks"
        case .album where Loudness.format(albumGain) == "0.0":
            "Level: already at CD loudness, no change"
        case .album where albumBound == .peak:
            "Level: +\(Loudness.format(albumGain)) dB — all the headroom there is before clipping"
        case .album:
            "Level: +\(Loudness.format(albumGain)) dB to reach "
                + "\(Loudness.formatTarget(targets.lufs)) LUFS"
        }
    }
}
