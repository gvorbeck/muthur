import AVFoundation
import Foundation

/// The picture inside the tags, when there is no picture beside the record. §5.
///
/// An APIC frame in an MP3, a PICTURE block in a FLAC, a `covr` atom in an M4A.
/// Whatever was in there at whatever size — copied, never re-encoded
/// (`player:1973`).
public protocol EmbeddedPictureReader: Sendable {
    func picture(of url: URL) async -> Data?
}

/// The primary read, and the reason the script's mapping comment does not
/// survive as code.
///
/// `ffmpeg` sees an attached picture as a video stream of one frame, so the
/// script has to ask for "every video stream less the ones that are really
/// video" — without that second half, a music video sitting in the folder has
/// its opening frame pulled out and hung beside the panel as a sleeve
/// (`player:1985`). AVFoundation makes that distinction itself: artwork is a
/// metadata item and a film is a track, and there is no spelling of this that
/// reaches for the film.
public struct AVFoundationEmbeddedPictureReader: EmbeddedPictureReader {

    public init() {}

    public func picture(of url: URL) async -> Data? {
        let asset = AVURLAsset(url: url)
        guard let common = try? await asset.load(.commonMetadata) else { return nil }
        for item in AVMetadataItem.metadataItems(
            from: common, filteredByIdentifier: .commonIdentifierArtwork
        ) {
            if let data = try? await item.load(.dataValue), !data.isEmpty { return data }
        }
        return nil
    }
}

/// The fallback, for what AVFoundation will not open at all — Opus and Ogg,
/// the same two formats that send `MetadataReader` down its second path.
///
/// This is the script's command verbatim, mapping and all (`player:1993`),
/// because for these containers ffmpeg is again the only thing answering.
public struct FFmpegEmbeddedPictureReader: EmbeddedPictureReader {
    let executable: URL

    public init(executable: URL) {
        self.executable = executable
    }

    /// Nil where this machine has no ffmpeg. Not an error — it is a record with
    /// no sleeve rather than a record that will not play, which is the rule the
    /// whole of §17 follows.
    public static func discovered(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> FFmpegEmbeddedPictureReader? {
        var directories = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        // A GUI app inherits no shell PATH, so Homebrew's two locations are
        // named — the same reason `FFprobeMetadataReader` names them.
        directories.append(contentsOf: ["/opt/homebrew/bin", "/usr/local/bin"])
        for directory in directories where !directory.isEmpty {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("ffmpeg")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return FFmpegEmbeddedPictureReader(executable: candidate)
            }
        }
        return nil
    }

    public func picture(of url: URL) async -> Data? {
        // No extension on the file and none wanted: what comes out is whatever
        // the tag held, usually JPEG and sometimes PNG, and everything
        // downstream reads the bytes rather than the name (`player:1997`).
        let out = FileManager.default.temporaryDirectory
            .appending(path: "muthur-embedded-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: out) }

        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "-v", "error", "-nostdin", "-y", "-i", url.path,
            "-map", "0:v", "-map", "-0:V", "-c", "copy", "-frames:v", "1",
            "-f", "image2", out.path,
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        guard let data = try? Data(contentsOf: out), !data.isEmpty else { return nil }
        return data
    }
}

/// Primary, then fallback — the shape `ChainedMetadataReader` already has, for
/// the same reason and over the same two formats.
public struct ChainedEmbeddedPictureReader: EmbeddedPictureReader {
    let primary: any EmbeddedPictureReader
    let fallback: (any EmbeddedPictureReader)?

    public init(primary: any EmbeddedPictureReader, fallback: (any EmbeddedPictureReader)?) {
        self.primary = primary
        self.fallback = fallback
    }

    public static func standard() -> ChainedEmbeddedPictureReader {
        ChainedEmbeddedPictureReader(
            primary: AVFoundationEmbeddedPictureReader(),
            fallback: FFmpegEmbeddedPictureReader.discovered()
        )
    }

    public func picture(of url: URL) async -> Data? {
        if let data = await primary.picture(of: url) { return data }
        return await fallback?.picture(of: url)
    }
}

/// A reader with the pictures already in it, keyed on the file's name.
public struct StubEmbeddedPictureReader: EmbeddedPictureReader {
    let pictures: [String: Data]

    public init(_ pictures: [String: Data]) {
        self.pictures = pictures
    }

    public func picture(of url: URL) async -> Data? {
        pictures[url.lastPathComponent]
    }
}

/// A reader that never has one. The ordinary case, and the one every test of
/// what happens *after* the tags needs.
public struct NoEmbeddedPictures: EmbeddedPictureReader {
    public init() {}
    public func picture(of url: URL) async -> Data? { nil }
}
