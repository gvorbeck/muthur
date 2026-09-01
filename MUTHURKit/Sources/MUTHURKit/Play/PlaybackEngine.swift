import AVFoundation
import Foundation

/// §6. The deck.
///
/// One `AVAudioEngine`, one `AVAudioPlayerNode`, and a stream of PCM buffers
/// scheduled into it back to back. Not `scheduleFile`, not a queue of players:
/// a player node renders consecutively scheduled buffers with nothing between
/// them, so **the seam between two tracks is an ordinary buffer boundary inside
/// one continuous stream**. Everything that could differ between two files —
/// sample rate, channel count, even which decoder read them — is settled on the
/// decoder side by `CanonicalFormat` and `Feeder` before the graph ever sees it.
/// The player node's connection format is decided once per record and never
/// changes, which is why there is no boundary in the audio graph to bridge.
///
/// The engine reads about two seconds ahead, so at any moment the next track is
/// already open and decoded while the current one is still coming out of the
/// speakers. That is what makes it gapless and it is also what makes "what is
/// playing" a question that must be *asked* rather than assumed: `Timeline` maps
/// the output stream back to rows, and the row you are on is the one the render
/// head is in. A track that ran out and a track picked with the cursor arrive by
/// the same route (`player:2461`).
public actor PlaybackEngine {

    // MARK: - What the panel reads

    public enum Mode: String, Sendable, Equatable {
        case stopped, playing, paused, finished

        /// The label across the faceplate (`player:3308`, `player:3497`).
        public var label: String { rawValue.uppercased() }
    }

    /// The status line. Blunt on purpose — D8: these already read as a machine
    /// talking, which is precisely why they work.
    public enum Status: Sendable, Equatable {
        case shuffle(Bool)
        case repeatMode(Transport.Repeat)
        case endOfAlbum
        case tracksGone(missing: Int, of: Int, source: SourceKind)
        case cannotRead(reason: String)

        public var text: String {
            switch self {
            case .shuffle(let on):
                "▪ SHUFFLE \(on ? "ON" : "OFF")"
            case .repeatMode(let mode):
                "▪ REPEAT \(mode.label)"
            case .endOfAlbum:
                "▪ END OF ALBUM — PRESS Q TO QUIT, ⏎ TO PLAY A TRACK"
            case .tracksGone(let missing, let total, let source):
                "▪ \(missing) OF \(total) TRACKS ARE NO LONGER ON DISK"
                    + (source == .zip
                        ? " — THE UNPACKED COPY IS GONE. Q, THEN PLAY IT AGAIN"
                        : " — STOPPED HERE")
            case .cannotRead(let reason):
                "▪ CANNOT READ THIS TRACK · \(reason) — STOPPED HERE, ⏎ TO TRY ANOTHER"
            }
        }
    }

    public struct State: Sendable, Equatable {
        public var mode: Mode
        /// Row in the running order — the same integer the panel draws and the
        /// same one the feeder indexes by, deliberately (`player:3239`).
        public var row: Int
        public var positionInTrack: Double
        public var trackDuration: Double
        public var positionInRecord: Double
        public var recordDuration: Double
        public var shuffle: Bool
        public var repeatMode: Transport.Repeat
        public var status: Status?
        public var volume: Float
        public var muted: Bool

        /// A deck with nothing on it. §10 needs something to draw in the moment
        /// between the window appearing and the first answer coming back across
        /// the actor boundary, and a blank panel drawn from real zeroes is more
        /// honest than one drawn from whatever the last record left behind.
        public static let empty = State(
            mode: .stopped, row: 0, positionInTrack: 0, trackDuration: 0,
            positionInRecord: 0, recordDuration: 0, shuffle: false,
            repeatMode: .off, status: nil, volume: 1, muted: false
        )
    }

    // MARK: - The graph

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let offline: Bool
    private var running = false
    /// §9, waiting for a player node to hang off. See `listen`.
    private var listener: Analyser?
    private var canonical = CanonicalFormat.format(
        rate: CanonicalFormat.fallbackRate, channels: CanonicalFormat.fallbackChannels
    )

    /// A hundred milliseconds of manual rendering at a time. Big enough that
    /// the offline suites are not spending their lives in call overhead, small
    /// enough that `pump` runs often enough to keep the queue fed.
    private static let manualRenderFrames: AVAudioFrameCount = 4096

    // MARK: - The record

    private var rows: [Track] = []
    private var urls: [URL] = []
    /// PRE running totals — where each row starts in the record, in seconds
    /// (`player:3329`). The album meter is denominated in these.
    private var starts: [Int] = []
    private var recordSeconds = 0
    private var sourceKind: SourceKind = .folder

    // MARK: - Feeding

    private var feeder: Feeder?
    private var timeline = Timeline()
    private var feedRow = 0
    private var feedVisit = 0
    private var feedEnded = false
    private var nextVisit = 1
    /// Which entry of the shuffled history each playing of a track belongs to.
    /// Kept out of the timeline because it changes under the panel's feet —
    /// turning shuffle on mid-track gives the track you are already hearing a
    /// place in a history that did not exist a moment ago.
    private var visitHistory: [Int: Int] = [:]

    // MARK: - Hearing

    private var transport = Transport(count: 0)
    private var currentRow = 0
    private var currentVisit = 0
    private var mode: Mode = .stopped
    private var status: Status?

    /// Where the render head is, in frames since the last discontinuity.
    private var lastHead: AVAudioFramePosition = 0
    private var offlineHead: AVAudioFramePosition = 0
    private var endedAtFrame: AVAudioFramePosition?

    // MARK: - §6.3

    /// The frame at which the record stops because something would not open.
    /// Planted when the *feeder* hits the failure, which is two seconds before
    /// the ear would — acted on when the head arrives, so the panel never reads
    /// STOPPED while sound is still coming out.
    private var stopAt: AVAudioFramePosition?
    private var stopRow = 0
    private var stopReason = ""

    // MARK: - §6.4

    private var pendingSeek: Double?

    // MARK: - §6.1a

    private var volume: Float = 1
    private var muted = false

    /// How many times a file has been opened. Not decoration: it is how the
    /// suites establish that a drag the length of the record opens the track it
    /// finished on and not the forty it crossed.
    public private(set) var trackOpenCount = 0

    public init(offline: Bool = false) {
        self.offline = offline
    }

    // MARK: - Loading

    /// The whole record at once, in panel order, so the engine can read ahead
    /// into the next file while the current one is still playing (`player:2453`).
    public func load(_ record: Record, source: SourceKind = .folder, seed: UInt64? = nil) throws {
        teardown()

        rows = record.running
        urls = rows.map(\.url)
        var total = 0
        starts = rows.map { track in
            defer { total += track.duration }
            return total
        }
        recordSeconds = total
        sourceKind = source
        transport = Transport(count: rows.count, seed: seed)

        // Decided once, before the first sample. Everything downstream is in
        // this format and the graph is never reconfigured.
        canonical = CanonicalFormat.decided(for: urls)
        feeder = Feeder(canonical: canonical)

        try startGraph()

        currentRow = 0
        currentVisit = 0
        feedRow = 0
        feedVisit = 0
        mode = .stopped
        status = nil
    }

    private func startGraph() throws {
        engine.attach(player)
        if offline {
            try engine.enableManualRenderingMode(
                .offline, format: canonical, maximumFrameCount: PlaybackEngine.manualRenderFrames
            )
        }
        // Through the main mixer, not straight to the output: §6.1a's gain is
        // *ours*, not the system's, and §9's analyser tap wants a node between
        // the player and the speakers to hang off.
        engine.connect(player, to: engine.mainMixerNode, format: canonical)
        applyGain()
        try engine.start()
        running = true
        listener?.tap(player)
    }

    /// The app's exit path. Stops the graph, closes the feeder, and resets
    /// state — the same thing `load` does before putting a new record on, done
    /// here because the process is leaving and nobody is loading anything next.
    public func shutdown() { teardown() }

    private func teardown() {
        if running {
            listener?.untap(player)
            player.stop()
            engine.stop()
            engine.disconnectNodeOutput(player)
            engine.detach(player)
            if engine.manualRenderingMode != .realtime { engine.disableManualRenderingMode() }
            running = false
        }
        feeder?.close()
        feeder = nil
        timeline.reset()
        visitHistory.removeAll()
        stopAt = nil
        pendingSeek = nil
        endedAtFrame = nil
        lastHead = 0
        offlineHead = 0
        feedEnded = false
    }

    // MARK: - State

    public var state: State {
        let finished = mode == .finished
        let trackDuration = Double(rows.indices.contains(currentRow) ? rows[currentRow].duration : 0)
        // §6.2: both meters parked at **full**, not at the fraction-before-the-end
        // the last position report carried (`player:3499`).
        let inTrack = finished ? trackDuration : min(positionInTrack, trackDuration)
        let inRecord =
            finished
            ? Double(recordSeconds)
            : min(Double(starts[safe: currentRow] ?? 0) + inTrack, Double(recordSeconds))
        return State(
            mode: mode,
            row: currentRow,
            positionInTrack: inTrack,
            trackDuration: trackDuration,
            positionInRecord: inRecord,
            recordDuration: Double(recordSeconds),
            shuffle: transport.shuffle,
            repeatMode: transport.repeatMode,
            status: status,
            volume: volume,
            muted: muted
        )
    }

    private var positionInTrack: Double {
        Double(framesIntoTrack) / canonical.sampleRate
    }

    private var framesIntoTrack: AVAudioFramePosition {
        guard let segment = timeline.segment(at: lastHead) else { return 0 }
        let within = max(0, min(lastHead, segment.end) - segment.start)
        return segment.offset + within
    }

    public var canonicalFormatDescription: String {
        "\(Int(canonical.sampleRate)) Hz · \(canonical.channelCount) ch"
    }

    public var shuffledHistory: [Int] { transport.shuffledOrder?.history ?? [] }

    // MARK: - Transport (§6.1)

    /// `⏎` on a row, and the first play of a record.
    ///
    /// §6.3: picking a track by hand clears the failure **and takes off the
    /// pause it put on** — without the unpause, choosing another track after a
    /// bad one looks like a second failure, the row changes and nothing plays
    /// (`player:3273`).
    public func pick(row: Int, offset: Double = 0) {
        guard urls.indices.contains(row) else { return }
        let move = transport.pick(row, historyIndex: visitHistory[currentVisit])
        mode = .playing
        apply(move, offset: offset)
    }

    public func play() {
        switch mode {
        case .playing: break
        case .paused:
            mode = .playing
            player.play()
        case .stopped, .finished:
            pick(row: currentRow)
        }
    }

    /// Pause, asked for by name rather than by `␣`.
    ///
    /// `player` never needed this — a terminal has one key and it toggles. A
    /// system transport does not toggle: Control Center sends PAUSE when it can
    /// see the deck is playing and PLAY when it can see it is not, and a
    /// Bluetooth remote sends both as separate buttons. Handing either of them
    /// `togglePause` means a PAUSE that arrives a moment stale starts the
    /// record instead of stopping it.
    ///
    /// Refuses from STOPPED and FINISHED for the same reason `togglePause`
    /// does (`player:2787`, `player:3308`).
    public func pause() {
        guard mode == .playing else { return }
        mode = .paused
        player.pause()
    }

    /// `␣`. Nothing to do from STOPPED or FINISHED: the failure pause must not
    /// be reported as the space-bar pause (`player:2787`), and a deck that is
    /// paused is waiting for you while this one is not (`player:3308`).
    public func togglePause() {
        switch mode {
        case .playing:
            mode = .paused
            player.pause()
        case .paused:
            mode = .playing
            player.play()
        case .stopped, .finished:
            break
        }
    }

    /// `n`. D3 lives in `Transport.next` — under REPEAT TRACK this advances and
    /// the mode stays on, so the track it lands on is the one that loops.
    public func next() {
        guard !urls.isEmpty else { return }
        let move = transport.next(from: currentRow, historyIndex: visitHistory[currentVisit])
        if mode != .paused { mode = .playing }
        apply(move, offset: 0)
    }

    /// `p`. Within three seconds, the previous track; after that, the start of
    /// this one. Under shuffle "previous" is the one you actually heard.
    public func previous() {
        guard !urls.isEmpty else { return }
        let move = transport.previous(
            from: currentRow,
            historyIndex: visitHistory[currentVisit],
            position: positionInTrack
        )
        if mode != .paused { mode = .playing }
        apply(move, offset: 0)
    }

    private func apply(_ move: Transport.Move, offset: Double) {
        switch move {
        case .play(let row, let history):
            // Starting a track clears the status line — including "end of
            // album", which a track starting has just made untrue
            // (`player:3398`).
            status = nil
            restart(row: row, offsetSeconds: offset, historyIndex: history)
        case .again:
            status = nil
            restart(
                row: currentRow, offsetSeconds: offset,
                historyIndex: visitHistory[currentVisit]
            )
        case .end:
            finish()
        }
    }

    public func toggleShuffle() {
        transport.toggleShuffle(from: currentRow)
        if let index = transport.historyIndex { visitHistory[currentVisit] = index } else {
            visitHistory.removeValue(forKey: currentVisit)
        }
        resyncIfFedAhead()
        status = .shuffle(transport.shuffle)
    }

    public func cycleRepeat() {
        transport.repeatMode = transport.repeatMode.next
        resyncIfFedAhead()
        status = .repeatMode(transport.repeatMode)
    }

    /// D21. Read-ahead is a couple of seconds, so nine times in ten the feeder
    /// has not reached the next track yet and a change of policy simply applies
    /// when it does — nothing scheduled, nothing to withdraw, no seam. Where it
    /// *has* already crossed, what is queued is an answer to the old question,
    /// and the only way to unschedule a buffer from a player node is to stop it.
    /// The cost is confined to the last seconds of a track.
    private func resyncIfFedAhead() {
        guard feedVisit != currentVisit, mode == .playing || mode == .paused else { return }
        restart(
            row: currentRow,
            offsetSeconds: positionInTrack,
            historyIndex: visitHistory[currentVisit]
        )
    }

    // MARK: - §6.1a Volume

    public func setVolume(_ level: Float) {
        volume = min(max(level, 0), 1)
        applyGain()
    }

    public func nudgeVolume(by delta: Float) {
        setVolume(volume + delta)
    }

    public func toggleMute() {
        muted.toggle()
        applyGain()
    }

    private func applyGain() {
        guard running else { return }
        engine.mainMixerNode.outputVolume = muted ? 0 : volume
    }

    // MARK: - §9 The analyser's tap

    /// Hang the analyser on the deck, **before the gain** (§6.1a).
    ///
    /// The gain is the main mixer's `outputVolume`, so before it is the player
    /// node — everything the decoders produced, at the level the record was
    /// mastered at, whatever the knob is doing. A record turned down is not a
    /// record playing quietly into its own bands: the columns would drop, §9's
    /// per-band autoscale would spend the next few seconds hauling them back up,
    /// and the panel would end up saying nothing about the music and something
    /// about the volume knob.
    ///
    /// It is the faithful port as well as the right behaviour. The script's
    /// analyser reads the decoded *file* and there is no volume control anywhere
    /// in that path, so turning the music down never moved its bars — there was
    /// nothing there to turn down (`player:754`).
    ///
    /// The node stays private: handing it out would let a caller reconnect the
    /// graph, and the analyser only ever needed somewhere to listen.
    /// The listener is remembered rather than wired straight in, because the
    /// player node only exists in the graph while a record is on the deck: it is
    /// attached in `startGraph` and detached again in `teardown`, and a tap on a
    /// detached node is not a quiet no-op — AVAudioEngine raises. So §9 says once
    /// that it wants to listen, and the graph hands it the player every time
    /// there is a player to hand it.
    public func listen(_ analyser: Analyser) {
        listener = analyser
        if running { analyser.tap(player) }
    }

    public func stopListening(_ analyser: Analyser) {
        if running { analyser.untap(player) }
        if listener === analyser { listener = nil }
    }

    // MARK: - §6.4 The meters as controls

    /// Click the **track** meter.
    public func seekInTrack(to seconds: Double) {
        guard rows.indices.contains(currentRow) else { return }
        let clamped = min(max(seconds, 0), Double(rows[currentRow].duration))
        restart(
            row: currentRow, offsetSeconds: clamped, historyIndex: visitHistory[currentVisit]
        )
    }

    /// `←` `→` ∓5 s, `⇧←` `⇧→` ∓30 s. Relative to **this track**, not to the
    /// record: thirty seconds back from ten seconds in is the top of the track
    /// you are on, not ten seconds into the one before it. That is the whole
    /// difference between an arrow key and the album meter.
    ///
    /// Forward past the end still runs the track out — the clamp lands on the
    /// last frame and the ordinary end-of-track path takes it from there, which
    /// is what mpv's relative seek did for the script (`player:2690`).
    public func nudge(by seconds: Double) {
        seekInTrack(to: positionInTrack + seconds)
    }

    /// Click or drag the **album** meter: put the needle anywhere in the record,
    /// whichever track that lands in (`player:3329`).
    ///
    /// **D2.** A drag crosses track boundaries freely — bash confined one to the
    /// track it started in because its loop could hold one track-change request
    /// at a time over a socket (`player:3340`), which is a property of the IPC.
    /// What survives is the hazard underneath: *never act on a position for a
    /// track that is not open yet*. Two things enforce it here.
    ///
    /// First, a drag only ever **records** a position; the pump acts on the last
    /// one recorded. A pointer crossing forty rows in a second cannot make this
    /// open forty files, and the position that takes effect is the one the drag
    /// finished on rather than the one it started with.
    ///
    /// Second — the pending-offset rule proper — an offset into another track is
    /// handed to `Feeder.open` as the frame to start at, so it is applied by the
    /// act of opening. There is no window in which a seek can land in the track
    /// being left (`player:3336`), because there is no moment at which the
    /// offset exists and the new track does not.
    public func seek(inRecord seconds: Double, dragging: Bool = false) {
        pendingSeek = seconds
        if !dragging { serviceSeek() }
    }

    private func serviceSeek() {
        guard let seconds = pendingSeek else { return }
        pendingSeek = nil
        let target = rowAndOffset(atRecordSeconds: seconds)
        status = nil
        if mode == .stopped || mode == .finished { mode = .playing }
        restart(
            row: target.row,
            offsetSeconds: target.offset,
            historyIndex: pickHistory(for: target.row)
        )
    }

    /// The album meter is a position in the record, not a row, so landing on a
    /// row this way is a pick as far as the shuffled order is concerned.
    private func pickHistory(for row: Int) -> Int? {
        guard transport.shuffle else { return nil }
        guard row != currentRow else { return visitHistory[currentVisit] }
        if case .play(_, let index) = transport.pick(row, historyIndex: visitHistory[currentVisit])
        {
            return index
        }
        return nil
    }

    /// The target row is the last one starting at or before the point; the
    /// remainder is an offset into it (`player:3329`).
    func rowAndOffset(atRecordSeconds seconds: Double) -> (row: Int, offset: Double) {
        guard !rows.isEmpty else { return (0, 0) }
        let clamped = min(max(seconds, 0), Double(recordSeconds))
        var row = 0
        for index in starts.indices where Double(starts[index]) <= clamped { row = index }
        return (row, clamped - Double(starts[row]))
    }

    // MARK: - The pump

    /// Everything that has to happen on a clock: service a drag, keep the queue
    /// two seconds ahead of the head, and notice where the head has got to.
    ///
    /// Called on a timer while playing, and by the offline renderer between
    /// blocks — which is what makes the whole of §6 testable without a sound
    /// card and without waiting in real time for a record to finish.
    public func pump() {
        // An empty deck. §10's clock starts with the window, not with the
        // record, so the first few hundred ticks arrive before there is a graph
        // to pump — and asking a detached node what time it is raises rather
        // than answering.
        guard running else { return }
        serviceSeek()
        fill()
        observe()
    }

    private func fill() {
        guard let feeder, stopAt == nil, mode == .playing || mode == .paused else { return }
        let readAhead = AVAudioFramePosition(canonical.sampleRate * PlaybackEngine.readAheadSeconds)
        var steps = 0
        while !feedEnded, timeline.end - lastHead < readAhead, steps < 64 {
            steps += 1
            do {
                switch try feeder.produce(frames: chunkFrames) {
                case .produced(let buffer, let row, let offset):
                    schedule(buffer, row: row, offset: offset, visit: feedVisit)
                case .exhausted:
                    if !advanceFeed() { return }
                case .idle:
                    feedEnded = true
                }
            } catch {
                plant(failure: error, row: feeder.row)
                return
            }
        }
    }

    /// The open file ran out. Ask what follows and open it — while the samples
    /// already scheduled are still playing, which is the whole trick.
    private func advanceFeed() -> Bool {
        guard let feeder else { return false }
        let move = transport.follows(feedRow, historyIndex: visitHistory[feedVisit])
        switch move {
        case .again:
            // REPEAT TRACK is the engine's own loop: the decoder rewinds, the
            // file is not reopened (§6.1).
            do { try feeder.rewind() } catch {
                plant(failure: error, row: feedRow)
                return false
            }
            feedVisit = claimVisit(history: visitHistory[feedVisit])
            return true

        case .play(let row, let history):
            do {
                if let tail = try feeder.follow(row: row, url: urls[row]),
                    case .produced(let buffer, let tailRow, let tailOffset) = tail
                {
                    schedule(buffer, row: tailRow, offset: tailOffset, visit: feedVisit)
                }
                trackOpenCount += 1
            } catch {
                plant(failure: error, row: row)
                return false
            }
            feedRow = row
            feedVisit = claimVisit(history: history)
            return true

        case .end:
            if case .produced(let buffer, let row, let offset)? = feeder.flushTail() {
                schedule(buffer, row: row, offset: offset, visit: feedVisit)
            }
            feeder.close()
            feedEnded = true
            return false
        }
    }

    private func schedule(
        _ buffer: AVAudioPCMBuffer, row: Int, offset: AVAudioFramePosition, visit: Int
    ) {
        player.scheduleBuffer(buffer, completionHandler: nil)
        timeline.append(
            frames: AVAudioFramePosition(buffer.frameLength), row: row, offset: offset, visit: visit
        )
    }

    private func observe() {
        lastHead = head
        timeline.trim(before: lastHead)

        if let stopAt, lastHead >= stopAt {
            applyFailure()
            return
        }
        // Deliberately not conditioned on anything having been scheduled. Drop
        // the needle on the last frame of the last track — the right-hand end of
        // the album meter is exactly that — and the feed ends having produced
        // nothing at all. A record that produced no frames has still finished,
        // and the alternative is a deck sitting on PLAYING in silence.
        if feedEnded, mode == .playing, lastHead >= timeline.end {
            finish()
            return
        }
        guard let segment = timeline.segment(at: lastHead) else { return }
        if segment.visit != currentVisit { enter(segment) }
    }

    private var head: AVAudioFramePosition {
        if offline { return offlineHead }
        guard
            let nodeTime = player.lastRenderTime,
            nodeTime.isSampleTimeValid,
            let time = player.playerTime(forNodeTime: nodeTime)
        else { return lastHead }
        return max(0, time.sampleTime)
    }

    /// `enter_track` (`player:3398`). The one place a track becomes the current
    /// one, whether it got there by running out, by `n`, by `⏎` or by a drag.
    private func enter(_ segment: Timeline.Segment) {
        currentVisit = segment.visit
        currentRow = segment.row
        status = nil
        if let index = visitHistory[segment.visit] { transport.settleHistory(at: index) }
        // §9's spectrum reset and §7's resume write hang here when they exist.
    }

    private func claimVisit(history: Int?) -> Int {
        let visit = nextVisit
        nextVisit += 1
        if let history { visitHistory[visit] = history }
        return visit
    }

    // MARK: - Restarting

    /// Every discontinuous move: `⏎`, `n`, `p`, a seek, a policy change that has
    /// been overtaken. Stop the node, throw away what was queued, rebuild the
    /// timeline from zero and start again.
    private func restart(row: Int, offsetSeconds: Double, historyIndex: Int?) {
        guard urls.indices.contains(row), let feeder else { return }

        player.stop()
        timeline.reset()
        offlineHead = 0
        lastHead = 0
        stopAt = nil
        endedAtFrame = nil
        feedEnded = false
        visitHistory = visitHistory.filter { $0.key == currentVisit }

        let visit = claimVisit(history: historyIndex)
        feedRow = row
        feedVisit = visit
        currentRow = row
        currentVisit = visit

        let frame = AVAudioFramePosition((offsetSeconds * canonical.sampleRate).rounded())
        do {
            if feeder.isOpen && feeder.row == row {
                // Already the open file — a seek inside it, not a reopen. The
                // ordinary case for `p` in the first three seconds and for the
                // arrow keys.
                try feeder.seek(toFrame: frame)
            } else {
                try feeder.open(row: row, url: urls[row], atFrame: frame)
                trackOpenCount += 1
            }
        } catch {
            plant(failure: error, row: row)
            observe()
            return
        }

        fill()
        if mode == .playing { player.play() }
        observe()
    }

    // MARK: - §6.2 and §6.3

    private func finish() {
        mode = .finished
        status = .endOfAlbum
        endedAtFrame = timeline.end
        player.stop()
        // §6.2 also clears the resume entry — a record heard to the end is not a
        // record you are partway through. §7 is not written; this is where it
        // goes (`player:3493`).
    }

    /// The failure is *planted*, not applied. The feeder is two seconds ahead of
    /// the ear, so it finds an unopenable file before that file would have been
    /// heard; saying STOPPED now would put the label on a panel that is still
    /// playing the previous track.
    private func plant(failure: any Error, row: Int) {
        stopAt = timeline.end
        stopRow = row
        stopReason = (failure as? PlaybackFailure)?.reason ?? AudioSourceOpener.shortened(failure)
    }

    /// **The first failure stops the record where it stands** (`player:3285`).
    /// Left alone the engine walks straight on to the next entry, which for a
    /// record whose files have all become unreadable is fifty failures in two
    /// seconds and a panel saying END OF ALBUM — the same thing it says when a
    /// record has simply finished.
    private func applyFailure() {
        stopAt = nil
        player.stop()
        feeder?.close()
        feedEnded = true
        // The panel stays on the track that actually stopped (`player:2811`) —
        // which is the one the message is about, and the one `⏎ TO TRY ANOTHER`
        // is asking you to move off.
        currentRow = stopRow
        mode = .stopped
        status = failureStatus()
    }

    /// The **whole record is stat-ed**, not the failing file guessed at — the
    /// interesting case is not a bad rip, it is a whole unpacked album
    /// disappearing underneath itself (`player:3292`).
    private func failureStatus() -> Status {
        let manager = FileManager.default
        let missing = urls.count { !manager.fileExists(atPath: $0.path) }
        guard missing == 0 else {
            return .tracksGone(missing: missing, of: urls.count, source: sourceKind)
        }
        return .cannotRead(reason: stopReason)
    }

    // MARK: - Offline rendering, for the suites

    /// A capture of the graph's own output. Not a re-decode and not a
    /// simulation: `enableManualRenderingMode` runs the *same* engine, the same
    /// player node and the same buffers, with the clock replaced. What comes out
    /// of here is what would have gone to the speakers.
    public struct Capture: Sendable {
        public var channels: [[Float]]
        public var sampleRate: Double
        public var frames: Int { channels.first?.count ?? 0 }
        public var seconds: Double { Double(frames) / sampleRate }
    }

    public enum CaptureFailure: Error { case notOffline }

    public func render(seconds: Double) throws -> Capture {
        guard offline, running else { throw CaptureFailure.notOffline }
        var out = [[Float]](repeating: [], count: Int(canonical.channelCount))
        var remaining = AVAudioFrameCount(max(0, seconds) * canonical.sampleRate)
        let block = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: engine.manualRenderingMaximumFrameCount
        )!

        while remaining > 0 {
            pump()
            let wanted = min(remaining, engine.manualRenderingMaximumFrameCount)
            let status = try engine.renderOffline(wanted, to: block)
            guard status == .success, block.frameLength > 0 else { break }
            let rendered = block.frameLength
            if player.isPlaying { offlineHead += AVAudioFramePosition(rendered) }
            append(block, to: &out)
            remaining -= rendered
        }
        return Capture(channels: out, sampleRate: canonical.sampleRate)
    }

    /// Play the record out and hand back everything it produced, trimmed to the
    /// last frame that was actually music. `limitSeconds` is the runaway guard,
    /// not the length.
    public func renderToEnd(limitSeconds: Double) throws -> Capture {
        guard offline, running else { throw CaptureFailure.notOffline }
        var out = [[Float]](repeating: [], count: Int(canonical.channelCount))
        var budget = AVAudioFrameCount(limitSeconds * canonical.sampleRate)
        let block = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: engine.manualRenderingMaximumFrameCount
        )!

        while budget > 0 {
            pump()
            if mode == .finished || mode == .stopped { break }
            let wanted = min(budget, engine.manualRenderingMaximumFrameCount)
            let status = try engine.renderOffline(wanted, to: block)
            guard status == .success, block.frameLength > 0 else { break }
            let rendered = block.frameLength
            if player.isPlaying { offlineHead += AVAudioFramePosition(rendered) }
            append(block, to: &out)
            budget -= rendered
        }

        // The last render block overshoots the end of the music by up to its own
        // length, and that overshoot is silence the graph invented. Measuring a
        // seam is measuring what the *feeder* produced, so the invented part is
        // cut off rather than counted.
        if let end = endedAtFrame, Int(end) <= (out.first?.count ?? 0) {
            for channel in out.indices { out[channel].removeLast(out[channel].count - Int(end)) }
        }
        return Capture(channels: out, sampleRate: canonical.sampleRate)
    }

    private func append(_ buffer: AVAudioPCMBuffer, to out: inout [[Float]]) {
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        for channel in out.indices where channel < Int(buffer.format.channelCount) {
            out[channel].append(contentsOf: UnsafeBufferPointer(start: data[channel], count: frames))
        }
    }

    // MARK: -

    private static let readAheadSeconds: Double = 2
    private var chunkFrames: AVAudioFrameCount {
        AVAudioFrameCount(canonical.sampleRate * 0.25)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
