import AVFoundation
import Foundation

/// What has been handed to the player node, and where each part of it came from.
///
/// This is §6's "one source of truth for what is playing" (`player:2461`). The
/// engine reads ahead by a couple of seconds, so at any moment the *next* track
/// is already decoded and scheduled while the current one is still coming out of
/// the speakers. Nothing may therefore assume a track change when it queues one;
/// what is playing is derived from where the render head is in this map, which
/// means a track that simply ran out and a track picked with the cursor arrive by
/// exactly the same route and cannot come to disagree.
struct Timeline {

    struct Segment: Equatable {
        /// Frame in the output stream, counted from the last discontinuity.
        var start: AVAudioFramePosition
        var frames: AVAudioFramePosition
        var row: Int
        /// Frame within the track at `start`, in canonical frames.
        var offset: AVAudioFramePosition
        /// Which *playing* of this row this is. A record on REPEAT TRACK comes
        /// round to the same row over and over, and "the track changed" has to
        /// stay true each time — comparing rows alone would miss every loop.
        var visit: Int

        var end: AVAudioFramePosition { start + frames }
    }

    private(set) var segments: [Segment] = []
    /// The first frame nothing has been scheduled for yet.
    private(set) var end: AVAudioFramePosition = 0

    var isEmpty: Bool { segments.isEmpty }

    mutating func reset() {
        segments.removeAll(keepingCapacity: true)
        end = 0
    }

    /// Consecutive buffers off the same track are one segment. The engine hands
    /// over a few hundred milliseconds at a time, so a five-minute track would
    /// otherwise be a thousand entries to search through for no gain.
    mutating func append(
        frames: AVAudioFramePosition, row: Int, offset: AVAudioFramePosition, visit: Int
    ) {
        guard frames > 0 else { return }
        if var last = segments.last,
            last.row == row,
            last.visit == visit,
            last.offset + last.frames == offset
        {
            last.frames += frames
            segments[segments.count - 1] = last
        } else {
            segments.append(
                Segment(start: end, frames: frames, row: row, offset: offset, visit: visit)
            )
        }
        end += frames
    }

    /// The segment the head is in. Past the end it is the last one, because the
    /// last thing played is still what you are looking at.
    func segment(at frame: AVAudioFramePosition) -> Segment? {
        guard !segments.isEmpty else { return nil }
        if frame < segments[0].start { return segments[0] }
        var low = 0
        var high = segments.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if segments[mid].start <= frame { low = mid } else { high = mid - 1 }
        }
        return segments[low]
    }

    /// Drop what the head has gone past. The stream is unbounded — a record is
    /// an hour of frames — and nothing ever looks backwards.
    mutating func trim(before frame: AVAudioFramePosition) {
        guard segments.count > 1 else { return }
        var keep = 0
        while keep + 1 < segments.count, segments[keep + 1].start <= frame { keep += 1 }
        if keep > 0 { segments.removeFirst(keep) }
    }
}
