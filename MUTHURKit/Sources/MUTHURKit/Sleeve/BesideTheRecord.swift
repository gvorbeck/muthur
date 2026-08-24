import Foundation

/// The sleeve the record came with, if it came with one. §5.1.
///
/// Searched first and preferred to the network, because it is the artwork *this
/// copy* shipped with — where the archive can only offer a scan of whichever
/// release the album *name* matched, and the name is the weakest thing there is
/// to match on (`player:1942`).
///
/// What it is called is the whole difficulty. Rips settle on `cover` or
/// `folder` or `front`; Bandcamp names its picture `Artist - Album.jpg`, which
/// is no convention at all. So the known names are ranked first and everything
/// else is still allowed after them, shallowest path first.
public enum BesideTheRecord {

    /// `player:1925`.
    public static let extensions: Set<String> = [
        "jpg", "jpeg", "png", "webp", "gif", "bmp", "tif", "tiff",
    ]

    /// `find -maxdepth 3` — deeper than the picker's scan and shallower than
    /// playback's, because a sleeve turns up in `Scans/` or `Artwork/CD1/` and
    /// not at the bottom of an arbitrary tree (`player:1951`).
    public static let maximumDepth = 3

    /// 200 px on a side. Well under the 500 the archive sends and well over
    /// anything that is really a thumbnail or a label logo (`player:1949`).
    public static let minimumSide = 200

    // MARK: - The answer

    /// The best readable picture beside the record, or nil.
    ///
    /// The ranking decides the order and the probe decides the winner: a
    /// candidate is only taken if something can open it *and* it clears the
    /// floor, so a 90×90 `cover.jpg` loses to the `Artist - Album.jpg` beside
    /// it rather than beating it on name alone (`player:1946`).
    public static func find(in directory: URL, probe: some PictureProbe) -> URL? {
        candidates(in: directory).first { probe.isPicture($0, minimumSide: minimumSide) }
    }

    /// Every picture under the record, best first.
    public static func candidates(in directory: URL) -> [URL] {
        ranked(scan(directory))
    }

    // MARK: - Ranking

    /// Rank, then shallowest path, then byte order over the whole path — the
    /// script's `sort -k1,1n -k2,2n -k3,3` under `LC_ALL=C` (`player:1961`).
    ///
    /// Thrown-out names are gone rather than last. Drawing the back of the
    /// sleeve, or the face of the disc, confidently beside the panel is worse
    /// than the network answer it displaced.
    public static func ranked(_ files: [URL]) -> [URL] {
        files
            .compactMap { file -> (url: URL, rank: Int, depth: Int)? in
                guard let rank = rank(of: file) else { return nil }
                return (file, rank, depth(of: file))
            }
            .sorted { a, b in
                if a.rank != b.rank { return a.rank < b.rank }
                if a.depth != b.depth { return a.depth < b.depth }
                return AudioFiles.byteOrder(a.url.path, b.url.path) == .orderedAscending
            }
            .map(\.url)
    }

    /// 1 to 4, or nil for a name that is thrown out.
    public static func rank(of file: URL) -> Int? {
        rank(folded: fold(file.deletingPathExtension().lastPathComponent))
    }

    static func rank(folded name: String) -> Int? {
        let words = name.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

        // The scans that are definitely not the front.
        if words.contains(where: notTheFront.contains) { return nil }
        // `disc`, `cd`, `dvd`, each with optional digits after it — so `cd2` is
        // out and `discovery` is not a disc, which is the whole reason the
        // separators were folded to spaces first.
        if words.contains(where: isADiscLabel) { return nil }

        if exactNames.contains(name) { return 1 }
        if words.contains("cover") || words.contains("front") { return 2 }
        if name.contains("cover") || name.contains("front") { return 3 }
        // Anything else, which is what it takes to find the `Artist - Album.jpg`
        // a Bandcamp download leaves you.
        return 4
    }

    static let notTheFront: Set<String> = [
        "back", "inlay", "booklet", "tray", "obi", "spine", "label", "matrix",
        "inside", "thumb", "thumbnail",
    ]

    static let exactNames: Set<String> = [
        "cover", "front", "folder", "album", "albumart", "artwork", "sleeve",
    ]

    static func isADiscLabel(_ word: String) -> Bool {
        for prefix in ["disc", "cd", "dvd"] where word.hasPrefix(prefix) {
            let rest = word.dropFirst(prefix.count)
            if rest.allSatisfy({ $0.isASCII && $0.isNumber }) { return true }
        }
        return false
    }

    /// `tolower`, extension off, then separators folded to spaces so the words
    /// can be matched as words: `front-cover` is a front cover and `discovery`
    /// is not a disc (`player:1956`).
    ///
    /// Not trimmed, because the script does not trim: `-cover-.jpg` folds to
    /// `" cover "`, which is rank 2 and not rank 1. That is the right answer
    /// anyway — a name with decoration on it is not the bare word.
    ///
    /// Lowercasing is ASCII-only, as `tr '[:upper:]' '[:lower:]'` is in the C
    /// locale the script runs under.
    public static func fold(_ basename: String) -> String {
        var out = String.UnicodeScalarView()
        var lastWasSeparator = false
        for scalar in basename.unicodeScalars {
            let isSeparator = scalar == "_" || scalar == " " || scalar == "-"
            if isSeparator {
                if !lastWasSeparator { out.append(" ") }
                lastWasSeparator = true
                continue
            }
            lastWasSeparator = false
            if scalar.value >= 65 && scalar.value <= 90 {
                out.append(Unicode.Scalar(scalar.value + 32)!)
            } else {
                out.append(scalar)
            }
        }
        return String(out)
    }

    // MARK: - The scan

    /// Every file with a picture's extension, no deeper than `maximumDepth`.
    ///
    /// Hidden files are included, because `find` includes them: an AppleDouble
    /// `._cover.jpg` out of a zip ranks as a cover and is then refused by the
    /// probe, which is the same two steps the script takes and one fewer rule
    /// to keep in step with the unpacker.
    public static func scan(_ directory: URL) -> [URL] {
        let manager = FileManager.default
        guard
            let walk = manager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey]
            )
        else { return [] }

        let root = directory.standardizedFileURL.pathComponents.count
        var found: [URL] = []
        for case let url as URL in walk {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            let below = url.standardizedFileURL.pathComponents.count - root
            if values?.isDirectory == true {
                // `-maxdepth 3`: a directory at the limit is looked at and not
                // descended into.
                if below >= maximumDepth { walk.skipDescendants() }
                continue
            }
            guard values?.isRegularFile == true, below <= maximumDepth,
                extensions.contains(url.pathExtension.lowercased())
            else { continue }
            found.append(url)
        }
        return found
    }

    /// How many components the path has — the script's `awk -F/ { … NF }`,
    /// which is what breaks a tie between two equally-named pictures at
    /// different depths (`player:1959`).
    static func depth(of file: URL) -> Int {
        file.standardizedFileURL.pathComponents.count
    }
}
