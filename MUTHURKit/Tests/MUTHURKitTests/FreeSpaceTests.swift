import Foundation
import Testing

@testable import MUTHURKit

/// `TempSpace.free`, against the volumes this machine actually has mounted.
///
/// **This suite exists because of a bug that only a second filesystem could
/// find.** `free` asked `volumeAvailableCapacityForImportantUsage` and nothing
/// else, which is the right question on APFS and returns **nought** on exFAT —
/// so the first import aimed at an external disk was refused for lack of room
/// on a volume with 505 GB free, and `TempSpace` is shared, so a burn whose
/// `MUTHUR_WORK` pointed anywhere but the boot volume would have been refused
/// the same way.
///
/// Every assertion here is deliberately weak, per `CLAUDE.md`: nothing is
/// claimed about *which* filesystems exist on the machine running this, because
/// that is not something the platform guarantees. What is asserted is the one
/// thing that has to be true of any of them — **if the kernel says a volume has
/// room, `free` must not say it has none.**
@Suite("TempSpace — free space, on whatever is mounted")
struct FreeSpaceTests {

    /// `f_bavail * f_bsize`, the number `df` prints, straight from the kernel.
    /// A second opinion that owes nothing to the URL resource keys under test.
    static func statfsAvailable(_ path: String) -> Int? {
        var buffer = statfs()
        guard statfs(path, &buffer) == 0 else { return nil }
        return Int(buffer.f_bavail) * Int(buffer.f_bsize)
    }

    static func filesystem(_ path: String) -> String? {
        var buffer = statfs()
        guard statfs(path, &buffer) == 0 else { return nil }
        return withUnsafePointer(to: buffer.f_fstypename) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
    }

    /// Every volume worth asking: the home directory, plus whatever is in
    /// `/Volumes`. On a bare machine that is one filesystem; on this one it was
    /// two, and the second is the whole reason this file exists.
    static var candidates: [URL] {
        var urls = [URL(fileURLWithPath: NSHomeDirectory())]
        let volumes = (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        urls.append(contentsOf: volumes)
        return urls
    }

    @Test("a volume the kernel says has room is never reported as having none")
    func agreesWithTheKernel() {
        for url in FreeSpaceTests.candidates {
            guard let kernel = FreeSpaceTests.statfsAvailable(url.path), kernel > 0 else {
                // A full volume, or one that will not answer. Neither is this
                // test's business — `check` is documented not to refuse a
                // volume that will not say.
                continue
            }
            let asked = TempSpace.free(at: url)
            let fs = FreeSpaceTests.filesystem(url.path) ?? "?"
            #expect(
                asked != nil,
                "\(fs) at \(url.path): kernel says \(kernel) bytes, free() said nothing")
            #expect(
                (asked ?? 0) > 0,
                "\(fs) at \(url.path): kernel says \(kernel) bytes, free() said \(asked ?? -1)")
        }
    }

    @Test("a read-only disc is not mistaken for a volume with room")
    func opticalIsHonest() {
        // A mounted audio CD reports nought free, truthfully — and that is the
        // one case where nought is the right answer rather than a filesystem
        // declining to keep the figure. It must not be turned into a positive
        // number by the fallback.
        let mounted = DiscFinder.MountTable.parse(DiscFinder.mountOutput() ?? "")
        for entry in mounted where entry.isCDDA {
            let asked = TempSpace.free(at: entry.mountPoint)
            #expect(
                asked == nil || asked == 0,
                "a disc reported \(asked ?? -1) bytes free")
        }
    }

    @Test("a job is not refused on a volume that has the room for it")
    func doesNotRefuseWrongly() throws {
        // The failure as it actually presented: a 52-minute record, about
        // 300 MB of FLAC, refused against half a terabyte.
        let home = URL(fileURLWithPath: NSHomeDirectory())
        guard let kernel = FreeSpaceTests.statfsAvailable(home.path), kernel > 1_000_000_000
        else { return }
        let plan = try ImportPlan.make(
            record: ImportTests.record(titles: ["A", "B"]),
            destination: home, format: .flac, exists: { _ in false })
        #expect(throws: Never.self) { try plan.checkRoom(in: home) }
    }

    @Test("a path on no volume at all is a shrug, not a refusal")
    func unknownIsNotRefusal() {
        // `check`'s documented posture: the check is a courtesy and the write
        // is the authority.
        let nowhere = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/deeper")
        #expect(TempSpace.free(at: nowhere) == nil)
    }
}
