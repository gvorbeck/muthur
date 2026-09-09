import Foundation

/// §20 stage 3 — the lamp under the burn meter (`burn_scan`, `burncd:1620`).
///
/// A lamp sweeping a dark field, where the plan's meter puts its minute scale.
/// It exists because a burn is twenty minutes of a number that moves once every
/// few seconds, and a panel with nothing moving on it looks like a panel that
/// has died.
///
/// **It keeps its own time, and that is the whole design.** It used to step once
/// per message from the drive, which made it an honest stall indicator and a
/// poor lamp: cdrecord speaks about once a second, so a crossing took the better
/// part of two minutes and the thing read as stuck — the exact impression it is
/// there to prevent. Showing a stall falls to the numbers above it, which are
/// the ones you would read to confirm it anyway (`burncd:1604`).
///
/// **Nothing here knows what a colour is**, on `Meter`'s rule: a cell carries
/// how far behind the lamp it is, because that is all the script decided —
/// `220`, `214`, `172`, `130` and the run-out are §10's four ambers reused, and
/// which pixels those are is `App/`'s to say.
public enum Lamp {

    /// How often the lamp is redrawn, and how far it travels each time
    /// (`burncd:97`). Its speed is `step / tick` — forty cells a second, about a
    /// second and a half to cross the panel. Much faster and the trail smears
    /// into a blur; much slower and it starts to read as a progress bar, which
    /// is the one thing it must not be mistaken for: the bar above it is the
    /// progress.
    public static let tick = 0.05
    public static let step = 2

    /// One column of the field.
    public enum Cell: Sendable, Equatable {
        /// The lamp itself.
        case head
        /// Behind it, `1` through `5` — the trail, falling off the way it came.
        case trail(behind: Int)
        /// The dark field the lamp is sweeping.
        case dark
    }

    /// The trail is five cells long and then it is dark (`burncd:1636`).
    public static let trailLength = 5

    /// One frame of the sweep.
    ///
    /// The distance is measured **against the way the lamp is travelling**, so
    /// the trail falls off behind it and the leading edge stays sharp. Getting
    /// the sign the wrong way round puts the fade out in front and the whole
    /// thing reads as moving backwards — which is the script's own comment, and
    /// the reason the direction is a multiplier rather than an `abs`.
    ///
    /// The bounce is the script's too, and it is off by one on purpose: the
    /// field is `width` wide, the turn is tested at `width` and reflected about
    /// `width - 1`, so the lamp reaches the far bezel and comes back without
    /// resting a frame against it.
    public static func cells(frame: Int, width: Int = PanelGrid.stripWidth) -> [Cell] {
        guard width > 1 else { return Array(repeating: .dark, count: max(0, width)) }
        let span = (width - 1) * 2
        var position = ((frame % span) + span) % span
        var direction = 1
        if position >= width {
            position = span - position
            direction = -1
        }
        return (0..<width).map { column in
            let behind = (position - column) * direction
            switch behind {
            case 0: return .head
            case 1...trailLength: return .trail(behind: behind)
            default: return .dark
            }
        }
    }
}
