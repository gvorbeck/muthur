import Foundation

/// §20 stage 2 — `DiscText`, serialised (`write_cue`, `burncd:2141`).
///
/// **None of the field choices are made here.** §20.3 settled which fields
/// survive the lead-in budget, what they read after transliteration into
/// ISO-8859-1, and what the operator is told about the difference; `DiscText`
/// is that answer and this only writes it down. What is added is the two things
/// that could not exist until there was an image to point at: the `FILE` line
/// naming it, and an `INDEX` per track in MSF sectors into it.
public enum CueSheet {

    /// The cue sheet for one disc.
    ///
    /// `imageName` is a **bare filename** and not a path (`basename "$IMAGE"`,
    /// `burncd:2160`): `cdrecord` is run with the working directory set to the
    /// scratch directory, and a cue sheet that names an absolute path is one
    /// that stops working the moment the image is moved — which is precisely
    /// what `BURNCD_KEEP_WORK` invites somebody to do.
    ///
    /// `starts` is one sector offset per track, from `ImageWriter.starts`.
    public static func text(
        _ discText: DiscText, imageName: String, starts: [Int]
    ) -> String {
        var lines: [String] = []

        // CD-Text has no year field, so the date can only be a cue comment
        // (`burncd:2149`). Some rippers and players read `REM DATE`; a CD
        // player's display never will. It costs nothing against the lead-in
        // budget, which is why it survives every rung of the shedding ladder
        // including the one that turns CD-Text off altogether.
        if !discText.date.isEmpty {
            lines.append("REM DATE \(discText.date)")
        }

        // Artist before title, which is the script's order (`burncd:2154`) and
        // not alphabetical accident: `PERFORMER` before `TITLE` is how every
        // cue sheet cdrecord has ever been handed is laid out, and a parser
        // that is fussy about it is a parser nobody wants to meet at 2 a.m.
        //
        // A field that came back empty is one nothing survived — a title
        // written entirely in an alphabet the disc has no room for. It is left
        // out rather than written as an empty string: the player shows the same
        // nothing either way, and the cue sheet stays honest about what it
        // carries (`burncd:2156`).
        if !discText.discArtist.isEmpty {
            lines.append("PERFORMER \(quoted(discText.discArtist))")
        }
        if !discText.discTitle.isEmpty {
            lines.append("TITLE \(quoted(discText.discTitle))")
        }

        lines.append("FILE \(quoted(imageName)) WAVE")

        for (index, start) in starts.enumerated() {
            lines.append(String(format: "  TRACK %02d AUDIO", index + 1))
            // `DiscText.tracks` is empty at the bottom rung and short of
            // `starts` for nothing else, so the two are zipped by index rather
            // than assumed to be the same length: a disc still gets all of its
            // `TRACK` and `INDEX` lines when it has given up all of its names.
            if index < discText.tracks.count {
                let track = discText.tracks[index]
                if !track.title.isEmpty {
                    lines.append("    TITLE \(quoted(track.title))")
                }
                if !track.artist.isEmpty {
                    lines.append("    PERFORMER \(quoted(track.artist))")
                }
            }
            lines.append("    INDEX 01 \(DiscImage.msf(sectors: start))")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Quotes are the cue sheet's only delimiter, and `CueText.convert` has
    /// already taken every `"` and `\` out of every field that reaches here —
    /// which is why this wraps rather than escapes. There is no escape sequence
    /// in the format to reach for.
    private static func quoted(_ value: String) -> String { "\"\(value)\"" }
}
