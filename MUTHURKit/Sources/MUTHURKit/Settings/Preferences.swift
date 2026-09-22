import Foundation

/// §13's table, as a value somebody can actually change (**D105**).
///
/// Every field here was a variable you had to export before launching, which is
/// a setting in the sense that it is read and in no other sense at all: nobody
/// opens a terminal to decide whether the tube is allowed to wobble. The
/// settings screen is where they became switches, and this is what it edits.
///
/// **What is in here is what had nowhere else to live.** `ImportOptions` and
/// `BurnOptions` are already values with their own homes, their own jobs to be
/// handed to, and their own arguments about what persists; they stay where they
/// are and the screen edits all three. This holds the leftovers of §13 — the
/// tube, the network, and the scratch directory.
///
/// **Everything here persists, and that is the easy half of D105.** None of it
/// can spoil anything: the worst a remembered setting here can do is draw the
/// figures in seven segments when you wanted type, which you can see and undo.
/// The argument that is *not* easy is `BurnOptions`, and it is made there.
public struct Preferences: Sendable, Equatable, Codable {

    // MARK: - The tube

    /// `MUTHUR_CRT` — whether the two moving faults are allowed to run (D52).
    ///
    /// On, which is what the variable's absence has always meant. `Tube` still
    /// owns the reading of the variable itself, because `--help`'s suite looks
    /// for it there.
    public var faults: Bool

    /// `MUTHUR_LETTERING` — the chrome's character generator.
    public var lettering: Lettering

    /// `MUTHUR_NUMERALS` — the figures.
    public var numerals: Numerals

    /// `MUTHUR_COMPOSITION` — what is under the last track (D26).
    public var composition: Composition

    // MARK: - The network

    /// `MUTHUR_NO_MB`, the right way up.
    ///
    /// **This is the one field here that was already reachable without a
    /// variable** — `--no-mb` on the command line, which `MUTHURApp` reads into
    /// `PanelModel.useMusicBrainz` at launch. What it was not was *durable*:
    /// somebody on a metered connection, or with no connection, had to say so
    /// every single launch. Now the flag sets this launch and the setting sets
    /// every launch, which is the distinction the whole screen is built on.
    public var useMusicBrainz: Bool

    // MARK: - The scratch

    /// `MUTHUR_KEEP` — leave the scratch directory behind instead of destroying
    /// it. A debugging switch, off, and honestly labelled as one on the screen.
    public var keepScratch: Bool

    /// `MUTHUR_WORK` — where zips unpack. Nil is `~/.cache/muthur/work`, which
    /// is what it has always been.
    ///
    /// **A path and not a bookmark, unlike D5's catalogue, and the difference is
    /// the direction.** The catalogue is somebody else's file that we open and
    /// read, so it wants a handle that survives the file moving and survives
    /// being sandboxed. This is a directory *we make*, under a parent that was
    /// picked because it is big enough, and `Scratch.workBase` already has the
    /// answer for one that will not take us: it falls back to `$TMPDIR` rather
    /// than refusing to play a record. A bookmark here would be D5's machinery
    /// without D5's reason.
    ///
    /// **It takes effect at the next launch and the screen says so.** The
    /// session's scratch directory is made once, at start-up, and a zip already
    /// unpacked into the old one is not going to walk across.
    public var work: String?

    public init(
        faults: Bool = true,
        lettering: Lettering = .type,
        numerals: Numerals = .type,
        composition: Composition = .runout,
        useMusicBrainz: Bool = true,
        keepScratch: Bool = false,
        work: String? = nil
    ) {
        self.faults = faults
        self.lettering = lettering
        self.numerals = numerals
        self.composition = composition
        self.useMusicBrainz = useMusicBrainz
        self.keepScratch = keepScratch
        self.work = work
    }

    // MARK: - Where it is kept

    /// One key holding the whole value as JSON, for `ImportOptions.defaultsKey`'s
    /// reason: seven keys would be seven things to keep agreeing with each other,
    /// and a half-written set is the failure mode.
    static let defaultsKey = "preferences"

    /// Defaults, then what was saved, then the environment — and the
    /// environment is **not written back**.
    ///
    /// The rule is `ImportOptions.load`'s, word for word, because it is the
    /// right one and having two would be worse than having it twice: a variable
    /// was typed *this* launch and the saved value is from some other one, so
    /// the variable wins; and a variable exported in a shell profile that
    /// silently became the saved setting would be a preference nobody chose and
    /// could not find.
    ///
    /// Each variable is read through the same function the rest of the program
    /// reads it through, so a setting cannot come to disagree with the thing it
    /// is a setting for. `Tube.faultsAllowed` and `SourceOpener`'s
    /// `musicBrainzDisabled` are asked here rather than reimplemented.
    public static func load(
        from store: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Preferences {
        var settings = Preferences()
        if let data = store.data(forKey: defaultsKey),
            let saved = try? JSONDecoder().decode(Preferences.self, from: data)
        {
            settings = saved
        }

        // `MUTHUR_CRT` and `MUTHUR_NO_MB` both mean something only when they are
        // set, so an unset one has to leave the saved value alone rather than
        // overwrite it with the function's answer for "unset".
        if environment["MUTHUR_CRT"] != nil {
            settings.faults = Tube.faultsAllowed(environment: environment)
        }
        if let named = environment["MUTHUR_LETTERING"], let face = Lettering(rawValue: named) {
            settings.lettering = face
        }
        if let named = environment["MUTHUR_NUMERALS"], let figures = Numerals(rawValue: named) {
            settings.numerals = figures
        }
        if let named = environment["MUTHUR_COMPOSITION"],
            let composition = Composition(rawValue: named)
        {
            settings.composition = composition
        }
        if environment["MUTHUR_NO_MB"] != nil {
            settings.useMusicBrainz = !SourceOpener.musicBrainzDisabled(environment: environment)
        }
        if Scratch.keepRequested(environment: environment) {
            settings.keepScratch = true
        }
        if let directory = Self.nonEmpty(environment["MUTHUR_WORK"])
            ?? Self.nonEmpty(environment["PLAYER_WORK"])
        {
            settings.work = directory
        }
        return settings
    }

    /// Written through on every change, because a setting chosen now has to
    /// survive the app being closed a second later (**D85**, and D97 after it).
    public func save(to store: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        store.set(data, forKey: Self.defaultsKey)
    }

    /// What this value means to the parts of the kit that still read the
    /// environment — `Scratch.workBase` and `Scratch.keepRequested` take a
    /// dictionary, and this is how a *setting* reaches them without either of
    /// them learning about settings.
    ///
    /// Only the two storage variables, because they are the only two read from
    /// a dictionary after launch. It writes nothing itself; the caller passes
    /// it where a dictionary is wanted, or — as `main.swift` does at start-up —
    /// puts `storageOverrides` into the process environment with `setenv`
    /// before the app begins.
    ///
    /// **That is why `work` takes effect at the next launch and not this one,
    /// and it is the honest arrangement rather than a shortcut.** `Scratch.open`
    /// is reached from inside `SourceOpener`, four calls down a path that exists
    /// to open a record; threading a settings dictionary through it would put a
    /// preference in the signature of every function between here and there.
    /// Applied once at start-up the setting behaves exactly like the variable it
    /// replaces, which is also what a scratch directory can honestly promise —
    /// this session's was made at start-up, and a zip already unpacked into it
    /// is not going to walk across.
    public func storageEnvironment(
        merging environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var merged = environment
        // The variable still beats the setting, exactly as `load` decided — so
        // an existing one is left standing rather than overwritten.
        if let work, Self.nonEmpty(environment["MUTHUR_WORK"]) == nil,
            Self.nonEmpty(environment["PLAYER_WORK"]) == nil
        {
            merged["MUTHUR_WORK"] = work
        }
        if keepScratch, !Scratch.keepRequested(environment: environment) {
            merged["MUTHUR_KEEP"] = "1"
        }
        return merged
    }

    /// Just the pairs `storageEnvironment` would add — what has to be written
    /// into the process environment, and nothing that is already there.
    ///
    /// Separate from the merged dictionary because the two callers want
    /// different things: a function taking an environment wants the whole of
    /// one, and `setenv` wants only what is new. Handing the whole merge to
    /// `setenv` would work, since a variable already set is left alone either
    /// way, but it would be the program writing back every variable it
    /// inherited, which is not a thing to do quietly.
    public func storageOverrides(
        merging environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        storageEnvironment(merging: environment).filter { environment[$0.key] != $0.value }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }

    // MARK: - Decoding

    /// Every field defaulted on the way in, `ImportOptions`'s reason: a value
    /// saved by a version with one switch fewer still decodes, and so does one
    /// naming a case this build has never heard of — which falls back rather
    /// than refusing the whole set.
    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        self.faults = (try? box.decode(Bool.self, forKey: .faults)) ?? true
        self.lettering = (try? box.decode(Lettering.self, forKey: .lettering)) ?? .type
        self.numerals = (try? box.decode(Numerals.self, forKey: .numerals)) ?? .type
        self.composition = (try? box.decode(Composition.self, forKey: .composition)) ?? .runout
        self.useMusicBrainz = (try? box.decode(Bool.self, forKey: .useMusicBrainz)) ?? true
        self.keepScratch = (try? box.decode(Bool.self, forKey: .keepScratch)) ?? false
        self.work = try? box.decode(String.self, forKey: .work)
    }
}
