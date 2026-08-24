import AVFoundation
import Foundation

/// One track, open, handing back PCM **in whatever format it is really in**.
///
/// The format is deliberately not negotiable here. §6 requires a seam between
/// two files that disagree on sample rate to be bridged, and the way that is
/// done is to convert once, in one place, with one converter that survives the
/// seam — see `Feeder`. A source that quietly resampled on the way out would put
/// a second, shorter-lived converter in the path and there would be nothing left
/// to carry across the boundary.
protocol AudioSource: AnyObject {
    /// Float32, deinterleaved, at the file's own rate and channel count.
    var format: AVAudioFormat { get }
    /// Frames, or `nil` where the decoder will only say when it gets there.
    var length: AVAudioFramePosition? { get }
    /// Up to `buffer.frameCapacity` frames. Zero means the file is finished.
    @discardableResult
    func read(into buffer: AVAudioPCMBuffer) throws -> AVAudioFrameCount
    func seek(toFrame frame: AVAudioFramePosition) throws
    func close()
}

/// The two ways a track can refuse to play, which §6.3 says different sentences
/// about. The distinction is drawn by stat-ing the record, not by reading the
/// error — see `PlaybackEngine.failureStatus`.
public enum PlaybackFailure: Error, Equatable {
    /// Nothing could open it, and here is what the last decoder said.
    case unreadable(url: URL, reason: String)
    /// No decoder on this machine handles it — `ffmpeg` is not installed and
    /// AVFoundation declined. §17's "no ffmpeg" path, at the moment it bites.
    case noDecoder(url: URL)

    public var reason: String {
        switch self {
        case .unreadable(_, let reason): reason
        case .noDecoder: "NO DECODER"
        }
    }
}

/// AVFoundation first, `ffmpeg` behind it — the same shape as §3's metadata
/// chain, and for the same reason: one decoder handles everything anybody
/// actually owns, and the other exists so that the two formats it refuses
/// outright are not a hole in the program.
enum AudioSourceOpener {

    /// What AVFoundation will not take. Asking it anyway costs an exception and
    /// a line of console noise per track, and the answer is never yes.
    static let fallbackExtensions: Set<String> = ["opus", "ogg", "ape", "wma"]

    static func open(_ url: URL) throws -> any AudioSource {
        var lastReason = "NO DECODER"

        if !fallbackExtensions.contains(url.pathExtension.lowercased()) {
            do {
                return try AVAudioFileSource(url: url)
            } catch {
                lastReason = shortened(error)
            }
        }

        guard let ffmpeg = Tooling.locate("ffmpeg"), let ffprobe = Tooling.locate("ffprobe")
        else {
            throw PlaybackFailure.noDecoder(url: url)
        }
        do {
            return try FFmpegSource(url: url, ffmpeg: ffmpeg, ffprobe: ffprobe)
        } catch let failure as PlaybackFailure {
            // Keep whichever decoder had something to say. AVFoundation's
            // message names the format; ffmpeg's names the file.
            if case .unreadable(_, let reason) = failure { lastReason = reason }
            throw PlaybackFailure.unreadable(url: url, reason: lastReason)
        }
    }

    /// The panel has one line for this and it is shared with the rest of the
    /// sentence. `OSStatus error 1954115647` is not worse than the paragraph
    /// AVFoundation would otherwise give, but it does have to fit.
    static func shortened(_ error: any Error) -> String {
        let text = (error as NSError).localizedDescription
            .replacingOccurrences(of: "\n", with: " ")
            .uppercased()
        return text.count > 60 ? String(text.prefix(59)) + "…" : text
    }
}

// MARK: - AVFoundation

/// The ordinary path: everything except Opus and Ogg.
final class AVAudioFileSource: AudioSource {
    private let file: AVAudioFile

    var format: AVAudioFormat { file.processingFormat }
    var length: AVAudioFramePosition? { file.length }

    init(url: URL) throws {
        // Float32 deinterleaved is what the rest of the graph is in, and asking
        // for it here is free — `AVAudioFile` decodes into whatever processing
        // format it is given.
        file = try AVAudioFile(
            forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false
        )
    }

    func read(into buffer: AVAudioPCMBuffer) throws -> AVAudioFrameCount {
        // Asked for frames when there are none left, `AVAudioFile` does not
        // hand back an empty buffer — it fails, and with no error attached. The
        // end of every track would arrive at the engine looking exactly like
        // §6.3's unreadable file. The file knows how long it is; ask it.
        guard file.framePosition < file.length else {
            buffer.frameLength = 0
            return 0
        }
        try file.read(into: buffer)
        return buffer.frameLength
    }

    func seek(toFrame frame: AVAudioFramePosition) throws {
        file.framePosition = max(0, min(frame, file.length))
    }

    func close() {}
}
