import Foundation

/// §10 — the grid the panel is set on.
///
/// `spec.md` says to treat the character grid as a design grid rather than a
/// constraint, and to drop the constraint where it only ever existed because of
/// the terminal. Most of `panel.sh`'s geometry was exactly that: the 25×71
/// floor, the row budget, the `\033[H` hazard that made a frame one line too
/// tall lose its top row forever.
///
/// The **column count** is not that, and the reason is not the one about
/// learnable columns. **The panel's width is fixed so that the sleeve has
/// somewhere to live** (`player:1738`): the panel ends at 71, most windows are
/// wider than that, and the cover goes in the space to the right that nothing
/// else was ever going to use. Columns 72 and 73 are the gutter — a sleeve
/// butted straight against the panel reads as part of the same object — and the
/// cover starts at column 74, row 3, level with the album title
/// (`player:504`). A panel that reflowed would take that space back and there
/// would be nowhere for the record's front to go.
///
/// The corollary is the part worth keeping in mind while reading `Line` below:
/// a window too narrow for a sleeve simply does not get one, and the panel is
/// exactly the panel it has always been. Widening the window is how you ask for
/// a bigger cover; it is not how you ask for a wider panel.
public enum PanelGrid {

    /// `PANEL` — the panel's own width, inside the two-column margin
    /// (`panel.sh:70`).
    public static let width = 69

    /// `STRIP_WIDTH` — a meter is the panel less its two bezels
    /// (`panel.sh:73`).
    public static let stripWidth = width - 2

    /// The margin the panel is indented by. **One margin, on the left** — a
    /// line is `2 + PANEL = 71` columns and not 73. A meter is `  ▐` +
    /// `stripWidth` cells + `▌`, which is where §6.4's `x - 4` comes from
    /// (`player:3204`).
    public static let margin = 2

    /// A whole line of the panel, margin included: 71 columns, and the number
    /// the sleeve's geometry is measured from (`player:1743`).
    public static var line: Int { margin + width }

    /// Columns 72 and 73 — the gap between the panel and the sleeve. A cover
    /// butted straight against the panel reads as part of the same object
    /// (`player:504`).
    public static let gutterToSleeve = 2

    /// Column 74 in the script's one-based reckoning, which is `line + gutter`
    /// here (`ART_COL0`).
    public static var sleeveColumn: Int { line + gutterToSleeve }

    /// Row 3 — the cover starts level with the album title (`ART_ROW0`).
    public static let sleeveRow = 3

    /// `ART_MIN`. Under twelve cells the sleeve is not worth the columns and is
    /// not drawn at all (`player:523`).
    ///
    /// **There is no `ART_MAX`.** The script capped the cover at 42 because past
    /// that it stops looking like it is beside the panel and starts looking like
    /// the panel is beside it — but that ceiling was reasoning about a character
    /// grid whose picture is always as many pixels as the grid has cells
    /// (`player:1758`). `spec.md` drops the column range; a real image has no
    /// such ceiling, and widening the window is how you ask for a bigger sleeve.
    /// The rhythm is kept, the ceiling is not.
    public static let sleeveMinimum = 12

    /// The track list's own gutter: the margin, then the cursor's `▶` and the
    /// space after it. A row that is not the cursor's simply leaves those two
    /// places blank, which is what keeps the list from shifting sideways under
    /// the cursor (`player:2367`).
    public static let gutter = margin + 2

    /// What a track row spends on things that are neither title nor artist: the
    /// playing mark, the space after it, the two-place row number, the gap, the
    /// gap before the duration and the five places `%5s` gives the duration.
    public static let trackRowFurniture = 1 + 1 + 2 + 2 + 2 + 5

    /// 52 — `NP_TITLE_W` with no artist column, and title plus gap plus artist
    /// with one (`player:2287`).
    public static var textWidth: Int { width - gutter - trackRowFurniture }
}
