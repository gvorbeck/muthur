import Foundation

/// §20 stage 3 — the stages between the editor and the summary (`burncd:1386`).
///
/// The script's own account of it: *everything between the editor and the
/// summary is a stage of the same display — a faceplate, the album being worked
/// on, a body the stage supplies, and the log of what has happened so far. Each
/// one replaces the last from the home position, so waiting for a disc,
/// converting it, writing it and reporting on it are four states of one
/// instrument rather than four messages stacked up the terminal.*
///
/// So this is one type with four cases and not four screens. The faceplate, the
/// `ALBUM` field and the log are the same in all of them and belong to whatever
/// draws them; what changes is the body, which is what each case carries.
///
/// **The row budgets are not here.** `stage_insert` and `stage_done` spend a
/// dozen lines working out how many track rows or how many disc meters fit in
/// `TERM_LINES`, because a frame one line too tall on the alternate screen
/// scrolls the panel's own top row away for good. A window has no such hazard
/// and no fixed height, so the clamp is the view's — `Readout.more` is the same
/// `▾ n MORE` for when it has to clamp, on the same grounds `PanelGrid` gives
/// for dropping the 25×71 floor.
public enum BurnStage: Sendable, Equatable {

    /// Waiting for a blank disc — and the last look at what is about to be
    /// permanent (`stage_insert`, `burncd:1495`).
    ///
    /// It shows the same fields and the same track rows the editor showed, for
    /// this disc, because this is the moment the edits stop being reversible:
    /// the next key starts writing them into a lead-in. Reading the listing off
    /// a summary two screens back is not checking it.
    case insert(disc: Int, of: Int, canEdit: Bool)

    /// Building the image (`stage_convert`, `burncd:1543`).
    ///
    /// The bar is the same bar the burn draws — same bands, same head — because
    /// from the outside these are one process with two halves, and watching the
    /// head cross the disc twice is a truer picture of the wait than a spinner.
    case converting(disc: Int, of: Int, track: Int, ofTracks: Int, title: String, head: Int)

    /// The disc is done, on a stage of its own so the burn screen's last frame
    /// is not left sitting at 100% while the next disc is being asked for
    /// (`burncd:2680`).
    case written(disc: Int, of: Int, rehearsal: Bool)

    /// The job, finished, waiting to be dismissed (`stage_done`, `burncd:1560`).
    /// Every disc gets its meter; `discs` is `FROM…NDISCS`, which is the discs
    /// this run actually wrote and not the discs the job has.
    case done(summary: String, discs: [Int])

    // MARK: - The faceplate

    /// `stage <meta>` — the line across the top.
    public var meta: String {
        switch self {
        case .insert(let disc, let of, _):
            "INSERT · DISC \(disc) OF \(of)"
        case .converting(let disc, let of, _, _, _, let head):
            "CONVERTING · DISC \(disc) OF \(of) · \(BurnStage.percent(head))%"
        case .written(let disc, let of, let rehearsal):
            "\(rehearsal ? "REHEARSED" : "WRITTEN") · DISC \(disc) OF \(of)"
        case .done(let summary, _):
            summary
        }
    }

    /// The conversion's percentage is read off the bar rather than counted in
    /// tracks (`burncd:1556`): the head is where the seconds already converted
    /// put it, so a long track moves the number the way it moves the bar.
    static func percent(_ head: Int, width: Int = PanelGrid.stripWidth) -> Int {
        let units = width * Meter.unitsPerCell
        guard units > 0 else { return 0 }
        return min(100, head * 100 / units)
    }

    // MARK: - What each stage says

    /// The insert stage's prompt. It names the disc only when there is more than
    /// one, because "disc 1 of 1" is a machine talking (`burncd:1524`).
    public static func insertPrompt(disc: Int, of: Int) -> String {
        of > 1 ? "INSERT a blank CD-R for disc \(disc) of \(of)" : "INSERT a blank CD-R"
    }

    /// `✓ Disc 1 of 2 written` (`burncd:2687`) — a log line and not a stage,
    /// because the log outlives the stage it was written on.
    public static func writtenNote(disc: Int, of: Int, rehearsal: Bool) -> String {
        rehearsal
            ? "✓ Disc \(disc) of \(of) rehearsed — nothing written, disc still blank"
            : "✓ Disc \(disc) of \(of) written"
    }

    /// What `--verify` says about one disc once it has read it back
    /// (`burncd:2666`). The reasons are the read-back's own notes and are already
    /// in the log above this line, which is what `see above` is pointing at.
    public static func verifiedNote(disc: Int, passed: Bool) -> String {
        passed
            ? "✓ Disc \(disc) verified"
            : "✗ Disc \(disc) did not verify — see above"
    }

    /// The line the summary carries when a job had a disc fail its read-back
    /// (`burncd:2739`).
    ///
    /// It is said again at the end because the per-disc line above scrolled off
    /// four discs ago, and the one thing somebody needs out of a finished
    /// multi-disc job is which of the discs in front of them to throw away.
    public static func verifyFailedNote(discs: [Int]) -> String {
        "✗ Discs that did not verify: \(discs.map(String.init).joined(separator: " "))"
    }

    /// The summary's own line (`burncd:2699`): `2 DISCS · 78:12 · 21:04 ELAPSED`,
    /// and a rehearsal says so instead of claiming a runtime it did not write.
    public static func summary(discs: Int, runtime: Int, elapsed: Int, rehearsal: Bool) -> String {
        let plural = discs == 1 ? "" : "S"
        if rehearsal {
            return "REHEARSED · \(discs) DISC\(plural) · \(Readout.mmss(elapsed)) ELAPSED"
        }
        return
            "\(discs) DISC\(plural) · \(Readout.mmss(runtime)) "
            + "· \(Readout.mmss(elapsed)) ELAPSED"
    }

    /// The title on the `TRACK` line, cut to 46.
    ///
    /// Not `PanelGrid.textWidth`: this line carries `TRACK`, `01 OF 11` and two
    /// gaps ahead of the title where a plan row carries a two-place number, so
    /// it has six fewer columns to give it (`burncd:1552`).
    public static let titleWidth = 46

    // MARK: - The bar

    /// The bands this disc's two halves are both drawn against
    /// (`burncd:2472`) — one band per track, across the full strip. Unlike the
    /// plan's meter there is no empty tail to leave unlit: the burn is over when
    /// the last track is written, so the disc's own tracks are the whole bar.
    public static func bands(
        durations: [Int], width: Int = PanelGrid.stripWidth
    ) -> [Meter.Band] {
        Meter.bands(for: durations, cells: width)
    }

    /// The conversion's bar, at `head` units along those bands.
    public static func cells(
        head: Int, bands: [Meter.Band], width: Int = PanelGrid.stripWidth
    ) -> [Meter.Cell] {
        Meter.cells(head: head, bands: bands, width: width)
    }

    // MARK: - The foot

    /// The stage's keycap row, or nothing where there is no key to press.
    ///
    /// The conversion and the written stage have no foot in the script either:
    /// one is a wait you cannot answer and the other is gone by the time you
    /// could.
    public var keys: [[Readout.Cap]] {
        switch self {
        case .insert(_, _, let canEdit):
            Readout.burnLegend(canEdit: canEdit)
        case .done:
            [[Readout.Cap("Q", "QUIT", .quit)]]
        case .converting, .written:
            []
        }
    }
}
