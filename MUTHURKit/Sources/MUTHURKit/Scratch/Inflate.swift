import Compression
import Foundation

/// Raw DEFLATE, which is what a zip stores and what `COMPRESSION_ZLIB` decodes
/// — the framework's name is for the algorithm, not for the zlib wrapper, and
/// there is no wrapper here to skip.
///
/// System framework, so this is not a dependency in the sense `CLAUDE.md`
/// means: it ships with the OS the app already requires.
enum Inflate {

    /// Decompress a stream, a chunk in and a chunk out, so that a lossless
    /// track is never in memory whole. `next` hands back the following bite of
    /// compressed bytes and an empty array when there are no more; `emit` takes
    /// each bite of the result in order.
    static func run(
        next: () throws -> [UInt8],
        emit: (UnsafeRawBufferPointer) throws -> Void
    ) throws {
        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }
        guard
            compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
                == COMPRESSION_STATUS_OK
        else { throw ZipFailure.damaged }
        defer { compression_stream_destroy(stream) }

        let outputSize = ZipArchive.chunk
        let output = UnsafeMutablePointer<UInt8>.allocate(capacity: outputSize)
        defer { output.deallocate() }

        var input: [UInt8] = []
        var consumed = 0
        var exhausted = false

        stream.pointee.dst_ptr = output
        stream.pointee.dst_size = outputSize
        stream.pointee.src_size = 0

        while true {
            if stream.pointee.src_size == 0 && !exhausted {
                input = try next()
                consumed = 0
                if input.isEmpty { exhausted = true }
            }

            let status: compression_status = try input.withUnsafeBufferPointer { buffer in
                if let base = buffer.baseAddress, consumed < buffer.count {
                    stream.pointee.src_ptr = base.advanced(by: consumed)
                    stream.pointee.src_size = buffer.count - consumed
                }
                let flags = exhausted ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                let before = stream.pointee.src_size
                let status = compression_stream_process(stream, flags)
                consumed += before - stream.pointee.src_size
                guard status != COMPRESSION_STATUS_ERROR else { throw ZipFailure.damaged }
                return status
            }

            let produced = outputSize - stream.pointee.dst_size
            if produced > 0 {
                try emit(UnsafeRawBufferPointer(start: output, count: produced))
                stream.pointee.dst_ptr = output
                stream.pointee.dst_size = outputSize
            }

            if status == COMPRESSION_STATUS_END { return }
            // Nothing in, nothing out, and no more coming: the entry stops
            // before the deflate stream does.
            if produced == 0 && exhausted && stream.pointee.src_size == 0 {
                throw ZipFailure.shortRead
            }
        }
    }
}
