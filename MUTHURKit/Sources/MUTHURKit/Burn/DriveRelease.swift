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
/// **The write end does not have the read end's race, and it is worth saying
/// why, because the reason is not the eject.** What tears the device node down
/// is the *exclusive open*, not the unmount: watched here, `diskutil unmount`
/// left `/dev/disk7` present and the disc off for a full twelve seconds with
/// `diskarbitrationd` showing no interest in either. So `run()`'s unmount holds
/// until cdrecord opens the drive, however long the two are apart, and a burn
/// that owes nothing back never asks the question `giveBack` had wrong. The one
/// exclusive open ahead of a write is `media_check`'s ATIP read, and the minutes
/// of conversion between it and the burn are far more than the second the node
/// takes to come back — by which time `diskarbitrationd` has re-mounted the disc
/// and `Burner.write`'s own release unmounts it again, which is the loop working
/// as written rather than in spite of itself.
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
        /// `diskutil mount <device>`. **D80** — only the read end ever calls
        /// this; a burn has nothing to put back.
        ///
        /// Its answer is not the answer. Whether the disc is back is read off
        /// the mount table afterwards, because on this machine the disc mostly
        /// comes back without being asked. See `giveBack`.
        public var mount: @Sendable (String) -> Bool
        /// The gap between one look at the mount table and the next, while
        /// `giveBack` waits. A closure so the suite can spend none — the same
        /// seam, and the same reason, as `MediaCheck.Probes.pause`.
        public var pause: @Sendable (Double) -> Void

        public init(
            drutil: @escaping @Sendable () -> String? = Diagnostics.drutilStatus,
            mounts: @escaping @Sendable () -> String? = DiscFinder.mountOutput,
            unmount: @escaping @Sendable (URL) -> Bool = DriveRelease.diskutilUnmount,
            mount: @escaping @Sendable (String) -> Bool = DriveRelease.diskutilMount,
            pause: @escaping @Sendable (Double) -> Void = { Thread.sleep(forTimeInterval: $0) }
        ) {
            self.drutil = drutil
            self.mounts = mounts
            self.unmount = unmount
            self.mount = mount
            self.pause = pause
        }
    }

    public var probes: Probes

    /// How long `giveBack` will wait for the disc, in seconds.
    ///
    /// **A bound over an observation, and not a promise the platform made.**
    /// Timed on this drive with the disc in it: the node was gone the instant
    /// `cdda2wav` exited and back at 1.03–1.08 s, and `diskarbitrationd` had the
    /// volume mounted again at 1.29–1.39 s, seven runs, every one of them inside
    /// a tenth of a second of the last. Five seconds is roughly three and a half
    /// times the slowest of those, which is the headroom seven readings off one
    /// drive can honestly carry.
    ///
    /// It is only ever spent on a disc that is genuinely not coming back: the
    /// loop returns the moment the mount table says the volume is there.
    public var patience: Double

    /// A fifth of a second between looks. Small enough that the ordinary case
    /// costs about what the disc costs, large enough that a five-second wait is
    /// twenty-five looks and not a spin.
    public static let step: Double = 0.2

    public init(probes: Probes = Probes(), patience: Double = 5) {
        self.probes = probes
        self.patience = patience
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
    /// The **device** and not the mount point, because `diskutil mount` is given
    /// a node: handing it the old `/Volumes/…` path asks the machine to remount
    /// something that, by then, is not there.
    ///
    /// **That is an argument about what `diskutil` takes, and it used to be
    /// written here as an argument about which of the two lasts. It is not.** On
    /// this drive the node is the transient one: an exclusive open makes the
    /// kernel tear it down and re-enumerate, so `/dev/disk7` is *missing* for
    /// about a second after `cdda2wav` exits, while `/Volumes/Audio CD` comes
    /// back under exactly that name every time. So this is the right string to
    /// ask with and the wrong thing to wait on, which is why `giveBack` waits on
    /// the mount table instead.
    ///
    /// Seven runs put the same `/dev/disk7` back each time. Nothing is built on
    /// that — a re-enumeration is free to pick another number, and the check
    /// that decides the outcome re-reads the node from `drutil` rather than
    /// trusting this one.
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

    /// How the borrow ended. **D80.**
    ///
    /// Three cases and not a `Bool`, because the two ways of not warning are not
    /// the same thing and folding them together is what made the flag lie in the
    /// quiet direction: a borrow that never took the disc used to report the
    /// same `true` as a borrow that got it back, so a second read on a disc the
    /// first read had lost said the disc was fine.
    public enum Outcome: Sendable, Equatable {
        /// Nothing was mounted when we looked, so nothing was moved and nothing
        /// is owed. **Not the same as `back`** — it is *we did not check*, and
        /// the program has no way to tell a disc the user unmounted from one an
        /// earlier borrow lost. It is not a warning, because a warning here
        /// would fire on every machine whose disc somebody else had put away.
        case nothingTaken
        /// A volume is on the drive's node again. Whose request put it there is
        /// not asked and cannot be told: on this machine `diskarbitrationd`
        /// mostly gets there first, and the user's question is whether the disc
        /// is back, not which process it came back for.
        case back
        /// It was taken, the patience ran out, and the drive still has no volume
        /// on it. The one outcome the user cannot diagnose from the panel.
        case stillAway
    }

    /// Put the disc back, wait for it, and say whether it is there.
    ///
    /// This one has a return value where the unmount deliberately does not, and
    /// the asymmetry is the whole of D80. An unmount that fails costs a lookup:
    /// cdrtools refuses, §4 falls through, and the panel is a track list short
    /// of ideal. A disc that stays away costs the disc — gone from Finder, gone
    /// from the record's own file URLs, and nothing on screen says why.
    ///
    /// **What it used to do was ask `diskutil mount` once and believe the
    /// answer, and that was wrong twice over.** `cdda2wav`'s exclusive open
    /// makes the kernel tear the device node down and re-enumerate it, so at the
    /// instant the read returns there is no `/dev/disk7` to mount and `diskutil`
    /// says `Failed to find disk`. A second later the node is back; a third of a
    /// second after that `diskarbitrationd` has mounted the volume of its own
    /// accord. So the one call was made in the only window where it could not
    /// work, and the disc it declared lost was on the desktop by the time the
    /// notice was drawn. Every successful read said the disc had gone.
    ///
    /// So it waits, and **it asks the mount table rather than `diskutil`'s exit
    /// status**. Asking still matters — an unmount that nothing re-enumerated
    /// after it is durable, watched here for twelve seconds with the node
    /// present and `diskarbitrationd` uninterested, and that is the shape of a
    /// borrow where the read never got as far as opening the device. But what is
    /// *reported* is the volume, because the volume is the thing the user is
    /// looking for and macOS is entitled to put it back without being asked.
    public func giveBack(_ taken: Taken) -> Outcome {
        guard !taken.isEmpty else { return .nothingTaken }
        var waited = 0.0
        while true {
            switch look() {
            case .mounted:
                return .back
            // Nothing to ask yet. The node the exclusive open took away has not
            // come back, and `diskutil mount` on a device that is not there is
            // the mistake this whole function is a fix for — a third of a second
            // of subprocess to be told what `drutil` just said for less.
            case .noNode:
                break
            case .bare:
                for device in taken.devices { _ = probes.mount(device) }
            }
            guard waited < patience else { break }
            probes.pause(DriveRelease.step)
            waited += DriveRelease.step
        }
        // The last ask has not been looked at yet, and on a node that came back
        // at the end of the patience it is the one that worked.
        return look() == .mounted ? .back : .stillAway
    }

    /// One look at the machine. `take`'s own question, asked the other way
    /// round, and with the answer split where `giveBack` has to act differently.
    ///
    /// Deliberately the same two probes and the same matching rule, so that the
    /// thing being verified is the thing that was taken. The node is re-read
    /// rather than remembered: a re-enumeration is free to hand the drive a new
    /// number, and a disc that came home under a different one is still home.
    enum Look: Equatable {
        /// `drutil` names no media. On this machine that is mostly not an empty
        /// drive — it is the second after an exclusive open, before the device
        /// has re-enumerated.
        case noNode
        /// The node is there with nothing mounted on it. The one state in which
        /// asking for the disc back can do anything.
        case bare
        /// A volume is on the drive's node. Whoever put it there.
        case mounted
    }

    func look() -> Look {
        guard let node = Diagnostics.mediaDevice(probes.drutil()) else { return .noNode }
        guard let mounts = probes.mounts() else { return .bare }
        return DriveRelease.entries(of: node, in: DiscFinder.MountTable.parse(mounts)).isEmpty
            ? .bare : .mounted
    }

    /// Unmount, do the thing, put it back — and say whether the disc came home.
    ///
    /// One function because the two halves must not be able to drift apart: any
    /// path that takes the drive has to reach the giving back, including the one
    /// where the work in the middle threw.
    public func around<T>(_ body: () async -> T) async -> (value: T, disc: Outcome) {
        let taken = take()
        let value = await body()
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
    /// back on the disc in the drive, under its own name, with the `.aiff` files
    /// and `.TOC.plist` where §3 and §4.3 left them, **once the node it names
    /// exists**. Asked in the second after an exclusive open it exits 1 with
    /// `Failed to find disk /dev/disk7`, which is not the drive refusing and not
    /// the disc being gone. `giveBack` is where that second is waited out.
    public static let diskutilMount: @Sendable (String) -> Bool = { device in
        guard let diskutil = Tooling.locate("diskutil") else { return false }
        return Tooling.run(diskutil, ["mount", device])?.status == 0
    }

    /// The whole of it as one closure, for the seams that want a step and not an
    /// object — `MediaCheck.Probes.release` is the only one so far.
    public static let standard: @Sendable () -> Void = { DriveRelease().run() }
}
