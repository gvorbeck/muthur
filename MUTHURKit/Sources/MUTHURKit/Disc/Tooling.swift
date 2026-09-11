import Foundation

/// Finding and running the cdrtools binaries. §4.2, §4.3.
///
/// Everything the disc chain needs from outside is a command-line tool the user
/// installed with Homebrew, and every one of them is optional: `command -v … ||
/// return 1` is the first line of both `cd_text` and `mb_discid`. A machine
/// without them has a smaller set of things it can tell you about a disc, which
/// is §11's business to report and nothing else's to complain about.
enum Tooling {

    /// Where the tool is, or nil.
    ///
    /// A GUI app is not launched from a shell and does not inherit a shell's
    /// PATH, so the two places Homebrew puts things have to be named outright —
    /// the same problem, and the same answer, as `FFprobeMetadataReader`.
    static func locate(
        _ name: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        var directories = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        directories.append(contentsOf: ["/opt/homebrew/bin", "/usr/local/bin"])
        for directory in directories where !directory.isEmpty {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Run it and take everything it said.
    ///
    /// **stdout and stderr together**, because cdrtools prints the interesting
    /// half of its output to stderr and the script captures both (`2>&1` at
    /// `player:2072`). Reading CD-Text off a drive that decides it has nothing
    /// to say is a blank capture either way.
    ///
    /// The status comes back beside the output because the two callers want
    /// different things from it: `-checkdrive` is asked *whether it worked* and
    /// nothing else, while every capture of CD-Text or a TOC is `|| true` in the
    /// script — cdrecord routinely exits non-zero having printed exactly what
    /// was wanted.
    struct Result {
        let output: String
        let status: Int32
    }

    static func output(_ executable: URL, _ arguments: [String], in directory: URL? = nil)
        -> String?
    {
        run(executable, arguments, in: directory)?.output
    }

    /// `directory` is where the tool is run, for the ones that write beside
    /// themselves rather than to the pipe.
    ///
    /// **cdda2wav is the reason this exists, and only D80 exposed it.** Asked for
    /// `titles` it also drops `audio.cdtext`, `audio.cddb`, `audio.cdindex` and
    /// an `audio_NN.inf` per track into the current directory — thirteen tracks,
    /// seventeen files. Nothing ever saw it because until the disc was unmounted
    /// cdda2wav failed before it wrote a byte; the first lead-in it managed to
    /// read, it littered the repository it was run from. A tool that succeeds
    /// has to have somewhere to succeed *into*.
    static func run(_ executable: URL, _ arguments: [String], in directory: URL? = nil) -> Result? {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let directory { process.currentDirectoryURL = directory }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        // Read before waiting: a full pipe with nobody reading it is a process
        // that never exits.
        //
        // `readToEnd` answers nil at EOF with nothing before it, and a tool that
        // said nothing is not a tool that failed to run — `ffmpeg -v error` on a
        // conversion that went fine is silent by design. Only a spawn that threw
        // is a nil here; everything else ran and has a status worth having.
        let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        return Result(
            output: String(decoding: data, as: UTF8.self),
            status: process.terminationStatus
        )
    }
}
