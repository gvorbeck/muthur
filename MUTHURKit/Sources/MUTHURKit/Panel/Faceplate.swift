import Foundation

/// §10 — the faceplate every screen wears: the badge, a rule across the panel,
/// and the state of the machine stamped at the far end the way a deck prints
/// its mode (`panel.sh:256`).
///
/// Every stage of every job wears the same one, which is most of why they read
/// as one instrument rather than as a run of unrelated screens. The badge is
/// the only part that differs between the tools that share it, and here it is
/// always the one word.
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
