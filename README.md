# MU/TH/UR

A native macOS player for whole albums — from a folder, from a zip, or from the
audio CD in the drive. Gapless, metadata-ordered, with the sleeve at real
resolution and a cassette-futurism CRT face.

A port of two bash TUIs that live in another repository and stay there —
`player`, and now `burncd`, which shares its faceplate. See `CLAUDE.md` for the
constraints and `docs/spec.md` for what it has to do. Parity is tracked across
three files sharing one numbering: `docs/parity.md` (§1–§15, §17, the still-open
questions of §18, and §20), `docs/decisions.md` (§16, every deliberate departure
from either script, and the answered half of §18), and `docs/hardware.md` (§19,
the procedure to work through with a disc in the drive).

## Status

It builds, installs with `Scripts/install.sh`, plays records — and burns them.
Parity stands at **319 of 324 boxes**. Of the five still open, three are what §14
marks as blocked on hardware and material: AirPlay's unplug, hi-res output
switching, and an Opus or Ogg file to make the ffmpeg fallback fail on. One is
what is left of §20's stage 3b: `--from-disc n`, written and tested everywhere
above the drive, which needs two blanks to resume a job between them and there is
none left. The last is §4.2's `cdda2wav` read of a disc's CD-Text, and it is open
for a reason that only a disc could have supplied — it runs, it reads a real
lead-in correctly, and it cannot open a disc macOS has mounted, which is every
audio CD. §19 is a procedure rather than boxes and is counted separately, at
**31 of 37**; what is left there wants a disc out of a multi-disc set, a data
disc, an empty bay, and two AIFFs on an external volume.

**The disc has been read back.** `--verify` came off that list against the CD-R
the port burnt: thirteen tracks off the table of contents, 265,307 sectors read
end to end with no error, and the album title back out of the lead-in — three
checks and deliberately not a byte-for-byte comparison, because every drive reads
audio at a small fixed offset from where it wrote it and an exact compare fails
on a perfectly good disc.

**`burncd` stage 3a has landed: the whole burn except the drive.** A folder
becomes a burn plan, cut across as many discs as it takes and balanced so the
last one is not a stub; `B` on the deck opens the editor that lets a wrong tag be
fixed before it is written to a lead-in permanently; and every track converts
through ffmpeg to 16-bit/44.1 kHz stereo — dithered on purpose, not truncated by
default — into one continuous image per disc with a cue sheet beside it.
`--level` matches the loudness of a record or of each track, as far as the
true-peak headroom allows and no further, and says which of the two stopped it.

The burn screen is the plan's capacity meter with the laser on — the same bands,
the same ambers, a different numerator under the head — with a lamp that keeps
its own time so a drive still working never reads as a drive that has died, and
a `LEAD-IN`/`LEAD-OUT` phase machine for the two silences a burn gives you for
free. The `cdrecord` invocation is built and can be read back argument by
argument; a stand-in drive plays a whole burn through the real panel; and a
record goes from a folder of files to a finished burn screen with nothing
spawned.

**Stage 3b has had the laser on.** `cdrecord` is a dependency now and is spawned
for real: the media check looks at the blank in the tray and is believed,
`--dummy` rehearsed a whole record at write speed three times, and then one blank
became an audio CD — thirteen tracks, 58:57.42, written at an average 8.0x with
the drive buffer never below 96% and the FIFO never once empty. It plays. Every
track boundary was written with no pregap, the read-back TOC's starts are the
image's own sector counts with nothing inserted between them, MusicBrainz
resolves the CD-R's disc ID to four real pressings of the album it was copied
from, and two tracks lifted back off it join sample for sample under §6's seam
tests. The CD-Text went into the lead-in and reads back whole, apostrophes and
all.

Three things came out of the drive. The six privilege warnings cdrtools prints
when it is not installed setuid root have no teeth here, under a real write as
well as a rehearsal, so no privileged helper is needed. `diskarbitrationd` does
have teeth: macOS mounts what a finished write leaves behind, a mounted drive is
one cdrtools cannot open at all, and that bites the CD-Text *reader* as well as
the writer. And a real disc found a real bug — the CD-Text parser knew two
printed shapes and this machine's `cdda2wav` prints two others, so a disc
carrying its full lead-in was displayed as a disc carrying none, on screen,
before any test failed. MUTHURKit carries 931 tests.
