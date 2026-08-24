import Testing

@testable import MUTHURKit

// The parity suites live one per section of docs/parity.md:
//
//   TrackRulesTests    §3    the rules on one file, and `sort -V`
//   RecordOrderingTests §3.1 a folder read whole, degenerate cases included
//   RealMaterialTests  §3    the readers, against files somebody else tagged
//
// This is what is left of the wiring check.
@Test func moduleLinks() {
    #expect(Track.noNumber == 9999)
}
