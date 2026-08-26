import Foundation
import Testing

@testable import MUTHURKit

/// §17 — what the program does when something it wanted is not there.
///
/// The degraded paths are scattered through the script and every one of them is
/// easy to skim past, which is why they are gathered in one section and now in
/// one suite. **The rule the whole program follows: the only thing worth
/// stopping for is not being able to play the record** — everything else quietly
/// becomes a worse panel, and "quietly" is the part with teeth. Most of what is
/// asserted below is the *absence* of a message, which is not a thing a feature
/// test ever accidentally covers.
///
/// Three of §17's boxes are not here and cannot be: `find_cd` returning nothing
/// (`player:965`), the picker's missing disc row (`player:1018`) and a disc
/// whose media is present but never mounts (`player:1000`) are all §1.3, which
/// does not exist yet. Their `--check` halves are in `DiagnosticsTests`; their
/// other halves are the seam this section splits at.
@Suite("§17 When something is missing")
struct MissingTests {

    // MARK: - No network

    /// **Every MusicBrainz and Cover Art Archive failure is silent and
    /// indistinguishable from every other one** (`player:2171`, whose comment
    /// calls the lookup deliberately forgiving). No error, no retry prompt, no
    /// "offline" indicator anywhere on the panel.
    ///
    /// Asserted as the absence of a vocabulary, because that is what the box
    /// actually says. A future panel line that reported the network would pass
    /// every other test in this suite and fail this one.
    @Test("An outage has no word for itself anywhere on the panel")
    func nothingOnThePanelCanSayOffline() {
        var vocabulary: [String] = []
        vocabulary += TitleSource.allCases.map(\.rawValue)
        vocabulary += [Sleeve.Source.besideTheRecord, .tags, .coverArtArchive].map(\.rawValue)
        vocabulary += Faceplate.Mode.allCases.map(\.rawValue)
        vocabulary += [
            PlaybackEngine.Status.endOfAlbum,
            .cannotRead(reason: "NO DECODER"),
            .tracksGone(missing: 3, of: 12, source: .zip),
            .tracksGone(missing: 3, of: 12, source: .folder),
        ].map(\.text)
        vocabulary += HeaderBlock(
            record: MissingTests.untagged(), shelf: HeaderBlock.Shelf(shelf: "x", note: "y")
        ).rows.map(\.label)

        // Not `MUSICBRAINZ`, which the faceplate says out loud and should: it is
        // the title source, and it only ever appears when the lookup *answered*.
        // The vocabulary that must not exist is the vocabulary of it failing.
        for word in ["OFFLINE", "NETWORK", "CONNECTION", "RETRY", "UNAVAILABLE", "LOOKUP FAILED"] {
            for line in vocabulary {
                #expect(
                    !line.uppercased().contains(word),
                    "the panel learned to say \(word): \(line)")
            }
        }
    }

    /// The sleeve's own half of the same box: with the wifi off the resolver
    /// returns no picture, tells nobody, and — D14 — leaves nothing behind that
    /// would make the next fortnight worse (`player:1921`).
    @Test("A cover fetch with no network fails into nothing at all")
    func anOutageCostsOnlyThePlayItHappenedOn() async throws {
        let cache = SleeveCache(
            directory: FileManager.default.temporaryDirectory
                .appending(path: "muthur-tests/\(UUID().uuidString)"))
        defer { try? FileManager.default.removeItem(at: cache.directory) }

        let resolver = SleeveResolver(
            probe: StubPictureProbe([:]),
            embedded: NoEmbeddedPictures(),
            transport: OfflineSleeveTransport(),
            cache: cache,
            retryDelay: .zero
        )
        let request = SleeveResolver.Request(
            directory: nil, files: [], album: "Kin", albumArtist: "KMRU"
        )
        let resolution = await resolver.resolve(request)
        #expect(resolution.sleeve == nil)
        #expect(await resolution.pending?.value == nil)

        // Nothing was written. The marker means "asked, and there is none" —
        // never "could not ask" (D14).
        let key = try #require(
            SleeveCache.key(releaseMBID: nil, albumArtist: "KMRU", album: "Kin"))
        #expect(!cache.noneIsFresh(forKey: key, now: Date()))
        #expect(!cache.hasEntry(forKey: key))
    }

    /// **A disc with no CD-Text and no network plays as `Track 01…Track NN`,
    /// source `track numbers`, and the panel says so** (`player:2237`,
    /// `player:2254`). The chain runs all three stages and comes back with the
    /// tidy default it started from.
    @Test("A disc with nothing to ask and nobody to ask plays as track numbers")
    func aSilentDiscOffTheNetworkKeepsItsNumbers() async {
        var record = DiscTitlesTests.mounted(9)
        var stages: [DiscTitles.Stage] = []
        let outcome = await DiscTitles.resolve(
            &record,
            volumeName: "Audio CD",
            cdText: StubCDText(output: nil),
            tableOfContents: StubTOC(toc: DiscIDTests.sevenTrack),
            transport: OfflineSleeveTransport(),
            stage: { stages.append($0) }
        )

        #expect(outcome.source == .trackNumbers)
        #expect(record.running.map(\.title) == (1...9).map { String(format: "Track %02d", $0) })
        // The volume's own name, because nothing else ever spoke (`player:2248`).
        #expect(record.album == "Audio CD")

        // The panel says which, and says it on the faceplate and nowhere else.
        let meta = Faceplate.meta(mode: .playing, trackCount: 9, source: outcome.source)
        #expect(meta == "PLAYING · 9 TRACKS · track numbers")
        #expect(!HeaderBlock(record: record).rows.contains { $0.label == "SOURCE-OF-TITLES" })

        // Three steps, always three — the meter is about the shape of the
        // search, not about how much of it ran.
        #expect(stages.map(\.step) == [1, 2, 3])
        #expect(stages.last?.detail == "no titles on this disc")
    }

    /// **A folder plays entirely normally.** Tags are local; the only thing lost
    /// is a cover that was not already beside the record or in the file — which
    /// is what makes §5.1 the step that matters for an untagged rip.
    @Test("A folder is unaffected by the network being gone")
    func aFolderNeedsNobody() async throws {
        let folder = try NamedFolder(
            "Rumours", files: ["01 Second Hand News.flac", "02 Dreams.flac", "cover.jpg"])
        let reader = StubMetadataReader([
            "01 Second Hand News.flac": RawMetadata(
                duration: 173, track: "1/11", title: "Second Hand News",
                album: "Rumours", artist: "Fleetwood Mac", date: "1977-02-04"),
            "02 Dreams.flac": RawMetadata(
                duration: 257, track: "2/11", title: "Dreams",
                album: "Rumours", artist: "Fleetwood Mac", date: "1977-02-04"),
        ])
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Rumours", reader: reader)

        #expect(record.running.map(\.title) == ["Second Hand News", "Dreams"])
        #expect(record.album == "Rumours")
        #expect(record.albumArtist == "Fleetwood Mac")
        #expect(record.year == "1977")
        #expect(record.total == 430)

        // And the sleeve beside it is found without asking anyone.
        let resolver = SleeveResolver(
            probe: StubPictureProbe(everythingIs: PictureSize(width: 600, height: 600)),
            embedded: NoEmbeddedPictures(),
            transport: OfflineSleeveTransport(),
            cache: SleeveCache(directory: folder.url.appending(path: "cache")),
            retryDelay: .zero
        )
        let resolution = await resolver.resolve(
            SleeveResolver.Request(record: record, directory: folder.url))
        #expect(resolution.sleeve?.source == .besideTheRecord)
        #expect(resolution.pending == nil)
    }

    // MARK: - No CD drive, or no disc in it

    /// **Not having a drive is not a warning worth escalating.** Most Macs have
    /// not had one for a decade: the check says so in one line and moves on, and
    /// none of the three drive outcomes changes the exit code (`panel.sh:596`).
    @Test("No drive, no disc and no drutil are all one line and exit zero")
    func theDriveNeverGatesAnything() throws {
        for drutil in [nil, "  Type: No Media Inserted\n", "  Type: CD-ROM\t  Name: /dev/disk4\n"] {
            for tools in [Set(["ffmpeg", "ffprobe"]), Set(["ffmpeg", "ffprobe", "drutil"])] {
                let report = Diagnostics.run(
                    DiagnosticsTests.probes(tools: tools, drutil: drutil))
                let row = try #require(DiagnosticsTests.row(report, "optical drive"))
                #expect(row.mark == .warn, "the drive escalated to \(row.mark)")
                #expect(report.exitCode == 0)
                #expect(report.verdict.hasPrefix("I CAN PLAY A RECORD"))
                // One line. Not a paragraph about buying an enclosure.
                #expect(!row.detail.contains("\n"))
            }
        }
    }

    // MARK: - A disc that will not read

    /// **CD-Text tooling that errors is treated exactly as CD-Text absent**
    /// (`player:2064`) — down to MusicBrainz, then to track numbers. The script
    /// gets this for free: it folds stderr into the capture with `2>&1`
    /// (`player:2071`), the parse finds no titles, and `[ "$titles" -gt 0 ]`
    /// returns 1 (`player:2111`). Same shape here.
    @Test("A CD-Text tool that only prints errors is a disc with no CD-Text")
    func toolingThatErrorsIsToolingThatFoundNothing() async {
        let errors = [
            "cdda2wav: Cannot open '/dev/rdisk4'. Cannot open SCSI driver.",
            "cdrecord: No such file or directory. Cannot open SCSI driver.",
            "",
        ]
        for output in errors {
            var record = DiscTitlesTests.mounted(4)
            let outcome = await DiscTitles.resolve(
                &record, volumeName: "Audio CD",
                cdText: StubCDText(output: output),
                tableOfContents: nil, transport: nil
            )
            #expect(outcome.source == .trackNumbers, "\(output) was taken for CD-Text")
            #expect(record.running.map(\.title).allSatisfy { $0.hasPrefix("Track ") })
        }
    }

    /// **A partially readable disc plays what it can**: the read skips files
    /// nothing can open (`player:1445`) and only zero readable files is fatal
    /// (`player:1494`). The meter still counts the skipped one, because the
    /// denominator counted it too — progress through the *folder*, not through
    /// the album (§18.12).
    @Test("A disc that reads eight of nine tracks is an album with eight tracks")
    func whatCanBeReadIsPlayed() async throws {
        let folder = try NamedFolder(
            "Audio CD",
            files: (1...9).map { "\($0) Audio Track.aiff" })
        var answers: [String: RawMetadata] = [:]
        for n in 1...9 where n != 4 {
            answers["\(n) Audio Track.aiff"] = RawMetadata(duration: 200)
        }

        let seen = Progress()
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Audio CD",
            numbersFromFilenames: true,
            reader: StubMetadataReader(answers),
            progress: { seen.append($0) }
        )

        #expect(record.tracks.count == 8)
        #expect(record.unreadableCount == 1)
        #expect(record.running.map(\.number) == [1, 2, 3, 5, 6, 7, 8, 9])
        // Eight reports for nine files — the skipped one draws no line. But the
        // denominator counted it, so the gap is where 44% would have been and
        // the meter still arrives at 100 rather than stopping at 88.
        #expect(seen.percents == [11, 22, 33, 55, 66, 77, 88, 100])
        #expect(seen.last?.total == 9)

        // Zero readable is the one that is fatal, and it is a different failure
        // from an empty folder.
        let broken = try NamedFolder("Broken", files: ["a.flac", "b.flac"])
        await #expect(throws: Record.Failure.noReadableAudio(source: "Broken")) {
            try await Record.read(
                directory: broken.url, sourceLabel: "Broken",
                reader: StubMetadataReader([:]))
        }
        let empty = try NamedFolder("Empty", files: ["notes.txt"])
        await #expect(throws: Record.Failure.noAudio(source: "Empty")) {
            try await Record.read(
                directory: empty.url, sourceLabel: "Empty", reader: StubMetadataReader([:]))
        }
    }

    /// **A disc that mounts and then stops responding is §6.3**, and §6.3 does
    /// not know what filesystem it is on: the whole record is stat-ed and the
    /// message distinguishes files that are *gone* from files that are *there
    /// and will not open* (`player:3285`, `player:3315`). Both sentences are
    /// asserted here as §17's restatement of them; the disc in the drive that
    /// would produce the first is §19's business.
    @Test("A record that stops responding says which of the two things happened")
    func thereAreTwoSentencesAndTheyAreDifferent() {
        let gone = PlaybackEngine.Status.tracksGone(missing: 9, of: 9, source: .folder)
        #expect(gone.text == "▪ 9 OF 9 TRACKS ARE NO LONGER ON DISK — STOPPED HERE")

        let unreadable = PlaybackEngine.Status.cannotRead(reason: "NO DECODER")
        #expect(unreadable.text.contains("CANNOT READ THIS TRACK · NO DECODER"))
        #expect(unreadable.text.contains("⏎ TO TRY ANOTHER"))

        // Neither is `END OF ALBUM`, which is the confusion §6.3 exists to
        // prevent: fifty tracks failing in two seconds is not a record ending.
        #expect(gone.text != PlaybackEngine.Status.endOfAlbum.text)
        #expect(!gone.text.contains("END OF ALBUM"))
        #expect(!unreadable.text.contains("END OF ALBUM"))
    }

    // MARK: - A folder with mixed formats

    /// **Twelve extensions, case-insensitive, in one album with no special case
    /// anywhere** (`player:1046`). A folder of FLACs with one MP3 bonus track is
    /// one album, and the MP3 is not last because it is an MP3.
    @Test("A mixed-format folder is one record and the extension decides nothing")
    func mixedFormatsAreOneAlbum() async throws {
        // The glob, read out of the script and counted: twelve `-iname` terms,
        // not the thirteen §17 said before this was checked.
        #expect(AudioFiles.extensions.count == 12)
        #expect(
            AudioFiles.extensions == [
                "aif", "aiff", "flac", "mp3", "ogg", "opus", "wav", "m4a", "wma", "ape",
                "alac", "mp4",
            ])

        // `-iname`, so the case on disk is not the case in the set.
        for spelling in ["A.FLAC", "b.Mp3", "c.OpUs", "d.AIFF"] {
            #expect(AudioFiles.isAudio(URL(fileURLWithPath: "/x/\(spelling)")))
        }
        #expect(!AudioFiles.isAudio(URL(fileURLWithPath: "/x/cover.jpg")))
        #expect(!AudioFiles.isAudio(URL(fileURLWithPath: "/x/notes.TXT")))

        let folder = try NamedFolder(
            "Mixed",
            files: ["01 One.FLAC", "02 Two.flac", "03 Bonus.Mp3", "04 Four.OPUS", "scan.png"])
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Mixed",
            reader: StubMetadataReader([
                "01 One.FLAC": RawMetadata(duration: 100, track: "1", album: "Mixed"),
                "02 Two.flac": RawMetadata(duration: 100, track: "2"),
                "03 Bonus.Mp3": RawMetadata(duration: 100, track: "3"),
                "04 Four.OPUS": RawMetadata(duration: 100, track: "4"),
            ]))
        #expect(record.tracks.count == 4)
        #expect(record.running.map(\.number) == [1, 2, 3, 4])
        #expect(record.unreadableCount == 0)
    }

    // MARK: - A folder with no metadata at all

    /// The album this section is about: nothing in any tag, only names.
    static func untagged(
        _ files: [String] = ["Track A.aiff", "Track B.aiff", "Track C.aiff"],
        label: String = "Some Rip"
    ) -> Record {
        Record(
            tracks: files.map {
                Track(url: URL(fileURLWithPath: "/x/\(label)/\($0)"), raw: RawMetadata(duration: 60))
            },
            album: Record.albumFromSourceLabel(label),
            albumArtist: "", year: "", sourceLabel: label
        )
    }

    /// **Every track sorts on key 9999 and is ordered by natural filename**
    /// (`player:1451`, `player:1511`) — which for `01 … 12` is the right answer
    /// by accident, and for `Track A/Track B` is the only answer available.
    @Test("With no track numbers the filenames are all there is, sorted naturally")
    func nothingButNames() async throws {
        let names = ["10 Ten.wav", "2 Two.wav", "1 One.wav", "Coda.wav"]
        let folder = try NamedFolder("Some Rip", files: names)
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Some Rip",
            reader: StubMetadataReader(
                Dictionary(uniqueKeysWithValues: names.map { ($0, RawMetadata(duration: 60)) })))

        #expect(record.tracks.allSatisfy { $0.number == Track.noNumber })
        #expect(record.unnumberedCount == record.tracks.count)
        // Natural, not byte order: 2 before 10, which is the whole reason
        // `sort -V` is the third key.
        #expect(
            record.running.map { $0.url.lastPathComponent }
                == ["1 One.wav", "2 Two.wav", "10 Ten.wav", "Coda.wav"])
        // Nothing is a filename decision except this: the CD-only rescue at
        // `player:1454` is off, so no row got a number out of its name.
        #expect(record.running.first?.number == Track.noNumber)
    }

    /// **Every title is the file's basename** (`player:1481`) — with its
    /// extension, which is what the script falls back to and what you would
    /// rather see than a blank row.
    @Test("An untagged row is titled with the name of its file, extension and all")
    func theTitleIsTheFilename() async throws {
        let folder = try NamedFolder("Some Rip", files: ["Track A.aiff", "Track B.aiff"])
        let record = try await Record.read(
            directory: folder.url, sourceLabel: "Some Rip",
            reader: StubMetadataReader([
                "Track A.aiff": RawMetadata(duration: 60),
                "Track B.aiff": RawMetadata(duration: 60),
            ]))
        #expect(record.running.map(\.title) == ["Track A.aiff", "Track B.aiff"])
        #expect(record.running.allSatisfy { !$0.title.isEmpty })
    }

    /// **Album is the folder's own name, or the zip's minus `.zip`**
    /// (`player:1497`). **Artist and year stay empty and the panel simply has
    /// less on it — no placeholder, no "Unknown Artist".**
    @Test("The folder names the album, and nothing invents an artist")
    func noPlaceholders() {
        #expect(Record.albumFromSourceLabel("KMRU - Peel.zip") == "KMRU - Peel")
        // §18.16: the suffix comes off whatever case it is written in.
        #expect(Record.albumFromSourceLabel("KMRU - Kin.ZIP") == "KMRU - Kin")
        #expect(Record.albumFromSourceLabel("Some Rip") == "Some Rip")

        let record = MissingTests.untagged()
        #expect(record.album == "Some Rip")
        #expect(record.albumArtist.isEmpty)
        #expect(record.year.isEmpty)

        let rows = HeaderBlock(record: record).rows
        #expect(rows.map(\.label) == ["ALBUM", "ARTIST", "SOURCE"])
        #expect(rows[0].value == "Some Rip")
        // An em dash, which reads as a line with nothing in it rather than as a
        // line that failed to print (`player:2325`) — and is not a name.
        #expect(rows[1].value == "—")
        for row in rows {
            for invention in ["Unknown", "Various", "N/A", "Untitled"] {
                #expect(!row.value.contains(invention), "\(row.label) invented \(invention)")
            }
        }
        // No year and no artist means no parenthesis either.
        #expect(!rows[1].value.contains("("))
    }

    /// **Source stays `tags` even when there were none**, because for a folder
    /// there is nothing else it could be. Only a CD gets a fallback chain (§4).
    @Test("A folder's titles came from tags even when the tags were empty")
    func aFolderHasOnlyOneSource() {
        let record = MissingTests.untagged()
        let meta = Faceplate.meta(mode: .playing, trackCount: record.tracks.count, source: .tags)
        #expect(meta == "PLAYING · 3 TRACKS · tags")
        // `track numbers` is the disc's answer and belongs to the disc: a folder
        // reaching it would mean §4's chain had run somewhere it never runs.
        #expect(!meta.contains("track numbers"))
    }

    /// **The sleeve is still looked for beside the record** (§5.1), which for an
    /// untagged folder is usually the only thing that finds one — **the
    /// name-based search has an album name and no artist and returns nothing, on
    /// purpose**.
    ///
    /// The precision the box's own wording misses: it *does* still ask. With no
    /// artist the script builds `release:"$b"` alone and sends it
    /// (`player:1825`). What returns nothing is the quoted phrase, matched
    /// strictly against a real title by a folder name that is not one
    /// (`player:1803`) — the result, not a refusal.
    @Test("With no artist the catalogue is still asked, and strictly enough to miss")
    func askedAnywayAndStrictlyEnoughToMiss() async throws {
        // The query is built and it is the one-term form.
        #expect(ReleaseSearch.lucene(artist: "", album: "Some Rip") == "release:\"Some Rip\"")
        // Only the album cannot be dropped.
        #expect(ReleaseSearch.lucene(artist: "Fleetwood Mac", album: "") == nil)

        let transport = StubSleeveTransport([], otherwise: .body(Data("{\"releases\":[]}".utf8)))
        let outcome = await ReleaseSearch.releaseIDs(
            albumArtist: "", album: "Some Rip", transport: transport, retryDelay: .zero)
        #expect(outcome.releaseIDs.isEmpty)
        // It reached the catalogue — which is what earns the `.none` marker
        // under D14, and is the difference from the wifi being off.
        #expect(outcome.heard)
        #expect(!transport.asked.isEmpty)
        #expect(transport.asked.allSatisfy { !$0.absoluteString.contains("artist:") })

        // And the picture beside the record is found regardless, which is the
        // half of §5 that an untagged folder actually depends on.
        let folder = try NamedFolder("Some Rip", files: ["Track A.aiff", "folder.jpg"])
        let found = BesideTheRecord.find(
            in: folder.url,
            probe: StubPictureProbe(everythingIs: PictureSize(width: 600, height: 600)))
        #expect(found?.lastPathComponent == "folder.jpg")
    }

    // MARK: - No ffmpeg

    /// **Native: ffmpeg is the fallback decoder only** (`CLAUDE.md`), so its
    /// absence means four formats will not play — a different and larger
    /// consequence than the script's, where it cost the analyser its columns
    /// (`player:367`, `player:374`, `player:253`, `player:928`).
    ///
    /// D40 is where the check was made to say the new thing. This is the other
    /// end of it: the sentence the check promises is the sentence the opener
    /// actually enforces.
    @Test("The four formats the check names are the four the opener refuses")
    func theCheckAndTheOpenerAgree() {
        #expect(AudioSourceOpener.fallbackExtensions == ["opus", "ogg", "ape", "wma"])
        #expect(AudioSourceOpener.fallbackFormats == "Opus, Ogg, APE and WMA")
        for extension_ in AudioSourceOpener.fallbackOrder {
            // Every one of them is a format the scan will pick up in the first
            // place, or naming it would be a promise about a file that is never
            // read.
            #expect(AudioFiles.extensions.contains(extension_))
        }
        // And it is `noDecoder`, not `unreadable`: §6.3 says different sentences
        // about the two, and this one is about the machine.
        #expect(PlaybackFailure.noDecoder(url: URL(fileURLWithPath: "/x/a.opus")).reason
            == "NO DECODER")
    }

    /// The analyser is a live tap and does not depend on ffmpeg at all, so the
    /// half of bash's warning that was about the columns has genuinely stopped
    /// being true — `SPEC_OK` and `spec_synth` have nothing to be the fallback
    /// *from* (`player:253`, `player:928`).
    @Test("Nothing left in the port falls back to a pattern")
    func thePatternHasNothingToFallBackFrom() {
        let report = Diagnostics.run(DiagnosticsTests.probes(tools: []))
        for check in report.checks {
            #expect(!check.detail.contains("pattern"))
            #expect(!check.detail.contains("travelling"))
        }
        // The one row that used to carry it is now unconditional.
        #expect(DiagnosticsTests.row(report, "analyser")?.mark == .ok)
    }
}
