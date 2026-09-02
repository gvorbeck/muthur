import Foundation

/// §1 — opening what the picker or the command line handed us.
///
/// Three paths: a folder is read directly, a zip is unpacked into scratch
/// first, and a disc throws until §1.3 exists.
public enum SourceOpener {

    /// What came out of opening a source: the record, where it came from, how
    /// its titles were sourced, the directory it lives in (for the sleeve), and
    /// the scratch directory if one was made.
    public struct Opened: Sendable {
        public let record: Record
        public let source: SourceKind
        public let titleSource: TitleSource
        public let directory: URL
        public let scratch: Scratch?
    }

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case notFound(path: String)
        case notASource(path: String)
        /// A `.zip` that opened, and holds nothing to play. **D47**, moved here
        /// from the scan by D50.
        case noAudioInArchive(path: String)
        /// `--cd` with an empty drive. `die "no audio CD in the drive"`
        /// (`player:3528`) — the script's words, kept.
        case noDisc

        public var description: String {
            switch self {
            case .notFound(let path):
                "no such file or directory: \(path)"
            case .notASource(let path):
                "not a zip or a folder: \(path)"
            case .noAudioInArchive(let path):
                // `Record.Failure.noAudio`'s words, because it is the same
                // finding arrived at earlier: a source with nothing in it to
                // play. A person who has seen one should recognise the other.
                "no audio in \(URL(fileURLWithPath: path).lastPathComponent)"
            case .noDisc:
                "no audio CD in the drive"
            }
        }
    }

    /// Resolve a path — off the command line, or out of `BROWSE`'s open panel —
    /// to a URL and a source kind.
    ///
    /// **D47 is applied here now, and it used to be applied in the scan.** With
    /// the scan gone (D50) this is the only place left that gets to look at an
    /// archive before it is unpacked, and it is the place that matters: a zip of
    /// scanned PDFs picked out of `BROWSE` said `OPENING`, spent the unpack, and
    /// then reported an empty record. It says what is wrong with it instead, for
    /// the price of the two `pread`s §2.2 already knows how to do.
    ///
    /// **An archive that will not open at all is let through, and the scan
    /// dropped it.** That is not an oversight in either direction — it is the
    /// same rule reaching a different answer because the question changed. The
    /// scan was choosing what to *offer*, and had no business offering a row it
    /// could not vouch for. This is answering a file somebody has just pointed
    /// at, and `BROWSE` exists precisely so that the archive the central
    /// directory would not read can still be tried (`PanelModel.browse`). Refuse
    /// only what was read and found wanting; where the read itself failed, let
    /// `Unpacker` have its go and report what it finds.
    public static func resolve(path: String) throws -> (url: URL, kind: SourceKind) {
        let url = URL(fileURLWithPath: path)
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            throw Failure.notFound(path: path)
        }
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return (url, .folder)
        }
        if url.pathExtension.lowercased() == "zip" {
            if let archive = try? ZipArchive(url: url), !archive.holdsAudio {
                throw Failure.noAudioInArchive(path: path)
            }
            return (url, .zip)
        }
        throw Failure.notASource(path: path)
    }

    /// Open a source and return the record it contains.
    ///
    /// `useMusicBrainz` is `--no-mb`, carried from the command line
    /// (`LaunchOptions`) to the one place that would ask. It rides on the
    /// general `open` rather than on `openDisc` because the picker opens a disc
    /// too (§1.2's row), and a flag that only worked when the disc was named on
    /// the command line would be a flag that quietly stopped working.
    /// **`progress` hands over the stage, not a sentence about it.** It used to
    /// pass a formatted string, which meant the two numbers `load_stage` puts
    /// the bar's head at (`player:1152`) were spent on making the words and then
    /// thrown away — so the panel could say `READING · 62%` and had nothing to
    /// draw a meter with. `LoadingStage` is what the script hands `load_stage`,
    /// and the wording is the screen's business.
    public static func open(
        url: URL,
        kind: SourceKind,
        useMusicBrainz: Bool = true,
        progress: (@Sendable (LoadingStage) -> Void)? = nil
    ) async throws -> Opened {
        switch kind {
        case .folder:
            return try await openFolder(url, progress: progress)
        case .zip:
            return try await openZip(url, progress: progress)
        case .disc:
            return try await openDisc(
                url, useMusicBrainz: useMusicBrainz, progress: progress
            )
        }
    }

    /// §1.3 and §4 together: the mounted CDDA volume is read as it stands, and
    /// then something is asked to name the tracks.
    ///
    /// **No ripping step** (`player:1371`). The volume already presents the
    /// audio as files; copying them somewhere first would buy nothing and cost
    /// the time.
    ///
    /// `numbersFromFilenames: true` is the CD-only rescue (§3, `player:1454`) —
    /// a CDDA mount has no tags at all, so without it every row is 9999 and
    /// every title §4 learns lands on the wrong one.
    ///
    /// **On the ordering.** The table of contents comes off `.TOC.plist` on the
    /// mount (**D44**) and opens no device. CD-Text is the one step here that
    /// talks to the drive, and on this platform it cannot succeed: an audio CD
    /// is always mounted, `diskarbitrationd` holds it, and cdrtools cannot get
    /// the exclusive open it insists on. It is attempted anyway rather than
    /// quietly dropped — it is the script's own §4.2 step, it is what an
    /// *unmounted* disc would answer, and the failed opens were observed not to
    /// disturb `drutil` or the mount (§19). What it costs is a handful of
    /// subprocesses that exit 255, and what it buys is that the port does not
    /// silently skip a step the script takes.
    private static func openDisc(
        _ url: URL,
        useMusicBrainz: Bool,
        progress: (@Sendable (LoadingStage) -> Void)?
    ) async throws -> Opened {
        let label = url.lastPathComponent
        var record = try await Record.read(
            directory: url, sourceLabel: label,
            numbersFromFilenames: true,
            progress: { p in
                progress?(.reading(p, source: label))
            }
        )

        let drive = OpticalDrive.detect()
        let outcome = await DiscTitles.resolve(
            &record,
            volumeName: label,
            cdText: DriveCDText(drive: drive),
            tableOfContents: VolumeTableOfContents(volume: url),
            // A nil transport disables the lookup silently (`ask`, line 163),
            // which would make `--no-mb` and "we forgot to pass one" the same
            // state. The real one goes in, and `useMusicBrainz` is the only
            // thing that switches it off.
            transport: URLSessionSleeveTransport(),
            useMusicBrainz: !musicBrainzDisabled(flag: useMusicBrainz),
            stage: { stage in
                progress?(.disc(stage, source: label))
            }
        )

        return Opened(
            record: record, source: .disc, titleSource: outcome.source,
            directory: url, scratch: nil
        )
    }

    /// Which switch, if either, has the sleeve lookup off.
    ///
    /// **Two names for one state.** The script has the same pair —
    /// `USE_MB="${PLAYER_MB:-1}"` (`player:81`) and `--no-mb) USE_MB=0`
    /// (`player:334`) — and merges them into one variable before anything reads
    /// it, which is why `run_check` at `player:410` and the lookup at
    /// `player:1839` can never disagree. This is that merge. Everything that
    /// wants to know goes through here: §11's report, and §4's disc path.
    ///
    /// **Either switch alone is enough, and nothing switches it back on.** The
    /// script's `[ "$USE_MB" = 1 ]` says the same: `PLAYER_MB=0` with no flag is
    /// off, `--no-mb` with no variable is off, and there is no argument that
    /// undoes either.
    enum MusicBrainzSwitch: Equatable {
        case on
        /// `--no-mb` on the command line.
        case flag
        /// `MUTHUR_NO_MB` in the environment.
        case variable

        var isOff: Bool { self != .on }

        /// What the report calls it. The script names the flag whichever one did
        /// it (`player:411`); with two names in play, naming the wrong one sends
        /// the reader to the wrong place, so this names the one that is set.
        var label: String {
            switch self {
            case .on: "on"
            case .flag: "--no-mb"
            case .variable: "MUTHUR_NO_MB"
            }
        }
    }

    /// **`MUTHUR_NO_MB` is inverted from the script's `PLAYER_MB`** and reads
    /// like every other `NO_` variable: unset is on, `0` and empty are on,
    /// anything else is off. The flag is checked first only because it is the
    /// thing a person just typed.
    static func musicBrainzSwitch(
        flag useMusicBrainz: Bool = true,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> MusicBrainzSwitch {
        if !useMusicBrainz { return .flag }
        guard let value = environment["MUTHUR_NO_MB"], value != "0", !value.isEmpty else {
            return .on
        }
        return .variable
    }

    static func musicBrainzDisabled(
        flag useMusicBrainz: Bool = true,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        musicBrainzSwitch(flag: useMusicBrainz, environment: environment).isOff
    }

    private static func openFolder(
        _ url: URL,
        progress: (@Sendable (LoadingStage) -> Void)?
    ) async throws -> Opened {
        let label = url.lastPathComponent
        let record = try await Record.read(
            directory: url, sourceLabel: label,
            progress: { p in
                progress?(.reading(p, source: label))
            }
        )
        return Opened(
            record: record, source: .folder, titleSource: .tags,
            directory: url, scratch: nil
        )
    }

    private static func openZip(
        _ url: URL,
        progress: (@Sendable (LoadingStage) -> Void)?
    ) async throws -> Opened {
        let label = url.lastPathComponent
        // `load_stage "OPENING" 0 "$total" "$SRC_LABEL"` (`player:1398`): said
        // before the archive is opened at all, so that a zip slow to be read off
        // a disk is a screen rather than a pause.
        progress?(.opening(source: label, total: 0))

        let scratch = try Scratch.open()

        let result = try Unpacker.unpack(
            zip: url, into: scratch.album, label: label,
            progress: { p in
                progress?(.opening(p, source: label))
            }
        )

        let discs = result.directories.count > 1
        let record = try await Record.read(
            directory: scratch.album, sourceLabel: label,
            discsFromSubdirectories: discs,
            progress: { p in
                progress?(.reading(p, source: label))
            }
        )
        return Opened(
            record: record, source: .zip, titleSource: .tags,
            directory: scratch.album, scratch: scratch
        )
    }
}
