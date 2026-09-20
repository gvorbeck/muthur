import Foundation

/// §21 — what the deck says when it will not start an import.
///
/// `PlanScreen.refusal`'s counterpart, and it exists for the same reason: a
/// `Failure`'s `description` is written for a log, where there is room for two
/// lines and a remedy, and a status line has one row of sixty-nine columns. The
/// two wordings are deliberately different rather than one truncated.
///
/// **Every one of these names the way out.** The failures an import can have
/// before it starts are all things the user can do something about — a fuller
/// volume, a different directory, a menu switch — and a refusal that did not
/// say which would be the panel declining and then declining to explain.
public enum ImportScreen {

    public static func refusal(_ failure: ImportPlan.Failure) -> String {
        switch failure {
        case .nothingToImport:
            "NOTHING ON THIS DISC TO IMPORT"
        case .noVacantName:
            "NO FREE NAME IN THAT FOLDER — CHOOSE ANOTHER"
        case .cannotWrite:
            "CANNOT WRITE THERE — CHOOSE ANOTHER FOLDER"
        case .noRoom(let need, let have, _):
            "NEEDS \(TempSpace.human(need)) · \(TempSpace.human(have)) FREE "
                + "— CHOOSE ANOTHER VOLUME"
        }
    }

    /// The same for a job that got past the plan and failed on the way.
    ///
    /// These land on the import screen's own summary rather than on the deck's
    /// status line, so they have the width of a faceplate rather than of a
    /// status row — but they are still one line, and `description`'s second
    /// line is still the part that does not fit.
    public static func refusal(_ failure: ImportJob.Failure) -> String {
        switch failure {
        case .noFFmpeg:
            "FFMPEG IS NEEDED TO IMPORT AND IS NOT INSTALLED"
        case .noEncoder(let format, let library):
            "THIS FFMPEG CANNOT WRITE \(format.name) — BUILT WITHOUT \(library.uppercased())"
        case .cancelled:
            "CANCELLED — NOTHING KEPT"
        case .nothingRead:
            "NOTHING ON THIS DISC COULD BE READ"
        case .cannotCreate:
            "COULD NOT MAKE THE FOLDER — CHOOSE ANOTHER PLACE"
        }
    }
}
