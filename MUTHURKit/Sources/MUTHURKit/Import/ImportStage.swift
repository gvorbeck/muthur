import Foundation

/// §21 — the states an import passes through, as the screen sees them.
///
/// `BurnStage`'s shape, with its argument intact: *one instrument in several
/// states and not several screens* — the faceplate, the record being worked on
/// and the log are the same throughout, and only the body changes.
///
/// **It has three cases where the burn has four, and the missing one is the
/// interesting one.** There is no `insert`. A burn's first act is to ask for a
/// blank and wait, because the disc it needs is not in the machine; an import's
/// disc is already in the machine and already on the deck — it is the record
/// you are listening to. The only thing an import has to ask is *where*, and
/// that is answered by an open panel before this type exists at all.
public enum ImportStage: Sendable, Equatable {

    /// Making the folder and looking at the room. Before any audio is decoded,
    /// and usually over in a frame — but not always: `TempSpace.free` asks a
    /// volume that may be a spinning disk on the end of a USB cable, and a
    /// blank screen for that second is the hang `BurnPanel` refuses to draw.
    case preparing(into: String)

    /// A track being written (`stage_convert`'s half of this, `burncd:1543`).
    ///
    /// `head` is in the same units the burn's bar uses and is driven the same
    /// way — off the seconds actually converted, not off the count of tracks —
    /// so a long track moves the bar like a long track and the percentage on
    /// the faceplate is read off the head rather than counted separately.
    case importing(track: Int, ofTracks: Int, title: String, head: Int)

    /// Over, waiting to be dismissed. `written` is how many landed, which is
    /// not always how many were asked for: a track the drive could not read is
    /// logged and stepped over, exactly as §6.3 steps over a track that will
    /// not open rather than ending the record.
    case done(summary: String, written: Int, folder: String)

    // MARK: - The faceplate

    /// The line across the top.
    public var meta: String {
        switch self {
        case .preparing:
            "IMPORT · PREPARING"
        case .importing(_, _, _, let head):
            "IMPORT · \(BurnStage.percent(head))%"
        case .done(let summary, _, _):
            summary
        }
    }

    // MARK: - What each stage says

    /// The title on the `TRACK` line, cut to the same 46 the burn uses and for
    /// the same arithmetic: the line carries `TRACK`, `01 OF 13` and two gaps
    /// before the title gets its turn.
    public static let titleWidth = BurnStage.titleWidth

    /// `✓ 01 Let It Rock` — one line per track, as it lands.
    ///
    /// The number and not the running position, so the log reads like the disc
    /// rather than like the loop.
    public static func wroteNote(number: Int, title: String) -> String {
        "✓ \(String(format: "%02d", number)) \(Columns.fit(title, to: titleWidth))"
    }

    /// A track that would not read. §6.3's rule applied to writing instead of
    /// playing: say so, step over it, and let the other twelve land.
    public static func skippedNote(number: Int, why: String) -> String {
        "✗ \(String(format: "%02d", number)) — \(why)"
    }

    /// `13 TRACKS · FLAC · 44:21 · 3:08 ELAPSED`, on `BurnStage.summary`'s
    /// pattern and carrying the one thing that summary has no need of: **what
    /// they were written as.** An import's whole result is a set of files in a
    /// format, and a summary that did not name the format would be leaving out
    /// the answer.
    public static func summary(
        written: Int, of asked: Int, format: ImportFormat, runtime: Int, elapsed: Int
    ) -> String {
        let plural = written == 1 ? "" : "S"
        var line =
            "\(written) TRACK\(plural) · \(format.name) · \(Readout.mmss(runtime)) "
            + "· \(Readout.mmss(elapsed)) ELAPSED"
        // Only when they differ. `13 OF 13` is a machine talking, which is the
        // objection `insertPrompt` raises about `disc 1 of 1`.
        if written < asked {
            line += " · \(asked - written) NOT IMPORTED"
        }
        return line
    }

    /// What is said when it was called off. Not a fault, the way
    /// `BurnRun`'s cancel is not: somebody said stop, and the program agreeing
    /// is not the program complaining.
    ///
    /// It names what was kept, because that is the only question a cancelled
    /// import leaves — **and what was kept is nothing.** See
    /// `ImportJob.cancelled`.
    public static func cancelledSummary(elapsed: Int) -> String {
        "CANCELLED · \(Readout.mmss(elapsed)) ELAPSED · nothing kept"
    }

    // MARK: - The bar

    /// One band per track across the full strip, as the burn draws it — the
    /// disc's own tracks are the whole bar, with no empty tail, because the
    /// import is over when the last track is written.
    public static func bands(
        durations: [Int], width: Int = PanelGrid.stripWidth
    ) -> [Meter.Band] {
        Meter.bands(for: durations, cells: width)
    }

    public static func cells(
        head: Int, bands: [Meter.Band], width: Int = PanelGrid.stripWidth
    ) -> [Meter.Cell] {
        Meter.cells(head: head, bands: bands, width: width)
    }

    /// Where the head stands after `seconds` of a `runtime`-second record.
    ///
    /// Clamped at both ends. The floor is arithmetic hygiene; the ceiling is
    /// real — ffmpeg's `out_time_us` on the last track can run a few
    /// milliseconds past the duration §3 rounded *up* from the container, and a
    /// head past the end of the strip draws a bar one cell too long.
    public static func head(
        seconds: Double, runtime: Int, width: Int = PanelGrid.stripWidth
    ) -> Int {
        let units = width * Meter.unitsPerCell
        guard runtime > 0, seconds > 0 else { return 0 }
        return max(0, min(units, Int(seconds * Double(units) / Double(runtime))))
    }

    // MARK: - The foot

    /// The stage's keycaps, off `Readout.importLegend` — which is where the
    /// reasoning about the cancel lives, and where the widths get measured with
    /// every other legend's.
    ///
    /// `canReveal` is the stage's own knowledge and not the run's: a summary
    /// that named a folder has one to show, and a summary that is a refusal or
    /// a cancellation does not.
    public var keys: [[Readout.Cap]] {
        switch self {
        case .preparing, .importing:
            Readout.importLegend(finished: false, canReveal: false)
        case .done(_, let written, let folder):
            Readout.importLegend(finished: true, canReveal: written > 0 && !folder.isEmpty)
        }
    }
}
