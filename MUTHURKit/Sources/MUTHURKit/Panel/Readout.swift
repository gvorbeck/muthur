import Foundation

/// §10 — the numbers and the fixed words on the panel.
///
/// Small enough to look like it does not need writing down, and it does: every
/// one of these strings is a thing the script settled on and half of them are
/// worded the way they are because of something that went wrong once.
public enum Readout {

    /// `mmssv` (`panel.sh:148`), with hours folded back in above sixty minutes
    /// (D60 — a divergence, not a fix: `panel.sh:148` is
    /// `printf '%d:%02d' $(($1/60)) $(($1%60))` with no hour term at all, so the
    /// script would print a three-hour record's total the same way this port
    /// used to, `190:06`). Minutes and hours are not padded; seconds always are,
    /// and so are minutes once there is an hour in front of them — a track is
    /// `3:07`, a record under the hour is `41:53`, and a long one is `3:10:06`,
    /// never `3:190:06` or `3:70:06`.
    public static func mmss(_ seconds: Int) -> String {
        let whole = max(0, seconds)
        let hours = whole / 3600
        let minutes = (whole % 3600) / 60
        let secs = whole % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
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
        /// `-` `=`, new as keys (D1); new again as a cap (D58) — the width
        /// objection that had kept them off the legend gave way to wanting them
        /// found at all.
        case volumeDown, volumeUp
        /// `m`, the same story as the pair above.
        case mute
        /// Ask the drive again (`player:1018`). It was named for `scan_sources`
        /// and outlived it (D50) — the bay is the one thing left that can change
        /// under a screen that is already drawn.
        case rescan
        /// Open a record from anywhere (§14). New, and since D50 it is the way
        /// in for everything that is not the disc: the script's picker is the
        /// search path or nothing, because a TUI over ssh has no file chooser to
        /// offer. A window does.
        case browse
        /// Take the record off and go back to the start screen (§14, **D57**).
        /// New, and with nothing behind it in the script: `pick_source` runs
        /// once and `q` ends the program (`player:3531`), so a terminal never
        /// needed a way back — you type `player` again. A window has no again.
        case eject
        /// Off the check screen and back to the panel (§11). New — `--check`
        /// leaves by ending the program (`player:531`), which a window cannot
        /// do.
        case close

        /// Open the plan screen on the record already on the deck (§20).
        ///
        /// `burncd` is a second program and this is the seam where it becomes a
        /// key: the script has no equivalent, because in a terminal you leave
        /// `player` and type `burncd`. `B` is free on the playing panel — it
        /// means BROWSE on the picker, which is a different screen, the way `R`
        /// already means REPEAT here and RESCAN there.
        case burn

        // The plan screen (§20.4). `⇧↑↓` is a rocker like `↑↓` above it, and
        // for the same reason: one plate, pressed at one end or the other.
        case moveUp, moveDown
        case rename
        case artist
        case drop
        /// `S` on this screen, where it means *start a new disc here* — not
        /// shuffle, which is not a thing you do to a plan.
        case split
        case undo
        /// Put the running order back the way the folder had it (D66). Distinct
        /// from `.rescan`, which asks the drive again: nothing is re-read here.
        case reset

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

    /// The keycap rows — three now, not two (`player:2429`, D58).
    ///
    /// Volume and mute were kept off this legend on the grounds that the script
    /// had neither and the row was already the width of the panel — a legend
    /// that has to wrap has stopped being a legend. Sound reasoning for a row,
    /// and the wrong call for the whole legend: it left two keys nobody could
    /// find without having read `PanelView.letter`. They wrap. §14's transport
    /// has not yet been asked to make the same trade.
    ///
    /// **`E EJECT` is on the second row and not the first** (D57). The first is
    /// the transport and measures 67 of the 69 columns, which is no room at all;
    /// the second is what you do *to* the record rather than inside it, which is
    /// where taking it off belongs anyway. `E` was the free letter — `N P S R Q`
    /// are spoken for — and *eject* is the program's own word for the thing the
    /// key does. Measured with the rest by `KeycapTests.fits`: the second row
    /// goes 35 → 47.
    ///
    /// **`Q` stays last**, where the hand already looks for it, on the picker
    /// row's precedent.
    ///
    /// **`VOL` and `MUTE` are the third row, after `QUIT` and not folded into
    /// it** (D58). Row two at 47 of 69 has room to spare on paper, but putting
    /// both new caps on it lands at exactly 69 — no margin at all, the same
    /// complaint the old comment made about the legend as a whole. A row that
    /// wraps and still has slack in it is the better trade. They read after
    /// `QUIT` because that is where an addition belongs: last in, last placed.
    ///
    /// **`B BURN` joins row two, between `EJECT` and `QUIT`** (§20). It is the
    /// argument D57 already made for putting `EJECT` there: burning is
    /// something you do *to* the record rather than inside it, and row one is
    /// the transport. It goes after `EJECT` because that is where an addition
    /// belongs, and before `QUIT` because `Q` stays last. Row two goes 47 → 58,
    /// measured by `KeycapTests.fits` and not by the arithmetic in this
    /// sentence.
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
            Cap("E", "EJECT", .eject),
            Cap("B", "BURN", .burn),
            Cap("Q", "QUIT", .quit),
        ],
        [
            Cap("-=", "VOL", .volumeDown, .volumeUp),
            Cap("M", "MUTE", .mute),
        ],
    ]

    /// The picker's keycap row (`player:1134`), plus `BROWSE` — **and it is now
    /// two rows, one of which is not drawn at the same time as the other.**
    ///
    /// D50 took the scan away, so the picker is the disc or it is nothing, and
    /// there is no list left to walk: `↑↓ SELECT` is gone from both forms
    /// because with at most one row there is nowhere for a cursor to go. When
    /// the bay is empty `⏎ OPEN` goes too, since it would open nothing. That is
    /// the same rule the check screen's row and the loading screen's absent row
    /// are already keeping — a legend naming keys the screen does not answer is
    /// the same lie the dead ⌘O was.
    ///
    /// **`BROWSE` sits between `RESCAN` and `QUIT`** and not at the end, because
    /// what comes before it is *do something about a record* and `QUIT` is the
    /// way out. `Q` stays last, where the hand already looks for it.
    ///
    /// **`RESCAN` survives the scan it was named for**, and means the one thing
    /// it always mainly meant: `r` re-runs `find_cd`, so a disc put in after the
    /// screen was drawn appears (`player:1018`). The bay is all there is left to
    /// look at, and looking again at it is still worth a key.
    ///
    /// Measured against the 69 columns, by the arithmetic `KeycapTests.fits`
    /// uses — a plate is ` KEY `, a legend is ` LABEL`, three columns between
    /// caps. With the disc: 36 of caps and 9 of gaps, **45**. With an empty bay:
    /// 28 and 6, **34**. The row that used to be there was 59, so there is more
    /// air on this screen than there was, not less.
    public static func pickerLegend(hasDisc: Bool) -> [[Cap]] {
        var caps: [Cap] = []
        if hasDisc { caps.append(Cap("⏎", "OPEN", .jump)) }
        caps.append(Cap("R", "RESCAN", .rescan))
        caps.append(Cap("B", "BROWSE", .browse))
        caps.append(Cap("Q", "QUIT", .quit))
        return [caps]
    }

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

    /// The plan screen's rows (§20.4, `burncd:1181`).
    ///
    /// Eleven keys, which is more than a row holds, and **the break between
    /// them is the script's own** (`burncd:1008`): the first row is what you do
    /// to a track, ending with dropping it, and the second is what you do to
    /// the plan and to the program. `⇧↑↓` is drawn as a rocker beside the plain
    /// `↑↓` because that is what it is — the same plate with a shift on it —
    /// and putting them next to each other is the only explanation either one
    /// needs.
    ///
    /// **`S` means SPLIT here and SHUFFLE on the panel.** Both are the script's
    /// own letters on their own screens (`burncd:1188`, `player:2429`), and
    /// shuffling a burn plan is not a thing anyone wants; the same is true of
    /// `R`, which is REPEAT on the panel, RESCAN on the picker and RESET here.
    ///
    /// **`B` is BURN in both places and means the same thing in both** — it is
    /// how you got to this screen and it is how you leave it forwards. Until
    /// stage 3 it declines, and says so.
    ///
    /// **`ESC BACK` is the eleventh key and it is not the script's (D68).**
    /// `tui_edit` has two ways out and neither of them is this one: `b` goes on
    /// to the burn, and `q` is `die "cancelled"` — the whole program
    /// (`burncd:1203`). That is a complete set in a terminal, where the editor
    /// *is* the session. It is not one in a window, where the deck is still
    /// spinning underneath and `B` declines until stage 3: without this cap the
    /// only way off the plan screen is to quit the app, which is D57's argument
    /// about `E` made a second time. `Q` still means the program, on this
    /// screen as on every other, because a legend that says QUIT and closes a
    /// panel is a legend that lies once and is never trusted again.
    ///
    /// Measured by `KeycapTests.fits` rather than by this arithmetic.
    public static let planLegend: [[Cap]] = [
        [
            Cap("↑↓", "SELECT", .selectUp, .selectDown),
            Cap("⇧↑↓", "MOVE", .moveUp, .moveDown),
            Cap("⏎", "RENAME", .rename),
            Cap("A", "ARTIST", .artist),
            Cap("X", "DROP", .drop),
        ],
        [
            Cap("S", "SPLIT", .split),
            Cap("U", "UNDO", .undo),
            Cap("R", "RESET", .reset),
            Cap("B", "BURN", .burn),
            Cap("ESC", "BACK", .close),
            Cap("Q", "QUIT", .quit),
        ],
    ]

    /// The insert stage's row (§20 stage 3, `burncd:1536`).
    ///
    /// `keys '⏎' BURN E EDIT Q CANCEL`, and the middle cap is conditional in the
    /// script for a reason worth keeping: **going back is only offered on the
    /// first disc of the job, and only when the job started there.** Once a disc
    /// is written the plan it came from is a fact about a physical object, and
    /// re-cutting the running order underneath it would renumber discs that are
    /// already in a sleeve.
    ///
    /// `Q` is CANCEL and not QUIT, which is the one place in the program that
    /// letter means something narrower than the whole session — and it is the
    /// script's own word (`burncd:1539`). It is accurate here: nothing has been
    /// written yet, so there is a job to cancel rather than only a program to
    /// leave. `.quit` is still the press behind it, because what the key does to
    /// the burn is end it.
    ///
    /// `E EDIT` presses `.close`, which is the plan screen's `ESC BACK` — the
    /// same movement backwards out of a screen, arriving at the same editor.
    public static func burnLegend(canEdit: Bool) -> [[Cap]] {
        var caps = [Cap("⏎", "BURN", .burn)]
        if canEdit { caps.append(Cap("E", "EDIT", .close)) }
        caps.append(Cap("Q", "CANCEL", .quit))
        return [caps]
    }

    /// Whether holding the cap down should go on asking.
    ///
    /// The three rockers. Holding `←→` to run through a track, `↑↓` to run down
    /// the list, and `-=` to run the level up or down is the whole point of them
    /// being rockers, and the keyboard already does all three —
    /// `onKeyPress(phases: [.down, .repeat])`. The rest are single-throw
    /// switches: a held `S` toggling shuffle twenty times a second is not a
    /// faster way of doing anything, it is a coin being flipped, and a held `M`
    /// is the same coin.
    ///
    /// **`⇧↑↓` repeats too**, and it is the fourth rocker rather than an
    /// exception: dragging a track from eleventh place to second is one gesture
    /// held down, and nine deliberate presses is the same coin flipped the
    /// other way. It stops on its own at either end, where `moveTrack` declines
    /// and the cursor stays put.
    public static func repeats(_ press: Press) -> Bool {
        switch press {
        case .seekBack, .seekForward, .selectUp, .selectDown, .volumeDown, .volumeUp,
            .moveUp, .moveDown:
            true
        default: false
        }
    }
}
