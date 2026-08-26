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
    /// (`player:1036`). The disc stub returns nothing — §1.3.
    public static func scan(
        directories: [URL],
        fileManager: FileManager = .default
    ) -> [PickerEntry] {
        var entries: [PickerEntry] = []

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

    private static func fileSize(_ url: URL, fileManager: FileManager) -> UInt64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(values?.fileSize ?? 0)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
