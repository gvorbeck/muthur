import Foundation
import Testing

@testable import MUTHURKit

/// §20 stage 3 — the stages a job raises on its way past.
///
/// `BurnStage`'s four cases were written before anything emitted them: the type
/// was complete, documented and never once constructed, which is a screen that
/// cannot be drawn because nothing tells it what to draw. These are the tests
/// for the seam that closed that — `BurnJob.run`'s `stage` callback — and what
/// they assert is the *order*, because the order is the whole of what a stage
/// means. Converting disc 2 before disc 1 has been asked for is exactly the
/// mistake `burncd:2398` rearranged the loop to prevent.
@Suite("§20 stage 3 — the stages", .enabled(if: Fixtures.locate("ffmpeg") != nil))
struct BurnStageTests {

    static let ffmpeg = Fixtures.locate("ffmpeg")

    /// A short record whose tracks are real audio, since the conversion has to
    /// actually run for the converting stage to be raised.
    private func shelf(_ work: URL, tracks: Int, seconds: Double = 1) throws -> [URL] {
        try (0..<tracks).map { index in
            try BurnConversionTests.make(
                "\(index).flac", in: work, seconds: seconds,
                frequency: 220 + index * 110, codec: ["-c:a", "flac"])
        }
    }

    /// A label for each stage, which is what makes an order assertable without
    /// writing the whole payload out four times.
    private func name(_ stage: BurnStage) -> String {
        switch stage {
        case .insert(let disc, let of, let canEdit):
            "insert \(disc)/\(of)\(canEdit ? " edit" : "")"
        case .converting(let disc, _, let track, let ofTracks, _, _):
            "converting \(disc):\(track)/\(ofTracks)"
        case .written(let disc, let of, let rehearsal):
            "written \(disc)/\(of)\(rehearsal ? " rehearsed" : "")"
        case .done:
            "done"
        }
    }

    // MARK: - The order

    /// One disc, `--demo`: no prompt, because a demo is never asked for a blank
    /// (`BurnJob.Insert` — nil is `--demo`), then a stage per track and one
    /// `written` at the end.
    @Test("a demo converts every track and then says the disc is written")
    func demoRaisesEveryStage() throws {
        let work = try BurnConversionTests.Work()
        let files = try shelf(work.url, tracks: 3)
        let job = BurnJob(
            draft: BurnConversionTests.draft(
                ["One", "Two", "Three"], durations: [1, 1, 1]),
            files: files, work: work.url, stop: .throughTheBurn
        )

        var seen: [String] = []
        _ = try job.run(
            ffmpeg: Self.ffmpeg, drive: FakeDrive(),
            stage: { seen.append(name($0)) })

        #expect(
            seen == [
                "converting 1:1/3", "converting 1:2/3", "converting 1:3/3",
                "written 1/1",
            ])
    }

    /// The prompt comes **before** the conversion, which is the order
    /// `burncd:2398` exists to enforce: a job that converts before anybody has
    /// been asked for a blank has already spent the minutes the check is meant
    /// to save.
    @Test("the blank is asked for before a second of audio is decoded")
    func insertComesFirst() throws {
        let work = try BurnConversionTests.Work()
        let files = try shelf(work.url, tracks: 2)
        let job = BurnJob(
            draft: BurnConversionTests.draft(["One", "Two"], durations: [1, 1]),
            files: files, work: work.url, stop: .throughTheBurn
        )

        var seen: [String] = []
        _ = try job.run(
            ffmpeg: Self.ffmpeg, drive: FakeDrive(),
            // A check that takes anything, since what is being asserted here is
            // the order the prompt falls in and not what the drive had in it.
            insert: BurnJob.Insert(check: MediaCheck(enabled: false), wait: { _ in true }),
            stage: { seen.append(name($0)) })

        #expect(seen.first == "insert 1/1 edit")
        #expect(seen.firstIndex(of: "insert 1/1 edit")! < seen.firstIndex(of: "converting 1:1/2")!)
    }

    /// `q` at the prompt. The job unwinds where it stands, and what matters is
    /// what is *not* in the list: nothing was converted and no disc was written.
    @Test("a refusal at the prompt stops the job before anything is built")
    func cancelStopsEverything() throws {
        let work = try BurnConversionTests.Work()
        let files = try shelf(work.url, tracks: 2)
        let job = BurnJob(
            draft: BurnConversionTests.draft(["One", "Two"], durations: [1, 1]),
            files: files, work: work.url, stop: .throughTheBurn
        )

        var seen: [String] = []
        #expect(throws: BurnJob.Failure.self) {
            _ = try job.run(
                ffmpeg: Self.ffmpeg, drive: FakeDrive(),
                insert: BurnJob.Insert(
                    check: MediaCheck(enabled: false), wait: { _ in false }),
                stage: { seen.append(name($0)) })
        }

        #expect(seen == ["insert 1/1 edit"])
        #expect(!FileManager.default.fileExists(atPath: job.imageURL(disc: 1).path))
    }

    /// `--dummy` carries one word all the way from the switch to the screen.
    @Test("a rehearsal says so on the stage that reports the disc")
    func rehearsalReachesTheStage() throws {
        let work = try BurnConversionTests.Work()
        let files = try shelf(work.url, tracks: 2)
        let job = BurnJob(
            draft: BurnConversionTests.draft(["One", "Two"], durations: [1, 1]),
            files: files, work: work.url, stop: .throughTheBurn, rehearsal: true
        )

        var seen: [String] = []
        _ = try job.run(
            ffmpeg: Self.ffmpeg, drive: FakeDrive(),
            stage: { seen.append(name($0)) })

        #expect(seen.last == "written 1/1 rehearsed")
    }

    // MARK: - The head

    /// The conversion's head is where the *seconds* already converted put it,
    /// not where the track count does (`burncd:1556`) — so a record whose first
    /// track is most of the disc has a bar that jumps, and one of equal tracks
    /// has a bar that walks.
    @Test("the converting head follows the seconds, not the track count")
    func headFollowsTheSeconds() throws {
        let work = try BurnConversionTests.Work()
        let files = try shelf(work.url, tracks: 2)
        // One long track and one short one. The head before the second track is
        // where the first track's share of the bar ends, which is nowhere near
        // halfway.
        let job = BurnJob(
            draft: BurnConversionTests.draft(["Long", "Short"], durations: [270, 30]),
            files: files, work: work.url, stop: .throughTheBurn
        )

        var heads: [Int] = []
        _ = try job.run(
            ffmpeg: Self.ffmpeg, drive: FakeDrive(),
            stage: { stage in
                if case .converting(_, _, _, _, _, let head) = stage { heads.append(head) }
            })

        let units = PanelGrid.stripWidth * Meter.unitsPerCell
        #expect(heads.count == 2)
        #expect(heads.first == 0)
        // 270 of 300 seconds, which is nine tenths along and not one half.
        #expect(heads.last == 270 * units / 300)
        // Not `== 90`: the head truncates once on the way in and `percent`
        // truncates again on the way out, so nine tenths reads as 89 here and
        // would read as either on a strip of a different width. What the screen
        // promises is that the bar is most of the way across before the last
        // track starts, and that is what is asserted.
        #expect(BurnStage.percent(heads.last ?? 0) >= 89)
    }
}
