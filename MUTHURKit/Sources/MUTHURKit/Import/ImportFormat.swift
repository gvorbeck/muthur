import Foundation

/// §21 — what a track is written as on the way off the disc.
///
/// Neither script has this. `player` reads a disc and `burncd` writes one;
/// taking a disc *and keeping it* is the half of the round trip that was
/// always done with something else, and **D95** is why it is here.
///
/// **The list is short on purpose.** Every entry is a format somebody would
/// actually keep an album in, and nothing is offered because ffmpeg happens to
/// have an encoder for it. Two of the six go through a library that a given
/// ffmpeg build may simply not have been compiled with, which is why
/// `library` exists: a format that cannot be encoded on this machine is a
/// refusal with a name in it, not a job that dies eleven tracks in.
///
/// The default is FLAC. A disc is 16-bit/44.1 kHz stereo and FLAC keeps every
/// bit of that in about half the room, which is the only answer that is both
/// honest about the source and reasonable about the disk.
public enum ImportFormat: String, Sendable, Equatable, CaseIterable, Codable {
    case flac
    case alac
    case aiff
    case wav
    case mp3
    case opus

    /// What the menu calls it. The parenthetical is the part that answers
    /// "which one do I want" — a codec name alone never has.
    public var label: String {
        switch self {
        case .flac: "FLAC — lossless"
        case .alac: "ALAC — lossless, Apple"
        case .aiff: "AIFF — lossless, uncompressed"
        case .wav: "WAV — lossless, uncompressed"
        case .mp3: "MP3 — V0"
        case .opus: "Opus — 128k"
        }
    }

    /// What the panel calls it, where there is one column to say it in.
    public var name: String { rawValue.uppercased() }

    public var fileExtension: String {
        switch self {
        case .flac: "flac"
        case .alac: "m4a"
        case .aiff: "aiff"
        case .wav: "wav"
        case .mp3: "mp3"
        case .opus: "opus"
        }
    }

    /// Whether the bits that come off the disc are the bits that land on
    /// disk. Said out loud because it is the only question worth asking about
    /// an archive, and the panel says it on the way past.
    public var isLossless: Bool {
        switch self {
        case .flac, .alac, .aiff, .wav: true
        case .mp3, .opus: false
        }
    }

    /// The external encoder this needs, where it needs one.
    ///
    /// `flac`, `alac` and the two PCM formats are built into every ffmpeg
    /// there has ever been. `libmp3lame` and `libopus` are compile-time
    /// options, and a Homebrew ffmpeg has them while a minimal build may not.
    /// Checked before a single track is decoded — see `ImportJob.Failure`.
    public var library: String? {
        switch self {
        case .mp3: "libmp3lame"
        case .opus: "libopus"
        case .flac, .alac, .aiff, .wav: nil
        }
    }

    /// The codec arguments, and nothing else — the input, the metadata and the
    /// output path are the job's.
    ///
    /// **Nothing here resamples and nothing here dithers**, which is the whole
    /// difference from `Converter.filter`. That one is aimed at a CD and has to
    /// get a 24-bit shelf down to 16 bits honestly; this one is coming *off* a
    /// CD, where the source is already 16/44.1 stereo, and the correct thing to
    /// do to it is nothing at all. A lossless format written this way is
    /// bit-identical to what the drive handed over.
    ///
    /// `-compression_level` on FLAC is 5 by default and 8 here: the disc is
    /// read once and the file is kept for years, so the extra seconds a track
    /// spends compressing are the cheapest trade in the program. ALAC has no
    /// such dial.
    ///
    /// `-q:a 0` is LAME's V0 — the highest VBR setting, and the only MP3
    /// setting worth offering. Opus at 128k VBR is stereo-transparent by every
    /// listening test there is, and going higher spends room on nothing.
    public var codecArguments: [String] {
        switch self {
        case .flac: ["-c:a", "flac", "-compression_level", "8"]
        case .alac: ["-c:a", "alac"]
        // `pcm_s16be` and not `pcm_s16le`: AIFF is a big-endian container, and
        // ffmpeg will write a little-endian AIFF-C if asked to rather than
        // refusing. What comes off a CDDA mount is already `pcm_s16be`, so
        // this is also the case where nothing is re-encoded at all.
        case .aiff: ["-c:a", "pcm_s16be"]
        case .wav: ["-c:a", "pcm_s16le"]
        case .mp3: ["-c:a", "libmp3lame", "-q:a", "0"]
        case .opus: ["-c:a", "libopus", "-b:a", "128k", "-vbr", "on"]
        }
    }

    /// Whether the container takes a cover picture ffmpeg can actually write.
    ///
    /// **The three nos are each a different no.** WAV and AIFF have no
    /// convention for one worth relying on — ffmpeg can be made to bolt an ID3
    /// chunk onto an AIFF, and nothing reliably reads it back. Opus is the
    /// interesting one: the Ogg encapsulation carries pictures as a
    /// base64 `METADATA_BLOCK_PICTURE` comment, and ffmpeg's ogg muxer does not
    /// write one — so asking for it produces a file with no picture and no
    /// complaint, which is worse than declining.
    public var takesCoverArt: Bool {
        switch self {
        case .flac, .alac, .mp3: true
        case .aiff, .wav, .opus: false
        }
    }

    /// How tags are named in this container.
    ///
    /// ffmpeg maps its generic keys onto each container's own vocabulary, and
    /// for everything here that mapping is right — except MP4, where
    /// `album_artist` is the key and `TPE2` is what ID3 calls the same thing,
    /// and ffmpeg handles both. So there is one shape of metadata and this
    /// exists to record that it was checked rather than assumed.
    ///
    /// The exception that is not a mapping: **WAV and AIFF keep almost
    /// nothing.** RIFF `INFO` has a title, an artist and a comment, and no
    /// album artist and no disc number. Nothing is done about it — a format
    /// that cannot hold a tag is not made to by this program — but a record
    /// imported as WAV losing its album artist is not a bug and it is written
    /// down here so nobody goes looking for one.
    public var keepsFullMetadata: Bool {
        switch self {
        case .flac, .alac, .mp3, .opus: true
        case .aiff, .wav: false
        }
    }
}
