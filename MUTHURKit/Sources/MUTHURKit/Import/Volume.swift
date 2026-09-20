import Foundation

/// §21 — what filesystem a destination is on, asked rather than assumed.
///
/// **This exists because of a rule that was written twice and wrong both
/// times** (D98). D96 kept `?`, `*`, `|`, `<`, `>`, `"` and `\` on the grounds
/// that stripping them would be the program guessing the disk was bound for
/// Windows. Then the first real import went to an exFAT drive and the release
/// notes claimed those characters would fail the write there.
///
/// **Both claims were guesses, and the measurement contradicts the second.**
/// Every one of those characters — and a trailing dot, and a trailing space —
/// writes, lists back byte-exact and reads back on macOS's exFAT, exactly as it
/// does on APFS. The Win32 restriction is a restriction in *Windows*, not in
/// the on-disk format, and the macOS driver does not enforce it.
///
/// So the honest rule is neither of the two that were written. It is not about
/// what the kernel refuses, because the kernel refuses nothing here. It is
/// about **what the volume is for**: a disk is formatted exFAT or FAT so that
/// something other than a Mac can read it, and a filename this program writes
/// that Windows cannot open defeats the only reason that format was chosen.
/// That is a fact about the user's intent, published by the filesystem they
/// picked, and it is worth honouring.
public struct Volume: Sendable, Equatable {

    /// `f_fstypename` — `apfs`, `hfs`, `exfat`, `msdos`, `smbfs`, `ntfs`,
    /// `cddafs`, and whatever else this machine has mounted.
    public let filesystem: String

    public init(filesystem: String) {
        self.filesystem = filesystem
    }

    /// Ask the kernel. Nil when the path is on nothing that answers, which is
    /// a path that does not exist.
    public static func at(_ url: URL) -> Volume? {
        var buffer = statfs()
        guard statfs(url.path, &buffer) == 0 else { return nil }
        let name = withUnsafePointer(to: buffer.f_fstypename) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        return Volume(filesystem: name.lowercased())
    }

    /// Whether this volume's whole reason for existing is being readable by
    /// something that is not a Mac.
    ///
    /// **A list and not a guess, and every name on it is a format nobody
    /// chooses for a Mac-only disk.** FAT and exFAT are what a drive is
    /// formatted as when it has to work on Windows too — that is the entire
    /// trade, since both give up permissions, symlinks and journalling to get
    /// it. `ntfs` is Windows' own. `smbfs` is a share whose far end is usually
    /// Windows and which enforces the Win32 rules itself.
    ///
    /// **`apfs` and `hfs` are not on it**, and neither is anything unknown:
    /// where the answer is not one of these, the name is left exactly as the
    /// panel says it, which is D96's rule and is what a Mac-only disk should
    /// get. An unfamiliar filesystem is treated as native rather than as
    /// portable, because guessing *toward* substitution would quietly rename
    /// tracks on a volume nobody said anything about — the mistake D96 made in
    /// the other direction, made in this one.
    public var wantsPortableNames: Bool {
        ["exfat", "msdos", "fat", "fat32", "vfat", "ntfs", "smbfs"].contains(filesystem)
    }

    /// The naming rules a destination on this volume should be written to.
    public var naming: ImportNames.Policy {
        wantsPortableNames ? .portable : .native
    }

    /// The rules for whatever `url` sits on, native where nothing answers.
    ///
    /// Falling back to `.native` rather than to `.portable` is the weak
    /// assertion `CLAUDE.md` asks for: a path that will not say what it is gets
    /// the treatment that changes the fewest characters.
    public static func naming(for url: URL) -> ImportNames.Policy {
        Volume.at(url)?.naming ?? .native
    }
}
