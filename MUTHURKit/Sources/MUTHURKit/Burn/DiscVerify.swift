import Foundation

/// §20 stage 3b — `--verify`, reading the finished disc back (`verify_disc`,
/// `burncd:2195`).
///
/// The script's own account of why it is not a comparison: *deliberately NOT a
/// byte-for-byte comparison against the image. Every drive reads audio at a small
/// fixed sample offset from where it wrote it, so an exact compare fails on a
/// perfectly good disc — which is the same false alarm this flag exists to
/// settle.* What it checks instead is the three things that actually go wrong:
/// the table of contents, whether every sector can be read back, and whether the
/// CD-Text survived.
///
/// **The three are not equal and are not meant to be.** A TOC with the wrong
/// number of tracks is a disc that will play wrong; a sector the drive cannot get
/// through is a disc that will stop mid-record; a CD-Text field that does not
/// read back is a disc that might be perfect and a `-J` that felt unhelpful. So
/// the first two fail the disc and the third prints `!` and does not — the
/// script's asymmetry, and it is right for the same reason `media_check` goes
/// ahead on an unreadable ATIP.
///
/// **It has to take the drive off macOS first, and the script did not. D77.**
/// The disc this reads is one `cdrecord` has just finished writing, which means
/// `diskarbitrationd` has just mounted it — that is what a finished write *does*
/// on this machine, and it is why there is an `Audio CD` on the desktop by the
/// time the panel says the disc is written. Both tools below want the same
/// exclusive open that a mount denies, so without the release every verify on
/// this machine would report a TOC of zero tracks and a full read that failed at
/// sector one, on a disc that is fine. The script never met this because a
/// terminal burn on a machine with no Finder in front of it usually had nothing
/// mounted to begin with.
public struct DiscVerify: Sendable {

    // MARK: - The seam

    /// Everything this asks of the machine. Same shape as `MediaCheck.Probes`
    /// and for the same reason: every branch below is a sentence somebody reads
    /// off a panel, and none of them should need a disc to reach.
    public struct Probes: Sendable {
        /// Take the drive back off macOS before either tool opens it (D77).
        public var release: @Sendable () -> Void
        /// `cdrecord -toc dev=…`, stdout and stderr together. The status is not
        /// consulted: cdrtools routinely exits non-zero having printed exactly
        /// what was wanted, and the script's `|| true` says so.
        public var toc: @Sendable (String) -> String?
        /// `command -v cdda2wav`. Its absence downgrades the verify to the TOC
        /// alone rather than failing the disc (`burncd:2240`).
        public var hasCdda2wav: @Sendable () -> Bool
        /// The full read: device, track count, and the file the drive's
        /// complaints are kept in. The exit status comes back; nil is a
        /// `cdda2wav` that could not be started at all.
        public var read: @Sendable (String, Int, URL) -> Int32?
        /// `cdda2wav -J -v titles`, run in the given directory. Whole, both
        /// streams, as the script's `2>&1` takes it.
        public var titles: @Sendable (String, URL) -> String?
        /// The tray, afterwards. Here rather than in the burn because the burn
        /// gave it up — see `DiscVerify.eject`.
        public var eject: @Sendable (String) -> Void

        public init(
            release: @escaping @Sendable () -> Void = DriveRelease.standard,
            toc: @escaping @Sendable (String) -> String? = DiscVerify.tocOutput,
            hasCdda2wav: @escaping @Sendable () -> Bool = DiscVerify.cdda2wavPresent,
            read: @escaping @Sendable (String, Int, URL) -> Int32? = DiscVerify.fullRead,
            titles: @escaping @Sendable (String, URL) -> String? = DiscVerify.titlesOutput,
            eject: @escaping @Sendable (String) -> Void = DiscVerify.eject
        ) {
            self.release = release
            self.toc = toc
            self.hasCdda2wav = hasCdda2wav
            self.read = read
            self.titles = titles
            self.eject = eject
        }
    }

    public var probes: Probes

    public init(probes: Probes = Probes()) {
        self.probes = probes
    }

    // MARK: - What it decides

    /// Whether the disc is sound, and every line said on the way to deciding.
    ///
    /// The notes travel with the verdict rather than being printed as they are
    /// found, for `MediaCheck.Verdict`'s reason: the thing that prints them and
    /// the thing that acts on them were one `note` in a terminal and are a panel
    /// and a loop in a window.
    public struct Report: Sendable, Equatable {
        public var passed: Bool
        public var notes: [String]

        public init(passed: Bool, notes: [String]) {
            self.passed = passed
            self.notes = notes
        }
    }

    // MARK: - The read-back

    /// Read disc `disc` back, expecting `want` tracks on it.
    ///
    /// `album` and `cdText` are this disc's, not the job's: a lead-in that was
    /// written without text has no text to read back, and asking for it would
    /// print a warning about a disc that is exactly as intended (`burncd:2229`).
    /// `log` is where the drive's complaints go — `verify-<n>.log`, beside the
    /// image and the cue, on the same reasoning as `cdrecord-<n>.log`: the panel
    /// drops what it cannot parse and this is a tool whose whole output is
    /// unparseable.
    public func look(
        disc: Int, want: Int, device: String, album: String, cdText: Bool, log: URL
    ) -> Report {
        var notes = ["VERIFYING disc \(disc)..."]
        var bad = false

        // Before either open, and it is the difference between a verify and a
        // false alarm on this machine (D77).
        probes.release()

        let toc = probes.toc(device) ?? ""
        let got = DiscVerify.trackCount(toc)
        if got == want {
            notes.append("  ✓ table of contents — \(got) tracks")
        } else if DiscVerify.refusedTheOpen(toc) {
            // **Not the disc's fault, and worth its own sentence.** The release
            // above is a `diskutil unmount`, and an unmount can be *dissented* —
            // by any process holding the volume, this app included, which is
            // what happens when somebody puts the disc they just burnt on and
            // then asks for it to be verified:
            //
            //     Volume Audio CD on disk7 failed to unmount:
            //     dissented by PID 86779 (…/MUTHUR)
            //
            // Reported as `expected 13 tracks, disc reports 0` that is a burn
            // that failed. It is a disc somebody is listening to. Forcing the
            // unmount out from under a reading process is not the answer; saying
            // which two things to do is (§19 step 4).
            notes.append("  ✗ table of contents — the drive would not open")
            notes.append("      macOS still has this disc mounted, and cdrtools needs it to itself.")
            notes.append("      Stop playing it and dismiss it from the desktop, then verify again.")
            bad = true
        } else {
            notes.append(
                "  ✗ table of contents — expected \(want) tracks, disc reports \(got)")
            bad = true
        }

        guard probes.hasCdda2wav() else {
            // Not a failure. A machine that cannot read sectors back has still
            // had its TOC checked, and saying so is more use than refusing to
            // answer (`burncd:2241`).
            notes.append("  ! cdda2wav not installed — TOC checked, sectors not read")
            return Report(passed: !bad, notes: notes)
        }

        let status = probes.read(device, want, log)
        if status == 0 {
            notes.append("  ✓ full read — every sector came back")
        } else if let status {
            notes.append("  ✗ full read failed (exit \(status)):")
            // A line at a time, so the drive's complaint joins the log rather
            // than printing straight through whatever stage is on screen.
            notes.append(contentsOf: DiscVerify.tail(of: log).map { "      \($0)" })
            bad = true
        } else {
            // `command -v` said yes and the spawn failed anyway — a tool that
            // has been deleted between the two, or one this process may not
            // execute. The script has no branch for it because a shell would
            // have handed back 127 and failed the disc, which is what this does.
            notes.append("  ✗ full read failed — cdda2wav would not run")
            bad = true
        }

        if cdText, !album.isEmpty {
            // Best effort: `-J` asks for information only. If the field does not
            // come back that is not proof it is missing, so this never fails the
            // disc.
            //
            // Fixed-string and case-sensitive, as `qgrep -F` is. The album has
            // been through §20.3's shedding ladder by now, so what is looked for
            // is what was written and not what the folder was called.
            let read = probes.titles(device, log.deletingLastPathComponent()) ?? ""
            if read.contains(album) {
                notes.append("  ✓ CD-Text — album title reads back")
            } else {
                notes.append("  ! CD-Text — could not read it back; check on a player")
            }
        }

        return Report(passed: !bad, notes: notes)
    }

    // MARK: - Reading what the drive said

    /// `grep -c '^track:[[:space:]]*[0-9]'` (`burncd:2201`).
    ///
    /// **Counted rather than parsed, on purpose.** `CDRecordTOC.parse` is right
    /// here and reads the same lines, but it answers nil for a listing with a
    /// gap in the middle or no lead-out — a stricter reading that exists to keep
    /// a bad disc ID out of MusicBrainz. Nil would arrive here as *zero tracks*,
    /// which is the report of a blank disc, and a TOC oddity would be printed as
    /// a burn that failed. The question this check asks is only *how many tracks
    /// does the disc say it has*, and counting is the honest way to ask it.
    ///
    /// The lead-out is excluded by the digit, not by name: cdrtools prints it as
    /// `track:lout`, and `l` is not `[0-9]`.
    static func trackCount(_ toc: String) -> Int {
        var count = 0
        for line in toc.split(separator: "\n", omittingEmptySubsequences: false) {
            guard line.hasPrefix("track:") else { continue }
            let rest = line.dropFirst("track:".count).drop(while: \.isWhitespace)
            guard let first = rest.first, first.isASCII, first.isNumber else { continue }
            count += 1
        }
        return count
    }

    /// Whether that capture is `diskarbitrationd` refusing the open rather than
    /// the drive answering (D77).
    ///
    /// Two phrases and not one: cdrtools prints the warning about the daemon and
    /// the refusal itself on separate lines, and which of them survives depends
    /// on the tool and the version. Either is enough to know the disc was never
    /// looked at.
    ///
    /// The word `mounted` is deliberately not among them. It appears in output
    /// that has nothing to do with this, and a false positive here would blame
    /// macOS for a disc that really is bad — which is the one mistake this
    /// message must not make.
    static func refusedTheOpen(_ capture: String) -> Bool {
        capture.contains("exclusive access") || capture.contains("diskarbitrationd")
    }

    /// `tail -6` of the log (`burncd:2224`).
    ///
    /// Six because cdda2wav's complaint is the last thing it says and everything
    /// above it is the disc it was reading; blank lines go, because a log that
    /// ends in a newline would otherwise spend a note on nothing.
    static func tail(of log: URL, keep: Int = 6) -> [String] {
        guard let text = try? String(contentsOf: log, encoding: .isoLatin1) else { return [] }
        return
            text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.allSatisfy(\.isWhitespace) }
            .suffix(keep)
    }

    // MARK: - The machine

    public static let cdda2wavPresent: @Sendable () -> Bool = {
        Tooling.locate("cdda2wav") != nil
    }

    public static let tocOutput: @Sendable (String) -> String? = { device in
        guard let cdrecord = Tooling.locate("cdrecord") else { return nil }
        return Tooling.output(cdrecord, ["-toc", "dev=\(device)"])
    }

    /// Stream every track to nowhere.
    ///
    /// The script's own account: *we do not want the audio; we want to know
    /// whether the drive can get through the disc without a read error, which is
    /// exactly what a player has to do.* So stdout is `/dev/null` and not a pipe
    /// — an hour of CD audio is six hundred megabytes, and `Tooling.run` reads
    /// what it spawns into memory.
    ///
    /// **The working directory is the job's, and that is not tidiness.**
    /// cdda2wav writes `audio_01.inf` and its friends beside itself as it goes,
    /// one per track, wherever it happens to be standing — which for an app is
    /// wherever it was launched from. Seventeen of them turned up in the root of
    /// this repository the first time it was run by hand.
    public static let fullRead: @Sendable (String, Int, URL) -> Int32? = { device, want, log in
        guard let cdda2wav = Tooling.locate("cdda2wav") else { return nil }
        let directory = log.deletingLastPathComponent()
        FileManager.default.createFile(atPath: log.path, contents: nil)
        guard let errors = try? FileHandle(forWritingTo: log) else { return nil }
        defer { try? errors.close() }

        let process = Process()
        process.executableURL = cdda2wav
        process.arguments = [
            "dev=\(device)", "-q", "-t", "1+\(want)", "-output-format", "raw", "-",
        ]
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        return process.terminationStatus
    }

    public static let titlesOutput: @Sendable (String, URL) -> String? = { device, directory in
        guard let cdda2wav = Tooling.locate("cdda2wav") else { return nil }
        // Same droppings, same answer as `fullRead` — and `Tooling.run` has no
        // opinion on where a process stands, so this one is spawned here.
        let process = Process()
        process.executableURL = cdda2wav
        process.arguments = ["dev=\(device)", "-J", "-v", "titles"]
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return nil }
        let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    /// `verify-<n>.log`, beside the image (`burncd:2219`).
    public static func logURL(work: URL, disc: Int) -> URL {
        work.appending(path: "verify-\(disc).log")
    }

    /// `cdrecord -eject dev=…` after the verify (`burncd:2674`).
    ///
    /// The write's own `-eject` was suppressed to keep the disc readable, so the
    /// tray still has to be opened afterwards — it is how a multi-disc job cues
    /// the next disc, and how a single-disc job tells you it is finished. Quiet
    /// and ignored, as the script's `>/dev/null 2>&1 || true` is: the disc is
    /// already verified, and a drive that will not open its own tray has not
    /// changed that.
    public static let eject: @Sendable (String) -> Void = { device in
        guard let cdrecord = Tooling.locate("cdrecord") else { return }
        _ = Tooling.run(cdrecord, ["-eject", "dev=\(device)"])
    }
}
