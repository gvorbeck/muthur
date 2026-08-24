import Foundation

/// §9's columns: where each of the sixteen is, where its trail has got to, and
/// how long that trail has been abandoned (`player:588`).
///
/// Nothing here knows what a colour is or what a glyph is. What it knows is the
/// *grade* — which step of the ramp a cell is on and how solid it is — because
/// the grading is a decision the script took and §10 is only going to draw it.
public struct AnalyserColumns: Sendable, Equatable {

    /// `SPEC_BANDS`, `SPEC_ROWS`, `SPEC_TOP` (`player:92`).
    ///
    /// Forty steps of travel, five rows of eight eighths. That is the range the
    /// falling trail needs to actually be seen falling: fewer, and a column is
    /// at the floor before the eye has followed it down.
    public static let bands = Bands.count
    public static let rows = 5
    public static let top = AnalyserColumns.rows * 8

    /// `SPEC_FALL` (`player:98`). Two eighths a *frame*, and the frames are the
    /// tick's twenty a second rather than the levels' ten — the script advances
    /// the columns once per tick from a table it indexes by position, so every
    /// level is stepped twice and a peak takes a second to come down the whole
    /// column (`player:2671`, `player:2878`).
    public static let fall = 2

    /// `SPEC_H` — where the column is.
    public private(set) var height: [Int]
    /// `SPEC_G` — where its peak has got to on the way down.
    public private(set) var trail: [Int]
    /// `SPEC_A` — how many frames that trail has been abandoned for, which is
    /// what fades it out.
    public private(set) var age: [Int]

    public init() {
        height = [Int](repeating: 0, count: AnalyserColumns.bands)
        trail = [Int](repeating: 0, count: AnalyserColumns.bands)
        age = [Int](repeating: 99, count: AnalyserColumns.bands)
    }

    /// `spec_reset` (`player:595`). Called at every track change — carrying the
    /// last track's heights into the next one reads as a glitch
    /// (`player:3389`).
    public mutating func reset() {
        for band in 0..<AnalyserColumns.bands {
            height[band] = 0
            trail[band] = 0
            age[band] = 99
        }
    }

    /// `spec_step` (`player:609`).
    ///
    /// A column jumps to its new level the instant the level arrives — an
    /// analyser that eased upward would read as a slow analyser, not a smooth
    /// one — and only the falling is slowed, because that is the part the eye
    /// follows.
    public mutating func step(_ heights: [Int]) {
        for band in 0..<AnalyserColumns.bands {
            let h = band < heights.count ? min(AnalyserColumns.top, max(0, heights[band])) : 0
            height[band] = h
            if h >= trail[band] {
                // Caught up with its own trail: there is nothing left up there
                // to dissipate.
                trail[band] = h
                age[band] = 0
            } else {
                trail[band] = max(h, trail[band] - AnalyserColumns.fall)
                age[band] += 1
            }
        }
    }

    /// `SPEC_WAVE` and `spec_synth` (`player:922`).
    ///
    /// Two travelling waves at rates that do not divide into one another, so the
    /// columns keep drifting out of step instead of settling into a pattern you
    /// can see repeating. It is honest about being decoration: it never claims
    /// to be the music, it only says the deck is running.
    public static let wave = [4, 8, 14, 20, 26, 32, 36, 39, 40, 39, 36, 32, 26, 20, 14, 8]

    public mutating func synthesise(frame: Int) {
        let count = AnalyserColumns.wave.count
        step(
            (0..<AnalyserColumns.bands).map { band in
                let a = AnalyserColumns.wave[((frame / 2 + band * 3) % count + count) % count]
                let b = AnalyserColumns.wave[((frame / 3 + band * 5) % count + count) % count]
                return (a + b) / 2
            }
        )
    }

    // MARK: - What a cell is

    /// A step of the amber ramp. The panel owns the actual colours; this says
    /// which one, and the order is bright to dark.
    public enum Shade: Int, Sendable, Comparable, CaseIterable {
        /// `HEAD` (231) — the brightest thing on the screen.
        case head
        /// 220.
        case lit
        /// `AMBER` (214).
        case amber
        /// `ETCH` (172).
        case etch
        /// 130.
        case deep
        /// `RUNOUT` (94) — the darkest amber on the ramp.
        case runout
        /// 236 — the field the columns stand on. Not amber at all.
        case field

        public static func < (a: Shade, b: Shade) -> Bool { a.rawValue < b.rawValue }
    }

    /// How solid a trail cell is: `▓`, `▒`, `░` in the terminal, and whatever
    /// §10 decides they are worth on a screen with real alpha.
    public enum Density: Sendable, Equatable {
        case dense
        case medium
        case light
    }

    public enum Cell: Sendable, Equatable {
        /// Part of the column itself. `eighths` is 1 through 8, 8 being a whole
        /// cell. Graded **by row, not by band**: the top of the panel is the
        /// brightest, so a column that reaches the ceiling *arrives* there
        /// rather than merely being tall (`player:632`).
        case fill(eighths: Int, shade: Shade)
        /// Above the column but inside its trail: the light that has not gone
        /// out yet. Graded by age instead, down the same amber ramp the meters
        /// use, so it reads as the same light going out (`player:667`).
        case trail(shade: Shade, density: Density)
        /// Nothing here.
        case field
        /// The floor of an idle analyser — the power on and nothing moving.
        case floor
    }

    /// The shade a filled cell gets, by row from the top (`player:641`).
    public static func fillShade(row: Int) -> Shade {
        switch row {
        case 0: .head
        case 1: .lit
        case 2: .amber
        case 3: .etch
        default: .deep
        }
    }

    /// The shade and the density a trail cell gets, by how long it has been
    /// abandoned (`player:667`).
    public static func trailShade(age: Int) -> (Shade, Density) {
        switch age {
        case 0, 1: (.lit, .dense)
        case 2, 3: (.amber, .medium)
        case 4, 5: (.etch, .medium)
        case 6, 7: (.deep, .light)
        default: (.runout, .light)
        }
    }

    /// One row of the analyser, sixteen cells wide, row 0 being the top
    /// (`player:636`).
    public func cells(row: Int) -> [Cell] {
        let low = (AnalyserColumns.rows - 1 - row) * 8
        let shade = AnalyserColumns.fillShade(row: row)
        return (0..<AnalyserColumns.bands).map { band in
            let fill = height[band] - low
            let above = trail[band] - low
            if fill >= 8 { return .fill(eighths: 8, shade: shade) }
            if fill > 0 { return .fill(eighths: fill, shade: shade) }
            if above > 0 {
                let (trailShade, density) = AnalyserColumns.trailShade(age: age[band])
                return .trail(shade: trailShade, density: density)
            }
            return .field
        }
    }

    /// Every row, top first.
    public var grid: [[Cell]] { (0..<AnalyserColumns.rows).map(cells(row:)) }

    /// `spec_idle` (`player:699`) — the analyser with the power still on but
    /// nothing moving. A floor row lit, and not a blank panel, because blank is
    /// what a broken one shows.
    public static var idle: [[Cell]] {
        (0..<rows).map { row in
            [Cell](
                repeating: row == rows - 1 ? .floor : .field,
                count: bands
            )
        }
    }
}
