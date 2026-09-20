import Foundation

/// §21 — turning what a record calls itself into something a filesystem will
/// take.
///
/// This is the one place in the port where a title stops being text on a panel
/// and becomes a name on a volume, and the two have almost nothing in common.
/// `Columns.fit` cuts a title to fit a column and the worst it can do is look
/// wrong; a name that is illegal, or that collides, either fails the write or
/// destroys the file that was already there.
///
/// **The rules are only the ones the platform actually imposes**, per
/// `CLAUDE.md`: a rule the kernel does not honour is worse than no rule. APFS
/// and HFS+ take every byte except `/` and NUL, in names up to 255 UTF-8 bytes.
/// Everything below is either one of those two, or a documented reason for
/// going further than the kernel does.
public enum ImportNames {

    /// The kernel's limit, in bytes and not in characters (`NAME_MAX`).
    ///
    /// Budgeted a little under it, because the extension and a `(2)` may still
    /// be waiting to go on the end and both are added after this has run.
    public static let byteBudget = 200

    /// Make one path component out of a title.
    ///
    /// The substitutions, and why each is there:
    ///
    /// - **`/` → `-`.** The only character the kernel refuses outright. Finder
    ///   draws a `:` as a `/`, which is the trick `CLAUDE.md` notes for
    ///   `MUTHUR.app` — but a `:` written into a file that is later read by
    ///   anything other than Finder is a `:`, so a dash is the honest answer.
    /// - **`:` → `-`.** Legal at the POSIX layer and shown by Finder as `/`,
    ///   which makes `Tago Mago: Disc One` appear on the desktop as a name with
    ///   a slash in it. That is the confusion the kernel's one rule exists to
    ///   prevent, arriving by the back door.
    /// - **…but `: ` → ` - `, and that is not the same rule.** A colon that
    ///   separates two phrases is punctuation with a space after it, and
    ///   replacing only the colon leaves `American IV- The Man Comes Around`,
    ///   with the dash welded to the first half and adrift from the second. The
    ///   spaced form is what every hand-made library on this machine already
    ///   uses — *Gold: Greatest Hits* is filed as `Gold - Greatest Hits` —
    ///   which is where the rule came from: **the first real disc this program
    ///   imported disagreed with the rule written for it from first principles,
    ///   and the shelf it was importing into had been right for years.** `/`
    ///   between spaces takes the same treatment for the same reason; a bare
    ///   one, as in `AC/DC`, stays a bare dash.
    /// - **Control characters → a space.** `Track.flatten` already took the
    ///   tabs and newlines out of anything that came off a tag, but a title
    ///   that came off CD-Text has been through a different parser, and a name
    ///   with a `\r` in it is a name you cannot type at a shell.
    ///
    /// **Nothing else is touched**, and the list of things deliberately kept is
    /// longer than the list of things removed: `?`, `*`, `|`, `<`, `>`, `"` and
    /// `\` are all legal here and all illegal on Windows, and stripping them
    /// would be this program guessing that the disk is going somewhere it has
    /// not been told about. `Where Is My Mind?` keeps its question mark.
    ///
    /// A leading `.` is dropped because it hides the file, which no one ever
    /// means by a title, and trailing dots and spaces are dropped because
    /// Finder and the shell both treat them as typing accidents.
    public static func component(_ text: String) -> String {
        // The spaced forms first, or the bare rule below would have eaten the
        // separator before anything could tell the two apart.
        var text = text
        for mark in [":", "/"] {
            text = text.replacingOccurrences(of: " \(mark) ", with: " - ")
            text = text.replacingOccurrences(of: "\(mark) ", with: " - ")
        }

        var out = ""
        out.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "/", ":":
                out.unicodeScalars.append("-")
            default:
                // `properties.generalCategory` rather than a range test: this
                // has to catch the C1 controls and the format characters a
                // paste can carry, not only the ASCII ones.
                let category = scalar.properties.generalCategory
                if category == .control || category == .format {
                    out.unicodeScalars.append(" ")
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        // Runs of space collapse, because the substitutions above make them:
        // `A / B` becomes `A - B` and not `A  -  B`, and a control character
        // between two words leaves one gap rather than two.
        out = out.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        while let last = out.last, last == "." || last == " " { out.removeLast() }
        while let first = out.first, first == "." || first == " " { out.removeFirst() }
        return clamp(out)
    }

    /// Cut to `byteBudget` **on a character boundary**, never in the middle of
    /// one.
    ///
    /// A UTF-8 name truncated mid-scalar is not a shorter name, it is an
    /// invalid one, and the write fails with an error that says nothing about
    /// the title it came from. Dropping whole characters until it fits is the
    /// slow way and the right one; names this long are rare enough that the
    /// loop never runs twice in practice.
    static func clamp(_ text: String, to budget: Int = byteBudget) -> String {
        var out = text
        while out.utf8.count > budget, !out.isEmpty {
            out.removeLast()
        }
        // The trim is done again because the cut may have landed just after a
        // space, and a name ending in one is the thing `component` just spent
        // two lines removing.
        while let last = out.last, last == "." || last == " " { out.removeLast() }
        return out
    }

    /// `01 Let It Rock` — the number, a space, the title.
    ///
    /// **Two places and not as many as the disc has**, which is the same call
    /// `Readout` makes on the panel and is made here for a different reason: a
    /// name is sorted by a machine as text, and `10` sorts before `2` unless
    /// the 2 was written `02`. A disc with more than 99 tracks does not exist;
    /// one is not defended against, but a wider number would not break either,
    /// because `%02d` widens rather than truncating.
    ///
    /// `fallback` is what an untitled track is called. A CD with no CD-Text and
    /// no MusicBrainz answer has thirteen rows that all say `1 Audio Track` —
    /// §4.1's track numbers — and those are titles, so they come through here
    /// like any other. What `fallback` catches is a title that sanitised down
    /// to nothing at all: a row whose whole name was punctuation the rules
    /// above removed. Without it that track would be written as `07 .flac`.
    public static func trackFile(
        number: Int, title: String, format: ImportFormat,
        style: TrackStyle = .dash
    ) -> String {
        let clean = component(title)
        let number2 = String(format: "%02d", number)
        let stem =
            clean.isEmpty
            ? "\(number2)\(style.separator)Track \(number2)"
            : "\(number2)\(style.separator)\(clean)"
        return "\(clamp(stem)).\(format.fileExtension)"
    }

    /// What goes between the number and the title.
    ///
    /// **Two options where there should be one**, and the honest reason is that
    /// the port picked the wrong one and found out from a real shelf. `01 Let It
    /// Rock` was written here from first principles; the library this program
    /// was first asked to import into had been `01 - Let It Rock` for years, and
    /// fifty albums agreeing with each other beat one reasoned guess.
    ///
    /// It is a switch rather than a silent change because the argument for the
    /// bare form is not *wrong* — a dash is a separator between two things that
    /// are already visibly separate — it is just not what anybody's shelf looks
    /// like.
    public enum TrackStyle: String, Sendable, Equatable, CaseIterable, Codable {
        /// `01 - Let It Rock`.
        case dash
        /// `01 Let It Rock`.
        case plain

        var separator: String {
            switch self {
            case .dash: " - "
            case .plain: " "
            }
        }

        public var label: String {
            switch self {
            case .dash: "01 - Title"
            case .plain: "01 Title"
            }
        }
    }

    /// What the record's own folder is called, where there is one (**D96**).
    public enum FolderStyle: String, Sendable, Equatable, CaseIterable, Codable {
        /// `American IV - The Man Comes Around`. **The default**, because the
        /// destination is usually already an artist's folder and repeating the
        /// artist inside it stutters: `Johnny Cash/Johnny Cash - American IV…`.
        case album
        /// `Johnny Cash - American IV - The Man Comes Around`, which is what a
        /// flat destination wants — everything in one directory, sorted by
        /// whoever made it.
        case artistAndAlbum
        /// No folder at all: the tracks land in the directory that was chosen.
        /// The only setting under which an import can land beside files that
        /// were already there.
        case none

        public var label: String {
            switch self {
            case .album: "Album"
            case .artistAndAlbum: "Artist — Album"
            case .none: "No Folder — Straight In"
            }
        }
    }

    /// `Bon Jovi - Slippery When Wet`, the folder one record lands in (**D96**).
    ///
    /// The artist leads because that is how a shelf is ordered, and the two are
    /// joined by a spaced dash rather than a slash for the reason `component`
    /// gives about slashes. Either half may be missing — an untagged disc that
    /// MusicBrainz could not place has neither — and the joint goes with it,
    /// so the result is never `` - Album`` or `Artist - `.
    ///
    /// When both are missing it is `Untitled Record`, which is a name and not
    /// an error. The disc is still perfectly rippable; nobody knows what it is,
    /// and the folder saying so is more use than a refusal.
    public static func recordFolder(
        album: String, albumArtist: String, style: FolderStyle = .album
    ) -> String {
        let record = component(album)
        let artist = component(albumArtist)
        // `.album` still falls back to the artist when the record has no name
        // of its own, because a folder called `Untitled Record` beside fifty
        // named ones says less than the artist does.
        guard style == .artistAndAlbum else {
            let alone = record.isEmpty ? artist : record
            return clamp(alone.isEmpty ? "Untitled Record" : alone)
        }
        let joined =
            switch (artist.isEmpty, record.isEmpty) {
            case (false, false): "\(artist) - \(record)"
            case (true, false): record
            case (false, true): artist
            case (true, true): "Untitled Record"
            }
        return clamp(joined)
    }

    /// A name nothing is standing on yet.
    ///
    /// **An import never writes over what is already there**, and this is the
    /// whole of how. A second import of the same disc into the same directory
    /// gets `Bon Jovi - Slippery When Wet (2)`, not a folder half of one rip
    /// and half of another — which is what merging into the existing one would
    /// produce the moment a title changed between the two, since the tracks
    /// that still matched would be overwritten and the tracks that did not
    /// would be left beside them.
    ///
    /// No dialog asks about it, because there is no question: the old rip is
    /// kept and the new one is beside it, and a folder the user did not want is
    /// a folder they can drag to the trash in a second. Losing the first one is
    /// not recoverable in a second.
    ///
    /// Counts from 2 and is bounded, because an unbounded loop against a
    /// filesystem that is answering "yes it exists" to everything — a full
    /// volume, a permissions fault — is a hang rather than an error.
    public static func vacant(
        _ name: String,
        in directory: URL,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        limit: Int = 999
    ) -> URL? {
        let first = directory.appending(path: name)
        guard exists(first) else { return first }
        // Split around the extension so `01 Song (2).flac` is what comes back
        // and not `01 Song.flac (2)`. A folder has no extension and the split
        // leaves it whole.
        let base = first.deletingPathExtension().lastPathComponent
        let ext = first.pathExtension
        for n in 2...max(2, limit) {
            let stem = clamp("\(base) (\(n))")
            let candidate = directory.appending(
                path: ext.isEmpty ? stem : "\(stem).\(ext)")
            if !exists(candidate) { return candidate }
        }
        return nil
    }
}
