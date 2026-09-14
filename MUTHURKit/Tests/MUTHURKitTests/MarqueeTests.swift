import Foundation
import Testing

@testable import MUTHURKit

// MARK: - §10 A cut title, moving (D89)

@Suite("§10 — the marquee")
struct MarqueeTests {

    @Test("A title that fits does not move, and is drawn as it always was")
    func fitsStaysPut() {
        #expect(!Marquee.runs("Short", in: 10))
        #expect(!Marquee.runs("Exactly10!", in: 10))
        #expect(Marquee.runs("Eleven wide", in: 10))
        #expect(Marquee.window("Short", columns: 10, offset: 7) == Columns.fit("Short", to: 10))
    }

    @Test("The window walks the title and its gap, and comes round")
    func walks() {
        let title = "ABCDEFGH"
        #expect(Marquee.window(title, columns: 5, offset: 0) == "ABCDE")
        #expect(Marquee.window(title, columns: 5, offset: 1) == "BCDEF")
        #expect(Marquee.window(title, columns: 5, offset: 5) == "FGH  ")
        #expect(Marquee.window(title, columns: 5, offset: 8) == "   AB")
        #expect(Marquee.window(title, columns: 5, offset: Marquee.lap(title)) == "ABCDE")
    }

    /// The whole reason it is a column function: the artist beside it must
    /// not move, so the window is exactly as wide as the column at every step.
    @Test("Every step is exactly the column's width, wide characters included")
    func alwaysTheColumnsWidth() {
        for title in ["ABCDEFGHIJKL", "東京事変の教育という名前", "a東b京c事d変e"] {
            for columns in [4, 5, 7] {
                for offset in 0..<(Marquee.lap(title) * 2) {
                    let window = Marquee.window(title, columns: columns, offset: offset)
                    #expect(Columns.width(of: window) == columns, "\(title) @\(offset)")
                }
            }
        }
    }

    @Test("A wide character cut by either edge is a blank, not half a glyph")
    func wideAtTheEdges() {
        let title = "東京事変教育"
        #expect(Marquee.window(title, columns: 5, offset: 0) == "東京 ")
        #expect(Marquee.window(title, columns: 5, offset: 1) == " 京事")
    }

    @Test("It rests at the start, then moves a place at a time, then laps")
    func timing() {
        let lap = 20
        #expect(Marquee.offset(elapsed: 0, lap: lap) == 0)
        #expect(Marquee.offset(elapsed: Marquee.hold - 0.01, lap: lap) == 0)
        #expect(Marquee.offset(elapsed: Marquee.hold + 1 / Marquee.rate + 0.001, lap: lap) == 1)
        let cycle = Marquee.hold + Double(lap) / Marquee.rate
        #expect(Marquee.offset(elapsed: cycle - 0.001, lap: lap) == lap - 1)
        #expect(Marquee.offset(elapsed: cycle + 0.01, lap: lap) == 0)
        #expect(Marquee.offset(elapsed: 5, lap: 0) == 0)
    }
}
