import AVFoundation
import MUTHURKit
import Observation
import SwiftUI

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

    /// The stage the panel is at when there is no record yet. §1 will replace
    /// the whole of this with a real source layer.
    private(set) var stage: String?

    // MARK: - The deck

    let engine = PlaybackEngine()
    let analyser = Analyser()

    private(set) var state = PlaybackEngine.State.empty

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
        start()
    }

    // MARK: - Opening a record

    /// **Not §1.** §1 is the source layer — the picker, the zip, the disc, the
    /// argument off the command line, the collection lookup — and none of it
    /// exists yet. This is the shortest path from a folder on disk to something
    /// the panel can draw, so that the panel can be looked at while it is being
    /// built, and it should be deleted the day §1 lands.
    func open(folder: URL) {
        stage = "OPENING"
        record = nil
        Task {
            do {
                let label = folder.lastPathComponent
                let read = try await Record.read(
                    directory: folder, sourceLabel: label,
                    progress: { [weak self] progress in
                        Task { @MainActor in
                            self?.stage = "READING · \(progress.percent)% · \(progress.filename)"
                        }
                    }
                )
                adopt(read, source: .folder, titleSource: .tags, directory: folder)
            } catch {
                stage = "\(error)"
            }
        }
    }

    private func adopt(
        _ read: Record, source: SourceKind, titleSource: TitleSource?, directory: URL?
    ) {
        record = read
        stage = nil
        // The scales now live across a track change (D33), so this is where they
        // are let go of: a record on the deck knows nothing about the last one.
        analyser.newRecord()
        columns = TrackColumns.decide(for: read)
        header = HeaderBlock(record: read)
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

    var faceplateMeta: String {
        Faceplate.meta(
            mode: mode, trackCount: record?.order.count ?? 0, source: titleSource,
            level: Faceplate.level(volume: state.volume, muted: state.muted)
        )
    }

    /// The status line, which the resume offer gets to borrow when the deck has
    /// nothing of its own to say. A record you have not started yet is exactly
    /// when the offer is worth reading.
    var statusLine: String? {
        if let text = state.status?.text { return text }
        if let offer { return offer.text }
        return nil
    }

    // MARK: - The keys (§6.1)

    func space() { Task { await engine.togglePause() } }

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
        let seconds = Double(cell) * state.trackDuration / Double(PanelGrid.stripWidth)
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
}
