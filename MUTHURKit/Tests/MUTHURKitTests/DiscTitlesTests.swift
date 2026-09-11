import Foundation
import Testing

@testable import MUTHURKit

/// A CD-Text tool with its answer already in it.
struct StubCDText: CDTextSource {
    let output: String?
    func cdTextOutput() async -> String? { output }
}

/// A drive with a table of contents already in it.
struct StubTOC: TableOfContentsSource {
    let toc: TableOfContents?
    func tableOfContents() async -> TableOfContents? { toc }
}

/// §4, §4.1, §4.4 — the chain, from a disc with nothing on it but audio.
@Suite("Disc — where the titles came from")
struct DiscTitlesTests {

    static let discID = DiscIDTests.sevenTrack.discID

    /// What macOS mounts an audio CD as: `N Audio Track.aiff`, no tags at all.
    /// The track number is rescued off the filename (`player:1454`) because
    /// without it every row is 9999 and nothing §4 learns can be written back.
    static func mounted(_ count: Int, album: String = "") -> Record {
        let tracks = (1...count).map { n in
            Track(
                url: URL(fileURLWithPath: "/Volumes/Audio CD/\(n) Audio Track.aiff"),
                raw: RawMetadata(), discFallback: 1, numberFromFilename: true
            )
        }
        return Record(
            tracks: tracks, album: album, albumArtist: "", year: "", sourceLabel: "Audio CD"
        )
    }

    static func discAnswer(_ titles: [String], album: String = "Nonagon Infinity") -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "releases": [
                [
                    "id": "rel-1",
                    "title": album,
                    "artist-credit": [["name": "King Gizzard"]],
                    "date": "2016-04-29",
                    "media": [
                        [
                            "discs": [["id": DiscTitlesTests.discID]],
                            "tracks": titles.map { ["title": $0] },
                        ]
                    ],
                ]
            ]
        ])
    }

    // MARK: - §3's rescue, which the whole of §4 rests on

    @Test("A CDDA volume's track numbers come off the filenames")
    func rescue() {
        let record = DiscTitlesTests.mounted(3)
        #expect(record.tracks.map(\.number) == [1, 2, 3])
        #expect(record.unnumberedCount == 0)
    }

    @Test("Nowhere else does a filename decide anything")
    func rescueIsCDOnly() {
        let track = Track(
            url: URL(fileURLWithPath: "/x/01 - Robot Stop.flac"), raw: RawMetadata()
        )
        #expect(track.number == Track.noNumber)
    }

    @Test("A name that does not start with digits stays unnumbered")
    func rescueNeedsDigits() {
        let track = Track(
            url: URL(fileURLWithPath: "/Volumes/Audio CD/Audio Track.aiff"),
            raw: RawMetadata(), numberFromFilename: true
        )
        #expect(track.number == Track.noNumber)
    }

    @Test("A tag always wins over the name")
    func tagBeatsName() {
        var raw = RawMetadata()
        raw.track = "7"
        let track = Track(
            url: URL(fileURLWithPath: "/Volumes/Audio CD/1 Audio Track.aiff"),
            raw: raw, numberFromFilename: true
        )
        #expect(track.number == 7)
    }

    // MARK: - §4.1

    @Test("Audio Track becomes Track 01, before anything is asked")
    func defaults() {
        var record = DiscTitlesTests.mounted(11)
        DiscTitles.applyDefaults(to: &record, volumeName: "Nonagon Infinity")
        #expect(record.running.map(\.title).first == "Track 01")
        #expect(record.running.map(\.title).last == "Track 11")
    }

    @Test("The album falls back to the volume name")
    func albumFromVolume() {
        var record = DiscTitlesTests.mounted(2)
        DiscTitles.applyDefaults(to: &record, volumeName: "Nonagon Infinity")
        #expect(record.album == "Nonagon Infinity")
    }

    @Test("A title that is not an Audio Track is left alone")
    func defaultsLeaveRealTitlesAlone() {
        var record = DiscTitlesTests.mounted(2)
        record.tracks[0].title = "Robot Stop"
        DiscTitles.applyDefaults(to: &record, volumeName: "X")
        #expect(record.tracks[0].title == "Robot Stop")
        #expect(record.tracks[1].title == "Track 02")
    }

    // MARK: - The chain

    @Test("Nothing to ask: the track numbers stay, and the panel says so")
    func nothingAnswers() async {
        var record = DiscTitlesTests.mounted(3)
        let outcome = await DiscTitles.resolve(&record, volumeName: "Audio CD")
        #expect(outcome.source == .trackNumbers)
        #expect(record.running.map(\.title) == ["Track 01", "Track 02", "Track 03"])
    }

    @Test("The three stages of READING DISC, in order")
    func stages() async {
        var record = DiscTitlesTests.mounted(2)
        var seen: [String] = []
        _ = await DiscTitles.resolve(&record, volumeName: "Audio CD") { seen.append($0.detail) }
        #expect(seen == ["looking for CD-Text", "asking MusicBrainz", "no titles on this disc"])
        #expect(DiscTitles.Stage.heading == "READING DISC")
    }

    @Test("CD-Text names the tracks and stops the chain")
    func cdTextWins() async {
        var record = DiscTitlesTests.mounted(2)
        let transport = StubSleeveTransport([], otherwise: .body(Data()))
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD",
            cdText: StubCDText(output: CDTextTests.withArtists),
            tableOfContents: StubTOC(toc: DiscIDTests.sevenTrack),
            transport: transport
        )
        #expect(outcome.source == .cdText)
        #expect(record.running.map(\.title) == ["Robot Stop", "Big Fig Wasp"])
        #expect(record.running.map(\.artist) == ["King Gizzard", "King Gizzard"])
        #expect(record.album == "Nonagon Infinity")
        #expect(record.albumArtist == "King Gizzard")
        // The catalogue was never asked.
        #expect(transport.asked.isEmpty)
    }

    @Test("An album title on its own is not a track list")
    func albumTitleAloneIsNotCDText() async {
        // Returning success for one would stamp `CD-Text` on the faceplate over
        // a column of bare track numbers *and* rob the disc of the lookup that
        // could have named them (`player:2106`).
        var record = DiscTitlesTests.mounted(2)
        let transport = StubSleeveTransport(
            [], otherwise: .body(DiscTitlesTests.discAnswer(["Robot Stop", "Big Fig Wasp"]))
        )
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD",
            cdText: StubCDText(output: "Album title: 'From The Lead-In' from 'Somebody'"),
            tableOfContents: StubTOC(toc: DiscIDTests.sevenTrack),
            transport: transport
        )
        #expect(outcome.source == .musicBrainz)
        #expect(transport.asked.count == 1)
    }

    @Test("§18.11 → D19 — an album from CD-Text survives a CD-Text failure")
    func albumSurvivesFailure() async {
        // Kept as-is: the source label is about the *track list*, which is what
        // you are looking at. MusicBrainz overwrites what it knows better and
        // leaves the rest alone — and here it knows nothing, so the lead-in's
        // album stands under a faceplate reading `track numbers`.
        var record = DiscTitlesTests.mounted(2)
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD",
            cdText: StubCDText(output: "Album title: 'From The Lead-In' from 'Somebody'")
        )
        #expect(outcome.source == .trackNumbers)
        #expect(record.album == "From The Lead-In")
        #expect(record.albumArtist == "Somebody")
    }

    @Test("CD-Text for tracks this disc does not have does not count")
    func cdTextForAbsentTracks() async {
        var record = DiscTitlesTests.mounted(2)
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD",
            cdText: StubCDText(output: "Track  8 title: 'Nothing Here'")
        )
        #expect(outcome.source == .trackNumbers)
        #expect(record.running.map(\.title) == ["Track 01", "Track 02"])
    }

    @Test("A disc with no CD-Text tooling at all falls straight through")
    func noCDTextTool() async {
        var record = DiscTitlesTests.mounted(2)
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD", cdText: StubCDText(output: nil)
        )
        #expect(outcome.source == .trackNumbers)
    }

    // MARK: - §4.3 through the chain

    @Test("MusicBrainz names the tracks, by track number")
    func musicBrainzWins() async {
        var record = DiscTitlesTests.mounted(2)
        let transport = StubSleeveTransport(
            [], otherwise: .body(DiscTitlesTests.discAnswer(["Robot Stop", "Big Fig Wasp"]))
        )
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD",
            tableOfContents: StubTOC(toc: DiscIDTests.sevenTrack), transport: transport
        )
        #expect(outcome.source == .musicBrainz)
        #expect(outcome.discID == DiscTitlesTests.discID)
        #expect(outcome.releaseID == "rel-1")
        #expect(record.running.map(\.title) == ["Robot Stop", "Big Fig Wasp"])
        #expect(record.album == "Nonagon Infinity")
        #expect(record.albumArtist == "King Gizzard")
        #expect(record.year == "2016")
        // The disc ID is in the URL that was asked, not just in the outcome.
        #expect(transport.asked.first?.absoluteString.contains(DiscTitlesTests.discID) == true)
    }

    @Test("The nth title is track n, which is not row n")
    func titlesAreByTrackNumber() async {
        // A disc whose files come off the mount in a different order from their
        // numbers — scan order is byte order, and `10` sorts before `2`.
        var record = Record(
            tracks: [10, 2].map { n in
                Track(
                    url: URL(fileURLWithPath: "/Volumes/CD/\(n) Audio Track.aiff"),
                    raw: RawMetadata(), numberFromFilename: true
                )
            },
            album: "", albumArtist: "", year: "", sourceLabel: "CD"
        )
        let titles = (1...10).map { "Title \($0)" }
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "CD",
            tableOfContents: StubTOC(toc: DiscIDTests.sevenTrack),
            transport: StubSleeveTransport([], otherwise: .body(DiscTitlesTests.discAnswer(titles)))
        )
        #expect(outcome.source == .musicBrainz)
        #expect(record.tracks[0].title == "Title 10")
        #expect(record.tracks[1].title == "Title 2")
        // And the running order is still by track number.
        #expect(record.running.map(\.title) == ["Title 2", "Title 10"])
    }

    @Test("Offered, not landed — the script's counter and this one agree")
    func offeredNotLanded() async {
        // `mb_lookup`'s `n` moves before the row lookup (`player:2223`), so a
        // disc whose titles all come back for track numbers this record does not
        // have is still stamped `MusicBrainz`. CD-Text counts the other way. The
        // asymmetry is `player`'s; ported as found.
        var record = Record(
            tracks: [
                Track(
                    url: URL(fileURLWithPath: "/Volumes/CD/50 Audio Track.aiff"),
                    raw: RawMetadata(), numberFromFilename: true
                )
            ],
            album: "", albumArtist: "", year: "", sourceLabel: "CD"
        )
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "CD",
            tableOfContents: StubTOC(toc: DiscIDTests.sevenTrack),
            transport: StubSleeveTransport([], otherwise: .body(DiscTitlesTests.discAnswer(["One"])))
        )
        #expect(outcome.source == .musicBrainz)
        #expect(record.tracks[0].title == "Track 50")
    }

    @Test("An answer with an empty track list is a failure, not a thin success")
    func emptyTrackList() async {
        var record = DiscTitlesTests.mounted(2)
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD",
            tableOfContents: StubTOC(toc: DiscIDTests.sevenTrack),
            transport: StubSleeveTransport([], otherwise: .body(DiscTitlesTests.discAnswer([])))
        )
        #expect(outcome.source == .trackNumbers)
        // The album still came back, and the release MBID is still worth
        // keeping — §5 has nothing stronger to go on than a disc ID's release.
        #expect(record.album == "Nonagon Infinity")
        #expect(outcome.releaseID == "rel-1")
    }

    @Test("--no-mb never asks")
    func noMusicBrainz() async {
        var record = DiscTitlesTests.mounted(2)
        let transport = StubSleeveTransport(
            [], otherwise: .body(DiscTitlesTests.discAnswer(["Robot Stop"]))
        )
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD",
            tableOfContents: StubTOC(toc: DiscIDTests.sevenTrack),
            transport: transport, useMusicBrainz: false
        )
        #expect(outcome.source == .trackNumbers)
        #expect(transport.asked.isEmpty)
    }

    @Test("A drive that will not give up its table of contents is not asked about")
    func noTOC() async {
        var record = DiscTitlesTests.mounted(2)
        let transport = StubSleeveTransport(
            [], otherwise: .body(DiscTitlesTests.discAnswer(["Robot Stop"]))
        )
        let outcome = await DiscTitles.resolve(
            &record, volumeName: "Audio CD",
            tableOfContents: StubTOC(toc: nil), transport: transport
        )
        #expect(outcome.source == .trackNumbers)
        #expect(outcome.discID == nil)
        #expect(transport.asked.isEmpty)
    }

    @Test("Every failure lands in the same place")
    func failuresAreAlike() async {
        // No network, an unsubmitted disc, a rate limit, half a JSON document.
        let answers: [SleeveAnswer] = [
            .couldNotAsk,
            .body(Data()),
            .body(Data(#"{"error":"rate limited"}"#.utf8)),
            .body(Data(#"{"releases":[]}"#.utf8)),
        ]
        for answer in answers {
            var record = DiscTitlesTests.mounted(2)
            let outcome = await DiscTitles.resolve(
                &record, volumeName: "Audio CD",
                tableOfContents: StubTOC(toc: DiscIDTests.sevenTrack),
                transport: StubSleeveTransport([], otherwise: answer),
                // Each of these four is now asked twice (D81); what this test is
                // about is where the second refusal lands, not the waiting.
                retryDelay: .zero
            )
            #expect(outcome.source == .trackNumbers)
            #expect(record.running.map(\.title) == ["Track 01", "Track 02"])
        }
    }

    @Test("The four sources, spelled the way the faceplate spells them")
    func sourceLabels() {
        #expect(
            TitleSource.allCases.map(\.rawValue)
                == ["tags", "CD-Text", "MusicBrainz", "track numbers"]
        )
    }
}
