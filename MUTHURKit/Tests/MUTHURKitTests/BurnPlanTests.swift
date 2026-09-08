import Foundation
import Testing

@testable import MUTHURKit

/// A draft of `count` tracks, each `each` seconds long, so a test can say what
/// it is about rather than what it is made of.
private func draft(
    _ durations: [Int],
    titles: [String]? = nil,
    breaks: Set<Int> = [],
    untagged: Bool = false
) -> PlanDraft {
    PlanDraft(
        rows: durations.enumerated().map { i, d in
            PlanDraft.Row(
                title: titles?[i] ?? "Track \(i + 1)", artist: "Someone", duration: d
            )
        },
        order: Array(durations.indices),
        breaks: breaks,
        album: "A Record", albumArtist: "Someone", year: "1979",
        orderedByFilename: untagged
    )
}

// MARK: - §20.1 The plan

@Suite("§20.1 — the burn plan")
struct BurnPlanTests {

    /// The size of an "80 minute" blank is 79:57, and believing the packaging
    /// is a burn that dies in the run-out (`burncd:178`).
    ///
    /// It reads `1:19:57` and not the script's `79:57`, which is **D60** doing
    /// what D60 decided: the port folds hours back in above sixty minutes,
    /// everywhere, and a disc capacity is not worth a second formatter. The
    /// sentence it appears in compares a track's runtime to it, and a runtime
    /// is exactly what D60 was written for.
    @Test("A disc is 4797 seconds, not 4800")
    func capacity() {
        #expect(BurnLimits.capacity == 4797)
        #expect(Readout.mmss(BurnLimits.capacity) == "1:19:57")
        #expect(BurnLimits.maxTracks == 99)
    }

    @Test("An album that fits is one disc, in the order it was given")
    func oneDisc() throws {
        let plan = try BurnPlan.make(draft: draft([200, 300, 250, 180]))
        #expect(plan.discCount == 1)
        #expect(plan.total == 930)
        #expect(plan.entries.map(\.source) == [0, 1, 2, 3])
        #expect(plan.entries.allSatisfy { $0.disc == 1 })
        #expect(plan.splitSentence == nil)
        #expect(plan.splitReason == nil)
    }

    /// The plan says where the order came from, because an order arrived at by
    /// filename is one worth checking before it goes into a lead-in
    /// permanently (`burncd:483`).
    @Test("The plan says it ordered by filename when it had to")
    func orderNote() throws {
        let tagged = try BurnPlan.make(draft: draft([100, 100]))
        #expect(tagged.orderNote == "embedded track numbers")

        let untagged = try BurnPlan.make(draft: draft([100, 100], untagged: true))
        #expect(untagged.orderNote == "filename (some files have no track number)")
    }

    /// **The point of the balancing search.** 128 minutes is two discs however
    /// you cut it, and greedy filling at the full capacity puts 79:57 on the
    /// first and a stub on the second. The search asks the same question again
    /// at every smaller size and keeps the smallest that has not cost a third
    /// disc (`burncd:709`).
    @Test("A 128-minute set becomes 60 + 68, not 79 + 49")
    func balanced() throws {
        // Sixteen eight-minute pieces: 7680 seconds, which is two discs.
        let plan = try BurnPlan.make(draft: draft(Array(repeating: 480, count: 16)))
        #expect(plan.discCount == 2)

        let first = plan.runtime(onDisc: 1)
        let second = plan.runtime(onDisc: 2)
        #expect(first + second == 7680)

        // Greedy at 4797 would take nine tracks (4320) and leave seven (3360).
        // Balanced takes eight and eight.
        #expect(first == 3840)
        #expect(second == 3840)
        #expect(plan.balancedCapacity < BurnLimits.capacity)
    }

    /// The rule the script writes down at `burncd:721`: the fill loop and the
    /// counting loop must agree, or the plan says two discs and the layout
    /// builds three. Asserted directly rather than trusted.
    @Test("The layout uses the same rule the count did")
    func layoutAndCountAgree() throws {
        for lengths in [
            Array(repeating: 480, count: 16),
            Array(repeating: 200, count: 40),
            [4000, 4000, 900, 100],
            Array(repeating: 61, count: 120),
        ] {
            let plan = try BurnPlan.make(draft: draft(lengths))
            let sources = plan.entries.map(\.source)
            let durations = plan.entries.map(\.duration)
            let needed = DiscLayout.discsNeeded(
                durations: durations, sources: sources, breaks: [],
                capacity: plan.balancedCapacity
            )
            #expect(needed == plan.discCount)
            for disc in 1...plan.discCount {
                #expect(plan.runtime(onDisc: disc) <= plan.balancedCapacity)
                #expect(plan.entries(onDisc: disc).count <= BurnLimits.maxTracks)
            }
        }
    }

    /// Runtime and the 99-track ceiling are very different problems, and "too
    /// long" is the wrong thing to tell someone whose album is nine minutes
    /// (`burncd:770`).
    @Test("The plan says which limit caused the split")
    func whichLimit() throws {
        let long = try BurnPlan.make(draft: draft(Array(repeating: 480, count: 16)))
        #expect(long.splitReason == .runtime)
        #expect(long.splitSentence == "Splitting across 2 discs — too long for one disc")

        // 120 tracks of a minute is two hours — over both limits at once.
        let both = try BurnPlan.make(draft: draft(Array(repeating: 60, count: 120)))
        #expect(both.splitReason == .both)

        // 120 tracks of five seconds is ten minutes and still two discs, and
        // "too long" would be a lie about it.
        let many = try BurnPlan.make(draft: draft(Array(repeating: 5, count: 120)))
        #expect(many.discCount == 2)
        #expect(many.splitReason == .trackCount)
        #expect(
            many.splitSentence == "Splitting across 2 discs — over the 99 track limit of a CD"
        )
    }

    /// A forced break splits a forty-minute album across two discs and neither
    /// limit was reached, so there is nothing to blame — and the script prints
    /// the sentence without a reason rather than inventing one (`burncd:780`).
    @Test("A break splits the record and blames no limit for it")
    func breakBlamesNothing() throws {
        let plan = try BurnPlan.make(draft: draft([600, 600, 600, 600], breaks: [2]))
        #expect(plan.discCount == 2)
        #expect(plan.splitReason == nil)
        #expect(plan.splitSentence == "Splitting across 2 discs")
        #expect(plan.entries(onDisc: 1).map(\.source) == [0, 1])
        #expect(plan.entries(onDisc: 2).map(\.source) == [2, 3])
    }

    /// A break is keyed by source and not by position (`burncd:656`), so it
    /// follows the track when the order changes around it.
    @Test("A break travels with its track through a reorder")
    func breakTravels() throws {
        var d = draft([600, 600, 600, 600], breaks: [2])
        d.order = [2, 0, 1, 3]
        let plan = try BurnPlan.make(draft: d)
        // Track 2 is now first, and entry 0 never breaks — it starts disc 1
        // already, and counting it would open an empty disc in front of it.
        #expect(plan.discCount == 1)
    }

    @Test("A track longer than a disc is refused, and says how to proceed")
    func refusesTheOverlong() {
        let d = draft([5000], titles: ["A Very Long Piece"])
        #expect(throws: PlanFailure.self) { try BurnPlan.make(draft: d) }
        do {
            _ = try BurnPlan.make(draft: d)
        } catch let failure as PlanFailure {
            let text = failure.description
            #expect(text.contains("A Very Long Piece"))
            #expect(text.contains("1:23:20"))
            #expect(text.contains("1:19:57"))
            #expect(text.contains("--split-long"))
        } catch {
            Issue.record("wrong error")
        }
    }

    /// Equal parts, so the tail is not a few-second stub (`burncd:635`).
    @Test("--split-long cuts into equal parts, not a disc and a remainder")
    func splitLong() throws {
        let plan = try BurnPlan.make(
            draft: draft([5700], titles: ["Long"]), splitLong: true
        )
        #expect(plan.entries.count == 2)
        #expect(plan.entries.map(\.duration) == [2850, 2850])
        #expect(plan.entries.map(\.title) == ["Long (part 1/2)", "Long (part 2/2)"])
        #expect(plan.entries.map(\.offset) == [0, 2850])
        #expect(plan.entries.allSatisfy { $0.isSlice })
        // Both parts came off one file, and both know it.
        #expect(plan.entries.map(\.source) == [0, 0])
    }

    /// The later parts of a cut track never take a break, because the break
    /// belongs to the track and the track begins at its first part
    /// (`burncd:666`).
    ///
    /// A cut track needs more than one disc by definition, so the thing to
    /// watch is that a break on it does not buy a *further* one: with the break
    /// and without it, the same number of discs and the same second part
    /// beginning disc two.
    @Test("A cut track's later parts do not break a disc")
    func slicesDoNotBreak() throws {
        let plain = try BurnPlan.make(
            draft: draft([5700, 600], titles: ["Long", "Short"]), splitLong: true
        )
        let broken = try BurnPlan.make(
            draft: draft([5700, 600], titles: ["Long", "Short"], breaks: [0]),
            splitLong: true
        )
        #expect(plain.entries.count == 3)
        #expect(broken.entries.count == 3)
        #expect(broken.discCount == plain.discCount)
        #expect(broken.entries.map(\.disc) == plain.entries.map(\.disc))
        // The break is on source 0, and entry 1 is source 0's second part.
        #expect(!DiscLayout.breaksHere(1, sources: broken.entries.map(\.source), breaks: [0]))
    }

    /// **D64.** The script assigns `SPLIT_NOTE` inside the loop
    /// (`burncd:647`), so a folder with two over-long files reported only the
    /// second one's part count. One note each — and the single-track wording,
    /// which is the case that actually happens, is unchanged.
    @Test("Every split track gets its own note, and one alone keeps its wording")
    func splitNotes() throws {
        let one = try BurnPlan.make(
            draft: draft([5700], titles: ["Long"]), splitLong: true
        )
        #expect(one.splitNotes == ["A track was longer than one disc and was split 2 ways"])

        let two = try BurnPlan.make(
            draft: draft([5700, 14000], titles: ["Long", "Longer"]), splitLong: true
        )
        #expect(two.splitNotes.count == 2)
        #expect(two.splitNotes[0].contains("\"Long\""))
        #expect(two.splitNotes[0].contains("2 ways"))
        #expect(two.splitNotes[1].contains("\"Longer\""))
        #expect(two.splitNotes[1].contains("3 ways"))
    }

    /// A hundred one-minute pieces is 100 minutes of runtime and 100 tracks,
    /// and either one alone would split it. It is the count that has to hold at
    /// the boundary: 99 on the first disc and not 100.
    @Test("The 99-track ceiling is a ceiling on count, whatever the runtime")
    func redBookCeiling() throws {
        // Two hundred five-second pieces: seventeen minutes, and three discs.
        let plan = try BurnPlan.make(draft: draft(Array(repeating: 5, count: 200)))
        #expect(plan.splitReason == .trackCount)
        for disc in 1...plan.discCount {
            #expect(plan.entries(onDisc: disc).count <= 99)
        }
        #expect(plan.entries.count == 200)
    }

    /// The plan is derived from the running order and nothing else, so the same
    /// order gives the same plan however it was arrived at.
    @Test("A reordered draft plans as though it had always been in that order")
    func orderIsTheOnlyInput() throws {
        var moved = draft([600, 300, 900])
        moved.order = [2, 0, 1]
        let plan = try BurnPlan.make(draft: moved)
        #expect(plan.entries.map(\.duration) == [900, 600, 300])
        #expect(plan.entries.map(\.title) == ["Track 3", "Track 1", "Track 2"])
    }

    @Test("A dropped track leaves the plan and takes its runtime with it")
    func dropped() throws {
        var d = draft([600, 300, 900])
        d.order = [0, 2]
        let plan = try BurnPlan.make(draft: d)
        #expect(plan.total == 1500)
        #expect(plan.entries.count == 2)
    }

    @Test("An empty order is nothing to burn")
    func empty() {
        var d = draft([600])
        d.order = []
        #expect(throws: PlanFailure.nothingToBurn) { try BurnPlan.make(draft: d) }
    }
}

// MARK: - §20.2 The layout

@Suite("§20.2 — cutting into discs")
struct DiscLayoutTests {

    /// Entry 0 never breaks: it starts disc 1 already, and counting it would
    /// open an empty disc in front of it (`burncd:662`).
    @Test("The first entry never starts a new disc")
    func firstNeverBreaks() {
        #expect(!DiscLayout.breaksHere(0, sources: [3, 4, 5], breaks: [3]))
        #expect(DiscLayout.breaksHere(1, sources: [3, 4, 5], breaks: [4]))
        #expect(!DiscLayout.breaksHere(1, sources: [3, 4, 5], breaks: [5]))
    }

    /// A break belongs to a track, and the second part of a cut track is not
    /// the start of that track.
    @Test("Two entries off one file take one break between them")
    func slicesShareASource() {
        let sources = [0, 1, 1, 2]
        #expect(DiscLayout.breaksHere(1, sources: sources, breaks: [1]))
        #expect(!DiscLayout.breaksHere(2, sources: sources, breaks: [1]))
    }

    /// Below the longest single entry nothing fits at all, and the search has
    /// to read that as "too small" rather than as an answer.
    @Test("A capacity smaller than the longest track has no answer")
    func noAnswer() {
        #expect(
            DiscLayout.discsNeeded(durations: [500, 900], sources: [0, 1], breaks: [], capacity: 800)
                == nil
        )
        #expect(
            DiscLayout.discsNeeded(durations: [500, 900], sources: [0, 1], breaks: [], capacity: 900)
                == 2
        )
    }

    /// The balancing search must never buy a smaller disc with an extra one.
    /// Checked against the greedy count at full capacity, which is the fewest
    /// discs by construction.
    @Test("Balancing never costs a disc")
    func neverCostsADisc() throws {
        var seed: UInt64 = 0x5EED
        func next(_ bound: Int) -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int(seed >> 33) % bound
        }
        for _ in 0..<200 {
            let lengths = (0..<(3 + next(30))).map { _ in 30 + next(900) }
            let plan = try BurnPlan.make(draft: draft(lengths))
            let greedy = DiscLayout.discsNeeded(
                durations: lengths, sources: Array(lengths.indices), breaks: [],
                capacity: BurnLimits.capacity
            )
            #expect(plan.discCount == greedy)
            // And it is the *smallest* such capacity: one second less needs more.
            if plan.balancedCapacity > lengths.max()! {
                let tighter = DiscLayout.discsNeeded(
                    durations: lengths, sources: Array(lengths.indices), breaks: [],
                    capacity: plan.balancedCapacity - 1
                )
                #expect(tighter == nil || tighter! > plan.discCount)
            }
        }
    }

    /// Album order is the point of the record. A packer that reorders to make
    /// something fit has improved the plan by destroying it.
    @Test("Discs are filled forwards and the order is never touched")
    func orderIsPreserved() throws {
        let plan = try BurnPlan.make(draft: draft(Array(repeating: 400, count: 30)))
        #expect(plan.entries.map(\.source) == Array(0..<30))
        // And the disc numbers only ever go up.
        #expect(zip(plan.entries, plan.entries.dropFirst()).allSatisfy { $0.disc <= $1.disc })
    }
}
