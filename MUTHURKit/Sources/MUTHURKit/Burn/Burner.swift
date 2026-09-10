import Foundation

/// §20 stage 3b — the drive itself, on the other side of the seam `FakeDrive`
/// has been holding open (`burncd:2599`).
///
/// **It is a swap and nothing else.** The vector is `Cdrecord.write`'s, built
/// exactly as the demo builds it; the panel is `BurnPanel`, filled by the parser
/// that has been drawing `fake_cdrecord`'s lines since stage 3a; the frames go
/// to the same closure. What this adds is a process, a pipe, a log and a clock —
/// the four things the script's pipeline is made of and the stand-in had no need
/// of. Nothing above it moved to let it in.
///
/// The script is the same shape, and says so in one line: `--demo` pipes
/// `fake_cdrecord` into `render` where a burn pipes `cdrecord` into `render`.
/// One `render`, two things upstream of it.
///
/// **Read on the carriage returns, not the newlines.** cdrecord narrates a burn
/// by overwriting one line forty times a second, so its progress arrives as
/// `\r`-terminated chunks with no newline anywhere near them; a reader splitting
/// on `\n` gets one enormous line at the end of the disc and draws nothing for
/// the twelve minutes before it. `read -r -d $'\r'` is what the script does
/// (`burncd:1852`) and this is that, byte for byte — including its last clause,
/// `|| [ -n "$chunk" ]`, which is why the final unterminated chunk is still
/// handed over: it is the one carrying `Fixating...` and every reason a burn had
/// for failing.
public struct Burner: Drive {

    // MARK: - The seam

    /// Everything this asks of the machine, so the parts that are arithmetic can
    /// be checked without a drive. The burn itself cannot be — it is a drive, and
    /// `BurnMaterialTests` is where it is asked.
    public struct Probes: Sendable {
        public var cdrecord: @Sendable () -> URL?
        /// `drutil status`, read **before** cdrecord opens anything. §19's
        /// opening rule holds here as everywhere else.
        public var drutil: @Sendable () -> String?
        /// `mount`, whole.
        public var mounts: @Sendable () -> String?
        /// `diskutil unmount <path>`. True where the volume let go.
        public var unmount: @Sendable (URL) -> Bool

        public init(
            cdrecord: @escaping @Sendable () -> URL? = Burner.installedCdrecord,
            drutil: @escaping @Sendable () -> String? = Diagnostics.drutilStatus,
            mounts: @escaping @Sendable () -> String? = DiscFinder.mountOutput,
            unmount: @escaping @Sendable (URL) -> Bool = Burner.diskutilUnmount
        ) {
            self.cdrecord = cdrecord
            self.drutil = drutil
            self.mounts = mounts
            self.unmount = unmount
        }
    }

    public var probes: Probes

    public init(probes: Probes = Probes()) {
        self.probes = probes
    }

    // MARK: - What went wrong

    public enum Failure: Error, CustomStringConvertible {
        /// No cdrecord on this machine. §11 says so long before here, and a job
        /// that got this far anyway should not die without naming the reason.
        case notInstalled
        /// cdrecord ran and refused. `said` is the tail of its own output, which
        /// is the only place the reason is written down.
        case refused(disc: Int, status: Int32, device: String, said: [String])

        public var description: String {
            switch self {
            case .notInstalled:
                "cdrecord is not installed — brew install cdrtools"
            case .refused(let disc, let status, let device, let said):
                // The script's own three questions, which between them cover
                // every failure this has actually had (`burncd:2643`). The
                // drive's last words go first: they are specific where these are
                // general.
                ([
                    said.isEmpty ? nil : "cdrecord said:",
                    said.isEmpty ? nil : said.map { "  \($0)" }.joined(separator: "\n"),
                    "cdrecord failed on disc \(disc) (exit \(status)), writing to dev=\(device).",
                    "  Wrong drive?              cdrecord -scanbus, then set MUTHUR_DEV.",
                    "  Choked on CD-Text or cue? Burn again without it.",
                    "  Either way, the diagnostics report what this machine supports.",
                ] as [String?]).compactMap { $0 }.joined(separator: "\n")
            }
        }
    }

    // MARK: - The disc's size

    /// The image, in whole megabytes (`total_mb=$(( DATA / 1048576 ))`,
    /// `burncd:2584`).
    ///
    /// The tracks are not consulted and the arrears are not added: that is the
    /// stand-in's business, and the reason `Drive` asks rather than computing it
    /// once for both. A real burn's bar comes up short of 100 all by itself,
    /// because cdrecord rounds every track up to a whole megabyte and the image
    /// does not.
    public func totalMegabytes(bytes: Int, tracks: Int) -> Int {
        bytes / 1_048_576
    }

    // MARK: - The burn

    public func write(
        _ invocation: Cdrecord,
        into panel: inout BurnPanel,
        frame: (BurnPanel) -> Void
    ) throws {
        guard let cdrecord = probes.cdrecord() else { throw Failure.notInstalled }
        releaseTheDrive()

        let log = Cdrecord.logURL(work: invocation.directory, disc: panel.disc)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let logHandle = try? FileHandle(forWritingTo: log)
        defer { try? logHandle?.close() }

        let process = Process()
        process.executableURL = cdrecord
        process.arguments = invocation.arguments
        process.currentDirectoryURL = invocation.directory
        // A burn reads nothing from its terminal, and a cdrecord left holding an
        // inherited stdin is a cdrecord that can block on it.
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        // **One pipe for both.** cdrecord's progress goes to stderr and its
        // summary to stdout, and the script merges them with `2>&1` before the
        // tee — two pipes here would be two orderings of one narration.
        process.standardOutput = pipe
        process.standardError = pipe

        let sink = Sink(log: logHandle)
        pipe.fileHandleForReading.readabilityHandler = { handle in
            sink.receive(handle.availableData)
        }

        do {
            try process.run()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            throw Failure.refused(
                disc: panel.disc, status: -1, device: Burner.device(in: invocation.arguments),
                said: ["could not run \(cdrecord.path): \(error.localizedDescription)"])
        }

        // The panel goes up now and not when the drive first speaks. The lead-in
        // is thirty silent seconds and it is a burn's most anxious half-minute;
        // a panel that waited for a progress line would spend it showing the
        // conversion screen stopped at 95% (`burncd:1834`).
        let started = Date()
        var pending = Data()
        frame(panel)

        // The drive's own words and the panel's clock, one loop rather than two
        // processes and a marker in the stream — the merge the script needs a
        // `scan_ticker` for is a `while` here, and the tick is the same twentieth
        // of a second either way.
        while true {
            let (data, finished) = sink.drain()
            let seconds = Int(Date().timeIntervalSince(started))
            if !data.isEmpty {
                pending.append(data)
                for chunk in Burner.chunks(from: &pending) {
                    panel.receive(chunk, at: seconds)
                }
            }
            panel.tick(at: seconds)
            frame(panel)
            if finished, !process.isRunning { break }
            Thread.sleep(forTimeInterval: Lamp.tick)
        }

        pipe.fileHandleForReading.readabilityHandler = nil
        process.waitUntilExit()

        // `|| [ -n "$chunk" ]`: what cdrecord said after its last carriage
        // return is not junk, it is the end of the burn.
        if !pending.isEmpty {
            panel.receive(
                String(decoding: pending, as: UTF8.self),
                at: Int(Date().timeIntervalSince(started)))
            panel.tick(at: Int(Date().timeIntervalSince(started)))
            frame(panel)
        }

        guard process.terminationStatus == 0 else {
            let said = Burner.lastWords((try? String(contentsOf: log, encoding: .isoLatin1)) ?? "")
            throw Failure.refused(
                disc: panel.disc,
                status: process.terminationStatus,
                device: Burner.device(in: invocation.arguments),
                said: said)
        }
    }

    // MARK: - Getting the drive back off macOS

    /// **Unmount whatever the drive is holding before cdrecord opens it. D77.**
    ///
    /// The reasoning, and the three steps, are `DriveRelease`'s — it is needed a
    /// step earlier than this as well, by the look at the blank, and one
    /// implementation with two callers beats two ways of finding the same drive.
    /// The probes are still the burner's own, so a test can watch what was
    /// unmounted without a drive in the machine.
    func releaseTheDrive() {
        DriveRelease(
            probes: DriveRelease.Probes(
                drutil: probes.drutil, mounts: probes.mounts, unmount: probes.unmount)
        ).run()
    }

    public static let installedCdrecord: @Sendable () -> URL? = {
        Tooling.locate(Cdrecord.program)
    }

    public static let diskutilUnmount: @Sendable (URL) -> Bool = DriveRelease.diskutilUnmount

    // MARK: - Reading the drive

    /// Split what has arrived on carriage returns, leaving the unterminated tail
    /// in the buffer.
    ///
    /// A chunk is what was between two `\r`s, the terminator dropped — which is
    /// what `read -d $'\r'` hands its loop. Newlines inside a chunk are left
    /// alone: cdrecord's last progress line and its closing summary arrive as one
    /// piece, and `BurnPanel.parse` reads that piece by its first three words and
    /// is untroubled by the rest.
    static func chunks(from buffer: inout Data) -> [String] {
        var found: [String] = []
        var rest = buffer[buffer.startIndex...]
        while let index = rest.firstIndex(of: 0x0D) {
            found.append(String(decoding: rest[rest.startIndex..<index], as: UTF8.self))
            rest = rest[rest.index(after: index)...]
        }
        // Rebased, because a slice keeps the offsets of the buffer it came from
        // and the next call would append past them.
        buffer = Data(rest)
        return found
    }

    /// The last of what cdrecord said, for a failure message (`burncd:2637`).
    ///
    /// Carriage returns become line breaks so the overwritten progress is
    /// readable at all, the progress itself is dropped — fifteen lines of
    /// `Track 03: 28 of 31 MB` is fifteen lines saying nothing went wrong — and
    /// what is left is the fifteen that did.
    ///
    /// Split on the scalars and not on the `Character`s, because Swift counts
    /// `\r\n` as *one* grapheme and neither half of it matches `"\r"` or `"\n"`.
    /// cdrecord ends a failing progress line by printing its complaint straight
    /// after the return, so the pair falls exactly where it does most damage:
    /// `Track 01: 3 of 39 MB written …\r\ncdrecord: Input/output error.` stays a
    /// single line, the `MB written` filter throws it away, and the one line
    /// saying why the burn failed goes with it.
    static func lastWords(_ log: String, keep: Int = 15) -> [String] {
        log.unicodeScalars
            .split(whereSeparator: { $0 == "\r" || $0 == "\n" })
            .map { String(String.UnicodeScalarView($0)) }
            .filter { !$0.contains("MB written") && !$0.allSatisfy(\.isWhitespace) }
            .suffix(keep)
    }

    /// The device out of the vector, for the message that names it.
    ///
    /// Read back rather than passed in, because the thing worth printing is what
    /// cdrecord was actually given: a `dev=` that came from `MUTHUR_DEV` and a
    /// `dev=` that came from probing look identical by the time they are an
    /// argument, and it is the argument that failed.
    static func device(in arguments: [String]) -> String {
        for argument in arguments where argument.hasPrefix("dev=") {
            return String(argument.dropFirst("dev=".count))
        }
        return "?"
    }

    // MARK: - The pipe

    /// The reader's side: everything cdrecord has said since the last frame, and
    /// whether it has stopped saying anything.
    ///
    /// `readabilityHandler` runs on a queue of its own, so this is the one place
    /// in the burn where two threads meet and it is a lock and a buffer and
    /// nothing else. The tee happens here rather than in the loop above so the
    /// log is complete even for a burn that ends by the process being killed:
    /// the whole reason the log exists is the failures, and a failure that took
    /// the reader with it would take the evidence too.
    private final class Sink: @unchecked Sendable {
        private let lock = NSLock()
        private var buffer = Data()
        private var finished = false
        private let log: FileHandle?

        init(log: FileHandle?) {
            self.log = log
        }

        func receive(_ data: Data) {
            // An empty read is the pipe's end, which is cdrecord's end.
            guard !data.isEmpty else {
                lock.lock()
                finished = true
                lock.unlock()
                return
            }
            try? log?.write(contentsOf: data)
            lock.lock()
            buffer.append(data)
            lock.unlock()
        }

        func drain() -> (Data, Bool) {
            lock.lock()
            defer { lock.unlock() }
            let taken = buffer
            buffer = Data()
            return (taken, finished)
        }
    }
}
