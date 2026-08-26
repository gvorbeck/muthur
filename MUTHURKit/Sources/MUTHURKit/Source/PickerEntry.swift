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

    /// `▸` folder, `▤` zip, `⊙` disc (`player:1073`).
    public var mark: String {
        switch kind {
        case .folder: "▸"
        case .zip: "▤"
        case .disc: "⊙"
        }
    }

    /// The detail string for a folder: `N tracks · folder`.
    public static func folderDetail(trackCount: Int) -> String {
        "\(trackCount) \(trackCount == 1 ? "track" : "tracks") · folder"
    }

    /// The detail string for a zip: `457M · zip` (`du -h` format).
    public static func zipDetail(bytes: UInt64) -> String {
        "\(formatSize(bytes)) · zip"
    }

    /// The detail string for a disc: `N tracks · disc`.
    public static func discDetail(trackCount: Int) -> String {
        "\(trackCount) \(trackCount == 1 ? "track" : "tracks") · disc"
    }

    /// `du -h` format: powers of 1024, single-letter suffix, no space.
    /// One decimal when < 10, no decimal otherwise.
    static func formatSize(_ bytes: UInt64) -> String {
        let units: [Character] = ["K", "M", "G", "T"]
        var value = Double(bytes)
        var index = -1
        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        if index < 0 { return "\(bytes)B" }
        if value < 10 {
            return String(format: "%.1f%c", value, units[index].asciiValue!)
        }
        return "\(Int(value.rounded()))\(units[index])"
    }
}
