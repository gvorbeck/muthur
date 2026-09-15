import Foundation

/// Where the records are under a directory you added to the library. **D91.**
///
/// This is the scan D50 took away, and the reason it is back is that you asked
/// for it by name: a directory handed to the library is a place you have said
/// the records live, where `PLAYER_DIRS` was a place the program went looking
/// uninvited. It runs when the library is opened or rescanned and never at
/// launch.
///
/// **A record is whatever `SourceOpener` would open**, and the walk stops at the
/// first one it meets on the way down. A folder with audio directly in it is a
/// record, and nothing below it is looked at — `Scans/` and `CD1/` are both the
/// record's business, not the library's. A zip is a record when its central
/// directory holds audio (D47's rule, asked the same way). A folder with no
/// audio in it is somewhere to keep walking.
///
/// **The one place a name is read** is the multi-disc folder: `Album/CD1`,
/// `Album/CD2`. D12 refuses to read `CD2` as a number *inside* a record, where
/// the shape of the archive already says there are two discs and the name adds
/// nothing. Out here the shape says nothing at all — `Artist/Album One` and
/// `Album/CD1` are the same tree — and without the name a double album is two
/// tiles, each of which plays half of it. So a folder whose audio-holding
/// children are **all** called something like `CD1` or `Disc 2` is one record,
/// and anything short of all of them is walked into as usual. A miss costs a
/// record shown as its discs, which still play.
public enum LibraryWalk {

    public enum Kind: String, Codable, Sendable, Equatable {
        case folder
        case zip
    }

    public struct Found: Sendable, Equatable {
        public let url: URL
        public let kind: Kind
        /// The path under the directory that was added, `/`-separated. The
        /// record's identity in the library: it survives the drive mounting
        /// somewhere else, where an absolute path would not.
        public let path: String

        public init(url: URL, kind: Kind, path: String) {
            self.url = url
            self.kind = kind
            self.path = path
        }
    }

    /// Deeper than any collection is filed, and shallow enough that a directory
    /// added by mistake — a whole home folder — gives up rather than spending
    /// the evening in `Library/Caches`.
    public static let maximumDepth = 8

    /// Every record under `root`, in byte order of their paths.
    ///
    /// **Symlinks are not followed.** A link back up the tree is a walk that
    /// never ends, and a link sideways shows the same record twice under two
    /// names. Hidden entries are skipped, which is what keeps the `._` stubs a
    /// Mac leaves on every FAT and exFAT drive out of the library: `._Album.zip`
    /// is a resource fork, not a zip.
    public static func albums(in root: URL) -> [Found] {
        var found: [Found] = []
        walk(root, root: root, depth: 0, into: &found)
        return found.sorted { AudioFiles.byteOrder($0.path, $1.path) == .orderedAscending }
    }

    // MARK: - The walk

    private struct Entry {
        let url: URL
        let isDirectory: Bool
        let isFile: Bool
    }

    private static func walk(_ directory: URL, root: URL, depth: Int, into found: inout [Found]) {
        let entries = listing(directory)

        if entries.contains(where: { $0.isFile && AudioFiles.isAudio($0.url) }) {
            found.append(Found(url: directory, kind: .folder, path: relative(directory, to: root)))
            return
        }

        let folders = entries.filter(\.isDirectory)
        let holding = folders.filter { holdsAudioDirectly($0.url) }
        if !holding.isEmpty, holding.allSatisfy({ isADisc($0.url.lastPathComponent) }) {
            found.append(Found(url: directory, kind: .folder, path: relative(directory, to: root)))
            return
        }

        for entry in entries where entry.isFile && entry.url.pathExtension.lowercased() == "zip" {
            // A zip that will not open is not a record, and not an error either:
            // a half-copied download on a drive is ordinary, and the library is
            // not the place to complain about it. Opening it is where that
            // happens.
            guard let archive = try? ZipArchive(url: entry.url), archive.holdsAudio else { continue }
            found.append(Found(url: entry.url, kind: .zip, path: relative(entry.url, to: root)))
        }

        guard depth < maximumDepth else { return }
        for folder in folders {
            walk(folder.url, root: root, depth: depth + 1, into: &found)
        }
    }

    private static func listing(_ directory: URL) -> [Entry] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        guard
            let urls = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        else { return [] }
        return
            urls
            .compactMap { url -> Entry? in
                // `BesideTheRecord.scan` observed `FileManager` not handing out
                // `._` stubs at all, on APFS and on exFAT. The dot test is
                // written out anyway, because that is an observation and not a
                // promise, and a stub that got through would be opened as a zip.
                guard !url.lastPathComponent.hasPrefix(".") else { return nil }
                let values = try? url.resourceValues(forKeys: Set(keys))
                guard values?.isSymbolicLink != true else { return nil }
                return Entry(
                    url: url,
                    isDirectory: values?.isDirectory == true,
                    isFile: values?.isRegularFile == true)
            }
            .sorted { AudioFiles.byteOrder($0.url.path, $1.url.path) == .orderedAscending }
    }

    private static func holdsAudioDirectly(_ directory: URL) -> Bool {
        listing(directory).contains { $0.isFile && AudioFiles.isAudio($0.url) }
    }

    /// `CD1`, `cd 2`, `Disc_03`, `Disk 1` — the word and a number, and nothing
    /// else. `Discovery` is not a disc and neither is `CD Singles`, and a bare
    /// `Disc` with no number is a folder somebody named, not a disc of anything.
    static func isADisc(_ name: String) -> Bool {
        let word = BesideTheRecord.fold(name).filter { $0 != " " }
        for prefix in ["disc", "disk", "cd"] where word.hasPrefix(prefix) {
            let rest = word.dropFirst(prefix.count)
            if !rest.isEmpty, rest.allSatisfy({ $0.isASCII && $0.isNumber }) { return true }
        }
        return false
    }

    static func relative(_ url: URL, to root: URL) -> String {
        let base = root.standardizedFileURL.pathComponents
        let parts = url.standardizedFileURL.pathComponents
        guard parts.count >= base.count, Array(parts.prefix(base.count)) == base else {
            return url.lastPathComponent
        }
        return parts.dropFirst(base.count).joined(separator: "/")
    }
}
