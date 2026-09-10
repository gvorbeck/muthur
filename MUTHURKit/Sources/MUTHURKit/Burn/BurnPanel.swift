import Foundation

/// §20 stage 3 — the burn screen (`burn_frame` and `render`, `burncd:1706`,
/// `burncd:1782`).
///
/// The burn screen is the plan screen with the laser on: the same badge, the
/// same 69-column grid, the same amber. **The progress bar is the plan's
/// capacity meter again, and that is the whole idea** — the bands are the
/// tracks, in the same alternating ambers, so the plan you approved and the
/// disc being written out of it are visibly the same picture at two moments.
/// `Meter.bands` then `Meter.head` then `Meter.cells`, which is `bands()` then
/// `bandbar()`, which is what the plan's meter and the conversion's bar are
/// already made of.
///
/// **A burn has three phases and cdrecord narrates only the middle one.** The
/// two silent ones are seconds long apiece — on some drives the better part of
/// a minute — and the panel used to spend both showing the last frame of
/// whatever had spoken most recently: the conversion stopped at 95%, then the
/// write stopped at 97% until the disc came out. Both read as a hang. The
/// layout is identical in all three, with `--` standing in for the fields the
/// drive has not filled in, so nothing on screen moves when a phase changes
/// hands.
///
/// **What is not ported, and why.** `render` has a compact four-line readout for
/// a terminal under 71 columns (`burncd:1722`), and a window cannot get there:
/// `PanelView` sets `minWidth: Theme.panelWidth` under
/// `.windowResizability(.contentMinSize)`, so the panel's own width is the
/// window's floor. The same goes for the redraw machinery either side of it —
/// the home position, the once-a-second full frame with the lamp's row redrawn
/// alone in between, the hidden cursor. Those are a terminal's answers to a cost
/// a window does not pay. What is ported is everything that decides *what the
/// panel says*, which is all of `render` that survives having a screen.
public struct BurnPanel: Sendable, Equatable {

    /// Which of a burn's three phases the panel is drawing.
    public enum Phase: String, Sendable, Equatable {
        /// The drive spinning up, calibrating its laser power and writing the
        /// lead-in, before the first sector of audio reaches the disc.
        case lead
        /// The part with a progress line behind it.
        case write
        /// The buffer emptying and the lead-out going down, after the last
        /// sector of audio and before the disc is ejected.
        case tail
    }

    /// When the drive falling silent means the burn is finished rather than the
    /// drive being slow (`burncd:114`). cdrecord's progress line stops with the
    /// last sector of audio and says nothing at all through the lead-out.
    public static let tailQuiet = 3

    /// How far in silence has to be for it to be the lead-out (`burncd:115`).
    ///
    /// **Measured against the last track as well as against the disc**, because
    /// the disc figure has a ceiling below 100 that no burn can reach: cdrecord
    /// rounds each track down to a whole megabyte on its own and we round the
    /// image down once, so the sum of its roundings is short of ours by up to a
    /// megabyte a track — enough to hold a forty-track disc of short pieces
    /// under ninety-three percent for the whole of its burn. The last track's
    /// own progress carries no such arrears.
    public static let tailPercent = 95

    /// What the drive has not told us yet, in the panel's own words. The same
    /// dashes the plan screen puts where a year is missing.
    public static let unknown = "--"

    // MARK: - Fixed for this disc

    public let disc: Int
    public let discs: Int
    /// This disc's track titles, in play order — `P_TITLE[IDX[…]]`.
    public let titles: [String]
    /// This disc's track durations, which are the bar's bands.
    public let durations: [Int]
    /// The image's size in whole megabytes (`total_mb`, `burncd:2584`).
    public let totalMegabytes: Int
    /// `--dummy`. The laser stays off and the verb changes; nothing else does.
    /// `BurnJob.rehearsal` sets it, and it is the same flag that puts `-dummy`
    /// on the vector — one word carried from the switch to the screen.
    public let rehearsal: Bool

    // MARK: - What the drive has said

    public private(set) var phase: Phase = .lead
    /// The track cdrecord is on, one-based; zero before it has said anything.
    public private(set) var track = 0
    public private(set) var doneMegabytes = 0
    public private(set) var percent = 0
    /// How far into this one track the drive is, kept for the lead-out test
    /// alone. Both its numbers come from the same line, so it is free of the
    /// rounding that keeps the disc's percentage off 100.
    public private(set) var trackPercent = 0
    public private(set) var buffer = BurnPanel.unknown
    public private(set) var speed = BurnPanel.unknown
    public private(set) var elapsed = 0
    public private(set) var remaining: Int?
    /// The lamp's position, in cells travelled since the panel went up.
    public private(set) var frame = 0

    /// The running total across tracks. **Finished means the track's own stated
    /// size** rather than the last figure reported before the drive moved on:
    /// the two agree on the drives to hand, but the stated size cannot quietly
    /// lose a megabyte to a drive that falls silent a moment early
    /// (`burncd:1925`).
    private var baseMegabytes = 0
    private var trackMegabytes = 0
    private var lastTrack = 1
    /// When the drive last said anything, in seconds since the panel went up.
    private var lastMessage = 0

    public init(
        disc: Int, of discs: Int, titles: [String], durations: [Int],
        totalMegabytes: Int, rehearsal: Bool = false
    ) {
        self.disc = disc
        self.discs = discs
        self.titles = titles
        self.durations = durations
        self.totalMegabytes = totalMegabytes
        self.rehearsal = rehearsal
    }

    // MARK: - The drive's half

    /// One chunk of cdrecord's output — the carriage-return-delimited progress
    /// line, and every other thing it says, which is dropped (`burncd:1913`).
    ///
    /// `Track 03:  12 of  45 MB written (fifo 100%) [buf  98%]  8.0x.`
    ///
    /// **Read as words, not as a shape.** The script matches a regex whose
    /// anchors are `Track`, `of` and `MB`; this splits on whitespace and checks
    /// the same three, because those are what was observed and the rest of the
    /// line — the fifo, the trailing full stop, the exact column padding — is
    /// cdrecord's business and has changed between its versions before.
    public struct Progress: Sendable, Equatable {
        public let track: Int
        /// Megabytes written of this track, and this track's size.
        public let done: Int
        public let total: Int
        /// The drive's buffer, and the speed it is writing at, as text — both
        /// are printed as given and neither is arithmetic. Nil where the line
        /// did not carry them.
        public let buffer: String?
        public let speed: String?

        public init(track: Int, done: Int, total: Int, buffer: String?, speed: String?) {
            self.track = track
            self.done = done
            self.total = total
            self.buffer = buffer
            self.speed = speed
        }
    }

    public static func parse(_ chunk: String) -> Progress? {
        let words = chunk.split(whereSeparator: \.isWhitespace)
        guard words.count >= 6, words[0] == "Track", words[3] == "of", words[5] == "MB",
            words[1].hasSuffix(":"),
            let track = Int(words[1].dropLast()),
            let done = Int(words[2]),
            let total = Int(words[4])
        else { return nil }

        // `buf[[:space:]]+([0-9]+)%` — the number after the word, wherever the
        // brackets fall around it. cdrecord pads the figure into a fixed column,
        // so on a full buffer the word and the number are one token and on a
        // filling one they are two.
        var buffer: String?
        if let index = words.firstIndex(where: { $0.hasPrefix("[buf") || $0 == "buf" }) {
            let rest = words[index].drop { $0 == "[" }.dropFirst(3)
            if let value = digits(before: "%", in: rest) {
                buffer = value
            } else if words.indices.contains(index + 1) {
                buffer = digits(before: "%", in: words[index + 1])
            }
        }

        // `([0-9]+\.[0-9]+)x` — a decimal with an `x` after it, which on the
        // drives to hand is the last word of the line with a full stop stuck to
        // it.
        var speed: String?
        for word in words.reversed() {
            guard let x = word.firstIndex(of: "x") else { continue }
            let value = word[word.startIndex..<x]
            if value.contains("."), value.allSatisfy({ $0.isNumber || $0 == "." }) {
                speed = String(value)
                break
            }
        }
        return Progress(track: track, done: done, total: total, buffer: buffer, speed: speed)
    }

    private static func digits(before terminator: Character, in word: Substring) -> String? {
        let value = word.prefix { $0.isNumber }
        guard !value.isEmpty, word.dropFirst(value.count).first == terminator else { return nil }
        return String(value)
    }

    /// A message from the drive, at `seconds` since the panel went up.
    public mutating func receive(_ chunk: String, at seconds: Int) {
        guard let progress = BurnPanel.parse(chunk) else { return }
        phase = .write
        lastMessage = seconds

        if progress.track != lastTrack {
            baseMegabytes += trackMegabytes
            lastTrack = progress.track
        }
        track = progress.track
        trackMegabytes = progress.total
        // Clamped for the readout only: `baseMegabytes` keeps the unclamped
        // running total, so a disc that overshoots here cannot lose the
        // megabytes back again at the next track boundary (`burncd:1935`).
        doneMegabytes = min(totalMegabytes, baseMegabytes + progress.done)

        buffer = progress.buffer ?? BurnPanel.unknown
        speed = progress.speed ?? BurnPanel.unknown

        percent = totalMegabytes > 0 ? min(100, doneMegabytes * 100 / totalMegabytes) : 0
        trackPercent = progress.total > 0 ? progress.done * 100 / progress.total : 0

        elapsed = seconds
        // Under three percent there is not enough of a burn behind us to divide
        // by, and the estimate keeps its last value rather than being cleared —
        // an ETA that blinked back to dashes would be saying the drive had
        // stopped, which is the one thing it must not say by accident
        // (`burncd:1955`).
        if percent >= 3, seconds > 0 {
            remaining = seconds * (100 - percent) / percent
        }
    }

    // MARK: - The panel's own half

    /// One tick of the lamp's clock (`scan_ticker`, `burncd:1662`).
    ///
    /// Through every silence the clock is the one number that can move, and a
    /// clock that moves is the difference between a drive still working and a
    /// drive that has died. The lamp steps every tick; everything else here
    /// happens because the drive has stopped talking.
    public mutating func tick(at seconds: Int) {
        frame += Lamp.step
        elapsed = seconds

        // The drive has stopped talking with the disc all but full: the audio is
        // down and this is the lead-out. Said outright, and the bar taken to the
        // end, because cdrecord's last word comes at the end of the last track
        // and it then spends half a minute saying nothing.
        //
        // Either reading of "all but full" will do, and both are wanted: a drive
        // that stalls early in a long final track is on the last track and
        // nowhere near done, and neither reading calls that a lead-out.
        // Reversible on purpose besides — a drive that was only pausing takes
        // the panel straight back to the figures in its next message.
        let quiet = seconds - lastMessage >= BurnPanel.tailQuiet
        let full = percent >= BurnPanel.tailPercent
            || (track >= titles.count && trackPercent >= BurnPanel.tailPercent)
        if phase == .write, quiet, full {
            phase = .tail
            doneMegabytes = totalMegabytes
            percent = 100
            // Nothing is being written now: the buffer is draining and the table
            // of contents is going down. A buffer percentage and a speed left
            // over from the last track would be the panel's only two dishonest
            // numbers.
            remaining = nil
            buffer = BurnPanel.unknown
            speed = BurnPanel.unknown
        }
    }

    // MARK: - The frame

    /// `WRITING`, or `REHEARSING` under `--dummy` (`burncd:1807`).
    public var verb: String { rehearsal ? "REHEARSING" : "WRITING" }

    /// The percentage field, which is where the two silent phases say what they
    /// are. `%3d%%` and not `%d%%`: the rule is sized from what is left after
    /// the meta, so a percentage that grows a digit would shorten the rule by
    /// one and the whole header would twitch sideways twice a burn.
    public var percentField: String {
        switch phase {
        case .lead: "LEAD-IN"
        case .tail: "LEAD-OUT"
        case .write: String(format: "%3d%%", percent)
        }
    }

    /// The track number, which the drive alone can fill in.
    public var trackField: String {
        phase == .lead ? BurnPanel.unknown : String(format: "%02d", track)
    }

    /// `WRITING · DISC 1 OF 2 ·  42%`.
    public var meta: String {
        "\(verb) · DISC \(disc) OF \(discs) · \(percentField)"
    }

    /// The title on the `TRACK` line, or an em dash while the drive has not said
    /// which track it is on.
    public var title: String {
        guard phase != .lead, track >= 1, track <= titles.count else { return "—" }
        return Columns.fit(titles[track - 1], to: BurnStage.titleWidth)
    }

    /// `03 OF 11  Sixty Eight Grand`.
    public var trackLine: String {
        "\(trackField) OF \(String(format: "%02d", titles.count))  \(title)"
    }

    /// `412 OF 806 MB AT 8.0x`.
    public var writtenLine: String {
        "\(doneMegabytes) OF \(totalMegabytes) MB AT \(speed)x"
    }

    /// `97%   ELAPSED 3:41   REMAINING 4:02`, with the labels the view draws
    /// between them.
    public var bufferField: String { "\(buffer)%" }
    public var elapsedField: String { Readout.mmss(elapsed) }
    public var remainingField: String {
        guard let remaining else { return "--:--" }
        return Readout.mmss(remaining)
    }

    /// The bands, which are fixed for the whole disc — only the head moves, so
    /// they are worked out once (`burncd:1795`).
    public var bands: [Meter.Band] { BurnStage.bands(durations: durations) }

    /// The bar: this disc's tracks, with the write head where the drive says it
    /// is (`burncd:1770`).
    public func cells(width: Int = PanelGrid.stripWidth) -> [Meter.Cell] {
        Meter.cells(
            head: Meter.head(done: doneMegabytes, of: totalMegabytes, width: width),
            bands: BurnStage.bands(durations: durations, width: width),
            width: width
        )
    }

    /// The lamp's row, under the bar.
    public func lamp(width: Int = PanelGrid.stripWidth) -> [Lamp.Cell] {
        Lamp.cells(frame: frame, width: width)
    }
}
