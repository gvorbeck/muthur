import Foundation

/// §11 — the health check, re-pointed at the native stack.
///
/// `run_check` (`player:345`–`player:466`) is fourteen checks and a verdict, and
/// its own comment says why it exists: `--check` is the first thing anyone runs
/// on a new machine, so it **says what is wrong and what to install** rather
/// than failing later with a shell error (`panel.sh:573`).
///
/// Five of the fourteen asked about things this port does not have. Each is
/// accounted for below rather than deleted, because a person who has run
/// `player --check` and then runs this one will notice a missing row and wonder
/// which of the two is lying:
///
/// - `mpv` (`player:349`) and `unix sockets` (`player:386`) — there is no
///   external player to find or to drive. The engine is AVFoundation (§6), so
///   the row becomes `playback` and reports what is playing the audio.
/// - `mpv archives` (`player:355`) and `zips` (`player:379`) — the port reads a
///   zip where it lies (§2.2, `ZipArchive`) and needs neither `bsdtar` nor
///   `unzip`. Both fold into one `zips` row that can no longer fail.
/// - `terminal` (`player:438`) and `window size` (`player:444`) — a locale and a
///   row count are questions about a terminal emulator. There isn't one.
///
/// **Nothing that the port cannot yet answer goes quiet.** A screen that omits a
/// subsystem it is unsure about leaves the reader with the same question they
/// arrived with — so `audio output` names a route it does not yet follow, and
/// `optical drive` says which of the two things the media in the bay is: a
/// record §1.3 can open, or something it cannot.
public struct Diagnostics: Sendable {

    /// The finished screen. `CHECK_FAIL` / `CHECK_WARN` are derived rather than
    /// accumulated — the script keeps two globals because `ck` is a printf and
    /// has nowhere else to put them (`panel.sh:578`).
    public struct Report: Sendable, Equatable {
        public let checks: [Check]

        public init(checks: [Check]) { self.checks = checks }

        public var failed: Bool { checks.contains { $0.mark == .fail } }
        public var warned: Bool { checks.contains { $0.mark == .warn } }

        /// **`fail` is the only thing that changes the exit code.** A warning is
        /// printed, counted, and said out loud at the end, and is not a reason
        /// to refuse: an empty drive bay is a warning (`panel.sh:596`).
        public var exitCode: Int32 { failed ? 1 : 0 }

        /// The verdict, and **the one place D8 lets the voice out**. Three
        /// lines, not two — `check_summary` has a middle case (`panel.sh:598`)
        /// and it is the one most people see, because most of these checks can
        /// only ever warn.
        ///
        /// First person, flat, declarative: it reports and does not banter, and
        /// it keeps the script's own words for what a warning is worth.
        public var verdict: String {
            if failed { return "I CANNOT PLAY A RECORD. THE ✗ ITEMS ABOVE ARE WHY." }
            if warned { return "I CAN PLAY A RECORD. THE ! ITEMS ABOVE ARE USUALLY FINE." }
            return "I CAN PLAY A RECORD."
        }

        public var mark: Check.Mark { failed ? .fail : (warned ? .warn : .ok) }

        /// The same report on a terminal, for `--check` (`player:531`).
        ///
        /// `ck`'s own layout with the colour left out — `'  %s  %-20s %s\n'`
        /// (`panel.sh:588`) under `check_open`'s heading (`panel.sh:583`) and
        /// over `check_summary`'s blank line and verdict (`panel.sh:599`).
        /// Nothing is wrapped here and nothing is truncated: a terminal is as
        /// wide as it is, and that is the whole difference between this and the
        /// panel, which is 69 columns whatever the window does.
        public var plainText: String {
            var out = "\n  MU/TH/UR health check\n\n"
            for check in checks {
                let label = Columns.fit(check.label, to: Check.labelWidth)
                out += "  \(check.mark.glyph)  \(label) \(check.detail)\n"
            }
            return out + "\n  \(verdict)\n\n"
        }
    }

    /// Everything the check asks the machine, in one place, so the suite can
    /// answer for it. The defaults are the real questions.
    public struct Probes: Sendable {
        public var environment: [String: String]
        /// `command -v <name>`, with Homebrew's two directories named outright
        /// because a GUI app inherits no shell PATH.
        public var tool: @Sendable (String) -> URL?
        /// `drutil status`, whole. Parsed here rather than there so the suite
        /// can hand over a recorded one.
        public var drutil: @Sendable () -> String?
        /// §1.3's answer about the same drive: the disc, if the disc source can
        /// find one on it. **It opens nothing** — `DiscFinder` reads the mount
        /// table and a `drutil status`, both of which are answers *about* the
        /// drive — so asking it here is on the safe side of the ordering rule
        /// below.
        public var disc: @Sendable () -> DiscFinder.Found?
        /// The default output device's name, or nil where CoreAudio would not
        /// say.
        public var outputRoute: @Sendable () -> String?
        /// Whether the sleeve is switched on at all (§13, `PLAYER_ART=0`).
        public var sleeveEnabled: Bool
        /// `--no-mb`'s half of the MusicBrainz switch. The other half is
        /// `MUTHUR_NO_MB`, which is already in `environment`; the row merges
        /// them the same way the disc path does.
        public var useMusicBrainz: Bool
        /// §8's catalogue, and where it was looked for.
        public var catalogue: @Sendable () -> (location: URL, shelf: Catalogue?)
        /// §1.2's scan: the directories, and what was found in them.
        public var sources: @Sendable () -> (directories: [URL], found: Int)
        /// Free bytes where a zip would be unpacked.
        public var freeSpace: @Sendable (URL) -> UInt64

        public init(
            environment: [String: String] = ProcessInfo.processInfo.environment,
            tool: @escaping @Sendable (String) -> URL? = Diagnostics.locate,
            drutil: @escaping @Sendable () -> String? = Diagnostics.drutilStatus,
            disc: @escaping @Sendable () -> DiscFinder.Found? = Diagnostics.discInTheDrive,
            outputRoute: @escaping @Sendable () -> String? = AudioRoute.current,
            sleeveEnabled: Bool = true,
            useMusicBrainz: Bool = true,
            catalogue: @escaping @Sendable () -> (location: URL, shelf: Catalogue?) = {
                let location = CatalogueFile.locate()
                return (location.url, CatalogueFile.read(location))
            },
            sources: @escaping @Sendable () -> (directories: [URL], found: Int) = {
                let directories = SourceScanner.defaultDirectories()
                return (directories, SourceScanner.scan(directories: directories).count)
            },
            freeSpace: @escaping @Sendable (URL) -> UInt64 = Unpacker.freeSpace(at:)
        ) {
            self.environment = environment
            self.tool = tool
            self.drutil = drutil
            self.disc = disc
            self.outputRoute = outputRoute
            self.sleeveEnabled = sleeveEnabled
            self.useMusicBrainz = useMusicBrainz
            self.catalogue = catalogue
            self.sources = sources
            self.freeSpace = freeSpace
        }
    }

    /// Run the whole check.
    ///
    /// **Order is not cosmetic here.** `drutil` is asked before anything that
    /// could open the drive, because `cdrecord -checkdrive` opens the device
    /// exclusively and macOS then lets go of the media — drutil reports `No
    /// Media Inserted` about a disc that never moved, and keeps reporting it
    /// (`burncd:278`, and §1.3's fourth box). The script's own order is already
    /// safe: it reads `drutil status` at `player:395` and only asks whether the
    /// cdrtools binaries *exist* at `player:402`. That order is kept, and the
    /// `CD-Text` row deliberately does not call `OpticalDrive.detect`.
    public static func run(_ probes: Probes = Probes()) -> Report {
        var checks: [Check] = []

        checks.append(playback(probes))
        checks.append(metadata(probes))
        checks.append(analyser())
        checks.append(zips())
        checks.append(opticalDrive(probes))
        checks.append(cdText(probes))
        checks.append(musicBrainz(probes))
        checks.append(scratchSpace(probes))
        checks.append(sleeve(probes))
        checks.append(audioOutput(probes))
        checks.append(shelf(probes))
        checks.append(records(probes))

        return Report(checks: checks)
    }

    // MARK: - The rows

    /// Was `mpv` (`player:349`), the one row in bash that could hard-fail on a
    /// missing binary. The engine itself cannot fail here — it ships with the
    /// machine — but **the row is about what plays the audio, and half of that
    /// is still a binary**. §17, and D40.
    ///
    /// Bash asked about `ffmpeg` on its `analyser` row, and said so outright:
    /// "ffmpeg itself, not ffprobe" (`player:367`), warning `no ffmpeg — the
    /// columns fall back to a pattern` (`player:374`). §9 taps the engine, so
    /// that row lost its subject — and the binary went with it, while
    /// `AudioSourceOpener` still refuses to open an Opus without it. A machine
    /// with `ffprobe` and no `ffmpeg` would have read the tags off the record,
    /// reported `ok` twice, and then not played it.
    ///
    /// Both halves are named because the fallback needs both: `ffprobe` to find
    /// out what is in the file and `ffmpeg` to decode it
    /// (`AudioSource.swift:63`). One without the other opens nothing, so a row
    /// that only asked after `ffmpeg` would be the same hole one binary along.
    static func playback(_ probes: Probes) -> Check {
        let missing = AudioSourceOpener.fallbackTools.filter { probes.tool($0) == nil }
        guard missing.isEmpty else {
            return Check(
                .warn, "playback",
                "AVFoundation, but no \(missing.joined(separator: " and ")) — \(AudioSourceOpener.fallbackFormats) will not play. brew install ffmpeg"
            )
        }
        return Check(
            .ok, "playback",
            "AVFoundation, part of the system, with ffmpeg behind it for \(AudioSourceOpener.fallbackFormats)"
        )
    }

    /// Was `ffprobe` (`player:361`), a hard failure. Here AVFoundation reads the
    /// tags and ffprobe is the fallback for what it will not take — notably
    /// Opus and Ogg (`CLAUDE.md`) — so a machine without it reads fewer formats
    /// rather than none, which is a warning.
    static func metadata(_ probes: Probes) -> Check {
        if let ffprobe = probes.tool("ffprobe") {
            return Check(.ok, "metadata", "AVFoundation, with ffprobe at \(ffprobe.path)")
        }
        return Check(
            .warn, "metadata",
            "AVFoundation only — no ffprobe, so Opus and Ogg may not read. brew install ffmpeg")
    }

    /// Was `analyser` (`player:371`), which warned `no ffmpeg — the columns fall
    /// back to a pattern`. §9 taps the engine and does the FFT in vDSP, so the
    /// columns are the audio whatever else is installed and the pattern
    /// fallback has nothing left to fall back from.
    static func analyser() -> Check {
        Check(.ok, "analyser", "an AVAudioEngine tap — the columns are the audio itself")
    }

    /// Was two rows: `mpv archives` (`player:355`) and `zips` (`player:379`),
    /// the latter of which could fail with `no tar and no unzip`. §2.2 reads the
    /// central directory itself, so the failure is gone and so is the warning
    /// about `unzip` mangling accented names — which is the reason it reads the
    /// archive directly in the first place (`player:256`).
    static func zips() -> Check {
        Check(.ok, "zips", "read where they lie — no tar, no unzip, no charset to get wrong")
    }

    /// `player:395`, ported outcome for outcome. Asked **first**, and asked with
    /// `drutil` rather than anything that opens the device. `DiscFinder` is
    /// asked after it and is safe to ask here for the same reason it is safe to
    /// ask on every rescan: it opens nothing either (§1.3's fifth box).
    ///
    /// **The media type cannot say whether a disc will play, which is why the
    /// finder is asked at all.** The audio CD this port was written against
    /// reported `Type: CD-ROM` — §19 step 1, the disc that mounted as
    /// `/Volumes/Deluxe` — the same word a data disc gives, so a list of
    /// playable type strings would be a rule the kernel never promised. What
    /// can be said honestly is whether §1.3 found a record on it, and that is
    /// the split: found is the script's own `ok` back again, `media: <type>`
    /// (`player:396`), with where it is mounted; media the disc source cannot
    /// open stays a warning, because `media: DVD-R` alone would read as a
    /// promise.
    static func opticalDrive(_ probes: Probes) -> Check {
        guard probes.tool("drutil") != nil else {
            return Check(.warn, "optical drive", "drutil not found — CDs cannot be detected")
        }
        guard let media = mediaType(probes.drutil()) else {
            return Check(.warn, "optical drive", "no disc, or no drive")
        }
        guard let disc = probes.disc() else {
            return Check(
                .warn, "optical drive",
                "media: \(media) — not mounted as an audio CD, so --cd has nothing to open")
        }
        return Check(.ok, "optical drive", "media: \(media) — mounted at \(disc.volume.path)")
    }

    /// The media type off `drutil status`, or nil for an empty bay. **D37.**
    ///
    /// `player:396` reads it with `awk -F: '/Type:/ { print $2; exit }'`, and
    /// `$2` on a colon split is everything between the first colon and the
    /// *second* — which on a drive with a disc in it is `CD-ROM       Name`,
    /// because drutil packs two columns onto that line. The script then prints
    /// `media: CD-ROM Name`.
    ///
    /// This is not the port second-guessing the author. **`burncd` is the same
    /// author reading the same output and getting it right**, with the trap
    /// written down beside the fix — "drutil packs two columns onto the Type
    /// line … so take the first word after the label and leave the rest of the
    /// row" (`burncd:322`), `sed -n 's/.*Type:[[:space:]]*\([^[:space:]]*\).*/\1/p'`
    /// (`burncd:324`). Where the two disagree the later one wins, and it comes
    /// with its own reasoning.
    ///
    /// The empty bay follows `burncd:319` too: `no media` anywhere in the
    /// status, case-insensitively, not a test on the parsed field. `[ -n "$v" ]`
    /// at `player:397` cannot catch it, because `No Media Inserted` is a
    /// perfectly good word.
    static func mediaType(_ status: String?) -> String? {
        guard let status else { return nil }
        guard status.range(of: "no media", options: .caseInsensitive) == nil else { return nil }
        for line in status.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let range = line.range(of: "Type:") else { continue }
            let word = line[range.upperBound...]
                .split(whereSeparator: \.isWhitespace)
                .first
                .map(String.init)
            guard let word, !word.isEmpty else { return nil }
            return word
        }
        return nil
    }

    /// The media's **device node** off the same `Type:` line. **D17**, and §1.3
    /// is what uses it.
    ///
    /// `drutil` packs two columns onto that row — `burncd:322` says so and
    /// `burncd:324` works around it — and this is the second column:
    ///
    /// ```
    ///   Type: CD-ROM               Name: /dev/disk10
    /// ```
    ///
    /// Verbatim from this machine, §19 step 1. The padding is generous and
    /// `Name:` never runs into the type, so this splits on the literal label
    /// rather than on a column position.
    ///
    /// Same empty-bay rule as `mediaType`, and for the same reason: an empty
    /// drive still prints a perfectly good `Type:` line, so the `no media` test
    /// has to come first or `No Media Inserted` reads as a media type.
    ///
    /// Nil where the drive names no node. That is a real state — a drive that
    /// does not report one — and §1.3 degrades rather than refusing, per §17.
    static func mediaDevice(_ status: String?) -> String? {
        guard let status else { return nil }
        guard status.range(of: "no media", options: .caseInsensitive) == nil else { return nil }
        for line in status.split(separator: "\n", omittingEmptySubsequences: false) {
            guard line.range(of: "Type:") != nil,
                let range = line.range(of: "Name:")
            else { continue }
            let word = line[range.upperBound...]
                .split(whereSeparator: \.isWhitespace)
                .first
                .map(String.init)
            guard let word, !word.isEmpty else { return nil }
            return word
        }
        return nil
    }

    /// `player:402`, unchanged: §4's chain is cdrtools, and neither binary is
    /// reliably present. Presence only — nothing here opens the drive.
    static func cdText(_ probes: Probes) -> Check {
        if probes.tool("cdda2wav") != nil {
            return Check(.ok, "CD-Text", "cdda2wav present")
        }
        if probes.tool("cdrecord") != nil {
            return Check(.ok, "CD-Text", "cdrecord present")
        }
        return Check(
            .warn, "CD-Text", "no cdrtools — discs fall back to MusicBrainz or numbers")
    }

    /// `player:410`. `curl` and `jq` drop — URLSession and JSONSerialization are
    /// the system's — so the question the row is left with is whether the lookup
    /// is switched off, and the honest answer about the rest is that a network
    /// this cannot reach looks the same as a disc nobody has catalogued.
    ///
    /// **It does not reach out to find out.** A diagnostic that hangs on a
    /// captive portal is a worse diagnostic than one that says what it will try.
    ///
    /// **The switch is not read here.** `player:410` reads the same `USE_MB` the
    /// lookup itself reads, so the check cannot claim the lookup is on while it
    /// is off; this row asks `SourceOpener` the same question §4's disc path
    /// asks, for the same reason.
    static func musicBrainz(_ probes: Probes) -> Check {
        let sleeve = SourceOpener.musicBrainzSwitch(
            flag: probes.useMusicBrainz, environment: probes.environment
        )
        if sleeve.isOff {
            return Check(
                .warn, "MusicBrainz",
                "disabled with \(sleeve.label) — untitled discs stay untitled")
        }
        return Check(
            .ok, "MusicBrainz",
            "URLSession — no curl, no jq. Reached when a disc needs naming, never before")
    }

    /// `player:423`, and the script's comment is right that this is the one that
    /// would otherwise not show up until an album was half open. All three
    /// outcomes ported, including the middle one — the `$TMPDIR` fallback works
    /// and is the directory the OS may reclaim under a playing album, so it
    /// reports as a warning and not a plain ok.
    static func scratchSpace(_ probes: Probes) -> Check {
        let (base, fellBack) = Scratch.workBase(environment: probes.environment)
        let manager = FileManager.default
        guard (try? manager.createDirectory(at: base, withIntermediateDirectories: true)) != nil,
            manager.isWritableFile(atPath: base.path)
        else {
            return Check(.fail, "scratch space", "cannot write to \(base.path) — zips cannot be opened")
        }
        // `room_str` (`player:1189`). It lives on `UnpackFailure` because §2's
        // two messages about room are the only other place a number of bytes is
        // read by a person.
        let free = UnpackFailure.room(probes.freeSpace(base))
        if fellBack {
            return Check(
                .warn, "scratch space",
                "\(free) free in \(base.path) — cache dir unwritable, so long albums may be reclaimed mid-play"
            )
        }
        return Check(.ok, "scratch space", "\(free) free in \(base.path)")
    }

    /// Was `cover` (`player:454`). **The question survives and every one of its
    /// answers does not**: the bash outcomes were all about how many columns the
    /// terminal had and whether it was iTerm2. A window has pixels.
    ///
    /// What is kept is the reason the row exists at all — a sleeve that is
    /// silently absent looks exactly like a sleeve that failed to download, and
    /// the two have nothing to do with each other.
    static func sleeve(_ probes: Probes) -> Check {
        guard probes.sleeveEnabled else {
            return Check(.ok, "sleeve", "off — no picture is looked for")
        }
        return Check(
            .ok, "sleeve",
            "beside the record, then the tags, then the archive — at the size the window has")
    }

    /// **New — not in bash**, because a terminal has no idea where the sound
    /// goes. §14's box for route *handling* is unticked, and this says so: it
    /// reports the route it can see and does not claim to follow it when it
    /// changes.
    static func audioOutput(_ probes: Probes) -> Check {
        guard let route = probes.outputRoute() else {
            return Check(.warn, "audio output", "CoreAudio named no default output device")
        }
        return Check(
            .warn, "audio output",
            "\(route) — the route is read once, and changing it mid-record is not handled yet")
    }

    /// **New — not in bash**, where the collection lookup was silent by design
    /// and had nothing to report (`player:1618`). §8 gave it a file that can be
    /// somewhere else, and a `SHELF` line that is simply absent looks identical
    /// whether the record is not in the catalogue or the catalogue was never
    /// found — the same confusion the cover row was written for.
    static func shelf(_ probes: Probes) -> Check {
        let (location, shelf) = probes.catalogue()
        guard let shelf else {
            return Check(
                .warn, "the shelf",
                "no catalogue at \(location.path) — records play, they just arrive unannotated")
        }
        guard shelf.columns.title != nil else {
            return Check(
                .warn, "the shelf",
                "\(location.path) has no title column — nothing can be looked up in it")
        }
        return Check(.ok, "the shelf", "\(shelf.count) records in \(location.path)")
    }

    /// **New — not in bash**, where `die "nothing to play…"` (`player:1114`) said
    /// this at the moment it mattered and then ended the program. D36 is why it
    /// cannot end the program here, and this row is the calm version of the same
    /// sentence: where it looks, and what it found there.
    static func records(_ probes: Probes) -> Check {
        let (directories, found) = probes.sources()
        let where_ = directories.map(\.path).joined(separator: ", ")
        guard found > 0 else {
            return Check(.warn, "records", "nothing to play in \(where_)")
        }
        return Check(.ok, "records", "\(found) in \(where_)")
    }

    // MARK: - Asking the machine

    /// `command -v <name>`. Public only because a default argument cannot reach
    /// `Tooling`, which is §4's own business and stays internal.
    public static func locate(_ name: String) -> URL? { Tooling.locate(name) }

    /// §1.3's `find_cd`, with its own default probes. Named here so the row has
    /// a default it can be handed a recorded answer in place of, the same way
    /// `drutilStatus` is.
    public static func discInTheDrive() -> DiscFinder.Found? { DiscFinder.find() }

    /// `drutil status`, whole and unparsed. Nil where drutil is not installed or
    /// would not run.
    public static func drutilStatus() -> String? {
        guard let drutil = Tooling.locate("drutil") else { return nil }
        return Tooling.output(drutil, ["status"])
    }
}
