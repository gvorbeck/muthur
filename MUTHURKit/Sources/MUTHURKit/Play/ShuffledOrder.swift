import Foundation

/// D4. A shuffled **order**, not a die roll per advance.
///
/// Bash re-rolls `RANDOM % n` and rejects only the current track
/// (`player:3423`, `player:3441`, `player:3479`), so a track can come round
/// twice in three plays and another can sit out the whole sitting. This is one
/// permutation of the rows, walked through — every track once before any track
/// twice, which is what the word means.
///
/// Two lists, and they do different jobs:
///
/// - `pending` is the permutation, what is left to hear.
/// - `history` is what was actually played, in the order it was played, which is
///   what `p` walks back through. `row - 1` under shuffle means the row above in
///   *album* order — a track you have not heard (`player:3462`).
///
/// `position` is where in the history you are. Walking back and forward again
/// lands where you were, because forward means "next in the history" until the
/// history runs out and only then means "next in the order".
public struct ShuffledOrder: Sendable, Equatable {
    public private(set) var history: [Int]
    public private(set) var position: Int
    private var pending: [Int]

    /// Shuffle covers **what is left to hear** — the track playing now stays
    /// playing and becomes the first entry of the history (§6.1b).
    public init<G: RandomNumberGenerator>(rows: Int, startingAt row: Int, using generator: inout G) {
        pending = (0..<rows).filter { $0 != row }.shuffled(using: &generator)
        history = rows > 0 ? [row] : []
        position = history.isEmpty ? -1 : 0
    }

    public var current: Int? {
        history.indices.contains(position) ? history[position] : nil
    }

    /// Nil is the end of the album. Every track has had its turn, which is the
    /// honest reading of a shuffled record ending and the one bash could not
    /// make (§6.1b).
    public mutating func advance() -> Int? {
        if position + 1 < history.count {
            position += 1
            return history[position]
        }
        guard !pending.isEmpty else { return nil }
        let row = pending.removeFirst()
        history.append(row)
        position = history.count - 1
        return row
    }

    /// Nil at the top of the history — there is nothing before the first thing
    /// you heard, and §6.1's rule for that is that the track restarts.
    public mutating func back() -> Int? {
        guard position > 0 else { return nil }
        position -= 1
        return history[position]
    }

    /// `⏎` under shuffle: play it, and the order continues from there. Not a
    /// reshuffle, and it does not turn shuffle off (§6.1b).
    ///
    /// The history is truncated at the current position first, because anything
    /// after it was read ahead and never heard — and `p` walks what was actually
    /// played.
    public mutating func pick(_ row: Int) {
        if position >= 0 && position + 1 < history.count {
            history.removeSubrange((position + 1)...)
        }
        history.append(row)
        position = history.count - 1
        pending.removeAll { $0 == row }
    }

    /// REPEAT ALBUM over a shuffled record. A new permutation, and it may not
    /// open with the track that just closed the old one or the reshuffle is
    /// audible as a track playing twice in a row (§6.1b).
    public mutating func reshuffle<G: RandomNumberGenerator>(
        rows: Int, avoiding row: Int, using generator: inout G
    ) -> Int? {
        var next = (0..<rows).shuffled(using: &generator)
        if next.count > 1, next[0] == row {
            // Swap with any other position rather than reshuffling until it
            // comes out right — one exchange is uniform enough for this and
            // cannot loop.
            let other = Int.random(in: 1..<next.count, using: &generator)
            next.swapAt(0, other)
        }
        guard let first = next.first else {
            history = []
            position = -1
            pending = []
            return nil
        }
        pending = Array(next.dropFirst())
        history = [first]
        position = 0
        return first
    }

    /// Put the position back where the *ear* is. The engine reads ahead, so the
    /// order may already have been walked past the track you can hear; `n` and
    /// `p` are answers to what is playing, not to what is decoded.
    mutating func settle(at index: Int) {
        guard history.indices.contains(index) else { return }
        position = index
    }
}

/// A seedable generator, so a shuffle can be a test rather than a hope.
///
/// SplitMix64. Production seeds it from the system generator at launch; the
/// suites seed it with a number, which is the only way to assert that a
/// permutation covers every row exactly once and that a reshuffle did not open
/// with the track that just closed.
public struct SeededGenerator: RandomNumberGenerator, Sendable, Equatable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public init() {
        var system = SystemRandomNumberGenerator()
        state = system.next()
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
