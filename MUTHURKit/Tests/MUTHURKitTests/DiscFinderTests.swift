import Foundation
import Testing

@testable import MUTHURKit

/// §1.3 — `find_cd`, every branch, with no disc and no drive.
///
/// The strings the stubs hand over are not invented shapes. `drutilCD` and the
/// `cddafs` mount line below are what this machine actually printed with an
/// audio CD in the drive (§19), copied down to the column the `Name:` label
/// lands in — so a test that passes here is testing the parse against the
/// thing it will meet.
struct DiscFinderTests {

    // MARK: - The stubs

    /// `drutil status` with the disc in, transcribed exactly — the run of
    /// spaces before `Name:` and the whole-disk node included, because those
    /// two details are the entire parse.
    static let drutilCD = """
         Vendor   Product           Rev\u{20}
         MATSHITA DVD-RAM UJ8E2 S   1.00

                   Type: CD-ROM               Name: /dev/disk10
               Sessions: 1                  Tracks: 13
           Overwritable:   00:00:00         blocks:        0 /   0.00MB /   0.00MiB
             Space Free:   00:00:00         blocks:        0 /   0.00MB /   0.00MiB
             Space Used:   53:33:70         blocks:   241045 / 493.66MB / 470.79MiB
            Writability:\u{20}
        """

    /// The same drive, empty. Also transcribed.
    static let drutilEmpty = """
         Vendor   Product           Rev\u{20}
         MATSHITA DVD-RAM UJ8E2 S   1.00

                   Type: No Media Inserted
        """

    /// A drive that reports media but names no device — the degraded case §17
    /// wants scanned rather than refused.
    static let drutilNameless = """
               Type: CD-ROM
          Sessions: 1
        """

    static func probes(
        drutil: String? = nil,
        mount: String = "",
        volumes: [String] = [],
        listing: [String: [String]] = [:],
        directories: Set<String>? = nil,
        hasDrutil: Bool = true
    ) -> DiscFinder.Probes {
        DiscFinder.Probes(
            drutil: { drutil },
            mount: { mount },
            volumes: { volumes.map { URL(fileURLWithPath: $0) } },
            listing: { listing[$0.path] ?? [] },
            isDirectory: { url in
                guard let directories else { return true }
                return directories.contains(url.path)
            },
            hasDrutil: { hasDrutil }
        )
    }

    // MARK: - The mount parse

    @Test func mountSplitsDeviceOffTheFirstOn() {
        let entries = DiscFinder.MountTable.parse(
            "/dev/disk10 on /Volumes/Live on Air (cddafs, local, read-only)"
        )
        #expect(entries.count == 1)
        #expect(entries[0].device == "/dev/disk10")
        // The volume name contains ` on ` and survives it.
        #expect(entries[0].mountPoint.path == "/Volumes/Live on Air")
    }

    @Test func mountSplitsOptionsOffTheLastBracket() {
        let entries = DiscFinder.MountTable.parse(
            "/dev/disk10 on /Volumes/Live (Remastered) (cddafs, local, read-only)"
        )
        #expect(entries[0].mountPoint.path == "/Volumes/Live (Remastered)")
        #expect(entries[0].isCDDA)
    }

    /// Observed on this machine, and the reason a naive field split is wrong
    /// even before anyone brings a bracket into it.
    @Test func mountKeepsASpaceInAVolumeName() {
        let entries = DiscFinder.MountTable.parse(
            "/dev/disk5s2 on /Volumes/My Passport (exfat, local, nodev, nosuid)"
        )
        #expect(entries[0].device == "/dev/disk5s2")
        #expect(entries[0].mountPoint.path == "/Volumes/My Passport")
        #expect(!entries[0].isCDDA)
    }

    @Test func mountLineWithNoBracketIsNotADisc() {
        let entries = DiscFinder.MountTable.parse("/dev/disk3s1 on /System/Volumes/Data")
        #expect(entries.count == 1)
        #expect(!entries[0].isCDDA)
    }

    /// `cddafs` has to be the whole word at the front of the bracket. A volume
    /// mounted from a directory called `cddafs-backup` is not a disc.
    @Test func cddafsMustBeTheWholeWord() {
        let entries = DiscFinder.MountTable.parse(
            "/dev/disk4s1 on /Volumes/X (cddafsish, local)"
        )
        #expect(!entries[0].isCDDA)
    }

    @Test func cddafsAloneInTheBracket() {
        let entries = DiscFinder.MountTable.parse("/dev/disk10 on /Volumes/Deluxe (cddafs)")
        #expect(entries[0].isCDDA)
    }

    // MARK: - Route 1: the kernel said so

    /// The observed line, verbatim.
    @Test func cddafsMountIsFoundAndNothingElseIsAsked() {
        // If `drutil` were consulted this would refuse: it says the drive is
        // empty. The point of the assertion is that it is never reached.
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilEmpty,
                mount: """
                    /dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)
                    /dev/disk10 on /Volumes/Deluxe (cddafs, local, nodev, nosuid, read-only, noowners)
                    """
            )
        )
        #expect(found?.volume.path == "/Volumes/Deluxe")
        #expect(found?.device == "/dev/disk10")
        #expect(found?.route == .cddafs)
        #expect(found?.deviceConfirmed == false)
    }

    /// `[ -d "$mp" ]` (`player:990`): a mount table entry pointing at nothing is
    /// skipped, and the scan carries on past it rather than stopping there.
    @Test func cddafsMountPointMustExist() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilEmpty,
                mount: "/dev/disk9 on /Volumes/Ghost (cddafs, local)",
                directories: []
            )
        )
        #expect(found == nil)
    }

    @Test func firstCDDAMountWins() {
        let found = DiscFinder.find(
            Self.probes(
                mount: """
                    /dev/disk10 on /Volumes/First (cddafs, local)
                    /dev/disk11 on /Volumes/Second (cddafs, local)
                    """
            )
        )
        #expect(found?.volume.path == "/Volumes/First")
    }

    // MARK: - The ordering: drutil before the listing

    /// **The ordering is load-bearing, and this is the case that shows it.**
    /// `/Volumes/Field Recordings` is an external drive full of AIFFs. It passes
    /// every shape test `find_cd` has. Only the drive can say it is not a disc.
    @Test func anExternalDriveOfAIFFsIsNotADiscWhenTheDriveIsEmpty() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilEmpty,
                mount: "/dev/disk6s1 on /Volumes/Field Recordings (exfat, local)",
                volumes: ["/Volumes/Field Recordings"],
                listing: ["/Volumes/Field Recordings": ["a.aiff", "b.aiff", "c.aiff"]]
            )
        )
        #expect(found == nil)
    }

    @Test func noDrutilOnTheMachineMeansNoFallbackScanAtAll() {
        let found = DiscFinder.find(
            Self.probes(
                volumes: ["/Volumes/Audio CD"],
                listing: ["/Volumes/Audio CD": ["1 Audio Track.aiff"]],
                hasDrutil: false
            )
        )
        #expect(found == nil)
    }

    @Test func drutilReturningNothingIsTheSameAsAnEmptyDrive() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: nil,
                volumes: ["/Volumes/Audio CD"],
                listing: ["/Volumes/Audio CD": ["1 Audio Track.aiff"]]
            )
        )
        #expect(found == nil)
    }

    // MARK: - Route 2: it looks like one

    @Test func audioTrackNamesAreEnoughOnTheirOwn() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilCD,
                mount: "/dev/disk10 on /Volumes/Audio CD (msdos, local)",
                volumes: ["/Volumes/Audio CD"],
                listing: ["/Volumes/Audio CD": ["1 Audio Track.aiff"]]
            )
        )
        #expect(found?.volume.path == "/Volumes/Audio CD")
        #expect(found?.route == .shape)
        #expect(found?.deviceConfirmed == true)
    }

    /// Two AIFFs and no `Audio Track` anywhere: the second test carries it
    /// (`player:1008`).
    @Test func twoAIFFsAreEnoughWithoutTheName() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilCD,
                mount: "/dev/disk10 on /Volumes/Deluxe (msdos, local)",
                volumes: ["/Volumes/Deluxe"],
                listing: ["/Volumes/Deluxe": ["01.aiff", "02.AIF"]]
            )
        )
        #expect(found?.volume.path == "/Volumes/Deluxe")
    }

    /// One AIFF, no `Audio Track`: neither test passes. The count guard is not
    /// the same as the count test.
    @Test func oneAIFFAndNoNameIsNotADisc() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilCD,
                mount: "/dev/disk10 on /Volumes/Solo (msdos, local)",
                volumes: ["/Volumes/Solo"],
                listing: ["/Volumes/Solo": ["only.aiff"]]
            )
        )
        #expect(found == nil)
    }

    /// The count guard (`player:1005`): a volume with a track *named* like a
    /// disc but no AIFFs in it never reaches the name test.
    @Test func noAIFFsAtAllStopsBeforeTheNameTest() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilCD,
                mount: "/dev/disk10 on /Volumes/Rips (msdos, local)",
                volumes: ["/Volumes/Rips"],
                listing: ["/Volumes/Rips": ["1 Audio Track.flac", "2 Audio Track.flac"]]
            )
        )
        #expect(found == nil)
    }

    /// **The narrowness of `aiffCount` is deliberate** — a shelf of mp3s must
    /// not answer to "is there a CD in the drive", even with the drive loaded.
    @Test func mp3sAreNotADiscShape() {
        #expect(DiscFinder.aiffCount(["a.mp3", "b.flac", "c.wav"]) == 0)
        #expect(DiscFinder.aiffCount(["a.AIFF", "b.Aif"]) == 2)
        #expect(DiscFinder.aiffCount(["notaiff", "aiff"]) == 0)
    }

    @Test func audioTrackIsMatchedAnywhereInTheNameAndCaselessly() {
        #expect(DiscFinder.hasAudioTrack(["01 audio track.aiff"]))
        #expect(DiscFinder.hasAudioTrack(["Deluxe Audio Track 03.aiff"]))
        #expect(!DiscFinder.hasAudioTrack(["Audio.aiff", "Track.aiff"]))
    }

    @Test func volumesAreTriedInOrderAndTheFirstMatchWins() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilNameless,
                volumes: ["/Volumes/AAA", "/Volumes/BBB"],
                listing: [
                    "/Volumes/AAA": ["1 Audio Track.aiff"],
                    "/Volumes/BBB": ["1 Audio Track.aiff"],
                ]
            )
        )
        #expect(found?.volume.path == "/Volumes/AAA")
    }

    // MARK: - D17: the device gate

    /// The gate at work: two volumes that both look like discs, and only one is
    /// on the node the drive named.
    @Test func onlyTheVolumeOnTheDrivesNodeIsTheDisc() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilCD,
                mount: """
                    /dev/disk6s1 on /Volumes/Field Recordings (exfat, local)
                    /dev/disk10 on /Volumes/Deluxe (msdos, local)
                    """,
                volumes: ["/Volumes/Field Recordings", "/Volumes/Deluxe"],
                listing: [
                    "/Volumes/Field Recordings": ["a.aiff", "b.aiff"],
                    "/Volumes/Deluxe": ["1 Audio Track.aiff"],
                ]
            )
        )
        #expect(found?.volume.path == "/Volumes/Deluxe")
        #expect(found?.deviceConfirmed == true)
    }

    /// A volume that is not in the mount table at all cannot be confirmed, so
    /// with a named node it is refused.
    @Test func anUnmountedLookingVolumeIsRefusedWhenTheNodeIsKnown() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilCD,
                mount: "",
                volumes: ["/Volumes/Deluxe"],
                listing: ["/Volumes/Deluxe": ["1 Audio Track.aiff"]]
            )
        )
        #expect(found == nil)
    }

    /// **The degraded scan.** `drutil` says there is media but names no device,
    /// so there is nothing to check against and the shape tests run undefended
    /// — scanned, not refused (§17).
    @Test func noNamedDeviceScansAnywayAndSaysSoInTheResult() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilNameless,
                mount: "",
                volumes: ["/Volumes/Deluxe"],
                listing: ["/Volumes/Deluxe": ["1 Audio Track.aiff"]]
            )
        )
        #expect(found?.volume.path == "/Volumes/Deluxe")
        #expect(found?.deviceConfirmed == false)
    }

    /// **The prefix trap, which is the whole reason this comparison is a
    /// function.** `/dev/disk1` is a prefix of `/dev/disk10`.
    @Test func diskOneDoesNotBelongToDiskTen() {
        #expect(!DiscFinder.device("/dev/disk1", belongsTo: "/dev/disk10"))
        #expect(!DiscFinder.device("/dev/disk1s2", belongsTo: "/dev/disk10"))
        #expect(!DiscFinder.device("/dev/disk100", belongsTo: "/dev/disk10"))
        #expect(!DiscFinder.device("/dev/disk10x1", belongsTo: "/dev/disk10"))
    }

    /// Observed: the CDDA mount is the whole-disk node itself, so equality is
    /// the case a real audio CD takes. The slice case is for the fallback.
    @Test func aNodeBelongsToItselfAndSoDoItsSlices() {
        #expect(DiscFinder.device("/dev/disk10", belongsTo: "/dev/disk10"))
        #expect(DiscFinder.device("/dev/disk10s1", belongsTo: "/dev/disk10"))
        #expect(DiscFinder.device("/dev/disk10s12", belongsTo: "/dev/disk10"))
    }

    /// The device gate sits between the count guard and the shape tests, and
    /// the ordering shows: a volume on the wrong node is skipped and the scan
    /// keeps going rather than returning nil at the first disappointment.
    @Test func aWrongNodeVolumeIsSkippedNotFatal() {
        let found = DiscFinder.find(
            Self.probes(
                drutil: Self.drutilCD,
                mount: """
                    /dev/disk1s3 on /Volumes/AAA (apfs, local)
                    /dev/disk10 on /Volumes/ZZZ (msdos, local)
                    """,
                volumes: ["/Volumes/AAA", "/Volumes/ZZZ"],
                listing: [
                    "/Volumes/AAA": ["x.aiff", "y.aiff"],
                    "/Volumes/ZZZ": ["x.aiff", "y.aiff"],
                ]
            )
        )
        #expect(found?.volume.path == "/Volumes/ZZZ")
    }

    // MARK: - The drutil parse the gate depends on

    @Test func mediaDeviceReadsTheNameOffTheTypeLine() {
        #expect(Diagnostics.mediaDevice(Self.drutilCD) == "/dev/disk10")
    }

    @Test func mediaDeviceRefusesAnEmptyDrive() {
        #expect(Diagnostics.mediaDevice(Self.drutilEmpty) == nil)
        #expect(Diagnostics.mediaType(Self.drutilEmpty) == nil)
    }

    @Test func mediaDeviceIsNilWhenTheTypeLineNamesNoNode() {
        #expect(Diagnostics.mediaDevice(Self.drutilNameless) == nil)
        #expect(Diagnostics.mediaType(Self.drutilNameless) != nil)
    }

    // MARK: - The picker row (§1.2's half of §1.3)

    /// `player:1018`: the disc is appended before the search path is walked, so
    /// its row is above everything.
    @Test func theDiscRowGoesFirst() throws {
        let tmp = TempDirectory("disc-row-order")
        let shelf = tmp.url.appending(path: "Shelf")
        let album = shelf.appending(path: "AAA Album")
        try FileManager.default.createDirectory(at: album, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: album.appending(path: "01.flac").path, contents: Data())

        let volume = tmp.url.appending(path: "Deluxe")
        try FileManager.default.createDirectory(at: volume, withIntermediateDirectories: true)
        for n in 1...3 {
            FileManager.default.createFile(
                atPath: volume.appending(path: "\(n) Audio Track.aiff").path, contents: Data()
            )
        }

        let entries = SourceScanner.scan(
            directories: [shelf],
            disc: DiscFinder.Found(
                volume: volume, device: "/dev/disk10", route: .cddafs, deviceConfirmed: false
            )
        )
        #expect(entries.first?.kind == .disc)
        #expect(entries.first?.label == "Deluxe")
        #expect(entries.first?.detail == "3 tracks · in the drive")
        #expect(entries.first?.mark == "⊙")
        #expect(entries.count == 2)
    }

    /// **D18.** The row is counted with `AudioFiles`, not with the script's
    /// AIFF grep — so a disc mounted with anything else on it still counts what
    /// is playable. The narrow `aiffCount` is for *detection* only.
    @Test func theDiscRowCountsWithAudioFilesNotWithTheAIFFGrep() throws {
        let tmp = TempDirectory("disc-row-count")
        let volume = tmp.url.appending(path: "Mixed")
        try FileManager.default.createDirectory(at: volume, withIntermediateDirectories: true)
        for name in ["1 Audio Track.aiff", "2 Audio Track.aiff", "bonus.flac", "sleeve.jpg"] {
            FileManager.default.createFile(
                atPath: volume.appending(path: name).path, contents: Data()
            )
        }
        let entries = SourceScanner.scan(
            directories: [],
            disc: DiscFinder.Found(
                volume: volume, device: nil, route: .shape, deviceConfirmed: false
            )
        )
        // Three playable files; the jpg is not one. The AIFF grep would say two.
        #expect(entries.first?.detail == "3 tracks · in the drive")
    }

    /// One level, because a CDDA mount is flat and the script counts with `ls`.
    @Test func theDiscRowDoesNotDescend() throws {
        let tmp = TempDirectory("disc-row-depth")
        let volume = tmp.url.appending(path: "Enhanced")
        let extras = volume.appending(path: "Extras")
        try FileManager.default.createDirectory(at: extras, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: volume.appending(path: "1 Audio Track.aiff").path, contents: Data()
        )
        FileManager.default.createFile(
            atPath: extras.appending(path: "video.flac").path, contents: Data()
        )
        let entries = SourceScanner.scan(
            directories: [],
            disc: DiscFinder.Found(
                volume: volume, device: nil, route: .cddafs, deviceConfirmed: false
            )
        )
        #expect(entries.first?.detail == "1 track · in the drive")
    }

    @Test func noDiscMeansNoDiscRow() {
        let tmp = TempDirectory("disc-row-absent")
        let entries = SourceScanner.scan(directories: [tmp.url], disc: nil)
        #expect(!entries.contains { $0.kind == .disc })
    }

    // MARK: - Against the machine, whatever is in it

    /// **Not gated on a disc, because it does not need one.** The default probes
    /// run for real here — `mount`, `drutil status`, `/Volumes` — and what is
    /// asserted is the *agreement* between them rather than any particular
    /// answer, so this holds on a machine with a disc, without one, and without
    /// an optical drive at all.
    ///
    /// It is the only place the real parsers meet the real strings outside §19,
    /// and it is what catches a macOS that changed the shape of `mount`.
    @Test func theRealMountTableParsesAndTheFinderAgreesWithIt() {
        let raw = DiscFinder.mountOutput() ?? ""
        #expect(!raw.isEmpty, "mount printed nothing — the probe itself is broken")

        let table = DiscFinder.MountTable.parse(raw)
        #expect(!table.isEmpty)
        // Every line that parsed names something and mounts it somewhere
        // absolute. A parse that quietly produced relative mount points would
        // still "work" and would compare against `drutil`'s node wrongly for
        // ever.
        //
        // **The device end is deliberately not asserted into a shape.** This
        // machine's table holds `devfs on /dev` and `map auto_home on …` —
        // neither is a device node, and the second even has a space in the
        // part before the first ` on `. `find_cd` copes with both for the
        // uninteresting reason that neither is `cddafs`, and any rule tighter
        // than "non-empty" here would be inventing a constraint the kernel
        // does not honour.
        for entry in table {
            #expect(!entry.device.isEmpty)
            #expect(entry.mountPoint.path.hasPrefix("/"))
        }
        // `/` is mounted on every running Mac, and it is not an audio CD.
        let root = table.first { $0.mountPoint.path == "/" }
        #expect(root != nil)
        #expect(root?.isCDDA == false)

        let found = DiscFinder.find()
        let cdda = table.first { $0.isCDDA && DiscFinder.directoryExists($0.mountPoint) }
        if let cdda {
            // A mounted audio CD: the kernel route must be the one taken.
            #expect(found?.volume.path == cdda.mountPoint.path)
            #expect(found?.route == .cddafs)
        } else if found == nil {
            // No CDDA mount and nothing found — nothing more to check.
        } else {
            // No CDDA mount but something *was* found: only the fallback can
            // have done that, and only with the drive reporting media.
            #expect(found?.route == .shape)
            #expect(Diagnostics.mediaType(Diagnostics.drutilStatus()) != nil)
        }
    }

    /// The empty-drive refusal, on this machine's real `drutil`, whichever way
    /// it answers. With no disc in there is nothing to find; with one in there
    /// is — and either way the finder and the drive tell the same story.
    @Test func theRealDriveAndTheFinderTellTheSameStory() {
        let status = Diagnostics.drutilStatus()
        let hasMedia = Diagnostics.mediaType(status) != nil
        let found = DiscFinder.find()
        if !hasMedia {
            // Nothing in the drive. The only way `find` may still answer is a
            // stale `cddafs` mount, which is a contradiction worth seeing.
            let cdda = DiscFinder.MountTable.parse(DiscFinder.mountOutput() ?? "")
                .contains { $0.isCDDA }
            #expect(found == nil || cdda)
        }
    }
}
