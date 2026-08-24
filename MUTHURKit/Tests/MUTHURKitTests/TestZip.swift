import Compression
import Foundation

@testable import MUTHURKit

/// A zip writer that exists only so the reader can be pointed at one.
///
/// Test scaffolding, and deliberately not the app's zip path — §2.2 is about
/// what happens when an archive is *wrong*, and every interesting case here is
/// one no honest archiver will produce for you: an entry whose declared size
/// runs past the end of the file, a CRC that does not match its bytes, an
/// encryption flag over plaintext, a name that climbs out of the folder it was
/// given. Shelling out to `/usr/bin/zip` can make none of them.
struct TestZip {

    struct Member {
        var name: String
        var bytes: [UInt8]
        /// Store by default; the deflate path is exercised where it is the
        /// point of the test.
        var deflate = false
        /// General purpose bit 0, over plaintext. The reader refuses on the
        /// flag alone and never gets as far as the bytes, which is the
        /// behaviour being pinned.
        var encrypted = false
        /// Something neither stored nor deflated: bzip2 is 12.
        var method: UInt16?
        var corruptCRC = false
        /// Claim more compressed bytes than are written, which is what a
        /// truncated archive looks like from the central directory.
        var overclaim: UInt32 = 0

        init(_ name: String, _ text: String) {
            self.name = name
            self.bytes = Array(text.utf8)
        }

        init(_ name: String, bytes: [UInt8]) {
            self.name = name
            self.bytes = bytes
        }
    }

    static func write(_ members: [Member], to url: URL) throws {
        var out: [UInt8] = []
        var directory: [UInt8] = []
        var count = 0

        for member in members {
            let name = Array(member.name.utf8)
            let payload = member.deflate ? deflate(member.bytes) : member.bytes
            let method: UInt16 = member.method ?? (member.deflate ? 8 : 0)
            var crc = CRC32()
            member.bytes.withUnsafeBytes { crc.update($0) }
            let checksum = member.corruptCRC ? crc.value ^ 0xFFFF : crc.value
            let compressed = UInt32(payload.count) + member.overclaim
            let flags: UInt16 = (member.encrypted ? 1 : 0) | 0x0800
            let offset = UInt32(out.count)

            out += le32(0x0403_4b50)
            out += le16(20) + le16(flags) + le16(method) + le16(0) + le16(0x21)
            out += le32(checksum) + le32(compressed) + le32(UInt32(member.bytes.count))
            out += le16(UInt16(name.count)) + le16(0)
            out += name
            out += payload

            directory += le32(0x0201_4b50)
            directory += le16(20) + le16(20) + le16(flags) + le16(method) + le16(0) + le16(0x21)
            directory += le32(checksum) + le32(compressed) + le32(UInt32(member.bytes.count))
            directory += le16(UInt16(name.count)) + le16(0) + le16(0)
            directory += le16(0) + le16(0) + le32(0) + le32(offset)
            directory += name
            count += 1
        }

        let directoryOffset = UInt32(out.count)
        out += directory
        out += le32(0x0605_4b50) + le16(0) + le16(0)
        out += le16(UInt16(count)) + le16(UInt16(count))
        out += le32(UInt32(directory.count)) + le32(directoryOffset) + le16(0)

        try Data(out).write(to: url)
    }

    /// The other half of `Inflate`, which is a useful thing for the deflate
    /// tests to be leaning on: if the two disagree, one of them is wrong.
    static func deflate(_ bytes: [UInt8]) -> [UInt8] {
        guard !bytes.isEmpty else { return [] }
        let capacity = bytes.count + 1024
        var out = [UInt8](repeating: 0, count: capacity)
        let written = out.withUnsafeMutableBufferPointer { destination in
            bytes.withUnsafeBufferPointer { source in
                compression_encode_buffer(
                    destination.baseAddress!, capacity,
                    source.baseAddress!, bytes.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        precondition(written > 0, "the encoder would not compress the fixture")
        return Array(out[0..<written])
    }

    private static func le16(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)]
    }

    private static func le32(_ value: UInt32) -> [UInt8] {
        (0..<4).map { UInt8(value >> ($0 * 8) & 0xFF) }
    }
}

/// A directory that goes away with the test that made it.
final class TempDirectory {
    let url: URL

    init(_ name: String = "muthur-tests") {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "\(name).\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func appending(_ component: String) -> URL { url.appending(path: component) }

    /// A subdirectory, made.
    func directory(_ component: String) -> URL {
        let child = url.appending(path: component)
        try? FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        return child
    }

    deinit { try? FileManager.default.removeItem(at: url) }
}
