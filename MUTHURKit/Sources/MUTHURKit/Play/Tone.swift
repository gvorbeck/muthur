import Foundation

/// The mixer: three tone controls between the deck and the volume knob.
///
/// Nothing in `player` corresponds to this — mpv was handed a file and the
/// speakers were somebody else's problem — so there is no behaviour to port and
/// the shape is a listener's: bass, mid, treble, in whole decibels.
///
/// Whole decibels in steps of two because the rocker on the settings screen
/// walks an enumerated list, and twenty-five stops would be a long walk to flat.
/// `±12` is where a shelf stops being tone and starts being clipping.
public struct Tone: Sendable, Equatable, Codable {
    public var bass: Gain
    public var mid: Gain
    public var treble: Gain

    public init(bass: Gain = .flat, mid: Gain = .flat, treble: Gain = .flat) {
        self.bass = bass
        self.mid = mid
        self.treble = treble
    }

    /// Flat is bypassed in the graph, not merely set to 0 dB: a filter at unity
    /// is still a filter, and the gapless suites compare samples.
    public var isFlat: Bool { self == Tone() }

    public struct Gain: Sendable, Equatable, Codable {
        public let decibels: Int
        public static let flat = Gain(decibels: 0)

        /// Clamped, so a value saved by some other build cannot ask the filter
        /// for more than the screen can show.
        public init(decibels: Int) {
            self.decibels = min(max(decibels, Gain.range.lowerBound), Gain.range.upperBound)
        }

        public static let range = -12...12

        /// Every stop on the rocker, lowest first.
        public static let all: [Gain] = stride(from: range.lowerBound, through: range.upperBound, by: 2)
            .map { Gain(decibels: $0) }

        public var label: String {
            decibels == 0 ? "FLAT" : String(format: "%+d dB", decibels)
        }
    }
}
