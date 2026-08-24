import Foundation
import Testing

@testable import MUTHURKit

/// §6.1, §6.1b and the end of §6.2 — what follows what.
///
/// Every rule here is an argument about intent rather than about audio, which is
/// why `Transport` is a struct with no sound card in it. A seeded generator makes
/// a shuffle a test rather than a hope.
@Suite("§6.1 Transport rules")
struct TransportRulesTests {

    // MARK: - Sequential

    @Test("A track that runs out plays the next one; the last one ends the record")
    func sequentialAdvance() {
        var transport = Transport(count: 3)
        #expect(transport.follows(0, historyIndex: nil) == .play(row: 1, historyIndex: nil))
        #expect(transport.follows(1, historyIndex: nil) == .play(row: 2, historyIndex: nil))
        #expect(transport.follows(2, historyIndex: nil) == .end)
    }

    @Test("REPEAT ALBUM sends the last track back to the first")
    func repeatAlbumWraps() {
        var transport = Transport(count: 3)
        transport.repeatMode = .album
        #expect(transport.follows(2, historyIndex: nil) == .play(row: 0, historyIndex: nil))
    }

    /// REPEAT TRACK is the engine's own loop — `.again` rather than
    /// `.play(row:)`, because a track told to start again *after* it has finished
    /// is a file being opened during the silence.
    @Test("REPEAT TRACK loops without reopening the file")
    func repeatTrackLoops() {
        var transport = Transport(count: 3)
        transport.repeatMode = .track
        #expect(transport.follows(1, historyIndex: nil) == .again)
        #expect(transport.follows(2, historyIndex: nil) == .again)
    }

    @Test("`r` cycles off → album → track → off")
    func repeatCycles() {
        #expect(Transport.Repeat.off.next == .album)
        #expect(Transport.Repeat.album.next == .track)
        #expect(Transport.Repeat.track.next == .off)
        #expect(Transport.Repeat.off.label == "OFF")
        #expect(Transport.Repeat.album.label == "ALBUM")
        #expect(Transport.Repeat.track.label == "TRACK")
    }

    // MARK: - D3

    /// The changed rule. `n` is you saying otherwise, and a transport key that
    /// visibly does nothing reads as a broken one.
    @Test("D3: `n` under REPEAT TRACK advances, and the mode stays on")
    func nextUnderRepeatTrackAdvances() {
        var transport = Transport(count: 3)
        transport.repeatMode = .track

        #expect(transport.next(from: 0, historyIndex: nil) == .play(row: 1, historyIndex: nil))
        // Still on, so the track it landed on is the one that now loops — which
        // is the half of D3 that makes it a change of intent rather than of key
        // binding.
        #expect(transport.repeatMode == .track)
        #expect(transport.follows(1, historyIndex: nil) == .again)
    }

    // MARK: - `p`

    @Test("`p` within three seconds goes back; after three seconds it restarts")
    func previousThreeSecondRule() {
        var transport = Transport(count: 3)
        #expect(
            transport.previous(from: 2, historyIndex: nil, position: 0.5)
                == .play(row: 1, historyIndex: nil)
        )
        #expect(transport.previous(from: 2, historyIndex: nil, position: 3) == .again)
        #expect(transport.previous(from: 2, historyIndex: nil, position: 90) == .again)
    }

    @Test("On track one `p` always restarts")
    func previousOnFirstTrack() {
        var transport = Transport(count: 3)
        #expect(transport.previous(from: 0, historyIndex: nil, position: 0) == .again)
    }
}

/// §6.1b. D4, all of it.
@Suite("§6.1b Shuffle")
struct ShuffleRulesTests {

    /// Walk a shuffled record from the first track to the end, collecting what
    /// was played.
    private func playThrough(rows: Int, seed: UInt64, from start: Int = 0) -> [Int] {
        var transport = Transport(count: rows, seed: seed)
        transport.setShuffle(true, from: start)
        var played = [start]
        var index = transport.historyIndex
        while case .play(let row, let history) = transport.follows(
            played.last!, historyIndex: index
        ) {
            played.append(row)
            index = history
            if played.count > rows * 4 { break }  // a runaway guard, not a rule
        }
        return played
    }

    /// The whole of D4's first box: a permutation, walked through. Bash could
    /// play a track twice in three advances and leave another out entirely.
    @Test("Every track plays once before any track plays twice", arguments: 0..<40 as Range<UInt64>)
    func everyTrackOnce(seed: UInt64) {
        let played = playThrough(rows: 12, seed: seed)
        #expect(played.count == 12, "the order did not cover the record: \(played)")
        #expect(Set(played).count == 12, "a track repeated: \(played)")
    }

    /// The track playing now stays playing, and the shuffle covers what is left
    /// to hear.
    @Test("Shuffle on mid-record keeps the current track and shuffles the rest")
    func shuffleFromTheMiddle() {
        let played = playThrough(rows: 8, seed: 99, from: 5)
        #expect(played.first == 5)
        #expect(Set(played) == Set(0..<8))
        #expect(played.count == 8)
    }

    /// The order running out is the end of the album. Note the record ends on
    /// whatever row the permutation finished on — falling off the *bottom of the
    /// list* is meaningless under shuffle, and this is the box that says so.
    @Test("The order running out is the end of the album, whatever row it ended on")
    func exhaustedOrderEnds() {
        var transport = Transport(count: 6, seed: 7)
        transport.setShuffle(true, from: 0)
        var row = 0
        var index = transport.historyIndex
        for _ in 0..<5 {
            guard case .play(let next, let history) = transport.follows(row, historyIndex: index)
            else { Issue.record("the order ended early"); return }
            row = next
            index = history
        }
        #expect(transport.follows(row, historyIndex: index) == .end)
    }

    /// And under REPEAT ALBUM it reshuffles instead — but may not open with the
    /// track that just closed the old order, or the reshuffle is audible as a
    /// track playing twice in a row.
    @Test(
        "REPEAT ALBUM reshuffles and never opens with the track that just closed",
        arguments: 0..<40 as Range<UInt64>
    )
    func reshuffleDoesNotRepeatTheLastTrack(seed: UInt64) {
        var transport = Transport(count: 5, seed: seed)
        transport.repeatMode = .album
        transport.setShuffle(true, from: 0)

        var row = 0
        var index = transport.historyIndex
        for _ in 0..<4 {
            guard case .play(let next, let history) = transport.follows(row, historyIndex: index)
            else { Issue.record("the order ended early"); return }
            row = next
            index = history
        }
        let closed = row
        guard case .play(let opened, _) = transport.follows(row, historyIndex: index) else {
            Issue.record("REPEAT ALBUM did not reshuffle")
            return
        }
        #expect(opened != closed, "the reshuffle opened with the track that just closed")
    }

    /// `p` walks back through what was actually *played*, not `row - 1`. Under
    /// bash "previous" meant the row above in album order, which is a track you
    /// have not heard.
    @Test("`p` under shuffle walks the history, not the list")
    func previousWalksHistory() {
        var transport = Transport(count: 10, seed: 3)
        transport.setShuffle(true, from: 4)
        var index = transport.historyIndex

        guard case .play(let second, let secondIndex) = transport.follows(4, historyIndex: index)
        else { Issue.record("no advance"); return }
        index = secondIndex

        let back = transport.previous(from: second, historyIndex: index, position: 0)
        #expect(
            back == .play(row: 4, historyIndex: 0),
            "previous should be the track actually heard, not row \(second - 1)"
        )
    }

    /// Walking back and forward again should land where you were — which is what
    /// makes it a history rather than a re-roll.
    @Test("Back then forward lands where you were")
    func backAndForwardIsIdentity() {
        var transport = Transport(count: 10, seed: 11)
        transport.setShuffle(true, from: 0)

        guard case .play(let second, let atSecond) = transport.follows(0, historyIndex: nil),
            case .play(let third, let atThird) = transport.follows(second, historyIndex: atSecond)
        else { Issue.record("no advance"); return }

        guard case .play(let back, let atBack) = transport.previous(
            from: third, historyIndex: atThird, position: 0
        ) else { Issue.record("no step back"); return }
        #expect(back == second)

        // Forward again, and it must be the same third track rather than a fresh
        // roll of the dice.
        #expect(
            transport.follows(back, historyIndex: atBack) == .play(row: third, historyIndex: atThird)
        )
    }

    /// `⏎` plays it and the order continues from there. It does not reshuffle and
    /// it does not turn shuffle off.
    @Test("Picking a row under shuffle continues the order rather than reshuffling")
    func pickContinuesTheOrder() {
        var transport = Transport(count: 6, seed: 5)
        transport.setShuffle(true, from: 0)
        let before = transport.shuffledOrder

        guard case .play(let row, let index) = transport.pick(3, historyIndex: nil) else {
            Issue.record("pick did not play")
            return
        }
        #expect(row == 3)
        #expect(transport.shuffle, "picking a row turned shuffle off")
        #expect(transport.shuffledOrder != before, "the history did not move")
        #expect(transport.shuffledOrder?.history.last == 3)

        // What is left still covers the record exactly once. Row 0 was heard
        // before the pick and row 3 by it, so neither should come round again —
        // the pick took row 3 out of what was pending rather than leaving it
        // there.
        var played = [0, 3]
        var walking = index
        while case .play(let next, let history) = transport.follows(
            played.last!, historyIndex: walking
        ) {
            played.append(next)
            walking = history
            if played.count > 12 { break }
        }
        #expect(Set(played) == Set(0..<6), "the record was not covered: \(played)")
        #expect(Set(played).count == played.count, "a track repeated after a pick: \(played)")
    }

    /// Switching it off returns to album order from wherever the needle is —
    /// which needs nothing remembered, because album order is derived from the
    /// row.
    @Test("Shuffle off returns to album order from wherever the needle is")
    func shuffleOffResumesAlbumOrder() {
        var transport = Transport(count: 6, seed: 1)
        transport.setShuffle(true, from: 0)
        _ = transport.follows(0, historyIndex: nil)

        transport.setShuffle(false, from: 4)
        #expect(transport.shuffledOrder == nil)
        #expect(transport.follows(4, historyIndex: nil) == .play(row: 5, historyIndex: nil))
    }

    /// Reading ahead must be invisible to the policy: the order can be a step
    /// past the ear, and `n`/`p` are answers to what is *playing*.
    @Test("Settling the history puts the order back where the ear is")
    func settleUndoesReadAhead() {
        var transport = Transport(count: 8, seed: 21)
        transport.setShuffle(true, from: 0)

        // The feeder walks two entries ahead while the ear is still on the first.
        guard case .play(let second, let atSecond) = transport.follows(0, historyIndex: nil),
            case .play = transport.follows(second, historyIndex: atSecond)
        else { Issue.record("no advance"); return }

        // The ear is still on entry 0, so `p` from there is a restart — there is
        // nothing before the first thing you heard.
        #expect(transport.previous(from: 0, historyIndex: 0, position: 0) == .again)
    }

    /// One-track and empty records, because both exist and neither should be a
    /// special case anywhere else.
    @Test("A one-track record and an empty one")
    func degenerateRecords() {
        var one = Transport(count: 1, seed: 0)
        one.setShuffle(true, from: 0)
        #expect(one.follows(0, historyIndex: nil) == .end)

        var none = Transport(count: 0, seed: 0)
        none.setShuffle(true, from: 0)
        #expect(none.follows(0, historyIndex: nil) == .end)
        #expect(none.next(from: 0, historyIndex: nil) == .end)
    }
}
