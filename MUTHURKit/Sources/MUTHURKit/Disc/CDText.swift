import Foundation

/// What CD-Text said, before anything has been matched against a record. §4.2.
///
/// Keyed by *track number*, not by row. The disc answers in track numbers and
/// the arrays are in scan order; joining the two is `fileIndex(ofTrackNumber:)`
/// and it happens once, in the chain.
public struct CDText: Sendable, Equatable {
    public var album = ""
    public var albumArtist = ""
    public var titles: [Int: String] = [:]
    public var artists: [Int: String] = [:]

    public var isEmpty: Bool {
        album.isEmpty && albumArtist.isEmpty && titles.isEmpty && artists.isEmpty
    }
}

/// Reading the shapes cdrtools prints. §4.2.
///
/// cdrecord and cdda2wav print CD-Text in a couple of shapes depending on
/// version, so both are matched and neither is required:
///
///     Album title: 'Nonagon Infinity'
///     Album title: 'Nonagon Infinity' from 'King Gizzard'
///     Track  1 title: 'Robot Stop'
///     Track  1 title: 'Robot Stop' from 'King Gizzard'
///
/// Every value on the disc arrives inside single quotes, and **the quote that
/// ends one is the one before `" from '"` or the one at the end of the line —
/// not simply the next one along.** Matching to the next one along cuts
/// `Don't Stop Me Now` down to `Don`, which is a title the disc does not have,
/// and there is no way to tell that from a disc that really is called that.
/// The script gets this right with greedy `\(.*\)` in sed; here it is a
/// deliberate search from the end (`player:2064`).
public enum CDTextParser {

    public static func parse(_ output: String) -> CDText {
        var text = CDText()
        // Two independent `head -1`s over the same output: the first
        // `Album title:` line settles the album whatever it says, and the first
        // one carrying a `from` clause settles the artist. A blank value on that
        // line leaves the field blank rather than sending the search on to the
        // next line, because that is what `head -1` before `[ -n "$line" ]`
        // does.
        var albumSettled = false
        var albumArtistSettled = false

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)

            if line.hasPrefix("Album title:") {
                guard let value = quoted(line.dropFirst("Album title:".count)) else { continue }
                if !albumSettled {
                    albumSettled = true
                    if !value.value.isEmpty { text.album = Track.flatten(value.value) }
                }
                if let from = value.from, !albumArtistSettled {
                    albumArtistSettled = true
                    if !from.isEmpty { text.albumArtist = Track.flatten(from) }
                }
                continue
            }

            // `Track[ ]*\([0-9]*\)[ ]*title:` — the number, then the same value
            // rule. `grep -i` only selects the lines; every sed that then reads
            // one is case-sensitive, so `track 1 title:` never gets a number out
            // and is dropped. Matching `Track` exactly is that, said once.
            guard line.hasPrefix("Track") else { continue }
            let afterTrack = line.dropFirst("Track".count).drop { $0 == " " }
            let digits = afterTrack.prefix { $0.isASCII && $0.isNumber }
            // `10#$n` — leading zeros are zeros, not octal.
            guard !digits.isEmpty, let number = Int(digits) else { continue }
            let afterDigits = afterTrack.dropFirst(digits.count).drop { $0 == " " }
            guard afterDigits.hasPrefix("title:") else { continue }
            guard let value = quoted(afterDigits.dropFirst("title:".count)),
                !value.value.isEmpty
            else { continue }

            // Later lines win over earlier ones for the same track, which is
            // what a plain array assignment does in the script. A shape that
            // does not parse leaves whatever was there alone — a row with a dull
            // title is better than a row with none.
            text.titles[number] = Track.flatten(value.value)
            if let from = value.from, !from.isEmpty {
                text.artists[number] = Track.flatten(from)
            }
        }

        return text
    }

    // MARK: - The quote rule

    struct Value: Equatable {
        let value: String
        /// The `from '…'` half, when the line carried one.
        let from: String?
    }

    /// Split `'value'` or `'value' from 'artist'`, given everything after the
    /// label.
    ///
    /// The search runs from the end of the line backwards, so the longest value
    /// that still leaves a well-formed `from` clause behind it is the one taken
    /// — which is what sed's greedy `\(.*\)` does, and what keeps the apostrophe
    /// in `Don't Stop Me Now`.
    static func quoted(_ rest: some StringProtocol) -> Value? {
        var body = Array(rest)
        while body.last == " " { body.removeLast() }
        while body.first == " " { body.removeFirst() }
        // Both shapes open with a quote and close with one.
        guard body.count >= 2, body.first == "'", body.last == "'" else { return nil }
        body.removeFirst()

        // Every quote is a candidate for the one that closes the value. Take the
        // last one that leaves a `from` clause behind it.
        var index = body.count - 1
        while index >= 0 {
            if body[index] == "'", let from = fromClause(body[(index + 1)...]) {
                return Value(value: String(body[0..<index]), from: from)
            }
            index -= 1
        }
        // No `from` clause: the value runs to the quote at the end of the line.
        return Value(value: String(body[0..<(body.count - 1)]), from: nil)
    }

    /// `[ ]*from[ ]*'\(.*\)'[ ]*$` — trailing spaces are already gone by here.
    private static func fromClause(_ tail: ArraySlice<Character>) -> String? {
        var rest = tail.drop { $0 == " " }
        guard rest.starts(with: "from") else { return nil }
        rest = rest.dropFirst(4).drop { $0 == " " }
        guard rest.count >= 2, rest.first == "'", rest.last == "'" else { return nil }
        return String(rest.dropFirst().dropLast())
    }
}
