import Foundation

/// §8, D5 — where the catalogue lives, and the one place that opens it.
///
/// Bash resolves the file relative to `$0`, following however many symlinks
/// stand between the script and itself, to `../../data/collection.csv`
/// (`player:1631`) — this lives in `scripts/player` of a repository whose data
/// is two directories up, and a symlink into `~/bin` is the normal way to have
/// it on a PATH. **A `.app` has no such relative path**, so D5 makes it a
/// setting instead: a default, an environment override, and a file picker whose
/// answer is kept as a security-scoped bookmark rather than as a string that
/// stops working the day this is sandboxed.
///
/// **The live file, read fresh. Not a copy imported into the app.** That CSV is
/// maintained — it is the data behind the collection site in the same
/// repository — and a copy would go stale silently. A stale note is worse than
/// no note: the entire value of this feature is that it remembers what you do
/// not, so a note that is merely out of date is the one failure mode that
/// cannot be spotted from the panel.
///
/// **Read only, ever.** `cd-collection` is not ours to write to (`CLAUDE.md`),
/// and nothing here needs to be. There is exactly one filesystem call in this
/// file and it is a read.
public enum CatalogueFile {

    /// D5's default. Where the repository this port was made from actually is.
    public static let defaultPath = "~/Sites/cd-collection/data/collection.csv"

    /// The bookmark the file picker leaves behind.
    public static let bookmarkKey = "muthur.collection.bookmark"

    /// A resolved catalogue path and how it has to be opened.
    public struct Location: Sendable, Equatable {
        public let url: URL
        /// Whether the URL came out of a bookmark and therefore has to be read
        /// inside `startAccessingSecurityScopedResource()`. A path off the
        /// environment or the default is just a path.
        public let scoped: Bool

        public init(url: URL, scoped: Bool = false) {
            self.url = url
            self.scoped = scoped
        }
    }

    /// Where to look, in order.
    ///
    /// The environment first, then the picked file, then the default —  D13's
    /// naming pattern, with `PLAYER_COLLECTION` still read behind
    /// `MUTHUR_COLLECTION` because somebody with that already exported meant it
    /// (§13, `player:1622`). The environment beats the bookmark for the same
    /// reason it beats every other setting here: it is the thing you set for
    /// one run.
    ///
    /// Nothing is checked for existence. A path that is not there is a
    /// catalogue that does not load, which is `nil` from `read` and a panel
    /// exactly as it would have been.
    public static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults? = .standard,
        home: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) -> Location {
        if let path = nonEmpty(environment["MUTHUR_COLLECTION"])
            ?? nonEmpty(environment["PLAYER_COLLECTION"])
        {
            return Location(url: expand(path, home: home))
        }
        if let defaults, let picked = resolveBookmark(defaults: defaults) {
            return picked
        }
        return Location(url: expand(defaultPath, home: home))
    }

    /// Read and parse. The only thing in §8 that touches a disk.
    ///
    /// Every way this can fail returns `nil` and says nothing: no file, no
    /// permission, bytes that are not text. A catalogue that will not open is
    /// indistinguishable from not having one, which is the normal state for
    /// anyone who is not the author (`player:1618`).
    public static func read(_ location: Location) -> Catalogue? {
        var scope = false
        if location.scoped {
            scope = location.url.startAccessingSecurityScopedResource()
        }
        defer { if scope { location.url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: location.url, options: [.mappedIfSafe]) else {
            return nil
        }
        return Catalogue(csv: String(decoding: data, as: UTF8.self))
    }

    /// Convenience: locate and read in one step.
    public static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults? = .standard,
        home: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) -> Catalogue? {
        read(locate(environment: environment, defaults: defaults, home: home))
    }

    // MARK: - The picked file

    /// Keep what the file picker was handed. The bookmark rather than the path
    /// is the whole of D5's second half: a string stops working the day this is
    /// sandboxed, and a bookmark survives the file being moved as well.
    ///
    /// A bookmark that cannot be made is not worth complaining about — the
    /// picker still has a URL and the next launch simply falls back.
    @discardableResult
    public static func remember(_ url: URL, defaults: UserDefaults = .standard) -> Bool {
        guard
            let data = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        else { return false }
        defaults.set(data, forKey: bookmarkKey)
        return true
    }

    /// Forget the picked file and go back to the default.
    public static func forget(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: bookmarkKey)
    }

    private static func resolveBookmark(defaults: UserDefaults) -> Location? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard
            let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        else { return nil }
        // A stale bookmark still resolves and still points at the file; it is
        // the *bookmark* that wants rewriting, and rewriting it needs the scope
        // open. Not worth doing on the read path — the next time the picker is
        // used it is replaced anyway, and a note that arrives is worth more than
        // a bookmark that is tidy.
        return Location(url: url, scoped: true)
    }

    // MARK: -

    private static func expand(_ path: String, home: URL) -> URL {
        if path == "~" { return home }
        if path.hasPrefix("~/") { return home.appending(path: String(path.dropFirst(2))) }
        return URL(fileURLWithPath: path)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
