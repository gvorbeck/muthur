import AppKit
import MUTHURKit
import SwiftUI
import UniformTypeIdentifiers

/// The entry point is `main.swift`, not `@main` here — `--check` has to be
/// answered and exited before `NSApplication` starts (§11, `player:531`).
struct MUTHURApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var model = PanelModel()

    var body: some Scene {
        WindowGroup("MU/TH/UR") {
            PanelView(model: model)
                .task {
                    delegate.model = model
                    Scratch.sweepAbandoned()

                    // `player:3517`: a named source first, `--cd` second, the
                    // picker last. Naming a record and asking for the disc in
                    // the same breath is not an error — the record wins.
                    do {
                        let options = try LaunchOptions.parse(
                            Array(CommandLine.arguments.dropFirst())
                        )
                        // Before anything is opened, and not as an argument to
                        // one call: `--no-mb` outlives the launch. A disc put
                        // in later and opened off the picker (`r`, §1.2) is
                        // still this session's disc, and the flag still holds.
                        //
                        // **Only when the flag was actually given** (D105). The
                        // model already starts at the saved setting, and an
                        // unconditional assignment here would hand it `true`
                        // every launch the flag was absent — which is the
                        // setting being quietly overwritten by the default of
                        // the thing that is meant to override it.
                        if !options.useMusicBrainz { model.useMusicBrainz = false }
                        if let path = options.sourcePath {
                            let (url, kind) = try SourceOpener.resolve(path: path)
                            model.open(source: url, kind: kind)
                        } else if options.wantCD {
                            model.openDisc()
                        } else {
                            model.pickSource()
                        }
                    } catch {
                        model.die("\(error)")
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            // Both under About: settings first, where every Mac keeps them,
            // then the health check — a question about the machine belongs in
            // the same menu, and `--check`'s screen has to stay reachable by
            // somebody who launched this from the Dock and has no command line
            // to type it on (§11).
            //
            // **`after: .appInfo` and not `replacing: .appSettings`, which is
            // a trap** (D105). That group is built by AppKit only for an app
            // that declares a `Settings` scene, and this one deliberately does
            // not — the settings are a phosphor screen, not a second window. So
            // there was nothing to replace, and SwiftUI drops the replacement
            // without a word: it compiles, it runs, and the item is simply not
            // in the menu. Found by reading the menu bar off a running copy,
            // which is the only place it could have been found.
            //
            // ⌘, still lands, because the shortcut travels with the item. The
            // item and the `,` cap are one switch, D30's rule: both call this.
            CommandGroup(after: .appInfo) {
                Button(model.isSettings ? "Hide Settings" : "Settings…") {
                    model.toggleSettings()
                }
                .keyboardShortcut(",")
                .disabled(model.isBurning || model.isPlanning || model.isImporting)
                Button("Health Check") { model.check() }
                    .keyboardShortcut("k")
            }
            CommandGroup(after: .newItem) {
                Button("Open Record…") { model.browse() }
                    .keyboardShortcut("o")
                // Still here, and still doing what it did — the settings screen
                // is a second door to the same chooser, not a replacement for
                // the first (D105). Both go through `PanelModel`.
                Button("Collection…") {
                    model.chooseCatalogue()
                    model.catalogueChanged()
                }
            }
            LibraryCommands(model: model)
            ImportCommands(model: model)
            BurnCommands(model: model)
        }
    }

    // ⌘O is `PanelModel.browse()`, which is also the picker's `BROWSE` cap
    // (§14). The chooser moved into the model when the cap arrived, so that the
    // menu item and the keycap are not two file pickers that have to be kept
    // agreeing with each other — they are one.
    //
    // The reason ⌘O exists at all is still `EmptyPanelView`: the script's
    // `pick_source` either hands back a record or dies where it stands
    // (`player:1114`, `player:3532`), so there is no state in which its panel is
    // up with no record in it. A window cannot die on the user like that, and
    // having invented that state the port owes it a way out.

    // D5's file picker used to be written out here, because a menu item was the
    // only place it could be reached from. It is `PanelModel.chooseCatalogue`
    // now — the settings screen opens the same chooser, and two copies of an
    // `NSOpenPanel` is two things that have to keep agreeing about what a
    // catalogue is (D105). What matters about it has not changed: the choice
    // leaves a **security-scoped bookmark** behind rather than a string, so it
    // goes on working the day this is sandboxed and survives the file moving.
}

/// The library (D91), from anywhere.
///
/// **⌘L is the whole reason this menu exists.** `L` on the deck has been the
/// needle forward since D1, so the only key that reaches the shelf from a
/// record that is playing is one with a modifier on it, and a modifier key is a
/// menu item or it is undiscoverable.
struct LibraryCommands: Commands {
    let model: PanelModel

    var body: some Commands {
        CommandMenu("Library") {
            Button(model.isLibrary ? "Hide Library" : "Show Library") { model.toggleLibrary() }
                .keyboardShortcut("l")
                .disabled(busy)

            Divider()

            Button("Add Directory…") {
                model.showLibrary()
                model.library.add()
            }
            .disabled(busy)

            // The menu's remove does not ask twice: the directory has already
            // been picked out of a list by name, which is the asking.
            Menu("Remove Directory") {
                ForEach(model.library.library.directories) { directory in
                    Button(directory.path) { model.library.remove(directory.id) }
                }
            }
            .disabled(busy || model.library.library.directories.isEmpty)

            Button("Rescan") {
                model.showLibrary()
                model.library.rescan()
            }
            .disabled(busy || model.library.library.directories.isEmpty)

            Divider()

            // ⌘F, which is where a Mac hand goes for this before it has read
            // a single cap; `/` is the panel's own (D93).
            Button("Find in Library") {
                model.showLibrary()
                model.library.find()
            }
            .keyboardShortcut("f")
            .disabled(busy || model.library.library.directories.isEmpty)
        }
    }

    /// The screens `showLibrary` will not go over.
    private var busy: Bool {
        model.isBurning || model.isPlanning || model.isLoading || model.isImporting
    }
}

/// §21's option set (**D95**).
///
/// **⌘I is half the reason this menu exists**, on the argument D92 makes about
/// ⌘L: `I` on the deck is the key, and a key with no modifier on it is one you
/// find by reading the legend or not at all. The other half is the format,
/// which was here because it had nowhere else to be; §13's screen is where it
/// lives now, and this stays as the second door to it (**D105**).
///
/// **It is not built like `BurnCommands` and the difference is on purpose.**
/// Every switch there is a flag typed per invocation and forgotten after it;
/// every switch here is written straight through to disk. `ImportOptions` has
/// the whole argument — the short form is that `Rehearse` describes one run and
/// `FLAC` describes your shelf.
struct ImportCommands: Commands {
    let model: PanelModel

    var body: some Commands {
        CommandMenu("Import") {
            Button("Import This Disc…") { model.importDisc() }
                .keyboardShortcut("i")
                .disabled(!model.canImport)

            Divider()

            Group {
                // The format first, because it is the only one of these anybody
                // opens this menu to change.
                Picker("Format", selection: option(\.format)) {
                    // Lossless above the line and lossy below it, which is the
                    // only grouping that matters when what you are choosing is
                    // how to keep a record.
                    ForEach(ImportFormat.allCases.filter(\.isLossless), id: \.self) {
                        Text($0.label).tag($0)
                    }
                    Divider()
                    ForEach(ImportFormat.allCases.filter { !$0.isLossless }, id: \.self) {
                        Text($0.label).tag($0)
                    }
                }

                Toggle("Embed the Sleeve", isOn: option(\.sleeve))

                // **Both of these exist because a real shelf disagreed with
                // the port** (D96, amended). The defaults are what fifty
                // hand-filed albums on this machine already looked like, and
                // the other settings are kept because the reasoning behind
                // them was not wrong, only unpopulated.
                Picker("Folder", selection: option(\.folder)) {
                    ForEach(ImportNames.FolderStyle.allCases, id: \.self) {
                        Text($0.label).tag($0)
                    }
                }
                Picker("Track Names", selection: option(\.trackStyle)) {
                    ForEach(ImportNames.TrackStyle.allCases, id: \.self) {
                        Text($0.label).tag($0)
                    }
                }

                Toggle("Eject When Done", isOn: option(\.ejectWhenDone))
            }
            .disabled(model.isImporting)
        }
    }

    private func option<Value>(_ key: WritableKeyPath<ImportOptions, Value>) -> Binding<Value> {
        Binding(
            get: { model.importOptions[keyPath: key] },
            set: { value in model.setImportOptions { $0[keyPath: key] = value } })
    }
}

/// `burncd`'s command line, as a menu (D86).
///
/// The flags were each ported, tested and wired into `BurnJob`, and the app
/// built every job with none of them. A window has no argument list, so the
/// argument list is here — the kind of burn first, what goes on the disc next,
/// the drive last — and it is read at the one moment it matters: `⏎ BURN`.
///
/// **Five of these eight are also on the settings screen and three are not**
/// (D105). The three are `Rehearse`, `Demo` and `Start at Disc`, which are the
/// three that do not persist and are the three that describe *this* run — so a
/// menu you open on the way to a burn is the right and only place for them, and
/// the settings screen says so in as many words rather than leaving somebody
/// hunting for a switch that was never going to be there.
struct BurnCommands: Commands {
    let model: PanelModel

    var body: some Commands {
        CommandMenu("Burn") {
            Button("Plan a Burn") { model.openPlan() }
                .disabled(model.record == nil || model.plan != nil || model.isBurning)

            Divider()

            // Not while a job is running: it has its own copy on another
            // thread, and a switch that moved under it would be one that lied.
            Group {
                Toggle("Rehearse — Laser Off", isOn: option(\.rehearsal))
                Toggle("Verify After Burning", isOn: option(\.verify))
                Toggle("Write CD-Text", isOn: option(\.cdText))
                Toggle(
                    "Split Long Tracks",
                    isOn: Binding(
                        get: { model.burnOptions.splitLong },
                        set: { model.setSplitLong($0) }))

                Picker("Level Loudness", selection: option(\.level)) {
                    Text("Off").tag(LevelMode.off)
                    Text("Album — One Gain for All").tag(LevelMode.album)
                    Text("Track — Each on Its Own").tag(LevelMode.track)
                }

                // Only against a plan: the discs are the plan's, and there is no
                // disc two until there is a plan to have one.
                Picker(
                    "Start at Disc",
                    selection: Binding(
                        get: { model.burnOptions.from },
                        set: { model.setFromDisc($0) })
                ) {
                    ForEach(1...max(1, model.plan?.plan.discCount ?? 1), id: \.self) { disc in
                        Text("Disc \(disc)").tag(disc)
                    }
                }
                .disabled(model.plan == nil || (model.plan?.plan.discCount ?? 1) < 2)

                Divider()

                Toggle("Check the Blank First", isOn: option(\.mediaCheck))
                Toggle("Demo — No Drive, No Disc", isOn: option(\.demo))
            }
            .disabled(model.isBurning)
        }
    }

    private func option<Value>(_ key: WritableKeyPath<BurnOptions, Value>) -> Binding<Value> {
        Binding(
            get: { model.burnOptions[keyPath: key] },
            set: { value in model.setBurnOptions { $0[keyPath: key] = value } })
    }
}

/// `trap cleanup EXIT` (`player:324`). The app delegate is where macOS
/// guarantees us a call on every exit path that is not a `SIGKILL`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor weak var model: PanelModel?

    /// `applicationShouldTerminate` rather than `applicationWillTerminate` so the
    /// engine can be stopped asynchronously before the scratch directory is
    /// deleted — the script kills mpv before `rm -rf $WORK` for the same reason
    /// (`player:297`).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { @MainActor in
            await model?.cleanup()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
