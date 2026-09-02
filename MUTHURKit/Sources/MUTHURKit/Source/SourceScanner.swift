import Foundation

/// §1.2 — finding what there is to play.
///
/// `scan_sources()` (`player:1036`): for each directory in the search path,
/// find the loose zips and the immediate subdirectories that contain audio.
/// The scan is one level deep — the picker offers albums, not every folder on
/// the disk.
public enum SourceScanner {

    /// `PLAYER_DIRS` → `MUTHUR_DIRS`, colon-separated, default
    /// `~/Music:~/Downloads` (`player:1023`).
    ///
    /// D13's naming pattern: the app's own variable first, the script's behind
    /// it for somebody who has had it exported for years, and a sensible default
    /// behind both.
    public static func defaultDirectories(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) -> [URL] {
        let raw = nonEmpty(environment["MUTHUR_DIRS"])
            ?? nonEmpty(environment["PLAYER_DIRS"])
            ?? "~/Music:~/Downloads"
        return raw.split(separator: ":").compactMap { segment in
            let path = String(segment)
            if path.hasPrefix("~/") || path == "~" {
                return home.appending(path: String(path.dropFirst(2)))
            }
            return URL(fileURLWithPath: path)
        }
    }

    /// Scan the given directories for playable sources.
    ///
    /// Per directory: `.zip`/`.ZIP` files at maxdepth 1, then immediate
    /// subdirectories that contain audio, both sorted `LC_ALL=C`
    /// (`player:1036`).
    ///
    /// **Both kinds are gated on containing audio (D47).** `scan_sources` gates
    /// the folders and not the zips, because it has no way to look inside one
    /// without unpacking it — so every `*.zip` in `~/Downloads` is offered as a
    /// record whatever is in it. §2.2 reads a central directory where it lies,
    /// which makes the folder rule askable of an archive for the price of two
    /// small reads. Closing the inconsistency, not diverging from it.
    ///
    /// **The disc goes first, above every directory**, because `scan_sources`
    /// appends it before it walks the search path at all (`player:1018`). Not a
    /// ranking — it is the row you almost certainly came for, and the script
    /// puts it where your eye already is.
    public static func scan(
        directories: [URL],
        disc: DiscFinder.Found? = nil,
        fileManager: FileManager = .default
    ) -> [PickerEntry] {
        var entries: [PickerEntry] = []

        if let disc {
            entries.append(discEntry(disc))
        }

        for directory in directories {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            guard
                let children = try? fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )
            else { continue }

            var zips: [(url: URL, name: String)] = []
            var folders: [(url: URL, name: String, count: Int)] = []

            for child in children {
                let values = try? child.resourceValues(
                    forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]
                )
                let ext = child.pathExtension.lowercased()

                if values?.isRegularFile == true, ext == "zip" {
                    zips.append((child, child.lastPathComponent))
                } else if values?.isDirectory == true {
                    let count = AudioFiles.scan(child, maxDepth: 2).count
                    if count > 0 {
                        folders.append((child, child.lastPathComponent, count))
                    }
                }
            }

            // LC_ALL=C sort — byte order, per directory (`player:1073`).
            zips.sort { AudioFiles.byteOrder($0.name, $1.name) == .orderedAscending }
            folders.sort { AudioFiles.byteOrder($0.name, $1.name) == .orderedAscending }

            // D47 — the folder rule, applied to the archives. Sorted first so
            // that dropping rows cannot change the order of the ones that stay.
            zips = holdingAudio(zips)

            // Zips before folders, within each directory.
            for zip in zips {
                let size = fileSize(zip.url, fileManager: fileManager)
                entries.append(
                    PickerEntry(
                        kind: .zip, url: zip.url,
                        label: zip.name,
                        detail: PickerEntry.zipDetail(bytes: size)
                    )
                )
            }
            for folder in folders {
                entries.append(
                    PickerEntry(
                        kind: .folder, url: folder.url,
                        label: folder.name,
                        detail: PickerEntry.folderDetail(trackCount: folder.count)
                    )
                )
            }
        }

        return entries
    }

    /// The disc's row. `basename "$CD_VOLUME"` for the label (`player:1020`),
    /// and the count is **D18's**: `AudioFiles`, one definition of audio
    /// everywhere, rather than the script's `grep -ic '\.aiff\?$'`.
    ///
    /// One level deep, because the script counts with `ls` and not with `find`
    /// (`player:1019`) — and because a CDDA mount is flat, so anything nested
    /// under one is not a track.
    ///
    /// **The count and the detection use different definitions on purpose.**
    /// `DiscFinder.aiffCount` asks "does this look like a disc" and stays narrow;
    /// this asks "how many tracks does the disc have" and stays wide. D18 is
    /// only ever about the second.
    static func discEntry(_ disc: DiscFinder.Found) -> PickerEntry {
        let count = AudioFiles.scan(disc.volume, maxDepth: 1).count
        return PickerEntry(
            kind: .disc, url: disc.volume,
            label: disc.volume.lastPathComponent,
            detail: PickerEntry.discDetail(trackCount: count)
        )
    }

    // MARK: - Which archives are records (D47)

    /// How long the archives in one directory get, between them, to say whether
    /// they hold audio.
    ///
    /// The read itself is two `pread`s of a few kilobytes and finishes in
    /// microseconds, so this budget is never spent on work — it is spent on a
    /// mount that has stopped answering. A `pread` into a stalled network volume
    /// or a sleeping external disk cannot be cancelled from here, so what the
    /// deadline buys is the right to **stop waiting** for one and go on drawing
    /// the picker without it. That is the trade this makes and it is the honest
    /// way round: a picker that is missing a row you can still reach with
    /// `BROWSE` (§14) beats a picker that never appears.
    static let zipProbeBudget: TimeInterval = 1

    /// The archives that hold something to play, in the order they came in.
    ///
    /// **Probed together rather than one after another**, so the budget above is
    /// wall-clock for the whole directory instead of a per-archive cost that
    /// multiplies by however many zips are sitting in `~/Downloads`. One archive
    /// on a stalled mount then loses only itself.
    ///
    /// An archive that cannot be opened at all — truncated, not a zip under a
    /// `.zip` name, encrypted so hard the directory will not read — comes back
    /// `false` and is not offered. The picker's job is to list what will play,
    /// and this is what the folder rows have always done with a directory that
    /// turns out to hold nothing: they do not appear either.
    private static func holdingAudio(
        _ zips: [(url: URL, name: String)]
    ) -> [(url: URL, name: String)] {
        guard !zips.isEmpty else { return [] }

        let answers = Answers(count: zips.count)
        let group = DispatchGroup()
        for (index, zip) in zips.enumerated() {
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                answers.settle(index, (try? ZipArchive(url: zip.url))?.holdsAudio ?? false)
            }
        }
        // The return value is deliberately dropped: a timeout is not an error
        // here, it is the answer for whichever archives have not given one.
        _ = group.wait(timeout: .now() + zipProbeBudget)

        let settled = answers.snapshot()
        return zips.enumerated().filter { settled[$0.offset] == true }.map(\.element)
    }

    /// Somewhere for the probes to put their answers that outlives the wait.
    ///
    /// A probe that misses the deadline goes on running — there is no way to
    /// stop it — and writes here after `snapshot` has already been taken. The
    /// lock is what makes that harmless rather than a race: the late write lands
    /// in a box nobody is reading any more.
    private final class Answers: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [Bool?]

        init(count: Int) { values = Array(repeating: nil, count: count) }

        func settle(_ index: Int, _ value: Bool) {
            lock.lock()
            defer { lock.unlock() }
            values[index] = value
        }

        func snapshot() -> [Bool?] {
            lock.lock()
            defer { lock.unlock() }
            return values
        }
    }

    private static func fileSize(_ url: URL, fileManager: FileManager) -> UInt64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(values?.fileSize ?? 0)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
