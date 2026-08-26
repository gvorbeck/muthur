import Foundation

/// §10 — the numbers and the fixed words on the panel.
///
/// Small enough to look like it does not need writing down, and it does: every
/// one of these strings is a thing the script settled on and half of them are
/// worded the way they are because of something that went wrong once.
public enum Readout {

    /// `mmssv` (`panel.sh:148`). Minutes are not padded; seconds always are.
    /// A track is `3:07` and a record is `41:53`, and neither of them wants a
    /// leading zero on the left of a colon.
    public static func mmss(_ seconds: Int) -> String {
        let whole = max(0, seconds)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    /// `TRACK 02 OF 11` (`player:2385`).
    public static func trackLabel(row: Int, of count: Int) -> String {
        String(format: "TRACK %02d OF %02d", row + 1, count)
    }

    /// The label on the meter above it. The album meter's is the one word.
    public static let albumLabel = "ALBUM"

    /// `0:00 / 0:00`, the counter that sits at the right-hand end of both
    /// meters' labels. The pad between label and counter is worked out from the
    /// finished string, so both readouts land on the same right-hand edge as
    /// the bars under them (`player:2380`).
    public static func counter(_ position: Int, _ length: Int) -> String {
        "\(mmss(position)) / \(mmss(length))"
    }

    /// The row number in the list. Two places, and it is the **row**, not the
    /// track's tag — a folder of untagged rips is every row at 9999 and this
    /// column still counts one to eleven (`player:2356`, and D25 for the same
    /// argument made about the resume offer).
    public static func rowNumber(_ row: Int) -> String {
        String(format: "%02d", row + 1)
    }

    /// What is below the fold, worded the same way wherever a list gets clamped
    /// (`panel.sh:384`).
    public static func more(_ count: Int) -> String { "▾ \(count) MORE" }


    // MARK: - The marks in the gutter

    /// Two different things are marked on the track list and they are not the
    /// same thing (`player:2344`).
    public enum Mark: Sendable, Equatable {
        /// `♪` — the music is coming out of this row.
        case playing
        /// `‖` — it is, but paused.
        case held
        /// Nothing.
        case none

        public var glyph: String {
            switch self {
            case .playing: "♪"
            case .held: "‖"
            case .none: " "
            }
        }
    }

    /// The cursor's own mark, which is a different mark on purpose: the
    /// highlighted row with `▶` in the gutter is where you are looking, and `♪`
    /// is where the music is. Usually they agree; when you browse ahead they do
    /// not, and the panel has to be able to say so — which is why the playing
    /// mark is not a second arrow.
    public static let cursorGlyph = "▶"

    // MARK: - The status line

    /// Pinned to the character: the leading `▪` is what makes a message read as
    /// the machine answering rather than as another label on the panel
    /// (`player:2702`).
    ///
    /// The deck's own messages — shuffle, repeat, end of album, and the two
    /// failures — are `PlaybackEngine.Status`, because the deck is what knows
    /// when to say them. This is here for the one message the deck has no part
    /// in: §7's resume offer, which is a thing the panel says before anything
    /// has started playing at all.
    public static func status(_ text: String) -> String { "▪ \(text)" }

    // MARK: - The legend

    /// What pressing a cap asks for. Named rather than left as a closure so the
    /// legend can stay in the kit — the panel's actions live in `App/` and the
    /// kit is not allowed to know they exist.
    public enum Press: String, Sendable, Equatable, CaseIterable {
        case play
        case seekBack, seekForward
        case selectUp, selectDown
        case jump
        case next, previous
        case shuffle, repeatMode
        case rescan
        /// Off the check screen and back to the panel (§11). New — `--check`
        /// leaves by ending the program (`player:531`), which a window cannot
        /// do.
        case close
        case quit
    }

    /// One key on the plate, and the label beside it in the open.
    public struct Cap: Sendable, Equatable {
        public let key: String
        public let label: String

        /// One press for a plain cap. **Two for a rocker** — `←→` and `↑↓` are
        /// drawn as two glyphs on one plate, which is a rocker switch and not a
        /// button, so it is pressed at one end or the other. The order here is
        /// the order the glyphs are drawn in, which is what lets the view split
        /// the plate without being told twice.
        public let presses: [Press]

        public init(_ key: String, _ label: String, _ presses: Press...) {
            self.key = key
            self.label = label
            self.presses = presses
        }
    }

    /// The two keycap rows, both of them (`player:2429`).
    ///
    /// Volume and mute are not on it. The script had neither, and the row is
    /// already the width of the panel — a legend that has to wrap has stopped
    /// being a legend. §14's transport takes the same view.
    public static let legend: [[Cap]] = [
        [
            Cap("␣", "PLAY", .play),
            Cap("←→", "SEEK", .seekBack, .seekForward),
            Cap("↑↓", "SELECT", .selectUp, .selectDown),
            Cap("⏎", "JUMP", .jump),
            Cap("N", "NEXT", .next),
            Cap("P", "PREV", .previous),
        ],
        [
            Cap("S", "SHUFFLE", .shuffle),
            Cap("R", "REPEAT", .repeatMode),
            Cap("Q", "QUIT", .quit),
        ],
    ]

    /// The picker's keycap row (`player:1134`).
    public static let pickerLegend: [[Cap]] = [
        [
            Cap("↑↓", "SELECT", .selectUp, .selectDown),
            Cap("⏎", "OPEN", .jump),
            Cap("R", "RESCAN", .rescan),
            Cap("Q", "QUIT", .quit),
        ],
    ]

    /// The check screen's row (§11). Two things can be done to a health check —
    /// leave it, or ask it again after fixing something — and `R` is already
    /// the key that means *go and look again* in the picker.
    public static let checkLegend: [[Cap]] = [
        [
            Cap("⏎", "RETURN", .close),
            Cap("R", "RECHECK", .rescan),
            Cap("Q", "QUIT", .quit),
        ],
    ]

    /// Whether holding the cap down should go on asking.
    ///
    /// The two rockers only. Holding `←→` to run through a track and `↑↓` to run
    /// down the list is the whole point of them being rockers, and the keyboard
    /// already does it — `onKeyPress(phases: [.down, .repeat])`. The rest are
    /// single-throw switches: a held `S` toggling shuffle twenty times a second
    /// is not a faster way of doing anything, it is a coin being flipped.
    public static func repeats(_ press: Press) -> Bool {
        switch press {
        case .seekBack, .seekForward, .selectUp, .selectDown: true
        default: false
        }
    }
}
