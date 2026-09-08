import Foundation
import Testing

@testable import MUTHURKit

// MARK: - §20.3 Into the disc's alphabet

@Suite("§20.3 — CD-Text conversion")
struct CueTextTests {

    @Test("A plain ASCII title comes back untouched and unapproximated")
    func ascii() {
        let field = CueText.convert("Kind of Blue")
        #expect(field.text == "Kind of Blue")
        #expect(!field.approximated)
    }

    /// **The one that started it.** Apple's iconv transliterates `’` to `´` —
    /// an acute accent standing where the apostrophe was — so `Don't` reaches
    /// the display as `Don´t`. Mapped before anything else looks at the string
    /// (`burncd:2057`), which also keeps it off the approximated count, where
    /// it was never really a loss.
    @Test("A curly apostrophe becomes a straight one, and is not a loss")
    func curlyApostrophe() {
        let field = CueText.convert("Don\u{2019}t Let Me Be Misunderstood")
        #expect(field.text == "Don't Let Me Be Misunderstood")
        #expect(!field.approximated)
    }

    @Test("Dashes, primes and the ellipsis have exact ASCII equivalents")
    func punctuation() {
        #expect(CueText.convert("A \u{2013} B").text == "A - B")
        #expect(CueText.convert("A \u{2014} B").text == "A - B")
        #expect(CueText.convert("Wait\u{2026}").text == "Wait...")
        #expect(CueText.convert("5\u{2032}").text == "5'")
        #expect(CueText.convert("A \u{2013} B").approximated == false)
    }

    /// Curly double quotes go the way the plain ones already have — out,
    /// because the cue parser reads them.
    @Test("Quotes and backslashes cannot survive a cue sheet")
    func quotes() {
        #expect(CueText.convert("\u{201C}Heroes\u{201D}").text == "Heroes")
        #expect(CueText.convert("She said \"go\"").text == "She said go")
        #expect(CueText.convert("A\\B").text == "AB")
    }

    /// A tag with a newline in it would end the cue line early and turn the
    /// rest of the title into a command the parser does not have.
    @Test("Control characters do not reach the cue sheet")
    func controls() {
        #expect(CueText.convert("A\tB\nC").text == "ABC")
        #expect(CueText.convert("A\u{7F}B").text == "AB")
    }

    /// Latin-1 has these already, so nothing is lost getting them onto a disc.
    @Test("An accented letter the alphabet has is kept, not flattened")
    func latin1Native() {
        let field = CueText.convert("Café Tacvba")
        #expect(field.text == "Café Tacvba")
        #expect(!field.approximated)
    }

    /// **D63.** `ō` is an `o` wearing a macron, and Latin-1 has no room for the
    /// macron. Foundation's own lossy conversion writes `T?ky?`; iconv's
    /// `//TRANSLIT` writes `Tokyo`; this is the second answer, reached by
    /// decomposing and dropping the mark.
    @Test("A letter the alphabet lacks keeps its base and loses its mark")
    func transliterated() {
        let field = CueText.convert("T\u{014D}ky\u{014D}")
        #expect(field.text == "Tokyo")
        #expect(field.approximated)
    }

    /// There is no base letter under kana, so there is nothing to keep. An
    /// empty field is left out of the cue sheet rather than written empty.
    @Test("A title with no Latin under it comes back empty and says it lost something")
    func nothingSurvives() {
        let field = CueText.convert("\u{6771}\u{4EAC}")
        #expect(field.isEmpty)
        #expect(field.approximated)
    }

    /// Whatever was dropped took its spacing with it, and a title indented by
    /// one space on the player's display is a worse answer than the same title
    /// without it (`burncd:2107`).
    @Test("A dropped character does not leave its space behind")
    func trimmed() {
        let field = CueText.convert("\u{6771}\u{4EAC} Nights")
        #expect(field.text == "Nights")
        #expect(field.approximated)
    }

    /// Cut last, where it is safe: one ISO-8859-1 byte is one character, so a
    /// byte count is a character count and cannot leave half of one behind
    /// (`burncd:2103`).
    @Test("A long title is cut to the limit, and cut after converting")
    func truncation() {
        let long = String(repeating: "a", count: 200)
        #expect(CueText.convert(long, max: 60).text.count == 60)
        #expect(CueText.convert(long, max: 30).text.count == 30)

        // Converted first: the ō is one character in the answer, not two bytes.
        let mixed = String(repeating: "\u{014D}", count: 40)
        let cut = CueText.convert(mixed, max: 30)
        #expect(cut.text == String(repeating: "o", count: 30))
    }

    /// A field is stored with a terminating NUL in 18-byte packs carrying 12
    /// bytes each, so a 12-character title takes two packs rather than one
    /// (`burncd:2116`).
    @Test("A field costs whole packs, and the NUL is one of the bytes")
    func packs() {
        #expect(CueText.packBytes("") == 0)
        #expect(CueText.packBytes(String(repeating: "a", count: 1)) == 18)
        #expect(CueText.packBytes(String(repeating: "a", count: 11)) == 18)
        #expect(CueText.packBytes(String(repeating: "a", count: 12)) == 36)
        #expect(CueText.packBytes(String(repeating: "a", count: 23)) == 36)
        #expect(CueText.packBytes(String(repeating: "a", count: 24)) == 54)
    }
}

// MARK: - §20.3 The shedding ladder

@Suite("§20.3 — the CD-Text ladder")
struct DiscTextLadderTests {

    /// `count` entries with titles and artists long enough to be worth
    /// measuring.
    private func entries(_ count: Int, titleLength: Int = 40) -> [BurnPlan.Entry] {
        (0..<count).map { i in
            BurnPlan.Entry(
                source: i,
                title: String(repeating: "t", count: titleLength),
                artist: String(repeating: "a", count: 20),
                duration: 200, offset: nil, length: nil, disc: 1
            )
        }
    }

    private func text(_ count: Int, titleLength: Int = 40) -> DiscText {
        DiscText.make(
            disc: 1, entries: entries(count, titleLength: titleLength),
            album: "A Record", albumArtist: "Someone", year: "1979"
        )
    }

    @Test("A small album keeps everything and says nothing about it")
    func fitsWhole() {
        let disc = text(10)
        #expect(disc.level == .full)
        #expect(disc.bytes <= DiscText.budget)
        #expect(disc.notes.isEmpty)
        #expect(disc.tracks.allSatisfy { !$0.artist.isEmpty })
        #expect(disc.discTitle == "A Record")
        #expect(disc.discArtist == "Someone")
        #expect(disc.writesCDText)
    }

    /// The date is a cue comment and not CD-Text — the format has no year
    /// field — so it costs nothing against the budget and survives every rung
    /// (`burncd:2149`).
    @Test("The year rides as a comment and is never shed")
    func yearIsAComment() {
        let bare = DiscText.make(
            disc: 1, entries: entries(1), album: "", albumArtist: "", year: "1979"
        )
        #expect(bare.date == "1979")
        let none = DiscText.at(
            .none, disc: 1, entries: entries(1), album: "A", albumArtist: "B", year: "1979"
        )
        #expect(none.date == "1979")
        #expect(none.bytes == 0)
    }

    /// The rungs, in order, and each one gives up exactly what it says
    /// (`burncd:2130`).
    @Test("Each rung sheds what it names and nothing else")
    func rungs() {
        let all = entries(4)
        func at(_ level: DiscText.Shed) -> DiscText {
            DiscText.at(
                level, disc: 1, entries: all, album: "A Record", albumArtist: "Someone",
                year: "1979"
            )
        }

        #expect(at(.full).tracks.allSatisfy { !$0.artist.isEmpty })
        #expect(at(.noTrackArtists).tracks.allSatisfy { $0.artist.isEmpty })
        #expect(at(.noTrackArtists).tracks.allSatisfy { $0.title.count == 40 })
        #expect(at(.titlesTo60).tracks.allSatisfy { $0.title.count == 40 })
        #expect(at(.titlesTo30).tracks.allSatisfy { $0.title.count == 30 })
        #expect(at(.noTrackTitles).tracks.allSatisfy { $0.title.isEmpty })
        // The disc's own names are the last thing standing before nothing.
        #expect(at(.noTrackTitles).discTitle == "A Record")
        #expect(at(.none).discTitle.isEmpty)
        #expect(at(.none).bytes == 0)
        #expect(!at(.none).writesCDText)
    }

    /// A 60-character cut is only a cut for a title longer than 60, which is
    /// why the ladder has two title rungs and not one: the first does nothing
    /// at all to an album of ordinary titles, and the second is what actually
    /// saves the lead-in.
    @Test("Shedding stops at the first rung that fits")
    func stopsAtTheFirstFit() {
        // Ninety tracks with long titles and artists will not fit whole.
        let disc = text(90, titleLength: 90)
        #expect(disc.bytes <= DiscText.budget)
        #expect(disc.level > .full)
        // And the rung above it does not fit, or it would have stopped there.
        if let above = DiscText.Shed(rawValue: disc.level.rawValue - 1) {
            let tighter = DiscText.at(
                above, disc: 1, entries: entries(90, titleLength: 90),
                album: "A Record", albumArtist: "Someone", year: "1979"
            )
            #expect(tighter.bytes > DiscText.budget)
        }
    }

    /// Every step is announced (`burncd:2568`). A disc that quietly arrives
    /// with fewer of its names on it is the failure this whole ladder is a
    /// remedy for.
    @Test("Every rung but the first says what it gave up")
    func announced() {
        for level in DiscText.Shed.allCases {
            let disc = DiscText.at(
                level, disc: 2, entries: entries(2), album: "A", albumArtist: "B", year: ""
            )
            if level == .full {
                #expect(disc.notes.isEmpty)
            } else {
                #expect(disc.notes.count == 1)
                #expect(disc.notes[0].contains("CD-Text"))
            }
        }
        let off = DiscText.at(
            .none, disc: 2, entries: entries(2), album: "A", albumArtist: "B", year: ""
        )
        #expect(off.notes[0].contains("disc 2"))
    }

    /// Kept inside the panel's 69 columns like every other line of it: `note`
    /// prints what it is given, and a line too long for the frame wraps, which
    /// costs the frame a row it did not budget for and scrolls its top away
    /// (`burncd:2576`).
    @Test("Every note fits the panel it is printed on")
    func notesFit() {
        for level in DiscText.Shed.allCases {
            let disc = DiscText.at(
                level, disc: 9, entries: entries(2), album: "A", albumArtist: "B", year: ""
            )
            for note in disc.notes {
                #expect(Columns.width(of: note) <= PanelGrid.width)
            }
        }
        let lossy = DiscText.make(
            disc: 1,
            entries: [
                BurnPlan.Entry(
                    source: 0, title: "T\u{014D}ky\u{014D}", artist: "", duration: 100,
                    offset: nil, length: nil, disc: 1
                )
            ],
            album: "", albumArtist: "", year: ""
        )
        #expect(lossy.approximatedCount == 1)
        for note in lossy.notes {
            #expect(Columns.width(of: note) <= PanelGrid.width)
        }
    }

    /// Counted and said out loud (`burncd:2578`), because the plan on screen
    /// goes on showing the real titles — the operator has no other way to know
    /// the disc will not.
    @Test("The approximations are counted across every field")
    func lossyCount() {
        let disc = DiscText.make(
            disc: 1,
            entries: [
                BurnPlan.Entry(
                    source: 0, title: "T\u{014D}ky\u{014D}", artist: "\u{6771}\u{4EAC}",
                    duration: 100, offset: nil, length: nil, disc: 1
                )
            ],
            album: "\u{014C}saka", albumArtist: "Someone", year: "1979"
        )
        // The album title, the track title and the track artist: three.
        #expect(disc.approximatedCount == 3)
        #expect(disc.notes.contains { $0.contains("3 field(s) approximated") })
    }

    @Test("CD-Text switched off is the bottom rung, reached without shedding")
    func switchedOff() {
        let disc = DiscText.make(
            disc: 1, entries: entries(4), album: "A", albumArtist: "B", year: "1979",
            enabled: false
        )
        #expect(disc.level == .none)
        #expect(!disc.writesCDText)
        #expect(disc.bytes == 0)
    }
}
