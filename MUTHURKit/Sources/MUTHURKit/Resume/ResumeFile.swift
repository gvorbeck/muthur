import CryptoKit
import Foundation

/// §7 — where you had got to, so that coming back to a record is not starting it
/// again (`player:1529`).
///
/// Offered rather than applied. Everything in here answers one of two
/// questions — *what record is this* and *where was I in it* — and neither of
/// them is allowed to reach the needle on its own. Putting the needle back is a
/// key press.
///
/// The file is a flat tab-separated table with an album to a line and no
/// database under it. It is rewritten whole on every write, which sounds
/// extravagant until you count the lines: two hundred, once every five seconds.
public struct ResumeFile: Sendable {

    /// The file itself, not the directory it sits in.
    public let url: URL

    public init(url: URL) { self.url = url }

    /// `${XDG_STATE_HOME:-$HOME/.local/state}/player/resume` (`player:1538`).
    ///
    /// `player` and not `muthur`, deliberately, and this is the one place in
    /// the port that shares a file with the script rather than keeping its own
    /// (compare §5.2's `~/.cache/muthur/art` and D13's scratch root). The
    /// format is identical in both directions, so a record left half-played in
    /// the terminal is offered back by the app and the other way round — which
    /// is either exactly right or exactly wrong, and is §18.19 until it is
    /// said which.
    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) -> ResumeFile {
        let state =
            environment["XDG_STATE_HOME"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
            ?? home.appending(path: ".local/state")
        return ResumeFile(url: state.appending(path: "player/resume"))
    }

    // MARK: - What this record is

    /// The key is what the record *is*, not where it lives (`player:1543`).
    ///
    /// A disc says what it is outright. Nothing else does, so everything else
    /// is asked what it *contains* instead: a folder that has been moved, and a
    /// zip unpacked into a different scratch directory every single run, are
    /// both still the same album, and a key made out of the path would lose
    /// them both.
    public static func key(discID: String) -> String { "d:\(discID)" }

    /// Album artist, album, how many tracks, how long — the four facts that
    /// survive being moved. SHA-1 of `a|b|c|d`, first sixteen hex characters,
    /// which is `shasum | cut -c1-16` (`player:1553`). SHA-1 because the script
    /// said SHA-1; nothing here is defending against anybody, it is telling two
    /// records apart.
    public static func key(albumArtist: String, album: String, trackCount: Int, total: Int)
        -> String
    {
        let subject = "\(albumArtist)|\(album)|\(trackCount)|\(total)"
        let digest = Insecure.SHA1.hash(data: Data(subject.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "a:\(hex.prefix(16))"
    }

    /// The running order's length and the sum of its durations, which is what
    /// `${#ORDER[@]}` and `$TOTAL` are.
    ///
    /// An empty disc ID is no disc ID — the script tests `-n "${DISCID:-}"`.
    public static func key(for record: Record, discID: String? = nil) -> String {
        if let discID, !discID.isEmpty { return key(discID: discID) }
        return key(
            albumArtist: record.albumArtist, album: record.album,
            trackCount: record.order.count, total: record.total
        )
    }

    // MARK: - A line of it

    public struct Entry: Sendable, Equatable {
        public let key: String
        /// Row in the running order, not a track number.
        public let row: Int
        /// Whole seconds into that track.
        public let position: Int
        /// The folder or zip as it was named on screen. Written, never read —
        /// it is there so the file can be looked at by a human.
        public let sourceLabel: String

        public init(key: String, row: Int, position: Int, sourceLabel: String) {
            self.key = key
            self.row = row
            self.position = position
            self.sourceLabel = sourceLabel
        }

        var line: String { "\(key)\t\(row)\t\(position)\t\(sourceLabel)" }

        /// Field four absorbs the rest of the line, tabs and all, because
        /// `read -r k row pos rest` does.
        static func parse(_ line: String) -> Entry? {
            let fields = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
            guard fields.count >= 3 else { return nil }
            return Entry(
                key: String(fields[0]), row: Int(fields[1]) ?? -1,
                position: Int(fields[2]) ?? -1,
                sourceLabel: fields.count > 3 ? String(fields[3]) : ""
            )
        }
    }

    /// What the panel is allowed to say, once there is something worth saying.
    public struct Offer: Sendable, Equatable {
        public let row: Int
        public let position: Int

        public init(row: Int, position: Int) {
            self.row = row
            self.position = position
        }

        /// `▪ RESUME AT <track no> · <m:ss> — PRESS U` (`player:2828`).
        ///
        /// The **track number**, not the row: the offer names the track the way
        /// the sleeve does, and a shuffled record's row seven would name
        /// nothing. An unnumbered row therefore offers `9999`, which is what
        /// the script does and is §18.20.
        public func text(trackNumber: Int) -> String {
            "▪ RESUME AT \(trackNumber) · \(Offer.mmss(position)) — PRESS U"
        }

        /// `panel.sh:148`. Minutes are not padded; seconds always are.
        static func mmss(_ seconds: Int) -> String {
            String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
    }

    // MARK: - Reading

    /// Every line of it, in file order, skipping what will not parse at all.
    public func entries() -> [Entry] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { Entry.parse(String($0)) }
    }

    /// The offer for this record, or none (`player:1557`).
    ///
    /// `rows` is the length of the running order, because a record that has
    /// lost a track since it was last played must not be sent to a row that no
    /// longer exists.
    ///
    /// The **first** line with this key decides, and if that line is malformed
    /// the answer is no offer rather than a search for a better one. A resume
    /// file with two entries for one album has already gone wrong somewhere,
    /// and picking the one that happens to parse would bury it.
    public func offer(key: String, rows: Int) -> Offer? {
        guard !key.isEmpty else { return nil }
        for entry in entries() where entry.key == key {
            guard entry.row >= 0, entry.position >= 0 else { return nil }
            guard entry.row < rows else { return nil }
            // Not worth offering to put you back at the top of track one, which
            // is where the record starts anyway, and not worth offering half a
            // minute in either — by the time reading the offer is over you
            // could have been there. Anything further in was a real listening
            // session (`player:1568`).
            guard entry.row > 0 || entry.position >= 30 else { return nil }
            return Offer(row: entry.row, position: entry.position)
        }
        return nil
    }

    // MARK: - Writing

    /// Every album but this one, then this one: an upsert with no database
    /// under it (`player:1579`).
    ///
    /// Capped at two hundred *other* albums, oldest off the top, because this
    /// one goes on the bottom every time it is written and the file is
    /// therefore already in least-recently-played order.
    @discardableResult
    public func save(key: String, row: Int, position: Int, sourceLabel: String) -> Bool {
        guard !key.isEmpty else { return false }
        let others = entries().filter { $0.key != key }.suffix(200)
        let entry = Entry(key: key, row: row, position: position, sourceLabel: sourceLabel)
        return write(others + [entry])
    }

    /// A record played to the end has nowhere to be resumed from, and leaving
    /// the last position on it would offer to put you back thirty seconds from
    /// the run-out groove the next time you reached for it (`player:1596`).
    ///
    /// No cap here. Dropping somebody else's album on the way past is a thing
    /// this is entitled to do when it is adding one of its own, and not
    /// otherwise.
    @discardableResult
    public func clear(key: String) -> Bool {
        guard !key.isEmpty else { return false }
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        return write(entries().filter { $0.key != key })
    }

    /// Built beside the file and moved onto it, so that a player killed halfway
    /// through a write leaves the old file whole rather than half of a new one.
    /// `.atomic` is the same temp-and-rename the script does by hand.
    ///
    /// Failure is silent and reported only as `false`. Nothing about a record
    /// playing depends on this working, and a read-only home directory is not
    /// a reason to interrupt one.
    private func write(_ entries: [Entry]) -> Bool {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let body = entries.isEmpty ? "" : entries.map(\.line).joined(separator: "\n") + "\n"
        do {
            try Data(body.utf8).write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Deliberately absent

    // No expiry, no pruning by age, no "played N times". The file answers one
    // question and the cap is the whole of its housekeeping.
}
