import Foundation

/// A title too long for its column, run past the column a place at a time
/// (**D89**).
///
/// `player` has nothing like it — a terminal redraws a row when something
/// changes, and a row that changed eight times a second would be a row flooding
/// the pipe it is drawn down (`panel.sh:338` cuts and leaves it). A window has
/// no such cost, and a cut title is the one thing on the panel you cannot find
/// out any other way.
///
/// **It moves by whole columns, not by pixels.** The grid is the instrument's
/// whole argument, and a smooth scroll would be the one piece of type on the
/// panel standing between two columns. So this is a string function, measured
/// by the same `Columns.width` that cut the title in the first place: the
/// window is exactly the column's width at every step, so the artist beside it
/// never moves.
public enum Marquee {

    /// Blank places between the end of the title and its start coming round
    /// again — enough that the join reads as a join.
    public static let gap = 3

    /// Places per second.
    public static let rate = 8.0

    /// How long the title rests at its start before each lap, so the first
    /// word is still read first.
    public static let hold: TimeInterval = 1.5

    /// Whether a title needs to move at all. One that fits is left exactly as
    /// `Columns.fit` draws it.
    public static func runs(_ text: String, in columns: Int) -> Bool {
        columns > 0 && Columns.width(of: text) > columns
    }

    /// One lap: the title and its gap.
    public static func lap(_ text: String) -> Int {
        Columns.width(of: text) + gap
    }

    /// The column the window starts at, `elapsed` seconds after the title
    /// started moving: resting at 0 for `hold`, then one place every
    /// `1 / rate` seconds until the lap comes round.
    public static func offset(elapsed: TimeInterval, lap: Int) -> Int {
        guard lap > 0, elapsed > 0 else { return 0 }
        let cycle = hold + Double(lap) / rate
        let into = elapsed.truncatingRemainder(dividingBy: cycle) - hold
        guard into > 0 else { return 0 }
        return min(lap - 1, Int(into * rate))
    }

    /// `columns` places of the title-and-gap loop, starting `offset` places in.
    ///
    /// A two-place character the window's edge would cut in half is drawn as
    /// a blank rather than half-drawn — the same rule `Columns.truncate` keeps
    /// at its own edge — so the result is exactly `columns` wide at every
    /// offset, wide characters or not. A title that fits comes back fitted.
    public static func window(_ text: String, columns: Int, offset: Int) -> String {
        guard runs(text, in: columns) else { return Columns.fit(text, to: columns) }

        // One entry per place: the character that starts there, or nil for the
        // second half of a wide one and for the gap.
        var places: [Character?] = []
        var starts: [Bool] = []
        for character in text {
            let width = Columns.width(of: character)
            places.append(character)
            starts.append(true)
            for _ in 1..<max(1, width) {
                places.append(nil)
                starts.append(false)
            }
        }
        for _ in 0..<gap {
            places.append(" ")
            starts.append(true)
        }

        let lap = places.count
        var out = ""
        var place = 0
        var index = ((offset % lap) + lap) % lap
        while place < columns {
            if !starts[index] {
                // The tail of a wide character whose head is off the left edge.
                out.append(" ")
                place += 1
            } else if let character = places[index] {
                let width = Columns.width(of: character)
                if place + width > columns {
                    out.append(" ")
                    place += 1
                } else {
                    out.append(character)
                    place += width
                    index = (index + width - 1) % lap
                }
            }
            index = (index + 1) % lap
        }
        return out
    }
}
