import AVFoundation
import Foundation

/// The fallback decoder, for what AVFoundation refuses — Opus and Ogg
/// (`CLAUDE.md`: ffmpeg is a fallback, never the engine).
///
/// It decodes at the file's **native** rate and channel count, not at the
/// record's canonical rate. That is the whole point of putting it here rather
/// than letting ffmpeg resample: an Opus track and a FLAC track that happen to
/// share a rate then present the *same* source format to the `Feeder`, the one
/// converter is kept across the boundary between them, and §17's cross-decoder
/// seam is no different from any other seam. Handing ffmpeg an `-ar` would put a
/// second resampler in the path, one that ends at the end of the file.
///
/// One process per open track, killed on `close`. `-ss` before `-i` is a
/// container seek, so a seek is a respawn — which is what a seek is anyway, and
/// costs the same as opening the file did.
final class FFmpegSource: AudioSource {
    let format: AVAudioFormat
    let length: AVAudioFramePosition?

    private let url: URL
    private let ffmpeg: URL
    private var process: Process?
    private var output: FileHandle?
    private var finished = false

    init(url: URL, ffmpeg: URL, ffprobe: URL) throws {
        self.url = url
        self.ffmpeg = ffmpeg

        guard let stream = FFmpegSource.probe(url, ffprobe: ffprobe) else {
            throw PlaybackFailure.unreadable(url: url, reason: "NO AUDIO STREAM")
        }
        guard
            let format = AVAudioFormat(
                standardFormatWithSampleRate: stream.rate, channels: stream.channels
            )
        else {
            throw PlaybackFailure.unreadable(
                url: url, reason: "\(stream.channels) CHANNELS AT \(Int(stream.rate)) HZ"
            )
        }
        self.format = format
        self.length = stream.duration.map { AVAudioFramePosition(($0 * stream.rate).rounded()) }

        try spawn(fromSeconds: 0)
    }

    deinit { close() }

    // MARK: - Probing

    struct Stream {
        let rate: Double
        let channels: AVAudioChannelCount
        let duration: Double?
    }

    /// The first audio stream, and only the three things the graph needs off it.
    /// §3 already asked this file about its tags; this is a separate question and
    /// deliberately a separate call, because a record is probed once at load and
    /// a track is opened whenever the needle lands on it.
    static func probe(_ url: URL, ffprobe: URL) -> Stream? {
        guard
            let output = Tooling.output(
                ffprobe,
                [
                    "-v", "error", "-select_streams", "a:0",
                    "-show_entries", "stream=sample_rate,channels,duration:format=duration",
                    "-of", "default=nw=1", url.path,
                ]
            )
        else { return nil }

        var rate: Double?
        var channels: AVAudioChannelCount?
        var duration: Double?
        for line in output.split(separator: "\n") {
            guard let split = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<split])
            let value = String(line[line.index(after: split)...])
            guard !value.isEmpty, value != "N/A" else { continue }
            switch key {
            case "sample_rate": rate = Double(value)
            case "channels": channels = UInt32(value)
            // The stream's own duration if it has one, the container's if not —
            // Ogg routinely answers only the second.
            case "duration": if duration == nil { duration = Double(value) }
            default: break
            }
        }
        guard let rate, rate > 0, let channels, channels > 0 else { return nil }
        return Stream(rate: rate, channels: channels, duration: duration)
    }

    // MARK: - The process

    private func spawn(fromSeconds start: Double) throws {
        close()
        finished = false

        let process = Process()
        process.executableURL = ffmpeg
        var arguments = ["-v", "quiet", "-nostdin"]
        if start > 0 { arguments += ["-ss", String(format: "%.6f", start)] }
        arguments += [
            "-i", url.path,
            "-map", "0:a:0", "-vn",
            "-f", "f32le",
            "-acodec", "pcm_f32le",
            // Named, not defaulted: the identity is the contract with `Feeder`.
            "-ar", String(Int(format.sampleRate)),
            "-ac", String(format.channelCount),
            "-",
        ]
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw PlaybackFailure.unreadable(
                url: url, reason: AudioSourceOpener.shortened(error)
            )
        }
        self.process = process
        self.output = pipe.fileHandleForReading
    }

    func close() {
        // Close the read end first: ffmpeg dies on the broken pipe rather than
        // decoding the remaining three hundred megabytes of an AIFF nobody is
        // listening to any more.
        try? output?.close()
        output = nil
        if let process, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        process = nil
    }

    // MARK: - Reading

    func read(into buffer: AVAudioPCMBuffer) throws -> AVAudioFrameCount {
        buffer.frameLength = 0
        guard !finished, let output else { return 0 }

        let channels = Int(format.channelCount)
        let wanted = Int(buffer.frameCapacity) * channels * MemoryLayout<Float>.size
        let data = readUpTo(wanted, from: output)
        // A short read at the end of the stream is normal; a short read that is
        // not a whole frame means the decoder was cut off mid-sample, and the
        // remainder is dropped rather than smeared across the channels.
        let frames = data.count / (channels * MemoryLayout<Float>.size)
        if frames == 0 {
            finished = true
            return 0
        }
        if data.count < wanted { finished = true }

        guard let destination = buffer.floatChannelData else { return 0 }
        data.withUnsafeBytes { raw in
            let source = raw.bindMemory(to: Float.self)
            for channel in 0..<channels {
                let out = destination[channel]
                for frame in 0..<frames {
                    out[frame] = source[frame * channels + channel]
                }
            }
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        return buffer.frameLength
    }

    /// A pipe hands over whatever it has, which is rarely what was asked for.
    /// Loop until the request is met or the writer is gone.
    private func readUpTo(_ count: Int, from handle: FileHandle) -> Data {
        var collected = Data()
        collected.reserveCapacity(count)
        while collected.count < count {
            guard
                let chunk = try? handle.read(upToCount: count - collected.count),
                !chunk.isEmpty
            else { break }
            collected.append(chunk)
        }
        return collected
    }

    func seek(toFrame frame: AVAudioFramePosition) throws {
        try spawn(fromSeconds: max(0, Double(frame) / format.sampleRate))
    }
}
