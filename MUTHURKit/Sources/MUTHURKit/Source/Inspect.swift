import Foundation

/// §12 — `-n`, the run that reads the record and plays none of it.
///
/// `player:3540`, whole:
///
///     if [ "$DRY_RUN" -eq 1 ]; then
///       screen_off
///       printf '\n  %s — %s (%s)\n' "${ALBUM:-—}" "${ALBUM_ARTIST:-—}" "${YEAR:-—}"
///       printf '  %d tracks, %s, from %s\n\n' "${#ORDER[@]}" "$(mmss "$TOTAL")" "$META_SOURCE"
///       i=1
///       for k in "${ORDER[@]}"; do
///         printf '   %2d. %s %6s\n' "$i" "$(fit "${TITLES[$k]}" 52)" "$(mmss "${DURS[$k]}")"
///         i=$(( i + 1 ))
///       done
///       printf '\n'
///       exit 0
///     fi
///
/// It sits *after* `open_source`, `read_metadata` and `order_tracks`
/// (`player:3535`) and before the panel, so a dry run does every expensive
/// thing a real run does except put a needle down — a zip is unpacked in full,
/// a disc is asked who it is. That is the point of it: what it prints is what
/// the panel would have shown, arrived at the same way, which is only worth
/// anything if it took the same road.
///
/// **The whole of it is printing.** Nothing here draws, nothing here waits for
/// a key, and the one thing it needs from the app is somewhere to put the
/// bytes — so it lives in the kit and the app is three lines around it.
public enum Inspect {

    /// What came of it. `.printed` goes to stdout and exits 0; `.died` is the
    /// script's `die()` (`panel.sh:265`) — stderr, exit 1 — and the caller
    /// wears the program name, because `die` prints `$APP` and this does not
    /// know what it was invoked as.
    public enum Outcome: Sendable, Equatable {
        case printed(String)
        case died(String)
    }

    /// The width `fit` is given for a title (`player:3546`). Fifty-two, and
    /// nothing anywhere says why — it is a terminal's worth of room with the
    /// number and the duration taken off, decided once and left alone.
    static let titleWidth = 52

    /// How wide the duration column is: `%6s` (`player:3546`).
    static let clockWidth = 6

    // MARK: - The printing

    /// The record, as `-n` prints it.
    ///
    /// **Four things here look wrong and are kept anyway.**
    ///
    /// 1. `%d tracks` is unconditionally plural, so a single is `1 tracks`.
    ///    The panel's own picker got this right (`PickerEntry.folderDetail`),
    ///    which means somebody thought about it *there* and did not come back
    ///    here. Matched rather than mended: the line is not a sentence, it is a
    ///    field, and a port that quietly improves one field is a port nobody
    ///    can diff.
    /// 2. The separator between album and artist is an em dash, and so is the
    ///    `:-` fallback for all three fields — so a record with nothing tagged
    ///    on it prints `— — — (—)`, which reads as a rule rather than as three
    ///    absences.
    /// 3. `%2d` is the *row*, not the track number, and it is two places wide.
    ///    A hundred-track box set pushes every line one column right from a
    ///    hundred on.
    /// 4. The title is padded to exactly 52 even when the duration that follows
    ///    it would have lined up anyway, and the duration is right-aligned in
    ///    six even when it is four characters long. Both are `printf`, and both
    ///    are reproduced by hand below rather than by `Columns.fit`, because
    ///    `fit` truncates with an ellipsis and `%6s` does not truncate at all.
    ///
    /// **The year is not `record.year`**, and that is §12's third requirement.
    /// The script has one global `YEAR` that MusicBrainz overwrites
    /// (`player:2215`) and the panel and the dry run both print, so they cannot
    /// disagree. Here the tag year, the lookup and the shelf are three separate
    /// values and the precedence that picks between them lives in
    /// `HeaderBlock.year` (D6). Calling it from here rather than reimplementing
    /// it is the only way `-n` and the panel stay the one year the script had.
    public static func text(
        record: Record, titleSource: TitleSource,
        releaseYear: String? = nil, shelf: HeaderBlock.Shelf? = nil
    ) -> String {
        let year = HeaderBlock.year(
            tags: record.year, musicBrainz: releaseYear, collection: shelf?.year
        )
        var out = "\n  \(orDash(record.album)) — \(orDash(record.albumArtist))"
        out += " (\(orDash(year)))\n"
        out += "  \(record.order.count) tracks, \(Readout.mmss(record.total))"
        out += ", from \(titleSource.rawValue)\n\n"

        for (row, track) in record.running.enumerated() {
            // `%2d`: padded to two, never cut.
            let number = String(format: "%2d", row + 1)
            // `$(fit "$title" 52)`, which is the panel's own width arithmetic
            // (`fit`, `panel.sh:368`) and is therefore `Columns.fit`.
            let title = Columns.fit(track.title, to: titleWidth)
            out += "   \(number). \(title) \(clock(track.duration))\n"
        }

        return out + "\n"
    }

    /// `%6s` exactly: right-aligned in six, and left alone when it is longer.
    /// A record with sixteen hours on it is not a case worth an ellipsis.
    private static func clock(_ seconds: Int) -> String {
        let text = Readout.mmss(seconds)
        let short = max(0, clockWidth - text.count)
        return String(repeating: " ", count: short) + text
    }

    /// `${X:-—}`. Bash's `:-` fires on unset *and* on empty, and everything
    /// arriving here is a `String` that has already been read, so empty is the
    /// only absence there is.
    private static func orDash(_ text: String) -> String {
        text.isEmpty ? "—" : text
    }

    // MARK: - Getting a record to print

    /// The whole flag: find the source the same way a real run finds it, open
    /// it, print it.
    ///
    /// **The one place this cannot follow the script, and the line that says
    /// what to do instead.** `player -n` with no argument runs the *picker*
    /// (`player:3531`) and dry-runs whatever was chosen, because the picker is
    /// a frame on the same terminal the listing is about to be printed on.
    /// There is no such terminal here — the panel is a window, and a window
    /// cannot hand its answer back to a pipe. But the script already has a rule
    /// for a run that cannot draw a picker, one line into `pick_source`:
    ///
    ///     [ "$SCREEN" -eq 1 ] || { PICKED=${SRC[0]}; return 0; }
    ///
    /// (`player:1118`) — with no screen, the first source found *is* the
    /// answer. `player -n | cat` has always behaved this way. So does this.
    ///
    /// `--check` never reaches here: it is answered and exited before there is
    /// an app at all (`player:531`, `App/main.swift`), which is the script's own
    /// order — `CHECK` is tested at 531 and `DRY_RUN` at 3540.
    public static func run(
        _ options: LaunchOptions,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        note: @Sendable (String) -> Void = { _ in }
    ) async -> Outcome {
        let chosen: (url: URL, kind: SourceKind)

        // `player:3517`, in its own order: a named source first, `--cd` second,
        // and whatever is lying about third. Naming a record and asking for the
        // disc in the same breath is not an error and the record wins.
        if let path = options.sourcePath {
            do {
                chosen = try SourceOpener.resolve(path: path)
            } catch {
                return .died("\(error)")
            }
        } else if options.wantCD {
            guard let disc = DiscFinder.find() else {
                return .died("\(SourceOpener.Failure.noDisc)")
            }
            chosen = (disc.volume, .disc)
        } else {
            let directories = SourceScanner.defaultDirectories(environment: environment)
            let found = SourceScanner.scan(
                directories: directories, disc: DiscFinder.find()
            )
            guard let first = found.first else {
                return .died(nothingToPlay(environment: environment))
            }
            chosen = (first.url, first.kind)
        }

        do {
            let opened = try await SourceOpener.open(
                url: chosen.url, kind: chosen.kind,
                useMusicBrainz: options.useMusicBrainz
            )
            // The zip really was unpacked, and the exit trap really does take it
            // away again (`player:319`) — including on a run that played
            // nothing. `MUTHUR_KEEP` says so out loud on stderr for the same
            // reason the script does (`player:317`): a directory that survives
            // silently is a directory nobody remembers to delete.
            if let scratch = opened.scratch {
                let keep = Scratch.keepRequested(environment: environment)
                if let kept = try? scratch.tearDown(keep: keep) {
                    note("scratch kept at \(kept.path)")
                }
            }
            // The shelf, looked up the way the panel looks it up
            // (`PanelModel.shelf(for:)`) — not to print the note, which `-n`
            // has no line for, but because the catalogue is one of the three
            // places the year can come from and the panel would have consulted
            // it. A record that is not on the shelf simply is not on it.
            let entry = CatalogueFile.load(environment: environment)?
                .look(album: opened.record.album, albumArtist: opened.record.albumArtist)
            let shelf = entry.flatMap { $0.isEmpty ? nil : HeaderBlock.Shelf($0) }
            return .printed(
                text(
                    record: opened.record, titleSource: opened.titleSource,
                    shelf: shelf
                )
            )
        } catch {
            return .died("\(error)")
        }
    }

    /// `player:1114`, kept including the shape of its own substitution:
    ///
    ///     die "nothing to play. Put an album in ${PLAYER_DIRS:-~/Music or ~/Downloads}, or a CD in the drive"
    ///
    /// **The two halves of that `:-` are not the same kind of thing** — set, it
    /// interpolates a colon-separated path list; unset, it interpolates English
    /// with an "or" in it. So the message reads either `Put an album in
    /// ~/Music or ~/Downloads` or `Put an album in /a:/b`, and only one of them
    /// is a sentence. Matched anyway. The variable named is the one that is
    /// actually set, for the same reason §11's MusicBrainz row names the switch
    /// that did it: sending a reader to the wrong name is worse than saying
    /// nothing.
    static func nothingToPlay(environment: [String: String]) -> String {
        let named = nonEmpty(environment["MUTHUR_DIRS"]) ?? nonEmpty(environment["PLAYER_DIRS"])
        return "nothing to play. Put an album in \(named ?? "~/Music or ~/Downloads")"
            + ", or a CD in the drive"
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
