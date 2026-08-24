import AVFoundation
import Foundation

/// The primary read. `CLAUDE.md`: AVFoundation does the work.
///
/// The script asks ffprobe for eight named fields and switches on the key it
/// gets back (`player:1428`). This does the same thing, and it has to, because
/// the four container families spell those eight fields four different ways —
/// `TRACKNUMBER` in a Vorbis comment, `TRCK` in ID3, a binary `trkn` atom in
/// an MP4, `info-*` in an AIFF. Matching on a normalised key name rather than
/// on AVFoundation's predefined identifiers is what keeps that one switch.
public struct AVFoundationMetadataReader: MetadataReader {

    public init() {}

    public func read(_ url: URL) async -> RawMetadata {
        // Precise timing costs a fuller parse and is worth it: the imprecise
        // answer is rounded to the container's timescale, and every duration
        // here is about to be rounded up and then summed into TOTAL.
        let asset = AVURLAsset(
            url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        )

        guard let duration = try? await asset.load(.duration),
            duration.isNumeric
        else {
            // Opus and Ogg land here — AVFoundation will not open them at all.
            // Not an error: it is the fallback's turn.
            return RawMetadata()
        }

        var raw = RawMetadata(duration: CMTimeGetSeconds(duration))

        guard let formats = try? await asset.load(.availableMetadataFormats) else { return raw }
        var fields: [Field: String] = [:]
        for format in formats {
            guard let items = try? await asset.loadMetadata(for: format) else { continue }
            for item in items {
                guard let field = Field(item) else { continue }
                // First non-empty answer wins. It is what the script does for
                // the date — `[ -z "$year" ] && year="$val"` across date, year
                // and originalyear (`player:1435`) — and for every other field
                // a file carrying two spellings of it is carrying the same
                // value twice.
                guard fields[field] == nil else { continue }
                guard let value = await string(from: item, field: field), !value.isEmpty
                else { continue }
                fields[field] = value
            }
        }

        raw.track = fields[.track]
        raw.disc = fields[.disc]
        raw.title = fields[.title]
        raw.album = fields[.album]
        raw.artist = fields[.artist]
        raw.albumArtist = fields[.albumArtist]
        raw.date = fields[.date]
        return raw
    }

    // MARK: - The one switch

    enum Field: Hashable {
        case track, disc, title, album, artist, albumArtist, date

        /// The key, uppercased with everything that is not a letter or a digit
        /// taken out. `©nam` becomes `NAM`, `info-title` becomes `INFOTITLE`,
        /// `TRACKNUMBER` stays itself — four spellings collapsing onto one
        /// name each.
        init?(_ item: AVMetadataItem) {
            guard let key = Field.normalisedKey(item) else { return nil }
            switch key {
            case "TRACK", "TRACKNUMBER", "TRKN", "TRCK", "INFOTRACKNUMBER": self = .track
            case "DISC", "DISCNUMBER", "DISK", "TPOS": self = .disc
            case "TITLE", "NAM", "TIT2", "INFOTITLE": self = .title
            case "ALBUM", "ALB", "TALB", "INFOALBUM": self = .album
            case "ARTIST", "ART", "TPE1", "INFOARTIST": self = .artist
            case "ALBUMARTIST", "ALBUMARTIST0", "AART", "TPE2": self = .albumArtist
            case "DATE", "YEAR", "ORIGINALYEAR", "DAY", "TDRC", "TYER", "TDOR", "TORY",
                "INFOYEAR", "INFORECORDINGDATE":
                self = .date
            default:
                // Fall back on what AVFoundation itself thinks the item is,
                // for a container nobody here has met yet.
                switch item.commonKey {
                case .commonKeyTitle?: self = .title
                case .commonKeyAlbumName?: self = .album
                case .commonKeyArtist?: self = .artist
                case .commonKeyCreationDate?: self = .date
                default: return nil
                }
            }
        }

        static func normalisedKey(_ item: AVMetadataItem) -> String? {
            // An MP4's key is a numeric FourCC, so the identifier is the only
            // readable spelling of it; a Vorbis comment's key is the word
            // itself. Try the identifier first — it is the one that is always
            // text.
            var candidate: String?
            if let identifier = item.identifier?.rawValue,
                let slash = identifier.firstIndex(of: "/")
            {
                let tail = String(identifier[identifier.index(after: slash)...])
                candidate = tail.removingPercentEncoding ?? tail
            }
            if candidate == nil, let key = item.key as? String { candidate = key }
            guard let candidate else { return nil }
            let stripped = candidate.uppercased().filter { $0.isLetter || $0.isNumber }
            return stripped.isEmpty ? nil : stripped
        }
    }

    /// An MP4 writes `trkn` and `disk` as a binary atom rather than a string:
    /// eight bytes, big-endian, the number at 2–3 and the total at 4–5. Turning
    /// it back into `3/11` means the slash rule in `Track` is still the only
    /// place that parses a track number.
    private func string(from item: AVMetadataItem, field: Field) async -> String? {
        if let value = try? await item.load(.stringValue) { return value }

        if field == .track || field == .disc,
            let data = try? await item.load(.dataValue), data.count >= 4
        {
            let bytes = [UInt8](data)
            let number = Int(bytes[2]) << 8 | Int(bytes[3])
            guard number > 0 else { return nil }
            if data.count >= 6 {
                let total = Int(bytes[4]) << 8 | Int(bytes[5])
                if total > 0 { return "\(number)/\(total)" }
            }
            return "\(number)"
        }

        if let number = try? await item.load(.numberValue) {
            return "\(number.intValue)"
        }
        return nil
    }
}
