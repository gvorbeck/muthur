import Foundation

/// Reading a table of contents out of what `cdrecord -toc` prints
/// (`player:2137`).
///
/// One line per track and one for the lead-out:
///
///     track:   1 lba:         0 (       0) 00:02:00 adr: 1 control: 0 mode: -1
///     track:lout lba:    164750 (  659000) 36:39:50 adr: 1 control: 0 mode: -1
///
/// The lead-out is track 0xAA in the TOC proper; cdrtools prints it as `lout`,
/// which is why it is matched by name rather than by number. Without it there is
/// no disc ID at all, so a listing missing that line is a failure rather than a
/// short disc.
public enum CDRecordTOC {

    public static func parse(_ output: String) -> TableOfContents? {
        var lbas: [Int: Int] = [:]
        var first = 0
        var last = 0
        var leadOut: Int?

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            guard line.hasPrefix("track:") else { continue }
            let body = line.dropFirst("track:".count).drop { $0 == " " }

            // `.*lba:[ ]*\(-*[0-9]*\)` — negative LBAs are matched on purpose.
            // A track can begin before track one does, in the pre-gap.
            guard let lbaRange = line.range(of: "lba:") else { continue }
            let after = line[lbaRange.upperBound...].drop { $0 == " " }
            let digits = after.prefix { $0 == "-" || ($0.isASCII && $0.isNumber) }
            guard let lba = Int(digits) else { continue }

            if body.hasPrefix("lout") {
                // First one wins — `head -1`.
                if leadOut == nil, lba >= 0 { leadOut = lba }
                continue
            }

            let number = body.prefix { $0.isASCII && $0.isNumber }
            guard !number.isEmpty, let n = Int(number), n >= 1,
                n <= TableOfContents.maxTracks
            else { continue }

            lbas[n] = lba
            if first == 0 { first = n }
            if n > last { last = n }
        }

        guard let leadOut, first > 0, last >= first else { return nil }
        // D20. A gap in the middle of the listing would leave a track with no
        // offset at all. The script writes a zero there; a zero is a real
        // offset, so it would produce a plausible-looking disc ID for a disc
        // that does not exist. Better to have no ID and fall through to track
        // numbers.
        var trackLBAs: [Int] = []
        for n in first...last {
            guard let lba = lbas[n] else { return nil }
            trackLBAs.append(lba)
        }

        return TableOfContents.fromLBA(
            firstTrack: first, lastTrack: last, leadOutLBA: leadOut, trackLBAs: trackLBAs
        )
    }
}
