import Foundation

/// §10's loading stage — the same panel, for the seconds a zip takes to come out
/// of its archive (`player:1147`).
///
/// `load_stage`, whole (`player:1152`):
///
///     load_stage() {  # load_stage <title> <done> <total> <line>
///       …
///       [ "$3" -gt 0 ] && head=$(( $2 * STRIP_WIDTH * 8 / $3 ))
///       bands $(( STRIP_WIDTH * 8 )) 1
///       trackbar "$2" "$3"
///       frame=$(
///         faceplate "$1"
///         printf '\n'
///         printf '    %b%-8s%b %s\n' "$ETCH" SOURCE "$OFF" "$SRC_LABEL"
///         printf '\n'
///         printf '    %b%-8s%b %s\n' "$ETCH" READING "$OFF" "$(fit "$4" 52)"
///         printf '\n'
///         printf '  %b▐%b%b%b▌%b\n' "$ETCH" "$OFF" "$TRACKBAR" "$ETCH" "$OFF"
///       )
///       paint "$frame"
///     }
///
/// **The bar is the album meter with no bands yet — one per file as they land,
/// which is the honest picture of the wait.** That is the script's own comment
/// (`player:1147`) and it is the whole argument for the screen: an album that
/// takes eight seconds to unpack is not a spinner, it is forty-one files, and
/// the thing that knows how many have landed should say so.
///
/// **Four oddities, kept.**
///
/// 1. **The second label is always `READING`**, whatever the stage is — so the
///    frame that says `OPENING · 42%` at the top says `READING  track04.flac`
///    three lines down. It reads as the machine reading the file it is
///    currently opening, which is nearly true, and it is what a person watching
///    the panel has always seen.
/// 2. **`SOURCE` is not cut here** and it is cut on the now-playing panel
///    (`player:2330` fits it to 52; `player:1169` does not). A zip with a very
///    long name overruns this line and no other.
/// 3. **`head` is computed and never used** (`player:1160`). `trackbar` works it
///    out again from the same two numbers a line later. Dead, and left where it
///    is rather than carried over.
/// 4. **`bands` is called and its answer thrown away** (`player:1161`) — the
///    frame prints `$TRACKBAR` and never `$BEND`/`$BCOL`. One band across the
///    whole strip is what the album meter would be with a single track in it, so
///    the call is the comment's sentence written out in code, and the sentence
///    is the part that survived. Not carried over either; `Meter.trackCells` is
///    already that bar.
public struct LoadingStage: Sendable, Equatable {

    /// The three stages, and only these three. The port had grown a fourth —
    /// `UNPACKING` — which the script does not have: `open_source` announces
    /// `OPENING` before the archive is touched (`player:1398`) and the unpack
    /// itself counts up under the same word (`player:1290`, `player:1360`). One
    /// word for one job, and the percentage is what says how far in it is.
    public enum Heading: String, Sendable, Equatable, CaseIterable {
        case opening = "OPENING"
        case reading = "READING"
        case readingDisc = "READING DISC"
    }

    public let heading: Heading
    /// `$SRC_LABEL` — the zip or folder this is all about.
    public let source: String
    /// The fourth argument: the file or the step being worked on right now.
    public let detail: String
    /// `<done>` and `<total>`, in whatever units this stage counts — files for
    /// the two that count files, steps for the disc.
    public let done: Int
    public let total: Int
    /// Whether the faceplate carries a percentage. **Nil is not zero**: two of
    /// the script's four calls print the bare heading, and a `0%` where the
    /// script printed nothing would be a claim about progress rather than the
    /// absence of one.
    public let percent: Int?

    public init(
        heading: Heading, source: String, detail: String,
        done: Int, total: Int, percent: Int?
    ) {
        self.heading = heading
        self.source = source
        self.detail = detail
        self.done = done
        self.total = total
        self.percent = percent
    }

    // MARK: - The four call sites

    /// `load_stage "OPENING" 0 "$total" "$SRC_LABEL"` (`player:1398`) — before
    /// the archive is touched, so the detail is the archive itself.
    public static func opening(source: String, total: Int) -> LoadingStage {
        LoadingStage(
            heading: .opening, source: source, detail: source,
            done: 0, total: total, percent: nil
        )
    }

    /// `load_stage "OPENING · N%" "$n" "$total" "$(basename "$entry")"`
    /// (`player:1290`, `player:1360`).
    public static func opening(_ progress: Unpacker.Progress, source: String) -> LoadingStage {
        LoadingStage(
            heading: .opening, source: source, detail: progress.name,
            done: progress.done, total: progress.total, percent: progress.percent
        )
    }

    /// `load_stage "READING · N%" "$n" "$total" "$(basename "$f")"`
    /// (`player:1491`).
    public static func reading(_ progress: Record.Progress, source: String) -> LoadingStage {
        LoadingStage(
            heading: .reading, source: source, detail: progress.filename,
            done: progress.read, total: progress.total, percent: progress.percent
        )
    }

    /// `load_stage "READING DISC" 1 3 "looking for CD-Text"` and its two
    /// siblings (`player:2250`). **No percentage**: three steps is a count you
    /// can read, and 33% of asking MusicBrainz a question is not a fact.
    public static func disc(_ stage: DiscTitles.Stage, source: String) -> LoadingStage {
        LoadingStage(
            heading: .readingDisc, source: source, detail: stage.detail,
            done: stage.step, total: stage.of, percent: nil
        )
    }

    // MARK: - What the panel draws

    /// `faceplate "$1"` — the stage title, which is this screen's answer to the
    /// mode word on the now-playing panel and to `N SOURCES` on the picker.
    public var meta: String {
        guard let percent else { return heading.rawValue }
        return "\(heading.rawValue) · \(percent)%"
    }

    /// `$(fit "$4" 52)`. The one thing on this screen that *is* cut, and the
    /// same 52 the track titles are set in.
    public var line: String { Columns.fit(detail, to: PanelGrid.textWidth) }

    /// The label the detail sits against. A constant, and see oddity 1.
    public static let detailLabel = "READING"

    /// `trackbar "$2" "$3"` — the head at done-over-total, in eighths, with
    /// everything behind it one band and everything ahead of it run-out.
    public func cells(width: Int = PanelGrid.stripWidth) -> [Meter.Cell] {
        Meter.trackCells(done: done, total: total, width: width)
    }
}
