import AVFoundation
import Foundation

/// §9, assembled: samples in one end, sixteen columns out the other.
///
/// Two clocks, and they are the script's two clocks (`player:2661`,
/// `player:2878`):
///
/// - **ten a second**, the rate levels are measured at, which is `SPEC_HZ` and
///   is why the window is `rate / 10` samples long;
/// - **twenty a second**, the rate the columns are stepped at, which is
///   `TICK_HZ`. The script indexes a ten-a-second table by position once per
///   tick, so every level is stepped twice and the trail falls two eighths a
///   tick — forty a second, the whole height of a column in one.
///
/// Keeping them apart matters: fold them into one and the trails fall at half
/// the rate they should, which is not a subtle difference on screen.
///
/// `hear` is called from the render thread and `frame` from whatever draws, so
/// everything behind both sits under a lock. Nothing here allocates on the audio
/// thread after the first buffer of a format.
public final class Analyser: @unchecked Sendable {

    private let lock = NSLock()

    private var spectrum: Spectrum?
    private var scales = [BandScale](repeating: BandScale(), count: Bands.count)
    private var columns = AnalyserColumns()

    /// Deinterleaved, one plane per channel, filled until there is a whole
    /// window.
    private var pending: [[Float]] = []
    private var filled = 0

    /// The most recent measurement. A frame takes the latest reading whether or
    /// not it is new, because the level clock is half the frame clock — which
    /// is exactly what indexing a table by position does.
    private var latest: [Int]?
    private var measured = [Double](repeating: Spectrum.floor, count: Bands.count)

    /// Frames since a window of actual sound went through. See `isIdle`.
    private var quiet = Int.max

    /// Whether anything is feeding this at all. The script asks whether there is
    /// a table for this track and draws the waves when there is not
    /// (`player:2884`); the same question here is whether there is a tap, since
    /// a tap that exists always has something to say within a tenth of a second
    /// of the deck making a sound.
    private var tapped = false

    /// The fallback's own clock, so the waves travel at the tick rate.
    private var synthFrame = 0

    public init() {}

    // MARK: - What the panel reads

    /// The grid, top row first.
    ///
    /// Idle draws the floor row rather than the columns, and the columns are
    /// left exactly where they were rather than run down to nothing — the
    /// script stops calling `spec_advance` altogether when the deck is quiet, so
    /// a record picked up again carries on from where it stopped
    /// (`player:2671`).
    public var grid: [[AnalyserColumns.Cell]] {
        lock.lock()
        defer { lock.unlock() }
        return isIdleLocked ? AnalyserColumns.idle : columns.grid
    }

    /// The raw column state, for anything that wants to draw it some other way.
    public var state: AnalyserColumns {
        lock.lock()
        defer { lock.unlock() }
        return columns
    }

    /// The levels the last window measured, in dBFS. The numbers behind the
    /// picture, which is what makes §9 testable with no window open.
    public var levels: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return measured
    }

    /// **Is anything coming out**, rather than is it paused (`player:740`).
    ///
    /// A record that has finished, a track that would not open, a buffer still
    /// filling — all of them are silence, and columns dancing over silence is
    /// the panel lying about what you are hearing. The test is therefore made on
    /// the signal and not on the deck's mode: either no window has arrived at
    /// all, or the ones that have are at the floor.
    ///
    /// Four frames is two level periods, which is the shortest gap that cannot
    /// simply be a window that has not finished filling.
    public var isIdle: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isIdleLocked
    }

    private var isIdleLocked: Bool { tapped && quiet > 4 }

    // MARK: - The frame clock

    /// One tick of the panel: twenty a second, and every column moves.
    ///
    /// With a tap on something, the columns go where the last measurement says.
    /// With nothing tapped, they travel — a deck that is running should look
    /// like one, and the waves never claim to be the music.
    public func frame() {
        lock.lock()
        defer { lock.unlock() }

        if quiet < Int.max { quiet += 1 }
        synthFrame += 1

        guard tapped else {
            columns.synthesise(frame: synthFrame)
            return
        }
        guard !isIdleLocked else { return }
        // Between a track change and its first window there is nothing to say,
        // and the honest thing to say it with is nought — the columns have just
        // been reset and stepping them to zero lets the trails come down rather
        // than freezing them mid-air.
        columns.step(latest ?? [Int](repeating: 0, count: Bands.count))
    }

    /// A new track: the columns, and only the columns.
    ///
    /// Heights carried across a track change read as a glitch, so they go
    /// (`player:3389`). **The scales stay** (D33). The script can afford to
    /// start each track's scale from nothing because it has the whole track
    /// before it draws anything; this cannot, and the previous track is by far
    /// the best evidence available about this one — same record, same room, same
    /// mastering. Measured, it takes side two's opening from eleven eighths out
    /// to four. It does nothing for track one, which is what the seed is for.
    public func newTrack() {
        lock.lock()
        defer { lock.unlock() }
        columns.reset()
        latest = nil
        filled = 0
        measured = [Double](repeating: Spectrum.floor, count: Bands.count)
    }

    /// A new record, which is where the scales *do* go — another record's scale
    /// is another record's scale, and this one is owed a cold start.
    public func newRecord() {
        lock.lock()
        defer { lock.unlock() }
        for band in scales.indices { scales[band].reset() }
        columns.reset()
        latest = nil
        filled = 0
        measured = [Double](repeating: Spectrum.floor, count: Bands.count)
    }

    // MARK: - Hearing

    /// One buffer off the tap. Float32, interleaved or not, any rate.
    public func hear(_ buffer: AVAudioPCMBuffer) {
        let frames = Int(buffer.frameLength)
        guard frames > 0, let channelData = buffer.floatChannelData else { return }
        let format = buffer.format
        let channels = Int(format.channelCount)
        let interleaved = format.isInterleaved
        let stride = interleaved ? channels : 1

        lock.lock()
        defer { lock.unlock() }

        tapped = true
        prepare(rate: format.sampleRate, channels: channels)
        guard let spectrum else { return }

        var consumed = 0
        while consumed < frames {
            let take = min(spectrum.hop - filled, frames - consumed)
            for channel in 0..<channels {
                let source = channelData[interleaved ? 0 : channel]
                let offset = consumed * stride + (interleaved ? channel : 0)
                for index in 0..<take {
                    pending[channel][filled + index] = source[offset + index * stride]
                }
            }
            filled += take
            consumed += take
            if filled == spectrum.hop { measure(spectrum) }
        }
    }

    /// The format is learned off the first buffer and re-learned if it changes.
    /// Building the transform costs a table of sines and sixteen filter
    /// responses; doing it once per format is the point of keeping it here.
    private func prepare(rate: Double, channels: Int) {
        if let spectrum, spectrum.rate == rate, pending.count == channels { return }
        let fresh = Spectrum(rate: rate)
        spectrum = fresh
        pending = (0..<channels).map { _ in [Float](repeating: 0, count: fresh.hop) }
        filled = 0
    }

    /// One window: measure it, feed the sixteen scales, and turn it into the
    /// heights the next frame will step to.
    private func measure(_ spectrum: Spectrum) {
        filled = 0
        let levels = spectrum.levels(pending)
        measured = levels

        // Silence is a window at the floor in every band, and that is the whole
        // test. It is deliberately not "is the deck paused": a stopped record, a
        // failed track and a buffer that has not arrived all make exactly this
        // signal.
        guard levels.contains(where: { $0 > Spectrum.floor }) else { return }

        quiet = 0
        var heights = [Int](repeating: 0, count: Bands.count)
        for band in 0..<Bands.count {
            scales[band].observe(levels[band])
            heights[band] = scales[band].height(of: levels[band])
        }
        latest = heights
    }

    // MARK: - The tap

    /// Hang the analyser off a node.
    ///
    /// Any node, on purpose: the deck's own graph is not reachable from here and
    /// does not need to be, and a test that builds its own engine offline gets
    /// the identical path through the identical code. §6.1a — the analyser reads
    /// the signal *before* the gain — is a question about *which* node, and it
    /// is asked of `Play/`, not of here.
    ///
    /// The buffer size is a request rather than an instruction; the window is
    /// filled across buffers whatever size they turn out to be.
    public func tap(
        _ node: AVAudioNode, bus: AVAudioNodeBus = 0, bufferSize: AVAudioFrameCount = 4096
    ) {
        lock.lock()
        tapped = true
        lock.unlock()
        node.installTap(onBus: bus, bufferSize: bufferSize, format: nil) { [weak self] buffer, _ in
            self?.hear(buffer)
        }
    }

    public func untap(_ node: AVAudioNode, bus: AVAudioNodeBus = 0) {
        node.removeTap(onBus: bus)
        lock.lock()
        tapped = false
        lock.unlock()
    }
}
