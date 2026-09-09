import Foundation

/// §20 stage 2 — everything to 16-bit/44.1 kHz stereo, straight into the image
/// (`burncd:2500–2526`).
///
/// The same ffmpeg the player falls back to in §12, asked for something
/// simpler: no seeking mid-stream, no format probing, one pass per track and
/// raw `s16le` on stdout. A record is whatever mixture of FLAC, ALAC, MP3, WAV
/// and Opus somebody's shelf actually is; a CD is one format. This is where
/// that stops being true of the second one.
public enum Converter {

    /// The audio filter chain, and the order of it is the whole point
    /// (`burncd:2513`).
    ///
    /// **ffmpeg does not dither by default.** `dither_method` is 0 unless it is
    /// asked otherwise, which means a 24-bit source is *truncated* to 16 —
    /// audible as a grainy floor on quiet passages, and silent about it. Every
    /// conversion here says `triangular` outright.
    ///
    /// Any level change goes in **ahead of** the dither and in floating point,
    /// so the gain is applied once at full precision and quantisation happens
    /// exactly once, at the end. It is a plain gain — no compression, no
    /// limiting — which is why it can only go as loud as the headroom allows.
    ///
    /// `gain` is the *text* `LevelDecision.gain(for:)` produced, and the
    /// comparison against `"0.0"` is a string comparison because the script's
    /// is (`burncd:2519`). See `Loudness.format`.
    public static func filter(gain: String) -> String {
        let dither = "aresample=out_sample_fmt=s16:dither_method=triangular"
        guard gain != "0.0" else { return dither }
        return "aformat=sample_fmts=fltp,volume=\(gain)dB,\(dither)"
    }

    /// The whole command line for one track (`burncd:2529`).
    ///
    /// `-ss` goes **before** `-i` and `-t` after it, which is not decoration:
    /// before the input it is a fast seek the demuxer does, after it a decode
    /// of everything up to that point and a discard. On a slice taken forty
    /// minutes into a live set that is the difference between a second and a
    /// minute.
    ///
    /// `-map a:0` and not `-map 0:a` — the first audio stream, and only it. A
    /// file with a cover image in it is a file with a video stream in it, and
    /// a converter that takes every stream will refuse to write one of them
    /// into a raw PCM container.
    /// `file` is passed in rather than read off the entry because a
    /// `PlanDraft` holds no files at all — the editor rearranges names and
    /// nothing else, and the list of sources it indexes into is the record's.
    /// Indexed by `BurnPlan.Entry.source`, exactly as the loudness readings are.
    public static func arguments(
        for entry: BurnPlan.Entry, file: URL, gain: String
    ) -> [String] {
        var arguments = ["-nostdin", "-v", "error"]
        if let offset = entry.offset {
            arguments += ["-ss", String(offset)]
        }
        arguments += ["-i", file.path]
        if let length = entry.length {
            arguments += ["-t", String(length)]
        }
        arguments += [
            "-map", "a:0",
            "-af", filter(gain: gain),
            "-ar", "44100",
            "-ac", "2",
            "-c:a", "pcm_s16le",
            "-f", "s16le", "-",
        ]
        return arguments
    }

    public enum Failure: Error, CustomStringConvertible {
        case noFFmpeg
        case failed(path: String, log: String)

        public var description: String {
            switch self {
            case .noFFmpeg:
                "ffmpeg is needed to convert to CD audio and is not installed"
            case .failed(let path, let log):
                log.isEmpty ? "ffmpeg failed on \(path)" : "ffmpeg failed on \(path)\n\(log)"
            }
        }
    }

    /// Convert one track and append it to the image, sector-aligned
    /// (`burncd:2529–2533`).
    ///
    /// The child writes **straight into the image's own descriptor**. Nothing
    /// is buffered through this process, which on a full disc is 800 MB that
    /// never has to exist anywhere but in the file — and it is why `syncSize`
    /// afterwards asks the filesystem rather than counting: a dup'd descriptor
    /// shares its offset, so the bytes the child wrote are already accounted
    /// for in the handle, and the honest length is the one on disk.
    ///
    /// **stderr goes to a log and not to the caller.** On the panel a stray
    /// ffmpeg warning would print through the middle of the display and be gone
    /// with the next frame; when a conversion does fail, the log is what the
    /// error message is made of, and by then the screen is off.
    @discardableResult
    public static func convert(
        _ entry: BurnPlan.Entry,
        file: URL,
        gain: String,
        into image: ImageWriter,
        ffmpeg: URL,
        log: FileHandle?
    ) throws -> Int {
        image.beginTrack()

        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = arguments(for: entry, file: file, gain: gain)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = image.sink
        let errors = Pipe()
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw Failure.failed(path: file.path, log: "")
        }
        // Drained before waiting: a full pipe with nobody reading it is a
        // process that never exits, and ffmpeg at `-v error` is usually silent
        // right up until the one time it is not.
        let said = (try? errors.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        if !said.isEmpty { try? log?.write(contentsOf: said) }

        guard process.terminationStatus == 0 else {
            throw Failure.failed(
                path: file.path, log: tail(String(decoding: said, as: UTF8.self))
            )
        }

        let before = image.dataBytes
        try image.syncSize()
        let written = image.dataBytes - before
        try image.padToSector()
        return written
    }

    /// The last eight lines, indented — `tail -8 | sed 's/^/    /'`
    /// (`burncd:2534`). Eight because ffmpeg's real complaint is the last thing
    /// it says and everything above it is usually the same complaint about a
    /// different stream.
    static func tail(_ log: String, lines: Int = 8) -> String {
        let all = log.split(separator: "\n").map(String.init)
        return all.suffix(lines).map { "    " + $0 }.joined(separator: "\n")
    }
}

/// §20 stage 2 — is there room for the image before there is an image
/// (`burncd:2405`).
///
/// Uncompressed audio is roughly 10 MB a minute and a full disc is about
/// 800 MB, so a job that will not fit is a job that can be refused in a
/// millisecond instead of discovered after five minutes of decoding, with the
/// scratch directory full and the record half-converted.
public enum TempSpace {

    /// The ten megabytes the script adds on top (`burncd:2409`).
    ///
    /// Not slack for the audio, which is known exactly: it is the cue sheet,
    /// the ffmpeg log, and the fact that a filesystem reporting its last byte
    /// as free is a filesystem nothing should be aimed at.
    public static let margin = 10_485_760

    /// Free bytes on the volume holding `url` (`free_bytes`, `burncd:159`).
    ///
    /// `volumeAvailableCapacityForImportantUsage` and not the raw free count,
    /// because on APFS those are different numbers and the raw one is a lie:
    /// it counts space held by local snapshots and purgeable caches that the
    /// system will hand over when something important asks. A burn is
    /// something important asking. `df` on this platform reports the
    /// pessimistic figure, which would refuse jobs that would in fact have run.
    ///
    /// The URL is rebuilt from its path first because `resourceValues` caches
    /// on the instance, and a free-space figure remembered from earlier in the
    /// job is exactly the figure this check must not use.
    public static func free(at url: URL) -> Int? {
        guard
            let values = try? URL(fileURLWithPath: url.path).resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey]
            ),
            let available = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return Int(available)
    }

    /// `%.1f GB` (`human`, `burncd:158`). In gigabytes whatever the size,
    /// because the number it is comparing against is always most of one.
    public static func human(_ bytes: Int) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    public struct TooSmall: Error, CustomStringConvertible {
        public let disc: Int
        public let need: Int
        public let have: Int
        public let directory: String

        /// Both lines of the script's message, because the second line is the
        /// entire remedy (`burncd:2412`).
        public var description: String {
            """
            disc \(disc) needs \(TempSpace.human(need)) of temp space, only \
            \(TempSpace.human(have)) free
              in \(directory). Free some space or set MUTHUR_WORK to a bigger volume.
            """
        }
    }

    /// Refuse now rather than at ninety percent.
    ///
    /// A volume that will not say how much room it has is not a reason to
    /// refuse: the check is a courtesy and the write is the authority. Better
    /// to try and fail honestly than to decline a burn on a filesystem this
    /// port has not met.
    public static func check(disc: Int, seconds: Int, in directory: URL) throws {
        let need = seconds * BurnLimits.bytesPerSecond + margin
        guard let have = free(at: directory) else { return }
        guard have >= need else {
            throw TooSmall(disc: disc, need: need, have: have, directory: directory.path)
        }
    }
}
