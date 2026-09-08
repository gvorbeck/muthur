import Foundation

/// §20.2 — cutting a running order into discs.
///
/// `breaks_here` (`burncd:668`), `discs_needed` (`burncd:677`) and
/// `layout_discs` (`burncd:693`), which are one piece of arithmetic in three
/// parts and are kept together for the reason the script gives at
/// `burncd:721`: the fill loop and the counting loop **must apply the same
/// rule**, or the plan says two discs and the layout builds three. They are one
/// function here, `fill`, called by both.
enum DiscLayout {

    struct Result {
        /// Disc number, 1-based, for each playlist entry, in playlist order.
        let discOf: [Int]
        let discCount: Int
        /// What the balancing search settled on.
        let balancedCapacity: Int
    }

    /// Does a new disc start at this entry because someone asked for one?
    ///
    /// Three conditions, and the second and third are the interesting ones
    /// (`burncd:664`):
    ///
    /// - Entry 0 never breaks. It starts disc 1 already, and counting it would
    ///   open an empty disc in front of it.
    /// - The break is keyed by **source**, not position, so it follows the
    ///   track through a reorder.
    /// - The later parts of a `--split-long` cut never break, because the break
    ///   belongs to the track and the track begins at its first part.
    static func breaksHere(_ index: Int, sources: [Int], breaks: Set<Int>) -> Bool {
        guard index > 0 else { return false }
        guard breaks.contains(sources[index]) else { return false }
        return sources[index] != sources[index - 1]
    }

    /// The greedy fill. Returns a disc number per entry, and therefore also the
    /// count.
    ///
    /// Album order is preserved absolutely — this packs forwards and never
    /// reorders to make something fit, because the running order is the whole
    /// point of the record and a bin-packer that improves it has destroyed it.
    private static func fill(
        durations: [Int], sources: [Int], breaks: Set<Int>, capacity: Int
    ) -> [Int] {
        var discOf: [Int] = []
        discOf.reserveCapacity(durations.count)
        var running = 0
        var trackCount = 0
        var disc = 1

        for i in durations.indices {
            let duration = durations[i]
            let forced = breaksHere(i, sources: sources, breaks: breaks)
            if forced || running + duration > capacity || trackCount >= BurnLimits.maxTracks {
                disc += 1
                running = duration
                trackCount = 1
            } else {
                running += duration
                trackCount += 1
            }
            discOf.append(disc)
        }
        return discOf
    }

    /// `discs_needed` — how many discs a given per-disc capacity takes.
    ///
    /// Returns nil where the script returns 0: one entry is longer than the
    /// capacity being tried, so no number of discs of that size will hold it.
    /// The binary search reads that as "too small" and moves on; it is not an
    /// error here, because `BurnPlan.flatten` has already refused or split
    /// anything longer than a real disc.
    static func discsNeeded(
        durations: [Int], sources: [Int], breaks: Set<Int>, capacity: Int
    ) -> Int? {
        guard durations.allSatisfy({ $0 <= capacity }) else { return nil }
        guard !durations.isEmpty else { return 1 }
        return fill(durations: durations, sources: sources, breaks: breaks, capacity: capacity).last
    }

    /// `layout_discs`. Find the fewest discs, then the smallest disc that still
    /// fits in that many, then fill at that size.
    ///
    /// The second step is what stops a 128-minute set becoming 79:57 and then a
    /// 48-minute stub. Greedy filling at the full capacity is right about *how
    /// many* discs and wrong about *where* they end, so the search asks the
    /// same question again at every smaller size and keeps the smallest answer
    /// that has not cost an extra disc: 60 + 68, not 79 + 49.
    ///
    /// A forced break needs nothing special here, and the script's note at
    /// `burncd:706` is the argument: breaks only ever end a disc early, never
    /// overflow one, so every capacity the search tries still fits in the same
    /// number of discs it would have without them — and the tracks either side
    /// of a break go on balancing among themselves.
    static func of(_ entries: [BurnPlan.Slice], breaks: Set<Int>, capacity: Int) -> Result {
        let durations = entries.map(\.duration)
        let sources = entries.map(\.source)

        guard !durations.isEmpty else {
            return Result(discOf: [], discCount: 0, balancedCapacity: capacity)
        }

        let needed =
            discsNeeded(durations: durations, sources: sources, breaks: breaks, capacity: capacity)
            ?? 1

        // The floor is the longest single entry: below that nothing fits at all
        // and `discsNeeded` stops answering. The ceiling is a real disc.
        var low = durations.max() ?? 0
        var high = capacity
        while low < high {
            let mid = (low + high) / 2
            if let r = discsNeeded(
                durations: durations, sources: sources, breaks: breaks, capacity: mid
            ), r <= needed {
                high = mid
            } else {
                low = mid + 1
            }
        }
        let balanced = low

        let discOf = fill(
            durations: durations, sources: sources, breaks: breaks, capacity: balanced
        )
        return Result(
            discOf: discOf, discCount: discOf.last ?? 1, balancedCapacity: balanced
        )
    }
}
