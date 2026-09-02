import AVFoundation
import AppKit
import MUTHURKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// §10's half of the event loop: what the panel is showing and what a key press
/// does to it.
///
/// The script keeps all of this in the locals of one `while read_key` loop
/// (`player:2547`). Here the deck is an actor and the panel is the main actor,
/// so the state has to be mirrored across rather than shared — which is the one
/// structural difference and it earns its keep: nothing on screen can be read
/// half-updated.
@MainActor
@Observable
final class PanelModel {

    // MARK: - The record

    private(set) var record: Record?
    private(set) var columns = TrackColumns(title: PanelGrid.textWidth, artist: 0)
    private(set) var header: HeaderBlock?
    private(set) var titleSource: TitleSource?
    private(set) var sourceKind: SourceKind = .folder

    /// What the panel has to say when there is no record yet and nothing is
    /// being loaded either — a refusal, or an empty scan. **A port invention
    /// both times**: the script says one line and exits.
    private(set) var stage: String?

    /// §10's loading stage, while a source is coming open (`player:1152`). Nil
    /// the rest of the time, and nil again the moment there is a record — the
    /// screen exists for the wait and for nothing else.
    private(set) var loading: LoadingStage?

    var isLoading: Bool { loading != nil && record == nil }

    /// The scratch directory a zip was unpacked into.
    private(set) var scratch: Scratch?

    // MARK: - The picker (§1.2)

    private(set) var pickerEntries: [PickerEntry]?
    var pickerCursor = 0

    var isPicking: Bool { pickerEntries != nil && record == nil }

    // MARK: - The health check (§11)

    /// The check that is on screen. `--check` in bash prints and the program
    /// ends (`player:345`, `player:531`); a window cannot end, so here it is a
    /// screen that goes over whatever was showing and comes off again. The
    /// record underneath is untouched — the check reports on the machine, not
    /// on what is playing, and stopping the music to ask about the machine
    /// would be its own small failure.
    private(set) var report: Diagnostics.Report?

    var isChecking: Bool { report != nil }

    /// Off the main actor: it launches `drutil`, walks `PLAYER_DIRS` and stats
    /// the scratch directory, and a drive that has to spin up takes seconds
    /// (`player:395`). None of that belongs on the thread doing the drawing.
    func check() {
        Task {
            report = await Task.detached { Diagnostics.run() }.value
        }
    }

    func closeCheck() { report = nil }

    // MARK: - The deck

    let engine = PlaybackEngine()
    let analyser = Analyser()

    private(set) var state = PlaybackEngine.State.empty

    /// §14 — the deck as the rest of the system sees it. Fed from `refresh`,
    /// which is the one place that already knows a track changed.
    private let nowPlaying = NowPlaying()

    // Nothing here touches the Dock tile, and that is the decision rather than
    // an omission — §14. The cover is what the *system* is shown (`NowPlaying`,
    // Control Center, the lock screen); the tile is what the *app* is found by,
    // and those are not the same job.

    // MARK: - The list

    var cursor = Cursor()
    /// How many track rows the window has room for. Set by the view, because
    /// the view is the only thing that knows how tall it is.
    private(set) var visibleRows = 12

    /// The window changed size. §18.22's fourth line lives in `Cursor.reflow`,
    /// and this is the only thing that calls it — a resize is the one event
    /// that can leave the list scrolled further down than it needs to be.
    func resized(rows: Int) {
        guard rows != visibleRows else { return }
        visibleRows = rows
        guard let record else { return }
        cursor.reflow(rows: rows, count: record.order.count)
    }

    private var lastPlayingRow = -1

    // MARK: - The sleeve (§5)

    private(set) var sleeve: Sleeve?

    /// The taste call, switchable from the environment while it is being decided.
    /// When it is decided this becomes a constant and the variable goes.
    let sleeveTreatment =
        SleeveImage.Treatment(
            rawValue: ProcessInfo.processInfo.environment["MUTHUR_SLEEVE"] ?? "") ?? .phosphor

    /// The other §5 call, settled: the bezel. It is not only a seat — the
    /// darkened edge is what buys back the tonal separation the cap at 5 costs
    /// the cover's highlights, which is why the two were picked together.
    let sleeveEdge =
        SleeveView.Edge(
            rawValue: ProcessInfo.processInfo.environment["MUTHUR_SLEEVE_EDGE"] ?? "") ?? .bezel

    private var sleeveWork: Task<Void, Never>?
    /// Step 3, the archive. **Nothing joins it**; it is held so a record being
    /// swapped can cancel the fetch for the one before it.
    private var pendingSleeve: Task<Sleeve?, Never>?

    /// Where a picture out of a tag gets written. Not §2's `Scratch` — that owns
    /// a pid file and a teardown and belongs with §1's source layer. This is the
    /// shortest thing that satisfies §5's "somewhere to put it", and it goes when
    /// the process does.
    private static let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "muthur-\(ProcessInfo.processInfo.processIdentifier)")

    /// **Nothing on the panel waits for this** (`player:1892`). The two local
    /// steps are a stat and at most three file opens and they finish before the
    /// record does; the archive answers when it answers, and if it never does,
    /// the panel is exactly the panel it would have been.
    private func findSleeve(for record: Record, directory: URL?) {
        sleeveWork?.cancel()
        pendingSleeve?.cancel()
        sleeve = nil

        let request = SleeveResolver.Request(
            record: record, directory: directory, scratch: Self.scratch)
        sleeveWork = Task {
            let resolver = SleeveResolver()
            // A cover that turned up late. By the time the archive answers the
            // record has been playing for several seconds and there is nowhere
            // for a return value to go, so it arrives by callback.
            let resolution = await resolver.resolve(request) { found in
                Task { @MainActor in self.arrived(found) }
            }
            guard !Task.isCancelled else { return }
            if let found = resolution.sleeve { sleeve = found }
            pendingSleeve = resolution.pending
        }
    }

    private func arrived(_ found: Sleeve) { sleeve = found }

    // MARK: - The shelf (§8)

    /// The catalogue, parsed once and kept for as long as the app runs. The
    /// script assembles its lookup once before the engine starts and never
    /// again, because the panel rebuilds itself many times a second for as long
    /// as the record lasts and this string never changes (`player:1723`).
    ///
    /// **Read only, ever** — `cd-collection` is not ours to write to
    /// (`CLAUDE.md`, D5). Read synchronously and on the path that opens a
    /// record, which is what `player:3558` does: it is one small file, and a
    /// header that arrives a frame late would be a header that changes height
    /// while you are looking at it.
    private var catalogue: Catalogue?
    private var catalogueRead = false

    /// What the shelf says about this record, or nothing at all. Every failure
    /// in here — no setting, no file, a renamed header, a record that is simply
    /// not in the catalogue — comes back `nil`, and a `nil` is a panel exactly
    /// as it would have been (`player:1618`).
    private func shelf(for record: Record) -> HeaderBlock.Shelf? {
        if !catalogueRead {
            catalogueRead = true
            catalogue = CatalogueFile.load()
        }
        guard
            let entry = catalogue?.look(
                album: record.album, albumArtist: record.albumArtist
            ), !entry.isEmpty
        else { return nil }
        return HeaderBlock.Shelf(entry)
    }

    /// A different catalogue was picked. Re-read it and rebuild the header, so
    /// the record on the deck picks up its own note rather than waiting for the
    /// next one.
    func catalogueChanged() {
        catalogueRead = false
        catalogue = nil
        guard let record else { return }
        header = HeaderBlock(record: record, shelf: shelf(for: record))
    }

    // MARK: - Resume

    private var resume: ResumeWatch?
    private(set) var offer: ResumeFile.Offer?

    // MARK: - Volume, which survives a quit

    /// §6.1a. A deck left at 3 is at 3 when you come back. It lives in the
    /// app's own defaults and **not** in the resume file: §18.19 froze that
    /// file's four fields so the bash player can go on reading it.
    private static let volumeKey = "muthur.volume"
    private static let mutedKey = "muthur.muted"

    // MARK: - The clock

    /// `TICK_HZ` — twenty a second, the rate the analyser's columns are stepped
    /// at (`player:2661`, and D23 on why that is not the same as the rate the
    /// levels are measured at).
    static let tickHz = 20.0

    private var ticker: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        let volume = defaults.object(forKey: Self.volumeKey) as? Double
        let muted = defaults.bool(forKey: Self.mutedKey)
        Task {
            await engine.setVolume(Float(volume ?? 1))
            if muted { await engine.toggleMute() }
            await engine.listen(analyser)
            await refresh()
        }
        // Once, because `MPRemoteCommandCenter` is a process-wide singleton and
        // its targets accumulate.
        nowPlaying.bind(
            NowPlaying.Transport(
                play: { [weak self] in self?.play() },
                pause: { [weak self] in self?.pause() },
                toggle: { [weak self] in self?.space() },
                next: { [weak self] in self?.next() },
                previous: { [weak self] in self?.previous() },
                seek: { [weak self] seconds in self?.seekTrack(to: seconds) }
            )
        )
        start()
    }

    // MARK: - Opening a record (§1)

    /// The script's `die()` — a message and nothing else.
    func die(_ message: String) {
        loading = nil
        stage = "▪ \(message)"
    }

    /// `--no-mb`, set once at launch (`player:81`'s `USE_MB`, which is a global
    /// there for the same reason it is a property here). Every path that opens
    /// a disc goes through `open(source:kind:)`, so this is the only place it
    /// has to be remembered.
    var useMusicBrainz = true

    /// Open a source — folder or zip — by URL and kind.
    func open(source url: URL, kind: SourceKind) {
        // The first stage is set here rather than waited for, because a folder
        // of four files can be read faster than the first `progress` call
        // arrives and a panel that flashes empty first is worse than one that
        // says `OPENING` for a sixteenth of a second. `open_source` does the
        // same: it announces the stage and then goes to work (`player:1398`).
        stage = nil
        loading = .opening(source: url.lastPathComponent, total: 0)
        record = nil
        pickerEntries = nil
        let useMusicBrainz = self.useMusicBrainz
        Task {
            do {
                let opened = try await SourceOpener.open(
                    url: url, kind: kind,
                    useMusicBrainz: useMusicBrainz,
                    progress: { [weak self] stage in
                        Task { @MainActor in self?.loading = stage }
                    }
                )
                self.scratch = opened.scratch
                adopt(
                    opened.record, source: opened.source,
                    titleSource: opened.titleSource, directory: opened.directory
                )
            } catch {
                die("\(error)")
            }
        }
    }

    // MARK: - The picker (§1.2)

    /// Scan the default directories for sources and show the picker — or open
    /// directly when there is exactly one.
    /// `--cd` (`player:3527`). The disc, or the script's own refusal.
    ///
    /// A window cannot `die`, so this lands on the panel the way every other
    /// refusal to open a source does — D36's shape, and the same reason ⌘O
    /// exists.
    func openDisc() {
        guard let disc = DiscFinder.find() else {
            die("\(SourceOpener.Failure.noDisc)")
            return
        }
        open(source: disc.volume, kind: .disc)
    }

    func scan() {
        let directories = SourceScanner.defaultDirectories()
        let found = SourceScanner.scan(directories: directories, disc: DiscFinder.find())

        switch found.count {
        case 0:
            let searched = directories.map(\.path).joined(separator: ", ")
            stage = "NOTHING TO PLAY IN \(searched.uppercased())"
        case 1:
            open(source: found[0].url, kind: found[0].kind)
        default:
            pickerEntries = found
            pickerCursor = 0
        }
    }

    func rescan() {
        let directories = SourceScanner.defaultDirectories()
        // `r` re-runs `scan_sources`, which re-runs `find_cd` — so a disc put in
        // after the picker was drawn appears on a rescan (`player:1018`). That
        // is the whole reason the key exists.
        let found = SourceScanner.scan(directories: directories, disc: DiscFinder.find())
        pickerEntries = found.isEmpty ? nil : found
        pickerCursor = min(pickerCursor, max(0, found.count - 1))
        pickerStatus = Readout.status("RESCANNED")
        if found.isEmpty {
            let searched = directories.map(\.path).joined(separator: ", ")
            stage = "NOTHING TO PLAY IN \(searched.uppercased())"
        }
    }

    func pickerStep(by delta: Int) {
        guard let entries = pickerEntries, !entries.isEmpty else { return }
        pickerCursor = max(0, min(entries.count - 1, pickerCursor + delta))
    }

    func pickerPageStep(by pages: Int) {
        pickerStep(by: pages * visibleRows)
    }

    func openPicked() {
        guard let entries = pickerEntries,
              pickerCursor >= 0, pickerCursor < entries.count
        else { return }
        let entry = entries[pickerCursor]
        open(source: entry.url, kind: entry.kind)
    }

    /// `BROWSE` — a record from anywhere, on the same rails as one from the list.
    ///
    /// **The scan is not what is wrong with the picker; it is what is limited
    /// about it.** `scan_sources` looks one level down `MUTHUR_DIRS` and nowhere
    /// else (`player:1036`), which is right nearly always and useless for the
    /// album on the external drive, the one two folders deep, and — since D47 —
    /// the archive whose central directory would not open. The script has no
    /// answer to any of those but "export a different `PLAYER_DIRS` and start
    /// again", because a TUI over ssh has no file chooser to reach for. A window
    /// does, so the list stays the default and this is the escape hatch.
    ///
    /// It goes through `SourceOpener.resolve` and `open(source:kind:)`, which is
    /// exactly what `openPicked` does with a row — one way in, so a folder
    /// chosen here cannot behave differently from the same folder found by the
    /// scan. ⌘O is this method too.
    func browse() {
        let panel = NSOpenPanel()
        panel.message = "A folder of tracks, or a zip of one."
        panel.prompt = "Play"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.folder, .zip]
        // Cancelling is not a refusal to be reported. The script's picker leaves
        // by `screen_off; exit 0` (`player:3532`); here the picker is simply
        // still up, which is the same nothing-happened in a window.
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let (resolved, kind) = try SourceOpener.resolve(path: url.path)
            open(source: resolved, kind: kind)
        } catch {
            // `die "not a zip or a folder: %s"` (`player:3524`), in the panel's
            // own voice rather than an alert — the same place every other
            // refusal to open a source is already printed.
            die("\(error)")
        }
    }

    func pickerClick(row: Int) {
        guard let entries = pickerEntries,
              row >= 0, row < entries.count
        else { return }
        if row == pickerCursor {
            openPicked()
        } else {
            pickerCursor = row
        }
    }

    /// The visible window of the picker list.
    var pickerVisible: Range<Int> {
        guard let entries = pickerEntries, !entries.isEmpty else { return 0..<0 }
        let count = entries.count
        let rows = visibleRows
        if count <= rows { return 0..<count }
        var top = pickerCursor - rows / 2
        top = max(0, min(top, count - rows))
        return top..<min(top + rows, count)
    }

    var pickerBelow: Int {
        guard let entries = pickerEntries else { return 0 }
        let range = pickerVisible
        return max(0, entries.count - range.upperBound)
    }

    private func adopt(
        _ read: Record, source: SourceKind, titleSource: TitleSource?, directory: URL?
    ) {
        record = read
        stage = nil
        loading = nil
        // The deck is loaded a moment from now, and until it is, `state` still
        // describes the record that just came off. A record change is a stop and
        // then a start, and the system is told it that way round rather than
        // being shown one record's title against another's playhead.
        nowPlaying.clear()
        // The scales now live across a track change (D33), so this is where they
        // are let go of: a record on the deck knows nothing about the last one.
        analyser.newRecord()
        columns = TrackColumns.decide(for: read)
        // §8 and §7 both here, and both after everything that names the album,
        // because each is looked up by what the record turned out to be rather
        // than by where it came from (`player:3555`).
        header = HeaderBlock(record: read, shelf: shelf(for: read))
        sourceKind = source
        self.titleSource = titleSource
        cursor = Cursor()
        lastPlayingRow = -1

        let key = ResumeFile.key(for: read)
        var watch = ResumeWatch(
            file: .standard(), key: key, sourceLabel: read.sourceLabel, rows: read.order.count
        )
        offer = watch.offerToShow(mode: .stopped)
        resume = watch

        findSleeve(for: read, directory: directory)

        Task {
            try? await engine.load(read, source: source)
            await refresh()
        }
    }

    // MARK: - The tick

    /// Twenty a second, and each tick does its work before the next is asked
    /// for. Sleeping between them rather than queueing them is what keeps the
    /// lesson `player:2643` learned: a window behind another window drains
    /// slowly, and queued ticks replay as visible catch-up lag. There is no
    /// backlog here to replay — a tick that is late is simply late.
    private func start() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            let interval = Duration.milliseconds(Int(1000 / PanelModel.tickHz))
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self else { return }
                await self.tick()
            }
        }
    }

    private func tick() async {
        analyser.frame()
        await engine.pump()
        await refresh()
    }

    private func refresh() async {
        let fresh = await engine.state
        let started = fresh.row != lastPlayingRow
        state = fresh

        if let record {
            if started {
                lastPlayingRow = fresh.row
                // §6: at every track start, a following cursor goes where the
                // music went (`player:3405`).
                cursor.trackStarted(fresh.row, rows: visibleRows, count: record.order.count)
                analyser.newTrack()
            }
            resume?.observe(
                mode: fresh.mode, row: fresh.row, positionInTrack: fresh.positionInTrack
            )
            offer = resume?.offerToShow(mode: fresh.mode)
        }

        // §14. Outside the `if`, because a panel with no record on it must say
        // so to the system too — a stale dictionary keeps the media keys coming
        // here instead of going wherever the music actually is now.
        nowPlaying.observe(record: record, state: fresh, sleeve: sleeve)
    }

    // MARK: - What the faceplate says

    var mode: Faceplate.Mode {
        switch state.mode {
        case .playing: .playing
        case .paused: .paused
        case .stopped: .stopped
        case .finished: .finished
        }
    }

    /// **Every screen's plate, in one place** (§10). The order is the order the
    /// screens cover each other in `PanelView`: the check goes over whatever was
    /// showing, the picker and the loading stage only exist while there is no
    /// record, and the deck's own meta is what is left.
    var faceplateMeta: String {
        if let report {
            return Faceplate.checkMeta(
                count: report.checks.count,
                warnings: report.checks.filter { $0.mark == .warn }.count,
                failures: report.checks.filter { $0.mark == .fail }.count
            )
        }
        if let entries = pickerEntries, record == nil {
            return Faceplate.pickerMeta(count: entries.count)
        }
        if let loading { return loading.meta }
        return Faceplate.meta(
            mode: mode, trackCount: record?.order.count ?? 0, source: titleSource,
            level: Faceplate.level(volume: state.volume, muted: state.muted)
        )
    }

    /// A status message set by the picker.
    private(set) var pickerStatus: String?

    /// The status line, which the resume offer gets to borrow when the deck has
    /// nothing of its own to say. A record you have not started yet is exactly
    /// when the offer is worth reading.
    var statusLine: String? {
        // The check has its own legend and its rows are the message; a status
        // line under it would be the deck talking over the diagnosis.
        if isChecking { return nil }
        // Nor while a source is coming open: `load_stage` has no status row
        // (`player:1162`), and the offer it would carry is about the record
        // that is still being read.
        if isLoading { return nil }
        if isPicking { return pickerStatus }
        if let text = state.status?.text { return text }
        if let offer { return offer.text }
        return nil
    }

    // MARK: - The keys (§6.1)

    func space() { Task { await engine.togglePause() } }

    /// PLAY and PAUSE as separate verbs, which the keyboard never needed and a
    /// system transport does. §14 — see `NowPlaying`.
    func play() { Task { await engine.play(); await refresh() } }
    func pause() { Task { await engine.pause(); await refresh() } }

    func seek(by seconds: Double) { Task { await engine.nudge(by: seconds) } }

    /// `↑↓` — browsing, which stops the cursor chasing the music.
    func step(by rows: Int) {
        guard let record else { return }
        cursor.browse(by: rows, rows: visibleRows, count: record.order.count)
    }

    /// `⏎` — play what the cursor is on, and start following it again.
    func jump() {
        guard let record else { return }
        let row = cursor.row
        cursor.choose(row, rows: visibleRows, count: record.order.count)
        Task {
            await engine.pick(row: row)
            await engine.play()
            await refresh()
        }
    }

    func next() {
        guard let record else { return }
        cursor.choose(cursor.row, rows: visibleRows, count: record.order.count)
        Task {
            await engine.next()
            await refresh()
        }
    }

    func previous() {
        guard let record else { return }
        cursor.choose(cursor.row, rows: visibleRows, count: record.order.count)
        Task {
            await engine.previous()
            await refresh()
        }
    }

    func toggleShuffle() { Task { await engine.toggleShuffle(); await refresh() } }
    func cycleRepeat() { Task { await engine.cycleRepeat(); await refresh() } }

    /// `u`, and bound only while there is an offer to take (`player:2720`).
    func takeOffer() {
        guard let record, let taken = resume?.spend() else { return }
        offer = nil
        cursor.choose(taken.row, rows: visibleRows, count: record.order.count)
        Task {
            await engine.pick(row: taken.row, offset: Double(taken.position))
            await engine.play()
            await refresh()
        }
    }

    // MARK: - Volume (§6.1a)

    func nudgeVolume(by delta: Float) {
        Task {
            await engine.nudgeVolume(by: delta)
            await refresh()
            UserDefaults.standard.set(Double(state.volume), forKey: Self.volumeKey)
        }
    }

    func toggleMute() {
        Task {
            await engine.toggleMute()
            await refresh()
            UserDefaults.standard.set(state.muted, forKey: Self.mutedKey)
        }
    }

    // MARK: - The meters as controls (§6.4)

    /// A cell of the album meter, which is a position in the whole record
    /// whichever track it lands in (`player:3329`).
    func seekRecord(cell: Int, dragging: Bool) {
        guard let record, record.total > 0 else { return }
        let seconds = Double(cell * record.total / PanelGrid.stripWidth)
        if !dragging {
            cursor.choose(cursor.row, rows: visibleRows, count: record.order.count)
        }
        Task {
            await engine.seek(inRecord: seconds, dragging: dragging)
            await refresh()
        }
    }

    /// A cell of the track meter, which is a position in this track only.
    func seekTrack(cell: Int) {
        guard state.trackDuration > 0 else { return }
        seekTrack(to: Double(cell) * state.trackDuration / Double(PanelGrid.stripWidth))
    }

    /// The same move in seconds rather than in cells — where Control Center's
    /// scrubber lands, because it has no idea the meter is 80 cells wide.
    func seekTrack(to seconds: Double) {
        Task {
            await engine.seekInTrack(to: seconds)
            await refresh()
        }
    }

    /// A click on a row. The first one moves the cursor and the second one on
    /// the same row starts it, which is the difference between reading the list
    /// with the pointer and being made to listen to whatever the pointer
    /// happened to land on (`player:3213`).
    func click(row: Int) {
        guard let record, row >= 0, row < record.order.count else { return }
        if row == cursor.row {
            jump()
        } else {
            cursor.browse(to: row, rows: visibleRows, count: record.order.count)
        }
    }

    /// The wheel walks the track list — over a panel whose one long list is the
    /// track list, scrolling means what the arrow keys mean (`player:3188`).
    func wheel(_ lines: Int) {
        guard lines != 0 else { return }
        step(by: lines)
    }

    // MARK: - What the list is showing

    var visible: Range<Int> {
        guard let record else { return 0..<0 }
        return cursor.window(rows: visibleRows, count: record.order.count).visible
    }

    var below: Int {
        guard let record else { return 0 }
        return cursor.window(rows: visibleRows, count: record.order.count).more
    }

    func mark(for row: Int) -> Readout.Mark {
        guard row == state.row, state.mode != .stopped else { return .none }
        return state.mode == .paused ? .held : .playing
    }

    // MARK: - The exit path (§2)

    /// Torn down however the app ends (`player:285`). Order matches the script:
    /// stop the player, then the analyser (which is a tap on the player's node),
    /// then delete the scratch directory. Nothing here may be skipped because
    /// something earlier failed — `set +e` in the script.
    func cleanup() async {
        ticker?.cancel()
        ticker = nil
        sleeveWork?.cancel()
        pendingSleeve?.cancel()
        await engine.shutdown()
        nowPlaying.clear()
        tearDownScratch()
    }

    /// The promise this program makes about your disk (`player:312`).
    private func tearDownScratch() {
        guard let scratch else { return }
        let keep = Scratch.keepRequested(
            environment: ProcessInfo.processInfo.environment
        )
        if let kept = try? scratch.tearDown(keep: keep) {
            FileHandle.standardError.write(
                Data("muthur: scratch kept at \(kept.path)\n".utf8)
            )
        }
        self.scratch = nil
    }
}
