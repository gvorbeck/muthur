import Foundation

/// One line of the health check. §11.
///
/// `ck <ok|warn|fail> <label> <detail>` (`panel.sh:587`), kept whole: a mark, a
/// label in a fixed column, and a detail that is **never a bare status**. The
/// detail is the reason the screen exists — a check that says `fail` and stops
/// has told you that something is wrong and nothing about what to do, which is
/// the state the person running this was already in.
public struct Check: Sendable, Equatable, Identifiable {

    public enum Mark: Sendable, Equatable {
        case ok
        case warn
        case fail

        /// `✓` green, `!` yellow, `✗` red (`panel.sh:588`–`panel.sh:591`).
        public var glyph: String {
            switch self {
            case .ok: "✓"
            case .warn: "!"
            case .fail: "✗"
            }
        }
    }

    public let mark: Mark
    public let label: String
    public let detail: String

    public var id: String { label }

    public init(_ mark: Mark, _ label: String, _ detail: String) {
        self.mark = mark
        self.label = label
        self.detail = detail
    }

    /// `%-20s` (`panel.sh:588`). The panel draws on a character grid and this is
    /// the width the labels were already given.
    public static let labelWidth = 20

    /// What is left of the panel once the margin, the mark, its space, the
    /// label and its space have been taken: `  %s %-20s %s` with a fixed
    /// measure under it (`panel.sh:588`). A detail wider than this turns over
    /// rather than being cut — see `Columns.wrap`.
    ///
    /// The margin counts. Leaving it out puts two columns in this measure that
    /// the panel does not have, and the layout then truncates the tail of the
    /// line itself — which is exactly the fix disappearing off the right-hand
    /// edge that the wrap is here to prevent.
    public static let detailWidth =
        PanelGrid.width - PanelGrid.margin - (1 + 1 + labelWidth + 1)

    /// The detail as it lands on the panel, one entry per row.
    public var detailLines: [String] { Columns.wrap(detail, to: Check.detailWidth) }

    /// How many rows this check stands in.
    public var rows: Int { detailLines.count }
}
