import Foundation

/// §10 — how wide a piece of text is, and how to make it a given width.
///
/// The grid is a design grid rather than a terminal, but the arithmetic that
/// produced its rhythm is the same arithmetic: an artist column sized to the
/// longest name the record contains only means anything if something can say
/// how long that name is, and it has to say it in the units the column is
/// measured in.
///
/// Most of `panel.sh`'s width machinery is gone with the terminal, and one
/// piece of it is gone for a better reason. Bash walked a string a *character*
/// at a time and had to subtract the combining marks itself, because macOS
/// hands back decomposed text and `é` arrives as two of them (`panel.sh:274`).
/// Swift's `Character` is a grapheme cluster, so the mark is already inside the
/// letter it belongs to and there is nothing to subtract. What survives is the
/// half that is about typesetting rather than encoding: a CJK character takes
/// two places in a monospaced grid, and a title full of them is twice as wide
/// as its character count says.
public enum Columns {

    /// The same ranges `cwidth` tests for (`panel.sh:307`), and they have to
    /// stay the same ranges: a title measured by one rule and cut by another
    /// slides the column after it.
    static let wide: [ClosedRange<UInt32>] = [
        // One range the script has not got, and it is here because of the
        // *reason* the script's width code exists rather than in spite of it.
        // macOS hands back decomposed text, so `한` arrives as three conjoining
        // jamo; the cluster is one character to Swift and its first scalar is
        // the leading jamo, which is in this block and nowhere near the
        // syllables below. Without it a Korean title measured here comes back
        // half its width — the exact failure `cwidth` was written to prevent,
        // arriving through the other door (§18.23).
        0x1100...0x115F,  // conjoining leading jamo
        0x2E80...0x303F,  // radicals, kana punctuation
        0x3040...0x30FF,  // hiragana, katakana
        0x4E00...0x9FFF,  // unified ideographs
        0xAC00...0xD7A3,  // hangul syllables
        0xFF01...0xFFA0,  // fullwidth forms
        0x1F000...0x1FFFF,  // tiles, pictographs, emoji
    ]

    /// How many places one character stands in. Two for the wide ranges, one
    /// for everything else — and never zero, because a grapheme cluster with
    /// nothing but marks in it is not something a tagger produces.
    public static func width(of character: Character) -> Int {
        // The cluster's first scalar is the one that decides. A wide character
        // followed by a variation selector is still one wide character.
        guard let first = character.unicodeScalars.first?.value else { return 0 }
        return wide.contains(where: { $0.contains(first) }) ? 2 : 1
    }

    /// How many places a whole string stands in.
    ///
    /// `wcols` asked the wide question of the whole string first and only
    /// walked it character by character if the answer was yes, because in bash
    /// the walk is a fork's worth of work and the common case is a Latin title
    /// (`panel.sh:313`). Here the walk *is* the cheap answer.
    public static func width(of text: String) -> Int {
        text.reduce(0) { $0 + width(of: $1) }
    }

    /// Cut to a column count, ending in `…` so the cut is visible
    /// (`panel.sh:338`).
    ///
    /// Whole characters only: a two-column character that would straddle the
    /// last place is left out rather than half-drawn, which leaves a column
    /// over for the pad to fill.
    public static func truncate(_ text: String, to columns: Int) -> String {
        guard columns > 0 else { return "" }
        guard width(of: text) > columns else { return text }
        let limit = columns - 1
        var kept = ""
        var used = 0
        for character in text {
            let next = used + width(of: character)
            if next > limit { break }
            kept.append(character)
            used = next
        }
        return kept + "…"
    }

    public enum Align: Sendable { case leading, trailing }

    /// Pad or truncate to exactly this many columns (`panel.sh:341`).
    ///
    /// Trailing alignment is the same fit with the slack moved to the front.
    /// It is asked for by a track list where the artist column stands against
    /// the durations: two ragged edges facing each other read as a gap of no
    /// particular width, where two flush ones read as a margin.
    ///
    /// Whether a screen with real type still pads with spaces is §10's
    /// business — what is here is the count.
    public static func fit(_ text: String, to columns: Int, align: Align = .leading) -> String {
        let cut = truncate(text, to: columns)
        let pad = String(repeating: " ", count: max(0, columns - width(of: cut)))
        return align == .trailing ? pad + cut : cut + pad
    }
}
