import Foundation

/// The disc in the drive, if there is one. §1.3 — `find_cd` (`player:974`).
///
/// **Nothing in here opens the device.** It reads the kernel's mount table and
/// `drutil status`, both of which are answers *about* the drive rather than
/// conversations with it, and that is not a stylistic preference — it is the
/// whole reason this can run on every scan and every rescan without
/// consequence. The things that do open the device are covered by the ordering
/// rule below.
///
/// Two routes to the same answer, tried in the script's order:
///
/// 1. **A `cddafs` mount.** macOS mounts an audio CD with the CDDA filesystem
///    and nothing else on the machine uses it, so this is the kernel telling
///    you outright. When it answers, nothing else is consulted — not even
///    `drutil`.
/// 2. **A `/Volumes` entry that looks like one**, but only once `drutil` has
///    confirmed there is media in the drive, and — **D17** — only if that
///    volume's backing device is the node `drutil` named.
public enum DiscFinder {

    /// Everything this asks the machine, as closures, so every branch below is
    /// reachable from the suite with no disc, no drive and no `/Volumes`.
    /// Same seam as §11's `Diagnostics.Probes` and for the same reason.
    public struct Probes: Sendable {
        /// `drutil status`, whole — parsed here so the suite can hand over a
        /// recorded one. **Called lazily**: the `cddafs` route never asks it,
        /// exactly as `find_cd` never reaches `optical_media` when the mount
        /// table answers first (`player:994`).
        public var drutil: @Sendable () -> String?
        /// `mount`, whole.
        public var mount: @Sendable () -> String?
        /// `/Volumes/*`, directories only, in byte order — the shell glob.
        public var volumes: @Sendable () -> [URL]
        /// `ls "$v"` — one level, names only, in the order `ls` gives them.
        public var listing: @Sendable (URL) -> [String]
        /// Whether a mount point is a directory that exists (`[ -d "$mp" ]`,
        /// `player:990`).
        public var isDirectory: @Sendable (URL) -> Bool
        /// `command -v drutil` (`player:976`).
        public var hasDrutil: @Sendable () -> Bool

        public init(
            drutil: @escaping @Sendable () -> String? = Diagnostics.drutilStatus,
            mount: @escaping @Sendable () -> String? = DiscFinder.mountOutput,
            volumes: @escaping @Sendable () -> [URL] = DiscFinder.volumesGlob,
            listing: @escaping @Sendable (URL) -> [String] = DiscFinder.directoryListing,
            isDirectory: @escaping @Sendable (URL) -> Bool = DiscFinder.directoryExists,
            hasDrutil: @escaping @Sendable () -> Bool = DiscFinder.drutilPresent
        ) {
            self.drutil = drutil
            self.mount = mount
            self.volumes = volumes
            self.listing = listing
            self.isDirectory = isDirectory
            self.hasDrutil = hasDrutil
        }
    }

    /// What was found, and how — because "how" is the difference between an
    /// answer from the kernel and an answer from a directory listing, and §17
    /// wants to be able to say which one you got.
    public struct Found: Sendable, Equatable {
        /// The mount point. `CD_VOLUME`.
        public let volume: URL
        /// The backing device node, where the mount table named one.
        public let device: String?
        public let route: Route
        /// **D17.** True when `drutil` named a device node and this volume's
        /// backing device is it. False on the `cddafs` route (which needs no
        /// such confirmation) and in the degraded scan where `drutil` named
        /// nothing.
        public let deviceConfirmed: Bool

        public enum Route: String, Sendable, Equatable {
            /// The kernel said so.
            case cddafs
            /// It looked like one, and the drive agreed there was a disc.
            case shape
        }

        public init(volume: URL, device: String?, route: Route, deviceConfirmed: Bool) {
            self.volume = volume
            self.device = device
            self.route = route
            self.deviceConfirmed = deviceConfirmed
        }
    }

    // MARK: - The search

    /// `find_cd` (`player:974`).
    public static func find(_ probes: Probes = Probes()) -> Found? {
        let table = MountTable.parse(probes.mount() ?? "")

        // 1. The kernel's answer. Nothing else is asked when this one lands.
        for entry in table where entry.isCDDA {
            guard probes.isDirectory(entry.mountPoint) else { continue }
            return Found(
                volume: entry.mountPoint, device: entry.device,
                route: .cddafs, deviceConfirmed: false
            )
        }

        // 2. **`drutil` before the `/Volumes` scan, and this is where the
        //    ordering earns itself.** A directory listing cannot tell an album
        //    from an external drive of field recordings; the drive can. Without
        //    asking it, that drive gets announced as "in the drive" and then has
        //    CD-Text and MusicBrainz answers *about the disc* written over its
        //    tracks (`player:1000`).
        guard probes.hasDrutil() else { return nil }
        let status = probes.drutil()
        guard Diagnostics.mediaType(status) != nil else { return nil }
        let node = Diagnostics.mediaDevice(status)

        for volume in probes.volumes() {
            let names = probes.listing(volume)
            let count = aiffCount(names)
            // The script's own first guard: no AIFFs at all and neither test
            // below is even reached (`player:1005`).
            guard count > 0 else { continue }

            // **D17, and it goes here — after the count, before the shape.**
            // The shape test below stays exactly as `player` has it; this is a
            // second condition, not a replacement. Where drutil named no device
            // there is nothing to check against, and the scan runs on
            // undefended — degraded, not refused, per §17.
            if let node {
                guard let device = table.device(for: volume),
                    Self.device(device, belongsTo: node)
                else { continue }
            }

            if hasAudioTrack(names) {
                return Found(
                    volume: volume, device: table.device(for: volume),
                    route: .shape, deviceConfirmed: node != nil
                )
            }
            if count >= 2 {
                return Found(
                    volume: volume, device: table.device(for: volume),
                    route: .shape, deviceConfirmed: node != nil
                )
            }
        }
        return nil
    }

    // MARK: - The tests a volume has to pass

    /// `grep -ic '\.aiff\?$'` (`player:1006`) — a name ending `.aif` or `.aiff`,
    /// case-insensitively.
    ///
    /// **Deliberately not `AudioFiles.extensions`, and this is the one place
    /// that distinction matters.** D18 is about *counting* a disc's tracks for
    /// the picker row, where one definition of audio everywhere is right. This
    /// is about *identifying* something as a disc, and widening it would make
    /// any folder of mp3s on an external drive answer to "is there a CD in the
    /// drive". A CDDA mount is AIFF; the question is what a disc looks like, not
    /// what is playable.
    static func aiffCount(_ names: [String]) -> Int {
        names.filter { name in
            let lower = name.lowercased()
            return lower.hasSuffix(".aif") || lower.hasSuffix(".aiff")
        }.count
    }

    /// `qgrep -i 'Audio Track'` over the listing (`player:1007`) — anywhere in
    /// any name, not just at the front.
    static func hasAudioTrack(_ names: [String]) -> Bool {
        names.contains { $0.range(of: "Audio Track", options: .caseInsensitive) != nil }
    }

    /// **D17's comparison, and the trap in it.** `drutil` names the whole disk —
    /// `/dev/disk10` — and a mount may be a slice of it, `/dev/disk10s1`. So a
    /// device belongs to the node if it *is* the node or is one of its slices.
    ///
    /// Plain prefix matching is wrong and wrong in the direction that matters:
    /// `/dev/disk1` is a prefix of `/dev/disk10`, so an unrelated internal
    /// volume would confirm itself against the disc in the drive. The slice
    /// suffix has to be `s` followed by digits.
    ///
    /// Observed on this machine: a CDDA mount is the whole-disk node itself —
    /// `/dev/disk10 on /Volumes/Deluxe (cddafs, …)` against `drutil`'s
    /// `Name: /dev/disk10` — so the equality case is the one a real audio CD
    /// takes. The slice case is for a disc that mounted some other way, which is
    /// exactly the fallback this gate defends.
    static func device(_ device: String, belongsTo node: String) -> Bool {
        if device == node { return true }
        guard device.hasPrefix(node) else { return false }
        let suffix = device.dropFirst(node.count)
        guard suffix.hasPrefix("s") else { return false }
        let digits = suffix.dropFirst()
        return !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }

    // MARK: - The mount table

    /// One line of `mount` output, split the way `find_cd` splits it.
    public struct MountEntry: Sendable, Equatable {
        public let device: String
        public let mountPoint: URL
        /// What was between the last ` (` and the end of the line.
        public let options: String

        /// `cddafs,*` or `cddafs)*` (`player:989`) — the filesystem is the first
        /// thing in the bracket, and it has to be the whole word.
        public var isCDDA: Bool {
            options == "cddafs" || options.hasPrefix("cddafs,") || options.hasPrefix("cddafs)")
        }
    }

    public enum MountTable {

        /// **The two splits, and why each is where it is** (`player:985`).
        ///
        /// The device comes off the **first** ` on `, because a device node has
        /// no spaces in it — so the front of the line is exact however strange
        /// the volume name is.
        ///
        /// The options come off the **last** ` (`, because a volume name may
        /// contain brackets and the filesystem list is always last. This is the
        /// rule that keeps `Live (Remastered)` its own name, and it is not
        /// hypothetical padding: this machine mounts `/dev/disk5s2 on
        /// /Volumes/My Passport (exfat, …)`, whose *space* would break a naive
        /// field split just as surely.
        public static func parse(_ output: String) -> [MountEntry] {
            var entries: [MountEntry] = []
            for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
                let text = String(line)
                guard let onRange = text.range(of: " on ") else { continue }
                let device = String(text[text.startIndex..<onRange.lowerBound])
                let rest = String(text[onRange.upperBound...])

                // No bracket at all: the script's parameter expansions both
                // leave `rest` untouched, the `cddafs` case then fails, and the
                // line is skipped. Same outcome here, arrived at the same way.
                guard let bracket = rest.range(of: " (", options: .backwards) else {
                    entries.append(
                        MountEntry(
                            device: device,
                            mountPoint: URL(fileURLWithPath: rest),
                            options: rest
                        )
                    )
                    continue
                }
                let mountPoint = String(rest[rest.startIndex..<bracket.lowerBound])
                let options = String(rest[bracket.upperBound...])
                entries.append(
                    MountEntry(
                        device: device,
                        mountPoint: URL(fileURLWithPath: mountPoint),
                        options: options
                    )
                )
            }
            return entries
        }
    }

    // MARK: - The default probes

    public static func drutilPresent() -> Bool {
        Tooling.locate("drutil") != nil
    }

    public static func mountOutput() -> String? {
        guard let mount = Tooling.locate("mount") else { return nil }
        return Tooling.output(mount, [])
    }

    public static func volumesGlob() -> [URL] {
        let volumes = URL(fileURLWithPath: "/Volumes")
        guard
            let children = try? FileManager.default.contentsOfDirectory(
                at: volumes, includingPropertiesForKeys: [.isDirectoryKey], options: []
            )
        else { return [] }
        return
            children
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .sorted {
                AudioFiles.byteOrder($0.lastPathComponent, $1.lastPathComponent) == .orderedAscending
            }
    }

    public static func directoryListing(_ url: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
    }

    public static func directoryExists(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
}

extension DiscFinder.MountTable {
    /// The device backing a mount point, or nil where nothing mounted there.
    static func device(for volume: URL, in entries: [DiscFinder.MountEntry]) -> String? {
        entries.first { $0.mountPoint.path == volume.path }?.device
    }
}

extension Array where Element == DiscFinder.MountEntry {
    func device(for volume: URL) -> String? {
        first { $0.mountPoint.path == volume.path }?.device
    }
}
