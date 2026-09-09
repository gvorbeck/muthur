import Foundation

/// §20 stage 2 — one continuous WAV per disc, and the sector arithmetic that
/// turns a stream of tracks into index marks in it.
///
/// `le32` (`burncd:2002`), `wav_header` (`burncd:2011`), `patch_le32`
/// (`burncd:2025`) and `msf` (`burncd:156`).
///
/// **One image rather than a file per track**, and the script gives two reasons
/// at `burncd:2478` that are really the same reason twice: `cdrecord` writes
/// CD-Text only from a cue sheet and a cue sheet must point at a single file,
/// and a single file is genuinely gapless because a track boundary becomes an
/// index mark in one stream rather than a separate write with a drive's idea of
/// a gap between. **The gap is not a flag that was turned off** — there is
/// nowhere for one to be, which is a stronger guarantee than any option.
public enum DiscImage {

    /// The canonical 44-byte PCM header. Every field is fixed by Red Book
    /// except the two lengths, and those are patched in afterwards by `finish`.
    public static let headerBytes = 44

    // MARK: - The header

    /// Little-endian 32-bit, the byte order every field in a RIFF header is
    /// written in (`le32`, `burncd:2002`).
    static func le32(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value & 255),
            UInt8((value >> 8) & 255),
            UInt8((value >> 16) & 255),
            UInt8((value >> 24) & 255),
        ]
    }

    /// A canonical 44-byte PCM WAV header (`wav_header`, `burncd:2011`).
    ///
    /// **Both size fields are zero**, exactly as the script writes them, and
    /// they are patched by `finish` once the real data length is known — **so
    /// the image can be written in a single streaming pass instead of being
    /// assembled twice**, which on a full disc is the difference between 800 MB
    /// of writing and 1.6 GB of it. A header carrying zeros is a WAV no player
    /// will open, which is the correct state for a file that is not finished.
    public static func wavHeader(dataBytes: Int = 0) -> Data {
        var bytes: [UInt8] = []
        bytes += Array("RIFF".utf8)
        bytes += le32(riffSize(dataBytes: dataBytes))
        bytes += Array("WAVEfmt ".utf8)
        bytes += le32(16)
        // PCM, 2 channels.
        bytes += [0x01, 0x00, 0x02, 0x00]
        bytes += le32(44100)
        bytes += le32(UInt32(BurnLimits.bytesPerSecond))
        // Block align 4, 16 bits.
        bytes += [0x04, 0x00, 0x10, 0x00]
        bytes += Array("data".utf8)
        bytes += le32(UInt32(clamping: dataBytes))
        return Data(bytes)
    }

    /// The `RIFF` chunk's length: everything after those first eight bytes,
    /// which is the data plus the 36 bytes of header that follow them
    /// (`burncd:2536`).
    ///
    /// Zero data is the one case where this is not `36`: an image with nothing
    /// in it has not been finished, and the unpatched header says so by having
    /// both fields still zero.
    static func riffSize(dataBytes: Int) -> UInt32 {
        UInt32(clamping: dataBytes == 0 ? 0 : dataBytes + 36)
    }

    /// Where the two patched fields live (`burncd:2537`).
    static let riffSizeOffset = 4
    static let dataSizeOffset = 40

    // MARK: - Sectors

    /// Sectors → `MM:SS:FF`, the addressing a cue sheet uses at 75 frames a
    /// second (`msf`, `burncd:156`).
    ///
    /// Not clamped at 99 minutes. A disc holds 79:57 and the plan will not
    /// build a longer one, so a three-digit minute here would mean the layout
    /// was already wrong — and printing `100:00:00` where that happened is a
    /// better bug report than silently wrapping to `00:00:00`.
    public static func msf(sectors: Int) -> String {
        let frames = BurnLimits.framesPerSecond
        let perMinute = frames * 60
        return String(
            format: "%02d:%02d:%02d",
            sectors / perMinute, sectors % perMinute / frames, sectors % frames
        )
    }

    /// How much silence a track needs after it so the next one starts on a
    /// sector boundary (`burncd:2528`).
    ///
    /// The same job `cdrecord -pad` used to do, moved here where the offsets
    /// are computed — because the offsets are what it is *for*, and a pad
    /// applied by the burner is a pad the cue sheet did not know about.
    static func padding(after dataBytes: Int) -> Int {
        let remainder = dataBytes % BurnLimits.sector
        return remainder == 0 ? 0 : BurnLimits.sector - remainder
    }

    /// What one disc's image will weigh, before a byte of it exists.
    ///
    /// Uncompressed audio is one rate and one rate only, so a runtime is a byte
    /// count (`burncd:2405`). Used to refuse a conversion that has nowhere to
    /// land rather than discovering it at ninety percent.
    public static func imageBytes(seconds: Int) -> Int {
        seconds * BurnLimits.bytesPerSecond + headerBytes
    }
}

/// The image being built, and the track starts it collects on the way.
///
/// Stateful on purpose: the script's loop appends to `$IMAGE`, reads the file's
/// size back to find where the next track begins, and pads — and the order of
/// those three is the whole correctness of the offsets. Wrapping them in one
/// object is what stops a later edit from doing them in the wrong order.
public final class ImageWriter {

    public let url: URL
    private let handle: FileHandle
    private var closed = false

    /// Where each track begins, in sectors, in the order they were written.
    /// The cue sheet's `INDEX 01` values.
    public private(set) var starts: [Int] = []

    /// How many bytes of audio are in the image so far — the file's size less
    /// the header, which is what the script reads back with `file_size`
    /// (`burncd:2495`).
    public private(set) var dataBytes = 0

    public enum Failure: Error, CustomStringConvertible {
        case cannotCreate(path: String)
        case cannotWrite(path: String)

        public var description: String {
            switch self {
            case .cannotCreate(let path): "cannot open \(path) for the disc image"
            case .cannotWrite(let path): "cannot write to \(path)"
            }
        }
    }

    /// Opens the image and writes the header, with both lengths still zero.
    public init(at url: URL) throws {
        self.url = url
        guard
            FileManager.default.createFile(
                atPath: url.path, contents: DiscImage.wavHeader()
            ),
            let handle = try? FileHandle(forWritingTo: url)
        else { throw Failure.cannotCreate(path: url.path) }
        self.handle = handle
        _ = try? handle.seekToEnd()
    }

    deinit { try? handle.close() }

    /// The file descriptor a converter appends through.
    ///
    /// Handed to `Process.standardOutput`, which dups it — and a dup shares the
    /// file offset, so what the child writes moves this handle's cursor too.
    /// That is why `syncSize` afterwards is a read of the truth and not a guess.
    var sink: FileHandle { handle }

    /// Note where the next track begins, **before** a byte of it is written
    /// (`burncd:2497`).
    ///
    /// The division is exact rather than approximately exact: every track
    /// before this one ended with `padToSector`, so `dataBytes` is a whole
    /// number of sectors here by construction. It is written as the script's
    /// integer division anyway, because that is the arithmetic being ported and
    /// a subtraction that can only ever be zero is not worth a second name.
    public func beginTrack() {
        starts.append(dataBytes / BurnLimits.sector)
    }

    /// Take the file's own size as the truth (`file_size`, `burncd:161`).
    ///
    /// Called after a converter has appended through `sink`: the bytes went in
    /// behind this object's back, and the only honest count is the one the
    /// filesystem has.
    func syncSize() throws {
        guard let end = try? handle.seekToEnd() else {
            throw Failure.cannotWrite(path: url.path)
        }
        dataBytes = max(0, Int(end) - DiscImage.headerBytes)
    }

    public func append(_ data: Data) throws {
        guard !data.isEmpty else { return }
        do {
            try handle.write(contentsOf: data)
        } catch {
            throw Failure.cannotWrite(path: url.path)
        }
        dataBytes += data.count
    }

    /// Pad out to a whole sector so the next track starts aligned
    /// (`burncd:2527`).
    public func padToSector() throws {
        let pad = DiscImage.padding(after: dataBytes)
        guard pad > 0 else { return }
        try append(Data(repeating: 0, count: pad))
    }

    /// Patch the two lengths and close (`patch_le32`, `burncd:2025`, called at
    /// `burncd:2535`).
    public func finish() throws {
        guard !closed else { return }
        closed = true
        try patch(at: DiscImage.riffSizeOffset, DiscImage.riffSize(dataBytes: dataBytes))
        try patch(at: DiscImage.dataSizeOffset, UInt32(clamping: dataBytes))
        try? handle.synchronize()
        try? handle.close()
    }

    private func patch(at offset: Int, _ value: UInt32) throws {
        do {
            try handle.seek(toOffset: UInt64(offset))
            try handle.write(contentsOf: Data(DiscImage.le32(value)))
        } catch {
            throw Failure.cannotWrite(path: url.path)
        }
    }
}
