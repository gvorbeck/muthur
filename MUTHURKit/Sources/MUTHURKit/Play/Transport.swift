import Foundation

/// What follows what. §6.1, §6.1b, §6.2 — the whole of the running order's
/// policy, and none of the audio.
///
/// It is separate from the engine because every rule in it is an argument about
/// intent — what `n` should do while REPEAT TRACK is on, what the end of a
/// shuffled record means — and those are worth being able to test without a
/// sound card, a file, or a clock.
public struct Transport: Sendable, Equatable {

    public enum Repeat: String, Sendable, CaseIterable {
        case off, album, track

        /// `r` cycles: off → album → track (`player:2704`).
        public var next: Repeat {
            switch self {
            case .off: .album
            case .album: .track
            case .track: .off
            }
        }

        public var label: String { rawValue.uppercased() }
    }

    /// What the engine should do next. `again` is the same track from the top
    /// without reopening it — REPEAT TRACK is the engine's own loop, because a
    /// track told to start again *after* it has finished is a file being opened
    /// during the silence (§6.1).
    public enum Move: Sendable, Equatable {
        case play(row: Int, historyIndex: Int?)
        case again
        case end
    }

    public private(set) var count: Int
    public private(set) var shuffle: Bool
    public var repeatMode: Repeat
    private var order: ShuffledOrder?
    private var generator: SeededGenerator

    public init(count: Int, seed: UInt64? = nil) {
        self.count = count
        self.shuffle = false
        self.repeatMode = .off
        self.order = nil
        self.generator = seed.map(SeededGenerator.init(seed:)) ?? SeededGenerator()
    }

    public var shuffledOrder: ShuffledOrder? { order }

    // MARK: - Turning shuffle on and off

    /// Switching shuffle on mid-record: the track playing now stays playing and
    /// the shuffle covers what is left. Switching it off returns to album order
    /// from wherever the needle is — which needs nothing done to it, because
    /// album order is derived from the row and not remembered (§6.1b).
    public mutating func setShuffle(_ on: Bool, from row: Int) {
        shuffle = on
        order = on ? ShuffledOrder(rows: count, startingAt: row, using: &generator) : nil
    }

    public mutating func toggleShuffle(from row: Int) {
        setShuffle(!shuffle, from: row)
    }

    /// Where the history says this playing of this row sits, for the engine to
    /// remember alongside it.
    public var historyIndex: Int? { order?.position }

    /// Put the history back where the ear is. The engine reads ahead, so the
    /// order may already have been walked past what you can hear.
    public mutating func settleHistory(at index: Int) {
        order?.settle(at: index)
    }

    // MARK: - What follows

    /// A track ran out on its own.
    ///
    /// `historyIndex` is where the *feeder* is in the history, which under
    /// shuffle can be one entry ahead of the ear. Settling on it first is what
    /// makes reading ahead invisible to the policy.
    public mutating func follows(_ row: Int, historyIndex: Int?) -> Move {
        if repeatMode == .track { return .again }
        return step(from: row, historyIndex: historyIndex)
    }

    /// D3. `n` under REPEAT TRACK **advances**, and the mode stays on so the
    /// track it lands on is the one that then loops. Bash restarted the current
    /// track (`player:3414`) and its comment explains only the mechanism —
    /// setting the playlist position to the row it is already on is a no-op.
    /// Repeat-track governs what happens when a track runs out by itself; `n` is
    /// you saying otherwise.
    public mutating func next(from row: Int, historyIndex: Int?) -> Move {
        step(from: row, historyIndex: historyIndex)
    }

    private mutating func step(from row: Int, historyIndex: Int?) -> Move {
        guard count > 0 else { return .end }

        if shuffle {
            if let historyIndex { order?.settle(at: historyIndex) }
            if let next = order?.advance() {
                return .play(row: next, historyIndex: order?.position)
            }
            // The order is exhausted, and that is the end of the album — every
            // track has had its turn. Falling off the bottom of the *list* is
            // meaningless under shuffle; the row it fell off is the last one by
            // accident (`player:3473`).
            guard repeatMode == .album else { return .end }
            guard let first = order?.reshuffle(rows: count, avoiding: row, using: &generator)
            else { return .end }
            return .play(row: first, historyIndex: order?.position)
        }

        let next = row + 1
        if next < count { return .play(row: next, historyIndex: nil) }
        return repeatMode == .album ? .play(row: 0, historyIndex: nil) : .end
    }

    /// `p`. Within the first three seconds it goes to the previous track, after
    /// that to the start of this one. On track one it always restarts
    /// (`player:3457`). Under shuffle "the previous track" is the one you
    /// actually heard.
    public mutating func previous(
        from row: Int, historyIndex: Int?, position seconds: Double
    ) -> Move {
        guard seconds < Transport.restartAfter else { return .again }

        if shuffle {
            if let historyIndex { order?.settle(at: historyIndex) }
            guard let previous = order?.back() else { return .again }
            return .play(row: previous, historyIndex: order?.position)
        }

        return row > 0 ? .play(row: row - 1, historyIndex: nil) : .again
    }

    /// Three seconds, like every deck ever made (`player:3457`).
    public static let restartAfter: Double = 3

    /// `⏎` on a row. Under shuffle the order continues from there; it does not
    /// reshuffle and it does not turn shuffle off (§6.1b).
    public mutating func pick(_ row: Int, historyIndex: Int?) -> Move {
        if shuffle {
            if let historyIndex { order?.settle(at: historyIndex) }
            order?.pick(row)
            return .play(row: row, historyIndex: order?.position)
        }
        return .play(row: row, historyIndex: nil)
    }
}
