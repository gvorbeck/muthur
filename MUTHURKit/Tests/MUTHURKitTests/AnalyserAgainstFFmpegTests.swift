import AVFoundation
import Foundation
import Testing

@testable import MUTHURKit

/// §9's port, checked against the thing it is a port of.
///
/// Everything in `AnalyserTests` proves the analyser is internally consistent —
/// that a tone lands in its own band and that the arithmetic does what the
/// script's arithmetic did. This proves the *number* is the same number, by
/// running the script's own filter chain, verbatim, over the same samples:
///
///     bandpass=f=<centre>:width_type=o:w=1.1,
///     asetnsamples=n=4410,
///     astats=metadata=1:reset=1
///
/// and reading `lavfi.astats.Overall.RMS_level` out of it, which is exactly what
/// `spectrum_analyse` does (`player:786`).
///
/// Material tier: needs ffmpeg, skipped without it. Nothing is written to the
/// repository and nothing under `cd-collection` is touched — the chain above is
/// typed out here, not read out of the script at runtime.
@Suite("The analyser, against ffmpeg", .enabled(if: Fixtures.locate("ffmpeg") != nil))
struct AnalyserAgainstFFmpegTests {

    /// A signal with something in every band: one tone per band centre, at
    /// amplitudes far enough apart that a per-band scale is the only way to see
    /// all sixteen — which is §9's whole argument, built as a file.
    static func chord(seconds: Double = 3, rate: Double = 44100) -> AVAudioPCMBuffer {
        AnalyserTests.buffer(seconds: seconds, rate: rate, channels: 2) { index in
            var sample = 0.0
            for (band, centre) in Bands.centres.enumerated() {
                // −6 dB a band down the spectrum, which is roughly what a record
                // does and is well over the sixty decibels one scale would have
                // to cover.
                let amplitude = 0.35 * pow(10, -Double(band) * 3 / 20)
                sample += amplitude * sin(2 * .pi * centre * Double(index) / rate)
            }
            return Float(sample / 2)
        }
    }

    /// A directory of its own per file, since every test here tidies up after
    /// itself by removing the directory its file is in and the tests run
    /// alongside one another.
    static func write(_ buffer: AVAudioPCMBuffer) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "muthur-analyser/\(UUID().uuidString)/side.wav")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: buffer.format.sampleRate,
            AVNumberOfChannelsKey: Int(buffer.format.channelCount),
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
        return url
    }

    /// The script's chain, one band, every window of the file.
    static func ffmpegLevels(of url: URL, centre: Double, hop: Int) -> [Double] {
        guard let ffmpeg = Fixtures.locate("ffmpeg") else { return [] }
        let out = url.deletingPathExtension().appendingPathExtension("b\(Int(centre))")
        defer { try? FileManager.default.removeItem(at: out) }

        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = [
            "-v", "error", "-nostdin", "-i", url.path,
            "-af",
            "aresample=44100,bandpass=f=\(Int(centre)):width_type=o:w=1.1,"
                + "asetnsamples=n=\(hop),astats=metadata=1:reset=1,"
                + "ametadata=print:key=lavfi.astats.Overall.RMS_level:file=\(out.path)",
            "-f", "null", "-",
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        process.waitUntilExit()

        guard let text = try? String(contentsOf: out, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            guard line.contains("RMS_level"), let value = line.split(separator: "=").last
            else { return nil }
            // Digital silence comes back as -inf, which would read as 0 dB — the
            // loudest thing there is (`player:819`).
            if value.contains("inf") { return Spectrum.floor }
            return Double(value).map { max(Spectrum.floor, $0) }
        }
    }

    /// One window of one channel, straight off the file.
    static func samples(of url: URL, window: Int, hop: Int) throws -> [[Float]] {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(
            standardFormatWithSampleRate: file.processingFormat.sampleRate,
            channels: file.processingFormat.channelCount
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(hop))!
        file.framePosition = AVAudioFramePosition(window * hop)
        try file.read(into: buffer, frameCount: AVAudioFrameCount(hop))
        return (0..<Int(format.channelCount)).map { channel in
            Array(UnsafeBufferPointer(start: buffer.floatChannelData![channel], count: hop))
        }
    }

    @Test("Sixteen band levels, the same numbers ffmpeg reads")
    func levelsMatch() throws {
        let url = try Self.write(Self.chord())
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let spectrum = Spectrum(rate: 44100)
        #expect(spectrum.hop == 4410)

        // The tenth window: a second in, so the sixteen IIRs have long since
        // settled and there is no start-up transient left in either reading.
        let window = 10
        let ours = spectrum.levels(try Self.samples(of: url, window: window, hop: spectrum.hop))

        for (band, centre) in Bands.centres.enumerated() {
            let theirs = Self.ffmpegLevels(of: url, centre: centre, hop: spectrum.hop)
            try #require(theirs.count > window, "no reading for \(Int(centre)) Hz")

            // A decibel and a half. The two are not the same computation and
            // cannot be: ffmpeg runs an IIR with memory of everything before
            // this window, and this runs one windowed transform of the window
            // itself. On a signal that has settled they agree to well inside
            // what a column an eighth of a cell tall could show.
            #expect(
                abs(ours[band] - theirs[window]) < 1.5,
                "\(Int(centre)) Hz: ours \(ours[band]) dB, ffmpeg \(theirs[window]) dB"
            )
        }
    }

    @Test("A full-scale sine is −3 dB to both of them")
    func fullScaleAgrees() throws {
        let url = try Self.write(AnalyserTests.tone(1000, seconds: 2))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let spectrum = Spectrum(rate: 44100)
        let ours = spectrum.levels(try Self.samples(of: url, window: 10, hop: spectrum.hop))
        let lit = AnalyserTests.band(containing: 1000)
        let theirs = Self.ffmpegLevels(of: url, centre: Bands.centres[lit], hop: spectrum.hop)

        try #require(theirs.count > 10)
        #expect(abs(ours[lit] - (-3.01)) < 0.5)
        #expect(abs(ours[lit] - theirs[10]) < 0.5)
    }

    @Test("Digital silence floors at −90 in both of them")
    func silenceAgrees() throws {
        let url = try Self.write(AnalyserTests.silence(seconds: 2))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let spectrum = Spectrum(rate: 44100)
        let ours = spectrum.levels(try Self.samples(of: url, window: 10, hop: spectrum.hop))
        #expect(ours.allSatisfy { $0 == Spectrum.floor })

        let theirs = Self.ffmpegLevels(of: url, centre: 976, hop: spectrum.hop)
        try #require(theirs.count > 10)
        #expect(theirs[10] == Spectrum.floor)
    }
}
