import AVFoundation
import Foundation

/// The one format the record plays in, decided before the first sample.
///
/// This is the answer to §6's hard box — bridging a seam where the two files
/// disagree on sample rate or channel layout. The move is to take the
/// disagreement **out of the audio graph entirely**. The player node is
/// connected once, in this format, and never reconnected; every track is
/// converted into it by the decoder side; the seam between two tracks is then an
/// ordinary buffer boundary inside one continuous stream, and the graph never
/// finds out the files differed.
///
/// The rate is the record's **highest**, never lower. Downsampling to the
/// commonest rate would throw away the one track somebody went to the trouble of
/// keeping at 96k, and it would do it silently — the meter would look identical.
/// Upsampling the rest costs arithmetic and nothing else.
///
/// Channels: the highest, with a floor of two. Mono records exist and a mono
/// record played into one channel is a fault report, not a mix.
enum CanonicalFormat {

    static let fallbackRate: Double = 44_100
    static let fallbackChannels: AVAudioChannelCount = 2

    /// Probe every file in the running order. Cheap for the ordinary path — an
    /// `AVAudioFile` open is a header read — and one `ffprobe` per Opus track,
    /// which is the price of knowing what the record is before it starts rather
    /// than discovering it at a seam.
    ///
    /// A file that will not probe is **skipped, not fatal**. §6.3 is about a
    /// track that will not open, and it fires when the needle reaches that track,
    /// not while a format is being chosen.
    static func decided(for urls: [URL]) -> AVAudioFormat {
        var rate: Double = 0
        var channels: AVAudioChannelCount = 0

        let ffprobe = Tooling.locate("ffprobe")
        for url in urls {
            guard let format = probe(url, ffprobe: ffprobe) else { continue }
            rate = max(rate, format.rate)
            channels = max(channels, format.channels)
        }

        return format(rate: rate > 0 ? rate : fallbackRate, channels: max(channels, 2))
    }

    private static func probe(_ url: URL, ffprobe: URL?) -> (rate: Double, channels: AVAudioChannelCount)? {
        if !AudioSourceOpener.fallbackExtensions.contains(url.pathExtension.lowercased()),
            let file = try? AVAudioFile(forReading: url)
        {
            let format = file.fileFormat
            return (format.sampleRate, format.channelCount)
        }
        guard let ffprobe, let stream = FFmpegSource.probe(url, ffprobe: ffprobe) else {
            return nil
        }
        return (stream.rate, stream.channels)
    }

    /// Float32, deinterleaved — what `AVAudioPCMBuffer` and vDSP both want, so
    /// §9's analyser can read the same buffers the graph is playing without a
    /// second pass over them.
    static func format(rate: Double, channels: AVAudioChannelCount) -> AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)
            // A channel count `AVAudioFormat` will not describe is a surround
            // file in a music player. Two channels is the honest answer and the
            // converter will fold it.
            ?? AVAudioFormat(
                standardFormatWithSampleRate: rate, channels: fallbackChannels
            )!
    }
}
