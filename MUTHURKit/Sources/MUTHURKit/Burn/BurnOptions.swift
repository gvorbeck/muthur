import Foundation

/// §20 — the switches `burncd` takes on its command line, held for a window that
/// has no command line to take them on (**D86**).
///
/// Every one of these was written, tested and had driven the drive, and none of
/// them could be reached from the panel: the same shape as the burn itself
/// before D83, one layer down. `BurnJob` had a field for each and the app built
/// every job with the defaults. So this is the whole of the flag parse at
/// `burncd:197`, less the two that are not about a burn — `--check` is §11 and
/// `-n` is `BurnJob.Stop` (D70) — and it is the one value the Burn menu edits
/// and the one value a job is made from.
///
/// **Five of them last as long as the app does and three of them outlive it
/// (D86, amended by D105).**
///
/// D86 said none of them persisted, and gave the reason: a flag is typed per
/// invocation, and a switch that survived a relaunch would be a flag you set
/// last month and cannot see. That reason is exactly right about `rehearsal`,
/// which is the case it was written for — a menu that remembered it would one
/// day spend an hour rehearsing a burn somebody meant to keep — and it is
/// exactly right about `demo` and `from`, which are the same shape: each
/// describes *this run*, and each, remembered, quietly produces a burn that is
/// not the one you asked for.
///
/// It was not right about the other five, and the settings screen is what made
/// that visible. `verify`, `cdText`, `splitLong`, `level` and `mediaCheck` are
/// not instructions about one run — they are how this person burns discs, on
/// this drive, and the answer is the same next month. **That is D97's test,
/// which `ImportOptions` has been keeping since the format was made to
/// persist: a switch that could make one run behave unlike the run you are
/// watching does not persist; a switch that describes your shelf does.** The
/// five are shelf facts by it and the three are not.
///
/// The three that do not persist are the three that can cost you a blank or an
/// hour, which is not a coincidence — it is the same test read from the other
/// end.
public struct BurnOptions: Sendable, Equatable {

    /// `--dummy` (`burncd:205`): a real drive, a real conversion, the laser off.
    public var rehearsal: Bool

    /// `--verify` (`burncd:206`): read the disc back afterwards and check it.
    /// Never asked of a rehearsal, which leaves nothing on the blank to read.
    public var verify: Bool

    /// `--no-cdtext` (`burncd:204`), the right way up. The script's own advice
    /// for a drive that chokes on the lead-in is to turn it off and burn again.
    public var cdText: Bool

    /// `--split-long` (`burncd:203`). A plan-time switch rather than a
    /// burn-time one: it changes what the plan *is*, which is why the plan
    /// editor is rebuilt when it moves.
    public var splitLong: Bool

    /// `--level` / `--level=track` (`burncd:208`).
    public var level: LevelMode

    /// `--from-disc n` (`burncd:210`). Only meaningful against a plan, so
    /// `PanelModel` puts it back to 1 whenever the plan screen comes off.
    public var from: Int

    /// `--no-media-check` (`burncd:207`), the right way up.
    public var mediaCheck: Bool

    /// `--demo` (`burncd:201`): the whole screen against `FakeDrive`, no drive
    /// and no blank.
    public var demo: Bool

    /// `BURNCD_LUFS` and `BURNCD_PEAK` (`burncd:85`, `burncd:88`). Variables in
    /// the script and variables here — there is no flag for them, so there is
    /// no switch — but they are carried, because until this they were read by
    /// nothing the app ever built.
    public var targets: LevelTargets

    /// `burncd` with no flags at all (`burncd:62–86`).
    public init(
        rehearsal: Bool = false,
        verify: Bool = false,
        cdText: Bool = true,
        splitLong: Bool = false,
        level: LevelMode = .off,
        from: Int = 1,
        mediaCheck: Bool = true,
        demo: Bool = false,
        targets: LevelTargets = LevelTargets()
    ) {
        self.rehearsal = rehearsal
        self.verify = verify
        self.cdText = cdText
        self.splitLong = splitLong
        self.level = level
        self.from = from
        self.mediaCheck = mediaCheck
        self.demo = demo
        self.targets = targets
    }

    /// What the menu starts at: the defaults, then the five that were saved,
    /// then every variable that already meant something still meaning it.
    /// `MUTHUR_DEMO` and `MUTHUR_DUMMY` are D83's, `MUTHUR_LEVEL` /
    /// `BURNCD_LEVEL` and the media-check pair are the script's own
    /// (`burncd:77`, `burncd:82`). A variable only sets where the menu
    /// *starts*; the menu is still the last word.
    ///
    /// **The environment goes last and is not written back**, which is
    /// `ImportOptions.load`'s rule and now applies to three values in the
    /// program rather than two: a variable was typed *this* launch and the
    /// saved value is from some other one.
    ///
    /// `store` is optional so the suite can ask what the environment alone
    /// says, which is what D86's own tests have always been asking.
    public static func atLaunch(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        store: UserDefaults? = .standard
    ) -> BurnOptions {
        func set(_ name: String) -> Bool { !(environment[name] ?? "").isEmpty }

        var options = BurnOptions()
        if let store, let data = store.data(forKey: defaultsKey),
            let saved = try? JSONDecoder().decode(Saved.self, from: data)
        {
            saved.apply(to: &options)
        }

        // Each variable only where it is actually set, so an unset one leaves
        // the saved value standing instead of overwriting it with the default.
        if set("MUTHUR_DUMMY") { options.rehearsal = true }
        if set("MUTHUR_DEMO") { options.demo = true }
        if environment["MUTHUR_LEVEL"] != nil || environment["BURNCD_LEVEL"] != nil {
            options.level = LevelMode.from(environment: environment)
        }
        if environment["MUTHUR_NO_MEDIA_CHECK"] != nil
            || environment["BURNCD_NO_MEDIA_CHECK"] != nil
        {
            options.mediaCheck = MediaCheck.enabled(environment)
        }
        options.targets = LevelTargets.from(environment: environment)
        return options
    }

    // MARK: - The five that are kept

    /// One key holding the saved half as JSON, for `ImportOptions.defaultsKey`'s
    /// reason: five keys would be five things to keep agreeing with each other.
    static let defaultsKey = "burn.options"

    /// **The split, written as a type rather than as a list in a `save`
    /// function.** A field added to `BurnOptions` does not silently join the
    /// saved set by being forgotten about — it has to be named here, which is
    /// the moment to ask D105's question about it. `rehearsal`, `demo`, `from`
    /// and `targets` are deliberately absent: the first three are one run's,
    /// and `targets` has no switch because it has no flag (`burncd:85`).
    private struct Saved: Codable {
        var verify: Bool
        var cdText: Bool
        var splitLong: Bool
        var level: LevelMode
        var mediaCheck: Bool

        init(_ options: BurnOptions) {
            self.verify = options.verify
            self.cdText = options.cdText
            self.splitLong = options.splitLong
            self.level = options.level
            self.mediaCheck = options.mediaCheck
        }

        func apply(to options: inout BurnOptions) {
            options.verify = verify
            options.cdText = cdText
            options.splitLong = splitLong
            options.level = level
            options.mediaCheck = mediaCheck
        }

        /// Defaulted on the way in, `ImportOptions`'s reason: a set saved by a
        /// version with one switch fewer still decodes.
        init(from decoder: any Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            let fresh = BurnOptions()
            self.verify = (try? box.decode(Bool.self, forKey: .verify)) ?? fresh.verify
            self.cdText = (try? box.decode(Bool.self, forKey: .cdText)) ?? fresh.cdText
            self.splitLong = (try? box.decode(Bool.self, forKey: .splitLong)) ?? fresh.splitLong
            self.level = (try? box.decode(LevelMode.self, forKey: .level)) ?? fresh.level
            self.mediaCheck = (try? box.decode(Bool.self, forKey: .mediaCheck)) ?? fresh.mediaCheck
        }
    }

    /// Written through on every change, D85's second: a setting chosen now has
    /// to survive the app being closed a second later. Only the five — the rest
    /// of this value is this session's and goes with it.
    public func save(to store: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(Saved(self)) else { return }
        store.set(data, forKey: Self.defaultsKey)
    }

    /// The job these options describe, for a plan the editor has settled.
    ///
    /// `keepImages` and `capacity` are left to `BurnJob`'s own defaults, which
    /// read their variables there: neither has a flag in `burncd`, so neither
    /// has a switch here.
    public func job(draft: PlanDraft, files: [URL], work: URL) -> BurnJob {
        BurnJob(
            draft: draft,
            files: files,
            work: work,
            stop: .throughTheBurn,
            splitLong: splitLong,
            cdText: cdText,
            level: level,
            targets: targets,
            rehearsal: rehearsal,
            from: from
        )
    }

    /// The insert prompt's look at the blank, or nil where there is no blank to
    /// look at. Nil is `--demo`, exactly as `BurnJob.Insert` documents it.
    public func insert(wait: @escaping (Int) -> Bool) -> BurnJob.Insert? {
        guard !demo else { return nil }
        return BurnJob.Insert(check: MediaCheck(enabled: mediaCheck), wait: wait)
    }

    /// The read-back, or nil where there is nothing to read. A demo has no disc
    /// and a rehearsal has a blank one (`burncd:2655`, `burncd:2665`).
    public func verifier() -> DiscVerify? {
        guard verify, !demo, !rehearsal else { return nil }
        return DiscVerify()
    }
}
