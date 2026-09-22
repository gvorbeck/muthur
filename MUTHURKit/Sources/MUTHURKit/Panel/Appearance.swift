import Foundation

/// The three knobs that say what the panel is made of, in the kit because
/// `Preferences` has to name them and `Preferences` is tested.
///
/// **They were each declared beside the code that draws them** — `Lettering`
/// above the 5×7 table, `Numerals` above the seven segments, `Composition`
/// above the run-out — and their explanations stay there, at the thing they
/// explain. What moved here is the value and nothing else, on `Tube`'s
/// precedent: a setting about how the panel looks is still a setting, and the
/// kit is where a setting can be round-tripped by a test.
///
/// `label` is the settings screen's word for each case, and is the reason these
/// are not left as bare string enums: a screen that printed `runout` would be
/// showing the person the variable rather than the choice.

/// The lettering on the chrome: labels, legends, the mode stamped on the
/// faceplate (`docs/spec.md:104`). Drawn by `DotMatrix`, which is where the 5×7
/// table and the argument for it live.
public enum Lettering: String, Sendable, Equatable, CaseIterable, Codable {
    /// The face the grid is measured from. The panel's own type, aged and
    /// bloomed with everything else — a character generator is a character
    /// generator, and this one has the advantage of knowing every alphabet.
    case type
    /// The 5×7 table.
    case matrix

    public var label: String {
        switch self {
        case .type: "Type"
        case .matrix: "Dot Matrix"
        }
    }
}

/// The numerals: track numbers, durations, the two counters over the meters
/// (`docs/spec.md:103`). Drawn by `Segments`.
public enum Numerals: String, Sendable, Equatable, CaseIterable, Codable {
    /// Figures in the panel's own face.
    case type
    /// Seven bars and the dark `8` behind them.
    case segment

    public var label: String {
        switch self {
        case .type: "Type"
        case .segment: "Seven Segment"
        }
    }
}

/// What to do with the room under the last track (D26). Drawn by
/// `RunoutField`, which is where the divergence is argued.
public enum Composition: String, Sendable, Equatable, CaseIterable, Codable {
    /// Nothing under the last track, which is what the script does.
    case deck
    /// Fill it with the dead groove at the end of a side. The default.
    case runout

    public var label: String {
        switch self {
        case .deck: "Stop at the Last Track"
        case .runout: "Run Out to the Floor"
        }
    }
}
