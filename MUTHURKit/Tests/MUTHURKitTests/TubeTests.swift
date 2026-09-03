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
