import Foundation

/// The tube striking: what the raster does in the second after a record
/// arrives, and how fast it stops doing it (D99).

/// A set that has just been handed something to draw does not simply have the
/// picture appear on it. The degauss coil fires, the mask lets go of whatever
/// field it had picked up, and the geometry shivers and settles — which on a
/// tube this age takes the better part of a second, and which is the most
/// recognisable thing a CRT does that a flat panel cannot.
///
/// **It is an event, not an effect, and that is the whole of why it is allowed
/// to exist beside D52's two.** `Tube` is the schedule for a tube that is
/// *failing*; this is the tube working, once, at the one moment it has been
/// given a new record. `spec.md:144` spends the entire movement budget on the
/// two faults, and the budget is about what runs *while you are listening* — a
/// strike cannot be seen a second time without putting a second record on, so
/// it can never become the thing you are watching instead of the track list.
///
/// The envelope is here rather than in the panel for `Tube`'s reason: a decay
/// somebody has to watch a window for is not a test. Unlike `Tube` there is
/// nothing random in it and no seed — a degauss is the same every time, because
/// it is one coil discharging into one yoke.
public enum Strike: Sendable {

    /// How long the raster takes to settle.
    ///
    /// Long enough to read as a machine coming up rather than as a glitch,
    /// short enough to be over before you have found the first track. The
    /// record is already playing underneath it either way — nothing here gates
    /// sound on the picture, which is D8's first box and is not being reopened.
    public static let settling = 0.9

    /// How fast the shiver oscillates, in cycles per second. Low enough that
    /// you see the picture cross the middle and come back rather than blur into
    /// a texture; about six of them fit inside `settling`.
    private static let frequency = 6.5

    /// How fast it dies away. A third of `settling`, which leaves a few percent
    /// at the end rather than nothing — the last frame is a picture that has
    /// nearly stopped, not one that snapped straight.
    private static let decay = settling / 3

    /// Where the geometry is, `elapsed` seconds in: **signed**, near ±1 at the
    /// start and at nothing by `settling`.
    ///
    /// Signed because a degauss is an oscillation and not a fade. An envelope
    /// that only falls from one to nothing is a picture sliding back into place
    /// from wherever it was put, which reads as a transition somebody wrote;
    /// the sign turning over five or six times on the way down is the thing
    /// that reads as a coil letting go.
    public static func shiver(elapsed: Double) -> Double {
        guard elapsed > 0, elapsed < settling else { return 0 }
        return exp(-elapsed / decay) * cos(2 * .pi * frequency * elapsed)
    }

    /// The phosphor coming up with it: `0…1`, the same decay without the
    /// oscillation.
    ///
    /// Unsigned, because this one is *light* and a tube cannot glow a negative
    /// amount. Driven off the same clock as `shiver` so the surge and the
    /// shiver are one event — a picture that shivers first and brightens a
    /// moment later is two things that happened near each other.
    public static func surge(elapsed: Double) -> Double {
        guard elapsed > 0, elapsed < settling else { return 0 }
        return exp(-elapsed / decay)
    }
}
