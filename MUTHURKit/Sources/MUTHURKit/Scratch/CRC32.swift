import Foundation

/// The checksum every zip entry carries, which is the only way to tell a
/// booklet scan that came out whole from one that did not.
///
/// It is what makes "one bad entry is not a bad album" a decision rather than a
/// hope: without it a corrupt entry is written to disk looking exactly like a
/// good one, and the album stops later, somewhere else, for no visible reason.
struct CRC32 {
    private(set) var value: UInt32 = 0

    private static let table: [UInt32] = {
        (0..<256).map { index -> UInt32 in
            var c = UInt32(index)
            for _ in 0..<8 { c = (c & 1 == 1) ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
            return c
        }
    }()

    mutating func update(_ buffer: UnsafeRawBufferPointer) {
        var c = ~value
        for byte in buffer {
            c = CRC32.table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
        }
        value = ~c
    }
}
