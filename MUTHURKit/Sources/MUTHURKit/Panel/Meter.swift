import Foundation

/// §10 — the two bars, which are one mechanism drawn twice.
///
/// The album meter is `burncd`'s capacity meter with the playhead on it: one
/// band per track, sized by its share of the whole, the head where the needle
/// has got to and the run-out everything not yet reached. The picture you
/// approved before burning a disc is the picture you watch while playing it
/// back (`player:544`).
///
/// The track bar is the same cells with one band and one colour, because a
/// track has no internal structure worth banding (`player:556`).
///
/// Two of them rather than one, because they answer different questions and
/// each is the wrong answer to the other's: the track bar is *how much of this
/// song is left*, which is what you want when deciding whether to skip; the
/// album meter is the shape of the record and where in that shape you are
/// (`player:2262`).
///
/// Nothing here knows what a colour is. A band carries the *index* of its
/// shade, because that is all `bands()` ever decided — `SHADES[nb % 4]` — and
/// what those four ambers actually are is §10's to say.
public enum Meter {

    /// Eight units to a column. Unicode has a full set of left-aligned partial
    /// blocks and a cell can show two colours, so a boundary is drawn where it
    /// actually falls rather than snapped to the nearest whole character. That
    /// is eight times the resolution without one extra column, which is what
    /// lets a few cells still say that a 3:14 is longer than a 2:58
    /// (`panel.sh:398`).
    public static let unitsPerCell = 8

    /// Four ambers, zigzagging light and dark so neighbouring bands separate on
    /// brightness even where the hues are cousins — and so the edges survive
    /// without colour vision (`panel.sh:92`).
    public static let shades = 4

    /// Where a band ends, in units from the left, and which of the four shades
    /// it wears.
    public struct Band: Sendable, Equatable {
        public let end: Int
        public let shade: Int

        public init(end: Int, shade: Int) {
            self.end = end
            self.shade = shade
        }
    }

    // MARK: - Widths

    /// Band widths by **largest remainder** (`panel.sh:414`).
    ///
    /// Walking a cumulative total and truncating each running position made a
    /// longer track look narrower than a shorter one — a 3:14 rounded down
    /// while the 2:58 after it landed on a boundary and got more — which is
    /// exactly the comparison the meter exists to support. Here every track
    /// gets `floor(its share)` and the leftover units go to the largest
    /// fractions, so the total is still exact and a longer track can never be
    /// drawn narrower than a shorter one.
    ///
    /// A track too short to earn a single unit gets no band at all and does not
    /// consume a colour, so the two tracks either side of it still contrast
    /// (`panel.sh:448`).
    public static func bands(units: Int, durations: [Int]) -> [Band] {
        let cumulative = durations.reduce(0, +)
        guard !durations.isEmpty, cumulative > 0, units > 0 else { return [] }

        var whole = durations.map { $0 * units / cumulative }
        var remainder = durations.map { $0 * units % cumulative }
        var left = units - whole.reduce(0, +)

        while left > 0 {
            // The largest remainder still unspent. Spent ones are set to −1,
            // which keeps them out of later rounds without a second array.
            var best = -1
            var pick = -1
            for index in remainder.indices where remainder[index] > best {
                best = remainder[index]
                pick = index
            }
            guard pick >= 0 else { break }
            whole[pick] += 1
            remainder[pick] = -1
            left -= 1
        }

        var bands: [Band] = []
        var position = 0
        for width in whole where width > 0 {
            position += width
            bands.append(Band(end: position, shade: bands.count % shades))
        }
        return bands
    }

    /// The album meter's bands for a record, at a given width in cells.
    public static func bands(for durations: [Int], cells: Int) -> [Band] {
        bands(units: cells * unitsPerCell, durations: durations)
    }

    // MARK: - Cells

    public enum Cell: Sendable, Equatable {
        /// A column wholly inside one band.
        case band(shade: Int)
        /// A column a boundary runs through: `eighths` of the outgoing band's
        /// shade laid over `under` as the ground. `under` is nil where what is
        /// on the other side of the boundary is the run-out.
        case boundary(eighths: Int, shade: Int, under: Int?)
        /// The head — the playhead — part-way across the cell it is in. It wins
        /// over any band boundary sharing that column: it is the one thing on
        /// the bar that is moving, and it is gone again in a second
        /// (`panel.sh:484`).
        case head(eighths: Int)
        /// Not yet reached, or past the last band. Drawn rather than left
        /// blank, so it still reads as part of the meter (`panel.sh:504`).
        case runout
    }

    /// One row of album meter (`panel.sh:490`).
    ///
    /// `head` is in the same units as the bands. A meter with nothing moving on
    /// it passes the full width, so nothing is ever behind the head there; a
    /// live one passes the real position and gets the same bar with an
    /// unwritten tail and a bright edge creeping along it.
    public static func cells(head: Int, bands: [Band], width: Int) -> [Cell] {
        var cells: [Cell] = []
        cells.reserveCapacity(width)
        var b = 0
        for column in 0..<width {
            let start = column * unitsPerCell
            let end = start + unitsPerCell
            while b < bands.count && bands[b].end <= start { b += 1 }

            if head > start && head < end {
                cells.append(.head(eighths: head - start))
            } else if head <= start || b >= bands.count {
                cells.append(.runout)
            } else if bands[b].end >= end {
                cells.append(.band(shade: bands[b].shade))
            } else {
                let next = b + 1
                cells.append(
                    .boundary(
                        eighths: bands[b].end - start,
                        shade: bands[b].shade,
                        under: next < bands.count ? bands[next].shade : nil
                    )
                )
            }
        }
        return cells
    }

    /// One row of track bar (`player:558`).
    ///
    /// The same cells and the same partial blocks as the album meter so the two
    /// read as one family, but one band and one head. Everything behind the
    /// head is the first shade; the cell the head is in is the head's; the rest
    /// is run-out.
    public static func trackCells(done: Int, total: Int, width: Int) -> [Cell] {
        let units = width * unitsPerCell
        var head = total > 0 ? done * units / total : 0
        if head > units { head = units }

        return (0..<width).map { column in
            let start = column * unitsPerCell
            let end = start + unitsPerCell
            if head >= end { return .band(shade: 0) }
            if head > start { return .head(eighths: head - start) }
            return .runout
        }
    }
}
