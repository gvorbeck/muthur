import CryptoKit
import Foundation

/// The disc's table of contents, and the fingerprint computed from it. §4.3.
///
/// A disc ID is not a lookup of the album — it is a lookup of the *pressing*.
/// Two masterings of the same record have different track lengths and therefore
/// different offsets, so the ID tells them apart where a search by name cannot.
/// That is why the drive gets asked before the catalogue does.
///
/// Offsets here are sector addresses **as the TOC carries them**, which means
/// the 150-frame pre-gap is already in them and track one is 150 rather than 0.
/// The drive reports LBAs, which are the same numbers with the pre-gap taken
/// out; `fromLBA` is where the 150 goes back on, once, somewhere visible.
public struct TableOfContents: Sendable, Equatable {
    public let firstTrack: Int
    public let lastTrack: Int
    /// Where the audio stops, in the same units as the offsets.
    public let leadOut: Int
    /// One per track, `firstTrack` through `lastTrack`, in that order.
    public let offsets: [Int]

    /// Every CD address is measured from two seconds in — 150 frames at 75 a
    /// second — because that is where the lead-in ends.
    public static let preGap = 150

    /// Red Book allows 99 tracks and the disc ID string has exactly 99 slots,
    /// so a hundredth track has nowhere to go. The script's own check is only
    /// `first > 0 && last >= first` (`player:2158`); it never meets a disc that
    /// needs the rest of this, and neither will we.
    public static let maxTracks = 99

    public init?(firstTrack: Int, lastTrack: Int, leadOut: Int, offsets: [Int]) {
        guard firstTrack >= 1, lastTrack >= firstTrack, lastTrack <= TableOfContents.maxTracks,
            offsets.count == lastTrack - firstTrack + 1,
            leadOut >= 0, offsets.allSatisfy({ $0 >= 0 })
        else { return nil }
        self.firstTrack = firstTrack
        self.lastTrack = lastTrack
        self.leadOut = leadOut
        self.offsets = offsets
    }

    /// The same table, given the LBAs a drive actually prints
    /// (`cdrecord -toc` says `lba: 0` for track one). The pre-gap is added here
    /// and nowhere else.
    ///
    /// An LBA may be negative — the pre-gap of a hidden track is addressed
    /// backwards from track one — and `+150` is what puts it back in range, so
    /// the guard against negatives belongs after the addition rather than
    /// before it.
    public static func fromLBA(
        firstTrack: Int, lastTrack: Int, leadOutLBA: Int, trackLBAs: [Int]
    ) -> TableOfContents? {
        TableOfContents(
            firstTrack: firstTrack,
            lastTrack: lastTrack,
            leadOut: leadOutLBA + preGap,
            offsets: trackLBAs.map { $0 + preGap }
        )
    }

    public var trackCount: Int { lastTrack - firstTrack + 1 }

    /// The offset of a given track number, or nil for a slot this disc does not
    /// have. Track numbers, not indices — the distinction §4 lives and dies on.
    public func offset(ofTrack number: Int) -> Int? {
        guard number >= firstTrack, number <= lastTrack else { return nil }
        return offsets[number - firstTrack]
    }

    // MARK: - The fingerprint

    /// The MusicBrainz disc ID.
    ///
    /// SHA-1 over an 804-character string: the first track, the last track and
    /// the lead-out, then 99 track offsets, every field uppercase hex — `%02X`,
    /// `%02X`, `%08X`, then 99 × `%08X`. Slots this disc has no track for are
    /// zeroes, and a seven-track disc is therefore mostly zeroes. Then base64 of
    /// the raw digest, with `+/=` rewritten to `._-` so the thing can sit in a
    /// URL.
    ///
    /// **The hash is over those characters, not over the bytes they spell.**
    /// The string is 804 ASCII characters and all 804 go in. It is a natural
    /// mistake to read a hex string as a way of writing 402 bytes and unpack it
    /// first, and the script makes exactly that mistake — `xxd -r -p` sits
    /// between the `printf` and the `shasum` at `player:2166` — which is why
    /// `mb_lookup` has in all likelihood never once resolved a disc. §4.3's
    /// failure path is silent by design, so nothing ever said so. Ported to the
    /// published specification rather than to the script, deliberately, as D15.
    public var discID: String {
        let digest = Insecure.SHA1.hash(data: Data(hexString.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: ".")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "-")
    }

    /// The 804 characters the digest is taken over. Internal because it is only
    /// interesting when something disagrees about the answer — at which point
    /// it is the first thing you want to see.
    var hexString: String {
        var hex = String(format: "%02X%02X%08X", firstTrack, lastTrack, leadOut)
        for track in 1...TableOfContents.maxTracks {
            hex += String(format: "%08X", offset(ofTrack: track) ?? 0)
        }
        return hex
    }

    /// `MB_TOC` — the table in the form MusicBrainz's submission URL wants, and
    /// the form every published example is written in: first, last, lead-out,
    /// then this disc's offsets only (`player:2160`).
    public var tocString: String {
        ([firstTrack, lastTrack, leadOut] + offsets).map(String.init).joined(separator: " ")
    }
}
