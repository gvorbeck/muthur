import Foundation

/// One row in the source picker: a folder, a zip, or a disc.
///
/// The mark, the label and the detail are what the picker draws beside each
/// other in a row, and they are settled here rather than in the view so that
/// the view can be one loop and one highlight.
public struct PickerEntry: Sendable, Identifiable {
    public let id: UUID
    public let kind: SourceKind
    public let url: URL
    public let label: String
    public let detail: String

    public init(kind: SourceKind, url: URL, label: String, detail: String) {
        self.id = UUID()
        self.kind = kind
        self.url = url
        self.label = label
        self.detail = detail
    }

    /// The disc's row, which since D50 is the only row the picker ever draws
    /// without being pointed at something.
    ///
    /// `basename "$CD_VOLUME"` for the label (`player:1020`), and the count is
    /// **D18's**: `AudioFiles`, one definition of audio everywhere, rather than
    /// the script's `grep -ic '\.aiff\?$'`.
    ///
    /// One level deep, because the script counts with `ls` and not with `find`
    /// (`player:1019`) — and because a CDDA mount is flat, so anything nested
    /// under one is not a track.
    ///
    /// **The count and the detection use different definitions on purpose.**
    /// `DiscFinder.aiffCount` asks "does this look like a disc" and stays narrow;
    /// this asks "how many tracks does the disc have" and stays wide. D18 is
    /// only ever about the second.
    public static func disc(_ disc: DiscFinder.Found) -> PickerEntry {
        let count = AudioFiles.scan(disc.volume, maxDepth: 1).count
        return PickerEntry(
            kind: .disc, url: disc.volume,
            label: disc.volume.lastPathComponent,
            detail: discDetail(trackCount: count)
        )
    }

    /// `▸` folder, `▤` zip, `⊙` disc (`player:1073`).
    public var mark: String {
        switch kind {
        case .folder: "▸"
        case .zip: "▤"
        case .disc: "⊙"
        }
    }

    // `folderDetail`, `zipDetail` and the `du -h` formatter under them went with
    // the scan (**D50**). They rendered rows for folders and archives that had
    // been *found*, and nothing finds one any more: a record that arrives by
    // `BROWSE` is opened, not listed. `mark` keeps all three arms because it
    // switches over `SourceKind` and that enum still has three cases.

    /// The detail string for a disc: `N tracks · in the drive` (`player:1020`).
    /// 1019 is where the count is taken; 1020 is where this string is built.
    ///
    /// Not `· disc`. The other two rows name the *thing* — a zip, a folder — and
    /// this one names where it is, because that is the fact you are choosing on:
    /// there is only ever one drive, and what is in it is almost certainly what
    /// you came to play.
    public static func discDetail(trackCount: Int) -> String {
        "\(trackCount) \(trackCount == 1 ? "track" : "tracks") · in the drive"
    }
}
