import Foundation

/// Where the titles came from. §4.
///
/// Four sources, tried in order of trust, and **the panel always says which one
/// you got**. A track list is only as good as its source, which is why this ends
/// up on screen rather than in a log.
public enum TitleSource: String, Sendable, Equatable, CaseIterable {
    /// Embedded metadata. The normal case, and the only source a folder or a zip
    /// ever has.
    case tags = "tags"
    case cdText = "CD-Text"
    case musicBrainz = "MusicBrainz"
    /// Nothing could say.
    case trackNumbers = "track numbers"
}

/// The raw output of whatever CD-Text tool this machine has. A seam, because
/// running `cdda2wav` needs a drive and parsing what it printed does not.
public protocol CDTextSource: Sendable {
    func cdTextOutput() async -> String?
}

/// The disc's table of contents, off the drive. §1.3 is where the real one
/// lives; this is the shape it has to arrive in.
public protocol TableOfContentsSource: Sendable {
    func tableOfContents() async -> TableOfContents?
}

/// A mounted CD has no tags at all — macOS presents it as `1 Audio Track.aiff`
/// and eleven more like it — so everything the panel shows has to come from
/// somewhere else. Tried in order of trust, and whichever answers is recorded
/// (`player:2235`).
public enum DiscTitles {

    /// How far through `READING DISC` the chain is. Three steps, always three,
    /// even when the middle one is switched off — the meter is about the shape
    /// of the search and not about how much of it ran.
    public struct Stage: Sendable, Equatable {
        public static let heading = "READING DISC"
        public let step: Int
        public let of: Int
        public let detail: String
    }

    public struct Outcome: Sendable, Equatable {
        public var source: TitleSource
        /// The fingerprint this disc was looked up by, when there was one.
        public var discID: String?
        /// The release the catalogue resolved it to — kept for the sleeve even
        /// when the lookup then failed to name a single track, because a release
        /// MBID is still the strongest identification §5 will ever be handed.
        public var releaseID: String?
    }

    // MARK: - §4.1, the tidy default

    /// Before anything is asked. A failure further down then leaves a column of
    /// `Track 01`, `Track 02` rather than a column of filenames
    /// (`player:2240`).
    public static func applyDefaults(to record: inout Record, volumeName: String) {
        for index in record.tracks.indices {
            let title = record.tracks[index].title
            // The two casings the script lists, and only those. macOS writes
            // `1 Audio Track.aiff`; matching case-insensitively would be a wider
            // net than the script casts, and this is not the place to widen one.
            guard title.contains("Audio Track") || title.contains("audio track") else { continue }
            record.tracks[index].title = String(
                format: "Track %02d", record.tracks[index].number
            )
        }
        // `basename "$SRC_PATH"` — the volume name, which for a CDDA mount is
        // whatever the disc called itself or `Audio CD` if it did not.
        if record.album.isEmpty { record.album = volumeName }
    }

    // MARK: - The chain

    public static func resolve(
        _ record: inout Record,
        volumeName: String,
        cdText: (any CDTextSource)? = nil,
        tableOfContents: (any TableOfContentsSource)? = nil,
        transport: (any SleeveTransport)? = nil,
        useMusicBrainz: Bool = true,
        stage: ((Stage) -> Void)? = nil
    ) async -> Outcome {
        applyDefaults(to: &record, volumeName: volumeName)
        var outcome = Outcome(source: .trackNumbers)

        stage?(Stage(step: 1, of: 3, detail: "looking for CD-Text"))
        if await readCDText(into: &record, from: cdText) {
            outcome.source = .cdText
            return outcome
        }

        stage?(Stage(step: 2, of: 3, detail: "asking MusicBrainz"))
        if await ask(&record, outcome: &outcome, tableOfContents, transport, useMusicBrainz) {
            outcome.source = .musicBrainz
            return outcome
        }

        stage?(Stage(step: 3, of: 3, detail: "no titles on this disc"))
        return outcome
    }

    // MARK: - §4.2

    /// True when at least one title landed on a row.
    ///
    /// Not "at least one title was found" — an album title on its own is not a
    /// track list, and returning success for one would both stamp `CD-Text` on
    /// the faceplate over a column of bare track numbers *and* rob the disc of
    /// the MusicBrainz lookup that could have named them (`player:2106`).
    ///
    /// Whatever album and artist were found stay put either way. §18.11, kept
    /// as-is (D19):
    /// the source label is about the *track list*, which is what you are looking
    /// at. MusicBrainz overwrites what it knows better and leaves the rest
    /// alone.
    static func readCDText(into record: inout Record, from source: (any CDTextSource)?) async
        -> Bool
    {
        guard let source, let output = await source.cdTextOutput(), !output.isEmpty else {
            return false
        }
        let text = CDTextParser.parse(output)
        if !text.album.isEmpty { record.album = text.album }
        if !text.albumArtist.isEmpty { record.albumArtist = text.albumArtist }

        var landed = 0
        for number in text.titles.keys.sorted() {
            // Track numbers, not rows. The disc counts from one and the arrays
            // are in scan order.
            guard let index = record.fileIndex(ofTrackNumber: number),
                let title = text.titles[number]
            else { continue }
            record.tracks[index].title = title
            if let artist = text.artists[number] { record.tracks[index].artist = artist }
            landed += 1
        }
        return landed > 0
    }

    // MARK: - §4.3

    /// True when the catalogue offered a track list.
    ///
    /// **Offered, not landed** — and that is the script, not a slip here. Its
    /// counter moves before the row lookup (`player:2223`), so a disc whose
    /// titles all come back for track numbers this record does not have is still
    /// stamped `MusicBrainz`. CD-Text a few lines above counts the other way.
    /// The asymmetry is real and it is `player`'s; ported as found.
    static func ask(
        _ record: inout Record,
        outcome: inout Outcome,
        _ source: (any TableOfContentsSource)?,
        _ transport: (any SleeveTransport)?,
        _ useMusicBrainz: Bool
    ) async -> Bool {
        // `--no-mb` / `PLAYER_MB=0`, no curl, no jq: all three land in the same
        // place as a failed lookup (`player:2176`).
        guard useMusicBrainz, let source, let transport else { return false }
        guard let table = await source.tableOfContents() else { return false }

        let discID = table.discID
        outcome.discID = discID
        guard let answer = await MusicBrainzDisc.look(up: discID, transport: transport) else {
            return false
        }

        // Applied before the titles are counted, and therefore applied even when
        // the answer then turns out to name nothing — same shape as §18.11
        // above. Only when present, so a half answer does not blank the other
        // half (`player:2213`).
        if !answer.album.isEmpty { record.album = answer.album }
        if !answer.albumArtist.isEmpty { record.albumArtist = answer.albumArtist }
        if !answer.year.isEmpty { record.year = answer.year }
        if !answer.releaseID.isEmpty { outcome.releaseID = answer.releaseID }

        // The list comes back in track order, so the nth title belongs to track
        // n — which is not row n, hence the lookup.
        for (offset, title) in answer.titles.enumerated() {
            guard let index = record.fileIndex(ofTrackNumber: offset + 1) else { continue }
            record.tracks[index].title = title
            if !record.albumArtist.isEmpty { record.tracks[index].artist = record.albumArtist }
        }
        return !answer.titles.isEmpty
    }
}
