import Foundation

/// §21 — the Import menu, as a value (**D95**).
///
/// `BurnOptions` is the model and this departs from it in exactly one place, so
/// the departure is worth stating first.
///
/// **The format survives a relaunch and nothing else does (D97).**
/// `BurnOptions` is emphatic that a switch outliving the app would be *a flag
/// you set last month and cannot see*, and it is right about every flag it
/// holds: `rehearsal` remembered is an hour spent rehearsing a burn somebody
/// meant to keep. The format is not that kind of switch. It is not an
/// instruction about one run — it is a statement about how this person keeps
/// their music, and somebody who keeps a FLAC library keeps a FLAC library next
/// month too. A menu that forgot it would be asking the same question before
/// every disc and getting the same answer.
///
/// The test the two obey together: **a switch that could make one run behave
/// unlike the run you are watching does not persist; a switch that describes
/// your shelf does.** `sleeve`, `folder`, `trackStyle` and `ejectWhenDone` are shelf
/// facts by that test and are kept too. Nothing here can spoil a disc, which is
/// the other half of why this is safe and `rehearsal` is not — the worst a
/// remembered setting can do to an import is write a folder you did not want,
/// which is a drag to the trash.
public struct ImportOptions: Sendable, Equatable, Codable {

    /// What the tracks are written as. FLAC unless somebody said otherwise.
    public var format: ImportFormat

    /// Put the cover in the files, where the container takes one
    /// (`ImportFormat.takesCoverArt`). On, because a record that arrives in a
    /// music library with no artwork is a record somebody has to go and find
    /// artwork for, and this program has already found it.
    ///
    /// It is the sleeve §5 resolved and not a fresh fetch: embedded art first,
    /// then beside the record, then the Cover Art Archive, in that order and
    /// already decided. Where §5 came up with nothing, this quietly does
    /// nothing.
    public var sleeve: Bool

    /// What the record's folder under the chosen directory is called, or that
    /// there is not one (**D96**).
    ///
    /// Defaults to the album's name alone, because the directory you choose is
    /// usually already an artist's and repeating the artist inside it stutters.
    public var folder: ImportNames.FolderStyle

    /// `01 - Let It Rock` or `01 Let It Rock`. Defaults to the dash, which is
    /// what shelves actually look like.
    public var trackStyle: ImportNames.TrackStyle

    /// Whether a folder is made at all — the question the rest of the program
    /// asks, kept as one word now that the answer has three shapes.
    public var makesFolder: Bool { folder != .none }

    /// Open the drive when the last track is written.
    ///
    /// Off by default, and that is not timidity. `E EJECT` on the deck takes
    /// the record off *and* the disc out, and a disc that left the machine on
    /// its own while a record was still playing off it would be the program
    /// stopping the music to tidy up. When it is on, the eject waits for the
    /// deck the same way — see `ImportRun`.
    public var ejectWhenDone: Bool

    public init(
        format: ImportFormat = .flac,
        sleeve: Bool = true,
        folder: ImportNames.FolderStyle = .album,
        trackStyle: ImportNames.TrackStyle = .dash,
        ejectWhenDone: Bool = false
    ) {
        self.format = format
        self.sleeve = sleeve
        self.folder = folder
        self.trackStyle = trackStyle
        self.ejectWhenDone = ejectWhenDone
    }

    // MARK: - Where it is kept

    /// One key, holding the whole value as JSON.
    ///
    /// Four keys would be four things to keep agreeing with each other, and a
    /// half-written set is the failure mode. One key is atomic: either the
    /// settings that came back are a set somebody chose, or there are none and
    /// the defaults stand.
    static let defaultsKey = "import.options"

    /// `MUTHUR_IMPORT_FORMAT=alac`, for a launch that wants to say so without
    /// touching the menu — the same courtesy `BurnOptions.atLaunch` extends to
    /// `MUTHUR_DEMO` and the rest, and on the same terms: **a variable only
    /// sets where the menu starts, and the menu is still the last word.**
    ///
    /// It beats what was saved, because it was typed *this* launch and the
    /// saved value is from some other one. It is not written back — a variable
    /// exported in a shell profile that silently became the saved setting would
    /// be a preference nobody chose and could not find.
    public static func load(
        from store: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ImportOptions {
        var options = ImportOptions()
        if let data = store.data(forKey: defaultsKey),
            let saved = try? JSONDecoder().decode(ImportOptions.self, from: data)
        {
            options = saved
        }
        if let named = environment["MUTHUR_IMPORT_FORMAT"],
            let format = ImportFormat(rawValue: named.lowercased())
        {
            options.format = format
        }
        return options
    }

    /// Written through on every change, because a setting chosen now has to
    /// survive the app being closed a second later — `Corrections` makes the
    /// same argument about the same second (**D85**).
    public func save(to store: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        store.set(data, forKey: Self.defaultsKey)
    }

    // MARK: - Decoding

    /// Every field defaulted on the way in, so a value saved by a version that
    /// had one switch fewer still decodes — and so does one saved by a version
    /// that had a format this build has never heard of, which falls back to
    /// FLAC rather than refusing the whole set.
    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        self.format = (try? box.decode(ImportFormat.self, forKey: .format)) ?? .flac
        self.sleeve = (try? box.decode(Bool.self, forKey: .sleeve)) ?? true
        self.folder =
            (try? box.decode(ImportNames.FolderStyle.self, forKey: .folder)) ?? .album
        self.trackStyle =
            (try? box.decode(ImportNames.TrackStyle.self, forKey: .trackStyle)) ?? .dash
        self.ejectWhenDone = (try? box.decode(Bool.self, forKey: .ejectWhenDone)) ?? false
    }
}
