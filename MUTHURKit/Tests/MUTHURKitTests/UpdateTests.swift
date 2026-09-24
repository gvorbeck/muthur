import Foundation
import Testing

@testable import MUTHURKit

/// *Check for Updates…* (**D106**) — everything short of the network and the
/// swap, which are the two halves that cannot be asked of a test.
struct UpdateTests {

    // MARK: - Versions

    @Test func theTagsLeadingVIsNotPartOfTheNumber() {
        #expect(Update.Version("v0.9.0") == Update.Version("0.9.0"))
    }

    /// v0.1.0 went out with a bundle saying `0.1` (761464a), so a two-field
    /// version is a thing that has existed and must still compare.
    @Test func aShortVersionIsPaddedWithZeros() {
        #expect(Update.Version("0.1") == Update.Version("v0.1.0"))
        #expect(Update.Version("0.1")! < Update.Version("0.1.1")!)
    }

    /// Numerically, not as text — `0.10.0` is after `0.9.0`, which a string
    /// comparison gets backwards.
    @Test func fieldsCompareAsNumbers() {
        #expect(Update.Version("0.9.0")! < Update.Version("0.10.0")!)
        #expect(Update.Version("1.0.0")! > Update.Version("0.99.99")!)
    }

    @Test func somethingThatIsNotANumberIsNotAVersion() {
        #expect(Update.Version("") == nil)
        #expect(Update.Version("latest") == nil)
        #expect(Update.Version("1.0.0-beta") == nil)
        #expect(Update.Version("1..0") == nil)
    }

    // MARK: - The release

    private func body(tag: String = "v0.9.1", assets: String? = nil) -> Data {
        let assets =
            assets
            ?? #"[{"name":"MUTHUR.zip","browser_download_url":"https://example.com/MUTHUR.zip"}]"#
        return Data(
            #"{"tag_name":"\#(tag)","html_url":"https://example.com/r","body":"notes","assets":\#(assets)}"#
                .utf8)
    }

    @Test func aReleaseIsReadForItsTagAndItsZip() throws {
        let release = try Update.parse(body())
        #expect(release.tag == "v0.9.1")
        #expect(release.version == Update.Version("0.9.1"))
        #expect(release.zip.absoluteString == "https://example.com/MUTHUR.zip")
        #expect(release.notes == "notes")
    }

    /// Other assets may appear beside it one day; only the one `release.sh`
    /// publishes is the one this installs.
    @Test func theZipIsFoundByNameAmongOthers() throws {
        let release = try Update.parse(
            body(
                assets: #"""
                    [{"name":"notes.txt","browser_download_url":"https://example.com/n"},
                     {"name":"MUTHUR.zip","browser_download_url":"https://example.com/z"}]
                    """#))
        #expect(release.zip.absoluteString == "https://example.com/z")
    }

    @Test func aReleaseWithoutTheZipIsSaidSo() {
        #expect(throws: Update.Failure.noAsset(tag: "v0.9.1")) {
            try Update.parse(body(assets: "[]"))
        }
    }

    @Test func somethingThatIsNotAReleaseIsUnreadable() {
        #expect(throws: Update.Failure.unreadable) { try Update.parse(Data("{}".utf8)) }
        #expect(throws: Update.Failure.unreadable) { try Update.parse(body(tag: "nightly")) }
    }

    /// `body` and `html_url` are GitHub's to leave out.
    @Test func notesAndPageAreOptional() throws {
        let release = try Update.parse(
            Data(
                #"{"tag_name":"v1.0.0","assets":[{"name":"MUTHUR.zip","browser_download_url":"https://example.com/z"}]}"#
                    .utf8))
        #expect(release.notes == "")
        #expect(release.page == nil)
    }

    // MARK: - Checking the download

    private func fakeBundle(id: String, version: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("update-test-\(UUID().uuidString)")
        let bundle = root.appendingPathComponent("MUTHUR.app")
        let contents = bundle.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: NSDictionary = [
            "CFBundleIdentifier": id, "CFBundleShortVersionString": version,
        ]
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        return bundle
    }

    @Test func aBundleThatIsNotMUTHURIsRefused() throws {
        let bundle = try fakeBundle(id: "com.example.other", version: "0.9.1")
        defer { try? FileManager.default.removeItem(at: bundle.deletingLastPathComponent()) }
        #expect(throws: Update.Failure.wrongIdentifier("com.example.other")) {
            try Update.verify(bundle, as: Update.Version("0.9.1")!)
        }
    }

    /// `release.sh` asks the bundle, not the project file, and so does this:
    /// the bundle is what would be launched.
    @Test func aBundleThatIsNotTheTaggedVersionIsRefused() throws {
        let bundle = try fakeBundle(id: Update.identifier, version: "0.9.0")
        defer { try? FileManager.default.removeItem(at: bundle.deletingLastPathComponent()) }
        #expect(throws: Update.Failure.wrongVersion(bundle: "0.9.0", tag: "0.9.1")) {
            try Update.verify(bundle, as: Update.Version("0.9.1")!)
        }
    }

    /// Right name, right number, no signature: `codesign` is the question
    /// that catches it, and it is asked.
    @Test func anUnsignedBundleIsRefused() throws {
        let bundle = try fakeBundle(id: Update.identifier, version: "0.9.1")
        defer { try? FileManager.default.removeItem(at: bundle.deletingLastPathComponent()) }
        #expect(throws: Update.Failure.doesNotVerify) {
            try Update.verify(bundle, as: Update.Version("0.9.1")!)
        }
    }

    /// The real thing, end to end short of the swap: ask GitHub, download what
    /// it names, unpack it and put every one of `verify`'s questions to it.
    /// Off unless asked for — a suite that needs the network is a suite that
    /// goes red on a train (D104).
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MUTHUR_LIVE_UPDATE"] != nil))
    func theLatestReleaseDownloadsAndVerifies() async throws {
        let verdict = try await Update.check(current: Update.Version("0")!)
        guard case .available(let release) = verdict else {
            Issue.record("every release is newer than 0")
            return
        }
        let bundle = try await Update.fetch(release)
        defer {
            try? FileManager.default.removeItem(
                at: bundle.deletingLastPathComponent().deletingLastPathComponent())
        }
        #expect(FileManager.default.fileExists(atPath: bundle.path))
    }

    @Test func aFolderWithNoBundleInItIsRefused() {
        let nowhere = FileManager.default.temporaryDirectory
            .appendingPathComponent("update-test-\(UUID().uuidString)/MUTHUR.app")
        #expect(throws: Update.Failure.notABundle) {
            try Update.verify(nowhere, as: Update.Version("0.9.1")!)
        }
    }
}
