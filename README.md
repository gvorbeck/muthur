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

It builds, installs with `Scripts/install.sh`, and plays records. Parity stands
at **315 of 324 boxes**. Of the nine still open, five are §20's stage 3b, the
drive itself, and four are elsewhere: three that §14 marks as blocked on hardware and
material — AirPlay's unplug, hi-res output switching, and an Opus or Ogg file to
make the ffmpeg fallback fail on — and one in §4.2, the `cdda2wav` read of a
disc's CD-Text, which is written and has never been run. §19 is a procedure
rather than boxes and is counted separately, at 10 of 33 — the rest are steps
waiting on a disc in the drive.

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
spawned. **`cdrecord` is not a dependency yet** — that is stage 3b, along with
the media check, `--dummy` and `--verify`, which need a blank in a drive. It
burns nothing, and says so. MUTHURKit carries 859 tests.
