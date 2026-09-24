import Foundation

/// *Check for Updates…* (**D106**) — `Scripts/bootstrap.sh`, from inside the
/// program it installs.
///
/// Re-running that script has always been how a machine without the repository
/// got the new release. This is the same four steps in the same order — ask
/// GitHub what is newest, download it, check it is what it says it is, put it
/// where the old one stood — with the one thing a script does not have to think
/// about: the program being replaced is the one doing the replacing. So the
/// last step is handed to a few lines of `sh` that wait for this process to be
/// gone before they touch the bundle it was running out of.
///
/// **Nothing here proves who made the download**, and nothing could. The app is
/// ad-hoc signed; `codesign --verify` says the bundle is intact, not whose it
/// is. The trust is HTTPS and the GitHub account, which is exactly the trust
/// `curl … bootstrap.sh | bash` already asks for, and no more.
public enum Update {

    public static let repository = "gvorbeck/muthur"
    public static let identifier = "com.gvorbeck.muthur"

    /// The one asset `Scripts/release.sh` publishes.
    public static let asset = "MUTHUR.zip"

    // MARK: - Versions

    /// A release number, compared a field at a time.
    ///
    /// `release.sh` insists on `MAJOR.MINOR.PATCH` for the tags it cuts, but
    /// the bundle's own `CFBundleShortVersionString` has been `0.1` before now
    /// (761464a) — so this reads any run of dot-separated integers and pads the
    /// short one with zeros, rather than asserting a shape the older bundles
    /// never had.
    public struct Version: Comparable, Sendable, CustomStringConvertible {
        public let fields: [Int]

        /// `v0.9.0`, `0.9.0` and `0.9` all parse; anything with a letter past
        /// the leading `v` does not.
        public init?(_ text: String) {
            var text = text.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            let fields = parts.compactMap { Int($0) }
            guard !parts.isEmpty, fields.count == parts.count, fields.allSatisfy({ $0 >= 0 })
            else { return nil }
            self.fields = fields
        }

        public static func < (a: Version, b: Version) -> Bool {
            let width = max(a.fields.count, b.fields.count)
            for i in 0..<width {
                let x = i < a.fields.count ? a.fields[i] : 0
                let y = i < b.fields.count ? b.fields[i] : 0
                if x != y { return x < y }
            }
            return false
        }

        public static func == (a: Version, b: Version) -> Bool { !(a < b) && !(b < a) }

        public var description: String { fields.map(String.init).joined(separator: ".") }
    }

    // MARK: - The release

    /// What `releases/latest` says, cut down to what an update needs.
    ///
    /// GitHub's `latest` already leaves out drafts and pre-releases, which is
    /// the same set `bootstrap.sh`'s `releases/latest/download/…` redirect
    /// resolves against — so the menu and the script cannot disagree about
    /// which release is the newest.
    public struct Release: Sendable, Equatable {
        public let tag: String
        public let version: Version
        public let zip: URL
        public let page: URL?
        public let notes: String

        public static func == (a: Release, b: Release) -> Bool {
            a.tag == b.tag && a.zip == b.zip
        }
    }

    public enum Failure: Error, Equatable, LocalizedError {
        case unreachable(String)
        case unreadable
        case noRelease
        case noAsset(tag: String)
        case notABundle
        case wrongIdentifier(String)
        case wrongVersion(bundle: String, tag: String)
        case doesNotVerify
        case noSlice(String)
        case cannotWrite(String)

        public var errorDescription: String? {
            switch self {
            case .unreachable(let why): "GitHub could not be reached — \(why)"
            case .unreadable: "GitHub's answer was not a release."
            case .noRelease: "There is no release yet."
            case .noAsset(let tag): "\(tag) has no \(Update.asset) on it."
            case .notABundle: "The download did not contain MUTHUR.app."
            case .wrongIdentifier(let id):
                "The download is not MU/TH/UR — its identifier is '\(id)'. Nothing was installed."
            case .wrongVersion(let bundle, let tag):
                "The download says it is \(bundle), not \(tag). Nothing was installed."
            case .doesNotVerify:
                "The downloaded bundle does not verify. Nothing was installed."
            case .noSlice(let arch):
                "The download has no \(arch) slice and would not launch on this Mac. Nothing was installed."
            case .cannotWrite(let dir):
                "\(dir) is not writable from here. Run Scripts/bootstrap.sh instead."
            }
        }
    }

    /// Reads the body of `GET /repos/…/releases/latest`.
    ///
    /// Only `tag_name` and the asset list are required. `html_url` and `body`
    /// are GitHub's to leave out, and a release with no notes is still a
    /// release.
    public static func parse(_ data: Data) throws -> Release {
        struct Wire: Decodable {
            struct Asset: Decodable {
                let name: String
                let browser_download_url: URL
            }
            let tag_name: String
            let html_url: URL?
            let body: String?
            let assets: [Asset]
        }
        guard let wire = try? JSONDecoder().decode(Wire.self, from: data),
            let version = Version(wire.tag_name)
        else { throw Failure.unreadable }
        guard let zip = wire.assets.first(where: { $0.name == asset }) else {
            throw Failure.noAsset(tag: wire.tag_name)
        }
        return Release(
            tag: wire.tag_name, version: version, zip: zip.browser_download_url,
            page: wire.html_url, notes: wire.body ?? "")
    }

    // MARK: - Asking

    public enum Verdict: Sendable, Equatable {
        case current(Release)
        case available(Release)
    }

    /// One request. No token: the repository is public, and sixty unauthenticated
    /// requests an hour is sixty more than a menu item somebody picks by hand
    /// is going to spend.
    public static func check(
        current: Version, session: URLSession = .shared
    ) async throws -> Verdict {
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue(MUTHUR.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Failure.unreachable(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { throw Failure.noRelease }
            guard http.statusCode == 200 else {
                throw Failure.unreachable("HTTP \(http.statusCode)")
            }
        }
        let release = try parse(data)
        return release.version > current ? .available(release) : .current(release)
    }

    // MARK: - Fetching

    /// Downloads the release, unpacks it, and checks it — `bootstrap.sh`'s
    /// middle, and `release.sh`'s four questions asked again at the other end.
    ///
    /// Returns the unpacked bundle, inside a directory of its own under
    /// `$TMPDIR` that the hand-off removes once it has copied from it.
    public static func fetch(
        _ release: Release, session: URLSession = .shared
    ) async throws -> URL {
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("muthur-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        do {
            var request = URLRequest(url: release.zip)
            request.setValue(MUTHUR.userAgent, forHTTPHeaderField: "User-Agent")
            let downloaded: URL
            let response: URLResponse
            do {
                (downloaded, response) = try await session.download(for: request)
            } catch {
                throw Failure.unreachable(error.localizedDescription)
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw Failure.unreachable("HTTP \(http.statusCode)")
            }
            let zip = work.appendingPathComponent(asset)
            try FileManager.default.moveItem(at: downloaded, to: zip)

            // `ditto` and not `unzip`, for `bootstrap.sh`'s reason: the
            // signature lives partly in extended attributes, and a bundle
            // unpacked by something that drops them will not launch.
            let unpacked = work.appendingPathComponent("x", isDirectory: true)
            guard run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path]).status == 0
            else { throw Failure.notABundle }
            try? FileManager.default.removeItem(at: zip)

            let bundle = unpacked.appendingPathComponent("MUTHUR.app", isDirectory: true)
            try verify(bundle, as: release.version)
            return bundle
        } catch {
            try? FileManager.default.removeItem(at: work)
            throw error
        }
    }

    /// The architecture this process is, which is the slice the new bundle must
    /// carry to be launched in its place.
    public static var thisArchitecture: String {
        #if arch(arm64)
            "arm64"
        #else
            "x86_64"
        #endif
    }

    /// Everything that must be true of a bundle before it is allowed to stand
    /// where this one does.
    ///
    /// The cheap questions first, so that a bundle which is plainly the wrong
    /// thing is refused without asking `codesign` about it.
    ///
    /// Only *this* machine's slice is required, not both of `release.sh`'s:
    /// that script is guarding every machine the release will reach, and this
    /// is guarding the one it is about to land on.
    public static func verify(_ bundle: URL, as version: Version) throws {
        let info = bundle.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: info) as? [String: Any] else {
            throw Failure.notABundle
        }
        let id = plist["CFBundleIdentifier"] as? String ?? ""
        guard id == identifier else { throw Failure.wrongIdentifier(id) }

        let said = plist["CFBundleShortVersionString"] as? String ?? ""
        guard let bundleVersion = Version(said), bundleVersion == version else {
            throw Failure.wrongVersion(bundle: said.isEmpty ? "nothing" : said, tag: version.description)
        }

        guard run("/usr/bin/codesign", ["--verify", "--deep", "--strict", bundle.path]).status == 0
        else { throw Failure.doesNotVerify }

        let binary = bundle.appendingPathComponent("Contents/MacOS/MUTHUR").path
        let archs = run("/usr/bin/lipo", ["-archs", binary])
        guard archs.status == 0,
            archs.output.split(whereSeparator: \.isWhitespace).contains(Substring(thisArchitecture))
        else { throw Failure.noSlice(thisArchitecture) }
    }

    // MARK: - Handing off

    /// The last step, which this process cannot take for itself.
    ///
    /// Written as `sh` rather than a second executable because it is a screen
    /// of it and has to outlive the program that launched it — a child of this
    /// process is reparented to `launchd` when we quit and carries on.
    ///
    /// **The new bundle is staged beside the old one before the old one goes**,
    /// on the same volume, so the moment with no MU/TH/UR in the folder is a
    /// `rename` and not a copy. Any failure before that moment puts nothing
    /// in the way and relaunches what was already there — an update that does
    /// not happen is a menu item somebody can pick again; an update that leaves
    /// an empty space in `/Applications` is not.
    ///
    /// The guard on the destination's identifier is `bootstrap.sh`'s and
    /// `install.sh`'s: never clear a path in an application folder without
    /// checking what is standing there.
    static let handOffScript = #"""
        pid=$1 new=$2 dest=$3 work=$4
        n=0
        while kill -0 "$pid" 2>/dev/null; do
          n=$((n+1)); [ "$n" -gt 600 ] && { rm -rf "$work"; exit 1; }
          sleep 0.1
        done
        staged="$dest.update-$$"
        ours() { [ "$(/usr/bin/defaults read "$dest/Contents/Info" CFBundleIdentifier 2>/dev/null)" = com.gvorbeck.muthur ]; }
        if ours && /usr/bin/ditto "$new" "$staged" \
          && /bin/rm -rf "$dest" && /bin/mv "$staged" "$dest"; then
          /usr/bin/xattr -dr com.apple.quarantine "$dest" 2>/dev/null
          /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$dest"
        else
          /bin/rm -rf "$staged"
        fi
        /bin/rm -rf "$work"
        ours && /usr/bin/open "$dest"
        """#

    /// Starts the hand-off and returns. The caller quits next.
    ///
    /// Asks whether the folder can be written *before* anything is started,
    /// because the script has nobody to tell when it cannot — it would simply
    /// relaunch the old version, which looks exactly like an update that did
    /// nothing.
    public static func handOff(
        _ bundle: URL, over destination: URL,
        pid: Int32 = ProcessInfo.processInfo.processIdentifier
    ) throws {
        let folder = destination.deletingLastPathComponent().path
        guard FileManager.default.isWritableFile(atPath: folder) else {
            throw Failure.cannotWrite(folder)
        }
        let work = bundle.deletingLastPathComponent().deletingLastPathComponent()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c", handOffScript, "muthur-update",
            String(pid), bundle.path, destination.path, work.path,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    // MARK: -

    private static func run(_ tool: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return (-1, "") }
        // Drained before waiting, for `Convert`'s reason: a full pipe with
        // nobody reading it is a process that never exits.
        let data = (try? out.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
