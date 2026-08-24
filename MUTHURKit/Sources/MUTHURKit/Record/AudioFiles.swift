import Foundation

/// What counts as audio, and the order the folder is walked in.
///
/// §1.4 and §3.1. The scan order is not the running order — it is only the
/// order the files are *read* in, and it exists as a separate, stable thing
/// because everything downstream indexes by it.
public enum AudioFiles {

    /// `player:1046`. Case-insensitive, and a mixed-format album is fine —
    /// a folder half FLAC and half MP3 is a rip that got interrupted and
    /// finished later, not an error.
    public static let extensions: Set<String> = [
        "aif", "aiff", "flac", "mp3", "ogg", "opus", "wav", "m4a", "wma",
        "ape", "alac", "mp4",
    ]

    public static func isAudio(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }

    /// `find "$AUDIO_DIR" -type f \( "${AUDIO_GLOB[@]}" \) | LC_ALL=C sort`
    /// (`player:1492`).
    ///
    /// Audio is found at **any** depth: a zip that unpacks to `Album/CD1/…`
    /// alongside `Album/scans/…` is read whole and the non-audio ignored
    /// (`player:1422`). The sort is byte order, not locale order, so the scan
    /// is the same on any machine — which is the only reason a scan index is
    /// safe to hand around.
    public static func scan(_ directory: URL) -> [URL] {
        let fm = FileManager.default
        guard
            let walk = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else { return [] }

        var found: [URL] = []
        for case let url as URL in walk {
            guard isAudio(url) else { continue }
            let regular = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?
                .isRegularFile
            guard regular == true else { continue }
            found.append(url.resolvingSymlinksInPath())
        }
        return found.sorted { byteOrder($0.path, $1.path) == .orderedAscending }
    }

    /// `LC_ALL=C` — compare the bytes, not the characters. Two albums whose
    /// names differ only in accents must not swap places because the machine
    /// was set to a different locale.
    static func byteOrder(_ a: String, _ b: String) -> ComparisonResult {
        let x = Array(a.utf8)
        let y = Array(b.utf8)
        for i in 0..<min(x.count, y.count) where x[i] != y[i] {
            return x[i] < y[i] ? .orderedAscending : .orderedDescending
        }
        if x.count == y.count { return .orderedSame }
        return x.count < y.count ? .orderedAscending : .orderedDescending
    }
}
