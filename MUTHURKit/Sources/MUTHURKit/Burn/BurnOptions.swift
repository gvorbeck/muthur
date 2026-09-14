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
/// **It lasts as long as the app does, and is not saved.** A flag is typed per
/// invocation, and forgetting one is forgetting to type it; a switch that
/// survived a relaunch would be a flag you set last month and cannot see.
/// `rehearsal` is the one that makes this matter — a menu that remembered it
/// would one day spend an hour rehearsing a burn somebody meant to keep.
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

    /// What the menu starts at: the defaults, with every variable that already
    /// meant something still meaning it. `MUTHUR_DEMO` and `MUTHUR_DUMMY` are
    /// D83's, `MUTHUR_LEVEL` / `BURNCD_LEVEL` and the media-check pair are the
    /// script's own (`burncd:77`, `burncd:82`). A variable only sets where the
    /// menu *starts*; the menu is still the last word.
    public static func atLaunch(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> BurnOptions {
        func set(_ name: String) -> Bool { !(environment[name] ?? "").isEmpty }
        return BurnOptions(
            rehearsal: set("MUTHUR_DUMMY"),
            level: LevelMode.from(environment: environment),
            mediaCheck: MediaCheck.enabled(environment),
            demo: set("MUTHUR_DEMO"),
            targets: LevelTargets.from(environment: environment)
        )
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
