import Foundation

/// §20.3 — getting a tag into the alphabet a CD lead-in can hold.
///
/// `cue_textv` (`burncd:2051`). A disc's CD-Text is ISO-8859-1 and a music tag
/// is UTF-8, and the gap between those two is where a perfectly good title
/// turns into mojibake on a car stereo that cannot explain itself.
///
/// **D63 — the mechanism is ported, not the tool.** The script reaches for
/// `iconv -c -f UTF-8 -t ISO-8859-1//TRANSLIT`, and the kit may not shell out.
/// Foundation is no substitute on its own: `String.data(using: .isoLatin1,
/// allowLossyConversion: true)` substitutes `?` for anything it cannot carry
/// and transliterates nothing at all, so `Tōkyō` comes back `T?ky?` where
/// Apple's iconv gives `Tokyo`. What is written below is the same three-step
/// answer iconv gives, done with Unicode normalisation: take the character if
/// Latin-1 has it, else decompose it and keep the base letter, else drop it.
/// `ō` loses its macron and stays an `o`; `é` is in the alphabet already and is
/// not touched; kana has no base letter to fall back to and goes.
public enum CueText {

    /// What came back, and whether anything was given up getting there.
    public struct Field: Sendable, Equatable {
        public let text: String
        /// True when the disc will not be showing what the tag said.
        ///
        /// Decided by taking it back (`burncd:2096`) — convert the result to
        /// UTF-8 again and see whether it is still the title we were handed.
        /// The script uses the round trip because on Apple's iconv the exit
        /// status is worthless in both directions: it reports success for a
        /// `Tōkyō` it has quietly turned into `Tokyo`, and failure for every
        /// character `-c` correctly dropped from a line it converted perfectly
        /// well. The round trip is the only test that answers the question
        /// actually being asked, so it is the one ported.
        public let approximated: Bool

        public var isEmpty: Bool { text.isEmpty }
    }

    /// The typographer's punctuation, mapped before anything else looks at the
    /// string (`burncd:2057`).
    ///
    /// ISO-8859-1 has none of it and no two iconvs agree about what to do. A
    /// curly apostrophe is by a wide margin the most common non-Latin-1
    /// character in a music tag, and Apple's iconv transliterates it to `´` —
    /// an acute accent standing where the apostrophe was, so `Don't` becomes
    /// `Don´t` on the display. These have exact ASCII equivalents and are
    /// simply what they are stand-ins for: mapping them here keeps them off the
    /// approximated count, where they were never really a loss, and lets a
    /// title that was only ever ASCII with fancy quotes take the fast path.
    ///
    /// Curly double quotes go the way the plain ones already have — out,
    /// because the cue parser reads them.
    private static let punctuation: [Character: String] = [
        "\u{2019}": "'", "\u{2018}": "'", "\u{2032}": "'",
        "\u{201C}": "", "\u{201D}": "",
        "\u{2013}": "-", "\u{2014}": "-", "\u{2015}": "-",
        "\u{2026}": "...",
    ]

    /// Convert one field. `max` is a **byte** count, and in ISO-8859-1 that is
    /// also a character count.
    public static func convert(_ raw: String, max: Int = 120) -> Field {
        // What the cue sheet's own syntax cannot survive, and what no display
        // can show: controls, the quote that ends a quoted string, and the
        // backslash that escapes it (`burncd:2053`).
        var s = String(
            raw.unicodeScalars.filter { scalar in
                !(scalar.value <= 0x1F || scalar.value == 0x7F)
                    && scalar != "\"" && scalar != "\\"
            }
        )
        guard !s.isEmpty else { return Field(text: "", approximated: false) }

        s = s.map { punctuation[$0] ?? String($0) }.joined()

        // Most fields are plain ASCII, which is a subset of both alphabets:
        // nothing to convert and nothing that can be lost. Worth the test — it
        // keeps the count honest, and it is the common album.
        //
        // The early return is the script's, spaces and all (`burncd:2079`): the
        // trim at the bottom exists to clean up after a character that was
        // dropped, and on this path nothing was.
        if s.allSatisfy({ $0.isASCII && $0 != "\u{7F}" }) {
            return Field(text: String(s.prefix(max)), approximated: false)
        }

        var out = ""
        for character in s {
            if let latin1 = intoLatin1(character) {
                out += latin1
            }
            // Else it is dropped, which is iconv's `-c`.
        }

        // Whether anything was given up. `out` is Latin-1 by construction, so
        // reading it back is the identity — the comparison is against the
        // punctuation-mapped string, which is what the script compares too.
        let approximated = out != s

        // Cut last, where it is safe (`burncd:2103`). One ISO-8859-1 byte is
        // one character, so a byte count is a character count and cannot leave
        // half of one behind; cutting the UTF-8 first would hand the converter
        // a broken tail to choke on.
        out = String(out.prefix(max))

        // Whatever was dropped took its spacing with it: `東京 Nights` arrives
        // here as ` Nights`, and a title indented by one space on the player's
        // display is a worse answer than the same title without it.
        out = out.trimmingCharacters(in: CharacterSet(charactersIn: " "))

        return Field(text: out, approximated: approximated)
    }

    /// One character into the disc's alphabet, or nil if it has no place there.
    ///
    /// The script's fallback chain — Latin-1, then ASCII, then a plain strip of
    /// the high bytes — all three arrive at the same place for the case that
    /// actually distinguishes them, a title written entirely in kana: empty.
    /// So there is one path here and it ends the same way, and a field that
    /// comes back empty is left out of the cue sheet rather than written as an
    /// empty string (`burncd:2152`).
    private static func intoLatin1(_ character: Character) -> String? {
        let scalars = character.unicodeScalars
        if scalars.count == 1, let only = scalars.first, only.value <= 0xFF {
            return String(character)
        }

        // Decompose and throw away the marks. This is what `//TRANSLIT` does
        // for the accented letters Latin-1 is missing, and it is why it is
        // worth doing rather than dropping: `ō` is an `o` wearing a macron, and
        // an `o` is a far better answer than nothing.
        let bare = String(character).decomposedStringWithCanonicalMapping
            .unicodeScalars
            .filter { !$0.properties.isDiacritic && $0.value <= 0xFF }
        guard !bare.isEmpty else { return nil }
        return String(String.UnicodeScalarView(bare))
    }

    /// What a field costs in the lead-in (`cdtext_add`, `burncd:2122`).
    ///
    /// CD-Text rides in 18-byte packs carrying 12 bytes of payload each, and a
    /// field is stored with a terminating NUL — so a 12-character title takes
    /// two packs rather than one, and `(n + 12) / 12` is the ceiling with that
    /// NUL already counted.
    ///
    /// Measuring the finished cue sheet instead, which is what the budget check
    /// used to do, counts `TRACK`, `INDEX` and `FILE` lines that never reach
    /// the lead-in at all and misses the packs' own overhead in both
    /// directions.
    public static func packBytes(_ field: String) -> Int {
        let n = field.count
        guard n > 0 else { return 0 }
        return ((n + 12) / 12) * 18
    }
}
