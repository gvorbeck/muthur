import Foundation
import Testing

@testable import MUTHURKit

/// §10's port, checked against the thing it is a port of.
///
/// `PanelTests` proves the arithmetic is internally consistent — that the bands
/// fill the bar, that a longer track is never narrower, that a cut title still
/// fits. This proves it is the *same* arithmetic, by running `lib/panel.sh`'s
/// own functions over the same inputs and comparing what comes back. Where the
/// two disagree, the script is right, and this is what would say so.
///
/// It only ever **sources** that file. Nothing under `cd-collection` is written,
/// created or moved, and no part of MU/TH/UR shells out to it at runtime —
/// this is a test bench, and the logic itself is ported.
///
/// Material tier: skipped where the script is not on this machine.
@Suite("§10, against the script", .enabled(if: PanelBash.available))
struct PanelAgainstBashTests {

    // MARK: - Widths

    /// The exact case `wcols` was written for, and the case Swift takes off it.
    @Test("A string is as many columns wide as bash says it is")
    func widths() throws {
        let subjects = [
            "Kind of Blue", "", "Björk", "君の名は", "ハルカ",
            "So What (Take 2)", "Amon Düül II", "🀄 tiles", "Ⅲ", "！？",
        ]
        let theirs = try PanelBash.run(
            subjects.map { "wcols \(PanelBash.quote($0)); printf '%s\\n' \"$WCOLS\"" }
        )
        try #require(theirs.count == subjects.count)
        for (subject, answer) in zip(subjects, theirs) {
            #expect(
                "\(Columns.width(of: subject))" == answer,
                "\(subject): ours \(Columns.width(of: subject)), bash \(answer)"
            )
        }
    }

    /// The two places the port and the script count differently, written down
    /// so neither of them drifts without somebody noticing (§18.23).
    ///
    /// Both are cases where `cwidth`'s own comment and `cwidth`'s own code
    /// disagree with each other, and where the terminal sides with the comment.
    /// Neither is a decision the script took; both are the byte-and-collation
    /// machinery the port was told to drop showing through.
    @Test("Where the two disagree about a width, and why")
    func widthDivergences() throws {
        // Conjoining jamo. `한국` handed back by macOS decomposed is six
        // characters to bash — and its zero-width table covers the combining
        // diacriticals but not the Hangul Jamo block, so each of the six counts
        // one and the answer is six for a name a terminal draws in four. Swift
        // has the syllable back as one grapheme cluster before anybody counts.
        let hangul = "한국".decomposedStringWithCanonicalMapping
        // Fullwidth Latin. `cwidth` says outright that "a fullwidth form is
        // drawn two columns wide", and then tests for it with the bracket range
        // `[！-｠]` — which bash matches by **collation** under a UTF-8 locale,
        // not by code point. `Ａ` collates beside `A` and falls outside the
        // range; `！` does not and stays in it. So the punctuation is measured
        // and the letters are not.
        let fullwidth = "Ａｂｃ"

        let theirs = try PanelBash.run(
            [hangul, fullwidth].map {
                "wcols \(PanelBash.quote($0)); printf '%s\\n' \"$WCOLS\""
            }
        )
        try #require(theirs.count == 2)

        #expect(Columns.width(of: hangul) == 4)
        #expect(theirs[0] == "6")

        #expect(Columns.width(of: fullwidth) == 6)
        #expect(theirs[1] == "3")
    }

    /// Including the ellipsis, the pad, and which side the slack goes.
    @Test("A fitted string is the string bash fits")
    func fits() throws {
        let subjects = [
            "Libet's all joyful camaraderie", "So What", "君の名は。", "",
            "The Velvet Underground & Nico", "Björk", "ハルカ・ネス",
        ]
        var lines: [String] = []
        var expected: [String] = []
        for subject in subjects {
            for width in [1, 2, 5, 8, 13, 18, 32, 52] {
                for right in [false, true] {
                    lines.append(
                        "fitv \(PanelBash.quote(subject)) \(width)\(right ? " right" : "");"
                            + " printf '%s\\n' \"$FIT\""
                    )
                    expected.append(
                        Columns.fit(subject, to: width, align: right ? .trailing : .leading)
                    )
                }
            }
        }
        let theirs = try PanelBash.run(lines)
        try #require(theirs.count == expected.count)
        for (index, answer) in theirs.enumerated() {
            #expect(expected[index] == answer, "line \(index): [\(expected[index])] vs [\(answer)]")
        }
    }

    // MARK: - The album meter

    /// Largest remainder, spent remainders, tracks too short to earn a band,
    /// and the four shades — all of it, over two hundred records that could
    /// exist.
    @Test("Every band ends where bash ends it, and wears the shade bash gives it")
    func bandWidths() throws {
        var random = PanelBash.Random(seed: 0x5EED_1979)
        var records: [[Int]] = [
            [194, 178, 200],
            [1200, 1, 1200],
            [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
            Array(repeating: 100, count: 9),
            [4321],
        ]
        for _ in 0..<200 {
            let count = random.next(in: 1...40)
            records.append((0..<count).map { _ in random.next(in: 1...1200) })
        }

        let units = PanelGrid.stripWidth * Meter.unitsPerCell
        let theirs = try PanelBash.run(
            records.map { durations in
                "bands \(units) \(durations.map(String.init).joined(separator: " "));"
                    + " printf '%s|%s\\n' \"${BEND[*]}\" \"${BCOL[*]}\""
            }
        )
        try #require(theirs.count == records.count)

        // `SHADES` in the order `bands()` cycles them (`panel.sh:92`). The port
        // carries the index; this is the one place that has to know what index
        // 2 actually was in the terminal.
        let shades = ["214", "130", "220", "166"]

        for (durations, answer) in zip(records, theirs) {
            let ours = Meter.bands(units: units, durations: durations)
            let parts = answer.split(separator: "|", omittingEmptySubsequences: false)
            let ends = parts[0].split(separator: " ").map { Int($0)! }
            let colours = parts.count > 1 ? parts[1].split(separator: " ").map(String.init) : []
            #expect(ours.map(\.end) == ends, "\(durations)")
            #expect(ours.map { shades[$0.shade] } == colours, "\(durations)")
        }
    }

    /// The cells themselves: whole bands, boundaries drawn where they fall, the
    /// head winning the column it is in, and the run-out.
    @Test("Every cell of the album meter is the cell bash draws")
    func bandBar() throws {
        var random = PanelBash.Random(seed: 0xC0FFEE)
        let durations = [194, 178, 200, 245, 31, 512, 178]
        let units = PanelGrid.stripWidth * Meter.unitsPerCell
        var heads = [0, 1, 7, 8, units - 1, units]
        heads += (0..<60).map { _ in random.next(in: 0...units) }

        let theirs = try PanelBash.run(
            ["bands \(units) \(durations.map(String.init).joined(separator: " "))"]
                + heads.map { "bandbar \($0); printf '%b\\n' \"$BANDBAR\"" }
        )
        try #require(theirs.count == heads.count)

        let bands = Meter.bands(units: units, durations: durations)
        for (head, answer) in zip(heads, theirs) {
            let ours = Meter.cells(head: head, bands: bands, width: PanelGrid.stripWidth)
            let mine = PanelBash.glyphs(ours)
            let theirs = PanelBash.stripSGR(answer)
            #expect(mine == theirs, "head \(head):\n  ours  \(mine)\n  bash  \(theirs)")
        }
    }
}

// MARK: - The bench

/// Runs `lib/panel.sh`'s functions and hands back what they printed.
///
/// The script is read and never touched, which is `CLAUDE.md`'s rule and also
/// simple prudence: it is a program somebody uses over ssh, and this is a test.
enum PanelBash {

    static let script = URL(
        fileURLWithPath: "/Users/garrett.vorbeck/Sites/cd-collection/scripts/lib/panel.sh"
    )

    static var available: Bool { FileManager.default.isReadableFile(atPath: script.path) }

    /// One `bash` with the library sourced, one line of output per statement.
    static func run(_ statements: [String]) throws -> [String] {
        let body = (["source \(quote(script.path))"] + statements).joined(separator: "\n")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", body]
        // `APP_BADGE` is built from it at source time. Nothing here reads the
        // badge, but an unset variable under `set -u` would be the end of it.
        process.environment = ["APP": "muthur", "LC_ALL": "en_US.UTF-8"]
        process.currentDirectoryURL = FileManager.default.temporaryDirectory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let text = String(decoding: data, as: UTF8.self)
        return text.hasSuffix("\n")
            ? text.dropLast().components(separatedBy: "\n")
            : text.components(separatedBy: "\n")
    }

    static func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// What `strip_sgr` put in, taken back out. Colour is compared through
    /// `bands()`; this is about which glyph landed in which cell.
    static func stripSGR(_ line: String) -> String {
        line.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression
        )
    }

    static let parts = ["", "▏", "▎", "▍", "▌", "▋", "▊", "▉"]

    static func glyphs(_ cells: [Meter.Cell]) -> String {
        cells.map { cell in
            switch cell {
            case .band: "▓"
            case .runout: "░"
            case .head(let eighths): parts[eighths]
            case .boundary(let eighths, _, _): parts[eighths]
            }
        }.joined()
    }

    /// Seeded, so a failure is a failure you can run again. SplitMix64, which
    /// is four lines and does not need to be good — it needs to be the same
    /// four lines tomorrow.
    struct Random {
        private var state: UInt64
        init(seed: UInt64) { state = seed }

        mutating func next(in range: ClosedRange<Int>) -> Int {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            let span = UInt64(range.count)
            return range.lowerBound + Int(z % span)
        }
    }
}
