import Foundation

/// The library as it is laid out on the screen: one section per directory, in
/// the order they were added, and the records in each filed by `Library.filed`.
/// **D91.**
///
/// Arithmetic only, the way `PanelGrid` and `Cursor` are, so that where the
/// cursor goes on `↓` is a thing the suite can be asked about rather than a
/// property of a layout pass.
///
/// **A directory with nothing in it still takes a place the cursor can stand
/// on.** A directory not yet walked, or walked and empty, is exactly the one
/// you may want to take off again — and `X` removes the directory the cursor
/// is in, so a directory the cursor cannot reach is one that cannot be removed
/// from the keyboard.
public struct LibraryShelf: Sendable, Equatable {

    public struct Section: Sendable, Equatable, Identifiable {
        public let directory: Library.Directory
        /// Filed, not walked order.
        public let albums: [Library.Album]
        /// Where this section's first slot is in the flat list.
        public let first: Int

        public var id: UUID { directory.id }
        /// An empty section is one slot, the line that says it is empty.
        public var slots: Int { max(1, albums.count) }
    }

    public let sections: [Section]

    /// `query` narrows the shelf to the records it finds (**D93**). An empty or
    /// blank one is the whole shelf, empty directories and all.
    public init(_ library: Library, matching query: String = "") {
        let terms = Self.terms(query)
        var sections: [Section] = []
        var first = 0
        for directory in library.directories {
            let albums = terms.isEmpty ? directory.albums : directory.albums.filter { Self.matches($0, terms) }
            // **A search leaves out the directories it found nothing in**,
            // where the whole shelf keeps them as a slot each. The slot exists
            // so that `X` can reach an empty directory; a directory that is only
            // empty of *this* query is not one anybody came here to remove, and
            // a wall of `NOTHING IN IT` lines would bury the three records that
            // did match.
            if !terms.isEmpty, albums.isEmpty { continue }
            let section = Section(directory: directory, albums: Library.filed(albums), first: first)
            sections.append(section)
            first += section.slots
        }
        self.sections = sections
    }

    // MARK: - Finding (D93)

    /// The words of a query, folded the way `matches` folds what it is held
    /// against.
    public static func terms(_ query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map { fold(String($0)) }
    }

    /// **Every word, somewhere in the record** — its title, its artist, or its
    /// path under the directory. In any order and in any of the three, so `cure
    /// disintegration` and `disintegration cure` find the same record, and so
    /// does `flac cure` on a drive filed by format. The path is in it because
    /// it is the third field on the screen, and because a record nobody has
    /// tagged is known by nothing else.
    ///
    /// Case and accents are both let go of: nobody types `Motörhead` into a
    /// search to mean it strictly.
    public static func matches(_ album: Library.Album, _ terms: [String]) -> Bool {
        let haystack = fold("\(album.title)\n\(album.artist)\n\(album.path)")
        return terms.allSatisfy { haystack.contains($0) }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// Every slot, records and empty directories alike.
    public var count: Int { sections.last.map { $0.first + $0.slots } ?? 0 }

    /// How many records, which is what the faceplate counts.
    public var records: Int { sections.reduce(0) { $0 + $1.albums.count } }

    public enum Slot: Sendable, Equatable {
        case album(section: Int, Library.Album)
        case empty(section: Int)

        public var section: Int {
            switch self {
            case .album(let section, _), .empty(let section): section
            }
        }

        public var album: Library.Album? {
            if case .album(_, let album) = self { return album }
            return nil
        }
    }

    public func slot(_ index: Int) -> Slot? {
        guard let section = sectionIndex(of: index) else { return nil }
        let s = sections[section]
        let offset = index - s.first
        return s.albums.isEmpty ? .empty(section: section) : .album(section: section, s.albums[offset])
    }

    public func sectionIndex(of index: Int) -> Int? {
        guard index >= 0, index < count else { return nil }
        return sections.lastIndex { $0.first <= index }
    }

    /// Where a record is now, for keeping the cursor on it across a walk that
    /// has moved everything around it.
    public func index(directory: UUID, path: String) -> Int? {
        guard let s = sections.first(where: { $0.id == directory }) else { return nil }
        return s.albums.firstIndex { $0.path == path }.map { s.first + $0 }
    }

    // MARK: - Lines

    /// One line of the shelf, top to bottom.
    public enum Line: Sendable, Equatable {
        /// The directory's rule: its path, its count, whether it is there.
        case rule(section: Int)
        /// A row of sleeves.
        case tiles(section: Int, row: Int)
        /// The line an empty directory gets instead of sleeves.
        case empty(section: Int)
    }

    public func lines(perRow: Int) -> [Line] {
        let perRow = max(1, perRow)
        var lines: [Line] = []
        for (index, section) in sections.enumerated() {
            lines.append(.rule(section: index))
            if section.albums.isEmpty {
                lines.append(.empty(section: index))
            } else {
                for row in 0..<rows(section.albums.count, perRow) {
                    lines.append(.tiles(section: index, row: row))
                }
            }
        }
        return lines
    }

    /// The slots a line holds.
    public func slots(on line: Line, perRow: Int) -> Range<Int> {
        let perRow = max(1, perRow)
        switch line {
        case .rule: return 0..<0
        case .empty(let section):
            let first = sections[section].first
            return first..<first + 1
        case .tiles(let section, let row):
            let s = sections[section]
            let start = s.first + row * perRow
            return start..<min(start + perRow, s.first + s.albums.count)
        }
    }

    /// Which line the slot is drawn on.
    public func line(of index: Int, perRow: Int) -> Int? {
        let perRow = max(1, perRow)
        guard let section = sectionIndex(of: index) else { return nil }
        var line = 0
        for s in sections.prefix(section) {
            line += 1 + (s.albums.isEmpty ? 1 : rows(s.albums.count, perRow))
        }
        let s = sections[section]
        return line + 1 + (s.albums.isEmpty ? 0 : (index - s.first) / perRow)
    }

    private func rows(_ count: Int, _ perRow: Int) -> Int { (count + perRow - 1) / perRow }

    // MARK: - The cursor

    public enum Move: Sendable, Equatable {
        case left, right, up, down
    }

    /// Where the cursor goes.
    ///
    /// `←→` run along the flat list, off the end of one row and onto the next,
    /// and across a directory's rule into the next directory: a shelf read left
    /// to right does not stop at the bookend. `↑↓` keep the column, and on a
    /// shorter row — the last of a section, or an empty directory — land on the
    /// nearest slot there is. Nothing wraps from the last slot to the first;
    /// the cursor stops, the way it does in every list on the panel.
    public func moved(_ index: Int, _ move: Move, perRow: Int) -> Int {
        let perRow = max(1, perRow)
        guard count > 0 else { return 0 }
        let index = min(max(index, 0), count - 1)
        switch move {
        case .left: return max(0, index - 1)
        case .right: return min(count - 1, index + 1)
        case .up, .down:
            guard let at = line(of: index, perRow: perRow) else { return index }
            let lines = lines(perRow: perRow)
            let column = index - slots(on: lines[at], perRow: perRow).lowerBound
            var next = at
            while true {
                next += move == .down ? 1 : -1
                guard lines.indices.contains(next) else { return index }
                let range = slots(on: lines[next], perRow: perRow)
                if !range.isEmpty { return min(range.lowerBound + column, range.upperBound - 1) }
            }
        }
    }

    // MARK: - The window

    /// **The shelf is scrolled in grid rows, not in lines.** A line is a row of
    /// sleeves — seven rows tall — and a wheel that moved the shelf a whole one
    /// at a time threw the wall a sleeve's height for a flick of the finger and
    /// could not be asked for anything smaller. The row is what the panel is
    /// drawn on and what the wheel already counts in (`PanelView.startWheel`),
    /// so it is what the shelf moves by: one row of glass for one row of wheel.
    ///
    /// `offset` is how many rows of the shelf are above the top of the glass.
    public static func rows(_ heights: [Int]) -> Int { heights.reduce(0, +) }

    /// Where each line's top sits, in rows from the head of the shelf.
    public static func tops(_ heights: [Int]) -> [Int] {
        var tops: [Int] = []
        tops.reserveCapacity(heights.count)
        var row = 0
        for height in heights {
            tops.append(row)
            row += height
        }
        return tops
    }

    /// The lines an offset puts on the glass, and how much of the first one is
    /// above it — what the view shifts the shelf up by to draw a line that is
    /// half on the screen.
    public static func window(
        heights: [Int], offset: Int, budget: Int
    ) -> (visible: Range<Int>, above: Int) {
        guard !heights.isEmpty, budget > 0 else { return (0..<0, 0) }
        let offset = clamp(heights: heights, offset: offset, budget: budget)
        let tops = tops(heights)
        let foot = offset + budget
        guard let first = heights.indices.first(where: { tops[$0] + heights[$0] > offset })
        else { return (0..<0, 0) }
        var end = first
        while end < heights.count, tops[end] < foot { end += 1 }
        return (first..<end, offset - tops[first])
    }

    /// Where the shelf stands after a scroll, and after the cursor has had its
    /// say.
    ///
    /// **The shelf moves only as far as the cursor makes it**, which is not the
    /// picker's rule. The picker centres its cursor, and on a list of one line
    /// per row that is steady. On a grid it is not: every `↓` would move the
    /// whole wall by a row of sleeves, and the thing you are looking for would
    /// never be where you last saw it.
    public static func scrolled(
        heights: [Int], offset: Int, budget: Int, keeping cursor: Int?
    ) -> Int {
        guard !heights.isEmpty, budget > 0 else { return 0 }
        var offset = offset
        if let cursor, heights.indices.contains(cursor) {
            let tops = tops(heights)
            let top = tops[cursor]
            let foot = top + heights[cursor]
            if top < offset { offset = top }
            // A line taller than the glass is shown from its head rather than
            // pinned to its foot: the sleeve, not the blank under it.
            if foot > offset + budget { offset = min(top, foot - budget) }
        }
        return clamp(heights: heights, offset: offset, budget: budget)
    }

    /// Never scrolled past the foot of the shelf — a wall with its last row at
    /// the top of the glass and nothing under it is empty space the wheel put
    /// there — and never above its head.
    private static func clamp(heights: [Int], offset: Int, budget: Int) -> Int {
        min(max(0, offset), max(0, rows(heights) - budget))
    }
}
