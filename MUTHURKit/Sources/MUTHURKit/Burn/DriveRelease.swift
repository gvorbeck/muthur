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
/// **The read end borrows the drive; the write end takes it. D80.** §4.2 has the
/// same problem from the other side — cdrtools cannot read a lead-in off a disc
/// macOS has mounted either — and the same three steps solve it, which is why
/// there is a `take`/`giveBack` pair here rather than a second way of finding
/// the drive in `Disc/`. What the two ends do not share is the obligation: a
/// burn unmounts a disc it is about to overwrite and owes it nothing back, while
/// a lookup has to hand the record back the files it is playing from.
///
/// **It is one type and three callers on purpose.** It was written for the burn
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
        /// `diskutil mount <device>`. True where it came back. **D80** — only
        /// the read end ever calls this; a burn has nothing to put back.
        public var mount: @Sendable (String) -> Bool

        public init(
            drutil: @escaping @Sendable () -> String? = Diagnostics.drutilStatus,
            mounts: @escaping @Sendable () -> String? = DiscFinder.mountOutput,
            unmount: @escaping @Sendable (URL) -> Bool = DriveRelease.diskutilUnmount,
            mount: @escaping @Sendable (String) -> Bool = DriveRelease.diskutilMount
        ) {
            self.drutil = drutil
            self.mounts = mounts
            self.unmount = unmount
            self.mount = mount
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
        _ = take()
    }

    // MARK: - Borrowing the drive rather than taking it. D80.

    /// What was unmounted, and therefore what is owed back.
    ///
    /// The **device** and not the mount point, because a mount point is where a
    /// volume was and a device is what it is. `diskutil mount` is given a node;
    /// giving it the old `/Volumes/…` path asks the machine to remount something
    /// that, by then, is not there.
    public struct Taken: Sendable, Equatable {
        public var devices: [String]
        public var isEmpty: Bool { devices.isEmpty }
        public init(devices: [String] = []) { self.devices = devices }
    }

    /// Unmount whatever is on the drive, and remember it.
    ///
    /// `run()` is this with the answer thrown away, which is all a burn wants:
    /// the disc it unmounts is about to be written over, and putting the old
    /// table of contents back would be putting back something that is no longer
    /// true.
    @discardableResult
    public func take() -> Taken {
        guard let node = Diagnostics.mediaDevice(probes.drutil()),
            let mounts = probes.mounts()
        else { return Taken() }
        var taken = Taken()
        for entry in DriveRelease.entries(of: node, in: DiscFinder.MountTable.parse(mounts)) {
            guard probes.unmount(entry.mountPoint) else { continue }
            taken.devices.append(entry.device)
        }
        return taken
    }

    /// Put back everything `take` got. **False if any of it stayed off.**
    ///
    /// This one has a return value where the unmount deliberately does not, and
    /// the asymmetry is the whole of D80. An unmount that fails costs a lookup:
    /// cdrtools refuses, §4 falls through, and the panel is a track list short
    /// of ideal. A *remount* that fails costs the disc — it is gone from Finder,
    /// gone from the record's own file URLs, and nothing on screen says why. The
    /// program took it; the program says so when it cannot give it back.
    public func giveBack(_ taken: Taken) -> Bool {
        var whole = true
        for device in taken.devices where !probes.mount(device) {
            whole = false
        }
        return whole
    }

    /// Unmount, do the thing, put it back — and say whether the disc came home.
    ///
    /// One function because the two halves must not be able to drift apart: any
    /// path that takes the drive has to reach the giving back, including the one
    /// where the work in the middle threw.
    public func around<T>(_ body: () async -> T) async -> (value: T, remounted: Bool) {
        let taken = take()
        let value = await body()
        // Nothing was taken, so nothing is owed — and *not* a remount failure.
        guard !taken.isEmpty else { return (value, true) }
        return (value, giveBack(taken))
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
        entries(of: node, in: mounts).map(\.mountPoint)
    }

    /// The same rule, keeping the device as well — D80 needs it to remount.
    static func entries(of node: String, in mounts: [DiscFinder.MountEntry])
        -> [DiscFinder.MountEntry]
    {
        mounts.filter { DiscFinder.device($0.device, belongsTo: node) }
    }

    public static let diskutilUnmount: @Sendable (URL) -> Bool = { volume in
        guard let diskutil = Tooling.locate("diskutil") else { return false }
        return Tooling.run(diskutil, ["unmount", volume.path])?.status == 0
    }

    /// **D80.** `diskutil mount <device>` — observed to bring `/Volumes/Audio CD`
    /// straight back on the disc in the drive, under its own name, with the
    /// `.aiff` files and `.TOC.plist` where §3 and §4.3 left them.
    public static let diskutilMount: @Sendable (String) -> Bool = { device in
        guard let diskutil = Tooling.locate("diskutil") else { return false }
        return Tooling.run(diskutil, ["mount", device])?.status == 0
    }

    /// The whole of it as one closure, for the seams that want a step and not an
    /// object — `MediaCheck.Probes.release` is the only one so far.
    public static let standard: @Sendable () -> Void = { DriveRelease().run() }
}
