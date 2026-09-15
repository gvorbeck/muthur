import Foundation

/// Where the library is kept, and how a directory in it is reached. **D91.**
///
/// **`XDG_DATA_HOME` and not the sleeve cache**, for `Corrections`' reason with
/// a sharper edge on it. `~/.cache/muthur/art` is a cache in the true sense and
/// the sleeves in it are fetched again when it is thrown away. The library's
/// are not supposed to be fetched again ever — that is the feature — and a
/// directory whose contract is *may be deleted at any time* cannot keep a
/// promise like that.
public struct LibraryFile: Sendable {

    /// `library.json`.
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The sleeves, beside the index. One JPEG per record, named by
    /// `Library.coverName`.
    public var covers: URL { url.deletingLastPathComponent().appending(path: "covers") }

    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> LibraryFile {
        let base: URL
        if let xdg = environment["XDG_DATA_HOME"], !xdg.isEmpty {
            base = URL(fileURLWithPath: xdg)
        } else {
            base = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/share")
        }
        return LibraryFile(url: base.appendingPathComponent("muthur/library/library.json"))
    }

    // MARK: - Reading and writing

    /// The library, or an empty one where there is no file yet.
    ///
    /// **A file that will not parse is moved aside, not read as empty.** Read as
    /// empty, the next save writes an empty library over it, and the list of
    /// directories — the one part of this that was typed by a person rather
    /// than found — is gone for the sake of a stray byte. Aside, it is one
    /// rename from coming back.
    public func read() -> Library {
        guard let data = try? Data(contentsOf: url) else { return Library() }
        if let library = try? JSONDecoder.library.decode(Library.self, from: data) {
            return library
        }
        let aside = url.appendingPathExtension("damaged")
        try? FileManager.default.removeItem(at: aside)
        try? FileManager.default.moveItem(at: url, to: aside)
        return Library()
    }

    /// Written whole and atomically. A library that cannot be written lasts the
    /// session, which is not worth a sentence on the panel.
    public func write(_ library: Library) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder.library.encode(library) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// A record's sleeve file, if it has one and it is still there.
    public func cover(_ album: Library.Album) -> URL? {
        guard let name = album.cover else { return nil }
        let file = covers.appending(path: name)
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    /// Clear up after records that are no longer in the library. These are the
    /// library's own copies — the sleeve beside the record and the one in the
    /// archive cache are not touched.
    public func discardCovers(of albums: [Library.Album]) {
        for name in albums.compactMap(\.cover) {
            try? FileManager.default.removeItem(at: covers.appending(path: name))
        }
    }

    // MARK: - Reaching a directory

    /// The bookmark the open panel leaves behind (D5's precedent).
    public static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// A directory that can be walked right now.
    public struct Reach: Sendable, Equatable {
        public let url: URL
        /// Whether it has to be read inside `startAccessingSecurityScopedResource`.
        public let scoped: Bool
    }

    /// Where the directory is, if it is anywhere.
    ///
    /// **`.withoutMounting`, so that asking is only ever asking.** A bookmark to
    /// a network share would otherwise try to mount it — a login sheet, or a
    /// long wait on a server that is not there — to answer what is meant to be
    /// a glance at which tiles to dim.
    ///
    /// The bookmark first, because it follows a drive that mounted under a new
    /// name (`My Passport 1`, which macOS does when the old mount point was not
    /// cleared). The path after, because a bookmark that will not resolve is
    /// not proof the directory is gone.
    public static func reach(_ directory: Library.Directory, fileManager: FileManager = .default) -> Reach? {
        if let data = directory.bookmark {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI, .withoutMounting],
                relativeTo: nil,
                bookmarkDataIsStale: &stale),
                isDirectory(url, fileManager)
            {
                return Reach(url: url, scoped: true)
            }
        }
        let url = directory.url
        return isDirectory(url, fileManager) ? Reach(url: url, scoped: false) : nil
    }

    private static func isDirectory(_ url: URL, _ fileManager: FileManager) -> Bool {
        var directory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue
    }
}

extension JSONEncoder {
    fileprivate static var library: JSONEncoder {
        let encoder = JSONEncoder()
        // Sorted and indented, because this is a file somebody may open to find
        // out why a record is missing, and a one-line blob answers nothing.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    fileprivate static var library: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
