import Foundation

/// When the tube misbehaves, and how badly.
///
/// The rest of `Phosphor.swift` draws a tube that is **old**: uneven coating,
/// burnt-in furniture, corners going off. None of that moves, and for a long time
/// none of it was allowed to. This is the amendment — the tube is now permitted to
/// be *failing slightly* as well as old, which is two things and only two: a
/// deflection fault that walks one soft band down the raster every so often, and a
/// wordmark that tears for a fraction of a second and comes back.
///
/// **The schedule lives here, in the kit, and it is seedable.** Two reasons, and
/// the second is the one that put the file in this target rather than in `App/`.
///
/// The first is the one `ShuffledOrder` already argued: timing drawn from the
/// system generator is a thing you can only look at, and looking at something rare
/// is not a test. `PlaybackEngine.load` takes a `seed:` that production leaves nil
/// and the suites fill in; this takes the same one, for the same reason, so a
/// suite can assert that the gaps between passes are not all the same number
/// rather than somebody watching the corner of a window for a minute.
///
/// The second is `MUTHUR_CRT`, and it is a constraint rather than a preference:
/// `UsageTests` reads `Sources/MUTHURKit` back off disk and asserts that every
/// variable named in `--help` is read *there*. A switch documented in the help and
/// read from `App/` would be a variable the suite calls imaginary. So the switch
/// is read here and the panel asks.
///
/// Both effects are off under Reduce Motion regardless of the variable, which is
/// the environment asking the same question with more authority.
public struct Tube: Sendable, Equatable {

    /// One pass of the deflection fault: how long the tube is clean beforehand,
    /// and how long the band takes to fall from the top of the window to the
    /// bottom.
    ///
    /// The rest is the point. A band on a timer is a barber's pole, and the eye
    /// locks on to it inside two passes and then cannot let go; irregular gaps
    /// read as a fault in something rather than a property of the window, which
    /// is what a failing tube actually is.
    public struct Sweep: Sendable, Equatable {
        /// Seconds of clean screen before the pass begins.
        public let rest: Double
        /// Seconds from the top edge to the bottom.
        public let travel: Double
    }

    /// One horizontal slice of the wordmark, displaced.
    ///
    /// Everything is a fraction so the caller can size it: `top` and `depth` are
    /// of the wordmark's height, `shift` is signed and counts **dots** — up to
    /// three of them, which is about half a character. Under one dot the tear
    /// reads as the letters going soft; over about four, the badge stops looking
    /// torn and starts looking like it moved, and the badge is not allowed to
    /// move.
    public struct Slice: Sendable, Equatable {
        public let top: Double
        public let depth: Double
        public let shift: Double
    }

    /// One glitch of the wordmark: how long until it, how long it lasts, and what
    /// the badge looks like while it does.
    public struct Slip: Sendable, Equatable {
        /// Seconds of a well-behaved wordmark before this one.
        public let wait: Double
        /// Seconds it is torn. Two or three frames.
        public let hold: Double
        /// The bands that move, top to bottom. Never all of it — a badge that
        /// jumps whole is a layout bug, and this must never be mistaken for one.
        public let slices: [Slice]
    }

    // The four windows the schedule draws from. They are numbers somebody sat and
    // watched, not calculations, and the only ones with an argument behind them
    // are the two `wait` bounds: under twenty seconds the glitch stops being an
    // event and becomes a tic, and over a minute and a half most people never see
    // it happen at all and only ever find the screen already wrong.
    private static let rest = 2.5...9.0
    private static let travel = 5.0...8.5
    private static let wait = 22.0...80.0
    private static let hold = 0.07...0.17

    private var generator: SeededGenerator

    /// Nil seeds from the system, which is what the app does — two windows open
    /// at once should not glitch in unison. A number is for the suites.
    public init(seed: UInt64? = nil) {
        generator = seed.map(SeededGenerator.init(seed:)) ?? SeededGenerator()
    }

    public mutating func nextSweep() -> Sweep {
        Sweep(rest: draw(Self.rest), travel: draw(Self.travel))
    }

    public mutating func nextSlip() -> Slip {
        let count = Int.random(in: 2...4, using: &generator)
        // Sorted, because a tear is one place the beam lost its line and the
        // slices below it inherit the fault — drawn out of order they read as
        // confetti. `depth` is kept small enough that even four of them leave
        // most of the badge standing where it was.
        let slices = (0..<count)
            .map { _ in
                Slice(
                    top: draw(0.0...0.82),
                    depth: draw(0.06...0.18),
                    shift: draw(-3.0...3.0))
            }
            .sorted { $0.top < $1.top }
        return Slip(wait: draw(Self.wait), hold: draw(Self.hold), slices: slices)
    }

    private mutating func draw(_ range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &generator)
    }

    /// **`MUTHUR_CRT=0` turns the two moving effects off**, and nothing else. The
    /// four screws, the surround, and the true sleeve under the pointer are not
    /// effects the tube is having — they are what the machine looks like — so they
    /// stay whatever this says.
    ///
    /// Shaped like `MUTHUR_NO_MB`'s reading of `0` and empty: only a literal `0`
    /// is off, because a variable that has been unset by being emptied should mean
    /// unset. This one is the right way up, though, since it names the thing it
    /// switches rather than the absence of it.
    public static func faultsAllowed(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["MUTHUR_CRT"] != "0"
    }
}
