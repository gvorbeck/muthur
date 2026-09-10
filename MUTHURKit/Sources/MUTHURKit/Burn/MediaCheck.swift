import Foundation

/// §20 stage 3b — the look at the blank before anything expensive happens
/// because of it (`media_check`, `burncd:2257`).
///
/// The script's own account of why it exists: *pressing ⏎ at the INSERT prompt
/// used to be an act of faith. An empty tray, a disc with last year's album
/// already on it, or a 74-minute blank under an 80-minute plan all looked
/// identical from here, and the way you found out was cdrecord refusing the job
/// after five minutes of converting. The drive can answer all three questions in
/// about two seconds.*
///
/// **`drutil` first, `cdrecord` second, always.** `-checkdrive`, `-prcap` and the
/// ATIP read below all open the device exclusively, and for as long as that
/// lasts macOS lets go of the media: `drutil` then reports `No Media Inserted`
/// about a disc that never moved (`burncd:278`). That is §19's opening rule and
/// it is the same drive it is talking about.
///
/// **And here that ordering is not enough on its own**, because this runs in a
/// loop at the insert prompt. The ATIP read *is* such an open, so the reading
/// taken after a refused disc is taken while the drive is still disowning it —
/// and the port would tell you the tray was empty while you were looking
/// straight at the disc in it. The state clears in about a second, so an empty
/// drive has to say so more than once before it is believed. A tray that really
/// is empty pays a second or two for that, once, at a prompt that was already
/// waiting on a human.
///
/// **Nothing here is asked by a rehearsal's stand-in.** `--demo` never goes near
/// a drive, so `FakeDrive` never asks (`burncd:2262`); `--dummy` does go near
/// one, and a rehearsal on a disc that is too small tells you nothing, so it is
/// checked like any other burn.
public struct MediaCheck: Sendable {

    /// How many times an answer that says nothing useful is asked again
    /// (`burncd:2277`, `burncd:2320`).
    ///
    /// Three readings and two waits, which is what the loop does — `tries`
    /// starts at zero and stops at two, so the third reading is taken and
    /// believed. The comment above it in the script says "twice"; the loop says
    /// three, and the loop is what burns discs.
    public static let readings = 3

    /// The second between them (`sleep 1`). A drive that has just been asked
    /// something else answers the first request with everything it knows about
    /// itself and nothing about the disc, and is perfectly forthcoming a second
    /// later. Taking that first answer at face value would put "could not read
    /// the capacity" in front of half the burns on this machine.
    public static let wait = 1.0

    // MARK: - The seam

    /// Everything this asks the machine, as closures, so every branch below is
    /// reachable from the suite with no drive, no blank and no two seconds to
    /// spend. Same seam as `DiscFinder.Probes` and §11's, for the same reason.
    public struct Probes: Sendable {
        /// `command -v drutil` (`burncd:2276`). A machine without it skips
        /// straight to the ATIP read, which is the script's shape: `drutil` is
        /// wrapped in `command -v` and `cdrecord` below is not.
        public var hasDrutil: @Sendable () -> Bool
        /// `drutil status`, whole.
        public var drutil: @Sendable () -> String?
        /// `cdrecord -atip dev=…`, whole, stdout and stderr together — the
        /// interesting half of what cdrtools says goes to stderr, and the script
        /// captures both with `2>&1 || true`. cdrecord routinely exits non-zero
        /// having printed exactly what was wanted, so the status is not
        /// consulted.
        public var atip: @Sendable (String) -> String?
        /// The second between readings. A closure so the suite can spend none.
        public var pause: @Sendable (Double) -> Void
        /// Take the drive off macOS before the ATIP read, which is an exclusive
        /// open and fails like every other one (**D77**). Not in the script,
        /// which had no `diskarbitrationd` to get around.
        public var release: @Sendable () -> Void

        public init(
            hasDrutil: @escaping @Sendable () -> Bool = MediaCheck.drutilPresent,
            drutil: @escaping @Sendable () -> String? = Diagnostics.drutilStatus,
            atip: @escaping @Sendable (String) -> String? = MediaCheck.atipOutput,
            pause: @escaping @Sendable (Double) -> Void = { Thread.sleep(forTimeInterval: $0) },
            release: @escaping @Sendable () -> Void = DriveRelease.standard
        ) {
            self.hasDrutil = hasDrutil
            self.drutil = drutil
            self.atip = atip
            self.pause = pause
            self.release = release
        }
    }

    public static let drutilPresent: @Sendable () -> Bool = {
        Tooling.locate("drutil") != nil
    }

    public static let atipOutput: @Sendable (String) -> String? = { device in
        guard let cdrecord = Tooling.locate("cdrecord") else { return nil }
        return Tooling.output(cdrecord, ["-atip", "dev=\(device)"])
    }

    // MARK: - What it decides

    /// Go ahead with this disc, or ask for another one.
    ///
    /// The script says it in a return code and a `note`; here the note travels
    /// with the verdict, because the panel that prints it and the loop that acts
    /// on it are two different things in a window and were one thing in a
    /// terminal.
    public enum Verdict: Sendable, Equatable {
        /// Write it. `note` is the one thing worth saying on the way past and is
        /// usually nothing: an oversized blank, or the single ATIP warning.
        case go(note: String?)
        /// Put this one back — the note is the reason and the remedy in one
        /// line, and the prompt goes up again underneath it.
        case swap(note: String)

        public var note: String? {
            switch self {
            case .go(let note): note
            case .swap(let note): note
            }
        }

        public var isGo: Bool {
            if case .go = self { return true }
            return false
        }
    }

    // MARK: - Switched off

    /// `BURNCD_NO_MEDIA_CHECK`, under this program's own name as well
    /// (`burncd:77`).
    ///
    /// It exists for the drive whose reporting lies — and they exist. Set to
    /// anything at all, as the script tests it: `[ -n … ]` and not a value.
    public static func enabled(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        for name in ["MUTHUR_NO_MEDIA_CHECK", "BURNCD_NO_MEDIA_CHECK"] {
            if let raw = environment[name], !raw.isEmpty { return false }
        }
        return true
    }

    // MARK: - The state that outlives one disc

    /// Whether the ATIP warning has been given (`ATIP_WARNED`, `burncd:2256`).
    ///
    /// A global in the script, and it has to be *something* here: the warning is
    /// given once for the whole job and not once per disc, because a drive that
    /// cannot read one disc's ATIP will not read the next one's either and a
    /// multi-disc job would otherwise say the same sentence five times.
    public private(set) var atipWarned = false

    public var enabled: Bool
    public var probes: Probes

    public init(enabled: Bool = MediaCheck.enabled(), probes: Probes = Probes()) {
        self.enabled = enabled
        self.probes = probes
    }

    // MARK: - The look

    /// Look at what is in the drive for disc `disc`, which wants `want` seconds
    /// of it.
    ///
    /// `capacity` is what the plan was cut against, and is only ever used to
    /// notice that the blank is *bigger* — a waste rather than a problem.
    public mutating func look(
        disc: Int, want: Int, capacity: Int = BurnLimits.capacity, device: String
    ) -> Verdict {
        guard enabled else { return .go(note: nil) }

        if probes.hasDrutil(), let verdict = drutilSays() { return verdict }

        // ATIP is the pre-groove's own account of where the disc ends, and the
        // only honest capacity there is: a 74-minute blank and an 80-minute
        // blank are the same object to everything else. Lead-out lba over 75 is
        // the length in seconds — a standard 80-minute blank reads 359,849,
        // which is 4797 and exactly the default capacity, so a parse that has
        // gone wrong tends to say so loudly.
        //
        // The drive is taken off macOS first, and this is not tidiness: an ATIP
        // read against a mounted drive fails, the failure is indistinguishable
        // from a drive that will not say, and the answer to that is *go ahead on
        // trust*. A mount left behind by an earlier write would quietly turn the
        // capacity check off for the rest of the session, which is the one thing
        // it is for (D77).
        probes.release()

        var leadOut: Int?
        for reading in 1...MediaCheck.readings {
            leadOut = MediaCheck.leadOut(probes.atip(device) ?? "")
            if leadOut != nil { break }
            if reading < MediaCheck.readings { probes.pause(MediaCheck.wait) }
        }

        guard let leadOut else {
            // A false negative that blocks a good burn is worse than the problem
            // being solved, so an unreadable ATIP goes ahead — once out loud,
            // and quietly after that.
            guard !atipWarned else { return .go(note: nil) }
            atipWarned = true
            return .go(
                note: "! Could not read the disc's capacity from its ATIP; going ahead on trust")
        }

        let seconds = leadOut / BurnLimits.framesPerSecond
        guard seconds >= want else {
            return .swap(
                note: "! This blank holds \(Readout.discLength(seconds)) and disc \(disc) is "
                    + "\(Readout.discLength(want)). Use an 80-minute disc, or set MUTHUR_MINUTES "
                    + "and start again")
        }
        // A longer blank than the plan assumed is not a problem, only a waste:
        // the layout is fixed by now, and renumbering discs under a job already
        // in progress is the thing `--from-disc` exists to avoid.
        if seconds > capacity + 60 {
            return .go(
                note: "! This blank holds \(Readout.discLength(seconds)), more than the "
                    + "\(Readout.discLength(capacity)) planned for — MUTHUR_MINUTES would use all of it")
        }
        return .go(note: nil)
    }

    /// The `drutil` half: is there a disc, and is it blank.
    ///
    /// Nil where `drutil` had nothing to say either way and the ATIP read is
    /// left to be the authority — which is the script's own `:` branch, and is
    /// not the same as a clean bill of health.
    private func drutilSays() -> Verdict? {
        var status: String?
        for reading in 1...MediaCheck.readings {
            status = probes.drutil()
            guard MediaCheck.saysNoMedia(status) else { break }
            if reading < MediaCheck.readings { probes.pause(MediaCheck.wait) }
        }

        // No drive visible to drutil at all. cdrecord below is the authority
        // anyway, and refusing here would refuse every machine whose drive
        // drutil does not enumerate.
        guard let status, !status.isEmpty else { return nil }

        if MediaCheck.saysNoMedia(status) {
            return .swap(
                note: "! The drive is empty — put a blank CD-R in it and press ⏎ again")
        }
        guard MediaCheck.saysBlank(status) else {
            // Refused by its own type name, which is the only word the operator
            // can act on: "that CD-RW" and "that DVD-R" are two different
            // mistakes with two different discs to go and find.
            let kind = Diagnostics.mediaType(status) ?? "disc"
            return .swap(
                note: "! That \(kind) is not blank — MU/TH/UR writes blanks only. "
                    + "Swap it and press ⏎ again")
        }
        return nil
    }

    // MARK: - Reading what the drive said

    /// `qgrep -i 'no media'` (`burncd:2280`). Nil counts as saying it, so a
    /// `drutil` that could not be run keeps the loop going rather than being
    /// mistaken for a disc.
    static func saysNoMedia(_ status: String?) -> Bool {
        guard let status else { return true }
        return status.range(of: "no media", options: .caseInsensitive) != nil
    }

    /// `qgrep -i 'blank'` over the whole of `drutil status` (`burncd:2296`).
    ///
    /// The whole output and not the `Writability:` line, because that is what
    /// the script greps and because the word's position in that output is
    /// `drutil`'s business: on this machine it arrives as
    /// `Writability: appendable, blank, overwritable`, and a parser that
    /// insisted on that shape would be asserting something the tool never
    /// promised.
    static func saysBlank(_ status: String) -> Bool {
        status.range(of: "blank", options: .caseInsensitive) != nil
    }

    /// The ATIP lead-out, in sectors (`burncd:2322`).
    ///
    /// The script's `sed -n 's/.*lead out:[[:space:]]*\([0-9][0-9]*\).*/\1/p' |
    /// head -1`: the **first line** that both carries the phrase *and* has
    /// digits after it, and within that line the **last** such occurrence,
    /// because the `.*` in front is greedy and backtracks only as far as it must.
    /// Neither half of that has ever mattered on a real capture — the line reads
    /// `ATIP start of lead out: 359846 (79:59/71)` and there is one of it — but
    /// reproducing the rule costs nothing and inventing a tidier one would be a
    /// guess about output this port does not own.
    ///
    /// Case-sensitive, as `sed` is. `lead in` is a different phrase on a
    /// neighbouring line carrying a negative number, which is why the digits are
    /// read as digits and not as an `Int` off the rest of the line.
    static func leadOut(_ atip: String) -> Int? {
        for line in atip.split(separator: "\n", omittingEmptySubsequences: false) {
            var found: Int?
            var from = line.startIndex
            while let phrase = line.range(of: "lead out:", range: from..<line.endIndex) {
                let digits = line[phrase.upperBound...]
                    .drop(while: \.isWhitespace)
                    .prefix(while: \.isNumber)
                if let value = Int(digits) { found = value }
                from = phrase.upperBound
            }
            if let found { return found }
        }
        return nil
    }
}
