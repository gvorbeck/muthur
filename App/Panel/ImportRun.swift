import AppKit
import Foundation
import MUTHURKit
import Observation

/// §21 — an import that is actually happening, as the window sees it.
///
/// `BurnRun`'s shape, and the reasoning transfers whole: `ImportJob.run` is one
/// blocking call with seams out of it, a window cannot be *inside* anything, so
/// the job runs on a thread of its own and every seam hops to the main actor and
/// lands in a value the view is already observing.
///
/// **What is not here is the interesting half.** `BurnRun` carries a `Gate` — a
/// semaphore on the thread's side and a key on this one — because the burn has
/// to stop and ask for a blank. An import asks nothing: the disc is already in
/// the machine and already on the deck, and the only question is *where*, which
/// was answered by an open panel before this object existed. So the traffic is
/// one-way, and the only thing going the other direction is the stop.
@MainActor
@Observable
final class ImportRun {

    /// What the panel is showing. Seeded rather than left empty, for `BurnRun`'s
    /// reason: the first stage does not arrive until the folder is made and the
    /// volume has been asked how much room it has, and a blank screen for those
    /// seconds is the hang `BurnPanel` spends three paragraphs refusing to draw.
    private(set) var stage: ImportStage

    /// Everything the job has said, oldest first.
    private(set) var log: [String] = []

    private(set) var finished = false

    /// Where it all went, once anything has. Nil until the job says so, which
    /// is what `REVEAL` is gated on — a folder that was swept by a cancel is
    /// not a folder to go and look at.
    private(set) var folder: URL?

    /// The plan, for the bands the bar is drawn against. The screen draws off
    /// this rather than off the job, which is holding its own copy on another
    /// thread.
    let plan: ImportPlan

    /// Whether the run can still be called off — **true for its whole length
    /// but the last frame**, which is the whole of how this differs from a
    /// burn. `BurnRun.isWaitingForDisc` is true at one prompt and false
    /// everywhere else, because once the laser is on there is nothing to cancel
    /// that would not leave a coaster behind. An import leaves files, and files
    /// can be taken back; `ImportJob.cancelled` takes them.
    var canCancel: Bool { !finished }

    private let stop = ImportJob.Stop()
    private let began = Date()
    private let ejectWhenDone: Bool
    /// Called when the job is over and the options asked for the disc back.
    /// The deck owns the drive, not this screen — see `PanelModel.importDisc`.
    private let eject: @MainActor () -> Void

    init(
        plan: ImportPlan,
        options: ImportOptions,
        sleeve: URL?,
        eject: @escaping @MainActor () -> Void = {}
    ) {
        self.plan = plan
        self.ejectWhenDone = options.ejectWhenDone
        self.eject = eject
        self.stage = .preparing(into: plan.folder.lastPathComponent)
        start(options: options, sleeve: sleeve)
    }

    // MARK: - The one key

    /// `Q CANCEL`. The job unwinds and takes everything it wrote with it.
    func cancel() { stop.ask() }

    /// The screen coming off.
    ///
    /// **Nothing to sweep, which is the difference from `BurnRun.discard`.** A
    /// burn builds an image in a scratch directory that outlives the run; an
    /// import's only output is the folder it was asked for, which is the thing
    /// the user wanted and is not ours to tidy away. A run still in flight is
    /// stopped rather than left — unlike a `cdrecord`, there is nothing here
    /// that is worse for being interrupted.
    func discard() {
        if !finished { stop.ask() }
    }

    /// `R REVEAL` on the summary — the folder, in Finder.
    ///
    /// The one question a finished import leaves. The summary names the folder
    /// and naming it is not the same as being able to find it, particularly
    /// when the name has a `(2)` on the end that the user did not choose.
    func reveal() {
        guard let folder else { return }
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    // MARK: - The thread

    private func start(options: ImportOptions, sleeve: URL?) {
        let plan = self.plan
        let stop = self.stop
        let began = self.began
        let ffmpeg = Diagnostics.locate("ffmpeg")

        let sink = Sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .stage(let stage):
                self.stage = stage
            case .note(let line):
                self.log.append(line)
            case .over(let closing, let written, let folder):
                self.stage = .done(
                    summary: closing, written: written,
                    folder: folder?.lastPathComponent ?? "")
                self.folder = folder
                self.finished = true
                // The disc is let go of only once there is nothing left to read
                // off it, and only if it was asked for. It goes through the
                // deck rather than straight to `drutil`, because the deck is
                // what has the record open and is the thing that has to let go
                // first.
                if self.ejectWhenDone, folder != nil { self.eject() }
            }
        }

        let job = ImportJob(plan: plan, options: options, sleeve: sleeve)

        Thread.detachNewThread {
            let outcome: ImportJob.Outcome?
            var trouble: String?
            do {
                outcome = try job.run(
                    ffmpeg: ffmpeg,
                    stop: stop,
                    note: { sink.send(.note($0)) },
                    stage: { sink.send(.stage($0)) }
                )
            } catch let failure as ImportJob.Failure {
                outcome = nil
                if case .cancelled = failure {
                    // Not a fault. Somebody said stop at a prompt that takes
                    // stop for an answer, and the machine agreeing is not the
                    // machine complaining — `BurnRun` makes the same point
                    // about the same word.
                    trouble = ImportStage.cancelledSummary(
                        elapsed: Int(Date().timeIntervalSince(began)))
                } else {
                    // The screen's wording and not the log's:
                    // `Failure.description` carries a second line with the
                    // remedy on it, which a faceplate has no room for.
                    trouble = ImportScreen.refusal(failure)
                }
            } catch let failure as ImportPlan.Failure {
                outcome = nil
                trouble = ImportScreen.refusal(failure)
            } catch {
                outcome = nil
                trouble = "\(error)".uppercased()
            }

            let elapsed = Int(Date().timeIntervalSince(began))
            if let outcome {
                let runtime = outcome.plan.entries
                    .filter { entry in outcome.written.contains { $0.path == entry.destination.path } }
                    .reduce(0) { $0 + $1.duration }
                let closing = ImportStage.summary(
                    written: outcome.written.count, of: outcome.plan.entries.count,
                    format: outcome.plan.format, runtime: runtime, elapsed: elapsed)
                sink.send(.over(closing, outcome.written.count, outcome.folder))
            } else {
                sink.send(.over(trouble ?? "STOPPED", 0, nil))
            }
        }
    }
}

/// One-way traffic off the job's thread, `BurnRun`'s `Sink` with this job's
/// events on it. Everything it carries is `Sendable` and everything it does
/// happens on the main actor.
private struct Sink: Sendable {
    enum Event: Sendable {
        case stage(ImportStage)
        case note(String)
        case over(String, Int, URL?)
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
