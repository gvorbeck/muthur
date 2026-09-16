import AppKit
import MUTHURKit
import Observation

/// **D91** — the library screen's half of the event loop: the directories, what
/// was found in them, where the cursor is, and the two jobs that keep the shelf
/// filled — the walk and the sleeves.
///
/// Its own object rather than more of `PanelModel`, because nothing in here
/// touches the deck: the one thing the library asks of the rest of the program
/// is *open this*, and that is handed in as `opener`.
///
/// **Nothing here touches a volume until the library is opened** (D50). The
/// index is a file in the app's own data directory, but asking whether a
/// directory is there is a stat on a volume, and a stat on a removable volume is
/// what fires the permission prompt D50 took off the launch path. So the first
/// `show` is the first time any of that is asked.
@MainActor
@Observable
final class LibraryModel {

    let file: LibraryFile
    /// Where zip members and tag pictures go while a sleeve is being looked for.
    private let work: URL

    /// Opens a record on the deck. `PanelModel.open(source:kind:)`.
    @ObservationIgnored var opener: (URL, SourceKind) -> Void = { _, _ in }

    /// The index is read now, because it is a file in the app's own data
    /// directory and asking for it touches no volume — and the menu's list of
    /// directories to remove wants it before the shelf has been opened.
    init(file: LibraryFile = .standard(), work: URL) {
        self.file = file
        self.work = work
        library = file.read()
        shelf = LibraryShelf(library)
    }

    // MARK: - What is on the shelf

    private(set) var library = Library()
    /// `library`, laid out. Rebuilt on every change rather than computed on
    /// read, because the panel redraws twenty times a second while a record
    /// plays under it and filing two hundred records is not free.
    private(set) var shelf = LibraryShelf(Library())
    @ObservationIgnored private var watching = false

    private(set) var isOpen = false

    /// The directories that can be walked right now.
    private(set) var reaches: [UUID: LibraryFile.Reach] = [:]

    func isOnline(_ section: LibraryShelf.Section) -> Bool { reaches[section.id] != nil }

    /// Records in directories that are not there, for the faceplate.
    var offline: Int {
        shelf.sections.filter { reaches[$0.id] == nil }.reduce(0) { $0 + $1.albums.count }
    }

    var meta: String { Faceplate.libraryMeta(count: shelf.records, offline: offline) }

    // MARK: - The cursor and the window

    private(set) var cursor = 0
    /// How much of the shelf is above the top of the glass, in grid rows.
    private(set) var offset = 0
    /// Sleeves to a row, and grid rows the shelf may stand in. The view's to
    /// say, because the view is the only thing that knows how big it is.
    private(set) var perRow = 1
    private(set) var budget = 7
    /// Whether the view has said how big it is yet. Until it has, `perRow` and
    /// `budget` are placeholders, and a window worked out from them is wrong in
    /// a way that sticks: a walk landing before the first layout pushed the
    /// top past the first directory's rule, and a window that only moves as
    /// far as the cursor makes it never brought it back.
    @ObservationIgnored private var sized = false

    /// A row of sleeves is the sleeve and a blank under it; a directory's rule
    /// and the line that says it is empty are a line each.
    static let tileRows = 6

    static func height(_ line: LibraryShelf.Line) -> Int {
        switch line {
        case .rule, .empty: 1
        case .tiles: tileRows + 1
        }
    }

    var lines: [LibraryShelf.Line] { shelf.lines(perRow: perRow) }

    private var heights: [Int] { lines.map(Self.height) }

    /// The whole shelf's height in grid rows, and the part of it on the glass.
    var rows: Int { LibraryShelf.rows(heights) }

    var window: (visible: Range<Int>, above: Int) {
        LibraryShelf.window(heights: heights, offset: offset, budget: budget)
    }

    var visible: Range<Int> { window.visible }

    /// Records below the last line on the screen. A line the fold cuts through
    /// is not counted: some of it is on the glass, and `MORE` is about what is
    /// not.
    var below: Int {
        let lines = lines
        let end = visible.upperBound
        guard end < lines.count else { return 0 }
        return (end..<lines.count).reduce(0) { total, index in
            guard case .tiles = lines[index] else { return total }
            return total + shelf.slots(on: lines[index], perRow: perRow).count
        }
    }

    func resized(perRow: Int, budget: Int) {
        guard !sized || perRow != self.perRow || budget != self.budget else { return }
        sized = true
        self.perRow = max(1, perRow)
        self.budget = max(1, budget)
        follow()
    }

    /// Bring the cursor's line on to the screen, moving the shelf no further
    /// than that takes (`LibraryShelf.scrolled`).
    private func follow() {
        guard sized else { return }
        offset = LibraryShelf.scrolled(
            heights: heights, offset: offset, budget: budget,
            keeping: shelf.line(of: cursor, perRow: perRow)
        )
    }

    // MARK: - What the status line says

    /// The answer to the key that was just pressed. Cleared by the next one.
    private(set) var message: String?
    private(set) var walking: String?
    private(set) var sleevesLeft = 0

    var statusLine: String? {
        if let message { return message }
        if let walking { return Readout.status("WALKING \(walking)") }
        if sleevesLeft > 0 {
            return Readout.status("FINDING SLEEVES · \(sleevesLeft) LEFT")
        }
        return nil
    }

    // MARK: - Coming and going

    func show() {
        if !watching {
            watching = true
            watchVolumes()
        }
        isOpen = true
        message = nil
        pendingRemoval = nil
        reach()
        // **Once a session, and not on every open.** A walk of a big drive is a
        // second or two, and the library is a screen you go to and come back
        // from; walking it every time would be making you wait to look at what
        // was already known. `R` is for when you know something changed.
        let unwalked = library.directories.map(\.id).filter { !walked.contains($0) }
        walk(unwalked, retrying: false)
    }

    func close() {
        isOpen = false
        message = nil
        pendingRemoval = nil
    }

    // MARK: - Keys

    func move(_ move: LibraryShelf.Move) {
        settle()
        cursor = shelf.moved(cursor, move, perRow: perRow)
        follow()
    }

    /// A screenful: as many rows of sleeves as are on the screen, less the one
    /// being left, so the row you were on is still in view at the far edge.
    func page(_ move: LibraryShelf.Move) {
        settle()
        let rows = lines[visible].filter { if case .tiles = $0 { true } else { false } }.count
        for _ in 0..<max(1, rows - 1) {
            cursor = shelf.moved(cursor, move, perRow: perRow)
        }
        follow()
    }

    /// Where the pointer is. A click on a sleeve plays it, so the cursor goes
    /// there too — it is where you will be when you come back.
    func point(at index: Int) {
        guard index >= 0, index < shelf.count else { return }
        cursor = index
    }

    /// The wheel moves the shelf and leaves the cursor where it was: a scroll
    /// is looking, not choosing. **A row of glass for a row of wheel** — the
    /// monitor counts the wheel in the panel's own rows, and the shelf moves by
    /// the same ones, so the wall goes exactly as far as the hand did.
    func wheel(_ rows: Int) {
        scroll(to: offset + rows)
    }

    /// Straight to a row of the shelf, which is what the bar does when it is
    /// dragged. Nothing is kept for the cursor: the bar is looking too.
    func scroll(to row: Int) {
        offset = LibraryShelf.scrolled(
            heights: heights, offset: row, budget: budget, keeping: nil)
    }

    /// `⏎`, and a click.
    func play(_ index: Int? = nil) {
        settle()
        let index = index ?? cursor
        guard let slot = shelf.slot(index), let album = slot.album else { return }
        let section = shelf.sections[slot.section]
        cursor = index
        guard let reach = reaches[section.id] else {
            message = Readout.status("OFFLINE — \(section.directory.path)")
            return
        }
        let url = reach.url.appending(path: album.path)
        // The index is a record of what was there at the last walk, and a
        // record can be moved or deleted from Finder since. Said, not opened:
        // `SourceOpener` would say `not found` about a path the user never
        // typed.
        guard FileManager.default.fileExists(atPath: url.path) else {
            message = Readout.status("NOT THERE ANY MORE — R TO RESCAN")
            return
        }
        do {
            let (resolved, kind) = try SourceOpener.resolve(path: url.path)
            isOpen = false
            opener(resolved, kind)
        } catch {
            message = Readout.status("\(error)")
        }
    }

    /// `R` — every directory that is there, walked again, and the records that
    /// came back without a sleeve asked about once more.
    func rescan() {
        settle()
        reach()
        walk(library.directories.map(\.id), retrying: true)
        message = nil
    }

    /// `A`.
    func add() {
        settle()
        let panel = NSOpenPanel()
        panel.message = "A directory of records — folders, zips, or both."
        panel.prompt = "Add"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let directory = try library.add(url, bookmark: LibraryFile.bookmark(for: url))
            changed()
            file.write(library)
            reach()
            if let section = shelf.sections.first(where: { $0.id == directory.id }) {
                cursor = section.first
                follow()
            }
            walk([directory.id], retrying: false)
        } catch {
            switch error {
            case .alreadyThere(let path):
                message = Readout.status("ALREADY IN THE LIBRARY — \(path)")
            case .holdsOneAlready(let path):
                message = Readout.status("ALREADY HOLDS \(path) — REMOVE THAT FIRST")
            }
        }
    }

    private var pendingRemoval: UUID?

    /// `X`, twice. **The second press is the one that does it**, because the
    /// first is so easy to make by accident on a screen where `X` is next to
    /// nothing else the hand is doing, and what it throws away — every sleeve
    /// found for that directory — is the one thing this feature promises never
    /// to fetch twice.
    func remove() {
        guard let slot = shelf.slot(cursor) else { return }
        let directory = shelf.sections[slot.section].directory
        guard pendingRemoval == directory.id else {
            pendingRemoval = directory.id
            // The path last: it is the part the status line cuts, and the
            // directory's rule is on the screen saying it anyway. What must
            // survive the cut is that nothing on the drive is touched.
            message = Readout.status("X AGAIN TO REMOVE · THE RECORDS STAY WHERE THEY ARE · \(directory.path)")
            return
        }
        remove(directory.id)
    }

    /// The menu's remove, which has already been chosen out of a list and does
    /// not ask twice.
    func remove(_ id: UUID) {
        pendingRemoval = nil
        guard let gone = library.remove(id) else { return }
        file.discardCovers(of: gone.albums)
        if let scoped = scopes.removeValue(forKey: id) { scoped.stopAccessingSecurityScopedResource() }
        reaches[id] = nil
        walked.remove(id)
        changed()
        file.write(library)
        cursor = min(cursor, max(0, shelf.count - 1))
        follow()
        message = Readout.status("REMOVED \(gone.path)")
    }

    /// Any key but `X` is a change of mind, and the answer to the last key is
    /// not the answer to this one.
    private func settle() {
        pendingRemoval = nil
        message = nil
    }

    // MARK: - Reaching the directories

    /// The directories whose security scope has been started, kept started for
    /// as long as the directory is in the library: a record played out of one
    /// is read for as long as it plays.
    @ObservationIgnored private var scopes: [UUID: URL] = [:]

    private func reach() {
        var found: [UUID: LibraryFile.Reach] = [:]
        for directory in library.directories {
            guard let reach = LibraryFile.reach(directory) else { continue }
            found[directory.id] = reach
            if reach.scoped, scopes[directory.id] == nil, reach.url.startAccessingSecurityScopedResource() {
                scopes[directory.id] = reach.url
            }
        }
        reaches = found
    }

    @ObservationIgnored private var volumes: [NSObjectProtocol] = []

    /// A drive plugged in with the library up lights its records without a key
    /// being pressed, and one pulled out dims them. Walked the first time it is
    /// seen this session, like any other directory.
    private func watchVolumes() {
        let centre = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            volumes.append(
                centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        self.reach()
                        let unwalked = self.library.directories.map(\.id).filter { !self.walked.contains($0) }
                        self.walk(unwalked, retrying: false)
                    }
                })
        }
    }

    // MARK: - The walk

    /// Walked this session. A directory that was not there when it was due is
    /// not in here, which is what gets it walked when it arrives.
    @ObservationIgnored private var walked: Set<UUID> = []
    @ObservationIgnored private var walks: Task<Void, Never>?

    /// One directory at a time and one walk after another: two walks of one
    /// drive at once are slower than two in a row, and a merge that landed on
    /// top of another would be merging with a list that had just changed.
    private func walk(_ ids: [UUID], retrying: Bool) {
        let previous = walks
        walks = Task {
            await previous?.value
            for id in ids {
                guard let reach = reaches[id],
                    let path = library.directories.first(where: { $0.id == id })?.path
                else { continue }
                walking = path
                let root = reach.url
                let found = await Task.detached(priority: .utility) {
                    LibraryWalk.albums(in: root)
                }.value
                // Removed while it was being walked.
                guard let index = library.directories.firstIndex(where: { $0.id == id }) else { continue }
                // A walk that found nothing in a directory that has gone away
                // under it is not a walk that found the records gone. Only a
                // directory still there is allowed to empty its section.
                guard LibraryFile.reach(library.directories[index]) != nil else { continue }
                var merged = Library.merge(library.directories[index].albums, with: found)
                if retrying {
                    for i in merged.albums.indices where file.cover(merged.albums[i]) == nil {
                        merged.albums[i].coverAsked = false
                        merged.albums[i].cover = nil
                        merged.albums[i].coverSource = nil
                    }
                }
                file.discardCovers(of: merged.dropped)
                changing {
                    library.directories[index].albums = merged.albums
                    library.directories[index].scanned = Date()
                }
                walked.insert(id)
                file.write(library)
            }
            walking = nil
            sleeves()
        }
    }

    // MARK: - The sleeves

    @ObservationIgnored private var sleeveWork: Task<Void, Never>?

    /// Every record not yet asked about, in the order they are on the shelf —
    /// so the sleeves fill in from the top of the screen down, where you are
    /// looking — and only in directories that are there.
    private func wanted(skipping skipped: Set<String>) -> [(id: UUID, album: Library.Album, url: URL)] {
        shelf.sections.flatMap { section -> [(id: UUID, album: Library.Album, url: URL)] in
            guard let reach = reaches[section.id] else { return [] }
            return section.albums
                .filter { !$0.coverAsked && !skipped.contains(Library.coverName(directory: section.id, path: $0.path)) }
                .map { (section.id, $0, reach.url.appending(path: $0.path)) }
        }
    }

    private func sleeves() {
        guard sleeveWork == nil else { return }
        sleeveWork = Task {
            let covers = LibraryCovers(work: work)
            var since = 0
            // Records that went away between the walk and their turn. Not asked
            // about, and not marked asked either — but not tried again this
            // run, or a record deleted from a drive that is still plugged in
            // would be the next one wanted for ever.
            var skipped: Set<String> = []
            while case let left = wanted(skipping: skipped), let next = left.first {
                sleevesLeft = left.count
                let destination = file.covers.appending(
                    path: Library.coverName(directory: next.id, path: next.album.path))
                let album = next.album
                let url = next.url
                let outcome = await Task.detached(priority: .utility) {
                    await covers.find(album, at: url, storingAt: destination)
                }.value
                // A drive pulled out part way through a record is not a record
                // with no sleeve. Left unasked, it is asked again when the drive
                // is back.
                guard FileManager.default.fileExists(atPath: url.path) else {
                    skipped.insert(destination.lastPathComponent)
                    reach()
                    continue
                }
                changing {
                    guard let d = library.directories.firstIndex(where: { $0.id == next.id }),
                        let a = library.directories[d].albums.firstIndex(where: { $0.path == album.path })
                    else { return }
                    library.directories[d].albums[a].apply(
                        outcome, coverName: destination.lastPathComponent)
                }
                since += 1
                // Written as it goes, so a quit halfway through a first walk of
                // a big drive keeps what it had found. Not after every record:
                // the index is rewritten whole each time.
                if since >= 10 {
                    since = 0
                    file.write(library)
                }
                // `ReleaseSearch`'s second between requests. MusicBrainz asks
                // for it, and two hundred records in a row is exactly the case.
                if outcome.askedTheArchive {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            file.write(library)
            sleevesLeft = 0
            sleeveWork = nil
        }
    }

    // MARK: - Keeping the shelf in step

    private func changed() {
        shelf = LibraryShelf(library)
    }

    /// A change to the library, with the cursor kept on the record it was on:
    /// a walk or a sleeve's tags can re-file everything around it.
    private func changing(_ change: () -> Void) {
        let slot = shelf.slot(cursor)
        let at = slot.map { shelf.sections[$0.section].id }
        let path = slot?.album?.path
        change()
        changed()
        if let at, let path, let index = shelf.index(directory: at, path: path) {
            cursor = index
        } else if let at, let section = shelf.sections.first(where: { $0.id == at }) {
            cursor = section.first
        } else {
            cursor = min(cursor, max(0, shelf.count - 1))
        }
        follow()
    }
}
