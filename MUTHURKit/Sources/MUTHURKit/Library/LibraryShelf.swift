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

    public init(_ library: Library) {
        var sections: [Section] = []
        var first = 0
        for directory in library.directories {
            let section = Section(
                directory: directory, albums: Library.filed(directory.albums), first: first)
            sections.append(section)
            first += section.slots
        }
        self.sections = sections
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

    /// Which lines are on the screen: from `top`, as many as `budget` grid
    /// rows hold, with each line as tall as `height` says.
    ///
    /// **The window moves only as far as the cursor makes it**, which is not
    /// the picker's rule. The picker centres its cursor, and on a list of one
    /// line per row that is steady. On a grid it is not: every `↓` would move
    /// the whole shelf by a row of sleeves, and the thing you are looking for
    /// would never be where you last saw it.
    public static func window(
        heights: [Int], top: Int, budget: Int, keeping cursor: Int?
    ) -> (top: Int, visible: Range<Int>) {
        guard !heights.isEmpty else { return (0, 0..<0) }
        var top = min(max(0, top), heights.count - 1)
        if let cursor, heights.indices.contains(cursor) {
            if cursor < top { top = cursor }
            // A cursor below the fold pulls the top down until the cursor's line
            // is whole on the screen, or until it is the top line and is simply
            // taller than the screen.
            while top < cursor, fits(heights, from: top, through: cursor) > budget {
                top += 1
            }
        }
        // Never a window scrolled past the point where the last line is on the
        // screen: a shelf with its foot at the top of the glass and nothing
        // below is empty space the wheel put there.
        while top > 0, fits(heights, from: top - 1, through: heights.count - 1) <= budget {
            top -= 1
        }
        var end = top
        var used = 0
        while end < heights.count, used + heights[end] <= budget || end == top {
            used += heights[end]
            end += 1
        }
        return (top, top..<end)
    }

    private static func fits(_ heights: [Int], from: Int, through: Int) -> Int {
        heights[from...through].reduce(0, +)
    }
}
