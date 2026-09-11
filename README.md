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

## Installing

Two Homebrew formulae first. The port does not bundle them; it looks up each
tool by name in `/opt/homebrew/bin` and `/usr/local/bin` and shells out to it.

    brew install ffmpeg cdrtools

`ffmpeg` decodes what AVFoundation will not take and converts every track on
the way to a burn. `cdrtools` is `cdrecord` and `cdda2wav` — the drive's writer
and the reader that lifts CD-Text out of a lead-in. Without them the player
still plays what AVFoundation understands; the burner does not run at all.

Then, from the repository root:

    Scripts/install.sh

It builds Release into `build/DerivedData`, copies the bundle to
`/Applications/MUTHUR.app`, nudges LaunchServices, and prints the path it
wrote. A copy and not a symlink, because Raycast indexes the standard
application folders and indexes symlinks into them only erratically — the cost
being that **the script has to be re-run to pick up a change**; during
development you are launching from Xcode anyway. It will not clear a path in an
application folder blind: anything already standing there whose
`CFBundleIdentifier` is not `com.gvorbeck.muthur` stops the install rather than
being deleted.

Both arguments are optional and positional —
`Scripts/install.sh [Release|Debug] [directory]`, defaulting to Release and
`/Applications`. `/Applications` rather than `~/Applications` because it is
`drwxrwxr-x root:admin`, so an admin account writes to it without `sudo`, and
it is where every launcher looks first.

### Without the repository

A tagged [release](https://github.com/gvorbeck/muthur/releases) carries a built
`MUTHUR.zip` — one universal bundle, arm64 and x86_64, so it runs on an Apple
silicon machine and an Intel one from the same download. Unzip it, drag
`MUTHUR.app` to `/Applications`, and then:

    xattr -dr com.apple.quarantine /Applications/MUTHUR.app

**That last line is not optional.** The app is ad-hoc signed — a personal app,
with no Developer ID and no notarization, which is what `CLAUDE.md` chose and
is fine for a bundle you built yourself. But a file that arrived over the
network carries `com.apple.quarantine`, and Gatekeeper rejects an ad-hoc
signature under quarantine outright: `spctl -a` on the downloaded bundle
answers `rejected`, and the Finder's version of that answer is a dialog saying
the app is damaged. Stripping the attribute is the whole fix, and it is
saying *I know where this came from*, which you do.

`brew install ffmpeg cdrtools` is still wanted on that machine; the zip is the
app and nothing else.

## Status

It builds, installs with `Scripts/install.sh`, plays records — and burns them.
Parity stands at **321 of 325 boxes**. Of the four still open, three are what §14
marks as blocked on hardware and material: AirPlay's unplug, hi-res output
switching, and an Opus or Ogg file to make the ffmpeg fallback fail on. The last
is what is left of §20's stage 3b: `--from-disc n`, written and tested everywhere
above the drive, which needs two blanks to resume a job between them and there is
none left. §19 is a procedure rather than boxes and is counted separately, at
**34 of 40**; what is left there wants a disc out of a multi-disc set, a data
disc, an empty bay, and two AIFFs on an external volume.

**The fifth open box closed by somebody deciding something.** §4.2's `cdda2wav`
read of a disc's CD-Text runs and reads a real lead-in correctly, and it cannot
open a disc macOS has mounted — which is every audio CD. The port now borrows the
mount for the length of that one read and waits for it back, **when the user
opens a record and never when the picker scans the drive**: a scan has not been
handed the disc. If the disc does not come back, the panel says so, because a
disc that vanishes from Finder is worse than absent CD-Text and is the one
failure here nobody could diagnose.

**Then it said so about every disc, which is how the giving back got measured.**
The `diskutil mount` D80 was written around never worked once: cdrtools' exclusive
open makes the kernel tear the device node down and re-enumerate it, so the port
was asking for a node that would not exist for another second — while
`diskarbitrationd`, asked by nobody, put the volume back at 1.3 s. The borrow now
waits for the disc rather than for its own request, up to five seconds, and reads
the mount table rather than an exit status; and it distinguishes *nothing was
taken* from *it came back*, which one `Bool` could not, and which is why a second
read in a row used to report a still-absent disc as fine. Opening a CD costs
about two and a half seconds now, and the record it hands back is one whose files
are actually there.

**And the burnt disc, played, found a bug worth the whole exercise.** Thirteen
correct tracks came up under `ALBUM Audio CD`, `ARTIST —`, thirteen rows reading
`Track 01` … `Track 13`, and an Elton John sleeve. One fault, not three:
MusicBrainz knows this disc, but it was shedding load — five of ten hand-run
queries came back *the web server is currently busy* — and the port took the
first refusal for an answer. The album fell back to the volume's own name, and
the sleeve search went looking, in earnest, for a record called *Audio CD*.
Which exists. It asks twice now, it does not search for a name it invented, and
the disc's identity reaches the sleeve when there is one. **The bug was never
the wrong cover; it was a confident answer where the honest one is *I do not
know this disc*.**

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
before any test failed. MUTHURKit carries 953 tests.
