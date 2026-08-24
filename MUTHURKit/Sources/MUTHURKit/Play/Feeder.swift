import AVFoundation
import Foundation

/// Where the record turns into one continuous stream of samples.
///
/// The engine never asks this for "the next track"; it asks for the next few
/// hundred milliseconds, and hands over a new file when the current one runs
/// out. Two things follow from that shape, and they are the whole of §6's
/// gapless requirement:
///
/// 1. **A buffer never spans two tracks.** The seam always lands on a buffer
///    boundary, which is exactly where `AVAudioPlayerNode` joins consecutively
///    scheduled buffers with nothing in between. It also keeps the timeline
///    honest — every buffer belongs to one row and one offset into it.
///
/// 2. **The converter outlives the track.** When the next file's native format
///    matches the one the converter was built for, the converter is *kept*: its
///    filter history still holds the tail of the track that just ended, so the
///    first frames of the next track are resampled with the previous track's
///    samples in the delay line. That is not merely a gap of zero — it is the
///    same output a single file containing both tracks would have produced. A
///    run of 44.1k tracks on a 48k record is resampled as one stream.
///
/// Only a genuine change of source format tears the converter down, and that is
/// the one seam that cannot be made sample-continuous by any means: the two
/// sides are different signals. What is preserved there is the *timing* — the
/// frame counts come out exact, so no silence is inserted and no frames are
/// dropped — leaving the resampler's edge response and nothing else. It is
/// measured rather than claimed; see `docs/parity.md`.
final class Feeder {
    let canonical: AVAudioFormat

    /// The row the open file belongs to, and how far into it, in canonical
    /// frames. The offset is counted in *output* frames because that is what the
    /// timeline and both meters are denominated in.
    private(set) var row: Int = -1
    private(set) var offset: AVAudioFramePosition = 0

    private var source: (any AudioSource)?
    private var converter: AVAudioConverter?
    /// The format the converter was built for — the outgoing track's, until a
    /// new track proves it still matches.
    private var converterInput: AVAudioFormat?
    /// Held for the length of a `convert` call: the converter reads from it
    /// after the input block has returned.
    private var scratch: AVAudioPCMBuffer?

    init(canonical: AVAudioFormat) {
        self.canonical = canonical
    }

    deinit { close() }

    var isOpen: Bool { source != nil }

    // MARK: - Opening

    /// A discontinuous start: `⏎`, a seek across a boundary, the first track of
    /// the record. Everything the converter was holding belonged to a stream
    /// that is not being played any more, so it goes.
    func open(row: Int, url: URL, atFrame frame: AVAudioFramePosition) throws {
        close()
        let source = try AudioSourceOpener.open(url)
        if frame > 0 {
            try source.seek(toFrame: nativeFrame(frame, in: source.format))
        }
        self.source = source
        self.row = row
        self.offset = frame
    }

    /// The seam. The next file in the running order, opened while the previous
    /// one's samples are still in flight.
    ///
    /// Returns the outgoing track's tail where the converter had to be flushed —
    /// the last few frames the resampler was still holding, which belong to the
    /// track being left and must be scheduled before the new one's. Where the
    /// two files agree on rate and channels there is no tail, because there is
    /// nothing to flush: the converter carries straight on.
    func follow(row: Int, url: URL) throws -> Step? {
        let next = try AudioSourceOpener.open(url)

        var tail: Step?
        if let converterInput, !sameStream(converterInput, next.format) {
            tail = flushTail()
        }
        source?.close()
        source = next
        self.row = row
        self.offset = 0
        return tail
    }

    /// Same track, from the top — REPEAT TRACK's loop (§6.1). The decoder
    /// rewinds; nothing is reopened, because a file opened at the moment the
    /// previous one ended is a file being opened during the silence.
    func rewind() throws {
        guard let source else { return }
        try source.seek(toFrame: 0)
        offset = 0
    }

    /// Within the open track. The converter's history is now describing samples
    /// that are not adjacent to what comes next, so it goes — a seek is a
    /// discontinuity by definition and there is nothing to preserve across it.
    func seek(toFrame frame: AVAudioFramePosition) throws {
        guard let source else { return }
        converter = nil
        converterInput = nil
        try source.seek(toFrame: nativeFrame(frame, in: source.format))
        offset = frame
    }

    func close() {
        source?.close()
        source = nil
        converter = nil
        converterInput = nil
        scratch = nil
        row = -1
        offset = 0
    }

    // MARK: - Producing

    enum Step {
        /// Canonical PCM, all of it belonging to `row` starting at `offset`.
        case produced(AVAudioPCMBuffer, row: Int, offset: AVAudioFramePosition)
        /// The open track is finished. The engine decides what follows.
        case exhausted
        /// Nothing open.
        case idle
    }

    func produce(frames: AVAudioFrameCount) throws -> Step {
        guard let source else { return .idle }
        let start = offset

        let buffer: AVAudioPCMBuffer?
        if sameStream(source.format, canonical) {
            // The common case, and the reason it is worth testing for: no
            // converter at all, so the samples reaching the player node are the
            // samples in the file, and a seam between two such tracks is exact
            // by construction rather than by measurement.
            buffer = try readDirect(source, frames: frames)
        } else {
            buffer = try readConverted(source, frames: frames)
        }

        guard let buffer, buffer.frameLength > 0 else { return .exhausted }
        offset += AVAudioFramePosition(buffer.frameLength)
        return .produced(buffer, row: row, offset: start)
    }

    /// The last frames the resampler is holding, at the end of the record or at
    /// a change of source format. Called by the engine so the record does not
    /// end a few milliseconds early.
    ///
    /// The tail belongs to the track being *left*, so it comes back stamped with
    /// that row and offset rather than with whatever is being opened.
    func flushTail() -> Step? {
        guard let converter else { return nil }
        let out = AVAudioPCMBuffer(pcmFormat: canonical, frameCapacity: 8192)!
        var error: NSError?
        _ = converter.convert(to: out, error: &error) { _, status in
            status.pointee = .endOfStream
            return nil
        }
        self.converter = nil
        self.converterInput = nil
        guard out.frameLength > 0 else { return nil }
        let start = offset
        offset += AVAudioFramePosition(out.frameLength)
        return .produced(out, row: row, offset: start)
    }

    // MARK: - The two reads

    private func readDirect(
        _ source: any AudioSource, frames: AVAudioFrameCount
    ) throws -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: canonical, frameCapacity: frames) else {
            return nil
        }
        let read = try source.read(into: buffer)
        return read > 0 ? buffer : nil
    }

    /// See `readConverted`. Unchecked because the promise being relied on is
    /// AVAudioConverter's, not Swift's: the block runs synchronously inside
    /// `convert` and nothing else ever touches this.
    private final class Pull: @unchecked Sendable {
        weak var feeder: Feeder?
        var thrown: (any Error)?
        init(feeder: Feeder) { self.feeder = feeder }
    }

    private func readConverted(
        _ source: any AudioSource, frames: AVAudioFrameCount
    ) throws -> AVAudioPCMBuffer? {
        let converter = try converter(for: source.format)
        guard let out = AVAudioPCMBuffer(pcmFormat: canonical, frameCapacity: frames) else {
            return nil
        }

        // The input block is declared `@Sendable` and is not: the converter
        // calls it on this thread, from inside `convert`, and has finished with
        // it before `convert` returns. The box carries what the block learned
        // back out across a promise the framework makes and the type system
        // cannot see.
        let pull = Pull(feeder: self)
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { need, inputStatus in
            guard let feeder = pull.feeder, let source = feeder.source else {
                inputStatus.pointee = .endOfStream
                return nil
            }
            let input = feeder.scratchBuffer(for: source.format, frames: need)
            let read: AVAudioFrameCount
            do {
                read = try source.read(into: input)
            } catch {
                pull.thrown = error
                inputStatus.pointee = .endOfStream
                return nil
            }
            guard read > 0 else {
                // Not `.endOfStream`: the converter must be left holding this
                // track's tail so the *next* track can be fed straight into it.
                // Saying the stream ended here is what would cost the seam.
                inputStatus.pointee = .noDataNow
                return nil
            }
            inputStatus.pointee = .haveData
            return input
        }

        if let thrown = pull.thrown { throw thrown }
        if status == .error, let error { throw error }
        return out.frameLength > 0 ? out : nil
    }

    private func converter(for input: AVAudioFormat) throws -> AVAudioConverter {
        if let converter, let converterInput, sameStream(converterInput, input) {
            return converter
        }
        guard let made = AVAudioConverter(from: input, to: canonical) else {
            throw PlaybackFailure.unreadable(
                url: URL(fileURLWithPath: "/"),
                reason: "CANNOT CONVERT \(Int(input.sampleRate)) HZ"
            )
        }
        // `.normal` is the zero-latency one, and the naming is a trap:
        // `.none` means *no priming*, which puts the filter's whole group delay
        // — 1253 frames, 26 ms — in front of the stream as latency. Harmless on
        // a record that is one long conversion, fatal at a seam where a
        // converter is built: those 26 ms arrive as silence between two tracks,
        // which is precisely the gap §6 forbids. Measured before it was
        // believed; see `docs/parity.md`.
        made.primeMethod = .normal
        made.sampleRateConverterQuality = AVAudioQuality.max.rawValue
        made.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
        converter = made
        converterInput = input
        return made
    }

    private func scratchBuffer(
        for format: AVAudioFormat, frames: AVAudioFrameCount
    ) -> AVAudioPCMBuffer {
        if let scratch, sameStream(scratch.format, format), scratch.frameCapacity >= frames {
            scratch.frameLength = 0
            return scratch
        }
        let made = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: max(frames, 8192)
        )!
        scratch = made
        return made
    }

    // MARK: - Arithmetic

    /// Two formats are the same *stream* when a decoder handing samples to the
    /// other one would be indistinguishable. Rate and channel count, not
    /// `isEqual` — two `AVAudioFormat`s built the same way by different routes
    /// can carry different channel layout objects and compare unequal while
    /// describing identical audio.
    private func sameStream(_ a: AVAudioFormat, _ b: AVAudioFormat) -> Bool {
        a.sampleRate == b.sampleRate && a.channelCount == b.channelCount
    }

    /// Offsets are canonical frames; decoders seek in their own.
    private func nativeFrame(
        _ frame: AVAudioFramePosition, in format: AVAudioFormat
    ) -> AVAudioFramePosition {
        guard format.sampleRate != canonical.sampleRate else { return frame }
        return AVAudioFramePosition(
            (Double(frame) * format.sampleRate / canonical.sampleRate).rounded()
        )
    }
}
