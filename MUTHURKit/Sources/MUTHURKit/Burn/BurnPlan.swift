import Foundation

/// §20 — the two hard numbers a Red Book disc is made of.
///
/// Source references in this directory are `burncd:NNNN` for
/// `/Users/garrett.vorbeck/Sites/cd-collection/scripts/burncd/burncd`, the
/// second program in the collection and read-only exactly as `player` is.
public enum BurnLimits {

    /// 4797 seconds — 79:57, and **not** 80:00 (`burncd:178`).
    ///
    /// A blank sold as "80 minute" holds 359,849 sectors at 75 a second, which
    /// is 79:57. The extra three seconds on the packaging are rounding, and a
    /// plan that believes them is a burn that dies in the run-out. Track
    /// lengths are rounded up when they are read (`Track.roundedUp`), so aiming
    /// at the true figure is the safe direction to be wrong in.
    public static let capacity = 4797

    /// 99 (`burncd:122`). The Red Book ceiling, and it is a limit on *count*
    /// rather than on runtime: forty minutes of ninety-second pieces still
    /// needs two discs. `BurnPlan.splitReason` exists because "too long" is the
    /// wrong thing to tell someone whose album is nine minutes.
    public static let maxTracks = 99

    /// 2352 bytes — 588 stereo 16-bit samples (`burncd:123`).
    ///
    /// The unit a CD is addressed in, and therefore the unit a track boundary
    /// has to land on: the cue sheet's `INDEX` is a sector number and there is
    /// no way to say "one and a third of one". Every track in the image is
    /// padded out to a whole one of these.
    public static let sector = 2352

    /// 176,400 — 44100 Hz × 2 channels × 2 bytes (`burncd:124`).
    ///
    /// A second of the only format a Red Book disc holds, which makes it both
    /// the conversion's target and the arithmetic that turns a runtime into an
    /// image size before anything has been converted.
    public static let bytesPerSecond = 176_400

    /// 75 (`msf`, `burncd:156`). Frames a second, the third field of the MSF
    /// addressing a cue sheet is written in.
    public static let framesPerSecond = 75

    /// The disc the plan is cut against, when the operator has said it is not a
    /// standard blank (`burncd:173`–`179`).
    ///
    /// **Why this is here and not just the constant above.** `media_check`
    /// refuses a blank that is too small for the disc it was asked to hold, and
    /// the whole of that refusal's usefulness is its second half: *use an
    /// 80-minute disc, or set this and start again*. A remedy naming a variable
    /// nothing reads is worse than no remedy at all, so the variable is read.
    ///
    /// Seconds win over minutes where both are set, which is the script's own
    /// order — it asks for `BURNCD_SECONDS` first and only falls through to
    /// minutes.
    ///
    /// **A junk value falls back and says so, on D74's reasoning and now D75's.**
    /// The script's `numeric` dies, which is right for a program you invoked
    /// from a shell one second ago. This one was launched by launchd from an
    /// environment nobody is looking at, and refusing to plan a record because
    /// a stale export says `80min` is a worse answer than planning it against
    /// the disc everybody actually buys.
    public static func capacity(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> (seconds: Int, note: String?) {
        for (name, scale) in [
            ("MUTHUR_SECONDS", 1), ("BURNCD_SECONDS", 1),
            ("MUTHUR_MINUTES", 60), ("BURNCD_MINUTES", 60),
        ] {
            guard let raw = environment[name], !raw.isEmpty else { continue }
            // The script's own test, and `Cdrecord.speed`'s: whole and
            // unsigned, so `80min`, `-80` and `80.0` are all junk. Zero is junk
            // here too — a disc that holds nothing is not a disc anybody meant.
            if let value = Int(raw), value > 0, raw.allSatisfy(\.isNumber) {
                return (value * scale, nil)
            }
            return (
                capacity,
                "! \(name) must be a whole number, got: \(raw) — planning for \(Readout.discLength(capacity))"
            )
        }
        return (capacity, nil)
    }
}

/// What stopped a plan being made at all.
public enum PlanFailure: Error, Equatable, CustomStringConvertible {

    /// One file is longer than a whole disc and `--split-long` was not asked
    /// for (`burncd:631`). The script's message, both lines of it, because the
    /// second line is the entire remedy.
    case trackLongerThanDisc(title: String, duration: Int, capacity: Int)

    /// `burncd:651`. Reachable from an empty folder; not reachable from the
    /// editor, which refuses to drop the last track.
    case nothingToBurn

    public var description: String {
        switch self {
        case .trackLongerThanDisc(let title, let duration, let capacity):
            """
            "\(title)" is \(Readout.mmss(duration)), longer than a \
            \(Readout.mmss(capacity)) disc.
              Pass --split-long to cut it into equal parts across discs.
            """
        case .nothingToBurn:
            "no tracks left to burn"
        }
    }
}

/// The state a plan is derived from — the script's `ORDER`, `TITLES`,
/// `ARTISTS`, `ALBUM`, `ALBUM_ARTIST`, `YEAR` and `BREAK_AT`, in one value.
///
/// It is the *source* level and not the flattened playlist, which is the whole
/// of `burncd:882`: a track that had to be cut across two discs stays one row
/// and one name on the screen, and `BurnPlan.make` re-derives the cut after
/// every change. Everything the editor touches is in here, and none of it is a
/// file — nothing on this screen writes to the record on disk.
public struct PlanDraft: Sendable, Equatable {

    /// One source track, in scan order.
    public struct Row: Sendable, Equatable {
        public var title: String
        public var artist: String
        /// Seconds, rounded **up** (`burncd:447`, and `Track.roundedUp` is
        /// already the same rule read out of `player:1478`). Never down:
        /// underestimating runtime is how a burn dies at 99%.
        public let duration: Int

        public init(title: String, artist: String, duration: Int) {
            self.title = title
            self.artist = artist
            self.duration = duration
        }
    }

    /// Indexed by source index. Nothing is ever removed from here — dropping a
    /// track takes it out of `order`, so an undo can put it back where it was.
    public var rows: [Row]

    /// The running order: indices into `rows`.
    public var order: [Int]

    /// Where a disc has to change hands because someone pressed `s`. Keyed by
    /// **source index and not by position** (`burncd:656`), so a break survives
    /// the reordering that happens around it — and survives the track being
    /// dropped and the drop being undone, which a position would not.
    public var breaks: Set<Int>

    public var album: String
    public var albumArtist: String
    public var year: String

    /// Whether any file in the folder arrived without a track number.
    ///
    /// Read once, off the folder, and then left alone. The script sets
    /// `UNTAGGED` in the metadata loop (`burncd:432`) and never revisits it, so
    /// dropping the one untagged track does not turn the note off — which is
    /// right: the *order* on screen was still arrived at by filename, and that
    /// is what the note is warning about.
    public var orderedByFilename: Bool

    public init(
        rows: [Row], order: [Int], breaks: Set<Int> = [],
        album: String, albumArtist: String, year: String,
        orderedByFilename: Bool
    ) {
        self.rows = rows
        self.order = order
        self.breaks = breaks
        self.album = album
        self.albumArtist = albumArtist
        self.year = year
        self.orderedByFilename = orderedByFilename
    }

    /// The record on the deck, as a plan to burn it.
    ///
    /// **The ordering is already ported and is not done again here.** `burncd`
    /// sorts by disc, then track number, then a natural filename sort
    /// (`burncd:469`) and `player` sorts by disc, then track number, then a
    /// natural filename sort (`player:1501`) — the same three keys in the same
    /// order, which is why §3.1 covers both. `Record.order` is that sort, so
    /// the draft takes it rather than re-deriving it and risking two orders
    /// that disagree.
    ///
    /// The untagged fallback is the one thing `burncd` says out loud that
    /// `player` does not, and `Record.unnumberedCount` is the same fact §3
    /// already computes.
    public init(record: Record) {
        self.init(
            rows: record.tracks.map {
                Row(title: $0.title, artist: $0.artist, duration: $0.duration)
            },
            order: record.order,
            album: record.album,
            albumArtist: record.albumArtist,
            year: record.year,
            orderedByFilename: record.unnumberedCount > 0
        )
    }
}

/// §20.1 and §20.2 — the running order flattened into what goes on discs, and
/// then cut into discs.
public struct BurnPlan: Sendable, Equatable {

    /// One thing that gets its own `TRACK` number on a disc.
    ///
    /// Usually a whole file. When `--split-long` had to cut one, it is a slice,
    /// and `offset`/`length` are what tell the converter to seek — stage 2's
    /// business, carried here because the plan is where the cut is decided.
    public struct Entry: Sendable, Equatable {
        /// Back to `PlanDraft.rows`. The script's `P_SRC` (`burncd:609`), and
        /// it is what `breaksHere` reads: the parts of one cut track share a
        /// source, so a break set on the track belongs to its first part.
        public let source: Int
        /// `P_TITLE` — with ` (part 1/2)` on it if this is a slice.
        public let title: String
        public let artist: String
        public let duration: Int
        /// `P_OFF` / `P_LEN`. Both nil for a whole file.
        public let offset: Int?
        public let length: Int?
        /// Which disc this landed on, once `layout` has said.
        public let disc: Int

        public var isSlice: Bool { offset != nil }
    }

    public let entries: [Entry]
    /// The sum of the ordered durations (`burncd:697`).
    public let total: Int
    public let discCount: Int
    /// What the balancer settled on — the smallest per-disc capacity that still
    /// fits in `discCount` discs. Kept because it is the number that explains
    /// the layout, and because a test that cannot see it can only assert the
    /// answer and not the rule.
    public let balancedCapacity: Int
    public let capacity: Int

    /// `ORDER_NOTE` (`burncd:483`), and the plan says it out loud because an
    /// order arrived at by filename is an order worth checking before you burn
    /// it into a lead-in permanently.
    public var orderNote: String {
        orderedByFilename
            ? "filename (some files have no track number)" : "embedded track numbers"
    }
    /// Whether `orderNote` is the warning one. Public because the screen has to
    /// decide whether the note is worth a row, and "ordered by embedded track
    /// numbers" is the case where it is not.
    public let orderedByFilename: Bool

    /// What was cut, and how many ways — the script's sentence at
    /// `burncd:768`, one per track that had to be cut.
    ///
    /// **One note per split track (D64)**, where the script keeps a single
    /// `SPLIT_NOTE` and overwrites it inside the loop (`burncd:647`) — so a
    /// folder holding two over-long files reported only the second one's part
    /// count, under a sentence beginning "A track was". The single-track
    /// wording is unchanged, because that is the case that actually happens;
    /// only where there is more than one does the title have to be named to
    /// tell them apart.
    public let splitNotes: [String]

    /// Which limit forced more than one disc, or nil when one disc was enough.
    ///
    /// `nil` inside a multi-disc plan is not a gap: a forced break splits a
    /// forty-minute album across two discs and neither limit was reached, so
    /// there is nothing to blame and the script prints the sentence without a
    /// reason (`burncd:780`).
    public enum SplitReason: Sendable, Equatable {
        case runtime
        case trackCount
        case both

        /// The script's own words (`burncd:770`).
        public var text: String {
            switch self {
            case .both: "too long and over \(BurnLimits.maxTracks) tracks"
            case .trackCount: "over the \(BurnLimits.maxTracks) track limit of a CD"
            case .runtime: "too long for one disc"
            }
        }
    }
    public let splitReason: SplitReason?

    /// The whole of `plan_header`'s multi-disc sentence (`burncd:778`).
    public var splitSentence: String? {
        guard discCount > 1 else { return nil }
        guard let splitReason else { return "Splitting across \(discCount) discs" }
        return "Splitting across \(discCount) discs — \(splitReason.text)"
    }

    /// The entries on one disc, in order.
    public func entries(onDisc disc: Int) -> [Entry] {
        entries.filter { $0.disc == disc }
    }

    /// How full one disc is, in seconds.
    public func runtime(onDisc disc: Int) -> Int {
        entries(onDisc: disc).reduce(0) { $0 + $1.duration }
    }

    /// Which disc a source track starts on, or nil if it is not in the plan.
    ///
    /// **First** and not only, because a cut track is on two discs and the one
    /// it starts on is the one its row on screen belongs to. Nil where the
    /// source was dropped — the plan is the running order, not the folder.
    public func firstDisc(ofSource source: Int) -> Int? {
        entries.first { $0.source == source }?.disc
    }

    // MARK: - Building it

    /// `build_playlist` (`burncd:617`) and then `layout_discs` (`burncd:693`).
    ///
    /// Rebuilt from scratch on every call, because the edit screen changes the
    /// order and the whole layout has to be derived again from the new one
    /// (`burncd:615`).
    public static func make(
        draft: PlanDraft,
        capacity: Int = BurnLimits.capacity,
        splitLong: Bool = false
    ) throws -> BurnPlan {
        let (flat, splitNotes) = try flatten(draft: draft, capacity: capacity, splitLong: splitLong)
        guard !flat.isEmpty else { throw PlanFailure.nothingToBurn }

        let total = flat.reduce(0) { $0 + $1.duration }
        let layout = DiscLayout.of(flat, breaks: draft.breaks, capacity: capacity)

        let entries = zip(flat, layout.discOf).map { slice, disc in
            Entry(
                source: slice.source, title: slice.title, artist: slice.artist,
                duration: slice.duration, offset: slice.offset, length: slice.length,
                disc: disc
            )
        }

        // Which limit to blame, decided on the whole plan rather than on the
        // disc that overflowed — the count is the playlist's and the runtime is
        // the record's, which is what `plan_header` compares (`burncd:770`).
        var reason: SplitReason?
        if layout.discCount > 1 {
            let overLong = total > capacity
            let overCount = flat.count > BurnLimits.maxTracks
            reason = overLong && overCount ? .both : overCount ? .trackCount : overLong ? .runtime : nil
        }

        return BurnPlan(
            entries: entries,
            total: total,
            discCount: layout.discCount,
            balancedCapacity: layout.balancedCapacity,
            capacity: capacity,
            orderedByFilename: draft.orderedByFilename,
            splitNotes: splitNotes,
            splitReason: reason
        )
    }

    /// A playlist entry before it knows which disc it is on.
    struct Slice {
        let source: Int
        let title: String
        let artist: String
        let duration: Int
        let offset: Int?
        let length: Int?
    }

    /// `build_playlist` (`burncd:617`). Flatten into play order, cutting
    /// anything that cannot fit on one disc into **equal** parts.
    ///
    /// Equal, so the tail is not a few-second stub (`burncd:635`): a
    /// ninety-five minute file becomes two of 47:30 and not 79:57 plus a
    /// sixteen-minute remainder.
    private static func flatten(
        draft: PlanDraft, capacity: Int, splitLong: Bool
    ) throws -> ([Slice], [String]) {
        var flat: [Slice] = []
        var cuts: [(title: String, parts: Int)] = []

        for source in draft.order {
            guard source >= 0, source < draft.rows.count else { continue }
            let row = draft.rows[source]

            if row.duration <= capacity {
                flat.append(
                    Slice(
                        source: source, title: row.title, artist: row.artist,
                        duration: row.duration, offset: nil, length: nil
                    )
                )
                continue
            }

            guard splitLong else {
                throw PlanFailure.trackLongerThanDisc(
                    title: row.title, duration: row.duration, capacity: capacity
                )
            }

            // Ceilings both times. The parts count has to cover the whole
            // track and the part length has to cover the whole track between
            // them, and rounding either down leaves audio with nowhere to go.
            let parts = (row.duration + capacity - 1) / capacity
            let partLength = (row.duration + parts - 1) / parts
            for part in 0..<parts {
                let offset = part * partLength
                let length = min(partLength, row.duration - offset)
                flat.append(
                    Slice(
                        source: source,
                        title: "\(row.title) (part \(part + 1)/\(parts))",
                        artist: row.artist,
                        duration: length,
                        offset: offset,
                        length: length
                    )
                )
            }
            cuts.append((row.title, parts))
        }

        let notes = cuts.map { cut in
            cuts.count == 1
                ? "A track was longer than one disc and was split \(cut.parts) ways"
                : "\"\(cut.title)\" was longer than one disc and was split \(cut.parts) ways"
        }
        return (flat, notes)
    }

    private init(
        entries: [Entry], total: Int, discCount: Int, balancedCapacity: Int,
        capacity: Int, orderedByFilename: Bool, splitNotes: [String],
        splitReason: SplitReason?
    ) {
        self.entries = entries
        self.total = total
        self.discCount = discCount
        self.balancedCapacity = balancedCapacity
        self.capacity = capacity
        self.orderedByFilename = orderedByFilename
        self.splitNotes = splitNotes
        self.splitReason = splitReason
    }
}
