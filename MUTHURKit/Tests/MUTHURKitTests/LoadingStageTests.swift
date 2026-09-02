import Foundation
import Testing

@testable import MUTHURKit

/// §10's last two boxes: the loading stage, and the faceplate every screen
/// wears.
@Suite("§10 — the loading stage")
struct LoadingStageTests {

    // MARK: - What the plate says

    /// `load_stage "OPENING · $(( n * 100 / total ))%"` (`player:1290`).
    @Test("Unpacking counts up under OPENING")
    func openingCountsUp() {
        let stage = LoadingStage.opening(
            Unpacker.Progress(done: 21, total: 50, name: "track21.flac"),
            source: "Album.zip"
        )
        #expect(stage.meta == "OPENING · 42%")
        #expect(stage.detail == "track21.flac")
        #expect(stage.source == "Album.zip")
    }

    /// `load_stage "OPENING" 0 "$total" "$SRC_LABEL"` (`player:1398`) — the
    /// announcement before the archive is touched. **A bare heading, and not
    /// `OPENING · 0%`**: nothing has happened yet, and a zero is a claim about
    /// progress rather than the absence of one.
    @Test("The announcement before the archive is opened carries no percentage")
    func announcementHasNoPercent() {
        let stage = LoadingStage.opening(source: "Album.zip", total: 0)
        #expect(stage.percent == nil)
        #expect(stage.meta == "OPENING")
        // The archive is the subject as well as the source, because there is
        // nothing inside it to name yet.
        #expect(stage.detail == "Album.zip")
    }

    /// `load_stage "READING · $(( n * 100 / total ))%"` (`player:1491`).
    @Test("Reading metadata counts up under READING")
    func readingCountsUp() {
        let stage = LoadingStage.reading(
            Record.Progress(read: 3, total: 4, filename: "04 Coda.aiff"),
            source: "Album"
        )
        #expect(stage.meta == "READING · 75%")
        #expect(stage.detail == "04 Coda.aiff")
    }

    /// `load_stage "READING DISC" 2 3 "asking MusicBrainz"` (`player:2252`).
    /// **Three steps and no percentage** — the script prints the bare heading,
    /// and 66% of asking MusicBrainz a question is not a fact.
    @Test("A disc counts in steps and says no percentage")
    func discCountsInSteps() {
        let stage = LoadingStage.disc(
            DiscTitles.Stage(step: 2, of: 3, detail: "asking MusicBrainz"),
            source: "Audio CD"
        )
        #expect(stage.meta == "READING DISC")
        #expect(stage.done == 2)
        #expect(stage.total == 3)
    }

    /// The port had grown a fourth stage word, `UNPACKING`, which the script has
    /// nowhere: `open_source` says `OPENING` before the archive is opened
    /// (`player:1398`) and the unpack counts up under the same word
    /// (`player:1290`). Three words, and the percentage says how far in it is.
    @Test("There are three stage words and the script's three are they")
    func threeStages() {
        #expect(
            LoadingStage.Heading.allCases.map(\.rawValue)
                == ["OPENING", "READING", "READING DISC"]
        )
    }

    // MARK: - The two lines

    /// `$(fit "$4" 52)` (`player:1170`) — the same measure the track titles are
    /// set in, and the cut shows.
    @Test("A long filename is cut to the measure with the cut showing")
    func detailIsCut() {
        let long = String(repeating: "verylongname", count: 10) + ".flac"
        let stage = LoadingStage.reading(
            Record.Progress(read: 1, total: 2, filename: long), source: "Album"
        )
        #expect(Columns.width(of: stage.line) == PanelGrid.textWidth)
        #expect(stage.line.hasSuffix("…"))
    }

    /// **`SOURCE` is not cut on this screen and is cut on the next one**
    /// (`player:1169` prints `$SRC_LABEL` whole; `player:2329` fits it to 52).
    /// Kept rather than tidied: a zip with a very long name overruns this line
    /// and no other, and it has always done so.
    @Test("The source label is carried whole, unlike the panel's own SOURCE row")
    func sourceIsNotCut() {
        let long = String(repeating: "A", count: 120) + ".zip"
        let stage = LoadingStage.opening(source: long, total: 0)
        #expect(stage.source == long)
        #expect(Columns.width(of: stage.source) > PanelGrid.textWidth)
    }

    // MARK: - The bar

    /// The whole argument for the screen: the head advances one file at a time,
    /// so a wait is a count rather than a spinner (`player:1147`).
    @Test("The bar gains ground once per file")
    func oneStepPerFile() {
        let filled = (0...4).map { done -> Int in
            LoadingStage.opening(
                Unpacker.Progress(done: done, total: 4, name: "x"), source: "z"
            )
            .cells(width: 8)
            .filter { if case .runout = $0 { return false } else { return true } }
            .count
        }
        // Strictly increasing: four files across eight cells means every file
        // that lands is visible, which is the promise the screen makes.
        #expect(filled == filled.sorted())
        #expect(zip(filled, filled.dropFirst()).allSatisfy { $0 < $1 })
        #expect(filled.first == 0)
        #expect(filled.last == 8)
    }

    /// `[ "$head" -gt "$units" ] && head=$units` (`player:564`). An error line
    /// wears the same `x ` as a good one, so the count really can run past the
    /// total (`player:1288`) — and the meter is not allowed to.
    @Test("A count that runs past the total does not run past the bar")
    func headIsClamped() {
        let stage = LoadingStage.opening(
            Unpacker.Progress(done: 9, total: 4, name: "x"), source: "z"
        )
        let cells = stage.cells(width: 8)
        #expect(cells.count == 8)
        #expect(cells.allSatisfy { if case .band = $0 { return true } else { return false } })
    }

    /// The announcement is made with a total of nothing, because nothing has
    /// been counted yet. `[ "$total" -gt 0 ]` guards the same division
    /// (`player:1160`).
    @Test("A total of nothing draws an empty bar rather than dividing by it")
    func emptyTotal() {
        let cells = LoadingStage.opening(source: "Album.zip", total: 0).cells(width: 8)
        #expect(cells.count == 8)
        #expect(cells.allSatisfy { if case .runout = $0 { return true } else { return false } })
    }
}

/// The other of §10's last two boxes. The claim is not that a faceplate exists —
/// it is that **every** screen wears the same one, which is only worth asserting
/// now that there are enough screens for "every" to mean something.
@Suite("§10 — the faceplate on every stage")
struct FaceplateEveryStageTests {

    /// The five metas the port can put on a plate, one per screen.
    static var everyScreen: [String] {
        [
            // The now-playing panel (`player:2322`).
            Faceplate.meta(mode: .playing, trackCount: 9, source: .tags, level: "VOL 80"),
            // The picker (`player:1063`).
            Faceplate.pickerMeta(count: 4),
            // The loading stage (`player:1167`).
            LoadingStage.opening(
                Unpacker.Progress(done: 21, total: 50, name: "x"), source: "z"
            ).meta,
            // The check screen — the port's, see `Faceplate.checkMeta`.
            Faceplate.checkMeta(count: 14, warnings: 2, failures: 0),
            // The empty deck — the port's, and the ordinary meta with nothing
            // in it.
            Faceplate.meta(mode: .stopped, trackCount: 0, source: nil),
        ]
    }

    /// Badge, rule, meta — in that order, on all five.
    @Test("Every screen's plate is the badge, a rule, and its own meta")
    func sameLineEverywhere() {
        for meta in Self.everyScreen {
            let line = Faceplate.line(meta: meta)
            #expect(line.hasPrefix(String(repeating: " ", count: PanelGrid.margin)))
            #expect(line.contains("━"))
            #expect(line.hasSuffix(meta))
        }
    }

    /// The meta finishes flush with the right-hand edge of every bar below it,
    /// however long the state word is — which is the whole reason the rule is
    /// computed rather than fixed (`panel.sh:257`).
    @Test("Every screen's meta lands on the panel's own right-hand edge")
    func flushRightEverywhere() {
        for meta in Self.everyScreen {
            #expect(Faceplate.rule(meta: meta) > 2, "\(meta) squeezed the rule to its floor")
            #expect(Columns.width(of: Faceplate.line(meta: meta)) == PanelGrid.line, "\(meta)")
        }
    }

    /// Every stage word of the loading screen, at both ends of its percentage,
    /// still fits. `READING DISC` is the longest of the three and 100% is the
    /// widest tail it can wear.
    @Test("The longest loading meta still leaves a rule")
    func loadingFits() {
        for heading in LoadingStage.Heading.allCases {
            let stage = LoadingStage(
                heading: heading, source: "z", detail: "x",
                done: 1, total: 1, percent: 100
            )
            #expect(Columns.width(of: Faceplate.line(meta: stage.meta)) == PanelGrid.line)
        }
    }

    /// A mark that is not there is not printed: listing `0 ✗` is a way of
    /// raising the subject.
    @Test("The check plate names only the marks it has")
    func checkMarks() {
        #expect(Faceplate.checkMeta(count: 14, warnings: 0, failures: 0) == "SELF TEST · 14 CHECKS")
        #expect(
            Faceplate.checkMeta(count: 14, warnings: 2, failures: 1)
                == "SELF TEST · 14 CHECKS · 1 ✗ · 2 !"
        )
        #expect(Faceplate.checkMeta(count: 1, warnings: 0, failures: 0) == "SELF TEST · 1 CHECK")
    }
}
