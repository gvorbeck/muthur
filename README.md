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

MU/TH/UR needs macOS 15 or later, on Apple silicon or Intel. There are three
ways to put it on a machine; pick by what the machine already has.

| The machine has | Use |
|---|---|
| Nothing — no clone, no Xcode | `Scripts/bootstrap.sh`, one command |
| Nothing, and you would rather not pipe a script into a shell | a release zip, by hand |
| This repository and Xcode | `Scripts/install.sh` |

Every route ends at `/Applications/MUTHUR.app`, where Spotlight, Raycast and the
Dock find it by name, and every one of them refuses to delete anything already
standing there whose `CFBundleIdentifier` is not `com.gvorbeck.muthur`.

### One command, on a new machine

    curl -fsSL https://raw.githubusercontent.com/gvorbeck/muthur/main/Scripts/bootstrap.sh | bash

It installs whichever of `ffmpeg` and `cdrtools` are missing, downloads the
latest [release](https://github.com/gvorbeck/muthur/releases), checks the
bundle's signature before trusting it, copies it into `/Applications`, and
lifts the quarantine (below). It asks for no password and runs no `sudo`.
Homebrew itself it will not install — that is a large thing to put on
somebody's machine, so it stops and points at <https://brew.sh> instead.

The script is short and meant to be read before it is run. A directory as its
argument installs somewhere other than `/Applications`.

### By hand, from a release

1. Download `MUTHUR.zip` from the latest
   [release](https://github.com/gvorbeck/muthur/releases), unzip it, and drag
   `MUTHUR.app` to `/Applications`.
2. Lift the quarantine:

       xattr -dr com.apple.quarantine /Applications/MUTHUR.app

3. Install the two tools:

       brew install ffmpeg cdrtools

**Step 2 is not optional.** The app is ad-hoc signed — a personal app, with no
Developer ID and no notarization, which is what `CLAUDE.md` chose. A file that
arrived over the network carries `com.apple.quarantine`, and Gatekeeper rejects
an ad-hoc signature under quarantine outright: `spctl -a` on a downloaded bundle
answers `rejected`, and the Finder's version of that answer is a dialog saying
the app is damaged. It is not damaged. Stripping the attribute is the whole
fix, and it is saying *I know where this came from*, which you do.

The zip is one universal bundle, arm64 and x86_64, so an Apple silicon machine
and an Intel one install from the same download.

### From source

    brew install ffmpeg cdrtools
    Scripts/install.sh

From the repository root, with Xcode installed. It builds Release into
`build/DerivedData`, copies the bundle to `/Applications/MUTHUR.app`, nudges
LaunchServices so launchers notice, and prints the path it wrote. It takes
about half a minute.

Both arguments are optional and positional —
`Scripts/install.sh [Release|Debug] [directory]`, defaulting to Release and
`/Applications`. `/Applications` rather than `~/Applications` because it is
`drwxrwxr-x root:admin`, so an admin account writes to it without `sudo`, and
it is where every launcher looks first.

It is a copy and not a symlink, because Raycast indexes the standard application
folders and indexes symlinks into them only erratically. The cost is that **the
script has to be re-run to pick up a change** — deliberately by hand, and not
from a commit hook: a commit is bookkeeping and an install replaces the app in
your Dock, and a hook that did both would rebuild for documentation-only commits
and refuse to commit work that does not build yet. During development you are
launching from Xcode anyway.

### Updating

Whichever route put it there, the same route again replaces it. **Quit
MU/TH/UR first**: every script deletes the old bundle and copies the new one in,
and an app whose bundle vanishes under it can fail the next time it reaches for
one of its own resources.

- Installed with `bootstrap.sh`: run the same one command.
- From source: `git pull`, then `Scripts/install.sh`.

The version you are running is in **MUTHUR → About MUTHUR**; `defaults read
/Applications/MUTHUR.app/Contents/Info CFBundleShortVersionString` says the
same from a shell.

### The two tools, and why they are not in the bundle

`ffmpeg` decodes what AVFoundation will not take — Opus and Ogg — and converts
every track on the way to a burn. `cdrtools` is `cdrecord` and `cdda2wav`: the
drive's writer, and the reader that lifts CD-Text out of a disc's lead-in. The
port finds each by name in `PATH`, `/opt/homebrew/bin` and `/usr/local/bin`,
because an app launched from the Dock inherits no shell's `PATH`.

Both are optional in the sense that nothing crashes without them. The player
plays everything AVFoundation understands, and **MUTHUR → Health Check (⌘K)**
says what is missing (§11); what does not run is the burner, and a disc's
CD-Text.

They are installed beside the app rather than shipped inside it, for three
reasons that were each checked rather than assumed:

- **Homebrew's builds are single-architecture.** On an Apple silicon machine
  `lipo -archs` answers `arm64` for all three binaries. Put in the bundle, they
  would break the Intel half of a universal app — which is the half the second
  machine is for.
- **ffmpeg does not travel alone.** It links 19 Homebrew libraries directly and
  more beneath those, every one of which would need relocating into the bundle
  and re-signing.
- **Licensing.** Homebrew's ffmpeg is built `--enable-gpl --enable-version3`, so
  shipping it in a public release carries GPLv3's obligations. cdrtools is
  CDDL-1.0, whose terms for redistribution alongside GPL code are contested
  enough that most Linux distributions will not package it.

So the answer to *can the install be automated* is fewer commands rather than
fewer dependencies, and `bootstrap.sh` is that.

## Releasing

A release is a tag, a GitHub release carrying `MUTHUR.zip`, and notes that say
what changed. Three steps.

**1. Name the version.** The app's version is written in exactly one place,
`MARKETING_VERSION` in the project's build settings; `App/Info.plist` quotes it
rather than repeating it, since v0.1.0 shipped a bundle saying `0.1` when the
two disagreed. In Xcode: the MUTHUR target → General → Identity → *Version*,
and bump *Build* beside it. Or edit `MUTHUR.xcodeproj/project.pbxproj`, where
`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` each appear twice, once for
Debug and once for Release. Commit and push.

**2. Write the notes**, if the release has anything to say beyond the install
instructions — a Markdown file, anywhere.

**3. Cut it.**

    Scripts/release.sh 0.4.0 notes.md

The version may be written with or without its `v`; the tag always has one.
The notes file is optional and goes *above* the install instructions, which the
script always appends, so a release cannot go out without them.

It checks everything before building anything, and refuses — exits, never
prompts — if the working tree is dirty, the branch is not `main`, `HEAD` is not
exactly `origin/main`, or the tag or the release already exists. Then it builds
and asks four questions of the bundle that `xcodebuild` succeeding does not
answer:

- **Is it signed?** `codesign --verify --deep --strict`.
- **Does it carry both architectures?** A build that quietly came out arm64-only
  installs perfectly and then will not launch on an Intel machine, with nothing
  on screen to say why.
- **Is it MU/TH/UR?** The bundle identifier.
- **Does it say the version the tag says?** Asked of the built bundle, not the
  project file, because the bundle is what gets downloaded. This is the check
  that notices step 1 was skipped.

Only then does it zip with `ditto` — not `zip`, which drops the extended
attributes the signature partly lives in — tag, push the tag, publish, and ask
GitHub what it really has rather than trusting that an upload which returned 0
is the file somebody will get.

A release is the one artifact that outlives a mistake: it has a URL and somebody
downloads it, and deleting it does not un-download it. That is why the script
is unwilling, and why every check it makes comes before the first byte is built.

Scripts that talk to GitHub need `gh`, logged in (`brew install gh`,
`gh auth login`). Run from inside Claude Code's Bash sandbox, `gh` fails with a
TLS certificate error that is the sandbox and not GitHub; it needs to run
outside it.

## Status

It builds, installs with `Scripts/install.sh`, plays records, and burns them
from the panel. **Every `burncd` switch is now in a Burn menu** (D86) —
rehearse, verify, CD-Text, split long tracks, loudness levelling, start at disc
n, the media check and demo — where before this release the app built every
burn with the defaults and none of them could be reached. They are not
remembered between launches, on purpose: a rehearsal left on from last month is
a burn nobody meant to rehearse. The panel also shows its version beside the
wordmark (D88), runs a cut-off title past its column on the playing row and the
row under the pointer (D89), and Health Check tells an empty drive from a
missing one (D87).

Everything waiting on a drive, a blank or a particular file is in
[`TODO.md`](TODO.md).

Parity stands at **321 of 325 boxes**, unchanged — no box had ever described
the unreachable switches either. Of the four still open,
three are what §14 marks as blocked on hardware and material: AirPlay's unplug,
hi-res output switching, and an Opus or Ogg file to make the ffmpeg fallback
fail on. The last is what is left of §20's stage 3b: `--from-disc n`, written
and tested everywhere above the drive, which needs two blanks to resume a job
between them and there is none left. §19 is a procedure rather than boxes and
is counted separately, at **34 of 40**; what is left there wants a disc out of a
multi-disc set, a data disc, an empty bay, and two AIFFs on an external volume.

**A year you correct now stays corrected** (D85). `2001 - Drukqs.zip` shows
`Aphex Twin (2017)` because 33 of its 35 files say so, and both numbers are
true: the tag names the pressing, the folder names the album. Fix it on the plan
screen and the correction is kept beside the program — never written into your
files — and reaches the faceplate, the plan and the disc's own lead-in alike.
The plan screen says when it is disagreeing with your tags, and deleting
`corrections.json` puts every record back to what they say.

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
