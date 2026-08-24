import Foundation

/// Where a fetched sleeve is kept, so an album fetched once is not fetched
/// again. §5.2.
///
/// Three files can exist per record and they mean three different things:
///
/// - `<key>.jpg` — the cover. Always whole, because it only ever arrives by
///   being moved onto that name from the part file beside it.
/// - `<key>.jpg.part` — a download in progress. Named after the *album* and not
///   after this process, so a fetch that is killed mid-download leaves one file
///   that the next attempt at the same record overwrites, instead of a new one
///   every time (`player:1896`).
/// - `<key>.jpg.none` — this record has no cover in the archive. Expires, so
///   that a scan uploaded in the meantime still turns up (`player:1879`).
///
/// The directory is ours and not the script's, for the reason D13 gives: two
/// programs sharing a cache root is a thing that only ever costs and never
/// pays. `player` uses `~/.cache/player/art`; this is `~/.cache/muthur/art`,
/// beside `~/.cache/muthur/work`.
public struct SleeveCache: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// A fortnight. Without the marker, an album with no scan costs two
    /// lookups on the network every single time it is played; without the
    /// expiry, a cover uploaded next week is never seen (`player:1884`).
    ///
    /// The script's `find -mtime +14` actually expires at fifteen days, because
    /// `find` truncates the age to whole days before comparing. Fourteen is
    /// what the comment says and what the box in §5.2 says, and a day either
    /// way of a fortnight is not a behaviour anybody has ever relied on.
    public static let noneLifetime: TimeInterval = 14 * 24 * 60 * 60

    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) -> SleeveCache {
        let base =
            environment["XDG_CACHE_HOME"].flatMap { $0.isEmpty ? nil : $0 }
            .map(URL.init(fileURLWithPath:)) ?? home.appending(path: ".cache")
        return SleeveCache(directory: base.appending(path: "muthur/art"))
    }

    // MARK: - What this record is called on disk

    /// The release ID when a disc gave us one, because that names a pressing
    /// exactly; otherwise the artist and the title folded down to letters and
    /// digits, so that the same album tagged two slightly different ways lands
    /// on one file (`player:1783`).
    ///
    /// Nil when there is nothing left after folding — a record with no artist
    /// and a title of punctuation has no name to file it under, and inventing
    /// one would put two such records on the same file.
    public static func key(
        releaseMBID: String? = nil, albumArtist: String = "", album: String = ""
    ) -> String? {
        let raw: String
        if let releaseMBID, !releaseMBID.isEmpty {
            raw = "mbid-\(releaseMBID)"
        } else {
            raw = "\(albumArtist)-\(album)"
        }
        let folded = fold(raw)
        return folded.isEmpty ? nil : folded
    }

    /// `tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-'`, then the ends
    /// trimmed and the whole thing cut to 80.
    ///
    /// `tr` works on bytes in the C locale, so an accented letter is several
    /// non-alphanumeric bytes squeezed into a single `-`. One non-ASCII scalar
    /// becoming a single `-` is the same answer, arrived at one level up.
    static func fold(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        var lastWasDash = false
        for scalar in text.unicodeScalars {
            let value = scalar.value
            let lowered: Unicode.Scalar? =
                switch value {
                case 65...90: Unicode.Scalar(value + 32)!
                case 97...122, 48...57: scalar
                default: nil
                }
            if let lowered {
                out.append(lowered)
                lastWasDash = false
            } else {
                if !lastWasDash { out.append("-") }
                lastWasDash = true
            }
        }
        var s = String(out)
        if s.hasPrefix("-") { s.removeFirst() }
        if s.hasSuffix("-") { s.removeLast() }
        s = String(s.prefix(80))
        if s.hasSuffix("-") { s.removeLast() }
        return s
    }

    // MARK: - The three files

    public func file(forKey key: String) -> URL {
        directory.appending(path: "\(key).jpg")
    }

    public func part(forKey key: String) -> URL {
        directory.appending(path: "\(key).jpg.part")
    }

    public func noneMarker(forKey key: String) -> URL {
        directory.appending(path: "\(key).jpg.none")
    }

    /// `[ -s "$ART_FILE" ]` — already on disk from a previous session, so there
    /// is nothing to ask the network (`player:2032`).
    public func hasEntry(forKey key: String) -> Bool {
        let entry = file(forKey: key)
        let size = (try? entry.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        return (size ?? 0) > 0
    }

    @discardableResult
    public func makeDirectory() -> Bool {
        (try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )) != nil
    }

    // MARK: - The marker

    /// Whether this record is still remembered as having no cover. A stale
    /// marker is removed on the way past, which is what the script's
    /// `find … -mtime +14 && rm -f` does and is why this is not a pure query.
    public func noneIsFresh(forKey key: String, now: Date = Date()) -> Bool {
        let marker = noneMarker(forKey: key)
        guard
            let modified = (try? marker.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
        else { return false }
        if now.timeIntervalSince(modified) > SleeveCache.noneLifetime {
            try? FileManager.default.removeItem(at: marker)
            return false
        }
        return true
    }

    /// `: > "$ART_FILE.none"` — an empty file whose whole content is its
    /// timestamp.
    public func markNone(forKey key: String) {
        let marker = noneMarker(forKey: key)
        if FileManager.default.fileExists(atPath: marker.path) {
            // Written again rather than left alone: the record was asked about
            // again and the answer is again no, so the fortnight starts again.
            try? FileManager.default.setAttributes(
                [.modificationDate: Date()], ofItemAtPath: marker.path
            )
            return
        }
        FileManager.default.createFile(atPath: marker.path, contents: Data())
    }

    // MARK: - The part file

    /// Everything downloaded lands here first.
    @discardableResult
    public func writePart(_ data: Data, forKey key: String) -> URL? {
        let partFile = part(forKey: key)
        // `rm -f "$tmp"` before each attempt: the previous try's bytes must not
        // be what the probe is looking at.
        try? FileManager.default.removeItem(at: partFile)
        guard (try? data.write(to: partFile)) != nil else { return nil }
        return partFile
    }

    /// Moved onto the cache entry, so a file in the cache is always a whole
    /// one: the panel tests for the file and nothing else, and half a JPEG
    /// would be read as the cover and drawn as rubbish (`player:1893`).
    public func commitPart(forKey key: String) -> URL? {
        let partFile = part(forKey: key)
        let entry = file(forKey: key)
        try? FileManager.default.removeItem(at: entry)
        guard (try? FileManager.default.moveItem(at: partFile, to: entry)) != nil else {
            return nil
        }
        return entry
    }

    public func removePart(forKey key: String) {
        try? FileManager.default.removeItem(at: part(forKey: key))
    }

    // MARK: - Deliberately absent
    //
    // There is no way to delete a cache entry from here, and that is the whole
    // of §5.2's last box. A picture that will not decode is one that will not
    // decode next second either, so the panel stops asking — but it *clears*
    // its reference rather than removing the file, because another player may
    // be part way through writing that very name (`player:3162`). The obvious
    // `rm` at the call site is the bug; not offering one is the fix.
}
