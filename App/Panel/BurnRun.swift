import Foundation
import MUTHURKit
import Observation

/// §20 stage 3 — a burn that is actually happening, as the window sees it.
///
/// `BurnJob.run` is one blocking call with three seams out of it: a frame, a
/// note, and a stage. That shape is a terminal's — the script is *inside* the
/// job for its whole length and draws from where it stands (`burncd:2398`) — and
/// a window cannot be inside anything. So the job runs on a thread of its own
/// and this is what it talks to: every seam hops to the main actor and lands in
/// a value the view is already observing.
///
/// **The insert prompt is the interesting one**, because it is the only seam
/// that goes the other way. `Insert.wait` blocks until a person has done
/// something, which on a background thread is a semaphore and on this side is a
/// key. `Gate` is that pair and nothing else.
@MainActor
@Observable
final class BurnRun {

    /// What the panel is showing. Seeded rather than left empty: the job's first
    /// stage does not arrive until the level pass and the CD-Text measurement
    /// are done, and a blank screen for those seconds is the hang `BurnPanel`
    /// spends three paragraphs refusing to draw.
    private(set) var stage: BurnStage

    /// The write screen, while the drive is writing. Nil in every other stage,
    /// which is what the view switches on.
    private(set) var panel: BurnPanel?

    /// Everything the job has said, oldest first (`LOG`, `burncd:1440`).
    private(set) var log: [String] = []

    /// Set once, when the job is over. A finished run is still on screen — the
    /// summary is a stage like any other — so this is what says the thread has
    /// gone, not whether there is anything to look at.
    private(set) var finished = false

    /// Whether the burn can still be called off. Only true at the insert
    /// prompt: `Q CANCEL` is on that legend and no other (`Readout.burnLegend`),
    /// because once ffmpeg or the laser is running there is nothing to cancel
    /// that would not leave a coaster behind.
    var isWaitingForDisc: Bool {
        if case .insert = stage, !finished { return true }
        return false
    }

    /// The plan as the editor left it. The screen draws off this rather than
    /// off the job, which is holding its own copy on another thread.
    let plan: BurnPlan
    let albumArtist: String
    let year: String

    /// Which disc the job is on, for the stages that draw a disc's tracks
    /// without naming it in their own payload.
    var disc: Int {
        switch stage {
        case .insert(let disc, _, _): disc
        case .converting(let disc, _, _, _, _, _): disc
        case .written(let disc, _, _): disc
        case .done: 1
        }
    }

    private let gate = Gate()
    private let rehearsal: Bool
    private let began = Date()

    /// The scratch this run made for itself, if it made one. Swept when the
    /// screen comes off — see `discard`.
    private let ownWork: URL?

    init(
        editor: PlanEditor,
        files: [URL],
        work: URL,
        ownWork: URL?,
        demo: Bool,
        rehearsal: Bool
    ) {
        self.plan = editor.plan
        self.albumArtist = editor.draft.albumArtist
        self.year = editor.draft.year
        self.rehearsal = rehearsal
        self.ownWork = ownWork

        // A demo is never asked for a disc (`BurnJob.Insert` says why: nil is
        // `--demo`), so it opens on the conversion rather than on a prompt that
        // is not coming. A real burn opens on the prompt, which is the first
        // thing the job will raise.
        let first = plan.entries(onDisc: 1)
        self.stage =
            demo
            ? .converting(
                disc: 1, of: plan.discCount, track: 1, ofTracks: first.count,
                title: first.first?.title ?? "", head: 0)
            : .insert(disc: 1, of: plan.discCount, canEdit: true)

        start(draft: editor.draft, files: files, work: work, demo: demo)
    }

    // MARK: - Answering the prompt

    /// `⏎ BURN` — a disc is in the drive, go and look at it.
    func go() { gate.decide(true) }

    /// `Q CANCEL` at the insert prompt. The job throws `.cancelled` and unwinds;
    /// nothing has been written by then, which is the whole reason this key only
    /// exists here.
    func cancel() { gate.decide(false) }

    /// The screen coming off. A run still in flight is left to finish — there is
    /// no safe way to stop a `cdrecord` halfway and the script does not offer
    /// one — so this only sweeps what is ours to sweep.
    func discard() {
        guard finished, let ownWork else { return }
        try? FileManager.default.removeItem(at: ownWork)
    }

    // MARK: - The thread

    private func start(draft: PlanDraft, files: [URL], work: URL, demo: Bool) {
        let rehearsal = self.rehearsal
        let gate = self.gate
        let began = self.began
        let ffmpeg = Diagnostics.locate("ffmpeg")

        // Every one of these lands on the main actor and touches nothing else,
        // so the closures carry a sendable box and never `self`.
        let sink = Sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .stage(let stage):
                self.stage = stage
                // The write screen belongs to the writing and to nothing else. A
                // stage arriving is the drive having finished or not yet started.
                self.panel = nil
            case .frame(let panel):
                self.panel = panel
            case .note(let line):
                self.log.append(line)
            case .over(let closing, let discs):
                self.stage = .done(summary: closing, discs: discs)
                self.panel = nil
                self.finished = true
            }
        }

        let job = BurnJob(
            draft: draft,
            files: files,
            work: work,
            stop: .throughTheBurn,
            rehearsal: rehearsal
        )

        Thread.detachNewThread {
            let outcome: BurnJob.Outcome?
            var trouble: String?
            do {
                outcome = try job.run(
                    ffmpeg: ffmpeg,
                    drive: demo ? FakeDrive() : Burner(),
                    insert: demo
                        ? nil
                        : BurnJob.Insert(check: MediaCheck(), wait: { _ in gate.wait() }),
                    frame: { panel in
                        sink.send(.frame(panel))
                        // The stand-in has no drive to wait for and emits its
                        // whole schedule as fast as the loop turns, so the pacing
                        // a real burn gets for free is put back here. `Lamp.tick`
                        // and not a guess: it is the interval the schedule was
                        // written in (`FakeDrive.play`).
                        if demo { Thread.sleep(forTimeInterval: Lamp.tick) }
                    },
                    note: { sink.send(.note($0)) },
                    stage: { sink.send(.stage($0)) }
                )
            } catch let failure as BurnJob.Failure {
                outcome = nil
                // A cancel is not a fault. The operator said no at the one
                // prompt that takes no for an answer, and saying `CANCELLED` at
                // them is the machine agreeing, not complaining.
                if case .cancelled = failure {
                    trouble = "CANCELLED — nothing was written"
                } else {
                    trouble = failure.description.uppercased()
                }
            } catch {
                outcome = nil
                trouble = "\(error)".uppercased()
            }

            let elapsed = Int(Date().timeIntervalSince(began))
            if let outcome {
                let wrote = Array(1...max(1, outcome.plan.discCount))
                let runtime = wrote.reduce(0) { $0 + outcome.plan.runtime(onDisc: $1) }
                sink.send(
                    .over(
                        BurnStage.summary(
                            discs: outcome.plan.discCount, runtime: runtime,
                            elapsed: elapsed, rehearsal: rehearsal),
                        wrote))
            } else {
                sink.send(.over(trouble ?? "STOPPED", []))
            }
        }
    }
}

// MARK: - The two things that cross the thread

/// One-way traffic off the job's thread. Everything it carries is `Sendable` and
/// everything it does happens on the main actor, which is the whole of why the
/// job's closures can be written without a capture list full of locks.
private struct Sink: Sendable {
    enum Event: Sendable {
        case stage(BurnStage)
        case frame(BurnPanel)
        case note(String)
        case over(String, [Int])
    }

    let apply: @MainActor @Sendable (Event) -> Void

    init(_ apply: @escaping @MainActor @Sendable (Event) -> Void) {
        self.apply = apply
    }

    func send(_ event: Event) {
        let apply = self.apply
        DispatchQueue.main.async { MainActor.assumeIsolated { apply(event) } }
    }
}

/// The insert prompt, from the thread's side: block until somebody presses
/// something, then say which (`stage_insert`'s `read_key` loop, `burncd:2425`).
private final class Gate: @unchecked Sendable {
    private let waiting = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var answer = false

    func decide(_ go: Bool) {
        lock.lock()
        answer = go
        lock.unlock()
        waiting.signal()
    }

    func wait() -> Bool {
        waiting.wait()
        lock.lock()
        defer { lock.unlock() }
        return answer
    }
}
