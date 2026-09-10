import Foundation

/// **Getting the drive back off macOS before anything tries to open it. D77.**
///
/// Not in the script, and not optional here. `diskarbitrationd` mounts every
/// audio CD it sees, and a mounted optical device is one cdrtools cannot get
/// exclusive access to — it says so outright, in as many words, and stops:
///
/// ```
/// Warning, 'diskarbitrationd' is running and does not allow us to
/// send SCSI commands to the drive.
/// cdrecord: Unable to get exclusive access to device.
/// ```
///
/// On this drive a *finished dummy write* was enough to cause it. The write
/// leaves a table of contents the kernel believes, macOS puts an `Audio CD` on
/// the desktop for a disc that is still blank, and the next thing to reach for
/// the drive fails on hardware that has done nothing wrong. Observed here: with
/// that mount in place `cdrecord -atip` printed the warning above and read
/// nothing; `diskutil unmount` and the identical command read the ATIP.
///
/// **How reliably a finished write leaves that mount behind is not known**, and
/// nothing here depends on knowing. Three rehearsals through this code left none
/// — but they each began by unmounting, so they are not evidence either way. The
/// unmount is cheap, it is idempotent, and a drive with nothing on it is a
/// no-op; the failure it prevents costs a disc or a minute of somebody's time.
///
/// A burn from a terminal is less likely to meet it: the operator had already
/// dismissed the disc, or was burning the first disc of a session on a machine
/// that had not seen one.
///
/// **It is one type and two callers on purpose.** It was written for the burn
/// and then found to be needed a step earlier: `media_check` reads the ATIP with
/// `cdrecord -atip`, which is the same exclusive open and fails the same way —
/// silently, because the check's answer to a drive that will not say is *go
/// ahead on trust*. So a rehearsal would quietly turn the capacity check off for
/// the rest of the session, which is the one thing that check exists to do. A
/// second implementation of the same three steps would have been a second way of
/// finding the wrong drive.
public struct DriveRelease: Sendable {

    /// Everything it asks of the machine.
    public struct Probes: Sendable {
        /// `drutil status`, read **before** any cdrecord probe. §19's opening
        /// rule holds here as everywhere else.
        public var drutil: @Sendable () -> String?
        /// `mount`, whole.
        public var mounts: @Sendable () -> String?
        /// `diskutil unmount <path>`. True where the volume let go.
        public var unmount: @Sendable (URL) -> Bool

        public init(
            drutil: @escaping @Sendable () -> String? = Diagnostics.drutilStatus,
            mounts: @escaping @Sendable () -> String? = DiscFinder.mountOutput,
            unmount: @escaping @Sendable (URL) -> Bool = DriveRelease.diskutilUnmount
        ) {
            self.drutil = drutil
            self.mounts = mounts
            self.unmount = unmount
        }
    }

    public var probes: Probes

    public init(probes: Probes = Probes()) {
        self.probes = probes
    }

    /// Unmount whatever is sitting on the drive's node.
    ///
    /// Quiet on the way past, deliberately, and it returns nothing anybody has
    /// to act on. Nothing here is a decision about the disc — it is the same
    /// housekeeping a Finder eject is, and a panel that announced it would be
    /// reporting on the operating system rather than on the record. An unmount
    /// that fails is not an error either: cdrecord's own refusal is a better
    /// message than anything guessed in advance of it.
    public func run() {
        guard let node = Diagnostics.mediaDevice(probes.drutil()),
            let mounts = probes.mounts()
        else { return }
        for volume in DriveRelease.volumes(of: node, in: DiscFinder.MountTable.parse(mounts)) {
            _ = probes.unmount(volume)
        }
    }

    /// Every mount point sitting on that device node.
    ///
    /// Plural because nothing promises there is one: a hybrid disc mounts its
    /// data session and its audio session separately, and the rule for what
    /// belongs to a node is `DiscFinder`'s — already written, already tested, and
    /// already careful about `/dev/disk1` being a prefix of `/dev/disk10`.
    ///
    /// The filesystem is not tested. `cddafs` is what an audio CD mounts as and
    /// what §1 looks for, but the thing in the way of an exclusive open is *any*
    /// mount, and refusing to unmount a data session because it was not the
    /// filesystem we expected would leave the burn to fail with a better-informed
    /// message and no disc.
    static func volumes(of node: String, in mounts: [DiscFinder.MountEntry]) -> [URL] {
        mounts
            .filter { DiscFinder.device($0.device, belongsTo: node) }
            .map(\.mountPoint)
    }

    public static let diskutilUnmount: @Sendable (URL) -> Bool = { volume in
        guard let diskutil = Tooling.locate("diskutil") else { return false }
        return Tooling.run(diskutil, ["unmount", volume.path])?.status == 0
    }

    /// The whole of it as one closure, for the seams that want a step and not an
    /// object — `MediaCheck.Probes.release` is the only one so far.
    public static let standard: @Sendable () -> Void = { DriveRelease().run() }
}
