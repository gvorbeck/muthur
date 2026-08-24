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
/// See the "With a disc in the drive" checklist in `docs/parity.md`.
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
        // `qgrep -i 'title'` — not "did it exit cleanly". cdda2wav on a disc
        // with no CD-Text exits however it likes and the question is only
        // whether it printed any.
        if !out.lowercased().contains("title"),
            let cdrecord = Tooling.locate("cdrecord", environment: environment)
        {
            out = Tooling.output(cdrecord, ["dev=\(drive.device)", "-toc", "-v"]) ?? ""
        }
        return out.isEmpty ? nil : out
    }
}

/// The table of contents, off the drive. §4.3.
///
/// `libdiscid` is the intended reader here and §1.3 is where it lands — it talks
/// to the device directly and needs no cdrtools at all. This is the cdrecord
/// parse the script uses, kept because it is what can be written and reasoned
/// about now, and because the two must agree: the disc ID either implementation
/// computes for the same disc has to be the same string.
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
