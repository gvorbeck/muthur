import Foundation

/// The drive, by the name cdrtools will open it under.
///
/// macOS names an optical drive after the richest media class its driver
/// publishes, not after what you intend to do with it: a SuperDrive that reads
/// CDs all day comes up as `IODVDServices` because it can also read a DVD, and
/// `IOCompactDiscServices` exists only on drives that can do nothing else —
/// which, outside a museum, is none of them. Hard-coding one name is how a
/// working drive with a disc in it gets reported as no drive at all, so each
/// name is asked in turn and the first one `cdrecord` can actually open is kept.
/// DVD first: it is what every SuperDrive and USB burner still sold answers to.
///
/// From `burncd`'s `detect_dev` (`panel.sh:627`), which drives this machine's
/// actual hardware and is the reference for talking to it. `player` remains the
/// spec for everything else.
///
/// **Nothing here is exercised by the suite.** It cannot be — it needs a drive.
/// See `docs/hardware.md`, which is §19 — the "with a disc in the drive"
/// checklist, moved out of `docs/parity.md` and still numbered §19.
public struct OpticalDrive: Sendable, Equatable {
    /// `IODVDServices/0` and the like — what goes in `dev=`.
    public let device: String
    /// False when no device answered and `device` below is only the common case
    /// named anyway, so that every message downstream has something concrete to
    /// print and `cdrecord -scanbus` has something to contradict.
    public let answered: Bool

    public static let fallbackDevice = "IODVDServices/0"

    /// The classes, in the order they are worth asking.
    static let classes = ["IODVDServices", "IOCompactDiscServices", "IOBDServices"]

    public init(device: String, answered: Bool) {
        self.device = device
        self.answered = answered
    }

    /// Ask each name in turn. `override` is a device named by hand, which is not
    /// second-guessed: its failure is reported against the name that was asked
    /// for.
    ///
    /// **Order matters against `drutil`.** `-checkdrive` and `-prcap` open the
    /// device exclusively, and for as long as that lasts macOS lets go of the
    /// media — `drutil` then reports `No Media Inserted` about a disc that never
    /// moved, and goes on reporting it until something makes the drive spin up
    /// again (`burncd:278`). Anything that wants both must read `drutil` first.
    public static func detect(
        override: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> OpticalDrive {
        if let override, !override.isEmpty {
            return OpticalDrive(device: override, answered: true)
        }
        if let named = environment["MUTHUR_DEV"], !named.isEmpty {
            return OpticalDrive(device: named, answered: true)
        }
        guard let cdrecord = Tooling.locate("cdrecord", environment: environment) else {
            return OpticalDrive(device: fallbackDevice, answered: false)
        }
        for cls in classes {
            for n in 0...1 {
                let candidate = "\(cls)/\(n)"
                if Tooling.run(cdrecord, ["-checkdrive", "dev=\(candidate)"])?.status == 0 {
                    return OpticalDrive(device: candidate, answered: true)
                }
            }
        }
        return OpticalDrive(device: fallbackDevice, answered: false)
    }
}

/// CD-Text off the disc's lead-in. §4.2.
///
/// `cdda2wav dev=… -J -v titles` first, and `cdrecord dev=… -toc -v` only if
/// what came back has no `title` in it anywhere. Two tools because the two
/// cdrtools builds in circulation print CD-Text differently and neither is
/// reliably present (`player:2070`).
public struct DriveCDText: CDTextSource {
    let drive: OpticalDrive
    let environment: [String: String]

    public init(
        drive: OpticalDrive,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.drive = drive
        self.environment = environment
    }

    public func cdTextOutput() async -> String? {
        var out = ""
        if let cdda2wav = Tooling.locate("cdda2wav", environment: environment) {
            out = Tooling.output(cdda2wav, ["dev=\(drive.device)", "-J", "-v", "titles"]) ?? ""
        }
        if Self.wantsFallback(out),
            let cdrecord = Tooling.locate("cdrecord", environment: environment)
        {
            out = Tooling.output(cdrecord, ["dev=\(drive.device)", "-toc", "-v"]) ?? ""
        }
        return out.isEmpty ? nil : out
    }

    /// Whether what cdda2wav printed is worth asking cdrecord about. **D43,
    /// narrowing §18.28 — a deliberate divergence from `player:2073`.**
    ///
    /// The script asks `qgrep -i 'title'` over the capture, and the reasoning
    /// behind *that* is right and is kept: the question is not "did cdda2wav
    /// exit cleanly", because cdda2wav on a disc with no CD-Text exits however
    /// it likes. The question is whether it printed any titles.
    ///
    /// What the script cannot do is ask that question precisely, because `2>&1`
    /// has already folded stderr into the same string — and the verbose keyword
    /// being passed is literally `titles`, which tools of this vintage echo back
    /// in a usage banner. An unhappy cdda2wav therefore satisfies the grep, the
    /// fallback is skipped, and a machine with a perfectly good cdrecord
    /// silently never asks it. The disc then degrades exactly as though it had
    /// no CD-Text, which is why nobody ever saw this.
    ///
    /// So the test is put to the parser that reads the capture anyway. It
    /// diverges from the script on **one** shape of input — a capture that says
    /// the word `title` in something that is not a CD-Text line — and that shape
    /// is the fault and nothing else:
    ///
    /// - real `Album title:` / `Track N title:` lines: grep matches, parse is
    ///   non-empty, neither asks cdrecord. Same.
    /// - a blank capture, or one that never says `title`: both fall back. Same.
    /// - a page of error text mentioning `titles`: the grep is satisfied and the
    ///   script stops. Here it falls back, which is what the error should have
    ///   triggered.
    ///
    /// `isEmpty` rather than "no *track* titles": an album title on its own
    /// still suppresses the fallback, exactly as the grep does. Widening it to
    /// the condition `readCDText` succeeds on would be a second divergence and
    /// this entry only earns the one.
    static func wantsFallback(_ capture: String) -> Bool {
        CDTextParser.parse(capture).isEmpty
    }
}

/// The table of contents, off the drive with `cdrecord -toc`. §4.3 — the
/// script's own route, and **no longer the one §1.3 reaches for. See D44.**
///
/// This cannot read a disc macOS has mounted, which on macOS means it cannot
/// read an audio CD: `diskarbitrationd` holds the media and cdrtools insists on
/// an exclusive open, so every device node exits 255 and no `track:` line is
/// ever printed. `VolumeTableOfContents` is what the app uses instead, off the
/// `.TOC.plist` cddafs leaves on the mount.
///
/// Kept, not deleted. It is tested, it is what the script does, and an
/// *unmounted* disc — one `diskarbitrationd` has let go of — is exactly what it
/// is still good for.
public struct DriveTableOfContents: TableOfContentsSource {
    let drive: OpticalDrive
    let environment: [String: String]

    public init(
        drive: OpticalDrive,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.drive = drive
        self.environment = environment
    }

    public func tableOfContents() async -> TableOfContents? {
        guard let cdrecord = Tooling.locate("cdrecord", environment: environment),
            let out = Tooling.output(cdrecord, ["dev=\(drive.device)", "-toc"])
        else { return nil }
        return CDRecordTOC.parse(out)
    }
}
