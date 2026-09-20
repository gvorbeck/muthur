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

/// **D98** — the naming policy against a real volume of each kind.
///
/// This is the tier the rule was got wrong in twice from a chair. D96 kept the
/// Win32 characters on the reasoning that removing them would be a guess; the
/// 0.8.0 notes then claimed exFAT would refuse them. **Neither was measured,
/// and the measurement says macOS's exFAT takes every one of them** — so the
/// rule that shipped is about portability rather than legality, and this is
/// what keeps that claim honest.
@Suite("D98 — names against the volumes that are mounted")
struct PortableNamingTests {

    /// A directory on `root` that cleans up after itself, or nil where `root`
    /// will not take one. Named with a dot and a UUID so it is invisible and
    /// cannot collide with anything of the user's.
    final class Scratch {
        let url: URL
        init?(on root: URL) {
            let dir = root.appending(path: ".muthur-naming-\(UUID().uuidString)")
            guard (try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)) != nil
            else { return nil }
            url = dir
        }
        deinit { try? FileManager.default.removeItem(at: url) }
    }

    /// Every mounted volume, with what the kernel calls its filesystem.
    static var mounted: [(URL, Volume)] {
        var found: [(URL, Volume)] = []
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if let v = Volume.at(home) { found.append((home, v)) }
        let volumes = (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for url in volumes {
            if let v = Volume.at(url) { found.append((url, v)) }
        }
        return found
    }

    /// The titles that started this: six Win32 refuses, and three shapes that
    /// are legal everywhere and must survive untouched.
    static let awkward = [
        "Where Is My Mind?", "*Fazer*", "a|b", "a<b>c", #"a"b"#, #"A\\B"#,
        "I’m So Lonesome I Could Cry", "émigré", "AC-DC",
    ]

    @Test("a name made for a volume is a name that volume takes")
    func namesRoundTrip() throws {
        for (root, volume) in PortableNamingTests.mounted {
            // Read-only volumes — a mounted disc, a sealed system volume —
            // have nothing to say here and are not failures.
            guard let scratch = Scratch(on: root) else { continue }
            for title in PortableNamingTests.awkward {
                let name = ImportNames.trackFile(
                    number: 1, title: title, format: .flac, policy: volume.naming)
                let url = scratch.url.appending(path: name)
                do {
                    try Data("x".utf8).write(to: url)
                } catch {
                    let said = "\(volume.filesystem) refused \(name.debugDescription)"
                        + " made for it from \(title.debugDescription)"
                    Issue.record(Comment(rawValue: said))
                    continue
                }
                // Written, listed back byte-exact, and readable. A name that
                // round-trips through the directory is a name that volume took.
                let listed = (try? FileManager.default.contentsOfDirectory(
                    atPath: scratch.url.path)) ?? []
                #expect(
                    listed.contains(name),
                    "\(volume.filesystem): \(name.debugDescription) is not in its own directory")
                #expect((try? Data(contentsOf: url)) != nil)
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    @Test("a portable volume gets names with none of the seven in them")
    func portableVolumesAreClean() throws {
        let portable = PortableNamingTests.mounted.filter { $0.1.wantsPortableNames }
        // Green on a machine with no such volume — that is a fact about the
        // machine, not a failure, and the rules tier covers the arithmetic.
        for (root, volume) in portable {
            for title in PortableNamingTests.awkward {
                let name = ImportNames.trackFile(
                    number: 1, title: title, format: .flac, policy: volume.naming)
                #expect(
                    !name.contains(where: { #"?*|<>"\"#.contains($0) }),
                    "\(volume.filesystem) at \(root.path) got \(name.debugDescription)")
            }
        }
    }

    @Test("a native volume keeps the punctuation, which is the measured half")
    func nativeVolumesKeepThem() {
        let native = PortableNamingTests.mounted.filter { !$0.1.wantsPortableNames }
        for (_, volume) in native {
            #expect(
                ImportNames.trackFile(
                    number: 1, title: "Where Is My Mind?", format: .flac,
                    policy: volume.naming) == "01 - Where Is My Mind?.flac")
        }
    }
}
