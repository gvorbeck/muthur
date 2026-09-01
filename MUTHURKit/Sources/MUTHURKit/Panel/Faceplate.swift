import Foundation

/// §10 — the faceplate every screen wears: the badge, a rule across the panel,
/// and the state of the machine stamped at the far end the way a deck prints
/// its mode (`panel.sh:256`).
///
/// Every stage of every job wears the same one, which is most of why they read
/// as one instrument rather than as a run of unrelated screens. The badge is
/// the only part that differs between the tools that share it, and here it is
/// always the one word.
///
/// **Five screens wear it, and each one puts something different at the far
/// end.** The script has three of them — the picker's `N SOURCES`
/// (`player:1063`), the loading stage's own title (`player:1167`), and the
/// now-playing panel's `PLAYING · 9 TRACKS · tags` (`player:2322`). The port
/// adds two it had to invent, and both are here rather than in the views so
/// that "every screen wears the same plate" is a thing the suite can be asked
/// about: the check screen (`checkMeta`), which in bash is a terminal and not a
/// panel at all, and the empty deck, which in bash cannot exist because
/// `pick_source` ends the program rather than coming back with nothing
/// (`player:1114`). The empty deck takes the ordinary `meta` and gets
/// `STOPPED · 0 TRACKS`, which is not a special case so much as the true one.
public enum Faceplate {

    /// Drawn as text and never touching the filesystem, so it is the slashed
    /// form (`CLAUDE.md`).
    public static let badge = "MU/TH/UR"

    /// What the deck is doing, stamped at the far end of the rule
    /// (`player:2547`, `player:3309`, `player:3401`, `player:3497`).
    public enum Mode: String, Sendable, Equatable, CaseIterable {
        case playing = "PLAYING"
        case paused = "PAUSED"
        case stopped = "STOPPED"
        /// The record has run out. Not the same as stopped: stopped is a thing
        /// you did and finished is a thing the record did.
        case finished = "FINISHED"
    }

    /// `PLAYING · 9 TRACKS · tags` (`player:2322`).
    ///
    /// The metadata source is on the faceplate and **nowhere else on this
    /// screen**. The header block underneath deliberately does not repeat it:
    /// saying it twice on one panel reads like two different facts
    /// (`player:2325`).
    public static func meta(
        mode: Mode, trackCount: Int, source: TitleSource?, level: String? = nil
    ) -> String {
        var text = "\(mode.rawValue) · \(trackCount) TRACKS"
        if let source { text += " · \(source.rawValue)" }
        if let level { text += " · \(level)" }
        return text
    }

    /// The picker's meta: `N SOURCES` or `1 SOURCE`.
    public static func pickerMeta(count: Int) -> String {
        "\(count) \(count == 1 ? "SOURCE" : "SOURCES")"
    }

    /// The check screen's meta: `SELF TEST · 14 CHECKS · 2 !`.
    ///
    /// **Mine, and there is nothing behind it in the script** — `run_check`
    /// prints to a terminal and the program ends (`panel.sh:583`); there is no
    /// panel up and so no faceplate to write. §11 put the same report on a
    /// screen, and a screen in this port wears the plate.
    ///
    /// The shape is the one the other three metas already have: a state word,
    /// then a count of the thing on screen. `SELF TEST` rather than `HEALTH
    /// CHECK` because `CheckView`'s first line already says `MU/TH/UR HEALTH
    /// CHECK` — the plate says what the machine is *doing* and the block under
    /// it says what is being looked at, which is the same split as the
    /// now-playing panel, where the plate says `PLAYING` and the header says
    /// what the record is.
    ///
    /// The tally is at the tail for the same reason the volume is: it is the
    /// part that changes. Marks that are not there are not printed — a clean
    /// machine gets `SELF TEST · 14 CHECKS` and nothing else, because listing
    /// `0 ✗` is a way of raising the subject.
    public static func checkMeta(count: Int, warnings: Int, failures: Int) -> String {
        var text = "SELF TEST · \(count) \(count == 1 ? "CHECK" : "CHECKS")"
        if failures > 0 { text += " · \(failures) ✗" }
        if warnings > 0 { text += " · \(warnings) !" }
        return text
    }

    /// §6.1a's level, stamped at the tail of the meta. New (D1): bash had no
    /// volume and so had nothing to put here.
    ///
    /// It goes on the faceplate rather than beside the meters because the
    /// faceplate is where this panel says what the *machine* is set to, and the
    /// meters say what the *record* is doing. And it is drawn in the chrome
    /// amber with the mode and the track count, never as data — a number that
    /// competed with the titles for brightness would be the loudest thing on a
    /// screen about music.
    public static func level(volume: Float, muted: Bool) -> String {
        muted ? "MUTE" : "VOL \(Int((volume * 100).rounded()))"
    }

    /// How long the rule between the badge and the meta is (`panel.sh:257`).
    ///
    /// The badge is engraved with a space either side of the name, and the rule
    /// takes whatever the two ends do not — so the meta always finishes flush
    /// with the right-hand edge of every bar below it, however long the mode
    /// word is. Never shorter than two: a rule that has been squeezed to
    /// nothing stops reading as a rule and starts reading as a typo.
    /// How wide the badge stands when it is drawn as bash draws it: the name
    /// with a space either side.
    public static var plateColumns: Int { Columns.width(of: badge) + 2 }

    public static func rule(
        meta: String, width: Int = PanelGrid.width, plate: Int = plateColumns
    ) -> Int {
        max(2, width - plate - 2 - Columns.width(of: meta))
    }

    /// The finished line, margin and all: `  ␣MU/TH/UR␣ ━━━━━ PLAYING · …`.
    ///
    /// **Nothing here is ever cut.** `repv '━'` cannot truncate and neither can
    /// a mode word, so the only `…` that could ever appear on this line would be
    /// one the drawing put there — which is what it did, twice. This exists so
    /// the claim is a fact something can be asked about rather than a property
    /// of a layout pass.
    ///
    /// When the meta is long enough that the rule has hit its floor the line is
    /// wider than the panel, and that is `faceplate`'s answer, not an oversight:
    /// the rule gives way and the line overruns rather than the mode losing a
    /// letter (`panel.sh:257`).
    /// A wider badge than bash's — the wordmark at twice the dot pitch — is
    /// still this arithmetic; the plate is simply a different number of columns
    /// wide and the rule gives way by that much more.
    public static func line(
        meta: String, width: Int = PanelGrid.width, plate: Int = plateColumns
    ) -> String {
        let bar = String(repeating: "━", count: rule(meta: meta, width: width, plate: plate))
        return String(repeating: " ", count: PanelGrid.margin)
            + String(repeating: "▓", count: plate) + " " + bar + " " + meta
    }
}
