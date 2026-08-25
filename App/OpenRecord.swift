import AppKit
import Foundation

/// **This is not §1.**
///
/// §1 is the whole source layer — the argument off the command line, the picker
/// that remembers where you keep records, the zip unpacked to scratch, the audio
/// CD in the drive, the collection lookup that puts a shelf and a note on the
/// panel. None of that exists yet, and none of it is what this is.
///
/// This is one `NSOpenPanel` pointed at a folder, so that §10 can be looked at
/// while it is being built. It should be deleted the day §1 lands, and the
/// parity boxes for §1 stay unticked until it is.
enum OpenRecord {

    /// A record named in the environment, so that a launch lands straight on a
    /// full panel while §10 is being drawn and tuned. Goes with the rest of this
    /// file the day §1 can be handed a record properly.
    static var preset: URL? {
        ProcessInfo.processInfo.environment["MUTHUR_RECORD"].map {
            URL(fileURLWithPath: $0)
        }
    }

    static func ask() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "PLAY"
        panel.message = "Choose a folder of audio files."
        return panel.runModal() == .OK ? panel.url : nil
    }
}
