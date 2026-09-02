import Foundation

/// §1.1 — `-h` / `--help`.
///
/// `panel.sh:269`, whole:
///
///     usage() {
///       awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "$0"
///       exit "${1:-0}"
///     }
///
/// Skip the shebang and the blank comment under it, print every remaining
/// comment line with its `# ` taken off, and stop at the first line that is not
/// one. Over `player` that is lines 3 to 51 — forty-nine of them, ending at
/// `PLAYER_KEEP`.
///
/// **The mechanism is the part that does not survive, and it was the good
/// part.** `usage` reads `$0`: the help and the file's own header are the same
/// forty-nine lines, and they cannot drift, because there is only one copy.
/// There is no `$0` to read here — the source is compiled and the bundle
/// carries no copy of it — so the text below is a literal, and a literal *can*
/// drift. What replaces the guarantee is a much weaker one: this is the only
/// copy in the repository, and the suite reads `Sources` back off disk and
/// asserts that every switch the parse accepts and every environment variable
/// the kit reads is spoken for here — and, the other way round, that nothing
/// named here has since been removed. That catches the drift that matters — a
/// switch added and not documented, a variable listed and no longer read — and
/// catches nothing else.
///
/// **Spoken for, not named.** The script's own header lists `-n` and not
/// `--dry-run` (`player:10`) and does not mention `-h` or `--help` at all, so
/// requiring every spelling would be a stricter rule than the original kept.
/// The suite carries the two alias pairs by hand instead; a switch with no
/// alias to hide behind must appear under its own name.
///
/// The program name is taken from the invocation rather than written in, which
/// is **mine**: the script hard-codes `player` in its own header because the
/// header is prose in a file, while `usage` is already reading `$0` for the
/// text. Doing both with `$0` seemed the smaller lie, and it means the lines
/// say `MUTHUR` when run out of the bundle and whatever you called it when it
/// is on your path.
public enum Usage {

    /// The default name, for the case where there is no `$0` worth reading.
    public static let program = "MUTHUR"

    /// `usage`'s output: no leading blank line and no trailing one — unlike
    /// `--check`, which frames itself with both (`panel.sh:583`). A page of
    /// help is the whole of what the terminal is showing; a report is a thing
    /// that arrived in the middle of a session.
    public static func text(invokedAs name: String = program) -> String {
        let called = nonEmpty(name.split(separator: "/").last.map(String.init)) ?? program
        return """
            MU/TH/UR — play an album from a zip, a folder, or the CD in the drive.

              \(called)                         offer the disc in the drive, or browse
              \(called) ~/Downloads/Album.zip   play a zip without unpacking it yourself
              \(called) ~/Music/Album           play a folder
              \(called) --cd                    play the disc in the drive
              \(called) --check                 check this machine can play anything
              \(called) -n ~/Music/Album        read it, show the album, play nothing
              \(called) --no-mb --cd            play the disc without asking MusicBrainz

            The binary is inside the bundle, at MUTHUR.app/Contents/MacOS/MUTHUR.
            --help, --check and -n print and exit; everything else opens the panel.

            Takes aiff, flac, mp3, ogg, wav, m4a, opus — anything AVFoundation reads,
            in a zip or loose in a folder. Track order comes from embedded metadata,
            not filenames. A zip is unpacked into a scratch directory under
            ~/.cache/muthur/work that is destroyed when the app closes, so what is
            left on disk afterwards is the zip you started with. Not $TMPDIR: macOS
            is entitled to reclaim that while a long record is still playing out of
            it, and it does.

            An audio CD is read off the disc's own table of contents: CD-Text when
            the disc carries it, MusicBrainz when it does not and the network is up,
            and plain track numbers when neither can say. Which of the three you got
            is printed on the panel, because a track list is only as good as its
            source.

            Transport is where your hands already are: space to pause, ←→ to seek
            and shift-←→ to seek further, ↑↓ to walk the list, enter to play what
            you are looking at, n and p for the next and previous track, s to
            shuffle, r for repeat, - and = for volume, m for mute, u to take up a
            record where you left it, q to stop.

            The meters are controls as well as readouts. Click the album meter to
            put the needle anywhere in the record, whichever track that lands in;
            click the track meter to move within the track. Dragging either one
            scrubs, though a drag on the album meter stays inside the track it
            started in. Click a row to select it and again to play it, and the wheel
            walks the list.

            The sleeve is drawn beside the panel when the window is wide enough to
            hold it. A picture inside the zip or the folder is the one used, or
            failing that the one in the tags, both being the artwork this copy came
            with; failing both it is fetched from the Cover Art Archive in the
            background and cached, so an album played twice only ever costs one
            download and one that brought its own artwork costs none. It is never
            waited for: if there is no cover, or no network, the panel is exactly
            the panel it would have been.

            Nothing on this machine is searched for records. Opened with no
            argument, the panel offers the disc in the drive if there is one, and
            B browses for anything else — which is also ⌘O, and is how a folder or
            a zip is chosen. The bash player scanned ~/Music and ~/Downloads and
            this does not: the scan cost two of macOS's permission prompts on
            every launch, and an open panel costs none.

            Env overrides:
              MUTHUR_WORK        where zips unpack (default ~/.cache/muthur/work)
              MUTHUR_KEEP        set to keep the scratch directory instead of destroying it
              MUTHUR_NO_MB       set to never ask MusicBrainz about a disc
              MUTHUR_DEV         cdrecord device for CD-Text (default: whichever the drive answers to)
              MUTHUR_COLLECTION  the catalogue CSV the shelf is read out of
              XDG_CACHE_HOME     where the scratch and the sleeve cache live
              XDG_STATE_HOME     where the resume file lives

            MUTHUR_WORK, MUTHUR_KEEP and MUTHUR_COLLECTION are read under their
            PLAYER_ names too, for somebody who has had those exported for years.
            PLAYER_DIRS is the one that is not: there is no scan for it to point
            at. MUTHUR_NO_MB is the other way up from the script's PLAYER_MB:
            unset, 0 and empty are on.

            """
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
