import Foundation

/// One read of one file (`player:1426`).
///
/// A protocol rather than a function because there are two of these and the
/// choice between them is the stack decision in `CLAUDE.md`: AVFoundation does
/// the work, ffmpeg picks up what AVFoundation will not open. Tests get a
/// third implementation that reads nothing at all, which is how the rules in
/// §3 stay testable without a folder of audio.
public protocol MetadataReader: Sendable {
    func read(_ url: URL) async -> RawMetadata
}

/// Primary, then fallback.
///
/// The fallback runs only when the primary came back with no duration — which
/// is exactly the Opus and Ogg case, where AVFoundation refuses the file
/// outright rather than returning a poor answer. A file neither can read has
/// no duration from either, and gets skipped by `Record` (`player:1443`).
///
/// Known gap: AVFoundation opens a WAV and reports its duration while ignoring
/// an ID3 chunk inside it, so a tagged WAV can come back numbered 9999 and
/// never reach the fallback. FLAC is fine — its Vorbis comments come through
/// whole. Worth revisiting when there is real WAV material to test against.
public struct ChainedMetadataReader: MetadataReader {
    let primary: any MetadataReader
    let fallback: (any MetadataReader)?

    public init(primary: any MetadataReader, fallback: (any MetadataReader)?) {
        self.primary = primary
        self.fallback = fallback
    }

    /// What the app uses: AVFoundation, with ffprobe behind it if this machine
    /// has one. No ffprobe is not an error — it is a smaller set of playable
    /// formats, which is a thing §11 diagnostics exists to say out loud.
    public static func standard() -> ChainedMetadataReader {
        ChainedMetadataReader(
            primary: AVFoundationMetadataReader(),
            fallback: FFprobeMetadataReader.discovered()
        )
    }

    public func read(_ url: URL) async -> RawMetadata {
        let first = await primary.read(url)
        guard !first.isReadable, let fallback else { return first }
        return await fallback.read(url)
    }
}

/// A reader with the answers already in it. Every rule in §3 can be exercised
/// through this, which is the point: the degenerate cases are degenerate
/// *tags*, and no real file has to be manufactured to hold them.
public struct StubMetadataReader: MetadataReader {
    let answers: [String: RawMetadata]

    public init(_ answers: [String: RawMetadata]) {
        self.answers = answers
    }

    public func read(_ url: URL) async -> RawMetadata {
        answers[url.lastPathComponent] ?? RawMetadata()
    }
}
