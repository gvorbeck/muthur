import Foundation

/// §20 stage 3 — the stand-in for cdrecord (`fake_cdrecord`, `burncd:1982`).
///
/// It sizes itself like a disc rather than from the files in front of it, so the
/// burn panel can be watched end to end with no blank, no drive, and no twenty
/// minutes to spare.
///
/// **The silences are as much the point of it as the numbers are.** A real drive
/// says nothing at all while it spins up, calibrates its laser and writes the
/// lead-in, and goes quiet again for the lead-out. Those two are precisely what
/// the panel covers out of its own pocket, so a stand-in that streamed tidily
/// from nothing to the last megabyte would rehearse the easy part of the display
/// and none of the hard part.
///
/// What it does not do is stop short of a track: a real drive closes every track
/// on that track's full size. The arrears that keep the disc's bar off 100 come
/// from the per-track rounding described at `BurnPanel.tailPercent`, and are put
/// there by handing the panel a disc total a megabyte a track larger than the
/// tracks add up to — so the bar comes up short here the way it does on a real
/// burn, and the lead-out has something real to paper over.
///
/// **A schedule and not a sleep.** The script's stand-in is written in real
/// seconds because it is being watched; this one is a list of times, which a
/// view can play at wall-clock speed and a test can play in a millisecond. Same
/// numbers either way.
public struct FakeDrive: Drive {

    /// Megabytes a track, which is the one thing about it worth varying: a
    /// four-track demo and a forty-track one want different discs.
    public var each: Int

    public init(each: Int = FakeDrive.megabytesPerTrack) {
        self.each = each
    }

    /// The lead-in, the lead-out, and the gap between progress lines
    /// (`burncd:1984`). Six and eight seconds are what a SuperDrive takes; the
    /// thirtieth of a second between lines is faster than cdrecord's once a
    /// second, because the demo is a display to be looked at rather than a burn
    /// to be waited out.
    public static let leadIn = 6.0
    public static let leadOut = 8.0
    public static let interval = 0.03

    /// Megabytes a track, and the step between messages (`burncd:2591`).
    public static let megabytesPerTrack = 55
    public static let step = 2

    /// What the panel is told the disc holds: **one megabyte a track more than
    /// the tracks add up to**, standing in for the rounding arrears of a real
    /// burn.
    public static func totalMegabytes(tracks: Int, each: Int = megabytesPerTrack) -> Int {
        (each + 1) * tracks
    }

    /// One line, in cdrecord's own layout — the columns padded exactly as it
    /// pads them, because the parser's business is reading what a drive actually
    /// emits and a stand-in that tidied the spacing would be testing a shape
    /// nothing produces.
    public static func line(track: Int, done: Int, total: Int) -> String {
        String(
            format: "Track %02d: %4d of %4d MB written (fifo 100%%) [buf  97%%]  8.0x.",
            track, done, total)
    }

    /// A progress line and the second it is said at.
    public struct Message: Sendable, Equatable {
        public let at: Double
        public let text: String
    }

    /// The whole burn, as times.
    public static func messages(tracks: Int, each: Int = megabytesPerTrack) -> [Message] {
        var messages: [Message] = []
        var clock = leadIn
        for track in 1...max(1, tracks) {
            var done = 0
            while done < each {
                messages.append(Message(at: clock, text: line(track: track, done: done, total: each)))
                clock += interval
                done += step
            }
            // Every track is closed on its own stated size, whatever the step
            // last landed on.
            messages.append(Message(at: clock, text: line(track: track, done: each, total: each)))
            clock += interval
        }
        return messages
    }

    /// When the disc is ejected: the last line, then the lead-out.
    public static func duration(tracks: Int, each: Int = megabytesPerTrack) -> Double {
        (messages(tracks: tracks, each: each).last?.at ?? leadIn) + interval + leadOut
    }

    // MARK: - End to end

    /// Play the whole schedule into a panel, at the lamp's own tick.
    ///
    /// This is the pipeline with the drive taken out and nothing else changed:
    /// the same panel, the same parser, the same lead-out test, the same lamp.
    /// The clock is a counter rather than a wall, so a burn that takes half a
    /// minute to watch takes no time at all to check.
    ///
    /// `onFrame` sees every frame in order, which is what makes the silences
    /// assertable — the interesting frames of a burn are the ones where nothing
    /// arrived.
    @discardableResult
    public static func play(
        titles: [String],
        durations: [Int],
        disc: Int = 1,
        of discs: Int = 1,
        each: Int = megabytesPerTrack,
        rehearsal: Bool = false,
        onFrame: (BurnPanel) -> Void = { _ in }
    ) -> BurnPanel {
        var panel = BurnPanel(
            disc: disc, of: discs, titles: titles, durations: durations,
            totalMegabytes: totalMegabytes(tracks: titles.count, each: each),
            rehearsal: rehearsal)

        let schedule = messages(tracks: titles.count, each: each)
        let end = duration(tracks: titles.count, each: each)
        var next = 0
        var clock = 0.0

        while clock <= end {
            // Everything the drive said since the last frame, in order. A tick
            // this coarse can cover more than one line — the lamp redraws twenty
            // times a second and the stand-in speaks thirty — and the panel is
            // the same either way: each message overwrites the last, which is
            // exactly what a carriage return does to a terminal.
            while next < schedule.count, schedule[next].at <= clock {
                panel.receive(schedule[next].text, at: Int(clock))
                next += 1
            }
            panel.tick(at: Int(clock))
            onFrame(panel)
            clock += Lamp.tick
        }
        return panel
    }

    // MARK: - The seam

    /// A megabyte a track more than the tracks add up to. The image's real size
    /// is not consulted: the stand-in is a display to be looked at, and a demo
    /// run on a two-minute test record would otherwise be over before the
    /// lead-in finished.
    public func totalMegabytes(bytes: Int, tracks: Int) -> Int {
        FakeDrive.totalMegabytes(tracks: tracks, each: each)
    }

    /// **Nothing is spawned.** The invocation is carried this far so that a demo
    /// exercises the vector's construction as well as the panel's drawing — the
    /// argument that is wrong is wrong whether or not anything runs it — and then
    /// it is dropped on the floor, which is the one difference between this and
    /// the drive that replaces it.
    public func write(
        _ invocation: Cdrecord,
        into panel: inout BurnPanel,
        frame: (BurnPanel) -> Void
    ) throws {
        panel = FakeDrive.play(
            titles: panel.titles, durations: panel.durations,
            disc: panel.disc, of: panel.discs, each: each,
            rehearsal: panel.rehearsal, onFrame: frame)
    }
}
