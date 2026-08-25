import Foundation

/// §1 — opening what the picker or the command line handed us.
///
/// Three paths: a folder is read directly, a zip is unpacked into scratch
/// first, and a disc throws until §1.3 exists.
public enum SourceOpener {

    /// What came out of opening a source: the record, where it came from, how
    /// its titles were sourced, the directory it lives in (for the sleeve), and
    /// the scratch directory if one was made.
    public struct Opened: Sendable {
        public let record: Record
        public let source: SourceKind
        public let titleSource: TitleSource
        public let directory: URL
        public let scratch: Scratch?
    }

    public enum Failure: Error, CustomStringConvertible {
        case notFound(path: String)
        case notASource(path: String)
        case discNotImplemented

        public var description: String {
            switch self {
            case .notFound(let path):
                "\(path): no such file or directory"
            case .notASource(let path):
                "\(path): not a zip or a folder"
            case .discNotImplemented:
                "disc sources are not yet implemented"
            }
        }
    }

    /// Resolve a path from the command line to a URL and a source kind.
    public static func resolve(path: String) throws -> (url: URL, kind: SourceKind) {
        let url = URL(fileURLWithPath: path)
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            throw Failure.notFound(path: path)
        }
        if url.pathExtension.lowercased() == "zip" {
            return (url, .zip)
        }
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return (url, .folder)
        }
        throw Failure.notASource(path: path)
    }

    /// Open a source and return the record it contains.
    public static func open(
        url: URL,
        kind: SourceKind,
        progress: (@Sendable (String) -> Void)? = nil
    ) async throws -> Opened {
        switch kind {
        case .folder:
            return try await openFolder(url, progress: progress)
        case .zip:
            return try await openZip(url, progress: progress)
        case .disc:
            throw Failure.discNotImplemented
        }
    }

    private static func openFolder(
        _ url: URL,
        progress: (@Sendable (String) -> Void)?
    ) async throws -> Opened {
        let label = url.lastPathComponent
        let record = try await Record.read(
            directory: url, sourceLabel: label,
            progress: { p in
                progress?("READING · \(p.percent)% · \(p.filename)")
            }
        )
        return Opened(
            record: record, source: .folder, titleSource: .tags,
            directory: url, scratch: nil
        )
    }

    private static func openZip(
        _ url: URL,
        progress: (@Sendable (String) -> Void)?
    ) async throws -> Opened {
        let label = url.lastPathComponent
        progress?("OPENING · \(label)")

        let scratch = try Scratch.open()

        progress?("UNPACKING · \(label)")
        let result = try Unpacker.unpack(
            zip: url, into: scratch.album, label: label,
            progress: { p in
                progress?("UNPACKING · \(p.percent)% · \(p.name)")
            }
        )

        let discs = result.directories.count > 1
        let record = try await Record.read(
            directory: scratch.album, sourceLabel: label,
            discsFromSubdirectories: discs,
            progress: { p in
                progress?("READING · \(p.percent)% · \(p.filename)")
            }
        )
        return Opened(
            record: record, source: .zip, titleSource: .tags,
            directory: scratch.album, scratch: scratch
        )
    }
}
