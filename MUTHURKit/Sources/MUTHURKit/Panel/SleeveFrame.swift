import Foundation

/// How big the sleeve is allowed to be, and whether there is room for one at all
/// — `art_tick`'s arithmetic and nothing else (`player:3133`).
///
/// Three bounds, in the order the script applies them:
///
/// 1. **The columns to the right of the gutter.** Whatever the window has spare
///    once the panel and its gutter have taken their 73.
/// 2. **The rows above the analyser.** On a tall window this never binds. On a
///    short one it is the only thing keeping the cover off the instrument — the
///    script's reason was that the analyser erases its own rows nineteen times a
///    second and would strobe a hole through the picture, which is not a hazard
///    here; the reason it stays is the one that was true either way, that a
///    sleeve overlapping the analyser is a sleeve in the wrong place.
/// 3. **`ART_MIN`.** Under twelve columns the sleeve is not worth the columns and
///    is not drawn.
///
/// **There is no `ART_MAX` (D2).** The script's 42 was a ceiling on a character
/// grid whose picture is always as many pixels as the grid has cells
/// (`player:1758`) — past that the sleeve stopped looking like it was beside the
/// panel. `spec.md` drops the column range and a real image has no such ceiling:
/// widening the window is how you ask for a bigger cover. The rhythm is kept, the
/// ceiling is not.
public enum SleeveFrame {

    /// The answer, in **whole rows**. The bottom of the sleeve lands on a row
    /// boundary like everything else on the panel, and the width follows from the
    /// height rather than the other way round, because the height is the bound
    /// that actually binds.
    ///
    /// `cellAspect` is how many columns wide a cell is *tall*. The script could
    /// hard-code 2 because a terminal cell is about twice as tall as it is wide;
    /// here the face is measured and the number is whatever it measures, so a
    /// square cover comes out square rather than nearly square.
    ///
    /// Nil is not a failure. It is a window with no room for a cover, and the
    /// panel is then exactly the panel it has always been (`player:1746`).
    public static func rows(
        availableColumns: Int, rowsToAnalyser: Int, cellAspect: Double
    ) -> Int? {
        guard availableColumns > 0, rowsToAnalyser > 0, cellAspect > 0 else { return nil }
        // As many rows as the spare columns can make a square out of, then cut to
        // what is above the analyser.
        let byWidth = Int((Double(availableColumns) / cellAspect).rounded(.down))
        let rows = min(byWidth, rowsToAnalyser)
        guard rows > 0 else { return nil }
        // The width the picture will actually occupy. Fractional on purpose: it
        // is a picture, not a row of glyphs, and only the threshold below is
        // counted in columns.
        let columns = Double(rows) * cellAspect
        guard columns >= Double(PanelGrid.sleeveMinimum) else { return nil }
        return rows
    }
}
