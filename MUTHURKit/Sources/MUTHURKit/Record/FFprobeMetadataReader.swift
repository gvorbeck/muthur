import Foundation

/// The fallback read, for what AVFoundation will not open — Opus and Ogg,
/// which it refuses outright rather than answering badly.
///
/// This is the script's read, verbatim: one `ffprobe` per file, the same eight
/// fields, `default=nw=1` so the answer is `key=value` a line at a time
/// (`player:1439`). Where the two readers disagree the script is right, and
/// keeping the request identical is what makes that checkable.
public struct FFprobeMetadataReader: MetadataReader {
    let executable: URL

    public init(executable: URL) {
        self.executable = executable
    }

    /// Nil if this machine has no ffprobe. Not an error — it is a smaller set
    /// of playable formats, and §11 exists so that "why is mine not working"
    /// has an answer rather than a crash.
    public static func discovered(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> FFprobeMetadataReader? {
        var directories = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        // A GUI app is not launched from a shell and does not inherit a shell's
        // PATH, so the two places Homebrew puts things have to be named.
        directories.append(contentsOf: ["/opt/homebrew/bin", "/usr/local/bin"])
        for directory in directories where !directory.isEmpty {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("ffprobe")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return FFprobeMetadataReader(executable: candidate)
            }
        }
        return nil
    }

    static let entries =
        "format=duration:format_tags=track,tracknumber,disc,discnumber,title,album,"
        + "artist,album_artist,albumartist,date,year,originalyear"

    public func read(_ url: URL) async -> RawMetadata {
        guard let output = run(url) else { return RawMetadata() }
        return FFprobeMetadataReader.parse(output)
    }

    private func run(_ url: URL) -> String? {
        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "-v", "error", "-show_entries", FFprobeMetadataReader.entries,
            "-of", "default=nw=1", url.path,
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        // Read before waiting: a file with a long tag list can fill the pipe,
        // and a full pipe with nobody reading it is a process that never exits.
        let data = try? pipe.fileHandleForReading.readToEnd()
        process.waitUntilExit()
        guard let data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// The script's `while IFS='=' read -r key val` switch (`player:1428`).
    /// Split on the *first* `=` only, because a tag value may contain one.
    static func parse(_ output: String) -> RawMetadata {
        var raw = RawMetadata()
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let split = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<split])
            let value = String(line[line.index(after: split)...])
            guard !value.isEmpty, value != "N/A" else { continue }
            switch key {
            case "duration": raw.duration = Double(value)
            case "TAG:track", "TAG:tracknumber": raw.track = value
            case "TAG:disc", "TAG:discnumber": raw.disc = value
            case "TAG:title": raw.title = value
            case "TAG:album": raw.album = value
            case "TAG:artist": raw.artist = value
            case "TAG:album_artist", "TAG:albumartist": raw.albumArtist = value
            // First of the three wins, per the script.
            case "TAG:date", "TAG:year", "TAG:originalyear":
                if raw.date == nil { raw.date = value }
            default: break
            }
        }
        return raw
    }
}
