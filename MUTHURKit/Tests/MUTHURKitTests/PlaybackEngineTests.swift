import AVFoundation
import Foundation
import Testing

@testable import MUTHURKit

/// §6.1a, §6.2, §6.3 and §6.4 — the deck's behaviour, played out offline.
///
/// These run the real graph with the clock replaced, so "play a record to the
/// end" is a hundred milliseconds rather than four minutes, and every assertion
/// is about what the engine actually did rather than about what it was asked to.
@Suite("§6 The deck")
struct PlaybackEngineTests {

    static let rate: Double = 44100

    /// A record of `durations` seconds of tone. Short on purpose: nothing here is
    /// measuring a waveform, and a two-second track plays out in milliseconds.
    private func tones(_ durations: [Int], in folder: borrowing ToneFolder) throws -> Record {
        var entries: [(URL, Int)] = []
        for (index, seconds) in durations.enumerated() {
            let url = folder.file("t\(index).wav")
            try Seam.writeTone(
                to: url, rate: Self.rate, frequency: 441,
                frames: Int(Self.rate) * seconds, startTime: 0
            )
            entries.append((url, seconds))
        }
        return recordOf(entries, label: "deck")
    }

    // MARK: - §6.1 The transport, through the engine

    /// The row is not assumed anywhere — it is read back off the timeline, which
    /// is the same route a track that simply ran out arrives by.
    @Test("Playing a record end to end walks every row and finishes")
    func playsThrough() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([1, 1, 1], in: folder))
        await engine.pick(row: 0)

        let capture = try await engine.renderToEnd(limitSeconds: 20)
        #expect(capture.frames == Int(Self.rate) * 3)

        let state = await engine.state
        #expect(state.mode == .finished)
        #expect(state.row == 2)
    }

    @Test("`n` walks forward and `p` walks back")
    func nextAndPrevious() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([4, 4, 4], in: folder))

        await engine.pick(row: 0)
        _ = try await engine.render(seconds: 0.2)
        #expect(await engine.state.row == 0)

        await engine.next()
        _ = try await engine.render(seconds: 0.2)
        #expect(await engine.state.row == 1)

        // Under three seconds in, so this is the previous track and not a
        // restart of this one.
        await engine.previous()
        _ = try await engine.render(seconds: 0.2)
        #expect(await engine.state.row == 0)
    }

    /// `p` after three seconds restarts rather than going back — measured by the
    /// position falling to nothing while the row stays put.
    @Test("`p` after three seconds restarts the track")
    func previousRestartsLateInTheTrack() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([10, 10], in: folder))

        await engine.pick(row: 1, offset: 6)
        _ = try await engine.render(seconds: 0.2)
        #expect(await engine.state.positionInTrack > 3)

        await engine.previous()
        _ = try await engine.render(seconds: 0.1)
        let state = await engine.state
        #expect(state.row == 1, "`p` late in a track went to the previous one")
        #expect(state.positionInTrack < 1)
    }

    /// A paused deck is waiting for you. `n` while paused moves the track and
    /// leaves it waiting — it does not start playing behind your back.
    @Test("`␣` pauses and resumes; STOPPED and FINISHED are not paused states")
    func pauseRules() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([4, 4], in: folder))

        // Nothing to pause before anything is playing.
        await engine.togglePause()
        #expect(await engine.state.mode == .stopped)

        await engine.pick(row: 0)
        _ = try await engine.render(seconds: 0.1)
        #expect(await engine.state.mode == .playing)

        await engine.togglePause()
        #expect(await engine.state.mode == .paused)
        await engine.next()
        #expect(await engine.state.mode == .paused, "`n` unpaused the deck")

        await engine.togglePause()
        #expect(await engine.state.mode == .playing)
    }

    /// REPEAT TRACK is the engine's own loop: the decoder rewinds and the file is
    /// not reopened. `trackOpenCount` is how that is told apart from a reload.
    @Test("REPEAT TRACK loops without reopening the file")
    func repeatTrackDoesNotReopen() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([1, 1], in: folder))

        await engine.cycleRepeat()  // album
        await engine.cycleRepeat()  // track
        #expect(await engine.state.repeatMode == .track)

        await engine.pick(row: 0)
        let opens = await engine.trackOpenCount
        // Four times round a one-second track. The limit is the length here, not
        // a runaway guard — under REPEAT TRACK the record never ends.
        _ = try await engine.render(seconds: 4)

        #expect(await engine.state.row == 0)
        #expect(await engine.state.mode == .playing)
        #expect(
            await engine.trackOpenCount == opens,
            "the loop reopened the file instead of rewinding the decoder"
        )
    }

    @Test("Starting a track clears the status line")
    func startingATrackClearsStatus() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([1, 1], in: folder))

        await engine.toggleShuffle()
        #expect(await engine.state.status == .shuffle(true))

        await engine.pick(row: 1)
        _ = try await engine.render(seconds: 0.1)
        #expect(await engine.state.status == nil)
    }

    @Test("The status line says what was just switched")
    func statusMessages() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([1, 1], in: folder))

        await engine.toggleShuffle()
        #expect(await engine.state.status?.text == "▪ SHUFFLE ON")
        await engine.toggleShuffle()
        #expect(await engine.state.status?.text == "▪ SHUFFLE OFF")

        await engine.cycleRepeat()
        #expect(await engine.state.status?.text == "▪ REPEAT ALBUM")
        await engine.cycleRepeat()
        #expect(await engine.state.status?.text == "▪ REPEAT TRACK")
        await engine.cycleRepeat()
        #expect(await engine.state.status?.text == "▪ REPEAT OFF")
    }

    // MARK: - §6.1a Volume (D1)

    /// The settled level, measured after the mixer's own ramp.
    ///
    /// A gain change is ramped rather than stepped, which is what keeps turning a
    /// record down from clicking — so a measurement taken across the change sees
    /// the level it was at a moment ago, and the honest window is the far end.
    private func settledPeak(of capture: PlaybackEngine.Capture) -> Float {
        let tail = capture.channels[0].suffix(capture.frames / 4)
        return tail.map(abs).max() ?? 0
    }

    /// Its **own** output gain. The proof that it is ours and not the system's is
    /// that it is visible in the capture — the samples the graph produced are
    /// scaled, which a system-level slider could not do.
    @Test("The gain is the engine's own, and it is in the samples")
    func volumeScalesTheOutput() async throws {
        let folder = try ToneFolder()

        func level(_ setting: Float) async throws -> Float {
            let engine = PlaybackEngine(offline: true)
            try await engine.load(tones([2], in: folder))
            await engine.setVolume(setting)
            await engine.pick(row: 0)
            return settledPeak(of: try await engine.render(seconds: 1))
        }

        let full = try await level(1)
        let half = try await level(0.5)
        #expect(full > 0.9)
        #expect(abs(half - full / 2) < 0.01, "half volume settled at \(half) against \(full)")
    }

    @Test("Mute is a state, not a level of zero")
    func muteIsAState() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([2], in: folder))
        await engine.setVolume(0.7)
        await engine.toggleMute()
        await engine.pick(row: 0)

        let capture = try await engine.render(seconds: 1)
        #expect(settledPeak(of: capture) == 0)

        // The level is still 0.7 — muted, not turned down, which is the whole
        // point: "no sound and I do not know why" is the question the panel
        // exists to answer.
        let state = await engine.state
        #expect(state.muted)
        #expect(state.volume == 0.7)

        // And unmuting comes back to where it was, rather than to full.
        await engine.toggleMute()
        #expect(await engine.state.volume == 0.7)
        #expect(await engine.state.muted == false)
        let back = try await engine.render(seconds: 1)
        #expect(abs(settledPeak(of: back) - 0.7) < 0.01)
    }

    @Test("The level clamps to 0…1")
    func volumeClamps() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([1], in: folder))

        await engine.setVolume(4)
        #expect(await engine.state.volume == 1)
        await engine.setVolume(-1)
        #expect(await engine.state.volume == 0)
        await engine.nudgeVolume(by: 0.1)
        #expect(abs(await engine.state.volume - 0.1) < 1e-6)
    }

    // MARK: - §6.2 End of album

    @Test("At the end: FINISHED, the sentence, and both meters parked at full")
    func endOfAlbum() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([1, 2], in: folder))
        await engine.pick(row: 0)
        _ = try await engine.renderToEnd(limitSeconds: 20)

        let state = await engine.state
        #expect(state.mode == .finished)
        #expect(state.mode.label == "FINISHED")
        #expect(state.status == .endOfAlbum)
        #expect(
            state.status?.text == "▪ END OF ALBUM — PRESS Q TO QUIT, ⏎ TO PLAY A TRACK"
        )
        // Full, not the fraction-before-the-end the last position report carried.
        #expect(state.positionInTrack == state.trackDuration)
        #expect(state.positionInRecord == state.recordDuration)
        #expect(state.recordDuration == 3)
    }

    @Test("`⏎` after the end plays again and takes the label off")
    func pickAfterTheEnd() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([1, 1], in: folder))
        await engine.pick(row: 0)
        _ = try await engine.renderToEnd(limitSeconds: 20)
        #expect(await engine.state.mode == .finished)

        await engine.pick(row: 0)
        _ = try await engine.render(seconds: 0.1)
        let state = await engine.state
        #expect(state.mode == .playing)
        #expect(state.status == nil)
        #expect(state.row == 0)
    }

    // MARK: - §6.3 A track that will not open

    /// Anything with an audio extension and no audio in it. §6.3 is about a track
    /// that will not open, and this is the cheapest honest one.
    private func rubbish(_ url: URL) throws {
        try Data("NOT AUDIO, AND NEVER WAS".utf8).write(to: url)
    }

    @Test("The first failure stops the record where it stands")
    func failureStopsTheRecord() async throws {
        let folder = try ToneFolder()
        let record = try tones([1, 1, 1], in: folder)
        try rubbish(record.tracks[1].url)

        let engine = PlaybackEngine(offline: true)
        try await engine.load(record)
        await engine.pick(row: 0)
        _ = try await engine.renderToEnd(limitSeconds: 20)

        let state = await engine.state
        // STOPPED, not PAUSED: a deck that is paused is waiting for you and this
        // one is not. And not FINISHED either — "you have heard this" and "this
        // is gone" are the difference the panel exists to draw.
        #expect(state.mode == .stopped)
        #expect(state.mode.label == "STOPPED")
        // The panel stays on the track that actually stopped, which is the one
        // the message is about.
        #expect(state.row == 1)
        // It stopped there rather than walking on to row 2.
        #expect(state.status != .endOfAlbum)
    }

    @Test("Files present: CANNOT READ THIS TRACK, with what the decoder said")
    func failureWhenTheFileIsPresent() async throws {
        let folder = try ToneFolder()
        let record = try tones([1, 1], in: folder)
        try rubbish(record.tracks[1].url)

        let engine = PlaybackEngine(offline: true)
        try await engine.load(record)
        await engine.pick(row: 0)
        _ = try await engine.renderToEnd(limitSeconds: 20)

        let text = try #require(await engine.state.status?.text)
        #expect(text.hasPrefix("▪ CANNOT READ THIS TRACK · "))
        #expect(text.hasSuffix(" — STOPPED HERE, ⏎ TO TRY ANOTHER"))
    }

    /// The interesting case is not a bad rip, it is a whole unpacked album
    /// disappearing underneath itself — so the **whole record is stat-ed** rather
    /// than the failing file guessed at.
    @Test("Files gone: N OF M TRACKS ARE NO LONGER ON DISK", arguments: [SourceKind.zip, .folder])
    func failureWhenTheFilesAreGone(source: SourceKind) async throws {
        let folder = try ToneFolder()
        let record = try tones([1, 1, 1], in: folder)

        let engine = PlaybackEngine(offline: true)
        try await engine.load(record, source: source)
        await engine.pick(row: 0)
        _ = try await engine.render(seconds: 0.1)

        // The album goes while it is playing, which is the case this box is for.
        for track in record.tracks.dropFirst() {
            try FileManager.default.removeItem(at: track.url)
        }
        _ = try await engine.renderToEnd(limitSeconds: 20)

        let state = await engine.state
        #expect(state.mode == .stopped)
        #expect(state.status == .tracksGone(missing: 2, of: 3, source: source))
        let text = try #require(state.status?.text)
        #expect(text.hasPrefix("▪ 2 OF 3 TRACKS ARE NO LONGER ON DISK"))
        if source == .zip {
            #expect(text.hasSuffix("— THE UNPACKED COPY IS GONE. Q, THEN PLAY IT AGAIN"))
        } else {
            #expect(text.hasSuffix("— STOPPED HERE"))
        }
    }

    /// Without the unpause, choosing another track after a bad one looks like a
    /// second failure: the row changes and nothing plays.
    @Test("Picking a track by hand clears the failure and takes off its pause")
    func pickClearsTheFailure() async throws {
        let folder = try ToneFolder()
        let record = try tones([1, 1, 1], in: folder)
        try rubbish(record.tracks[1].url)

        let engine = PlaybackEngine(offline: true)
        try await engine.load(record)
        await engine.pick(row: 0)
        _ = try await engine.renderToEnd(limitSeconds: 20)
        #expect(await engine.state.mode == .stopped)

        await engine.pick(row: 2)
        let capture = try await engine.render(seconds: 0.3)

        let state = await engine.state
        #expect(state.mode == .playing, "the failure's pause was left on")
        #expect(state.status == nil)
        #expect(state.row == 2)
        #expect((capture.channels[0].map(abs).max() ?? 0) > 0.5, "the row changed but nothing played")
    }

    // MARK: - §6.4 The meters as controls

    @Test("The album meter's arithmetic: the last row starting at or before the point")
    func albumMeterArithmetic() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([3, 4, 5], in: folder))

        var target = await engine.rowAndOffset(atRecordSeconds: 0)
        #expect(target.row == 0 && target.offset == 0)

        target = await engine.rowAndOffset(atRecordSeconds: 3)
        #expect(target.row == 1 && target.offset == 0)

        target = await engine.rowAndOffset(atRecordSeconds: 8.5)
        #expect(target.row == 2 && abs(target.offset - 1.5) < 1e-9)

        // Clamped at both ends — the pointer leaves the meter and the needle
        // does not leave the record.
        target = await engine.rowAndOffset(atRecordSeconds: -40)
        #expect(target.row == 0 && target.offset == 0)
        target = await engine.rowAndOffset(atRecordSeconds: 900)
        #expect(target.row == 2 && abs(target.offset - 5) < 1e-9)
    }

    /// D2. A drag crosses boundaries freely, and the position that takes effect
    /// is the one it **finished** on.
    @Test("A drag the length of the record opens one track, not forty")
    func dragOpensOneTrack() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        // Eight eight-second tracks, and the drag lands well clear of a
        // boundary — otherwise the read-ahead legitimately opens the *next*
        // track too and the count stops being about the drag.
        try await engine.load(tones([8, 8, 8, 8, 8, 8, 8, 8], in: folder))
        await engine.pick(row: 0)
        _ = try await engine.render(seconds: 0.1)

        let opens = await engine.trackOpenCount
        // A pointer crossing the whole record: a position reported per cell, and
        // none of them acted on.
        for step in 0..<128 {
            await engine.seek(inRecord: Double(step) * 0.5, dragging: true)
        }
        #expect(
            await engine.trackOpenCount == opens,
            "a drag opened files while the pointer was still down"
        )

        // The lift. Row 6 runs 48…56 s, so this is four seconds in.
        await engine.seek(inRecord: 52, dragging: false)
        _ = try await engine.render(seconds: 0.2)

        let state = await engine.state
        let opened = await engine.trackOpenCount - opens
        #expect(state.row == 6, "the drag landed in row \(state.row)")
        #expect(abs(state.positionInRecord - 52) < 0.5)
        #expect(opened == 1, "the drag opened \(opened) files instead of one")
    }

    /// The pending-offset rule proper: an offset into another track is applied by
    /// the act of opening it, so there is no moment at which the offset exists
    /// and the new track does not. What comes out is the *new* track at the
    /// offset — never the old one seeked to a position that means nothing in it.
    @Test("A seek into another track lands in that track, at that offset")
    func seekAcrossABoundaryLandsInTheNewTrack() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([5, 5, 5], in: folder))
        await engine.pick(row: 0)
        _ = try await engine.render(seconds: 0.1)

        await engine.seek(inRecord: 12)
        _ = try await engine.render(seconds: 0.1)

        let state = await engine.state
        #expect(state.row == 2)
        #expect(abs(state.positionInTrack - 2) < 0.3, "landed at \(state.positionInTrack)")
        #expect(abs(state.positionInRecord - 12) < 0.3)
    }

    /// An arrow key is relative, and relative to **this track** — 30 seconds back
    /// from ten seconds in is the top of the track you are on, not ten seconds
    /// into the one before it. That is the difference between an arrow key and
    /// the album meter, and both exist.
    @Test("`←` and `→` are relative to the track, not to the record")
    func nudgeIsRelativeToTheTrack() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([20, 20, 20], in: folder))
        await engine.pick(row: 1, offset: 10)
        _ = try await engine.render(seconds: 0.1)

        await engine.nudge(by: -30)
        _ = try await engine.render(seconds: 0.1)
        var state = await engine.state
        #expect(state.row == 1, "`⇧←` fell back into the previous track")
        #expect(state.positionInTrack < 0.5)

        await engine.nudge(by: 5)
        _ = try await engine.render(seconds: 0.1)
        state = await engine.state
        #expect(state.row == 1)
        #expect(abs(state.positionInTrack - 5) < 0.3)
    }

    /// `→` past the end of a track runs that track out, which is what mpv's
    /// relative seek did for the script (`player:2690`) and what a deck does.
    /// Worth pinning because the clamp makes it look like it might not.
    @Test("`→` past the end of a track runs it out")
    func nudgePastTheEndAdvances() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([4, 4], in: folder))
        await engine.pick(row: 0, offset: 2)
        _ = try await engine.render(seconds: 0.1)

        await engine.nudge(by: 30)
        _ = try await engine.render(seconds: 0.3)
        var state = await engine.state
        #expect(state.row == 1)
        #expect(state.positionInTrack < 0.5)

        // And off the end of the last track it is the end of the record, by the
        // same route a track running out on its own takes.
        await engine.nudge(by: 30)
        _ = try await engine.render(seconds: 0.3)
        state = await engine.state
        #expect(state.mode == .finished)
        #expect(state.status == .endOfAlbum)
    }

    @Test("The track meter seeks within the track")
    func trackMeterSeeks() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([8, 8], in: folder))
        await engine.pick(row: 1)
        _ = try await engine.render(seconds: 0.1)

        await engine.seekInTrack(to: 5)
        _ = try await engine.render(seconds: 0.1)

        let state = await engine.state
        #expect(state.row == 1)
        #expect(abs(state.positionInTrack - 5) < 0.3)
        // The album meter follows it, because it is one position in one record.
        #expect(abs(state.positionInRecord - 13) < 0.3)
    }

    /// A seek out of STOPPED or FINISHED starts the deck — the meter is a
    /// control, and a control that leaves the transport where it found it reads
    /// as broken.
    @Test("Seeking a finished record starts it playing again")
    func seekAfterTheEndPlays() async throws {
        let folder = try ToneFolder()
        let engine = PlaybackEngine(offline: true)
        try await engine.load(tones([1, 1], in: folder))
        await engine.pick(row: 0)
        _ = try await engine.renderToEnd(limitSeconds: 20)
        #expect(await engine.state.mode == .finished)

        await engine.seek(inRecord: 0.5)
        let capture = try await engine.render(seconds: 0.2)
        #expect(await engine.state.mode == .playing)
        #expect(await engine.state.status == nil)
        #expect((capture.channels[0].map(abs).max() ?? 0) > 0.5)
    }
}
