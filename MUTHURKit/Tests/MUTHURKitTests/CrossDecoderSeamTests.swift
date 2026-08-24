import AVFoundation
import Foundation
import Testing

@testable import MUTHURKit

/// §17's cross-decoder seam: one side of the join read by AVFoundation, the
/// other by `ffmpeg`.
///
/// This is the seam the fallback decoder creates and nothing else does — a
/// folder holding a WAV and an Opus is an ordinary enough thing to have, and the
/// two tracks arrive by entirely different routes: one through `AVAudioFile`, one
/// down a pipe out of another process. `FFmpegSource` decoding at the file's
/// **native** rate rather than at the record's is what makes this seam ordinary:
/// both sides present the same source format, so the graph never finds out which
/// decoder produced which frames.
///
/// Opus is lossy, so there is no sample-exact claim to make here. The claim is
/// that the *join* is no worse than the codec is anyway, and that no frames go
/// missing across it — which for a decoder that is a subprocess and a pipe is the
/// thing worth proving.
@Suite("§17 Cross-decoder seam", .enabled(if: CrossDecoderSeam.available))
struct CrossDecoderSeamTests {

    static let rate: Double = 48000  // Opus's own rate; anything else it resamples
    static let frequency: Double = 480

    @Test("WAV → Opus: no frames lost, and no step at the join")
    func wavToOpus() async throws {
        let folder = try ToneFolder()
        let a = folder.file("a.wav")
        let b = folder.file("b.opus")
        try Seam.writeTone(
            to: a, rate: Self.rate, frequency: Self.frequency, frames: 96000, startTime: 0
        )
        try CrossDecoderSeam.writeOpus(
            to: b, rate: Self.rate, frequency: Self.frequency, frames: 96000, startTime: 2,
            in: folder
        )

        let engine = PlaybackEngine(offline: true)
        try await engine.load(recordOf([(a, 2), (b, 2)]))
        // Both files are 48 k stereo, so the record is too and no converter is in
        // the path — the seam is a buffer boundary and nothing else.
        #expect(await engine.canonicalFormatDescription == "48000 Hz · 2 ch")

        await engine.pick(row: 0)
        let capture = try await engine.renderToEnd(limitSeconds: 30)
        let samples = capture.channels[0]

        let report = Seam.report(
            capture: samples, rate: Self.rate, frequency: Self.frequency,
            expectedFrames: 192000, seamFrame: 96000
        )
        // The floor here is Opus, not arithmetic — it is reported so the seam
        // number can be read against something.
        let codec = Seam.worstError(
            samples, rate: Self.rate, frequency: Self.frequency,
            over: 120000..<min(samples.count, 168000)
        )
        print(
            String(
                format: "SEAM | cross-decoder (WAV → Opus) | %@ · opus's own error %.1f dBFS (%.3g)",
                report.description as NSString, Seam.decibels(codec), codec
            )
        )

        // A pipe that lost a buffer, or a pre-skip the decoder did not account
        // for, both show up here and nowhere else.
        #expect(
            abs(report.framesLost) <= 1,
            "frames went missing across the decoder boundary: \(report.description)"
        )
        // The one that means *click*.
        #expect(
            report.steepness < 1.1,
            "there is a step where the decoder changed: \(report.description)"
        )
        // And the join is no worse than the codec is in the middle of a track,
        // which is the only fair thing to hold a lossy file to.
        #expect(
            report.seam < codec * 3,
            "the join is worse than Opus is anyway: \(report.description), codec \(codec)"
        )
    }

    /// The other way round, because the two decoders' edges are not the same
    /// shape and a record can begin on either kind of file.
    @Test("Opus → WAV: no frames lost, and no step at the join")
    func opusToWav() async throws {
        let folder = try ToneFolder()
        let a = folder.file("a.opus")
        let b = folder.file("b.wav")
        try CrossDecoderSeam.writeOpus(
            to: a, rate: Self.rate, frequency: Self.frequency, frames: 96000, startTime: 0,
            in: folder
        )
        try Seam.writeTone(
            to: b, rate: Self.rate, frequency: Self.frequency, frames: 96000, startTime: 2
        )

        let engine = PlaybackEngine(offline: true)
        try await engine.load(recordOf([(a, 2), (b, 2)]))
        await engine.pick(row: 0)
        let capture = try await engine.renderToEnd(limitSeconds: 30)
        let samples = capture.channels[0]

        let report = Seam.report(
            capture: samples, rate: Self.rate, frequency: Self.frequency,
            expectedFrames: 192000, seamFrame: 96000
        )
        let codec = Seam.worstError(
            samples, rate: Self.rate, frequency: Self.frequency, over: 24000..<72000
        )
        print(
            String(
                format: "SEAM | cross-decoder (Opus → WAV) | %@ · opus's own error %.1f dBFS (%.3g)",
                report.description as NSString, Seam.decibels(codec), codec
            )
        )

        #expect(abs(report.framesLost) <= 1, "\(report.description)")
        #expect(report.steepness < 1.1, "\(report.description)")
        #expect(report.seam < codec * 3, "\(report.description), codec \(codec)")
    }
}

/// Making an Opus file, which is scaffolding and not the app's business.
enum CrossDecoderSeam {

    static var available: Bool {
        Fixtures.locate("ffmpeg") != nil && Fixtures.locate("ffprobe") != nil
    }

    /// The same tone `Seam.writeTone` writes, encoded to Opus by way of a WAV.
    /// Opus is 48 k internally; anything else and the encoder resamples and the
    /// test is measuring that instead.
    static func writeOpus(
        to url: URL, rate: Double, frequency: Double, frames: Int, startTime: Double,
        in folder: borrowing ToneFolder
    ) throws {
        let intermediate = folder.file("\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: intermediate) }
        try Seam.writeTone(
            to: intermediate, rate: rate, frequency: frequency, frames: frames,
            startTime: startTime
        )

        guard let ffmpeg = Fixtures.locate("ffmpeg") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let encode = Process()
        encode.executableURL = ffmpeg
        encode.arguments = [
            "-v", "error", "-nostdin", "-i", intermediate.path,
            "-c:a", "libopus", "-b:a", "256k", "-vbr", "off",
            "-y", url.path,
        ]
        encode.standardOutput = FileHandle.nullDevice
        encode.standardError = FileHandle.nullDevice
        try encode.run()
        encode.waitUntilExit()
        guard encode.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}
