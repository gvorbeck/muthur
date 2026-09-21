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
/// **Still two, and D102 is careful to have left it at two.** What that entry
/// changed is *when* they happen: both schedules now take how far into the record
/// the needle is, and both close their rests up as it runs in, so a set is at its
/// steadiest on the lead-in and at its most restless in the run-out. No third
/// fault, nothing bigger, nothing new to look at — the same two events, at the end
/// of forty minutes rather than at the start of them. `spec.md:144` rations the
/// number of things that move, and this adds none.
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

    /// How much of a rest window's span is gone by the run-out (D102).
    ///
    /// A set that has been on for forty minutes is not the set that was switched
    /// on forty minutes ago, and the two faults are the only place this panel has
    /// to say so. So the **rests** close up as the needle runs in: the same fault,
    /// the same size, oftener.
    ///
    /// **From the top only, and that is the whole of the restraint.** The lower
    /// bound of each window is a number with an argument behind it — twenty-two
    /// seconds is what keeps the tear an event rather than a tic — and a factor
    /// applied to the whole range would walk straight through it by the second
    /// side. Narrowing from above leaves every bound that was reasoned about
    /// exactly where it was and only stops the *long* gaps being drawn: the mean
    /// wait falls from about fifty-one seconds to about thirty-five, and the
    /// shortest gap the tube can have is the one it could always have had.
    private static let wear = 0.55

    private var generator: SeededGenerator

    /// Nil seeds from the system, which is what the app does — two windows open
    /// at once should not glitch in unison. A number is for the suites.
    public init(seed: UInt64? = nil) {
        generator = seed.map(SeededGenerator.init(seed:)) ?? SeededGenerator()
    }

    /// `worn` is how far into the record the needle is, 0 at the lead-in and 1 at
    /// the run-out. The default is a record that has just gone on, which is also
    /// every caller that has no record — and is exactly today's schedule.
    ///
    /// **`travel` is not worn.** How fast the band falls is the beat between the
    /// mains and the field rate, and neither of those gets tired. What changes is
    /// how long the tube holds its line between passes, which is the only half of
    /// this a warm set actually has an opinion about.
    public mutating func nextSweep(worn: Double = 0) -> Sweep {
        Sweep(rest: draw(Self.narrowed(Self.rest, by: worn)), travel: draw(Self.travel))
    }

    /// `worn` as in `nextSweep(worn:)`, and with the same half left alone: the
    /// **tear itself never grows**. `hold`, the slice count, the depths and above
    /// all `shift` are drawn from the windows they always were — three dots is the
    /// bound at which the badge stops looking torn and starts looking like it
    /// moved, and a badge that moves is a layout bug wearing a costume. A tired
    /// tube loses its line more often, not further.
    public mutating func nextSlip(worn: Double = 0) -> Slip {
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
        return Slip(
            wait: draw(Self.narrowed(Self.wait, by: worn)), hold: draw(Self.hold),
            slices: slices)
    }

    /// A rest window with its top brought down, the needle's depth into the
    /// record deciding how far.
    ///
    /// **Squared, so the first side of a record is very nearly untouched.** Linear
    /// wear would have the tube already noticeably restless four tracks in, which
    /// is a set that was tired when you put the record on. At the halfway mark the
    /// window has given up an eighth of its span; the rest of it goes in the last
    /// quarter, which is where sitting through a whole record is a thing you have
    /// actually done.
    ///
    /// **Nothing at all at zero**, and by return rather than by arithmetic that
    /// happens to come out the same. `lower + (upper - lower)` is `upper` for the
    /// four windows above and is not `upper` in general, and a schedule that drew
    /// imperceptibly different numbers on a fresh tube than it did before this
    /// existed would be a change nobody asked for hiding in the last bit of a
    /// Double.
    private static func narrowed(_ range: ClosedRange<Double>, by worn: Double)
        -> ClosedRange<Double>
    {
        guard worn > 0 else { return range }
        let depth = min(1, worn)
        let span = (range.upperBound - range.lowerBound) * (1 - wear * depth * depth)
        return range.lowerBound...(range.lowerBound + span)
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
