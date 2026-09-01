import Foundation
import Testing

@testable import MUTHURKit

/// §1.1 — `-h` / `--help`.
///
/// **This suite is standing in for a mechanism.** `usage` reads `$0`
/// (`panel.sh:270`), so in the script the help and the file's own header are
/// literally the same forty-nine lines and cannot disagree. Compiled, there is
/// no `$0` to read, and the text is a literal that *can* drift. What is left is
/// this: read the source back off disk and check that no switch and no
/// environment variable was added without a line about it. That is weaker than
/// the shell's guarantee and it is the honest amount of guarantee available.
@Suite("§1.1 — --help")
struct UsageTests {

    // MARK: - Reading the source back

    /// The package's `Sources` directory, from this file's own compiled-in path.
    ///
    /// `#filePath` is what the compiler saw, not a promise about what is on this
    /// machine now — a build copied elsewhere, or run from a cached artefact,
    /// has every right to leave nothing here. So the drift checks below are
    /// *conditional* on finding it, and say so rather than asserting a layout
    /// nobody guaranteed.
    static let sources: URL? = {
        let here = URL(fileURLWithPath: #filePath)
        let root = here  // UsageTests.swift → MUTHURKitTests → Tests → MUTHURKit
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = root.appending(path: "Sources/MUTHURKit")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sources.path, isDirectory: &isDir),
            isDir.boolValue
        else { return nil }
        return sources
    }()

    static var canReadSource: Bool { sources != nil }

    /// Every `.swift` file under `Sources`, read as text.
    private static func sourceText() -> String {
        guard let sources else { return "" }
        let walker = FileManager.default.enumerator(
            at: sources, includingPropertiesForKeys: nil)
        var all = ""
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            all += (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        return all
    }

    /// Whole string literals that look like a command-line switch.
    private static func flagLiterals(in text: String) -> Set<String> {
        var found: Set<String> = []
        let pattern = try! NSRegularExpression(pattern: "\"(-{1,2}[a-z][a-z-]*)\"")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in pattern.matches(in: text, range: range) {
            if let r = Range(match.range(at: 1), in: text) { found.insert(String(text[r])) }
        }
        return found
    }

    /// Whatever the help itself offers as a switch: a word, on its own, that
    /// starts with a dash. Trailing punctuation is prose, not part of the flag.
    private static func flagsNamedIn(_ help: String) -> Set<String> {
        var found: Set<String> = []
        for word in help.split(whereSeparator: { $0.isWhitespace }) {
            let token = word.trimmingCharacters(in: CharacterSet(charactersIn: ",."))
            guard token.count > 1, token.hasPrefix("-") else { continue }
            if token.dropFirst(token.hasPrefix("--") ? 2 : 1).allSatisfy({
                $0.isLowercase || $0 == "-"
            }) {
                found.insert(token)
            }
        }
        return found
    }

    /// **The pairs the help is allowed to name only once**, because the script's
    /// own header names them only once: `player -n ~/Music/Album` is there
    /// (`player:10`) and `--dry-run` is not, and `-h` and `--help` are both
    /// absent from it altogether. A flag with no entry here has no alias to hide
    /// behind and must be documented under its own name.
    static let aliases: [String: String] = [
        "--dry-run": "-n",
        "-h": "--help",
    ]

    // MARK: - The promise in `Usage.swift`'s doc comment

    /// Every switch the parse accepts is spoken for: named in the help, or
    /// aliased to one that is.
    @Test(
        "No flag the parse accepts goes undocumented",
        .enabled(if: UsageTests.canReadSource)
    )
    func everyFlagIsDocumented() throws {
        let sources = try #require(Self.sources)
        let parseSource = try String(
            contentsOf: sources.appending(path: "Source/LaunchOptions.swift"), encoding: .utf8)
        let accepted = Self.flagLiterals(in: parseSource)
        try #require(!accepted.isEmpty)

        let help = Usage.text()
        let named = Self.flagsNamedIn(help)
        for flag in accepted.sorted() {
            let spoken = named.contains(flag) || Self.aliases[flag].map(named.contains) == true
            #expect(spoken, "\(flag) is accepted by the parse and named nowhere in --help")
        }
    }

    /// The other direction, and the one a literal is likeliest to get wrong: the
    /// help offering a switch that no longer exists.
    @Test("Every flag the help offers is a flag that still works")
    func theHelpOffersNothingImaginary() {
        for flag in Self.flagsNamedIn(Usage.text()).sorted() {
            #expect(
                (try? LaunchOptions.parse([flag])) != nil,
                "--help offers \(flag) and the parse refuses it")
        }
    }

    /// **`MUTHUR_ART` is the one to watch for.** The script has `PLAYER_ART`
    /// (`player:49`) and this port has no such switch — the sleeve is always
    /// drawn when there is room for it — so documenting one would be the help
    /// telling a straight lie. Every variable listed must be one something
    /// actually reads.
    @Test(
        "Every variable the help lists is one the kit reads",
        .enabled(if: UsageTests.canReadSource)
    )
    func theHelpListsNothingImaginary() {
        let read = Self.environmentNames(in: Self.sourceText())
        for line in Usage.text().components(separatedBy: "\n") {
            guard line.hasPrefix("  MUTHUR_") || line.hasPrefix("  XDG_") else { continue }
            let name = String(line.trimmingCharacters(in: .whitespaces).prefix(while: {
                $0.isUppercase || $0 == "_"
            }))
            #expect(read.contains(name), "--help lists \(name) and nothing reads it")
        }
        #expect(!Usage.text().contains("MUTHUR_ART"))
    }

    /// And the reverse: a variable added to the kit and never written down.
    @Test(
        "No variable the kit reads goes unlisted",
        .enabled(if: UsageTests.canReadSource)
    )
    func everyVariableIsDocumented() {
        let help = Usage.text()
        for name in Self.environmentNames(in: Self.sourceText()).sorted() {
            // A `PLAYER_` name is documented by the paragraph about `PLAYER_`
            // names, which speaks of them under their new spelling.
            let modern = name.replacingOccurrences(of: "PLAYER_", with: "MUTHUR_")
            #expect(
                help.contains(name) || help.contains(modern),
                "\(name) is read by the kit and named nowhere in --help")
        }
    }

    /// The compatibility paragraph names four variables by hand. If a fifth
    /// `PLAYER_` name is ever honoured, that sentence is wrong and this says so.
    @Test(
        "The PLAYER_ paragraph names exactly the PLAYER_ names that work",
        .enabled(if: UsageTests.canReadSource)
    )
    func theCompatibilityParagraphIsComplete() {
        let honoured = Self.environmentNames(in: Self.sourceText())
            .filter { $0.hasPrefix("PLAYER_") }
            .sorted()
        #expect(
            honoured == ["PLAYER_COLLECTION", "PLAYER_DIRS", "PLAYER_KEEP", "PLAYER_WORK"])
        let help = Usage.text()
        #expect(
            help.contains(
                "MUTHUR_DIRS, MUTHUR_WORK, MUTHUR_KEEP and MUTHUR_COLLECTION are read"))
    }

    private static func environmentNames(in text: String) -> Set<String> {
        var found: Set<String> = []
        let pattern = try! NSRegularExpression(pattern: "\"((?:MUTHUR|PLAYER|XDG)_[A-Z_]+)\"")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in pattern.matches(in: text, range: range) {
            if let r = Range(match.range(at: 1), in: text) { found.insert(String(text[r])) }
        }
        return found
    }

    // MARK: - The shape of the page

    /// `usage` prints the header and nothing round it: no blank line above, one
    /// newline below. `--check` is the opposite (`panel.sh:583`) and that
    /// difference is deliberate — see `Usage.text`.
    @Test("The page is not framed the way the check report is")
    func itIsNotFramed() {
        let text = Usage.text()
        #expect(!text.hasPrefix("\n"))
        #expect(text.hasSuffix("\n"))
        #expect(!text.hasSuffix("\n\n"))
    }

    /// It opens on the same line the script's header opens on (`player:3`), in
    /// the slashed form, because this is one of the places the name is drawn
    /// rather than stored.
    @Test("It opens with the name as it is written, not as it is filed")
    func itOpensWithTheSlashedName() {
        #expect(Usage.text().hasPrefix("MU/TH/UR — play an album from a zip, a folder,"))
    }

    /// **Mine, not the script's**: the examples say whatever you called it.
    /// `usage` is already reading `$0` for the text, so reading `$0` for the
    /// name too seemed the smaller lie than a hard-coded `player` in a file that
    /// can be renamed.
    @Test("The examples are written in the name it was invoked under")
    func theExamplesUseTheInvokedName() {
        let text = Usage.text(invokedAs: "/usr/local/bin/deck")
        #expect(text.contains("\n  deck --cd  "))
        #expect(!text.contains("  MUTHUR --cd"))
        // The banner is the program, not the invocation, and does not move.
        #expect(text.hasPrefix("MU/TH/UR — "))
    }

    /// No `$0` at all falls back to the bundle's name rather than printing a
    /// column of examples with a hole down the left of it.
    ///
    /// Only the empty case is asserted. A path with a trailing slash keeps the
    /// component before it — `split` drops the empty piece — and that is a
    /// consequence of how paths are split rather than a rule anything promised,
    /// so it is not written down as one.
    @Test("A name that is not a name falls back to the bundle's")
    func anEmptyNameFallsBack() {
        #expect(Usage.text(invokedAs: "").contains("\n  MUTHUR --cd"))
        #expect(Usage.text(invokedAs: "/opt/bin/muthur").contains("\n  muthur --cd"))
    }
}
