import Foundation
import Testing

@testable import MUTHURKit

/// D99 — the tube striking when a record arrives.
///
/// The envelope is in the kit for exactly this reason: a decay somebody has to
/// watch a window for is not a test. What is asserted is the *shape* — it
/// starts, it oscillates, it dies, and it is nothing at all outside the second
/// it is allowed. Not the particular numbers, which are taste and are allowed
/// to be retuned without this suite having an opinion.
@Suite("D99 — the tube striking")
struct StrikeTests {

    @Test("Nothing before the coil fires and nothing after it has settled")
    func silentOutside() {
        #expect(Strike.shiver(elapsed: 0) == 0)
        #expect(Strike.shiver(elapsed: -1) == 0)
        #expect(Strike.shiver(elapsed: Strike.settling) == 0)
        #expect(Strike.shiver(elapsed: Strike.settling * 2) == 0)

        #expect(Strike.surge(elapsed: 0) == 0)
        #expect(Strike.surge(elapsed: -1) == 0)
        #expect(Strike.surge(elapsed: Strike.settling) == 0)
    }

    /// The strike has to *strike*: a first frame already halfway down is a
    /// picture that was disturbed before you were looking at it.
    ///
    /// The surge is asked for more than the shiver, and the gap is the cosine,
    /// not slack in the tuning. `surge` is decay alone, so one frame in it is
    /// still nearly all of itself; `shiver` is that times a cosine which has
    /// already turned a tenth of a cycle by then, and any honest bound on it
    /// has to leave room for whatever `frequency` is retuned to. Half is the
    /// weak thing that is actually promised — a strike, not a first frame at a
    /// particular number.
    @Test("It is at full strength in its first frame")
    func startsHard() {
        #expect(Strike.shiver(elapsed: 1 / 60.0) > 0.5)
        #expect(Strike.surge(elapsed: 1 / 60.0) > 0.9)
    }

    /// Never past the rails, because the shader multiplies it by an amplitude
    /// in points and a picture pushed further than that is a picture with a
    /// hole in the side of it.
    @Test("It stays inside ±1")
    func bounded() {
        for step in 0...200 {
            let t = Strike.settling * Double(step) / 200
            #expect(abs(Strike.shiver(elapsed: t)) <= 1)
            #expect(Strike.surge(elapsed: t) >= 0)
            #expect(Strike.surge(elapsed: t) <= 1)
        }
    }

    /// The whole argument of D99: signed, and turning over. An envelope that
    /// only fell from one to nothing is a picture sliding back into place,
    /// which reads as a transition somebody wrote rather than a coil letting
    /// go.
    @Test("It crosses zero several times on the way down")
    func oscillates() {
        var crossings = 0
        var previous = Strike.shiver(elapsed: 1 / 240.0)
        for step in 2...240 {
            let value = Strike.shiver(elapsed: Strike.settling * Double(step) / 241)
            if value != 0, previous != 0, (value < 0) != (previous < 0) { crossings += 1 }
            previous = value
        }
        #expect(crossings >= 4)
    }

    /// The light only ever goes down. A tube coming back up brighter partway
    /// through settling would be a second event.
    @Test("The surge never brightens again")
    func surgeOnlyFalls() {
        var previous = Strike.surge(elapsed: 1 / 240.0)
        for step in 2...240 {
            let value = Strike.surge(elapsed: Strike.settling * Double(step) / 241)
            #expect(value <= previous)
            previous = value
        }
    }

    /// Both halves are one event, which in practice means one clock: the
    /// shiver's peaks are bounded by the surge, so the picture is never
    /// wobbling harder than it is lit.
    @Test("The shiver rides inside the surge")
    func oneEnvelope() {
        for step in 1...200 {
            let t = Strike.settling * Double(step) / 201
            #expect(abs(Strike.shiver(elapsed: t)) <= Strike.surge(elapsed: t) + 1e-12)
        }
    }
}
