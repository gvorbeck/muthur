import Foundation
import Testing

@testable import MUTHURKit

/// §20 stage 2, rules tier — the image, the cue sheet and the arithmetic that
/// joins them, none of which needs a decoder or a disc.
///
/// Everything here is `Data` and `String`. The half of stage 2 that genuinely
/// needs ffmpeg is `BurnConversionTests`, and it is gated on ffmpeg being
/// installed; this file must pass on any machine.
@Suite("§20 stage 2 — the image and the cue")
struct BurnImageTests {

    private static func scratch() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "muthur-image-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - The header

    @Test("le32 is little-endian, four bytes, always")
    func littleEndian() {
        #expect(DiscImage.le32(0) == [0, 0, 0, 0])
        #expect(DiscImage.le32(1) == [1, 0, 0, 0])
        #expect(DiscImage.le32(44100) == [0x44, 0xAC, 0, 0])
        #expect(DiscImage.le32(176_400) == [0x10, 0xB1, 0x02, 0])
        #expect(DiscImage.le32(.max) == [255, 255, 255, 255])
    }

    /// Byte for byte against `wav_header` (`burncd:2011`), because a WAV header
    /// is one of the few things in this port where the specification really is
    /// a list of bytes and "roughly right" is a file nothing opens.
    @Test("The header is 44 bytes of Red Book, with both lengths still zero")
    func header() {
        let header = Array(DiscImage.wavHeader())
        #expect(header.count == DiscImage.headerBytes)
        #expect(Array(header[0..<4]) == Array("RIFF".utf8))
        #expect(Array(header[4..<8]) == [0, 0, 0, 0])
        #expect(Array(header[8..<16]) == Array("WAVEfmt ".utf8))
        // Chunk size 16, PCM, two channels.
        #expect(Array(header[16..<20]) == [16, 0, 0, 0])
        #expect(Array(header[20..<24]) == [1, 0, 2, 0])
        // 44100 Hz, 176400 bytes a second.
        #expect(Array(header[24..<28]) == DiscImage.le32(44100))
        #expect(Array(header[28..<32]) == DiscImage.le32(176_400))
        // Block align 4, 16 bits a sample.
        #expect(Array(header[32..<36]) == [4, 0, 16, 0])
        #expect(Array(header[36..<40]) == Array("data".utf8))
        #expect(Array(header[40..<44]) == [0, 0, 0, 0])
    }

    /// 44100 × 2 × 2, and the sector it has to divide into.
    @Test("A second of CD audio is 176,400 bytes and 75 sectors")
    func rates() {
        #expect(BurnLimits.bytesPerSecond == 44100 * 2 * 2)
        #expect(BurnLimits.sector == 2352)
        #expect(BurnLimits.framesPerSecond == 75)
        #expect(BurnLimits.bytesPerSecond == BurnLimits.sector * BurnLimits.framesPerSecond)
    }

    // MARK: - MSF

    /// The script's own arithmetic, `$1/4500 : $1%4500/75 : $1%75`
    /// (`burncd:156`).
    @Test("Sectors read out as MM:SS:FF")
    func msf() {
        #expect(DiscImage.msf(sectors: 0) == "00:00:00")
        #expect(DiscImage.msf(sectors: 1) == "00:00:01")
        #expect(DiscImage.msf(sectors: 74) == "00:00:74")
        #expect(DiscImage.msf(sectors: 75) == "00:01:00")
        #expect(DiscImage.msf(sectors: 4500) == "01:00:00")
        #expect(DiscImage.msf(sectors: 4574) == "01:00:74")
        // A full disc: 4797 seconds is 359,775 sectors, which reads 79:57:00.
        #expect(DiscImage.msf(sectors: BurnLimits.capacity * 75) == "79:57:00")
    }

    /// Not clamped at 99 minutes. A layout that produced this was already
    /// wrong, and `100:00:00` is a better bug report than a wrap to zero.
    @Test("Past a hundred minutes it says so rather than wrapping")
    func msfPastTheEnd() {
        #expect(DiscImage.msf(sectors: 100 * 4500) == "100:00:00")
    }

    // MARK: - Sector alignment

    @Test("Padding takes a track up to a whole sector and no further")
    func padding() {
        #expect(DiscImage.padding(after: 0) == 0)
        #expect(DiscImage.padding(after: 2352) == 0)
        #expect(DiscImage.padding(after: 2353) == 2351)
        #expect(DiscImage.padding(after: 1) == 2351)
        #expect(DiscImage.padding(after: 4703) == 1)
    }

    /// Every track starts on a sector, which is what makes the offsets the cue
    /// sheet writes exact rather than nearly exact.
    @Test("Track starts land on sectors whatever lengths went in")
    func starts() throws {
        let work = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: work) }

        let writer = try ImageWriter(at: work.appending(path: "disc1.wav"))
        // Deliberately none of these is a whole sector.
        for length in [1000, 5000, 2353, 7] {
            writer.beginTrack()
            try writer.append(Data(repeating: 0, count: length))
            try writer.padToSector()
        }
        try writer.finish()

        #expect(writer.starts == [0, 1, 4, 6])
        #expect(writer.dataBytes % BurnLimits.sector == 0)
        #expect(writer.dataBytes == 7 * BurnLimits.sector)
    }

    /// The two patched fields are the whole reason the image can be written
    /// once instead of twice (`patch_le32`, `burncd:2025`).
    @Test("Finishing patches the two lengths and nothing else")
    func patched() throws {
        let work = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: work) }

        let url = work.appending(path: "disc1.wav")
        let writer = try ImageWriter(at: url)
        writer.beginTrack()
        try writer.append(Data(repeating: 0x7F, count: BurnLimits.sector))
        try writer.finish()

        let written = Array(try Data(contentsOf: url))
        #expect(written.count == DiscImage.headerBytes + BurnLimits.sector)
        #expect(Array(written[4..<8]) == DiscImage.le32(UInt32(BurnLimits.sector + 36)))
        #expect(Array(written[40..<44]) == DiscImage.le32(UInt32(BurnLimits.sector)))
        // Everything between the two patches is the header it always was.
        #expect(Array(written[8..<40]) == Array(DiscImage.wavHeader()[8..<40]))
        // And the audio is untouched.
        #expect(written[44...].allSatisfy { $0 == 0x7F })
    }

    /// Ten megabytes a minute, near enough, and the check that uses it.
    @Test("A runtime is a byte count, because there is only one bitrate")
    func size() {
        #expect(DiscImage.imageBytes(seconds: 0) == 44)
        #expect(DiscImage.imageBytes(seconds: 60) == 60 * 176_400 + 44)
        // A full disc is about 800 MB, which is the figure the script quotes.
        let full = DiscImage.imageBytes(seconds: BurnLimits.capacity)
        #expect(full > 800_000_000 && full < 850_000_000)
    }

    @Test("Free space is reported the way the script's message reads it")
    func human() {
        #expect(TempSpace.human(1_073_741_824) == "1.0 GB")
        #expect(TempSpace.human(0) == "0.0 GB")
        #expect(TempSpace.human(805_000_000) == "0.7 GB")
    }

    /// The check refuses before a byte is decoded, and its message carries the
    /// remedy on the second line (`burncd:2412`).
    @Test("A volume that cannot hold the image is refused up front")
    func noRoom() throws {
        let work = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: work) }

        // Three years of continuous audio — seventeen petabytes of it. The
        // figure is absurd on purpose: a test that asserts "this volume is too
        // small" has to name a size no volume anybody runs this on could
        // possibly have, or it is a test that passes until somebody buys a
        // bigger disk.
        #expect(throws: TempSpace.TooSmall.self) {
            try TempSpace.check(disc: 1, seconds: 100_000_000, in: work)
        }
        // A single second is not a burn anything will refuse.
        try TempSpace.check(disc: 1, seconds: 1, in: work)

        let failure = TempSpace.TooSmall(
            disc: 2, need: 850_000_000, have: 1_000_000, directory: "/tmp/x"
        )
        #expect(failure.description.contains("disc 2 needs 0.8 GB of temp space"))
        #expect(failure.description.contains("only 0.0 GB free"))
        #expect(failure.description.contains("Free some space"))
    }

    // MARK: - The cue sheet

    private static func discText(
        album: String = "A Record", artist: String = "Someone", year: String = "1979",
        titles: [String] = ["One", "Two"]
    ) -> DiscText {
        DiscText.make(
            disc: 1,
            entries: titles.enumerated().map { index, title in
                BurnPlan.Entry(
                    source: index, title: title, artist: artist, duration: 100,
                    offset: nil, length: nil, disc: 1
                )
            },
            album: album, albumArtist: artist, year: year
        )
    }

    /// The whole file, in the script's order (`write_cue`, `burncd:2141`).
    @Test("A cue sheet reads exactly as the script writes it")
    func cue() {
        let cue = CueSheet.text(
            Self.discText(), imageName: "disc1.wav", starts: [0, 7500]
        )
        #expect(cue == """
            REM DATE 1979
            PERFORMER "Someone"
            TITLE "A Record"
            FILE "disc1.wav" WAVE
              TRACK 01 AUDIO
                TITLE "One"
                PERFORMER "Someone"
                INDEX 01 00:00:00
              TRACK 02 AUDIO
                TITLE "Two"
                PERFORMER "Someone"
                INDEX 01 01:40:00

            """)
    }

    /// The year is the one field CD-Text has nowhere to put, so it can only be
    /// a comment — and a comment costs the lead-in nothing, which is why it
    /// survives every rung of the shedding ladder.
    @Test("The year is a REM, and only a REM")
    func date() {
        let cue = CueSheet.text(Self.discText(), imageName: "disc1.wav", starts: [0, 1])
        #expect(cue.hasPrefix("REM DATE 1979\n"))
        #expect(!cue.contains("DATE \""))

        let undated = CueSheet.text(
            Self.discText(year: ""), imageName: "disc1.wav", starts: [0, 1]
        )
        #expect(!undated.contains("REM"))
        #expect(undated.hasPrefix("PERFORMER"))
    }

    /// A field nothing survived is left out rather than written empty: the
    /// player shows the same nothing either way, and the cue sheet stays honest
    /// about what it carries (`burncd:2156`).
    @Test("An empty field is absent, not blank")
    func empty() {
        let text = DiscText.make(
            disc: 1,
            entries: [
                BurnPlan.Entry(
                    source: 0, title: "Untitled", artist: "", duration: 100,
                    offset: nil, length: nil, disc: 1
                )
            ],
            album: "", albumArtist: "", year: ""
        )
        let cue = CueSheet.text(text, imageName: "disc1.wav", starts: [0])
        #expect(!cue.contains("\"\""))
        #expect(!cue.contains("PERFORMER"))
        #expect(cue.hasPrefix("FILE \"disc1.wav\" WAVE\n"))
        #expect(cue.contains("  TRACK 01 AUDIO\n    TITLE \"Untitled\"\n    INDEX 01 00:00:00"))
    }

    /// The bottom rung of §20.3's ladder gives up every name. The disc still
    /// needs all of its `TRACK` and `INDEX` lines, because those are what tell
    /// the burner where the tracks are.
    @Test("A disc with no CD-Text left still has all its index marks")
    func noText() {
        let text = DiscText.make(
            disc: 1,
            entries: (0..<3).map {
                BurnPlan.Entry(
                    source: $0, title: "T\($0)", artist: "A", duration: 100,
                    offset: nil, length: nil, disc: 1
                )
            },
            album: "A Record", albumArtist: "Someone", year: "1979",
            enabled: false
        )
        let cue = CueSheet.text(text, imageName: "disc1.wav", starts: [0, 100, 200])
        #expect(!cue.contains("TITLE"))
        #expect(!cue.contains("PERFORMER"))
        #expect(cue.contains("REM DATE 1979"))
        #expect(cue.contains("  TRACK 03 AUDIO"))
        #expect(cue.components(separatedBy: "INDEX 01").count == 4)
    }

    /// A path in the `FILE` line is a cue sheet that stops working the moment
    /// the image moves, which `MUTHUR_KEEP` invites somebody to do
    /// (`burncd:2160`).
    @Test("FILE names the image and not where it happens to be today")
    func bareFilename() {
        let cue = CueSheet.text(Self.discText(), imageName: "disc2.wav", starts: [0, 1])
        #expect(cue.contains("FILE \"disc2.wav\" WAVE"))
        #expect(!cue.contains("/"))
    }

    // MARK: - The filter

    /// ffmpeg does **not** dither by default, so a 24-bit source would be
    /// truncated to 16 and be quietly grainy about it (`burncd:2513`).
    @Test("Triangular dither is always asked for, by name")
    func dither() {
        for gain in ["0.0", "3.5", "-2.0", "-0.0"] {
            #expect(Converter.filter(gain: gain).contains("dither_method=triangular"))
        }
    }

    /// A gain of zero is no filter at all, and any other gain goes in ahead of
    /// the dither and in floating point, so quantisation happens exactly once.
    @Test("The gain goes in before the dither, in float")
    func filterOrder() {
        #expect(
            Converter.filter(gain: "0.0")
                == "aresample=out_sample_fmt=s16:dither_method=triangular"
        )
        #expect(
            Converter.filter(gain: "3.5")
                == "aformat=sample_fmts=fltp,volume=3.5dB,"
                    + "aresample=out_sample_fmt=s16:dither_method=triangular"
        )
        // The string comparison is the script's, so -0.0 takes the volume path.
        // A no-op filter applied for nothing, kept because diverging here would
        // let the two programs write different images from the same record.
        #expect(Converter.filter(gain: "-0.0").contains("volume=-0.0dB"))
    }

    @Test("A whole file is converted whole; a slice seeks before it opens")
    func arguments() {
        let whole = BurnPlan.Entry(
            source: 0, title: "One", artist: "A", duration: 100,
            offset: nil, length: nil, disc: 1
        )
        let file = URL(fileURLWithPath: "/music/one.flac")
        let plain = Converter.arguments(for: whole, file: file, gain: "0.0")
        #expect(!plain.contains("-ss"))
        #expect(!plain.contains("-t"))
        // The first audio stream and only it: a file with a cover image in it
        // is a file with a video stream in it.
        #expect(plain.contains("a:0"))
        // Red Book out, raw, on stdout — nothing here writes a container.
        #expect(
            Array(plain.suffix(11))
                == [
                    "-af", Converter.filter(gain: "0.0"),
                    "-ar", "44100", "-ac", "2",
                    "-c:a", "pcm_s16le", "-f", "s16le", "-",
                ]
        )

        let slice = BurnPlan.Entry(
            source: 0, title: "One (part 2/2)", artist: "A", duration: 100,
            offset: 600, length: 100, disc: 2
        )
        let cut = Converter.arguments(for: slice, file: file, gain: "1.0")
        // -ss before -i is a demuxer seek; after it, a decode-and-discard of
        // everything up to that point.
        let ss = try! #require(cut.firstIndex(of: "-ss"))
        let input = try! #require(cut.firstIndex(of: "-i"))
        let length = try! #require(cut.firstIndex(of: "-t"))
        #expect(ss < input)
        #expect(input < length)
        #expect(cut[ss + 1] == "600")
        #expect(cut[length + 1] == "100")
    }
}
