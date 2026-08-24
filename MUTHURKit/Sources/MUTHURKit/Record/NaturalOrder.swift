import Foundation

/// `sort -V` — the third and last column of the running-order sort
/// (`player:1511`).
///
/// It only ever separates files that agreed on both numbers, which in practice
/// means an album with no track tags at all. A plain byte sort puts
/// `track10.flac` before `track2.flac`, and an album that plays in that order
/// is the single most obvious way for this to look broken.
public enum NaturalOrder {

    public static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let x = Array(a.utf8)
        let y = Array(b.utf8)
        var i = 0, j = 0

        while i < x.count && j < y.count {
            let xDigit = isDigit(x[i])
            let yDigit = isDigit(y[j])

            // A run of digits sorts ahead of anything else, so `2 Track` comes
            // before `Two Track` rather than landing wherever the byte for `2`
            // happens to fall.
            if xDigit != yDigit { return xDigit ? .orderedAscending : .orderedDescending }

            if xDigit {
                let (xVal, xEnd) = digitRun(x, from: i)
                let (yVal, yEnd) = digitRun(y, from: j)
                if xVal != yVal { return xVal < yVal ? .orderedAscending : .orderedDescending }
                // Same value, different spelling: `01` and `1`. Break it on the
                // written length so the comparison is a total order and the sort
                // is reproducible, rather than leaving two files tied.
                let xLen = xEnd - i, yLen = yEnd - j
                if xLen != yLen { return xLen < yLen ? .orderedAscending : .orderedDescending }
                i = xEnd
                j = yEnd
            } else {
                if x[i] != y[j] { return x[i] < y[j] ? .orderedAscending : .orderedDescending }
                i += 1
                j += 1
            }
        }

        let xLeft = x.count - i, yLeft = y.count - j
        if xLeft == yLeft { return .orderedSame }
        return xLeft < yLeft ? .orderedAscending : .orderedDescending
    }

    private static func isDigit(_ b: UInt8) -> Bool { b >= 0x30 && b <= 0x39 }

    /// The value of the digit run starting at `from`, and where it ends.
    /// Saturating rather than overflowing: a filename with forty digits in it
    /// is not a track number, and it is not worth a crash either.
    private static func digitRun(_ bytes: [UInt8], from: Int) -> (UInt64, Int) {
        var value: UInt64 = 0
        var i = from
        var saturated = false
        while i < bytes.count, isDigit(bytes[i]) {
            if !saturated {
                let (m, overflowM) = value.multipliedReportingOverflow(by: 10)
                let (s, overflowA) = m.addingReportingOverflow(UInt64(bytes[i] - 0x30))
                if overflowM || overflowA {
                    value = .max
                    saturated = true
                } else {
                    value = s
                }
            }
            i += 1
        }
        return (value, i)
    }
}
