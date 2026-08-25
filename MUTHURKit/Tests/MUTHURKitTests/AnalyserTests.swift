import AVFoundation
import Foundation
import Testing

@testable import MUTHURKit

/// §9 — the data path. Given a known tone, the right bands light up, and the
/// numbers coming out are numbers, not a picture.
@Suite("The analyser")
struct AnalyserTests {

    // MARK: - Tones

    /// One buffer of a sine at full scale, in the deck's own float format.
    static func tone(
        _ frequency: Double, seconds: Double = 1.0, rate: Double = 44100, channels: UInt32 = 2,
        amplitude: Float = 1.0
    ) -> AVAudioPCMBuffer {
        buffer(seconds: seconds, rate: rate, channels: channels) { index in
            amplitude * Float(sin(2 * .pi * frequency * Double(index) / rate))
        }
    }

    static func silence(seconds: Double = 1.0, rate: Double = 44100, channels: UInt32 = 2)
        -> AVAudioPCMBuffer
    {
        buffer(seconds: seconds, rate: rate, channels: channels) { _ in 0 }
    }

    static func buffer(
        seconds: Double, rate: Double, channels: UInt32, sample: (Int) -> Float
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: rate, channels: AVAudioChannelCount(channels)
        )!
        let frames = AVAudioFrameCount(rate * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for channel in 0..<Int(channels) {
            let plane = buffer.floatChannelData![channel]
            for index in 0..<Int(frames) { plane[index] = sample(index) }
        }
        return buffer
    }

    static func band(containing frequency: Double) -> Int {
        Bands.centres.enumerated().min {
            abs(log2($0.element / frequency)) < abs(log2($1.element / frequency))
        }!.offset
    }

    // MARK: - The bands

    @Test("Sixteen centres, even steps in octaves")
    func centres() {
        #expect(Bands.count == 16)
        #expect(Bands.centres.first == 40)
        #expect(Bands.centres.last == 16000)

        // Even in octaves, not in hertz: every step is the same ratio to within
        // the rounding the script's own list carries.
        // Sixteen centres over 8.6 octaves is 0.576 of an octave a step. The
        // list is written in whole hertz, and 40 → 59 is the step that rounding
        // moves furthest.
        let steps = zip(Bands.centres.dropFirst(), Bands.centres).map { log2($0 / $1) }
        let mean = steps.reduce(0, +) / Double(steps.count)
        #expect(abs(mean - log2(16000.0 / 40) / 15) < 0.001)
        for step in steps { #expect(abs(step - mean) < 0.02) }
    }

    @Test("The bandpass is flat at its centre and just over an octave wide")
    func filterShape() {
        for centre in Bands.centres {
            let peak = Bands.power(centre: centre, rate: 44100, at: centre)
            #expect(abs(peak - 1.0) < 0.02, "\(centre) Hz should pass its own centre whole")
        }

        // `w=1.1` octaves is measured between the half-power points, so the
        // edges land at −3 dB, which is a power of a half. Through the bottom
        // eleven bands they land there to a hundredth of a decibel and through
        // the twelfth to a fifth of one.
        //
        // Higher than that they stop landing there — the bilinear transform
        // compresses the top of the spectrum towards Nyquist, and by sixteen
        // kilohertz the low edge is a decibel and a half high and the high edge
        // two and a half low. That is not an error in the port. It is what the
        // biquad ffmpeg builds does, so it is what the script's own top band has
        // always been, and the top band is being asked to answer for everything
        // above eleven kilohertz regardless.
        for centre in Bands.centres where centre < 5000 {
            let low = centre / pow(2, Bands.width / 2)
            let high = centre * pow(2, Bands.width / 2)
            let tolerance = centre < 2000 ? 0.02 : 0.25
            let atLow = 10 * log10(Bands.power(centre: centre, rate: 44100, at: low) / 0.5)
            let atHigh = 10 * log10(Bands.power(centre: centre, rate: 44100, at: high) / 0.5)
            #expect(abs(atLow) < tolerance, "\(centre) Hz low edge is \(atLow) dB off −3")
            #expect(abs(atHigh) < tolerance, "\(centre) Hz high edge is \(atHigh) dB off −3")
        }
    }

    @Test("Neighbours overlap, so nothing falls in a gap")
    func filtersOverlap() {
        // Halfway between two centres, in octaves, both of them are still
        // hearing it — that is what the extra tenth of an octave buys.
        for index in 0..<(Bands.count - 1) {
            let between = sqrt(Bands.centres[index] * Bands.centres[index + 1])
            guard between < 18000 else { continue }
            let left = Bands.power(centre: Bands.centres[index], rate: 44100, at: between)
            let right = Bands.power(centre: Bands.centres[index + 1], rate: 44100, at: between)
            #expect(left > 0.25, "gap below \(between) Hz")
            #expect(right > 0.25, "gap above \(between) Hz")
        }
    }

    @Test("A band whose centre is past Nyquist is silent rather than folded back")
    func aboveNyquist() {
        #expect(Bands.power(centre: 16000, rate: 22050, at: 8000) == 0)
    }

    // MARK: - The measurement

    @Test("A full-scale sine reads −3 dB, which is what its RMS is")
    func fullScaleSine() {
        let analyser = Analyser()
        analyser.hear(Self.tone(1000))
        let levels = analyser.levels
        let lit = Self.band(containing: 1000)
        #expect(abs(levels[lit] - (-3.01)) < 0.5)
    }

    @Test("Halving the amplitude takes six decibels off it")
    func amplitudeIsDecibels() {
        let loud = Analyser()
        loud.hear(Self.tone(1000, amplitude: 1.0))
        let quiet = Analyser()
        quiet.hear(Self.tone(1000, amplitude: 0.5))

        let lit = Self.band(containing: 1000)
        #expect(abs((loud.levels[lit] - quiet.levels[lit]) - 6.02) < 0.3)
    }

    @Test("The right bands light up, and the columns fall away either side of them")
    func toneFindsItsBand() {
        // What a two-pole bandpass an octave and a tenth wide actually does,
        // measured off the coefficients: a neighbour is three decibels down, two
        // bands out is eight, three is twelve, five is nineteen. It is a gentle
        // skirt and it is meant to be — the overlap is the point, and sixteen
        // sharp filters would show sixteen unrelated columns instead of a
        // spectrum. These are floors with a couple of decibels of margin on
        // them, not the numbers themselves.
        for frequency in [88.0, 294.0, 976.0, 3237.0] {
            let analyser = Analyser()
            analyser.hear(Self.tone(frequency))
            let levels = analyser.levels
            let lit = Self.band(containing: frequency)

            #expect(levels[lit] > -6, "\(frequency) Hz did not light band \(lit)")
            #expect(
                levels.enumerated().max { $0.element < $1.element }!.offset == lit,
                "\(frequency) Hz was loudest somewhere other than band \(lit)"
            )
            for band in 0..<Bands.count where abs(band - lit) >= 3 {
                let down = abs(band - lit) >= 5 ? 12.0 : 6.0
                #expect(
                    levels[band] < levels[lit] - down,
                    "\(frequency) Hz leaked into band \(band) at \(levels[band]) dB"
                )
            }
        }
    }

    @Test("A neighbour is three decibels down, which is where the bands cross")
    func neighboursOverlapByHalf() {
        for frequency in [294.0, 976.0, 3237.0] {
            let analyser = Analyser()
            analyser.hear(Self.tone(frequency))
            let levels = analyser.levels
            let lit = Self.band(containing: frequency)
            for neighbour in [lit - 1, lit + 1] where neighbour >= 0 && neighbour < Bands.count {
                #expect(abs(levels[neighbour] - (levels[lit] - 3.2)) < 1.0)
            }
        }
    }

    @Test("Every band answers to its own centre and to nobody else's most")
    func everyBandAnswers() {
        for (index, centre) in Bands.centres.enumerated() {
            let analyser = Analyser()
            analyser.hear(Self.tone(centre))
            let levels = analyser.levels
            let loudest = levels.enumerated().max { $0.element < $1.element }!.offset
            #expect(loudest == index, "\(centre) Hz was loudest in band \(loudest)")
        }
    }

    @Test("Digital silence is floored, not read as the loudest thing there is")
    func silenceIsFloored() {
        let analyser = Analyser()
        analyser.hear(Self.silence())
        #expect(analyser.levels.allSatisfy { $0 == Spectrum.floor })
    }

    @Test("Ten windows a second, at any rate the file happens to be")
    func rowRateIsFixed() {
        for rate in [44100.0, 48000.0, 96000.0, 22050.0] {
            let spectrum = Spectrum(rate: rate)
            #expect(spectrum.hop == Int(rate) / 10)
        }
    }

    @Test("A 48 kHz tone reads the same as a 44.1 kHz one")
    func rateDoesNotChangeTheReading() {
        let cd = Analyser()
        cd.hear(Self.tone(1000, rate: 44100))
        let dat = Analyser()
        dat.hear(Self.tone(1000, rate: 48000))

        let lit = Self.band(containing: 1000)
        #expect(abs(cd.levels[lit] - dat.levels[lit]) < 0.5)
    }

    @Test("Both sides are measured, not one of them or their average")
    func bothChannels() {
        // The same tone in phase, and the same tone with one side inverted. A
        // downmix would cancel the second to nothing; a proper reading of both
        // channels gives the identical level, because the power is identical.
        let together = Analyser()
        together.hear(Self.tone(1000))

        let apart = Analyser()
        let buffer = Self.tone(1000)
        let right = buffer.floatChannelData![1]
        for index in 0..<Int(buffer.frameLength) { right[index] = -right[index] }
        apart.hear(buffer)

        let lit = Self.band(containing: 1000)
        #expect(abs(together.levels[lit] - apart.levels[lit]) < 0.01)
    }

    @Test("A window is filled across however many buffers it takes")
    func windowSpansBuffers() {
        let whole = Analyser()
        whole.hear(Self.tone(1000, seconds: 0.5))

        // The same half second, in pieces small enough that no one of them is a
        // window on its own.
        let pieces = Analyser()
        for _ in 0..<50 { pieces.hear(Self.tone(1000, seconds: 0.01)) }

        let lit = Self.band(containing: 1000)
        #expect(abs(whole.levels[lit] - pieces.levels[lit]) < 1.0)
    }

    // MARK: - The scale

    /// The next three are the *arithmetic* — `SPEC_WINDOW`, the two anchors,
    /// the 0.60 between them — and they are asked of an unseeded scale on
    /// purpose. The seed is an initial condition (D33) and not part of the sum;
    /// what these hold down is the sum, which is the script's and does not move.
    @Test("A band that does not move stays honestly flat a quarter of the way up")
    func minimumSpan() {
        var scale = BandScale(seeded: false)
        for _ in 0..<200 { scale.observe(-20) }
        let (lo, hi) = scale.bounds
        #expect(abs(hi - lo - BandScale.minimumSpan) < 0.001)
        #expect(scale.height(of: -20) == 10)
        #expect(10 * 4 == AnalyserColumns.top)
    }

    @Test("The anchors are the quarter and ninety marks, a quarter and six sevenths up")
    func percentileAnchors() {
        // A hundred readings spread evenly from −60 to −11 dB. The 25th
        // percentile is −50 and the 90th is −15, in half-decibel bins.
        var scale = BandScale(seeded: false)
        for step in 0..<100 { scale.observe(-60 + Double(step) * 0.5) }

        let quarter = scale.height(of: -50)
        let ninety = scale.height(of: -15)
        #expect(abs(quarter - AnalyserColumns.top / 4) <= 1)
        #expect(abs(ninety - AnalyserColumns.top * 6 / 7) <= 1)
    }

    /// The paragraph in §9 that says why the percentiles are there at all.
    @Test("A long thin tail into the gaps does not get the whole column")
    func theTailIsThrownAway() {
        // A modern master: most of its life within a few decibels of its own
        // ceiling, and a thin tail forty decibels down where the songs stop.
        var scale = BandScale()
        for _ in 0..<900 { scale.observe(Double.random(in: -8 ... -3)) }
        for _ in 0..<100 { scale.observe(Double.random(in: -70 ... -60)) }

        // Scaled to the extremes this record would sit pinned at the ceiling.
        // Scaled to its own quarter-to-ninety it uses the column.
        let loud = scale.height(of: -4)
        let ordinary = scale.height(of: -6)
        #expect(loud > ordinary)
        #expect(ordinary > AnalyserColumns.top / 4)
        #expect(loud <= AnalyserColumns.top)
        #expect(scale.height(of: -65) == 0)
    }

    @Test("Digital silence lands on the floor of the column")
    func floorIsFloor() {
        var scale = BandScale()
        for _ in 0..<500 { scale.observe(Double.random(in: -30 ... -10)) }
        #expect(scale.height(of: -90) == 0)
        // −inf and NaN are silence too, not the top of the column.
        #expect(scale.height(of: -.infinity) == 0)
        #expect(scale.height(of: .nan) == 0)
    }

    /// One reading is still not enough to know anything — what changed is what
    /// it says while it does not know (D33). It used to answer a quarter of the
    /// way up whatever the level was, which is a distribution it has not got.
    /// Now it says nothing at all, because the only thing it is entitled to
    /// assume is that the loud part has not arrived yet.
    @Test("One reading is not enough to know anything, and draws nothing")
    func firstReading() {
        var scale = BandScale(seeded: true)
        scale.observe(-24)
        let (lo, hi) = scale.bounds

        // Both anchors are still at the ceiling, so the scale is the minimum
        // span sitting at the top of the range rather than anywhere near −24.
        #expect(abs(hi - lo - BandScale.minimumSpan) < 0.001)
        #expect(lo > -3, "the cold scale has already come down to \(lo)")

        // A loud reading is a quiet one until something louder is heard, which
        // is the whole point: a fade-in cannot be drawn as a chorus. Nothing
        // short of full scale itself gets off the floor of a cold band, and that
        // is the cost of the prior as well as the reason for it — §18.21.
        #expect(scale.height(of: -24) == 0)
        #expect(scale.height(of: -3) == 0)
        #expect(scale.height(of: 0) > 0, "not even full scale reaches the cold scale")
    }

    /// **Not a new track** — that keeps the scale now, which is the other half
    /// of D33. This is what a new record does.
    @Test("A new record is a new scale, and it comes back at the ceiling")
    func scaleResets() {
        var scale = BandScale()
        for _ in 0..<500 { scale.observe(-6) }
        // A record that lives at −6 uses the column at −6. A band that never
        // moves gets the minimum span and sits honestly at the quarter mark,
        // which is `minimumSpan` doing exactly its job (`player:866`).
        #expect(scale.height(of: -6) >= AnalyserColumns.top / 4)

        scale.reset()
        let (lo, hi) = scale.bounds
        #expect(abs(hi - lo - BandScale.minimumSpan) < 0.001)
        // And on a record that has not been heard, the same level is nothing —
        // until this record says otherwise.
        #expect(scale.height(of: -6) == 0)
    }

    // MARK: - The columns

    @Test("Forty steps of travel: five rows of eight")
    func travel() {
        #expect(AnalyserColumns.top == 40)
        #expect(AnalyserColumns.rows == 5)
        #expect(AnalyserColumns.bands == 16)
    }

    @Test("A column jumps to its new level instantly; only the fall is slowed")
    func riseIsInstantFallIsNot() {
        var columns = AnalyserColumns()
        columns.step([Int](repeating: 40, count: 16))
        #expect(columns.height[0] == 40)
        #expect(columns.trail[0] == 40)

        // Straight to the floor, and the trail is left behind it.
        columns.step([Int](repeating: 0, count: 16))
        #expect(columns.height[0] == 0)
        #expect(columns.trail[0] == 38)
        #expect(columns.age[0] == 1)

        // Straight back to the top the moment the level says so.
        columns.step([Int](repeating: 40, count: 16))
        #expect(columns.height[0] == 40)
        #expect(columns.trail[0] == 40)
        #expect(columns.age[0] == 0)
    }

    @Test("The trail sinks two eighths a frame and never below the column")
    func trailFalls() {
        var columns = AnalyserColumns()
        columns.step([Int](repeating: 40, count: 16))
        for frame in 1...5 {
            columns.step([Int](repeating: 10, count: 16))
            #expect(columns.trail[0] == 40 - 2 * frame)
            #expect(columns.age[0] == frame)
        }
        // Twenty frames is a second, and a second is the whole column.
        for _ in 6...20 { columns.step([Int](repeating: 10, count: 16)) }
        #expect(columns.trail[0] == 10)
    }

    @Test("Filled cells are graded by row, not by band")
    func gradedByRow() {
        var columns = AnalyserColumns()
        // Every band at the ceiling: every cell in a row is the same shade, and
        // the rows differ.
        columns.step([Int](repeating: 40, count: 16))
        let grid = columns.grid
        for row in 0..<AnalyserColumns.rows {
            let shades = Set(
                grid[row].compactMap { cell -> AnalyserColumns.Shade? in
                    if case .fill(_, let shade) = cell { return shade }
                    return nil
                }
            )
            #expect(shades.count == 1)
        }
        #expect(AnalyserColumns.fillShade(row: 0) == .head)
        #expect(AnalyserColumns.fillShade(row: 4) == .deep)

        // The top is the brightest, so arriving there reads as arriving.
        let ladder = (0..<AnalyserColumns.rows).map { AnalyserColumns.fillShade(row: $0) }
        #expect(ladder == ladder.sorted())
    }

    @Test("A column short of a whole cell gets the eighths it has earned")
    func eighths() {
        var columns = AnalyserColumns()
        // Three eighths into the bottom row.
        columns.step([3] + [Int](repeating: 0, count: 15))
        #expect(columns.cells(row: 4)[0] == .fill(eighths: 3, shade: .deep))
        #expect(columns.cells(row: 3)[0] == .field)

        // A whole bottom row and one eighth of the next.
        columns.step([9] + [Int](repeating: 0, count: 15))
        #expect(columns.cells(row: 4)[0] == .fill(eighths: 8, shade: .deep))
        #expect(columns.cells(row: 3)[0] == .fill(eighths: 1, shade: .etch))
    }

    @Test("The trail dims with age, so it reads as the same light going out")
    func trailDims() {
        let ramp = (0...9).map { AnalyserColumns.trailShade(age: $0).0 }
        #expect(ramp == [.lit, .lit, .amber, .amber, .etch, .etch, .deep, .deep, .runout, .runout])
        // Monotonically darker, which is the whole point of it being a ramp.
        #expect(ramp == ramp.sorted())
        #expect(AnalyserColumns.trailShade(age: 99).0 == .runout)
    }

    @Test("A fast transient stays visible for longer than the tenth of a second it lasted")
    func transientOutlivesItself() {
        var columns = AnalyserColumns()
        columns.step([Int](repeating: 2, count: 16))
        columns.step([40] + [Int](repeating: 2, count: 15))
        // Gone from the signal on the very next frame.
        columns.step([Int](repeating: 2, count: 16))

        var framesVisible = 0
        while columns.trail[0] > 2 {
            let top = columns.cells(row: 0)[0]
            if case .trail = top { framesVisible += 1 }
            columns.step([Int](repeating: 2, count: 16))
        }
        // Nineteen frames at twenty a second is most of a second, for a peak
        // that was there for one.
        #expect(framesVisible >= 3)
        #expect(columns.trail[0] == 2)
    }

    @Test("The idle state is a floor row lit, not a blank panel")
    func idle() {
        let idle = AnalyserColumns.idle
        #expect(idle.count == AnalyserColumns.rows)
        #expect(idle[AnalyserColumns.rows - 1].allSatisfy { $0 == .floor })
        for row in 0..<(AnalyserColumns.rows - 1) {
            #expect(idle[row].allSatisfy { $0 == .field })
        }
    }

    @Test("Columns reset at every track change")
    func resetOnTrackChange() {
        var columns = AnalyserColumns()
        columns.step([Int](repeating: 40, count: 16))
        columns.reset()
        #expect(columns.height.allSatisfy { $0 == 0 })
        #expect(columns.trail.allSatisfy { $0 == 0 })
        #expect(columns.age.allSatisfy { $0 == 99 })
        #expect(columns.grid.allSatisfy { $0.allSatisfy { $0 == .field } })
    }

    // MARK: - The fallback

    @Test("Two waves at rates that do not divide into one another")
    func synth() {
        var columns = AnalyserColumns()
        var seen: Set<[Int]> = []
        for frame in 0..<200 {
            columns.synthesise(frame: frame)
            seen.insert(columns.height)
            #expect(columns.height.allSatisfy { $0 >= 0 && $0 <= AnalyserColumns.top })
        }
        // Six and six: the shorter loop is 96 frames and nothing under 200 of
        // them repeats often enough to be a pattern you can see.
        #expect(seen.count > 40)

        // And it does not sit still.
        var moved = 0
        var previous = columns.height
        for frame in 200..<240 {
            columns.synthesise(frame: frame)
            if columns.height != previous { moved += 1 }
            previous = columns.height
        }
        #expect(moved > 15)
    }

    @Test("With nothing tapped at all, the deck still looks like it is running")
    func fallbackWhenNothingIsTapped() {
        let analyser = Analyser()
        #expect(!analyser.isIdle)
        var seen: Set<[Int]> = []
        for _ in 0..<40 {
            analyser.frame()
            seen.insert(analyser.state.height)
        }
        #expect(seen.count > 10)
    }

    // MARK: - The two clocks, end to end

    @Test("It stops dead when there is no sound, and picks up where it stopped")
    func stopsDeadOnSilence() {
        let analyser = Analyser()
        analyser.hear(Self.tone(1000, seconds: 0.5))
        for _ in 0..<4 { analyser.frame() }
        #expect(!analyser.isIdle)
        let standing = analyser.state.height

        // Half a second of nothing coming out.
        analyser.hear(Self.silence(seconds: 0.5))
        for _ in 0..<6 { analyser.frame() }
        #expect(analyser.isIdle)
        #expect(analyser.grid[AnalyserColumns.rows - 1].allSatisfy { $0 == .floor })
        // Frozen, not run down — the script stops advancing rather than
        // stepping to nought.
        #expect(analyser.state.height == standing)

        analyser.hear(Self.tone(1000, seconds: 0.5))
        analyser.frame()
        #expect(!analyser.isIdle)
    }

    @Test("A silent stretch is silence however loud the deck's volume is")
    func silenceIsNotPause() {
        // Nothing here ever asks what the deck's mode is. That is the box:
        // the test is whether anything is coming out.
        let analyser = Analyser()
        analyser.hear(Self.silence(seconds: 1.0))
        for _ in 0..<10 { analyser.frame() }
        #expect(analyser.isIdle)
    }

    @Test("A new track clears the columns and the last reading")
    func newTrack() {
        let analyser = Analyser()
        analyser.hear(Self.tone(60, seconds: 1.0))
        for _ in 0..<4 { analyser.frame() }
        // A reading, but no column yet: one second into a record the scales are
        // still up at the ceiling and nothing is drawn (D33, §18.21).
        #expect(analyser.levels.contains { $0 > Spectrum.floor })
        #expect(analyser.state.height.allSatisfy { $0 == 0 })

        // Seven seconds in, the prior has been pulled down and there is a
        // column to clear — which is what this test is actually about.
        analyser.hear(Self.tone(60, seconds: 6.0))
        for _ in 0..<4 { analyser.frame() }
        #expect(analyser.state.height.contains { $0 > 0 })

        analyser.newTrack()
        #expect(analyser.state.height.allSatisfy { $0 == 0 })
        #expect(analyser.levels.allSatisfy { $0 == Spectrum.floor })
    }

    /// D33, at the level anyone would notice it: two tracks of the same record
    /// are one scale, and two records are two.
    @Test("The scale survives a track change and does not survive a record change")
    func scaleCarriesBetweenTracks() {
        let analyser = Analyser()

        // A minute of a loud, narrow band: enough evidence to bury the seed.
        for _ in 0..<600 { analyser.hear(Self.tone(60, seconds: 0.1, amplitude: 0.9)) }
        analyser.frame()
        let lit = Self.band(containing: 60)
        let learned = analyser.state.height[lit]
        #expect(learned > 0)

        // The next track. One window in, the same tone still draws what it drew
        // before, because the minute it took to learn that is still there.
        analyser.newTrack()
        analyser.hear(Self.tone(60, seconds: 0.1, amplitude: 0.9))
        analyser.frame()
        let carried = analyser.state.height[lit]
        #expect(carried == learned, "carried \(carried), learned \(learned)")

        // A new record throws it away and starts at the ceiling, so the very
        // same tone draws short until the evidence comes back (D33).
        analyser.newRecord()
        analyser.hear(Self.tone(60, seconds: 0.1, amplitude: 0.9))
        analyser.frame()
        let cold = analyser.state.height[lit]

        #expect(cold < carried, "cold \(cold), carried \(carried)")
    }

    @Test("Twenty frames a second over ten measurements a second")
    func twoClocks() {
        let analyser = Analyser()
        // Music as it would actually arrive: a window's worth of samples, then
        // the two frames the panel draws in that tenth of a second. Seven
        // seconds of it, because that is how long a record takes to pull its
        // scales down off the ceiling and draw anything at all (D33, §18.21).
        for _ in 0..<70 {
            analyser.hear(Self.tone(1000, seconds: 0.1))
            analyser.frame()
            analyser.frame()
        }

        let lit = Self.band(containing: 1000)
        #expect(analyser.state.height[lit] > 0)
        #expect(!analyser.isIdle)

        // The trail falls two eighths a *frame*, so it comes down forty in the
        // second — the whole column — and not twenty.
        analyser.newTrack()
        var columns = AnalyserColumns()
        columns.step([Int](repeating: AnalyserColumns.top, count: 16))
        for _ in 0..<20 { columns.step([Int](repeating: 0, count: 16)) }
        #expect(columns.trail[0] == 0)
    }

    // MARK: - Off a real engine

    /// The whole path, through an `AVAudioEngine` rendering offline: a tap on a
    /// mixer, a player node pushing a tone into it, and the columns coming out
    /// the other end. No window, no device, no clock — which is the only way
    /// this is a test rather than a demonstration.
    @Test("A tap on a live graph lights the band the tone is in")
    func throughAnEngine() throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
        // Pulling the main mixer is what makes the graph render at all.
        _ = engine.mainMixerNode

        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)

        let analyser = Analyser()
        analyser.tap(engine.mainMixerNode, bufferSize: 4096)
        defer { analyser.untap(engine.mainMixerNode) }

        try engine.start()
        player.scheduleBuffer(Self.tone(1000, seconds: 1.0), completionHandler: nil)
        player.play()

        let sink = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096
        )!
        var rendered: AVAudioFramePosition = 0
        while rendered < 44100 {
            let status = try engine.renderOffline(4096, to: sink)
            guard status == .success else { break }
            rendered += AVAudioFramePosition(sink.frameLength)
        }
        player.stop()
        engine.stop()

        for _ in 0..<4 { analyser.frame() }

        let lit = Self.band(containing: 1000)
        #expect(analyser.levels[lit] > -12)
        #expect(!analyser.isIdle)

        // **The columns are deliberately not asserted here.** Offline rendering
        // does not deliver a tap callback per render call — measured, eight
        // seconds through the graph arrived as seventeen buffers and about one
        // and seven tenths of a second of audio — so how much the scales have
        // heard is not something this test controls, and under D33 that is
        // exactly what decides whether anything is drawn. The tap's own contract
        // is the reading and the shape of the bands around it; the columns are
        // `twoClocks`, where the windows are counted.

        // And the columns fall away either side of it.
        for band in 0..<Bands.count where abs(band - lit) >= 3 {
            #expect(analyser.levels[band] < analyser.levels[lit] - 6)
        }
    }
}
