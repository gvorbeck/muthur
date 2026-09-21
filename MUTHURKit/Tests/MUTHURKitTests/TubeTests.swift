import Foundation
import Testing

@testable import MUTHURKit

/// §10 — the two things the tube is allowed to do that move.
///
/// Both are rare by design, which makes both untestable by looking. A seed is
/// what turns "watch the corner of the window for a minute and see if it feels
/// irregular" into an assertion — the same trade `ShuffledOrder` and
/// `PlaybackEngine.load(_:source:seed:)` already made.
///
/// **The bounds asserted here are the bounds the ranges promise and nothing
/// tighter.** A draw is allowed to land anywhere in its window, so a suite that
/// asserted a distribution would be asserting a shape the generator never
/// promised; what is checked is that every draw is inside, that the same seed
/// gives the same schedule twice, and that the gaps are not a metronome.
@Suite("§10 — the tube's faults")
struct TubeTests {

    // MARK: - Reproducibility

    @Test("The same seed schedules the same faults")
    func seedRepeats() {
        var one = Tube(seed: 0x5EED_1979)
        var two = Tube(seed: 0x5EED_1979)
        for _ in 0..<8 {
            #expect(one.nextSweep() == two.nextSweep())
            #expect(one.nextSlip() == two.nextSlip())
        }
    }

    @Test("A different seed schedules different faults")
    func seedsDiffer() {
        var one = Tube(seed: 1)
        var two = Tube(seed: 2)
        #expect(one.nextSweep() != two.nextSweep())
    }

    // MARK: - The windows

    @Test("Every pass rests and travels inside its window")
    func sweepsAreInRange() {
        var tube = Tube(seed: 0xC0FFEE)
        for _ in 0..<500 {
            let sweep = tube.nextSweep()
            #expect((2.5...9.0).contains(sweep.rest))
            #expect((5.0...8.5).contains(sweep.travel))
        }
    }

    /// Several seconds top to bottom. A band that crosses the window in under a
    /// second is a flash, and a flash is the one thing `docs/spec.md:126` rules
    /// out by name.
    @Test("A pass is never quick")
    func sweepsAreSlow() {
        var tube = Tube(seed: 7)
        for _ in 0..<200 { #expect(tube.nextSweep().travel >= 5) }
    }

    @Test("Every glitch waits and holds inside its window")
    func slipsAreInRange() {
        var tube = Tube(seed: 0xBADF_00D)
        for _ in 0..<500 {
            let slip = tube.nextSlip()
            #expect((22.0...80.0).contains(slip.wait))
            #expect((0.07...0.17).contains(slip.hold))
        }
    }

    // MARK: - Not a metronome

    /// The requirement in one assertion. Regular gaps are what the eye locks on
    /// to, and this is the difference between a fault and a barber's pole.
    @Test("The gaps between passes are not all the same")
    func restsVary() {
        var tube = Tube(seed: 42)
        let rests = (0..<12).map { _ in tube.nextSweep().rest }
        #expect(Set(rests).count > 1)
        #expect((rests.max()! - rests.min()!) > 1)
    }

    @Test("The gaps between glitches are not all the same")
    func waitsVary() {
        var tube = Tube(seed: 43)
        let waits = (0..<12).map { _ in tube.nextSlip().wait }
        #expect(Set(waits).count > 1)
        #expect((waits.max()! - waits.min()!) > 1)
    }

    // MARK: - The shape of a tear

    /// It has to be a tear and not a jump. The wordmark shares its row with the
    /// faceplate meta and the rule beside it, so a badge that moved whole would
    /// read as the layout breaking rather than as the tube doing it.
    @Test("A glitch moves bands, never the whole badge")
    func slicesLeaveTheBadgeStanding() {
        var tube = Tube(seed: 0xDEAD_BEEF)
        for _ in 0..<500 {
            let slices = tube.nextSlip().slices
            #expect((2...4).contains(slices.count))
            #expect(slices.map(\.depth).reduce(0, +) < 1)
            for slice in slices {
                #expect((0.0...0.82).contains(slice.top))
                #expect((0.06...0.18).contains(slice.depth))
                #expect(abs(slice.shift) <= 3)
            }
        }
    }

    /// Top to bottom, because a tear is one place the beam lost its line: the
    /// slices are read down the badge, not shuffled across it.
    @Test("The bands come out in order down the badge")
    func slicesAreOrdered() {
        var tube = Tube(seed: 0x1234)
        for _ in 0..<200 {
            let tops = tube.nextSlip().slices.map(\.top)
            #expect(tops == tops.sorted())
        }
    }

    // MARK: - Wear (D102)

    /// The windows at the run-out, worked out here rather than read off `Tube`,
    /// so the suite is checking the arithmetic instead of restating it: 55% of
    /// each span gone, from the top only.
    private static let wornRest = 2.5...(2.5 + 6.5 * 0.45)
    private static let wornWait = 22.0...(22.0 + 58.0 * 0.45)

    /// The one that matters most, because it is the promise the default makes:
    /// a tube with no record on it draws what it drew before any of this existed.
    @Test("A fresh tube schedules exactly what it always did")
    func leadInIsUnchanged() {
        var plain = Tube(seed: 0x1979)
        var fresh = Tube(seed: 0x1979)
        for _ in 0..<50 {
            #expect(plain.nextSweep() == fresh.nextSweep(worn: 0))
            #expect(plain.nextSlip() == fresh.nextSlip(worn: 0))
        }
    }

    /// **The floors are the point of narrowing from above.** Twenty-two seconds
    /// is the bound with an argument behind it — under it the tear stops being an
    /// event and becomes a tic — and a worn tube is not allowed to go there.
    @Test("A worn tube rests inside a smaller window, never a lower one")
    func runOutNarrowsFromTheTop() {
        var tube = Tube(seed: 0xC0FFEE)
        for _ in 0..<500 {
            #expect(Self.wornRest.contains(tube.nextSweep(worn: 1).rest))
            #expect(Self.wornWait.contains(tube.nextSlip(worn: 1).wait))
        }
    }

    /// Past the run-out is still the run-out. A record's duration is the sum of
    /// what the taggers said, so a playhead can outlive it by a few seconds.
    @Test("A fraction past the end is clamped, not extrapolated")
    func pastTheRunOutIsTheRunOut() {
        var tube = Tube(seed: 11)
        for _ in 0..<200 {
            #expect(Self.wornRest.contains(tube.nextSweep(worn: 4.2).rest))
            #expect(Self.wornWait.contains(tube.nextSlip(worn: 99).wait))
        }
    }

    /// That the window really did close: over five hundred draws a fresh tube
    /// reaches gaps a worn one cannot have. Deterministic under the seed, and
    /// vanishingly unlikely under any of them — the fresh window's top 55% would
    /// have to be missed five hundred times running.
    @Test("A worn tube never takes the long rests a fresh one does")
    func theLongGapsGoFirst() {
        var fresh = Tube(seed: 0xBADF_00D)
        let restedFor = (0..<500).map { _ in fresh.nextSweep(worn: 0).rest }
        let waitedFor = (0..<500).map { _ in fresh.nextSlip(worn: 0).wait }
        #expect(restedFor.max()! > Self.wornRest.upperBound)
        #expect(waitedFor.max()! > Self.wornWait.upperBound)
    }

    /// **Squared, so a side and a half is nearly nothing.** Halfway through the
    /// record the window has given up about an eighth of its span, which is why a
    /// tube at the midpoint still reaches rests the run-out has lost.
    @Test("The first half of a record barely tires the tube")
    func wearArrivesLate() {
        var tube = Tube(seed: 0x5EED)
        let midway = (0..<500).map { _ in tube.nextSweep(worn: 0.5).rest }
        #expect(midway.max()! > Self.wornRest.upperBound)
        #expect(midway.max()! < 9.0)
    }

    /// The half of each fault that wear is not allowed to touch: how fast the
    /// band falls, and how long the badge stays torn.
    ///
    /// **Asserted as ranges and not as equalities, deliberately.** The tighter
    /// test — that a worn tube draws the *same* travel as a fresh one from the
    /// same seed — would hold only if `Double.random(in:using:)` consumed exactly
    /// one word of the generator per call regardless of the range it was given,
    /// and the standard library promises nothing of the sort. That is a rule the
    /// platform does not honour, so what is written is the rule it does: these
    /// two are drawn from their whole windows at any depth into the record.
    @Test("Wear changes when the faults happen, never how big they are")
    func theFaultsThemselvesDoNotGrow() {
        var tube = Tube(seed: 0xFEED)
        for depth in [0.0, 0.25, 0.5, 0.75, 1.0] {
            for _ in 0..<100 {
                #expect((5.0...8.5).contains(tube.nextSweep(worn: depth).travel))
                let slip = tube.nextSlip(worn: depth)
                #expect((0.07...0.17).contains(slip.hold))
                #expect((2...4).contains(slip.slices.count))
                for slice in slip.slices { #expect(abs(slice.shift) <= 3) }
            }
        }
    }

    // MARK: - The switch

    @Test("MUTHUR_CRT=0 holds the tube still")
    func theSwitchTurnsThemOff() {
        #expect(!Tube.faultsAllowed(environment: ["MUTHUR_CRT": "0"]))
    }

    /// Unset is on, and so is emptied — a variable someone unset by clearing it
    /// should mean unset, which is how `MUTHUR_NO_MB` already reads `0` and empty.
    @Test("Anything that is not 0 leaves it running")
    func anythingElseLeavesThemOn() {
        #expect(Tube.faultsAllowed(environment: [:]))
        #expect(Tube.faultsAllowed(environment: ["MUTHUR_CRT": ""]))
        #expect(Tube.faultsAllowed(environment: ["MUTHUR_CRT": "1"]))
        #expect(Tube.faultsAllowed(environment: ["MUTHUR_CRT": "off"]))
    }
}
