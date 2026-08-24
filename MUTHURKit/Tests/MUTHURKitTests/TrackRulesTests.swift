import Foundation
import Testing

@testable import MUTHURKit

/// §3, one rule at a time, with no file on disk.
///
/// The interesting cases are the degenerate ones and they are all degenerate
/// *tags* — there is no album anywhere that has an octal-looking track number
/// and a tab in its title, and there does not need to be.
@Suite("§3 — the rules on one file")
struct TrackRulesTests {

    // MARK: - Track and disc numbers

    @Test("`3/12` keeps the 3 (player:1447)")
    func slashKeepsTheHead() {
        #expect(Track.number(from: "3/12") == 3)
        #expect(Track.number(from: "1/1") == 1)
        // A CD rip that says which disc of how many.
        #expect(Track.number(from: "2/2") == 2)
        // Nothing before the slash is not a number.
        #expect(Track.number(from: "/12") == nil)
    }

    @Test("`08` is base ten, not octal (player:1451)")
    func leadingZeroIsBaseTen() {
        // The whole reason the script says `10#` out loud: bash reads a leading
        // zero as octal and rejects 08 and 09 outright, so an album tagged the
        // way every tagger tags it loses two tracks to 9999.
        #expect(Track.number(from: "08") == 8)
        #expect(Track.number(from: "09") == 9)
        #expect(Track.number(from: "007") == 7)
        #expect(Track.number(from: "0") == 0)
        #expect(Track.number(from: "08/12") == 8)
    }

    @Test("anything that is not digits did not say")
    func nonNumericIsMissing() {
        #expect(Track.number(from: nil) == nil)
        #expect(Track.number(from: "") == nil)
        #expect(Track.number(from: "A3") == nil)
        #expect(Track.number(from: " 3") == nil)
        #expect(Track.number(from: "3a") == nil)
        #expect(Track.number(from: "-1") == nil)
        // Forty digits is not a track number, and refusing it is the same
        // answer as refusing `A3`.
        #expect(Track.number(from: String(repeating: "9", count: 40)) == nil)
    }

    @Test("a missing track number is 9999 and a missing disc is 1")
    func missingDefaults() {
        let track = Track(url: URL(fileURLWithPath: "/x/song.flac"), raw: RawMetadata(duration: 1))
        #expect(track.number == Track.noNumber)
        #expect(track.number == 9999)
        #expect(track.disc == 1)
        #expect(!track.isNumbered)
    }

    // MARK: - Durations

    @Test("durations round up, never down (player:1478)")
    func durationsRoundUp() {
        // A track that ends before the meter says it does looks like a skip.
        #expect(Track.roundedUp(134.466757) == 135)
        #expect(Track.roundedUp(0.0001) == 1)
        #expect(Track.roundedUp(212.5) == 213)
        #expect(Track.roundedUp(59.999) == 60)
        // Already whole stays whole — the script's `d == int(d) ? d : int(d)+1`.
        #expect(Track.roundedUp(198.0) == 198)
        #expect(Track.roundedUp(0) == 0)
    }

    @Test("an unreadable duration is not a duration")
    func unreadableDurations() {
        #expect(!RawMetadata(duration: nil).isReadable)
        #expect(!RawMetadata(duration: .nan).isReadable)
        #expect(!RawMetadata(duration: .infinity).isReadable)
        #expect(RawMetadata(duration: 0).isReadable)
        #expect(RawMetadata(duration: 212.4).isReadable)
    }

    // MARK: - Text

    @Test("tab, newline and CR are flattened to a space (player:1468)")
    func textIsFlattened() {
        // A newline bends the frame the panel keeps square; a tab is the
        // separator the resume file splits every record on.
        #expect(Track.flatten("a\tb") == "a b")
        #expect(Track.flatten("a\nb") == "a b")
        #expect(Track.flatten("a\r\nb") == "a  b")
        #expect(Track.flatten("\tlead") == " lead")
        #expect(Track.flatten("Sunday\tBloody\nSunday") == "Sunday Bloody Sunday")
        #expect(Track.flatten(nil) == "")
        // Once, on the way in — and nothing else is touched.
        #expect(Track.flatten("Hôtel  Costes") == "Hôtel  Costes")
    }

    @Test("flattening reaches every text tag on the way in")
    func flattenedOnConstruction() {
        let track = Track(
            url: URL(fileURLWithPath: "/x/01.flac"),
            raw: RawMetadata(duration: 1, title: "One\tTwo", artist: "A\nB")
        )
        #expect(track.title == "One Two")
        #expect(track.artist == "A B")
    }

    @Test("title falls back to the basename, extension and all (player:1481)")
    func titleFallsBackToBasename() {
        let url = URL(fileURLWithPath: "/x/y/03 Never Going Back Again.m4a")
        let missing = Track(url: url, raw: RawMetadata(duration: 1))
        #expect(missing.title == "03 Never Going Back Again.m4a")
        // `:-` not `-`: an empty title falls back too.
        let empty = Track(url: url, raw: RawMetadata(duration: 1, title: ""))
        #expect(empty.title == "03 Never Going Back Again.m4a")
    }

    @Test("the year is the part before the first dash (player:1488)")
    func yearIsTruncated() {
        #expect(Track.year(from: "1977-02-04T08:00:00Z") == "1977")
        #expect(Track.year(from: "1979-05-25") == "1979")
        #expect(Track.year(from: "1979") == "1979")
        #expect(Track.year(from: "") == "")
        #expect(Track.year(from: nil) == "")
    }
}

/// `sort -V`, which is the third and last column of the running order.
@Suite("§3.1 — natural filename order")
struct NaturalOrderTests {

    @Test("track2 comes before track10, which a plain sort reverses")
    func digitsCompareNumerically() {
        #expect(NaturalOrder.compare("track2.flac", "track10.flac") == .orderedAscending)
        #expect(NaturalOrder.compare("track10.flac", "track2.flac") == .orderedDescending)
        #expect(NaturalOrder.compare("track2.flac", "track2.flac") == .orderedSame)
    }

    @Test("sorting a folder of unpadded names")
    func sortsAFolder() {
        let names = ["track10.flac", "track1.flac", "track2.flac", "track20.flac", "track3.flac"]
        let sorted = names.sorted { NaturalOrder.compare($0, $1) == .orderedAscending }
        #expect(sorted == ["track1.flac", "track2.flac", "track3.flac", "track10.flac", "track20.flac"])
    }

    @Test("padding and value are both accounted for")
    func paddingIsATiebreak() {
        // Same value, different spelling: settle it rather than leave a tie, so
        // that reading an album twice gives the same order twice.
        #expect(NaturalOrder.compare("1.flac", "01.flac") == .orderedAscending)
        #expect(NaturalOrder.compare("01 A.flac", "1 A.flac") == .orderedDescending)
    }

    @Test("a run of digits sorts ahead of a run of letters")
    func digitsBeforeLetters() {
        #expect(NaturalOrder.compare("2 Track.flac", "Two Track.flac") == .orderedAscending)
    }

    @Test("a prefix sorts before what extends it")
    func prefixesComeFirst() {
        #expect(NaturalOrder.compare("song", "song2") == .orderedAscending)
        #expect(NaturalOrder.compare("song", "songbird") == .orderedAscending)
        #expect(NaturalOrder.compare("", "a") == .orderedAscending)
        #expect(NaturalOrder.compare("", "") == .orderedSame)
    }

    @Test("an alt take sorts above the take it is an alt of")
    func spaceSortsUnderTheFullStop() {
        // Not a prefix case: the two names diverge at ` ` against `.`, and a
        // space is the lower byte. It is the reason a duplicate track number
        // puts `03 Song (alt take).flac` first, which is worth pinning because
        // that ordering is otherwise surprising to read.
        #expect(
            NaturalOrder.compare("song (alt).flac", "song.flac") == .orderedAscending
        )
    }

    @Test("a forty-digit run does not overflow anything")
    func longDigitRunsSaturate() {
        let long = String(repeating: "9", count: 40)
        _ = NaturalOrder.compare("\(long).flac", "1.flac")
        #expect(NaturalOrder.compare("\(long).flac", "\(long).flac") == .orderedSame)
    }
}
