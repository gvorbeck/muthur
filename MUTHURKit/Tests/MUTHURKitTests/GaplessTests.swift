import AVFoundation
import Foundation
import Testing

@testable import MUTHURKit

/// §6. The evidence, not the claim.
@Suite("§6 Gapless — measured")
struct GaplessTests {

    /// 441 Hz at 44.1 k and 48 k alike is a whole number of cycles per second
    /// and lands nowhere near either Nyquist, so nothing in the measurement is
    /// fighting the resampler's roll-off.
    static let frequency: Double = 441

    @Test("A float tone survives the round trip through the file")
    func fileRoundTrip() throws {
        let folder = try ToneFolder()
        let url = folder.file("a.wav")
        try Seam.writeTone(
            to: url, rate: 44100, frequency: Self.frequency, frames: 44100, startTime: 0
        )

        let file = try AVAudioFile(
            forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false
        )
        let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat, frameCapacity: 44100
        )!
        try file.read(into: buffer)

        var samples = [Float](
            UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
        )
        #expect(samples.count == 44100)

        // If the writer quantised to 16 bits this residual sits around 2⁻¹⁵ and
        // everything downstream would be measuring the file format rather than
        // the seam.
        let worst = Seam.worstError(
            samples, rate: 44100, frequency: Self.frequency, over: 0..<samples.count
        )
        #expect(
            worst < 1e-5,
            "written tone is not float-clean: \(Seam.decibels(worst)) dBFS"
        )
        samples.removeAll()
    }

    /// The control. Two files at one rate, so no converter is in the path at
    /// all, and the seam must be *exact* — not small, zero.
    @Test("Same-rate seam: sample-exact")
    func sameRateSeam() async throws {
        let folder = try ToneFolder()
        let rate: Double = 44100
        let firstFrames = Int(rate) * 2
        let secondFrames = Int(rate) * 2

        let a = folder.file("a.wav")
        let b = folder.file("b.wav")
        try Seam.writeTone(
            to: a, rate: rate, frequency: Self.frequency, frames: firstFrames, startTime: 0
        )
        try Seam.writeTone(
            to: b, rate: rate, frequency: Self.frequency, frames: secondFrames,
            startTime: Double(firstFrames) / rate
        )

        let engine = PlaybackEngine(offline: true)
        try await engine.load(recordOf([(a, 2), (b, 2)]))
        #expect(await engine.canonicalFormatDescription == "44100 Hz · 2 ch")

        await engine.pick(row: 0)
        let capture = try await engine.renderToEnd(limitSeconds: 30)

        let report = Seam.report(
            capture: capture.channels[0],
            rate: rate,
            frequency: Self.frequency,
            expectedFrames: firstFrames + secondFrames,
            seamFrame: firstFrames
        )
        SeamLog.record("same rate (44.1 k → 44.1 k)", report)

        #expect(report.actualFrames == report.expectedFrames)
        #expect(report.seam < 1e-6, "same-rate seam is not exact: \(report.description)")
        #expect(report.spread.isEmpty, "\(report.description)")
        #expect(report.steepness < 1.001, "\(report.description)")
    }

    /// The hard one, and both halves of it in a single record.
    ///
    /// Three tracks: 44.1 k, 44.1 k, 48 k. The record's canonical rate is its
    /// highest, so the first two are resampled and the third is not.
    ///
    /// - The **first** seam is between two tracks the converter can carry
    ///   straight across, because they present it the same source format. Its
    ///   filter history still holds the tail of track one when track two's first
    ///   sample goes in. Nothing about this seam should be visible at all — it
    ///   should measure the same as the middle of a track.
    /// - The **second** seam is the irreducible case: the two sides really are
    ///   different streams and the converter has to be torn down. What survives
    ///   is the timing; what is left is the resampler's edge response, and that
    ///   is the number worth publishing.
    @Test("Mixed-rate seam: 44.1 k → 44.1 k → 48 k on a 48 k record")
    func mixedRateSeam() async throws {
        let folder = try ToneFolder()
        let a = folder.file("a.wav")  // 44.1 k, t ∈ [0, 2)
        let b = folder.file("b.wav")  // 44.1 k, t ∈ [2, 4)
        let c = folder.file("c.wav")  // 48 k,   t ∈ [4, 6)
        try Seam.writeTone(to: a, rate: 44100, frequency: Self.frequency, frames: 88200, startTime: 0)
        try Seam.writeTone(to: b, rate: 44100, frequency: Self.frequency, frames: 88200, startTime: 2)
        try Seam.writeTone(to: c, rate: 48000, frequency: Self.frequency, frames: 96000, startTime: 4)

        let engine = PlaybackEngine(offline: true)
        try await engine.load(recordOf([(a, 2), (b, 2), (c, 2)]))
        // Never downsample: the record's canonical rate is its highest, so the
        // 48 k track is the one that plays untouched.
        #expect(await engine.canonicalFormatDescription == "48000 Hz · 2 ch")

        await engine.pick(row: 0)
        let capture = try await engine.renderToEnd(limitSeconds: 60)
        let samples = capture.channels[0]

        let carried = Seam.report(
            capture: samples, rate: 48000, frequency: Self.frequency,
            expectedFrames: 96000 * 3, seamFrame: 96000
        )
        SeamLog.record("mixed record, converter carried across (44.1 k → 44.1 k)", carried)

        let rebuilt = Seam.report(
            capture: samples, rate: 48000, frequency: Self.frequency,
            expectedFrames: 96000 * 3, seamFrame: 96000 * 2
        )
        SeamLog.record("mixed record, converter rebuilt (44.1 k → 48 k)", rebuilt)

        // Timing first: whatever the resampler does to the waveform at a seam,
        // it may not insert or eat frames. Exactly, not nearly — the record is
        // one continuous stream and its length is arithmetic.
        #expect(
            carried.framesLost == 0,
            "frames were lost or invented: \(carried.description)"
        )

        // The carried seam is not merely gapless, it is invisible — the same
        // measurement taken in the middle of a track, and nothing anywhere near
        // the boundary disturbed at all.
        #expect(
            carried.seam <= carried.floor * 1.01,
            "carrying the converter across bought nothing: \(carried.description)"
        )
        #expect(carried.spread.isEmpty, "\(carried.description)")

        // The rebuilt seam is the irreducible one and it is *not* zero. What it
        // has to be is inaudible by shape rather than merely small: no step the
        // waveform could not have made by itself — which is what a click is —
        // and the disturbance confined to a few milliseconds on one side.
        #expect(
            rebuilt.steepness < 1.1,
            "there is a step at the seam, which is a click: \(rebuilt.description)"
        )
        #expect(
            rebuilt.seamDB < -50,
            "converter-rebuild seam is worse than it measured: \(rebuilt.description)"
        )
        #expect(
            rebuilt.spreadMilliseconds < 15,
            "the disturbance is wider than a resampler edge: \(rebuilt.description)"
        )
        // Entirely on the outgoing side. This seam is the outgoing converter
        // being flushed against silence; the incoming track is untouched.
        #expect(rebuilt.spread.upperBound <= 0, "\(rebuilt.description)")
    }

    /// The same seam the other way round, because a resampler's edge response is
    /// not symmetric and the record that starts on the 48 k track is just as
    /// likely as the one that ends on it.
    @Test("Mixed-rate seam: 48 k → 44.1 k")
    func mixedRateSeamDownward() async throws {
        let folder = try ToneFolder()
        let a = folder.file("a.wav")  // 48 k,   t ∈ [0, 2)
        let b = folder.file("b.wav")  // 44.1 k, t ∈ [2, 4)
        try Seam.writeTone(to: a, rate: 48000, frequency: Self.frequency, frames: 96000, startTime: 0)
        try Seam.writeTone(to: b, rate: 44100, frequency: Self.frequency, frames: 88200, startTime: 2)

        let engine = PlaybackEngine(offline: true)
        try await engine.load(recordOf([(a, 2), (b, 2)]))
        await engine.pick(row: 0)
        let capture = try await engine.renderToEnd(limitSeconds: 60)

        let report = Seam.report(
            capture: capture.channels[0], rate: 48000, frequency: Self.frequency,
            expectedFrames: 96000 * 2, seamFrame: 96000
        )
        SeamLog.record("mixed record, converter rebuilt (48 k → 44.1 k)", report)

        #expect(report.framesLost == 0, "\(report.description)")
        #expect(report.steepness < 1.1, "there is a step at the seam: \(report.description)")
        #expect(report.seamDB < -50, "\(report.description)")
        #expect(report.spreadMilliseconds < 15, "\(report.description)")
        // The mirror image of the seam above: here it is the *incoming*
        // converter starting with silence in its delay line, so this time the
        // outgoing track is the one left alone.
        #expect(report.spread.lowerBound >= 0, "\(report.description)")
    }
}
