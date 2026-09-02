import Foundation
import Testing

@testable import MUTHURKit

// MARK: - Columns

@Suite("§10 — columns")
struct ColumnTests {

    @Test("A Latin title is as wide as it is long")
    func latin() {
        #expect(Columns.width(of: "Kind of Blue") == 12)
        #expect(Columns.width(of: "") == 0)
    }

    /// The thing `wcols` exists for. A CJK title measured by its character
    /// count comes back half the truth and the artist column after it lands a
    /// dozen places to the right (`panel.sh:288`).
    @Test("A CJK title is twice as wide as its character count")
    func wide() {
        #expect("君の名は".count == 4)
        #expect(Columns.width(of: "君の名は") == 8)
        #expect(Columns.width(of: "ハルカ") == 6)
        #expect(Columns.width(of: "한국") == 4)
    }

    /// The half of the width machinery that Swift takes care of by itself.
    /// macOS hands back decomposed text, so `é` arrives as `e` and a combining
    /// acute — two characters to bash and one to Swift.
    @Test("A decomposed accent is one place, not two")
    func decomposed() {
        let composed = "Homogénic"
        let decomposed = composed.decomposedStringWithCanonicalMapping
        #expect(decomposed.unicodeScalars.count > composed.unicodeScalars.count)
        #expect(Columns.width(of: decomposed) == 9)
        #expect(Columns.width(of: composed) == 9)
    }

    /// The same problem one door along: a Hangul syllable macOS hands back
    /// decomposed leads with a conjoining jamo, and the grid has to know that a
    /// cluster starting there is still two places wide (§18.23).
    @Test("A decomposed Hangul syllable is still two places")
    func jamo() {
        let composed = "한국"
        let decomposed = composed.decomposedStringWithCanonicalMapping
        #expect(decomposed.unicodeScalars.count == 6)
        #expect(decomposed.count == 2)
        #expect(Columns.width(of: decomposed) == 4)
        #expect(Columns.width(of: composed) == 4)
    }

    @Test("A title that fits is left alone")
    func untouched() {
        #expect(Columns.truncate("Blue in Green", to: 32) == "Blue in Green")
        #expect(Columns.fit("Blue in Green", to: 15) == "Blue in Green  ")
    }

    @Test("A cut title ends in an ellipsis, and still fits")
    func truncated() {
        let cut = Columns.truncate("Libet's all joyful camaraderie", to: 20)
        #expect(cut.hasSuffix("…"))
        #expect(Columns.width(of: cut) == 20)
        #expect(cut == "Libet's all joyful …")
    }

    /// A two-column character that would straddle the last place is left out
    /// rather than half-drawn, which leaves a column over for the pad to fill
    /// (`panel.sh:345`).
    @Test("A wide character is never cut in half")
    func neverHalfDrawn() {
        let cut = Columns.truncate("君の名は。", to: 6)
        #expect(cut == "君の…")
        #expect(Columns.width(of: cut) == 5)
        // And the fit pads the column the character gave up.
        #expect(Columns.width(of: Columns.fit("君の名は。", to: 6)) == 6)
    }

    /// Two ragged edges facing each other read as a gap of no particular width;
    /// two flush ones read as a margin (`panel.sh:363`).
    @Test("Right alignment moves the slack to the front")
    func trailing() {
        #expect(Columns.fit("Bill Evans", to: 14, align: .trailing) == "    Bill Evans")
        #expect(Columns.fit("Bill Evans", to: 14, align: .leading) == "Bill Evans    ")
    }

    @Test("Every fit is exactly the width it was asked for")
    func exact() {
        let names = ["", "a", "Miles Davis", "君の名は", "Björk", "The Velvet Underground & Nico"]
        for name in names {
            for width in 1...20 {
                #expect(
                    Columns.width(of: Columns.fit(name, to: width)) == width,
                    "\(name) at \(width)"
                )
            }
        }
    }
}

// MARK: - The track list's columns

@Suite("§10 — the artist column")
struct TrackColumnTests {

    static func record(albumArtist: String, artists: [String]) -> Record {
        Record(
            tracks: artists.enumerated().map { index, artist in
                Track(
                    url: URL(fileURLWithPath: "/x/\(index).flac"), duration: 200,
                    title: "Track \(index + 1)", artist: artist, number: index + 1, disc: 1
                )
            },
            album: "An Album", albumArtist: albumArtist, year: "", sourceLabel: "x"
        )
    }

    /// A column that repeats one fact fifty times is not a column, it is a
    /// margin with writing on it (`player:2274`).
    @Test("An album drops it, and the titles get the whole width")
    func album() {
        let record = Self.record(
            albumArtist: "Miles Davis", artists: Array(repeating: "Miles Davis", count: 5)
        )
        let columns = TrackColumns.decide(for: record)
        #expect(columns.artist == 0)
        #expect(columns.title == 52)
    }

    @Test("A record with no track artists at all drops it too")
    func untagged() {
        let record = Self.record(albumArtist: "", artists: Array(repeating: "", count: 5))
        #expect(TrackColumns.decide(for: record).artist == 0)
    }

    /// The test is against the album artist rather than merely "they all
    /// agree": a record whose tracks say `Miles Davis Quintet` under an album
    /// credited to `Miles Davis` is not repeating the header, it is saying
    /// something else (`player:2301`).
    @Test("Agreeing with each other is not the same as agreeing with the header")
    func quintet() {
        let record = Self.record(
            albumArtist: "Miles Davis",
            artists: Array(repeating: "Miles Davis Quintet", count: 5)
        )
        let columns = TrackColumns.decide(for: record)
        #expect(columns.artist == 19 - 1)  // capped at 18
        #expect(columns.title == 52 - 2 - 18)
    }

    /// Sized to the longest name the record actually contains rather than to
    /// the worst case, so the titles get whatever the names do not use
    /// (`player:2281`).
    @Test("A compilation is sized to the longest name it has")
    func compilation() {
        let record = Self.record(
            albumArtist: "Various Artists", artists: ["Can", "Neu!", "Faust", "Amon Düül II"]
        )
        let columns = TrackColumns.decide(for: record)
        #expect(columns.artist == 12)
        #expect(columns.title == 52 - 2 - 12)
    }

    @Test("However long the names are, the row is still the width of the panel")
    func widthHolds() {
        let names = [["Can"], ["A Really Very Long Band Name Indeed"], ["Faust", "Can"]]
        for artists in names {
            let record = Self.record(albumArtist: "Various", artists: artists)
            let columns = TrackColumns.decide(for: record)
            let gap = columns.artist > 0 ? TrackColumns.gap : 0
            #expect(columns.title + gap + columns.artist == PanelGrid.textWidth)
        }
    }

    @Test("Decided once for the record, not per row")
    func onceOnly() {
        let record = Self.record(
            albumArtist: "Various", artists: ["Can", "Amon Düül II", "Neu!"]
        )
        let columns = TrackColumns.decide(for: record)
        // Every row is fitted to the same two numbers, so the edges stay flush.
        for track in record.running {
            #expect(Columns.width(of: Columns.fit(track.title, to: columns.title)) == columns.title)
            #expect(
                Columns.width(
                    of: Columns.fit(track.artist, to: columns.artist, align: .trailing)
                ) == columns.artist
            )
        }
    }
}

// MARK: - The meters

@Suite("§10 — the meters")
struct MeterTests {

    static func widths(_ bands: [Meter.Band]) -> [Int] {
        var last = 0
        return bands.map { band in
            defer { last = band.end }
            return band.end - last
        }
    }

    @Test("The bands fill the bar exactly, whatever the durations are")
    func exact() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let count = Int.random(in: 1...40, using: &generator)
            let durations = (0..<count).map { _ in Int.random(in: 1...900, using: &generator) }
            let units = PanelGrid.stripWidth * Meter.unitsPerCell
            let bands = Meter.bands(units: units, durations: durations)
            #expect(bands.last?.end == units)
        }
    }

    /// The comparison the meter exists to support. Walking a cumulative total
    /// and truncating made a 3:14 come out narrower than the 2:58 after it
    /// (`panel.sh:406`).
    @Test("A longer track is never drawn narrower than a shorter one")
    func monotone() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let count = Int.random(in: 2...30, using: &generator)
            let durations = (0..<count).map { _ in Int.random(in: 30...900, using: &generator) }
            let bands = Meter.bands(units: 536, durations: durations)
            guard bands.count == count else { continue }
            let widths = Self.widths(bands)
            for a in durations.indices {
                for b in durations.indices where durations[a] > durations[b] {
                    #expect(widths[a] >= widths[b], "\(durations) → \(widths)")
                }
            }
        }
    }

    /// The exact case the comment names: a 3:14 and a 2:58 side by side.
    @Test("3:14 is visibly longer than 2:58")
    func the314() {
        let bands = Meter.bands(units: 536, durations: [194, 178])
        let widths = Self.widths(bands)
        #expect(widths[0] > widths[1])
    }

    /// So the two tracks either side of it still contrast (`panel.sh:448`).
    @Test("A track too short to earn any width gets no band and no colour")
    func tooShort() {
        // One second between two twenty-minute sides, on a narrow bar.
        let bands = Meter.bands(units: 16, durations: [1200, 1, 1200])
        #expect(bands.count == 2)
        #expect(bands[0].shade == 0)
        #expect(bands[1].shade == 1)
    }

    @Test("Four shades, zigzagging round again")
    func shades() {
        let bands = Meter.bands(units: 800, durations: Array(repeating: 100, count: 9))
        #expect(bands.map(\.shade) == [0, 1, 2, 3, 0, 1, 2, 3, 0])
    }

    @Test("Nothing to measure draws nothing")
    func empty() {
        #expect(Meter.bands(units: 100, durations: []).isEmpty)
        #expect(Meter.bands(units: 100, durations: [0, 0]).isEmpty)
        #expect(Meter.bands(units: 0, durations: [100]).isEmpty)
    }

    @Test("Every cell of every bar is accounted for")
    func widthOfCells() {
        let bands = Meter.bands(for: [200, 300, 250], cells: 67)
        for head in stride(from: 0, through: 536, by: 17) {
            #expect(Meter.cells(head: head, bands: bands, width: 67).count == 67)
        }
    }

    /// It is the one thing on the bar that is moving, and it is gone again in a
    /// second (`panel.sh:484`).
    @Test("The head wins the cell it is in, boundary or not")
    func headWins() {
        // A boundary at unit 80 — the tenth cell — and the head inside it.
        let bands = [Meter.Band(end: 84, shade: 0), Meter.Band(end: 160, shade: 1)]
        let cells = Meter.cells(head: 83, bands: bands, width: 20)
        #expect(cells[10] == .head(eighths: 3))
    }

    @Test("A boundary mid-cell carries the band on the other side of it")
    func boundary() {
        let bands = [Meter.Band(end: 84, shade: 0), Meter.Band(end: 160, shade: 1)]
        let cells = Meter.cells(head: 160, bands: bands, width: 20)
        #expect(cells[10] == .boundary(eighths: 4, shade: 0, under: 1))
    }

    /// The last band meets the run-out, which is not another band.
    @Test("The last boundary has nothing under it")
    func lastBoundary() {
        let bands = [Meter.Band(end: 84, shade: 0)]
        let cells = Meter.cells(head: 200, bands: bands, width: 20)
        #expect(cells[10] == .boundary(eighths: 4, shade: 0, under: nil))
        #expect(cells[11] == .runout)
    }

    /// A meter with nothing moving on it passes the full width, so nothing is
    /// ever behind the head there (`panel.sh:479`).
    @Test("A still meter is all bands and no run-out inside them")
    func still() {
        let bands = Meter.bands(for: [200, 300, 250], cells: 40)
        let cells = Meter.cells(head: 320, bands: bands, width: 40)
        #expect(!cells.contains(.runout))
        #expect(!cells.contains { if case .head = $0 { true } else { false } })
    }

    @Test("Nothing played yet is all run-out")
    func atRest() {
        let bands = Meter.bands(for: [200, 300], cells: 30)
        #expect(Meter.cells(head: 0, bands: bands, width: 30).allSatisfy { $0 == .runout })
    }

    @Test("The track bar is one band, one head and a tail")
    func trackBar() {
        let cells = Meter.trackCells(done: 0, total: 200, width: 20)
        #expect(cells.allSatisfy { $0 == .runout })

        let half = Meter.trackCells(done: 100, total: 200, width: 20)
        #expect(half[0] == .band(shade: 0))
        #expect(half[9] == .band(shade: 0))
        #expect(half[10] == .runout)

        let done = Meter.trackCells(done: 200, total: 200, width: 20)
        #expect(done.allSatisfy { $0 == .band(shade: 0) })
    }

    /// A track whose length is not known yet, and one seeked past its own end.
    @Test("The track bar survives a length of nothing and a head past the end")
    func trackBarEdges() {
        #expect(Meter.trackCells(done: 30, total: 0, width: 20).allSatisfy { $0 == .runout })
        #expect(
            Meter.trackCells(done: 900, total: 200, width: 20)
                .allSatisfy { $0 == .band(shade: 0) }
        )
    }

    /// Eight times the resolution without one extra column (`panel.sh:398`).
    @Test("Eighths, so a few cells still separate two nearly equal tracks")
    func eighths() {
        // Two tracks nine seconds apart on a six-cell bar: at one unit per cell
        // they would be identical, at eight they are not.
        let coarse = Self.widths(Meter.bands(units: 6, durations: [194, 185]))
        let fine = Self.widths(Meter.bands(units: 48, durations: [194, 185]))
        #expect(coarse[0] == coarse[1])
        #expect(fine[0] > fine[1])
    }
}

// MARK: - The cursor

@Suite("§6 — the cursor and the playhead")
struct CursorTests {

    /// Usually they agree; when you browse ahead they do not (`player:2344`).
    @Test("Browsing stops the cursor chasing the music")
    func browsing() {
        var cursor = Cursor()
        #expect(cursor.follows)
        cursor.browse(by: 3, rows: 8, count: 12)
        #expect(cursor.row == 3)
        #expect(!cursor.follows)

        // And the music moving on does not drag it back.
        cursor.trackStarted(1, rows: 8, count: 12)
        #expect(cursor.row == 3)
    }

    @Test("A cursor that is still following goes where the music went")
    func following() {
        var cursor = Cursor()
        cursor.trackStarted(5, rows: 8, count: 12)
        #expect(cursor.row == 5)
        #expect(cursor.follows)
    }

    /// `⏎`, `n`, `p`, a click on the album meter and the resume offer all put
    /// it back to following (`player:2693`).
    @Test("Picking something with it puts it back to following")
    func choosing() {
        var cursor = Cursor()
        cursor.browse(by: 4, rows: 8, count: 12)
        #expect(!cursor.follows)
        cursor.choose(4, rows: 8, count: 12)
        #expect(cursor.follows)
    }

    @Test("It never leaves the record")
    func clamped() {
        var cursor = Cursor()
        cursor.browse(by: -5, rows: 8, count: 12)
        #expect(cursor.row == 0)
        cursor.browse(by: 99, rows: 8, count: 12)
        #expect(cursor.row == 11)
    }

    /// A record that has lost a track since the cursor was last put somewhere.
    @Test("A record that has shrunk does not leave it pointing off the end")
    func shrunk() {
        var cursor = Cursor()
        cursor.browse(by: 11, rows: 8, count: 12)
        cursor.reflow(rows: 8, count: 4)
        #expect(cursor.row == 3)
    }

    /// §18.22, **answered**: the fourth line goes in.
    ///
    /// The script pulls the window only *towards* the cursor and never pushes it
    /// back when it has more room than it needs — three lines and no fourth
    /// (`player:2904`) — so a list that suddenly has room to spare sat low in
    /// its window with blank underneath until the cursor next moved. Rare in a
    /// terminal you resize twice a day; the thing you are looking at the whole
    /// time in a window with a corner to drag.
    @Test("A window with room to spare pulls the list back up to fill it")
    func windowRecovers() {
        var cursor = Cursor()
        cursor.browse(by: 11, rows: 8, count: 12)
        #expect(cursor.top == 4)

        // The record shrinks under it: four rows, room for eight.
        cursor.reflow(rows: 8, count: 4)
        #expect(cursor.top == 0)
        let (visible, more) = cursor.window(rows: 8, count: 4)
        #expect(visible == 0..<4)
        #expect(more == 0)
    }

    /// The other half of the same fourth line, and the reason it is safe: it
    /// only ever fires when the list cannot fill the window from where it is,
    /// which is never true in the case bash was actually in.
    @Test("A window smaller than the list is left exactly where the script left it")
    func windowUnchangedWhenFull() {
        var cursor = Cursor()
        cursor.browse(by: 11, rows: 5, count: 40)
        #expect(cursor.top == 7)

        // Still far more list than window: the fourth line has nothing to say.
        cursor.reflow(rows: 5, count: 40)
        #expect(cursor.top == 7)

        // Dragged taller, but still short of the list: the window grows
        // downward from where it was, exactly as the three lines always did.
        cursor.reflow(rows: 12, count: 40)
        #expect(cursor.top == 7)

        // Taller than what is left below it, and now it comes back up — but
        // only as far as it must to fill itself.
        cursor.reflow(rows: 36, count: 40)
        #expect(cursor.top == 4)
        #expect(cursor.row == 11)
    }

    /// Walking down a list scrolls a row at a time from the bottom rather than
    /// jumping a page (`player:2904`).
    @Test("The window moves only as far as it has to")
    func window() {
        var cursor = Cursor()
        for _ in 0..<5 { cursor.browse(by: 1, rows: 5, count: 20) }
        #expect(cursor.row == 5)
        #expect(cursor.top == 1)

        for _ in 0..<3 { cursor.browse(by: -1, rows: 5, count: 20) }
        #expect(cursor.row == 2)
        #expect(cursor.top == 1)  // still inside the window, so nothing moved

        cursor.browse(by: -2, rows: 5, count: 20)
        #expect(cursor.top == 0)
    }

    @Test("What is on screen, and what is below the fold")
    func fold() {
        var cursor = Cursor()
        let (visible, more) = cursor.window(rows: 5, count: 12)
        #expect(visible == 0..<5)
        #expect(more == 7)

        cursor.browse(by: 11, rows: 5, count: 12)
        let (end, none) = cursor.window(rows: 5, count: 12)
        #expect(end == 7..<12)
        #expect(none == 0)
    }

    @Test("A list shorter than the window has nothing below the fold")
    func short() {
        let cursor = Cursor()
        let (visible, more) = cursor.window(rows: 20, count: 3)
        #expect(visible == 0..<3)
        #expect(more == 0)
    }
}

// MARK: - The words on the panel

@Suite("§10 — the readouts")
struct ReadoutTests {

    @Test("Minutes are not padded and seconds always are")
    func mmss() {
        #expect(Readout.mmss(0) == "0:00")
        #expect(Readout.mmss(7) == "0:07")
        #expect(Readout.mmss(95) == "1:35")
        #expect(Readout.mmss(2513) == "41:53")
        #expect(Readout.mmss(-4) == "0:00")
    }

    @Test("The track readout counts rows, and pads both of them")
    func trackLabel() {
        #expect(Readout.trackLabel(row: 0, of: 9) == "TRACK 01 OF 09")
        #expect(Readout.trackLabel(row: 10, of: 11) == "TRACK 11 OF 11")
    }

    /// D25's argument, made about the list rather than the offer: a folder of
    /// untagged rips is every row at 9999, and this column still counts.
    @Test("The row number is the row, never the tag")
    func rowNumber() {
        #expect(Readout.rowNumber(0) == "01")
        #expect(Readout.rowNumber(Track.noNumber) == "10000")
        #expect(Readout.rowNumber(11) == "12")
    }

    @Test("The counter is the pair, in the order you read them")
    func counter() {
        #expect(Readout.counter(95, 194) == "1:35 / 3:14")
    }

    @Test("What is below the fold, worded the one way")
    func more() {
        #expect(Readout.more(7) == "▾ 7 MORE")
    }

    /// The deck owns its own messages; this is the one the panel says on its
    /// own behalf, before there is anything playing to have an opinion.
    @Test("The status line is pinned to its character")
    func status() {
        #expect(PlaybackEngine.Status.shuffle(true).text == "▪ SHUFFLE ON")
        #expect(PlaybackEngine.Status.shuffle(false).text == "▪ SHUFFLE OFF")
        #expect(PlaybackEngine.Status.repeatMode(.off).text == "▪ REPEAT OFF")
        #expect(PlaybackEngine.Status.repeatMode(.album).text == "▪ REPEAT ALBUM")
        #expect(PlaybackEngine.Status.repeatMode(.track).text == "▪ REPEAT TRACK")
        #expect(Readout.status("RESUME AT 5 · 1:35 — PRESS U").hasPrefix("▪ "))
    }

    @Test("The playing mark is not a second arrow")
    func marks() {
        #expect(Readout.Mark.playing.glyph == "♪")
        #expect(Readout.Mark.held.glyph == "‖")
        #expect(Readout.Mark.playing.glyph != Readout.cursorGlyph)
    }

    @Test("The faceplate says the mode, the count and where the titles came from")
    func faceplate() {
        #expect(
            Faceplate.meta(mode: .playing, trackCount: 9, source: .tags)
                == "PLAYING · 9 TRACKS · tags"
        )
        #expect(
            Faceplate.meta(mode: .paused, trackCount: 12, source: .musicBrainz)
                == "PAUSED · 12 TRACKS · MusicBrainz"
        )
        #expect(Faceplate.meta(mode: .stopped, trackCount: 1, source: nil) == "STOPPED · 1 TRACKS")
    }

    @Test("The rule takes up whatever the badge and the meta leave, so the meta ends flush")
    func rule() {
        // The line is two of margin, the badge with a space either side, a
        // space, the rule, a space, the meta. What matters is that the last
        // character of the meta lands on the panel's right-hand edge — the same
        // edge as the end of every bar below it.
        for meta in [
            "PLAYING · 9 TRACKS · tags",
            "FINISHED · 12 TRACKS · MusicBrainz · VOL 80",
            "STOPPED · 1 TRACKS",
        ] {
            let line =
                " \(Faceplate.badge) "
                + " " + String(repeating: "━", count: Faceplate.rule(meta: meta))
                + " " + meta
            #expect(Columns.width(of: line) == PanelGrid.width)
        }
    }

    @Test("A rule squeezed to nothing stops reading as a rule")
    func shortRule() {
        // A meta long enough to eat the panel does not get to eat the rule as
        // well: the line overruns instead, which is visible, where a vanished
        // rule reads as a typo.
        let long = String(repeating: "X", count: PanelGrid.width)
        #expect(Faceplate.rule(meta: long) == 2)
    }

    @Test("The level is chrome and says which of the two things it is")
    func level() {
        #expect(Faceplate.level(volume: 0.8, muted: false) == "VOL 80")
        #expect(Faceplate.level(volume: 1, muted: false) == "VOL 100")
        // Mute is a state you can see, not a level of zero you have to infer,
        // and the level is kept while muted (§6.1a).
        #expect(Faceplate.level(volume: 0.8, muted: true) == "MUTE")
    }

    /// **The faceplate never abbreviates anything, at any window size.**
    ///
    /// It did, twice: `MU/TH/UR ━━━━━…  STOPPED`, which made 1, 10 and 100 all
    /// look like `VOL 1…`. Nothing in `faceplate` can produce that — the rule is
    /// `repv '━'` and the meta is copied through whole — so it was the drawing,
    /// and the first attempt at it only moved the width the drawing broke at.
    ///
    /// So this walks the width instead of picking one. The assertion it makes is
    /// the structural claim itself: **the window's width is not an input to this
    /// line.** Whatever the window is doing, the badge, the rule and the meta
    /// come out at their full length, and the only thing that ever gives is the
    /// rule — down to two, after which the line overruns the panel and says so
    /// (`panel.sh:257`).
    @Test("No window width can put an ellipsis on the faceplate")
    func neverAbbreviated() {
        let metas =
            Faceplate.Mode.allCases.flatMap { mode in
                [0, 9, 99].flatMap { count in
                    ([nil] + TitleSource.allCases.map { Optional($0) }).flatMap {
                        (source: TitleSource?) in
                        ["VOL 1", "VOL 100", "MUTE"].map { level in
                            Faceplate.meta(
                                mode: mode, trackCount: count, source: source, level: level)
                        }
                    }
                }
            }

        // Both wordmarks: the plate is bash's ten columns, the dot-matrix one is
        // twice the pitch and so twice as wide, and the rule gives way for it.
        for plate in [Faceplate.plateColumns, Columns.width(of: Faceplate.badge) * 2 + 2] {
            for meta in metas {
                let reference = Faceplate.line(meta: meta, plate: plate)
                #expect(!reference.contains("…"), "\(reference)")
                #expect(reference.hasSuffix(meta), "\(reference)")

                if Faceplate.rule(meta: meta, plate: plate) > 2 {
                    // Room to spare: the meta finishes flush with the right-hand
                    // edge of every bar below it.
                    #expect(Columns.width(of: reference) == PanelGrid.line)
                } else {
                    // No room: the rule has hit its floor and the line runs past
                    // the panel rather than the mode losing a letter.
                    #expect(Columns.width(of: reference) >= PanelGrid.line)
                }

                // And the sweep. Every window width the app will ever be given,
                // in whole cells: the panel is `PANEL` columns wide whatever the
                // window is doing (`player:504`), so every one of these has to
                // come back the identical line. A faceplate that is a function
                // of the window is exactly the bug that was here.
                for width in stride(from: 320.0, through: 2560.0, by: 8) {
                    let cells = max(PanelGrid.width, Int(width / 8.0361328125))
                    #expect(Faceplate.line(meta: meta, plate: plate) == reference, "\(cells) cells")
                }
            }
        }
    }
}

// MARK: - The header block

@Suite("§10 — the header block")
struct HeaderBlockTests {

    static func record(album: String = "Kind of Blue", artist: String = "Miles Davis", year: String)
        -> Record
    {
        Record(
            tracks: [
                Track(
                    url: URL(fileURLWithPath: "/x/1.flac"), duration: 200,
                    title: "So What", artist: artist, number: 1, disc: 1
                )
            ],
            album: album, albumArtist: artist, year: year, sourceLabel: "Kind of Blue [1959]"
        )
    }

    /// D6, as amended. MusicBrainz where it answered, the tags where it did
    /// not, the collection last — the script's own order, where the lookup
    /// overwrites the tag year (`player:2215`).
    @Test("The year comes from MusicBrainz, then the tags, then the collection")
    func year() {
        #expect(HeaderBlock.year(tags: "1959", musicBrainz: "1997", collection: "2001") == "1997")
        #expect(HeaderBlock.year(tags: "1959", musicBrainz: "", collection: "2001") == "1959")
        #expect(HeaderBlock.year(tags: "", musicBrainz: "1997", collection: "2001") == "1997")
        #expect(HeaderBlock.year(tags: "", musicBrainz: "", collection: "2001") == "2001")
        #expect(HeaderBlock.year(tags: "", musicBrainz: nil, collection: nil) == "")
    }

    /// The bug D6 fixes: in bash a record *not* in the collection showed no
    /// year anywhere at all.
    @Test("A record nobody has shelved still shows its own year")
    func unshelved() {
        let header = HeaderBlock(record: Self.record(year: "1959"))
        #expect(header.rows[1].value == "Miles Davis (1959)")
        #expect(header.rows.count == 3)
    }

    @Test("The shelf lines arrive only when the record is on the shelf")
    func shelved() {
        let header = HeaderBlock(
            record: Self.record(year: "1959"),
            shelf: HeaderBlock.Shelf(shelf: "Jazz / A–M", note: "the 1997 remaster", year: "1997")
        )
        #expect(header.rows.map(\.label) == ["ALBUM", "ARTIST", "SOURCE", "SHELF", "NOTE"])
        // SHELF has stopped carrying the year, and the tags won it anyway.
        #expect(header.rows[1].value == "Miles Davis (1959)")
        #expect(header.rows[3].value == "Jazz / A–M")
        #expect(header.rows[4].annotated)
    }

    /// The faceplate says where the titles came from, and saying it twice on
    /// one screen reads like two different facts (`player:2325`).
    @Test("The metadata source is not repeated here")
    func notRepeated() {
        let header = HeaderBlock(record: Self.record(year: ""))
        for source in TitleSource.allCases {
            #expect(!header.rows.contains { $0.value == source.rawValue })
        }
    }

    @Test("Nothing at all is a dash, not a blank")
    func dash() {
        let header = HeaderBlock(record: Self.record(album: "", artist: "", year: ""))
        #expect(header.rows[0].value == "—")
        #expect(header.rows[1].value == "—")
    }
}

/// `art_tick`'s three bounds (`player:3133`).
@Suite("How big the sleeve is allowed to be")
struct SleeveFrameTests {

    /// The cell this app actually measures, so the numbers below are the numbers
    /// on screen rather than the terminal's assumed 2.
    static let aspect = 20.0 / 8.0361328125

    static func rows(columns: Int, toAnalyser: Int) -> Int? {
        SleeveFrame.rows(
            availableColumns: columns, rowsToAnalyser: toAnalyser, cellAspect: aspect)
    }

    @Test("Width is the bound when the panel is tall and the window is not wide")
    func width() {
        // 60 columns is 24 rows of a 2.489:1 cell, with change.
        #expect(Self.rows(columns: 60, toAnalyser: 40) == 24)
    }

    @Test("The analyser is the bound when the window is wide")
    func analyser() {
        #expect(Self.rows(columns: 400, toAnalyser: 19) == 19)
    }

    /// `ART_MIN=12`, measured in columns as bash measures it: below it there is
    /// no sleeve, and the panel is exactly the panel. Not a small sleeve — none.
    @Test("Under the minimum there is no sleeve at all")
    func minimum() {
        // Twelve columns is under five rows, and five rows is under twelve
        // columns again once the cell's aspect is undone — so it does not draw.
        #expect(Self.rows(columns: 12, toAnalyser: 40) == nil)
        // One more column and it clears the bar.
        #expect(Self.rows(columns: 13, toAnalyser: 40) == 5)
        // The panel being tall does not rescue a window that is narrow.
        #expect(Self.rows(columns: 11, toAnalyser: 10_000) == nil)
    }

    /// The other side of the same bound: a panel with almost no room above the
    /// analyser cannot have a sleeve either, however wide the window is.
    @Test("A squeezed panel loses the sleeve rather than shrinking it")
    func squeezed() {
        #expect(Self.rows(columns: 2000, toAnalyser: 4) == nil)
        #expect(Self.rows(columns: 2000, toAnalyser: 5) == 5)
    }

    /// **There is no ceiling (D2).** A window dragged wide keeps giving the
    /// sleeve more, which is how you ask for a bigger one.
    @Test("No ART_MAX: a wider window is a bigger sleeve, without limit")
    func noCeiling() {
        var last = 0
        for columns in stride(from: 40, through: 2000, by: 40) {
            let rows = Self.rows(columns: columns, toAnalyser: 10_000) ?? 0
            #expect(rows >= last)
            last = rows
        }
        #expect(last > 42)
    }

    @Test("A window with nothing spare has no sleeve")
    func nothingSpare() {
        #expect(Self.rows(columns: 0, toAnalyser: 40) == nil)
        #expect(Self.rows(columns: -20, toAnalyser: 40) == nil)
        #expect(Self.rows(columns: 400, toAnalyser: 0) == nil)
    }

    /// The cover starts level with the album title, in the gutter's own column
    /// (`player:504`, `player:1746`).
    @Test("It sits at column 74, row 3")
    func where_() {
        #expect(PanelGrid.line == 71)
        #expect(PanelGrid.gutterToSleeve == 2)
        #expect(PanelGrid.sleeveColumn == 73)  // zero-based: bash's column 74
        #expect(PanelGrid.sleeveRow == 3)
        #expect(PanelGrid.sleeveMinimum == 12)
    }
}

@Suite("§10 — the keycaps")
struct KeycapTests {

    @Test("Both rows, and every cap on them says what it does")
    func legend() {
        #expect(Readout.legend.count == 2)
        for cap in Readout.legend.flatMap({ $0 }) {
            #expect(!cap.presses.isEmpty, "\(cap.key) is a switch wired to nothing")
            #expect(!cap.label.isEmpty)
        }
    }

    /// A cap that has to wrap has stopped being a legend (`player:2429`).
    ///
    /// **Every legend**, not just the playing one — and the picker has two
    /// shapes since **D50** (a disc in the bay, or an empty one), so both are
    /// measured. The picker's row is the one that grows: `BROWSE` (§14) went on
    /// it, and this is the only thing standing between the next addition and a
    /// wrapped row.
    @Test("Each row fits the panel it is drawn on")
    func fits() {
        let legends =
            Readout.legend + Readout.pickerLegend(hasDisc: true)
            + Readout.pickerLegend(hasDisc: false) + Readout.checkLegend
        for caps in legends {
            // The plate is ` KEY `, the legend is ` LABEL`, and three columns
            // between one cap and the next.
            let width = caps.reduce(0) { total, cap in
                total + Columns.width(of: " \(cap.key) ") + Columns.width(of: " \(cap.label)")
            }
            #expect(width + (caps.count - 1) * 3 <= PanelGrid.width)
        }
    }

    /// `←→` and `↑↓` are two glyphs on one plate, which is a rocker and not a
    /// button. Everything else is a single throw.
    @Test("The rockers are the two with two ends, and they are the two that repeat")
    func rockers() {
        let rockers = Readout.legend.flatMap { $0 }.filter { $0.presses.count > 1 }
        #expect(rockers.map(\.key) == ["←→", "↑↓"])
        for cap in rockers {
            #expect(cap.presses.count == 2)
            #expect(cap.presses.allSatisfy(Readout.repeats))
        }
        for cap in Readout.legend.flatMap({ $0 }) where cap.presses.count == 1 {
            #expect(!Readout.repeats(cap.presses[0]), "held \(cap.key) is a coin being flipped")
        }
    }

    /// The legend is a picture of the keyboard, so anything the caps can ask for
    /// has to be something a key asks for too — and the other way round is not
    /// required, because `u`, `m` and the volume pair are deliberately not on it.
    @Test("Every press a cap can make is one the legend names")
    func wired() {
        let playing = Set(Readout.legend.flatMap { $0 }.flatMap(\.presses))
        let picker = Set(Readout.pickerLegend(hasDisc: true).flatMap { $0 }.flatMap(\.presses))
        let check = Set(Readout.checkLegend.flatMap { $0 }.flatMap(\.presses))
        let all = playing.union(picker).union(check)
        #expect(all == Set(Readout.Press.allCases))
    }

    /// **D50.** `OPEN` is on the picker's legend only when there is something to
    /// open. A cap for a key that does nothing is worse than no cap: it is the
    /// panel promising something the bay cannot deliver.
    @Test("The picker offers OPEN only when the bay has something in it")
    func theOpenCapFollowsTheDisc() {
        let withDisc = Readout.pickerLegend(hasDisc: true).flatMap { $0 }
        let empty = Readout.pickerLegend(hasDisc: false).flatMap { $0 }
        #expect(withDisc.map(\.label) == ["OPEN", "RESCAN", "BROWSE", "QUIT"])
        #expect(empty.map(\.label) == ["RESCAN", "BROWSE", "QUIT"])
        // `RESCAN` survives an empty bay because an empty bay is exactly when it
        // means something: it is how a disc put in after launch gets noticed.
        #expect(empty.contains { $0.presses.contains(.rescan) })
    }
}
