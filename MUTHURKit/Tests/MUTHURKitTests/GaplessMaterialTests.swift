import AVFoundation
import Foundation
import Testing

@testable import MUTHURKit

/// §6 against a record somebody actually mastered.
///
/// The synthetic suites prove the arithmetic of a seam. These prove it survives
/// contact with a real file: an ambient record whose audio runs continuously
/// across the track boundary, which is the one case where a seam is not hidden
/// by the music stopping anyway.
///
/// Nothing here assumes a rate — the fixture is whichever record is to hand, and
/// what it is gets asked rather than asserted. All that is claimed is that a
/// record whose tracks share one format needs no converter and must therefore
/// come out *identical*, and that the join is not a step.
///
/// Gated on the material being present, so a fresh clone is green rather than
/// red about somebody else's record collection.
@Suite("§6 Gapless — real material")
struct GaplessMaterialTests {

    static let seam = Fixtures.continuousSeam()

    /// Every sample the engine produced is the sample that was in the file, and
    /// there are exactly as many of them as the two files hold between them.
    ///
    /// Both halves come off one record, so they share a format and the record's
    /// canonical format is that format — no converter is in the path at all, and
    /// *exact* is the only acceptable answer here. Not "below audibility";
    /// identical.
    @Test(
        "A real album seam is the concatenation of its two tracks, sample for sample",
        .enabled(if: GaplessMaterialTests.seam != nil)
    )
    func realSeamIsExact() async throws {
        let (before, after) = try #require(Self.seam)
        let native = try format(of: before)

        let first = try decode(before)
        let second = try decode(after)
        #expect(first.count > Int(native.sampleRate), "the fixture is too short to be a seam")
        #expect(second.count > Int(native.sampleRate), "the fixture is too short to be a seam")

        let engine = PlaybackEngine(offline: true)
        try await engine.load(record(first.count, second.count, at: native.sampleRate))

        // One record, one format: whatever the album's rate is, that is the
        // canonical rate, and the direct path is the one being exercised.
        #expect(
            await engine.canonicalFormatDescription
                == "\(Int(native.sampleRate)) Hz · \(native.channelCount) ch"
        )

        await engine.pick(row: 0)
        let capture = try await engine.renderToEnd(limitSeconds: 120)
        let played = capture.channels[0]

        #expect(
            played.count == first.count + second.count,
            "frames \(played.count) against \(first.count + second.count)"
        )

        // Sample for sample against the two files decoded separately. Anything
        // the engine inserted, dropped or altered anywhere in the record fails
        // here, and it fails at the frame it happened.
        let expected = first + second
        var firstDifference: Int?
        for n in 0..<min(played.count, expected.count) where played[n] != expected[n] {
            firstDifference = n
            break
        }
        #expect(
            firstDifference == nil,
            "output diverges from the files at frame \(firstDifference ?? -1)"
        )
    }

    /// The listening test, done with arithmetic.
    ///
    /// A click is a step from one sample to the next that the music was never
    /// going to make. There is no ideal to subtract from real material, so the
    /// music is asked what it is entitled to: the largest step anywhere inside
    /// either track. If the join is no steeper than that, there is nothing at
    /// the join that is not already all over the record.
    @Test(
        "The join is no steeper than the music either side of it",
        .enabled(if: GaplessMaterialTests.seam != nil)
    )
    func realSeamHasNoStep() async throws {
        let (before, after) = try #require(Self.seam)
        let native = try format(of: before)
        let rate = Int(native.sampleRate)

        let first = try decode(before)
        let second = try decode(after)

        let engine = PlaybackEngine(offline: true)
        try await engine.load(record(first.count, second.count, at: native.sampleRate))
        await engine.pick(row: 0)
        let capture = try await engine.renderToEnd(limitSeconds: 120)
        let played = capture.channels[0]
        let boundary = first.count

        // What the music does on its own, measured a tenth of a second clear of
        // the join so the join cannot flatter itself by borrowing from it.
        let natural = max(
            Seam.worstStep(played, over: 1..<(boundary - rate / 10)),
            Seam.worstStep(played, over: (boundary + rate / 10)..<played.count)
        )
        let join = Seam.worstStep(played, over: (boundary - 2)..<(boundary + 2))

        print(
            String(
                format: "SEAM | real material (%@) | frames %d · join step %.3g"
                    + " · music's own %.3g · ratio %.4f",
                before.deletingLastPathComponent().lastPathComponent as NSString,
                played.count, join, natural, natural > 0 ? join / natural : 0
            )
        )

        #expect(natural > 0, "the fixture is silence and proves nothing")
        #expect(join <= natural, "the join is steeper than anything in the music")
    }

    // MARK: - Scaffolding

    /// The two halves as a two-track record, with the durations the files
    /// actually have rather than whatever §3 would guess.
    private func record(_ first: Int, _ second: Int, at rate: Double) -> Record {
        let (before, after) = Self.seam!
        return recordOf(
            [(before, Int(Double(first) / rate)), (after, Int(Double(second) / rate))],
            label: before.deletingLastPathComponent().lastPathComponent
        )
    }

    private func format(of url: URL) throws -> AVAudioFormat {
        try AVAudioFile(forReading: url).processingFormat
    }

    /// Both files decoded straight, with no engine involved — the reference the
    /// capture is held against.
    private func decode(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(
            forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false
        )
        var out: [Float] = []
        out.reserveCapacity(Int(file.length))
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 65536)!
        while file.framePosition < file.length {
            try file.read(into: buffer)
            guard buffer.frameLength > 0 else { break }
            out.append(
                contentsOf: UnsafeBufferPointer(
                    start: buffer.floatChannelData![0], count: Int(buffer.frameLength)
                )
            )
        }
        return out
    }
}
