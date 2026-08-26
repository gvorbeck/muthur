import Foundation

/// The table of contents, off the mount rather than off the device. §4.3, D44.
///
/// When macOS mounts an audio CD it writes the disc's whole table of contents
/// into `.TOC.plist` at the root of the volume, beside the `.aiff` files it
/// synthesises. Everything the fingerprint needs is in there — first track, last
/// track, lead-out, and one start block per track — and it is there for the
/// reading, with no device to open, no tool to locate and nothing to install.
///
/// **This is the route that works on this platform, and the two that talk to the
/// device are the ones that do not.** `diskarbitrationd` holds a mounted audio
/// CD, and cdrtools insists on an exclusive open it therefore cannot get: on a
/// disc sitting in the drive right now, every `cdrecord` device node exits 255
/// and `cdda2wav` exits 1. An audio CD on macOS is *always* mounted, so that is
/// not a degraded corner — it is every disc you would ever want to play. See
/// D44.
///
/// The blocks are already in TOC form. Track one reads 150, not 0, so the
/// pre-gap is on them and `fromLBA` is emphatically not what to call: that is
/// for `cdrecord -toc`, which prints LBAs. Checked against `libdiscid` on real
/// material — it produces this table field for field (§19).
public enum VolumeTOC {

    /// Where cddafs puts it.
    public static let filename = ".TOC.plist"

    public static func url(inVolume volume: URL) -> URL {
        volume.appendingPathComponent(filename)
    }

    /// The keys cddafs writes. Spelled out because they are somebody else's
    /// spelling, spaces and all, and a typo here fails silently as "no disc".
    enum Key {
        static let sessions = "Sessions"
        static let firstTrack = "First Track"
        static let lastTrack = "Last Track"
        static let leadOut = "Leadout Block"
        static let trackArray = "Track Array"
        static let point = "Point"
        static let startBlock = "Start Block"
    }

    /// Parse a `.TOC.plist`. Separate from reading one so the shape can be
    /// tested without a disc in the drive.
    ///
    /// **The first session, and only the first.** An enhanced CD carries a data
    /// session after its audio one, and the fingerprint is computed over the
    /// audio session alone — including that session's own lead-out, which is
    /// where the audio actually stops. Taking the last session, or pooling them,
    /// would fingerprint a disc that does not exist.
    public static func parse(_ data: Data) -> TableOfContents? {
        guard
            let root = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil
            ) as? [String: Any],
            let sessions = root[Key.sessions] as? [[String: Any]],
            let session = sessions.first,
            let first = session[Key.firstTrack] as? Int,
            let last = session[Key.lastTrack] as? Int,
            let leadOut = session[Key.leadOut] as? Int,
            let tracks = session[Key.trackArray] as? [[String: Any]]
        else { return nil }

        // Points above 99 are the lead-in descriptors — 0xA0, 0xA1, 0xA2 — which
        // carry the same three numbers already read off the session and no start
        // block worth having. Red Book has no track 100.
        var blocks: [Int: Int] = [:]
        for track in tracks {
            guard let point = track[Key.point] as? Int,
                point >= 1, point <= TableOfContents.maxTracks,
                let start = track[Key.startBlock] as? Int
            else { continue }
            blocks[point] = start
        }

        // Every slot the session claims, or nothing. A table with a hole in it
        // fingerprints as a different disc rather than failing, so a missing
        // track has to be fatal here.
        guard first >= 1, last >= first else { return nil }
        var offsets: [Int] = []
        for number in first...last {
            guard let block = blocks[number] else { return nil }
            offsets.append(block)
        }
        return TableOfContents(
            firstTrack: first, lastTrack: last, leadOut: leadOut, offsets: offsets
        )
    }
}

/// §4.3's table, read from the volume macOS mounted. D44.
///
/// Takes the mount point — the same `/Volumes/…` the picker and §3 are already
/// holding — because that is where the file is. Nothing here opens the drive,
/// so the `drutil`-first ordering that governs the cdrtools paths
/// (`burncd:278`) does not apply to it.
public struct VolumeTableOfContents: TableOfContentsSource {
    let volume: URL

    public init(volume: URL) {
        self.volume = volume
    }

    public func tableOfContents() async -> TableOfContents? {
        guard let data = try? Data(contentsOf: VolumeTOC.url(inVolume: volume)) else {
            return nil
        }
        return VolumeTOC.parse(data)
    }
}
