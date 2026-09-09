import Foundation

/// §20 stage 3 — what would be said to the drive (`burncd:2600`).
///
/// **A value, not a call.** The argument vector is the part of the burn that can
/// be got wrong in silence: a missing `-dao` is a disc with two-second gaps
/// between the tracks, a missing `-text` is a disc with no titles on it, and
/// both are only discoverable by playing the coaster you just made. So it is
/// built here, where a test can read it back argument by argument, and handed to
/// whatever runs it. Nothing in this file spawns anything.
///
/// The invocation is also the disc's whole character. Disc-at-once because a CD
/// written track-at-once has a two-second gap mastered into it and cannot carry
/// CD-Text at all; `burnfree` because a buffer underrun on a CD-R is a ruined
/// blank rather than a retry; the cue sheet rather than a list of files because
/// the cue is what carries the pregaps, the ISRCs and the text.
public struct Cdrecord: Sendable, Equatable {

    /// The default, and the reason there is one: a CD-R written at 48x is
    /// written by a laser making decisions in a fortieth of the time, and the
    /// drives that read the result back — car decks, CD players from the era
    /// this program is dressed as — are the least tolerant of the jitter that
    /// comes of it. Eight is slow enough to be safe on the cheapest dye and
    /// still puts a full disc down in under ten minutes (`burncd:62`).
    public static let defaultSpeed = 8

    /// The program's name only. Where it lives is `Tooling`'s to answer, and at
    /// this stage nothing asks.
    public static let program = "cdrecord"

    public let arguments: [String]
    /// cdrecord is run with the working directory set to the job's, because
    /// `cuefile=` is passed as a bare filename: a cue sheet holds the image's
    /// name unqualified, so cdrecord resolves it against its own cwd and a path
    /// with a space or a quote in it never reaches a shell at all
    /// (`burncd:2617`).
    public let directory: URL

    public init(arguments: [String], directory: URL) {
        self.arguments = arguments
        self.directory = directory
    }

    /// Build the vector for one disc.
    ///
    /// `cdText` is this disc's answer and not the job's: a lead-in that will not
    /// hold the text is written without it, and that decision is taken per disc
    /// after the cue sheet has been shrunk as far as it will go (`burncd:2573`).
    public static func write(
        cue: URL,
        device: String,
        speed: Int = defaultSpeed,
        cdText: Bool,
        rehearsal: Bool = false,
        verify: Bool = false,
        directory: URL
    ) -> Cdrecord {
        // -v so cdrecord narrates at all: without it there is no progress line
        // and the panel has nothing to draw.
        var arguments = ["-v", "-dao"]
        if cdText { arguments.append("-text") }
        if rehearsal { arguments.append("-dummy") }
        // Ejecting is also how the next disc gets asked for. Not when the disc
        // has to be read back, and not after a rehearsal — a rehearsal's blank
        // is still blank and is about to be written for real.
        if !verify && !rehearsal { arguments.append("-eject") }

        arguments += [
            "dev=\(device)",
            "speed=\(speed)",
            "driveropts=burnfree",
            "cuefile=\(cue.lastPathComponent)",
        ]
        return Cdrecord(arguments: arguments, directory: directory)
    }

    /// Where the drive's own words are kept (`burncd:2619`).
    ///
    /// The panel drops every line it cannot parse, which is nearly all of them,
    /// and the lines it drops are the ones that say why a burn failed. So the
    /// output is kept whole beside the image, under the disc's number.
    public static func logURL(work: URL, disc: Int) -> URL {
        work.appending(path: "cdrecord-\(disc).log")
    }

    // MARK: - Speed

    /// `BURNCD_SPEED`, and `MUTHUR_SPEED` under this program's own name
    /// (`burncd:62`).
    ///
    /// **A junk value falls back instead of stopping. D74.** The script checks
    /// it at startup and `die`s — the right answer for a program you invoked
    /// from a shell a second ago, where the fix is to retype the line. An app
    /// reads its environment once, at launch, from whatever launched it; there
    /// is no line to retype, and refusing to burn is a worse answer than burning
    /// at the speed it would have used anyway. So it says what it did, in the
    /// job's notes, and carries on.
    public static func speed(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> (speed: Int, note: String?) {
        for name in ["MUTHUR_SPEED", "BURNCD_SPEED"] {
            guard let raw = environment[name], !raw.isEmpty else { continue }
            // The script's own test: whole and unsigned, so `8x`, `-8` and `8.0`
            // are all junk. Zero is junk too — cdrecord reads it as "the drive's
            // choice", which is not a speed anybody typed on purpose.
            if let value = Int(raw), value > 0, raw.allSatisfy(\.isNumber) {
                return (value, nil)
            }
            return (
                defaultSpeed,
                "! \(name) must be a whole number, got: \(raw) — writing at \(defaultSpeed)x"
            )
        }
        return (defaultSpeed, nil)
    }
}
