import AppKit
import MUTHURKit
import MediaPlayer

/// §14 — the media keys, and what Control Center and the lock screen say is
/// playing.
///
/// **There is nothing to port here.** `player` is a bash TUI: it has no bundle,
/// no Dock tile and no way to be told that F8 was pressed while another window
/// was in front, so it never had this and could not have. Everything below is a
/// choice made for the native port under §14 rather than a reading of the
/// script, and the ones that were arguable are marked as mine where they occur.
///
/// **MediaPlayer stops here.** `MUTHURKit` is headless and stays headless — no
/// SwiftUI, no AppKit, no MediaPlayer anywhere under `MUTHURKit/Sources`. This
/// file takes values *out* of the kit (a `Record`, a `PlaybackEngine.State`, a
/// `Sleeve`) and turns them into a dictionary the system understands. The kit is
/// never told that a system framework exists, and the only thing that went the
/// other way was `PlaybackEngine.pause()`, which is a transport verb and not a
/// framework.
///
/// ## Why this does not push at 20 Hz
///
/// The panel is redrawn twenty times a second (`player:2661`). The Now Playing
/// widget is not a panel and must not be driven like one — the system does not
/// want a position every 50 ms, it wants a position, a rate and the time the two
/// were true, and it extrapolates the clock itself. So a full push happens when
/// something the widget actually displays changes, and a position push happens
/// only when the system's own extrapolation would have drifted more than
/// `tolerance` off the truth. In steady play that is never; on a seek it is
/// immediately. See `observe`.
@MainActor
final class NowPlaying {

    /// What a remote command does. Closures rather than a reference to the
    /// model, so that the thing being wired to a system singleton is a handful
    /// of verbs and not the whole panel.
    struct Transport {
        var play: () -> Void
        var pause: () -> Void
        var toggle: () -> Void
        var next: () -> Void
        var previous: () -> Void
        var seek: (Double) -> Void
    }

    /// How far out the widget's clock is allowed to get before the truth is
    /// pushed at it. One second: the smallest deliberate move in the program is
    /// `←`'s five (`player:2794`), so every real seek is well past this, and the
    /// drift of an undisturbed track never reaches it — including when the
    /// window is behind another window and the tick is running late, which is
    /// the case a plain "did the position jump?" test gets wrong.
    private static let tolerance = 1.0

    private var transport: Transport?

    /// What was last handed to the system, so an unchanged record is not pushed
    /// sixty thousand times an hour. Only the fields the widget draws.
    private struct Pushed: Equatable {
        var row: Int
        var mode: PlaybackEngine.Mode
        var title: String
        var artist: String
        var album: String
        var albumArtist: String
        var duration: Double
        var artwork: URL?
    }

    private var pushed: Pushed?
    /// The three numbers the system extrapolates its clock from, as they were at
    /// the moment they were pushed.
    private var pushedPosition = 0.0
    private var pushedRate = 0.0
    private var pushedAt = Date.distantPast

    // MARK: - The commands

    /// Called once. `MPRemoteCommandCenter` is a process-wide singleton and its
    /// targets accumulate, so adding these on every record change would end with
    /// one key press being handled four times.
    func bind(_ transport: Transport) {
        self.transport = transport
        let centre = MPRemoteCommandCenter.shared()

        // PLAY and PAUSE arrive as two different commands and must stay two
        // different verbs. Control Center decides which to send from the state
        // it last saw, and a PAUSE that arrives a moment stale would start the
        // record if it were wired to `␣`. That is what `PlaybackEngine.pause()`
        // is for.
        centre.playCommand.addTarget { [weak self] _ in self?.run { $0.play } ?? .commandFailed }
        centre.pauseCommand.addTarget { [weak self] _ in self?.run { $0.pause } ?? .commandFailed }
        // The one key on the keyboard, which really is a toggle.
        centre.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.run { $0.toggle } ?? .commandFailed
        }
        centre.nextTrackCommand.addTarget { [weak self] _ in self?.run { $0.next } ?? .commandFailed }
        centre.previousTrackCommand.addTarget { [weak self] _ in
            self?.run { $0.previous } ?? .commandFailed
        }

        // **Mine.** §14 asks for play/pause/next/previous and stops there, but
        // the widget draws a scrubber whether or not anything is listening, and
        // a scrubber that does nothing is worse than one that is absent. It goes
        // to the same place a click on the track meter goes (§6.4).
        centre.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let transport = self.transport,
                let event = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            let seconds = event.positionTime
            Task { @MainActor in transport.seek(seconds) }
            return .success
        }

        for command in [centre.playCommand, centre.pauseCommand, centre.togglePlayPauseCommand,
            centre.nextTrackCommand, centre.previousTrackCommand,
            centre.changePlaybackPositionCommand] {
            command.isEnabled = true
        }

        // Everything this program does not do, said out loud. An enabled command
        // with no target is a button the widget will draw and then swallow, and
        // "the app ignored me" is indistinguishable from "the app hung".
        // ±15 s in particular is not `←`/`→`: those are ∓5 and ∓30 and belong to
        // a keyboard, not to a transport that has no shift key.
        for command in [centre.skipForwardCommand, centre.skipBackwardCommand] {
            command.isEnabled = false
        }
        for command: MPRemoteCommand in [
            centre.seekForwardCommand, centre.seekBackwardCommand, centre.stopCommand,
            centre.changeRepeatModeCommand, centre.changeShuffleModeCommand,
            centre.changePlaybackRateCommand, centre.ratingCommand, centre.likeCommand,
            centre.dislikeCommand, centre.bookmarkCommand,
        ] {
            command.isEnabled = false
        }
    }

    /// A command handler, which is not guaranteed to arrive on the main thread.
    private func run(
        _ verb: (Transport) -> () -> Void
    ) -> MPRemoteCommandHandlerStatus {
        guard let transport else { return .commandFailed }
        let action = verb(transport)
        Task { @MainActor in action() }
        return .success
    }

    // MARK: - What is playing

    /// Called from the panel's own tick. Cheap on the ticks where nothing has
    /// changed, which is nearly all of them.
    func observe(record: Record?, state: PlaybackEngine.State, sleeve: Sleeve?) {
        guard let record, record.order.indices.contains(state.row) else {
            clear()
            return
        }
        let track = record.running[state.row]

        let now = Pushed(
            row: state.row,
            mode: state.mode,
            title: track.title,
            // The track's own artist where it has one, the record's otherwise —
            // the same fallback §10's artist column makes, and for the same
            // reason: on most records the two are the same string and printing
            // nothing would be printing a fact about the tagger.
            artist: track.artist.isEmpty ? record.albumArtist : track.artist,
            album: record.album,
            albumArtist: record.albumArtist,
            duration: Double(track.duration),
            artwork: sleeve?.url
        )

        // What the system's clock would be reading right now if nothing were
        // pushed at it. `pushedRate` is 0 while paused, so a paused deck drifts
        // by nothing and is never re-pushed.
        let extrapolated = pushedPosition + Date().timeIntervalSince(pushedAt) * pushedRate
        let drifted = abs(state.positionInTrack - extrapolated) > Self.tolerance

        guard pushed != now || drifted else { return }
        pushed = now
        push(now, position: state.positionInTrack)
    }

    /// Nothing on the deck. Both halves matter: an app that leaves a stale
    /// dictionary behind goes on being the Now Playing app for a record it is
    /// not playing, and the media keys keep coming here instead of going to
    /// whatever the user actually started next.
    func clear() {
        guard pushed != nil else { return }
        pushed = nil
        pushedRate = 0
        pushedPosition = 0
        pushedAt = .distantPast
        let centre = MPNowPlayingInfoCenter.default()
        centre.nowPlayingInfo = nil
        centre.playbackState = .stopped
    }

    private func push(_ item: Pushed, position: Double) {
        let rate: Double = item.mode == .playing ? 1 : 0
        pushedPosition = position
        pushedRate = rate
        pushedAt = Date()

        var info: [String: Any] = [
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.artist,
            MPMediaItemPropertyAlbumTitle: item.album,
            MPMediaItemPropertyAlbumArtist: item.albumArtist,
            MPMediaItemPropertyPlaybackDuration: item.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]

        if let url = item.artwork, let artwork = Self.artwork(at: url) {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        let centre = MPNowPlayingInfoCenter.default()
        centre.nowPlayingInfo = info
        centre.playbackState =
            switch item.mode {
            case .playing: .playing
            case .paused: .paused
            // FINISHED is the end of the record, not a deck someone stopped —
            // but to the system both are "not playing and not waiting", and
            // there is no third state to say it in.
            case .stopped, .finished: .stopped
            }
    }

    /// The cover, at whatever size the system asks for.
    ///
    /// **Mine, and the one that could go either way.** The panel draws the
    /// sleeve through `SleeveImage.quantise` — one phosphor, eight levels,
    /// because an amber CRT cannot show a red cover and a blue cover
    /// differently. Control Center is not an amber CRT. Handing it the
    /// quantised picture would be claiming the *record* is amber rather than
    /// that this *screen* is, and the lock screen would show a cover nobody
    /// pressed. So the system gets the picture as it is, and only the panel
    /// pretends.
    ///
    /// The request handler is called by the system, off the main actor, at a
    /// size it picks; `SleeveImage.decode` is a thumbnail decode straight to
    /// that size, so a 1500 px cover is never fully decoded to be shown at 64.
    nonisolated static func artwork(at url: URL) -> MPMediaItemArtwork? {
        guard let size = SleeveImage.pixelSize(of: url) else { return nil }
        return MPMediaItemArtwork(boundsSize: size) { requested in
            let side = max(requested.width, requested.height)
            guard side > 0,
                let image = SleeveImage.decode(url, side: side, scale: 1)
            else { return NSImage(size: requested) }
            return NSImage(
                cgImage: image, size: CGSize(width: image.width, height: image.height))
        }
    }
}
