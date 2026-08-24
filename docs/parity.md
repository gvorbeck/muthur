# MU/TH/UR — parity

The definition of done. Every box here is something the bash `player` does, read
out of the source rather than out of the README, with the reasoning that has to
survive the port attached to it.

Source references are `player:NNNN` for
`/Users/garrett.vorbeck/Sites/cd-collection/scripts/player/player` and
`panel.sh:NNNN` for `../lib/panel.sh`. Both are read-only.

Three kinds of entry:

- `[ ]` — behaviour to port, unchecked until it lands and is verified.
- **(terminal)** — exists only because the display is a character grid. Listed so
  the reasoning behind it is on record, not so it gets rebuilt.
- **Changed from bash (Dn)** — a deliberate departure from the script, carrying
  the reasoning and the decision it came from. All twenty-four are settled; §16
  lists them together so a difference from `player` is never later mistaken for
  a porting mistake.

§17 collects the degraded paths — no network, no drive, a disc that will not
read, a folder with nothing in its tags. §18 is the open list: things in the
script that are not obviously either a feature or a bug, each needing an answer
before the code that would inherit it gets written. Neither is a checklist.

**§19 is.** It is the one section written to be worked through rather than read:
everything §4 does that a machine with an empty drive can only test structurally,
and what to do with a disc in the drive to prove each of it. Nothing else in this
document assumes you have read it, and it does not assume you have read anything
else.

Line numbers are against the source as it stands today. Where a behaviour spans
a comment and the code it explains, both are cited — the comment is usually the
part worth porting.

---

## Status

**141 of 263 boxes** (§19 is a procedure, not boxes, and is not counted). §5,
§5.1, §5.2 and §5.3 are done whole — nineteen boxes, none held back — and D14
takes one of §17's with them, the only durable consequence an outage used to
have. §4, §4.1, §4.3 and §4.4 are done bar one box, and §4.2 bar one: both of
those are the same box in different clothes — the command that runs a tool
against a drive there is no drive for. §2, §2.1 and §2.2 are done bar five: three
that need an exit path to hang off, and two that need the source layer. §3 and
§3.1 are done whole, the CD-only filename rescue included. §6, §6.1b, §6.2 and
§6.3 are done whole, and §6.1, §6.1a and §6.4 are done bar what is plainly the
panel's half rather than the deck's — the cursor, the wheel, the mouse buttons,
the faceplate, the analyser and the key bindings themselves. **All eleven of §6's
remaining boxes are waiting on the panel — none of them on the engine.** It takes
four of §17's with it: the two degraded paths for an album that vanishes while it
is playing, and the two about a folder of mixed formats, which is the same
requirement §6 opens with and the album it would be audible on.

**§7 and §9 are the new ones, and both are done whole** — twenty boxes, and
§6.2's resume entry with them, which had been waiting for §7 to have one to
clear. Neither needed a line changed in `Play/`: §7 watches the deck's published
state and never speaks to it (D24), and §9 taps whatever node it is handed, which
is a question §10 answers. §9 is the numbers only — the bands, the levels, the
scales and the column state, all of it measured in `swift test` with no window
open. Nothing is drawn. Every other entry in this document should be read as
outstanding.

**Where a fresh session picks up.** Two things are ahead and neither blocks the
other. **The UI** — gate 4's second half — is what §6's eleven open
boxes are waiting for, along with the whole of §10; the deck underneath them is
written and measured, the analyser behind them is measured too, and what they are
missing is somebody to press their keys and a surface to draw on. **§1, the
source layer**, is
still the piece that opens a folder, a zip or a disc and hands the result to §3;
nothing calls §2, §3, §4 or §5 in anger until it exists. It also unblocks the
two §2.2 boxes below (a zip's provenance has to reach `Record.read` before D12
can ever fire outside a test), the three §2 teardown boxes (which need something
with an exit path), and the two things §4 and §5 currently hand to nobody: the
release MBID that comes off a disc in §4.3 and lets the sleeve skip the name
search entirely, and `TitleSource` itself, which is the only one of §4's four
sources nothing stamps — `tags` is what a folder or a zip gets, and there is
nothing yet that knows a source is a folder. §6 has already borrowed the one
piece of §1 it could not do without: `SourceKind`, because §6.3's message for a
record that has vanished depends on whether it came out of a zip.

**§1.3 is deliberately not written.** Disc detection wants the drive present, by
your call; §19 is the list it gets written against.

**§18.4** came due while §5 was being written and is answered — **D14**: the
`.none` marker is written only when something at the far end actually replied.
**§18.1, §18.6, §18.7 and §18.11** came due together before §4 was written and
are answered as **D16–D19**; §18.6 and §18.7 land in §1, which is still ahead.
**§18.18** is new and deliberately left open — where the table of contents comes
off the drive is a question to answer with the drive plugged in. **§18.19,
§18.20 and §18.21** are newer still and come out of §7 and §9: whether the resume
file is shared with the bash script or owned outright, what the offer says for a
row with no track number, and how long a live autoscale takes to settle. The
first two want an answer before §10 draws anything that depends on them; the
third is a thing to watch on a real record rather than a question. Ten open items
remain in §18.

What has landed:

- **§3, §3.1 — metadata and ordering.** `MUTHURKit/Sources/MUTHURKit/Record/`.
  A scan in byte order, one read per file, §3's rules applied to what comes
  back, and the running order those rules dictate. Reading is a protocol with
  two implementations — AVFoundation first, `ffprobe` behind it for what
  AVFoundation will not open — and a third that reads nothing, which is how
  every degenerate case in §3.1 is tested without a folder of audio.
- **§2, §2.1, §2.2 — the scratch directory and zips.**
  `MUTHURKit/Sources/MUTHURKit/Scratch/`. `Scratch` is the session directory:
  where it goes, the pid that claims it, the startup sweep that clears what no
  process answers for, and a teardown that refuses any path this process did not
  create. `ZipArchive` reads the central directory, `Inflate` runs raw DEFLATE
  through `Compression`, and `Unpacker` is §2.1's fit check and §2.2's failure
  taxonomy over the two of them. Nothing shells out to `tar` or `unzip`, which
  is the whole of §2.2's first box.
- **§5, §5.1, §5.2, §5.3 — the sleeve.**
  `MUTHURKit/Sources/MUTHURKit/Sleeve/`. `SleeveResolver` is the resolution
  order: beside the record, then the tags, then the archive — and `resolve`
  touches the filesystem and returns, handing back a `Task` that **nothing
  joins**, so no panel can accidentally come to depend on the network.
  `BesideTheRecord` is the ranking and the thrown-out names; `SleeveCache` is the
  key, the `.part` file and the `.none` marker, and deliberately offers no way to
  delete an entry, which is the whole of §5.2's last box. `ReleaseSearch` is
  §5.3's ladder. Three seams are protocols with stubs — `PictureProbe`,
  `EmbeddedPictureReader`, `SleeveTransport` — so every rule here is tested
  without a network and most of them without a decoder. `MUTHUR.userAgent` is one
  string, set in one place, used by every request the program makes (§4.3).
- **§4, §4.1, §4.2, §4.3, §4.4 — where the titles came from.**
  `MUTHURKit/Sources/MUTHURKit/Disc/`. `TableOfContents` is the disc ID, computed
  here and checked against `libdiscid` as an offline oracle (**D15** — the
  script's is wrong); `CDRecordTOC` reads a `cdrecord -toc` listing into one;
  `CDText` is §4.2's parser and the quote rule that keeps `Don't Stop Me Now`
  whole; `MusicBrainzDisc` is the lookup, over the same `SleeveTransport` seam §5
  uses, so it is tested without a network; `DiscTitles` is the chain, and it
  reports which of the four sources answered along with the disc ID and the
  release MBID it picked up on the way. `OpticalDrive` and `Tooling` are the two
  files nothing in the suite touches — they run `cdrecord`, `cdda2wav` and
  `drutil`, and none of that can be exercised without a drive.
- **§6, §6.1, §6.1a, §6.1b, §6.2, §6.3, §6.4 — the deck.**
  `MUTHURKit/Sources/MUTHURKit/Play/`. `PlaybackEngine` is the deck itself and
  the only actor; `Feeder` reads ahead and keeps the node fed; `AudioSource` and
  `FFmpegSource` are the two decoders, the second a fallback for what
  AVFoundation will not take; `CanonicalFormat` decides the one format a record
  is played in; `Timeline` maps the output frame counter back to a row, an
  offset and a visit, and is the single source of truth §6 asks for;
  `Transport` and `ShuffledOrder` are what-follows-what, with no sound card in
  them, which is why the D3, D4 and D21 rules are tested against a seeded
  generator rather than against a speaker. The engine renders offline as well as
  to a device — the same graph, driven by hand — which is what makes the seam
  measurements above reproducible on any machine rather than a matter of what
  the audio hardware felt like doing.
- **§7 — resume.** `MUTHURKit/Sources/MUTHURKit/Resume/`. `ResumeFile` is the
  file — the key (a disc ID, else a SHA-1 of what the record *is*), the
  tab-separated line, the whole-write-and-rename, the 200-album cap, and the two
  rules about what is worth offering. `ResumeWatch` is the tick that decides when
  to write and holds the offer until something spends it. It has no reference to
  the engine at all, which is D24 and is why the offer cannot be applied by
  accident. Every test builds its own throwaway directory; nothing in the suite
  goes near `~/.local/state`, and the SHA-1 is checked against the machine's own
  `shasum` rather than against itself.
- **§9 — the analyser, the data path.**
  `MUTHURKit/Sources/MUTHURKit/Analyser/`. `Bands`, `Spectrum`, `BandScale`,
  `AnalyserColumns` and `Analyser`: sixteen bandpass responses, one windowed
  transform a tenth of a second, a histogram per band, and the column state with
  its trail and its age. The method is D22 and D23; the output is sixteen
  numbers in dBFS and a grid of graded cells, and **no colours and no glyphs** —
  §10 owns those. The whole of it is measured against tones with known answers,
  and against real ffmpeg running the script's own filter chain.
- 370 tests, `swift test --package-path MUTHURKit`. Five of them skip themselves
  on a machine with nothing in the drive — that is §19, and it is the list of
  what is still unproven rather than untested. Five more skip without `ffmpeg`
  (the cross-decoder seam, and §9's three against the script's own chain), and
  two without a record on the machine that has continuous audio across a track
  boundary.
- Not in it: the three §2 boxes that are about *when* teardown runs rather than
  what it does — those need the app's exit path, and there is no app yet.

Two things about §3 worth knowing before §4 is written:

- `row_of_track` is `Record.fileIndex(ofTrackNumber:)`, and there is a separate
  `row(ofTrackNumber:)` for the one caller that wants a position in the running
  order. That split is D9, closing §18.2; the behaviour is the script's either
  way — first match wins.
- AVFoundation reports an MP4's *trimmed* duration where `ffprobe` reports the
  container's — 134.4 against 134.466757 on the same file. Both round up to the
  same second, so §3 cannot tell them apart, and AVFoundation's is the one a
  gapless engine will actually play. Noted here because §6 can tell them apart.

What is still the empty frame:

- `MUTHURKit/` — the headless package, one folder per section here: `Record/`
  §3, `Disc/` §1.3 and §4, `Scratch/` §2, `Sleeve/` §5, `Play/` §6, `Resume/` §7,
  `Analyser/` §9, `Shelf/` §8. All but `Shelf/` have the above in them —
  `Disc/` holds §4 but not §1.3. It is a package
  and not a folder inside the app target so that these suites run without
  standing up an app, and so that nothing in here can import SwiftUI by
  accident — the moment it can, parity stops being testable in isolation. §6
  earns that arrangement twice over: an audio engine that can only be tested by
  listening to it is an audio engine nobody tests.
- `MUTHUR.xcodeproj` and `App/` — the app target. Ad-hoc signed, links
  `MUTHURKit`, opens one empty window, does nothing else.
- Toolchain: Xcode 26.3, Swift 6.2.4, deployment target macOS 15, Swift 6
  language mode on both halves.

```
swift test --package-path MUTHURKit
xcodebuild -project MUTHUR.xcodeproj -scheme MUTHUR build
Scripts/install.sh                      # a real bundle in ~/Applications
```

Against `spec.md`'s build order: step 1 — this document — is done. Step 2, the
domain layer, is under way: §3, §2, §5 and §4 are the first of it, and §1 is what
is left of it. Step 3 — the playback engine, §6 through §6.4 — is done, and was
taken ahead of §1 deliberately: gapless across a format change is the hardest
claim in this document to make good on, and finding out late that it could not be
made would have been the expensive way to find out. It can, and the numbers are
in §6. §7 and §9 were taken next for the same reason and against the same test —
both are state and arithmetic with no picture in them, and both can be proved
before there is anything to look at. What is left of §9 is §10's half: it has
sixteen numbers and a grid of graded cells and nothing that knows what amber is.
§16 D8 is a constraint on the UI when it arrives, not work that can be started
early.

**Test material.** The suites come in two tiers. The rules tier runs anywhere —
zero-byte files with the right names, and a stub reader that says what the tags
would have been, which is the only way to build a folder with an octal-looking
track number and a tab in its title. The material tier reads real files that
are already on this machine and copies none of them into the tree: `~/Music`
for tagged MP4s, the zips in `~/Downloads` for AIFF rips with no tags at all.
Point them somewhere else with `MUTHUR_TEST_MUSIC` and `MUTHUR_TEST_ZIPS`;
where the material is absent those tests skip rather than fail, so a fresh
clone is green. No audio is ever committed.

D12's cases are a third kind again: paths and nothing else. The rule reads the
*shape* of a scan, so its tests hand it lists of paths that never existed —
which is the only practical way to pin the layouts §18.17 is about, including
the two that are the same archive and must both be declined.

§6's material is a fourth kind: **audio written by the test to be measured
against.** A tone whose value at every sample is known in advance can be
subtracted from what came out of the engine, and the remainder is the answer —
which is the difference between "gapless" as a claim and gapless as a number. The
real-record tier sits beside it and asks a harder question the synthetic tier
cannot: the tone proves the arithmetic, the ambient album proves the arithmetic
survives a file somebody mastered. Both are in §6 above.

§9 uses the same kind and adds an oracle to it. A sine at a known frequency and a
known amplitude has a known answer in decibels, so every level the analyser
reports can be checked rather than eyeballed — but the numbers agreeing with
*theory* only proves the transform, not the port. So the material tier writes a
file with a tone in each of the sixteen bands, runs the script's exact chain over
it with real `ffmpeg`, and compares band for band. That is the only test in the
document that asks whether this is the same program; it skips without ffmpeg, and
it reads the chain from D22 rather than from the script, because nothing here
executes anything under `cd-collection`.

§2.2's archives are neither tier: they are written by a zip writer that exists
only in the test target, because every case worth testing is one no honest
archiver will make for you — a declared size that runs past the end of the file,
a CRC that does not match its own bytes, an encryption flag over plaintext, a
name that climbs out of the folder it was handed.

§5's pictures are a fourth kind: real JPEGs, generated in the test target at
whatever size the rule under test needs. The 200 px floor and "can a decoder read
these bytes" are both questions about actual image data, and a folder of
zero-byte files cannot ask either — but a 3000×3000 scan made on the spot costs a
few hundred bytes and nothing in the repository. Nothing in §5's suites touches
the network: `SleeveTransport` is a protocol, and the stub records what it was
asked so that "asks nothing at all" can be a test rather than a hope.

§4's disc IDs are a fifth kind, and the one that could not be invented at all:
three tables of contents and the IDs `libdiscid` gives them, produced by
`Scripts/discid-oracle.c` and pasted into the suite. Checking this arithmetic
against the same arithmetic written twice would prove nothing; the reference
implementation is the point, and `discid_put()` needs no drive, which is what
makes it usable on a machine with an empty tray. §19's suite is a sixth: it reads
a real listing off a real disc, and every test in it skips itself when the
material is not there.

---

## 1. Sources

### 1.1 Invocation

- [ ] No argument → the source picker (`player:3531`).
- [ ] A directory argument → play that folder (`player:3519`).
- [ ] A `.zip`/`.ZIP` argument → unpack and play (`player:3523`).
- [ ] Anything else that exists → `not a zip or a folder` (`player:3524`).
- [ ] A path that does not exist → `no such file or directory` (`player:3518`).
- [ ] Exactly one source argument; a second is an error (`player:337`).
- [ ] `--cd` → the disc, or die `no audio CD in the drive` (`player:3527`).
- [ ] `-n` / `--dry-run` → read it, print the album, play nothing
      (`player:331`, `player:3540`).
- [ ] `--check` → diagnostics, exit non-zero on hard failure (`player:332`,
      `player:531`).
- [ ] `--no-mb` → never ask MusicBrainz (`player:334`, `player:81`).
- [ ] `-h` / `--help` → the header comment, reprinted (`panel.sh:269`).

### 1.2 The picker

- [ ] Scans `PLAYER_DIRS` (default `~/Music:~/Downloads`), colon-separated
      (`player:1023`).
- [ ] `find -maxdepth 1`: loose zips, and immediate subdirectories that contain
      audio. The *scan* stays one level deep — the picker offers albums, not
      every folder on the disk (`player:1031`).
- [ ] The disc, when there is one, is listed **first** — if there is a disc in
      the drive it is almost certainly what you came to play (`player:1018`).
- [ ] Per-row detail column: `N tracks · in the drive`, `<du -h> · zip`,
      `N tracks · folder`.
- [ ] **Changed from bash (D18).** The disc's count is the same count every other
      row uses, not `ls | grep -ic '\.aiff\?'` (`player:1019`). A CDDA mount is
      AIFF today and the grep is right today; it is right by coincidence, and the
      row it is wrong in is the one offering you the disc — `0 tracks · in the
      drive` beside a disc that plays perfectly reads as a broken drive. One
      counter for all three source kinds, which is also the shape D7 gave the
      other two.
- [ ] Row marks: `⊙` disc, `▤` zip, `▸` folder (`player:1073`).
- [ ] Zips sorted `LC_ALL=C`, folders likewise, per scanned directory.
- [ ] A folder is offered only if it contains audio (`player:1039`).
- [ ] **Changed from bash (D7).** The count that decides this looks as deep as
      playback does, not one level. In bash they disagreed — the picker counted
      at `maxdepth 1` while playback reads at any depth (`player:1050` vs.
      `player:1422`) — so an album whose tracks live in `CD1/` showed up as
      having none and was dropped from the list, while playing fine if you named
      it on the command line. The depth limit was a fork-cost dodge, not a
      guard; a single directory enumeration is cheap here.
- [ ] One source and no argument is not a choice, it is the answer — skip the
      picker entirely (`player:1117`).
- [ ] Nothing to play at all → die with the directories it looked in
      (`player:1114`).
- [ ] Keys: `↑↓`/`kj` move, `PgUp`/`PgDn` a screenful, `⏎` open, `r` rescan
      (status `▪ RESCANNED`), `q` walk away with exit 0 (`player:1134`).

### 1.3 The disc

- [ ] `drutil status` is asked **before** any `/Volumes` scan. The drive knows
      about a disc that has not finished mounting, and a directory listing cannot
      tell an album from an external drive of field recordings — without the
      drive's answer that drive gets announced as "in the drive" and then has
      CD-Text and MusicBrainz answers about some entirely other disc applied to
      it (`player:965`, `player:994`, `player:1000`).
- [ ] Primary detection: a `cddafs` mount, parsed off `mount` output. Split on
      the **first** ` on ` and the **last** ` (` so a volume called
      `Live (Remastered)` keeps its name (`player:985`).
- [ ] Fallback: a `/Volumes` entry whose listing contains `Audio Track`, or ≥ 2
      `.aif`/`.aiff` files — only once `drutil` has confirmed media
      (`player:1002`).
- [ ] **Changed from bash (D17).** The shape test above stays exactly as it is
      and is **gated on the device**: `drutil status` prints the media's device
      node on the same line as its type — `Type: CD-R   Name: /dev/disk8`
      (`burncd:322`) — so a `/Volumes` entry whose backing device is not the node
      drutil named is not the disc, whatever its listing looks like. Two AIFFs is
      not evidence of a CD; a drive of field recordings is exactly that, and the
      cost of getting it wrong is not a missing feature but a *wrong* one — the
      external volume is announced as being in the drive, and then §4's CD-Text
      and MusicBrainz answers, which are about the disc, are written over its
      tracks (`player:1009`). Where drutil names no device, fall back to the
      script's ordered scan: degraded, not refused, per §17.
- [ ] **`drutil` runs before anything opens the device.** `cdrecord -checkdrive`
      and `-prcap` — and any libdiscid read — open the drive *exclusively*, and
      for as long as that lasts macOS lets go of the media, so `drutil` then
      reports `No Media Inserted` about a disc that never moved, and keeps
      reporting it until something spins the drive back up (`burncd:278`).
      Ask drutil first, keep the answer, and never let a device read run ahead of
      it. Not in `player` — `burncd` is where this was learned — but it is the
      same ordering the first box argues for on entirely different grounds, which
      is a good sign about both.
- [ ] No ripping step. The mounted CDDA volume is played as it stands
      (`player:1371`).
- [ ] A data disc is correctly ignored: it is not a `cddafs` mount
      (`player:985`), and its `/Volumes` listing carries neither `Audio Track`
      nor two AIFFs (`player:1006`). It falls out of detection rather than being
      rejected — there is no "this is a data disc" message and there should not
      be one, because from here it is simply a mounted volume like any other.

### 1.4 Accepted audio

- [x] `.aif .aiff .flac .mp3 .ogg .opus .wav .m4a .wma .ape .alac .mp4`,
      case-insensitive (`player:1046`). Mixed formats in one album are fine.
- [x] Audio is found at **any depth** under the album directory — a zip
      unpacking to `Album/CD1/…` alongside `Album/scans/…` is read whole and the
      non-audio ignored (`player:1422`).

---

## 2. Zips and the scratch directory

The single most load-bearing piece of hard-won reasoning in the program.

- [x] Zips unpack to `~/.cache/muthur/work` (`XDG_CACHE_HOME` respected,
      `MUTHUR_WORK` overrides, `PLAYER_WORK` read behind it — D13).
      **Not `$TMPDIR`**: macOS is entitled to reclaim
      `/var/folders/…/T` whenever the disk gets tight and does not care that
      something is playing out of it. A six-hour record on a tight volume can
      simply cease to exist halfway through, and what that looks like from here
      is every remaining track failing to open inside two seconds and the album
      quietly "finishing" (`player:170`).
- [x] If the cache directory cannot be made or written, `$TMPDIR` is taken
      anyway. A read-only or missing home is a reason to accept the worse
      directory, not a reason to refuse to play a record (`player:196`).
- [x] One `mktemp -d "$base/muthur.XXXXXX"` per session — a private directory,
      `0700`, and the name retried until it is one nothing else holds. The
      delete is only ever pointed at a path this process created, and refuses
      anything else outright rather than trying and failing (`player:241`).
- [x] The session's pid is written to `$WORK/pid` **before anything else goes
      in** — until that file exists the directory is indistinguishable from an
      abandoned one (`player:243`).
- [x] Startup sweep of `$base/muthur.*` (`player:207`):
  - a directory whose pid does not answer `kill -0` is removed;
  - a directory with no pid file is removed only if older than 5 minutes, so a
    player starting this instant is not swept by one starting the next;
  - a directory containing `keep` is never swept — somebody asked for it.
  - Two decks at once is allowed, and the second must not delete the first
    one's album out from under it.
- [ ] Teardown on **every** exit path — clean quit, `die()`, Ctrl-C, SIGTERM
      (`player:285`, `player:324`). `Scratch.tearDown()` exists and is tested;
      what is missing is anything that *calls* it, which is the app's exit path
      and has no app yet.
- [ ] Teardown order: screen first (so a message below lands on a terminal that
      can show it), then the player process, then any background analysis, then
      the directory. Nothing in the handler may be skipped because something
      earlier in it failed (`player:293`). Waits on the same exit path — three
      of the four things it orders do not exist yet.
- [ ] `MUTHUR_KEEP` set (or `PLAYER_KEEP` — D13) → the directory survives, is
      marked with a `keep` file so the next session's sweep spares it, and its
      path is printed to stderr (`player:313`). The survival and the mark
      landed; the line to stderr belongs to the exit path above.
- [x] The **whole** zip is unpacked, not just the audio, so the cover art comes
      along (`player:1181`).

### 2.1 Fit, before a byte is written

- [x] Uncompressed size is asked of the archive and compared against free space
      **before** unpacking starts. A lossless record is two to three times its
      zip; finding out afterwards means a half-unpacked album and a disk with
      nothing left on it (`player:1381`). The size comes off the central
      directory, so nothing is decompressed to find it out.
- [x] Headroom margin: 32 MiB (`33554432`). A record that only just fits must not
      leave the volume at zero — an album is not worth wedging a Mac for.
- [x] Failure message names the unpacked size, the free space, and
      `MUTHUR_WORK` as the way out.

### 2.2 Unpacking, and its failure taxonomy

- [x] `bsdtar` (`/usr/bin/tar` on any Mac) is preferred; `unzip` is the fallback.
      Apple's `unzip` runs a UTF-8 name through a conversion to the local charset
      first, so a decomposed `ô` — which is how a Mac writes `Hôtel` — comes out
      as two bytes no filesystem will take, and `unzip` reports that as exit 50,
      the same code it uses for a full disk (`player:256`). **On a Swift port
      this is the argument for reading the zip directly rather than shelling out
      to either.** Whatever does the work must take the archive's name bytes as
      the archive stores them. Neither is shelled out to: the central directory
      is read directly, stored and deflated entries are inflated through
      `Compression` (raw DEFLATE, which is what a zip holds), and every name
      goes to the filesystem as the bytes the archive stored — nothing is
      normalised, transcoded, or re-encoded on the way. A name that climbs out
      of the album, or claims to be absolute, is skipped rather than obeyed.
- [x] Encrypted archives are refused with one sentence, not a prompt. The bash
      version hands `tar` a passphrase it will certainly not accept and `unzip`
      an empty one, purely to turn a hang nobody can see into an error
      (`player:267`, `player:1339`). Reading the archive ourselves means the flag
      in the central directory answers it before a byte is decompressed, and
      there is nothing left that could hang.
- [x] Progress is per entry, driving the loading meter (`player:1290`).
- [x] **One bad entry is not a bad album.** A resource fork or a corrupt booklet
      scan is skipped and the record still plays; something wrong with the
      *archive*, or an archive that yielded nothing, ends it (`player:1298`).
      An entry that fails its CRC takes its half-written file with it, so the
      album §3 then reads has nothing truncated in it.
- [x] Disk-full is asked of the **disk**, never inferred from an exit code. That
      inference is exactly what once put "ran out of room" on a screen with a
      hundred gigabytes free (`player:1226`, `player:1350`). Every ambiguous
      failure asks the filesystem the same way: a write that failed is out of
      room only if the volume says so, and a read that came up short is a
      truncated archive unless the archive is no longer there.
- [x] Distinct messages for: out of room, encrypted, truncated, not-a-zip,
      unreadable, source vanished mid-unpack, interrupted (`player:1230`). Plus
      two the script also distinguishes: an archive with nothing in it, and one
      that yielded nothing (`player:1379`, `player:1308`).
- [ ] **The album knows it came out of a zip.** D12's rule only applies to a zip
      source, so something has to carry that fact from whatever opened the
      source to whatever reads the album — the unpacker is the only thing that
      knows it, and §3 is the only thing that needs it. Nothing carries it today
      because there is no source layer between them yet (§1).
- [ ] **D12 is switched on for real zips.** `Record.read` takes
      `discsFromSubdirectories`, it is implemented and tested, and every caller
      that passes `true` is a test. The one real caller is the zip path in §1,
      which is not written; until it is, an actual two-disc zip still
      interleaves. → D12

---

## 3. Metadata and ordering

- [x] One metadata read per file for: duration, track, disc, title, album,
      artist, album_artist/albumartist, date/year/originalyear (`player:1426`,
      `player:1439`).
- [x] A file whose duration cannot be read is **skipped, not fatal** — one bad
      track in a zip, and eleven good ones are still an album worth playing
      (`player:1443`, `player:1445`).
- [x] `track`/`disc` tags of the form `3/12` keep the part before the slash.
      Leading zeros are base ten, not octal — taggers write `08`, and bash reads
      a leading zero as octal and rejects `08` outright (`player:1447`,
      `player:1451`, `player:1466`).
- [x] Missing track number → sort key 9999, so tagged files keep their album
      order regardless (`player:1451`).
- [x] Missing disc number → 1 (`player:1452`), except under D12: where a zip's
      audio was found in more than one directory, and those directories are
      *siblings* (§18.17), a file whose own `disc` tag did not say takes the
      ordinal of the directory it is in. A tag always wins over the directory it
      sits in, and nothing is read off what the directory is *called*. → §2.2
- [x] **CD only:** with no track tag, the number comes off the leading digits of
      the filename macOS gave it (`1 Audio Track.aiff`). This matters more than
      ordering — CD-Text and MusicBrainz both answer in track numbers, and
      without it every one of them would be applied to the wrong row, because a
      plain sort puts track 10 between 1 and 2 (`player:1454`, `player:1459`).
      `Record.read(numbersFromFilenames:)`, off by default and passed `true` by
      exactly one caller-to-be: the disc source. Nowhere else does a filename
      decide anything, which is the whole reason it is a parameter and not a
      fallback in `Track`.
- [x] Tab, newline and CR are flattened to a space in every text tag, once, on
      the way in — a newline bends the frame the width code works to keep square,
      and a tab is the separator every record in the resume file is split on
      (`player:1468`, `player:1472`).
- [x] Durations round **up**, never down: a track that ends before the meter says
      it does looks like a skip (`player:1478`, `player:1480`).
- [x] Title falls back to the file's basename (`player:1481`).
- [x] Album/album-artist/year are taken from the first file that carries them.
      Album artist falls back to artist. Year is truncated at the first `-`, so a
      full ISO stamp becomes a year (`player:1485`, `player:1486`,
      `player:1488`).
- [x] Album falls back to the folder or zip's own name minus `.zip`, which is
      nearly always the album (`player:1496`, `player:1497`). The suffix comes
      off whatever case it is written in — §18.16, resolved.
- [x] **Ordering: disc, then track number, then a natural (`sort -V`) filename
      sort** — the last of the three only ever separating files that share key
      9999 (`player:1501`, `player:1504`). Order comes from metadata, not
      filenames. Not negotiable.
- [x] `TOTAL` is the sum of the ordered durations (`player:1513`).
- [x] Nothing may index a track number as `n - 1`. CD-Text and MusicBrainz answer
      in track numbers while the arrays are in scan order, and those are not the
      same thing — there is an explicit track-number → row lookup
      (`player:1518`, `player:1521`).

### 3.1 Ordering, exactly

Written out in full because the interesting cases are the degenerate ones, and
they are three lines of `sort` flags in the script.

- [x] **Scan order** is `find "$AUDIO_DIR" -type f \( "${AUDIO_GLOB[@]}" \) |
      LC_ALL=C sort` — byte order, not locale order, so the scan is the same on
      any machine (`player:1492`). The pre-count that drives the loading meter
      uses the identical `find` (`player:1422`), and zero results is
      `no audio in <source>` (`player:1423`).
- [x] **The sort key is a three-column tab-separated record**, `%04d` disc,
      `%04d` track, basename, then the scan index as the payload
      (`player:1509`). Sorted `-k1,1n -k2,2n -k3,3V` and `cut -f4`
      (`player:1511`). The `%04d` matters: it is what makes the *fallback*
      ordering stable even where the numeric flags are not consulted.
      *Ported as the comparison it stands for; the padding has nothing left to
      do once the numbers are numbers, and where `sort` would have fallen
      through to comparing the record as text the scan index settles it
      instead, so reading an album twice gives the same order twice.*
- [x] **Missing track numbers** all land on 9999 together and are then separated
      among themselves by the natural filename sort — `track2.flac` before
      `track10.flac`, which a plain sort would reverse. Tagged files are
      unaffected, because 9999 sorts after every real track number
      (`player:1451`, `player:1501`).
- [x] **Duplicate `(disc, track)`** — two files both tagged track 3, which is
      what a folder holding `03 Song.flac` and `03 Song (alt take).flac`
      produces — is **not** an error and does not stop anything. The pair falls
      through to the natural basename sort and is ordered by name; the album is
      one track longer than the tags claim and both copies play
      (`player:1511`). Port this as-is. A record that plays a bonus take twice
      in a row is self-evidently what is happening; a record that refuses to
      play is not.
- [x] **`row_of_track` returns the first match**, so with a duplicate track
      number the CD-Text or MusicBrainz title for track 3 lands on whichever of
      the two sorted first, and the other keeps whatever it had
      (`player:1521`). See §18 — the function name says "row" and the value is a
      *file index*.
- [x] **A file that is unreadable still counts** toward the loading percentage:
      `n` is incremented on the skip path as well (`player:1445`). "READING ·
      80%" can therefore count files it did not read. Cosmetic; §18.
- [x] **Nothing is ever sorted by filename alone.** Where the script has to fall
      back that far it is because two files agreed on both numbers, and that is
      already a broken tagging job. Not negotiable, per `spec.md`.

---

## 4. Where the titles came from

Four sources, tried in order of trust, and **the panel always says which one you
got**. A track list is only as good as its source, which is why it is on screen
rather than in a log (README, `player:2054`).

- [ ] `tags` — embedded metadata. The normal case, and the only source a folder
      or a zip ever has (`player:1417`). *The only one of the four nothing
      stamps yet: it is what a source that is not a disc gets, and there is no
      source layer to stamp it. §1.*
- [x] `CD-Text` — read off the disc's lead-in (`player:2251`).
- [x] `MusicBrainz` — looked up by disc ID (`player:2253`).
- [x] `track numbers` — nothing could say (`player:2237`), and the panel says
      `no titles on this disc` (`player:2254`).

### 4.1 CD default

- [x] Before anything is asked, every title matching `*Audio Track*` becomes
      `Track %02d` from its track number, so a failure below still leaves a tidy
      list rather than filenames (`player:2240`). Matched in the two casings the
      script lists and no others — matching case-insensitively would be a wider
      net than the script casts, and this is not the place to widen one.
- [x] Album falls back to the volume name — the basename of the mount point
      (`player:2248`).

### 4.2 CD-Text

- [ ] `cdda2wav dev=… -J -v titles`, falling back to `cdrecord dev=… -toc -v`
      (`player:2070`). *Written, never run — see §19.* The fallback is on the
      script's own condition: the first tool's output not containing `title`.
- [x] Both printed shapes are matched: `Track  1 title: 'X' from 'Y'` and
      `Track  1 title: 'X'`. **The quote that ends a value is the one before
      ` from '` or the one at the end of the line — not simply the next one
      along.** Matching to the next one along cuts `Don't Stop Me Now` down to
      `Don`, and there is no way to tell that from a disc that really is called
      that (`player:2058`). Implemented as the backwards search the greedy
      `\(.*\)` in the script's sed is, so the rule is the same rule and not an
      approximation of it.
- [x] A title that does not match a known shape leaves the tidy `Track 07`
      alone rather than blanking it (`player:2092`).
- [x] **An album title on its own does not count as CD-Text.** Returning success
      for one would stamp `CD-Text` on the faceplate over a column of bare track
      numbers *and* rob the disc of the MusicBrainz lookup that could have named
      them. Album/artist found this way stay put either way; MusicBrainz
      overwrites what it knows better and leaves the rest alone (`player:2106`).

### 4.3 MusicBrainz

- [x] Disc ID to spec: SHA-1 over first track, last track, lead-out offset and
      all 99 track offsets as uppercase hex; base64; then `+/=` → `._-`
      (`player:2123`, `player:2163`). Offsets are TOC frames plus the 150-frame
      pre-gap.
      It fingerprints the *pressing*, which is why it tells the 1984 CD from the
      2011 remaster with the bonus tracks. **The script's is wrong and this one
      is not — D15.** `libdiscid` is here as the *oracle* rather than as the
      implementation: `discid_put()` computes an ID from a table of contents with
      no drive in the machine, so the three tables in `DiscIDTests` carry the IDs
      the reference implementation gives them, and the arithmetic is checked
      against somebody else's rather than against itself. `Scripts/discid-oracle.c`
      is how they were produced; it is not built by the package and nothing links
      `libdiscid`, so a fresh clone still compiles with no brew formula
      installed. **Where the TOC itself comes from is still open — §18.18.**
- [x] The `cdrecord -toc` listing is read into that table: `track: N lba: X`
      lines and the `track:lout` lead-out, first lead-out wins (`head -1`,
      `player:2141`), and a negative LBA is allowed because a hidden track in the
      pre-gap is addressed backwards from track one — the guard against negatives
      runs *after* the +150, not before it (`player:2150`).
- [x] **Changed from bash (D20).** A gap in the track numbering — track 4 absent
      from the listing — is refused rather than filled with a zero. The script
      writes a literal `0` into the missing slot (`player:2156`), and zero is a
      real offset: it produces a plausible disc ID for a disc that does not
      exist, and the lookup then misses silently, which is indistinguishable from
      a disc nobody has submitted. A Red Book disc numbers its tracks
      consecutively, so this is a listing that has been misread rather than a
      disc; the cheaper of the two ways to be wrong is to have no fingerprint
      rather than a confident wrong one.
- [x] Lookup `…/ws/2/discid/<id>?fmt=json&inc=recordings+artist-credits`
      (`player:2181`).
- [x] **The User-Agent is not optional and not decoration.** MusicBrainz requires
      an identifying one and blocks generic ones; the script sends
      `player/1.0 ( https://github.com/gvorbeck )` on **all three** requests it
      makes — the release search (`player:1827`), the Cover Art Archive fetch
      (`player:1915`) and the disc-ID lookup (`player:2180`). Port it with the
      app's own name and version and a URL that resolves —
      `MUTHUR/<version> ( <contact url> )`. One string, set once, used by every
      request the app makes.
- [x] **Timeouts are per-endpoint and deliberately different:** disc ID 12s
      (`player:2180`), release search 15s (`player:1827`), cover art 25s
      (`player:1915`). The cover gets the longest because it is a redirect chain
      to an Internet Archive node and nothing is waiting on it (§5); the disc ID
      gets the shortest because the panel is.
- [x] Nothing is retried on a **timeout**, only on an empty answer, and only for
      the searches — see §5.3 and §5.2. The disc-ID lookup is asked exactly once
      (`player:2180`): it either resolves or the track numbers stay.
- [x] **Take the medium matching the disc ID that was asked about**, not every
      medium on the release. A release is one entry per disc in the box, so
      taking them all concatenates disc two's track list onto disc one's
      (`player:2194`, `player:2201`).
- [x] A release with one medium and no disc IDs listed is still that medium —
      a single-disc answer is worth taking on its own (`player:2204`,
      `player:2206`).
- [x] Release title, artist credit and date overwrite album/artist/year when
      present — and only when present, so a lookup that answers with half an
      answer does not blank the other half (`player:2213`).
- [x] Titles are written **through the track-number → row lookup**, and the
      source is stamped `MusicBrainz` only if the answer carried a track list at
      all (`player:2223`, `player:2228`). An answer with an empty track list is a
      failure, not a success with nothing in it.

      *Correction to this document, not a change to the code.* It said "if at
      least one title actually **landed**", which is what CD-Text does
      (`player:2106`) and not what this does. The script's counter moves before
      the row lookup (`player:2223`), so a disc whose titles all come back for
      track numbers this record does not have is still stamped `MusicBrainz` over
      a column of untouched `Track 01`s. **Offered, not landed.** The asymmetry
      between the two sources is real and it is `player`'s; ported as found,
      because it cannot arise on a disc whose track numbers came off the same
      disc, and the wording here was the mistake.
- [x] The release MBID is kept for the sleeve — a disc ID resolves to one
      release exactly, which is the strongest identification anything here ever
      gets (`player:2190`, `player:2193`). Carried out on `DiscTitles.Outcome`,
      and kept even when the lookup then names no tracks — a release MBID is
      still the strongest thing §5 will ever be handed. Nothing joins the two
      yet; that is §1's wiring.
- [x] Every failure — no network, an unsubmitted disc, a rate limit, malformed
      JSON — means the same thing: the track numbers stay and the panel says so
      (`player:2171`). There is no error, no retry prompt and no diagnostic; the
      one place any of this is ever reported is `--check` (§11).
- [x] Skipped entirely under `--no-mb` / `PLAYER_MB=0` (`player:2176`), and with
      no `curl` (`player:2177`) or no `jq` (`player:2186`, `player:2210`) — all
      three land in the same place as a failed lookup.

### 4.4 Multi-disc sets

Handled, but thinly, and the thin parts are worth knowing before they are
rebuilt.

- [x] **A disc in the drive is one disc.** The medium is picked out of the
      release by the disc ID that asked the question, so disc two of a box set
      gets disc two's titles (`player:2194`, `player:2201`). Bracketed and
      indexed rather than `select`-piped, because one medium carries several disc
      IDs for the same pressing and `select` would emit it once per ID
      (`player:2198`).
- [x] **A folder or zip holding a whole set is one album.** `find` reads at
      unlimited depth (`player:1492`), so `Album/CD1/` and `Album/CD2/` come back
      as one record, ordered disc-then-track by `DISCNOS`/`TRKNOS`
      (`player:1509`). This is right: a two-CD album is an album, the album meter
      shows the whole thing in proportion, and gapless carries across the
      boundary. It is also the case D7 fixed in the picker (§1.2) — the count
      used to stop at depth 1 and so reported such a folder as empty.
- [x] **Disc numbers are the only thing separating the two halves.** A rip whose
      `CD2` files carry no disc tag lands every one of them on disc 1 and
      interleaves the two discs by track number. Untagged is untagged; the script
      does not infer a disc number from a directory name and neither should this.
      Was §18.14 — **resolved as D12**: still nothing off a directory's *name*,
      but a zip whose audio lives in sibling directories has those directories as
      its discs. The behaviour described here is what a *folder* source still
      does, and deliberately.
- [x] **`.releases[0]` is arbitrary.** Album, artist, date and the release MBID
      all come off the first release in the answer (`player:2187`), while only
      the *medium* is chosen by disc ID. A disc ID that resolves to several
      releases — a reissue sharing a pressing, which is the common case for a
      box set — therefore takes its album name and its cover-art key from
      whichever one MusicBrainz listed first. Was §18.1 — **resolved as D16**:
      the release that *contains* the matched medium is the release, and the
      whole answer comes out of that one entry.

---

## 5. The sleeve

Resolution order, and it is deliberate (`player:2004`, `player:2005`):

- [x] **1. A picture beside the record** — searched first and preferred to the
      network, because it is the artwork *this copy* shipped with, where the
      archive can only offer a scan of whichever release the album *name*
      matched, and the name is the weakest thing there is to match on
      (`player:1942`, `player:2020`).
- [x] **2. A picture in the tags** — the attached-pic stream. Mapped as "every
      video stream less the ones that are really video", or a music video sitting
      in the folder has its opening frame pulled out and hung beside the panel as
      a sleeve (`player:1973`, `player:1985`). Copied, not re-encoded — whatever
      was in there at whatever size. Only the first **three** tracks are asked: a
      record that tags its artwork tags it on track one (`player:2025`).
- [x] **3. The Cover Art Archive**, in the background, cached (`player:1903`,
      `player:2035`).
- [x] Nothing ever waits for it. No cover, no network, no window — the panel is
      exactly the panel it would have been (`player:1892`, `player:2035`). The
      fetch is backgrounded and nothing ever joins it; the picture appears when
      it appears, or never, and either way the record is playing.

### 5.1 Ranking pictures beside the record

- [x] `find -maxdepth 3` over `jpg jpeg png webp gif bmp tif tiff`
      (`player:1925`, `player:1951`) — deeper than the picker's scan and
      shallower than playback's, because a sleeve turns up in `Scans/` or
      `Artwork/CD1/` but not at the bottom of an arbitrary tree.
- [x] Names folded: separators → spaces, so `front-cover` is a front cover and
      `discovery` is not a disc (`player:1956`).
- [x] **Thrown out, not ranked last:** `back inlay booklet tray obi spine label
      matrix inside thumb thumbnail`, and `disc|cd|dvd` with optional digits.
      Drawing one of those confidently beside the panel is worse than the network
      answer it displaced.
- [x] Rank 1 exact `cover|front|folder|album|albumart|artwork|sleeve`; rank 2 the
      word `cover`/`front` anywhere as a word; rank 3 the substring; rank 4
      anything else — which is what it takes to find the `Artist - Album.jpg` a
      Bandcamp download leaves you. Ties break on shallowest path
      (`player:1952`, `player:1961`).
- [x] Anything under **200 px** on a side is skipped as a thumbnail or a label
      logo (`player:1949`). Applies to local files and embedded art, not to the
      archive, which only ever sends one size.

### 5.2 Validation and caching

- [x] **Whether a decoder can read the bytes is the only test worth making.** The
      Cover Art Archive redirects to Internet Archive nodes, and a sick one has
      been seen serving an nginx error page under a 200 — labelled
      `image/jpeg`. Neither the status line nor the content type can be believed
      (`player:1858`). ImageIO replaces `ffprobe -show_entries
      stream=width,height` and reads exactly as far — the header. Bytes that are
      not an image are caught; a JPEG whose header is intact and whose data stops
      early is not, in either program. Catching that would mean fully decoding
      every candidate beside the record before the panel's first frame, to cover
      a case the `.part` file already prevents on our side of the wire.
- [x] Cache under `~/.cache/player/art` (`player:2028`, `player:2030`) — **ours
      is `~/.cache/muthur/art`**, following D13 rather than deciding anything
      new: two programs sharing a cache root is a thing that only ever costs and
      never pays, and `player` keeps its own. Keyed on
      the release MBID when there is one, otherwise artist+album folded to
      lowercase alphanumerics so the same
      album tagged two slightly different ways lands on one file (`player:1783`).
- [x] Downloaded to a `.part` beside the cache entry and moved onto it, so a file
      in the cache is always a whole one. The part file is named after the album,
      not the process, so a killed fetch leaves one file the next attempt
      overwrites rather than a new one every time (`player:1896`).
- [x] Up to 5 candidate releases, each tried **twice** — a first failure is more
      often a sick archive node than a missing cover, and the redirect lands
      elsewhere next time (`player:1913`).
- [x] A record with no cover is remembered in a `.none` marker, **expiring after
      14 days**, so an album with no scan does not cost two network lookups every
      single time it is played, and a cover uploaded in the meantime still turns
      up (`player:1879`). Fourteen exactly: the script's `find -mtime +14`
      truncates the age to whole days and so really expires at fifteen, and a day
      either way of a fortnight is not a behaviour anybody has relied on. **What
      gets a marker was §18.4, answered by D14** — see the note at the end of
      §5.3.
- [x] A cache entry that will not decode is one that will not decode next second
      either — stop asking. Cleared, not deleted: another player may be part way
      through writing it (`player:3162`).

### 5.3 Searching by name (no disc ID)

- [x] Quoted-phrase Lucene query, `artist:"…" AND release:"…"`, limit 5. Strict
      on purpose: asked for an artist and an album that do not belong together
      the catalogue answers with nothing rather than with its best guess, and a
      wrong cover drawn confidently beside the panel would be worse than none
      (`player:1803`).
- [x] Terms are URL-encoded, and quotes are stripped out of them first — they
      are the syntax that holds the phrase together (`player:1809`).
- [x] Asked **twice**, a second apart. An empty answer is at least as often the
      rate limiter or a timed-out search index as it is the catalogue
      (`player:1815`).
- [x] Retry ladder for folder-name albums (`player:1842`):
  1. album as tagged;
  2. brackets and parens stripped, underscores collapsed — `Comfort Eagle
     (1998) [FLAC]`, `OK_Computer_(Remastered)`;
  3. `Artist - Album` split, **only** when no album-artist tag stands to
     contradict it.

**§18.4, answered → D14.** The script writes the `.none` marker whatever
happened, including after an attempt that never reached the network. We write it
only when something at the far end replied. `ReleaseSearch.Outcome` carries
`heard` alongside the release IDs, the cover loop sets the same flag on any body
at all, and a cancelled fetch — which never finished asking — marks nothing.
Anything that answered counts, including a rate-limit page or an error document:
those are the catalogue talking, and the retry ladder above is what handles them.
The distinction is only between *asked* and *could not ask*.

---

## 6. Playback

- [x] **Gapless is a requirement.** The whole record is handed to the engine at
      once, in panel order, so it can read ahead into the next file while the
      current one is still playing. A file opened at the moment the previous one
      ends is a file being opened during the silence (`player:2453`).
- [x] Gapless must bridge a boundary **even when the two files disagree on sample
      rate or channel layout** — mpv's "weak" default does not, and a folder with
      one 48k track in it is exactly the album you would notice the gap on
      (`player:2481`). Measured rather than asserted; the numbers are below.
- [x] Row index and playlist index are the same integer, deliberately
      (`player:3239`).
- [x] **One source of truth for what is playing.** Nothing assumes a track
      change; it is asked for and waited on. A track that simply ran out and a
      track picked with the cursor arrive by the same route, so a track started
      by hand and one started by the record itself cannot come to disagree
      (`player:2461`, `player:3265`). Natively that source of truth is
      `Timeline`: the output frame counter, mapped back to a row, an offset into
      it, and a visit number. Nothing else is allowed an opinion about what is
      playing, including the thing that queued it.
- [x] Sequential auto-advance is left alone — it is already right and already
      gapless. **Shuffle no longer interrupts it (D21)**: the shuffled order is
      asked the same question sequential order is asked, at the same moment, by
      the same code, so a shuffled record is gapless too. Bash could not do this
      and paid a seam per advance (`player:3437`). → D21

#### The seam, measured

Gapless is a claim that can be checked with a ruler instead of an ear, so it was.
A pure tone is written across two files so that the second file continues the
first exactly — the two halves are one unbroken tone that happens to be cut in
half. The engine plays the pair, its output is captured, and the capture is
subtracted from the tone the two files add up to. **Whatever is left over is what
the seam did.** Zero left over means the join is not there.

Two numbers matter and they are not the same question:

- **How far the output strays** from the tone it should have been, at its worst.
  Written as a percentage of full volume — full volume being the loudest sound
  the format can hold.
- **Whether it is a step or a slope.** A click is a jump between two neighbouring
  samples that the sound was never going to make on its own. So the biggest jump
  at the join is divided by the biggest jump the tone makes anyway: **1.00 means
  the join is no steeper than the music, and that is the number that means "no
  click."** A genuine one-sample hole in the audio reads about 17 on this scale.

| The seam | Frames lost | Strays by, at worst | Step or slope | Verdict |
| --- | --- | --- | --- | --- |
| **Same rate**, 44.1 k → 44.1 k | none (+0) | 0.0000027 % | 1.00 | **Perfect.** The residue is arithmetic rounding and nothing else. |
| **Same rate on a mixed record** — 44.1 k → 44.1 k where the record is 48 k, so both tracks are being converted | none (+0) | 0.0000148 % | 1.00 | **Perfect.** The converter is carried across the join and never notices it. |
| **Rate change**, 44.1 k → 48 k | none (+0) | **0.133 %** | 1.04 | Not perfect. A soft dip in the last 7 ms of the outgoing track. |
| **Rate change**, 48 k → 44.1 k | none (+0) | **0.133 %** | 1.04 | Not perfect. The same dip, in the first 8 ms of the incoming track. |
| **A real record** — KMRU, *Kin*, 48 k/24-bit, continuous audio across the join | none (+0) | **nil — bit-for-bit identical** | 0.0003 | **Perfect**, in the strongest sense available: every one of 768,648 samples the engine produced is the sample that was in the file. |
| **Two different decoders**, WAV → Opus | none (+0) | 1.9 % | 1.06 | At the codec's own error level (Opus is 1.1 % in mid-track), not above it. |
| **Two different decoders**, Opus → WAV | none (+0) | 1.5 % | 1.08 | Below the codec's own error. Nothing at the join. |

**Frames lost is the first column for a reason.** Every seam is exact: not one
sample is dropped or repeated anywhere, including across a subprocess and a pipe.
A gapless engine that loses a frame per track has drifted a tenth of a second by
the end of a long record, and no error measurement would catch it.

**Where it is not perfect, said plainly.** The rate-change seams came out at
0.133 % — **worse than I expected**, and worth saying so rather than leaving it
under a passing test. Three things about it, in order of how much they matter:

- It is **not a click**. 1.04 against a click's ~17. The disturbance is a smooth
  roll-off about 7 ms long, and it sits **entirely on one side** of the boundary
  — never straddling it, which is what a gap or a step would do.
- It is exactly what the machinery predicts. Where the rate changes, the
  resampler has to be torn down and a new one built, and a resampler's first and
  last few milliseconds are computed against silence it does not have the
  neighbouring track to fill in with. So the tail of the outgoing track fades
  slightly into the join, or the head of the incoming track fades slightly out of
  it. It is a filter edge, not a hole.
- It is **relative, not absolute**: 0.133 % *of whatever is playing*, not of full
  scale. It is always about 58 dB below the music it is happening to — quiet
  under quiet music, and still 58 dB down under loud — which is roughly where a
  well-behaved fade lives rather than where a fault does.

It is fixable — feed the new resampler the tail of the outgoing track as context,
instead of silence — and it has not been fixed, because it costs a decode of the
wrong file in the wrong format at every rate change, and it only ever applies to
a record whose tracks disagree about their sample rate, which is rare and is
already the case bash could not play at all. **Flagged rather than closed.** If it
turns out to be audible on real material, this is the thing to do about it.

The resampler settings came out of measuring, not out of the documentation:
`AVSampleRateConverterAlgorithm_Mastering` at maximum quality (Mastering 0.133 %,
Normal 0.25 %, MinimumPhase 30 %), and — the one real trap — `primeMethod` must
be **`.normal`**, which is the zero-latency mode. `.none` is the *latency* mode
and inserts the filter's entire group delay, 1,253 frames of silence, as an
audible 26 ms hole at every seam where a converter is built. The names are
inverted from what they read like; this cost an afternoon and was found by
measurement.

### 6.1 Transport

| Key | Action |
| --- | --- |
| `␣` | pause / resume |
| `←` `→` / `h` `l` | seek ∓5 s |
| `⇧←` `⇧→` | seek ∓30 s |
| `↑` `↓` / `k` `j` | move the cursor |
| `PgUp` `PgDn` | move the cursor a screenful |
| `⏎` | play the row the cursor is on |
| `n` `p` | next / previous |
| `s` | shuffle on/off |
| `r` | repeat: off → album → track |
| `u` | take the resume offer |
| `q` | quit |
| `-` `=` | volume down / up — **new (D1)** |
| `m` | mute / unmute — **new (D1)** |

- [ ] All of the above (`player:2687`).
- [ ] **Cursor and playhead are two different things.** `♪` is the track the
      music is coming out of (`‖` when paused); the highlighted row with `▶` in
      the gutter is the cursor. Usually they agree; when you browse ahead they do
      not, and the panel has to be able to say so — which is why the playing mark
      is not a second arrow (`player:2344`).
- [ ] Moving the cursor is browsing, and browsing stops the cursor chasing the
      music until you pick something with it again. `⏎`, `n`, `p`, a click on the
      album meter and the resume offer all put it back to following
      (`player:2693`).
- [x] `p` behaves like every deck ever made: within the first 3 seconds it goes
      to the previous track, after that to the start of this one. On track one it
      always restarts (`player:3457`). Under shuffle, "the previous track" is the
      one you actually heard — see §6.1b.
- [x] **Changed from bash (D3).** `n` under REPEAT TRACK **advances**, and the
      mode stays on so the track it lands on is the one that then loops. In bash
      it restarted the current track instead (`player:3414`), which the comment
      there explains as mechanism — setting the playlist position to the row it
      is already on is a no-op — rather than as intent. Repeat-track governs what
      happens when a track runs out on its own; `n` is you saying otherwise, and
      a transport key that visibly does nothing reads as a broken one.
- [x] REPEAT TRACK is the engine's own loop, not a reload on end: a track told to
      start again after it has finished is a file being opened during the
      silence. REPEAT ALBUM stays ours, because it is where shuffle has to be
      asked and one place deciding what follows the last track is easier to be
      sure of than two (`player:2704`, `player:3486`). Proved by counting file
      opens rather than by reading the code: a looping track opens its file once.
- [x] Shuffle — see §6.1b. **Changed from bash (D4).**
- [ ] Status line messages: `▪ SHUFFLE ON/OFF`, `▪ REPEAT OFF/ALBUM/TRACK`
      (`player:2702`, `player:2704`). `u` takes the resume offer and is bound
      only while there is one (`player:2720`). *The two messages are written and
      pinned to the character; the box stays open on `u`, which needs §7.*
- [x] Starting a track clears the status line — including "end of album", which a
      track starting has just made untrue (`player:3398`).

### 6.1a Volume — new, not in bash (D1)

The script has none, on purpose: it plays at whatever the system is set to
(README, *No sound, but the meters are moving*). A terminal program can defer to
the system that way; an app carrying its own transport, its own faceplate and a
Now Playing widget cannot, because it looks like a deck and a deck has a level.

- [x] Its **own** output gain, not the system's. Turning a record down must not
      turn a video call down with it — a player that moves the system slider has
      reached outside its own window (`AVAudioEngine` main mixer). Worth knowing
      when reading the test: the main mixer's gain **ramps** rather than steps —
      which is what stops a volume change clicking, and which means a level has to
      be measured after it has settled or the old level is what comes back.
- [ ] The hardware volume keys stay the system's. macOS handles them above the
      app and they never arrive here — nothing to bind, nothing to fight. What
      the media keys owe us is play/pause/next/previous (§14), which is separate.
- [ ] The level survives a quit. A deck left at 3 is at 3 when you come back.
- [ ] Shown on the faceplate, in the chrome amber, not as data.
- [x] Mute is a state you can see, not a level of zero you have to infer — "no
      sound and I do not know why" is exactly the question the panel exists to
      answer, and §11 answers the other half of it. The level is kept while muted
      and comes back at it, so mute is a switch and not a trip to zero and back.
- [x] **The analyser reads the signal before the gain, not after.** A record
      turned down is not a record playing quietly into its own bands: the columns
      would drop, the per-band autoscale (§9) would spend the next few seconds
      hauling them back up, and the panel would end up saying nothing about the
      music and something about the volume knob.

      It is also the faithful port, which settles it twice over: the script's
      analyser reads the *decoded file*, and there is no volume control anywhere
      in that path — turning the music down never moved its bars because there
      was nothing to turn down (`player:754`). The gain here is
      `engine.mainMixerNode.outputVolume`, so before it means the player node,
      and `PlaybackEngine.listen(_:)` is the one line §10 needed from `Play/`.

### 6.1b Shuffle — changed from bash (D4)

Bash re-rolls `RANDOM % n` per advance and rejects only the current track
(`player:3423`, `player:3441`, `player:3479`). Three separate consequences, none
of them intended: a track can come round again two tracks later, a track can go
a whole sitting without being played, and — because `p` is still `cur_track - 1`
(`player:3462`) — "previous" under shuffle means the row above in album order,
which is a track you have not heard.

- [x] A shuffled **order**, not a die roll per advance: one permutation of the
      rows, walked through. Every track plays once before any track plays twice,
      which is what people mean by the word.
- [x] Switching shuffle on mid-record: the track playing now stays playing, and
      the shuffle covers what is left to hear. Switching it off returns to album
      order from wherever the needle is.
- [x] When the order runs out, **that is the end of the album** — every track has
      had its turn, which is the honest reading and the one bash could not make.
      Under REPEAT ALBUM it reshuffles instead, and the new order may not open
      with the track that just closed the old one, or the reshuffle is audible as
      a track playing twice in a row.
- [x] `p` walks back through what was actually played. A history, not `row - 1`.
      `n` at the end of the history resumes the shuffled order rather than
      re-rolling — walking back and forward again should land where you were.
- [x] Picking a row with `⏎` under shuffle plays it and the order continues from
      there; it does not reshuffle and it does not turn shuffle off.
- [x] **Changed from bash (D21).** Shuffle no longer costs the seam. Bash had to
      interrupt its own gapless auto-advance to redirect it (`player:3437`); here
      the read-ahead asks the transport what follows, and the transport answers
      out of the shuffled order exactly as it answers out of album order, so a
      shuffled record is as gapless as a sequential one. → D21
- [x] Retained from bash: falling off the bottom of the list is meaningless under
      shuffle. The engine walks entries in order and ran out of them; the row it
      fell off is the last one by accident (`player:3473`). What ends a shuffled
      record is the order being exhausted, nothing else.

### 6.2 End of album

- [x] Mode label `FINISHED`, status
      `▪ END OF ALBUM — PRESS Q TO QUIT, ⏎ TO PLAY A TRACK`. The panel says so
      rather than sitting there looking like it hung (`player:3470`,
      `player:3497`).
- [x] Both meters are parked at **full**, not at the fraction-before-the-end the
      last position report carried (`player:3499`, `player:3501`).
- [x] The resume entry is cleared — a record heard to the end is not a record you
      are partway through (`player:3493`, `player:3496`).

### 6.3 A track that will not open

- [x] **The first failure stops the record where it stands.** Left alone, the
      engine walks straight on to the next entry, which for a record whose files
      have all become unreadable means fifty failures in about two seconds and a
      panel saying END OF ALBUM — the same thing it says when a record has simply
      finished. The difference between "you have heard this" and "this is gone"
      is the whole of what the panel is for (`player:3285`).
- [x] Mode label `STOPPED`, not `PAUSED`: a deck that is paused is waiting for
      you, and this one is not (`player:3308`).
- [x] The failure pause must not be reported as the space-bar pause
      (`player:2787`).
- [x] The **whole record is stat-ed**, not the failing file guessed at — the
      interesting case is not a bad rip, it is a whole unpacked album
      disappearing underneath itself (`player:3292`):
  - files missing → `▪ N OF M TRACKS ARE NO LONGER ON DISK`, plus
    `— THE UNPACKED COPY IS GONE. Q, THEN PLAY IT AGAIN` when the source was a
    zip, else `— STOPPED HERE`;
  - files present → `▪ CANNOT READ THIS TRACK · <error> — STOPPED HERE, ⏎ TO TRY
    ANOTHER`.
- [x] Picking a track by hand clears the failure **and takes off the pause it
      put on** — without the unpause, choosing another track after a bad one
      looks like a second failure: the row changes and nothing plays
      (`player:3273`).
- [x] While walking off entries behind a failure, the panel stays on the track
      that actually stopped (`player:2811`).

### 6.4 The meters as controls

- [x] Click the **album** meter → put the needle anywhere in the record,
      whichever track that lands in. The target row is the last one starting at
      or before the point; the remainder is an offset into it (`player:3329`).
- [x] Click the **track** meter → seek within the track.
- [ ] Click a row to select, click it again to play it. The first click moves the
      cursor and the second starts it, which is the difference between reading
      the list with the pointer and being made to listen to whatever the pointer
      happened to land on (`player:3213`).
- [ ] The wheel walks the track list (`player:3188`).
- [x] **Changed from bash (D2).** A drag on the album meter crosses track
      boundaries freely — drag the whole length of the record and the needle
      follows. Bash confined a drag to the track it started in (`player:3340`)
      because a drag reports a position per cell crossed and its loop could only
      have one track-change request outstanding at a time; that is a property of
      talking to another process down a socket, not a decision about scrubbing.
- [x] What survives the lift is the reason underneath it: **do not act on a
      position for a track that is not open yet.** The mechanism differs
      natively, the hazard does not — a drag can outrun the loading of the item
      it has landed in, and the last position the drag reported is the one that
      must take effect when it opens, not the first (see the pending-offset rule
      below).
- [x] A seek that lands in another track is a track change with the offset left
      **pending** until the new track is genuinely playing. A seek sent alongside
      the move lands in the track being left, not the one arriving
      (`player:3336`). The native equivalent — do not seek an item that is not
      the current item — has to be preserved even though the mechanism differs.
- [ ] Middle and right buttons mean nothing here; answering them with a seek
      would be a nasty surprise (`player:3194`).

One thing the far right-hand end of the album meter found, worth writing down
because it will look like an odd line of code otherwise: dropping the needle on
the *last frame of the last track* asks the engine to play nothing at all, and a
deck that has produced no frames still has to be able to notice that the record
has finished. It did not, at first — it sat on PLAYING in silence, because the
condition for finishing was written against having something queued. A record
that produced nothing has still ended. Found by a test, not by ear, and the same
would go for the arrow key run off the end of the last track.

Also from `player:2689` and the arrow keys: `←` and `→` are relative to **this
track**, not to the record — thirty seconds back from ten seconds in is the top
of the track you are on, not ten seconds into the one before it, and that is the
whole difference between an arrow key and the album meter. But forward past the
end still runs the track out and advances, because mpv's relative seek did, and
because it is what an arrow key held down ought to do.

---

## 7. Resume

Not in `spec.md`. It is in the program (`player:1529`).

- [x] Where you had got to is **offered, never applied**. The panel says where it
      left off and waits for `u`. A player that jumps to the middle of side two
      because you played it last week has taken a decision that was yours to
      take, and the one thing you cannot do once it has is un-hear the surprise.
- [x] The key is what the record *is*, not where it lives: the disc ID when there
      is one, otherwise a hash of album-artist + album + track count + total
      duration. A folder that has been moved, and a zip unpacked into a different
      scratch directory every single run, are both still the same album, and a
      key made out of the path would lose them both (`player:1543`).
- [x] Stored at `~/.local/state/player/resume` (`XDG_STATE_HOME` respected), tab
      separated, upserted via a temp file and a rename so a player killed halfway
      through a write leaves the old file whole (`player:1579`). Capped at ~200
      other albums.
- [x] **Not offered** for row 0 at under 30 seconds — that is where the record
      starts anyway, and by the time reading the offer is over you could have
      been there. Anything further in was a real listening session
      (`player:1568`).
- [x] Offer text: `▪ RESUME AT <track no> · <m:ss> — PRESS U`, shown after the
      first track has started, because starting a track clears the status line
      and this is the one thing on it that has to outlive that (`player:2825`).
- [x] Written on every track change (before a note of the new track has played,
      so quitting between tracks comes back to the right one) and then every 5
      seconds of position. A file write a second for the length of a record is a
      lot of writing to save a number that is read once, and five seconds is
      inside the margin of where you would say you had got to anyway
      (`player:2772`).
- [x] Cleared when the record finishes.

**Landed.** `MUTHURKit/Sources/MUTHURKit/Resume/`. `ResumeFile` is the store —
the key, the file, the tab-separated line, the whole-write-and-rename, the cap.
`ResumeWatch` is the tick: it reads the deck's state, decides whether anything is
worth writing, and holds the offer until §10 spends it. **D24** is the shape —
the watch has no reference to the engine, so §7 required no change to `Play/` and
nothing here can move the needle. Two things flagged rather than settled: whose
file this is (**§18.19**) and what the offer says for a row with no track number
(**§18.20**).

The row index a saved entry carries is stable because ORDER is never reshuffled
in place — D4's shuffle is a separate order laid over it, not a permutation of
it — so a resume written last week still names the same track today.

---

## 8. The collection annotation

Not in `spec.md`. It is in the program (`player:1609`).

- [ ] Looks the playing album up in a catalogue CSV (`PLAYER_COLLECTION`, else
      the CSV two directories up from the script) and prints two extra faceplate
      lines: `SHELF` (year · parent genre · tags) and `NOTE`, the note in amber.
- [ ] **This is the one thing a general-purpose player cannot do.** MusicBrainz
      knows what a disc is; only the shelf it came off knows that you bought it
      used at Amoeba and that it skips on track seven — and track seven skipping
      is precisely the moment you want to be told you already knew.
- [ ] **Nothing here is allowed to matter.** No file, a renamed header, an album
      not in the collection — the panel is exactly what it would have been. A
      missing note is not a reason to interrupt a record (`player:1618`).
- [ ] Columns found **by name, not by number** — the two CSVs in that repository
      do not agree on column order, and a lookup that silently reads the wrong
      column is worse than one that finds nothing (`player:1645`).
- [ ] Real CSV field parsing, quoted fields included: `"riot grrrl, compilation,
      punk rock"` is one field with two commas in it.
- [ ] Matching is normalised — lowercased, leading `the ` dropped,
      non-alphanumerics stripped — so `The Beatles` finds `Beatles` and
      punctuation never decides it (`player:1679`).
- [ ] Artist must agree when there is one. With no album artist at all, a title
      match is accepted **only if exactly one** record answers to it — two would
      be a coin toss (`player:1698`).
- [ ] Assembled once per session, not per frame.

**Where the file lives (D5, decided).** Bash resolves it relative to `$0`,
following symlinks, to `../../data/collection.csv` (`player:1631`) — a `.app` has
no such relative path.

- [ ] A **path in Settings**, defaulting to
      `~/Sites/cd-collection/data/collection.csv`, overridable through a file
      picker so the choice is a security-scoped bookmark rather than a string
      that stops working the day the app is sandboxed. `PLAYER_COLLECTION`
      becomes that setting.
- [ ] **The live file, read fresh at launch. Not a copy imported into the app.**
      That CSV is maintained — it is the data behind the collection site in the
      same repository — and a copy would go stale silently. A stale note is worse
      than no note: the entire value of this feature is that it remembers what
      you do not, so a note that is merely out of date is the one failure mode
      that cannot be spotted from the panel.
- [ ] **Read only, ever.** `cd-collection` is not ours to write to (`CLAUDE.md`),
      and nothing here needs to.
- [ ] Header as it stands today:
      `Number,Book,Artist,Title,Year,Parent Genre,Tags,Art URL,Notes,Barcode` —
      recorded as a fact about the file, not as an assumption. Columns are still
      found by name, and a renamed or missing one still means the panel is
      exactly what it would have been.
- [ ] No file, no setting, no match — nothing happens, silently. Not a
      diagnostic, not an error. Unconfigured is the normal state for anyone who
      is not the author.

---

## 9. The analyser

Sixteen bands, five rows, ten frames a second, spaced by octaves rather than
hertz (`player:92`, `player:99`).

- [x] Band centres: `40 59 88 132 197 294 439 655 976 1456 2171 3237 4827 7197
      10731 16000` Hz — even steps in octaves, because that is how the ear
      divides it and how the low end earns enough bands to move independently
      instead of as one lump (`player:109`).
- [x] Bandpass just over an octave wide (`w=1.1` octaves): enough overlap that no
      frequency falls in a gap, tight enough that neighbours still move
      independently (`player:783`).
- [x] Column travel is 40 steps (5 rows × 8 eighths) — the range the falling
      trail needs to actually be seen falling. Fewer and a column is at the floor
      before the eye has followed it down (`player:96`).
- [x] **A column jumps to its new level instantly; only the fall is slowed.** An
      analyser that eased upward would read as a slow analyser, not a smooth one
      (`player:605`).
- [x] Peak-hold trail: it sinks 2 eighths a frame and dims with age down the
      amber ramp, so it reads as the same light going out. A fast transient stays
      visible for longer than the tenth of a second it lasted (`player:667`).
- [x] Filled cells are graded **by row, not by band**: the top is brightest, so a
      column that reaches the ceiling *arrives* there rather than merely being
      tall (`player:632`).
- [x] **Per-band autoscaling, and this is the whole trick** (`player:831`): each
      band is scaled by what *that band* actually does over the track, anchored
      at the **25th and 90th percentile** of its own level distribution, placed a
      quarter and six-sevenths of the way up the column. Not the extremes. A
      record mastered in this century spends its life within a few decibels of
      its own ceiling with a long thin tail down into the gaps between songs;
      scale the tail and every band ends up pinned near the top, twitching —
      which is what this did at first. Throw the tail away and the columns use
      their whole height.
- [x] Minimum scale width 6 dB, so a band that genuinely does not move — a
      constant hiss, a held tone — stays honestly flat a quarter of the way up
      rather than having its own noise magnified to fill the column
      (`player:866`).
- [x] Digital silence is floored at −90 dB, not treated as 0 dB — which is the
      loudest thing there is (`player:819`).
- [x] **It stops dead when there is no sound**, and the test is "is anything
      coming out" rather than "is it paused". A record that has finished, a track
      that would not open, a buffer still filling — all of them are silence, and
      columns dancing over silence is the panel lying about what you are hearing
      (`player:740`, `player:736`).
- [x] The idle state is a floor row lit, not a blank panel — blank is what a
      broken one shows (`player:697`, `player:699`).
- [x] Columns reset at every track change; carrying the last track's heights into
      the next one reads as a glitch (`player:3389`).
- [x] Fallback pattern when levels are unavailable: two travelling waves at rates
      that do not divide into one another, so the columns keep drifting out of
      step instead of settling into a visible loop. It is honest about being
      decoration — it never claims to be the music, it only says the deck is
      running (`player:922`).

**Mechanism (terminal → native).** bash has no audio tap and no FFT, so the
script decodes each track ahead of time through sixteen bandpasses at ~40× real
time and the panel reads a table a row at a time; the next track is measured
while the current one plays and nothing is analysed twice (`player:754`,
`player:766`, `player:3387`). `spec.md` calls for a live `AVAudioEngine` tap + vDSP instead.
**What has to survive is the look, not the method** — every bullet above is
about what the columns do, and the percentile autoscaling in particular has to
be re-derived as something that works on a live signal.

**Landed — the data path, and nothing drawn.**
`MUTHURKit/Sources/MUTHURKit/Analyser/`. `Bands` is the sixteen centres and the
bandpass response; `Spectrum` is the window and the transform, and answers in
dBFS; `BandScale` is the histogram and the two percentiles, one per band;
`AnalyserColumns` is `SPEC_H`, `SPEC_G` and `SPEC_A` and the grading — by row for
the column, by age for the trail — as `Shade` and `Density` rather than as
colours, because §10 owns what an amber is. `Analyser` is the tap and the two
clocks.

The method is **D22** — a weighted transform where bash ran sixteen filters,
checked against real ffmpeg running the script's own chain and agreeing to inside
1.5 dB — and **D23**, the ten-a-second measurement under the twenty-a-second
step. The autoscale is the one thing that could not be ported as it stood, and
the difference is only the sample it is taken over: **§18.21**.

`Analyser.tap` takes any `AVAudioNode`, on purpose. The deck's graph is not
reachable from here and does not need to be, which is why §9 landed without
touching `Play/` and why the whole of it is tested against an engine rendering
offline with no sound card in the room. §6.1a — that the analyser reads the
signal *before* the gain, so a record turned down still moves the columns — is a
question about *which* node, and it is asked of §10 when it wires the two
together.

---

## 10. Panel and layout

The character-grid arithmetic is documented here so the *visual rhythm* survives
even where the constraint does not. `spec.md`: treat the grid as a design grid,
drop the constraint where it only ever existed because of the terminal.

- [ ] Faceplate on every stage — badge, rule, and the machine's state stamped at
      the far end the way a deck prints its mode. Every screen wearing the same
      one is most of why they read as one instrument (`panel.sh:256`).
- [ ] Faceplate meta on the now-playing panel: `PLAYING · 9 TRACKS · tags`
      (`player:2320`). Mode labels: `PLAYING`, `PAUSED`, `STOPPED`, `FINISHED`.
- [ ] Header block: `ALBUM`, `ARTIST`, `SOURCE`, then `SHELF`/`NOTE` when the
      record is in the collection. **The metadata source is not repeated here** —
      the faceplate says it, and saying it twice on one screen reads like two
      different facts (`player:2325`).
- [ ] **Changed from bash (D6). The year is on the panel**, set after the artist
      as `(1979)`, the same shape `-n` prints. In bash it appeared only in `-n`
      (`player:3542`) while the panel's `SHELF` line carried the *collection's*
      year (`player:2333`) — so a record not in the collection showed no year
      anywhere, and one that was in it showed a year that had not come from the
      record.
- [ ] One year, from the first source that has one: tags, then the MusicBrainz
      release date, then the collection. `SHELF` stops carrying it and keeps
      genre and tags, by the same rule as the source label above — where the two
      disagree, that disagreement is not worth two lines on a faceplate.
- [ ] **Amber is the chrome — rules, labels, the badge — and never the data, so
      the titles stay the brightest thing on the screen** (`panel.sh:84`).
- [ ] Band colours zigzag light/dark/light/dark around the panel's own amber, so
      neighbouring bands separate on brightness even where the hues are cousins
      and the edges survive without colour vision (`panel.sh:92`, `panel.sh:97`).
- [ ] **The artist column is dropped on an album and kept on a compilation.** On
      an album every row would carry the same name and that name is already at
      the top: a column that repeats one fact fifty times is not a column, it is
      a margin with writing on it. Dropping it is the difference between
      `Libet's all joyful camarad…` and the title the record actually has
      (`player:2270`).
- [ ] The test is against the *album artist*, not merely "they all agree": a
      record whose tracks say `Miles Davis Quintet` under an album credited to
      `Miles Davis` is not repeating the header, it is saying something else
      (`player:2301`).
- [ ] Decided once per record, not per row — this gives the titles the slack, it
      does not make the edges ragged (`player:2284`).
- [ ] The artist column is sized to the longest name the record actually
      contains, and right-aligned against the durations: two ragged edges facing
      each other read as a gap of no particular width, two flush ones read as a
      margin (`panel.sh:362`, `panel.sh:366`).
- [ ] Truncation is visible — a cut title ends in `…` (`panel.sh:338`,
      `panel.sh:358`).
- [ ] Two meters, because they answer different questions and each is the wrong
      answer to the other's: the track bar is "how much of this song is left",
      which is what you want when deciding whether to skip; the album meter is
      the whole record divided into its tracks in proportion, so you can see the
      shape of the record and where in that shape you are (`player:2260`).
- [ ] Album meter band widths by **largest remainder**, so a longer track can
      never be drawn narrower than a shorter one. Truncating each running total
      independently made exactly that happen — a 3:14 rounded down while the 2:58
      after it landed on a boundary and got more — which is the one comparison
      the meter exists to support (`panel.sh:406`, `panel.sh:414`).
- [ ] A track too short to earn any width gets no band and consumes no colour, so
      the two tracks either side of it still contrast (`panel.sh:448`,
      `panel.sh:453`).
- [ ] The head — the playhead — wins over any band boundary in the cell it is
      in. It is the one thing on the bar that is moving (`panel.sh:484`,
      `panel.sh:505`).
- [ ] Eighth-cell resolution: a boundary falling mid-column is drawn as a partial
      block of the outgoing colour over the incoming one as background. Eight
      times the resolution without one extra column, which is what lets a few
      cells still say that a 3:14 is longer than a 2:58 (`panel.sh:398`,
      `panel.sh:500`).
- [ ] `▾ N MORE` when the list is clamped, worded the same wherever that happens
      (`panel.sh:384`).
- [ ] Keycap legend rows, both of them (`player:2429`, `player:2430`).
- [ ] Loading stage: the album meter with no bands yet, one per file as they
      land, which is the honest picture of the wait. Distinct stages `OPENING`,
      `READING`, `READING DISC` with a per-file/per-step line
      (`player:1148`).

**(terminal)** — reasoning kept, mechanism dropped:

- Fixed 71-column panel, `NP_MIN_LINES` 25×71 floor, row budgeting against the
  window (`np_fit_rows`), and the `\033[H` hazard that makes a frame one line too
  tall lose its top row permanently (`panel.sh:202`, `panel.sh:212`).
- Alternate screen, single-write frames, `\033[K`/`\033[X` bounded erase, the
  `PAINT_COLS` gutter that lets the sleeve survive a repaint (`panel.sh:224`,
  `panel.sh:226`).
- Locale repair and the UTF-8 width primitives — East Asian double-width ranges,
  combining marks and variation selectors, because macOS hands back decomposed
  text (`panel.sh:274`).
- Half-block cover rendering, the 6×6×6 cube vs. 24-step grey ramp choice with a
  saturation guard, the finding that dithering read as checkerboard noise at
  cell resolution, and the iTerm2 inline-image path (`player:2948`).
- `ART_COL0`/`ART_MIN`/`ART_MAX` (12–42 cells) and the rule that the sleeve stops
  where the analyser starts. Note the *reason*: the analyser repaints its rows 19
  times a second with an erase on each and would strobe a hole through the
  picture (`player:3119`). `spec.md` frees the cover from a column range.
- SGR-1006 mouse tracking, and the drag-vs-text-selection cost (`player:147`,
  `player:165`).
- Frame rationing against the clock: a window behind another window on macOS
  drains slowly enough that queued ticks replay as visible catch-up lag
  (`player:2643`). The lesson — drop stale frames rather than render a backlog —
  survives into any render loop.
- `read_key`'s blocking single-mode read, and why ESC is bound to nothing
  (`panel.sh:540`, `panel.sh:548`).

---

## 11. Diagnostics (`--check`)

`spec.md`: this becomes a diagnostics screen, keeping the spirit — it exists so
that "why is mine not working" has an answer. It is also the **only** screen that
speaks in MU/TH/UR's voice (D8, §16).

- [ ] Per-item pass / warn / fail with a fix, and a verdict. Non-zero exit on a
      hard failure only; a warning is worth saying out loud but is not a reason
      to refuse (`panel.sh:595`, `panel.sh:598`, `player:531`).
- [ ] Items to carry across, re-pointed at the native stack: decoder
      availability, the ffmpeg fallback path (Opus/Ogg), zip handling, optical
      drive and media, CD-Text tooling, MusicBrainz reachability (and whether it
      is disabled), **scratch space — free bytes, writability, and whether the
      `$TMPDIR` fallback is in force**, and audio output route.
- [ ] **What the cover will look like, and whether it can be shown at all.** This
      is the question the check is really there for: a sleeve that is silently
      absent looks exactly like a sleeve that failed to download, and the two
      have nothing to do with each other (`player:454`).
- [ ] Warnings are usually fine — "no disc, or no drive" just means the drive is
      empty (README).

**(terminal)** mpv, `nc -U`, `archive://`, UTF-8 locale, window size.

### 11.1 Every message `--check` can print

Fourteen checks and a verdict, all of `run_check` (`player:345`–`player:466`).
This is a feature list in itself: each row is a thing the program needs, the
shape of the answer when it has it, and the sentence it says when it does not.
The **Native** column is what the check becomes when there is no mpv, no `nc`
and no terminal.

| # | Label | Source | Outcomes, verbatim | Native |
| --- | --- | --- | --- | --- |
| 1 | `mpv` | `player:349` | **ok** `<version>` · **fail** `not found. brew install mpv` | Drops — AVFoundation is the engine (§6) |
| 2 | `mpv archives` | `player:355` | **ok** `libarchive present` · **warn** `no archive:// — zips are unpacked to scratch anyway` | Drops — zips are always unpacked (§2) |
| 3 | `ffprobe` | `player:361` | **ok** `<version>` · **fail** `not found. brew install ffmpeg` | Becomes: can metadata be read at all |
| 4 | `analyser` | `player:371` | **ok** `<ffmpeg version>` · **warn** `no ffmpeg — the columns fall back to a pattern` | Becomes: is the audio tap running (§9) |
| 5 | `zips` | `player:379` | **ok** `<tar version>` · **warn** `<unzip version> — no bsdtar, so accented track names may not unpack` · **fail** `no tar and no unzip — zips cannot be opened` | Drops if the zip is read directly (§2.2) |
| 6 | `unix sockets` | `player:386` | **ok** `nc -U present — mpv can be driven` · **warn** `nc present, -U undocumented — probably fine` · **fail** `nc not found — mpv cannot be driven` | Drops with mpv |
| 7 | `optical drive` | `player:395` | **ok** `media: <type>` · **warn** `no disc, or no drive` · **warn** `drutil not found — CDs cannot be detected` | Keep, re-pointed at the native disc layer |
| 8 | `CD-Text` | `player:402` | **ok** `cdda2wav present` / `cdrecord present` · **warn** `no cdrtools — discs fall back to MusicBrainz or numbers` | Keep — this is the §4 fallback chain, on screen |
| 9 | `MusicBrainz` | `player:410` | **warn** `disabled with --no-mb — untitled discs stay untitled` · **ok** `curl and jq present — untitled discs can be looked up` · **warn** `no curl — untitled discs stay untitled. brew install curl` (likewise `jq`) | Becomes: reachability, and whether it is switched off |
| 10 | `scratch space` | `player:423` | **warn** `<N> free in <dir> — cache dir unwritable, so long albums may be reclaimed mid-play` · **ok** `<N> free in <dir>` · **fail** `cannot write to <dir> — zips cannot be opened` | **Keep, and it is the important one** — §2's whole argument is in that warning |
| 11 | `terminal` | `player:438` | **ok** `UTF-8 (<locale>), <cols>x<lines>` · **warn** `not UTF-8 — the meters will render as mojibake` | Drops |
| 12 | `window size` | `player:444` | **warn** `need <N> rows x <M> cols for the panel` · **ok** `room for the panel` | Drops |
| 13 | `cover` | `player:454` | **ok** `off (PLAYER_ART=0)` · **warn** `window is <N> cols — need <X> for a sleeve, <Y> for a full-size one` · **ok** `iTerm2 inline images, at the resolution the screen has` · **ok** `half blocks — a real picture needs iTerm2, outside tmux` | Keep the *question*, not the answers: can a sleeve be shown, and at what size |
| 14 | — | — | verdict: `Ready to play.` / `Not ready to play.` | Keep, and this is where D8's voice belongs |
| — | audio output | — | not in bash | **New** — the route, per §14 |

- [ ] **`fail` is the only thing that changes the exit code**; `warn` is printed
      and counted and does not (`panel.sh:577`, `panel.sh:598`). Ten of the
      fourteen can only ever warn — the check exists to explain, not to gate.
- [ ] The gate is separate from the check and comes after it: `--check` exits on
      its own verdict (`player:531`), and a normal run dies independently if mpv,
      ffprobe or `nc` are missing (`player:538`). Natively the second gate is
      almost empty, and that is the point — most of what could go wrong is a
      degraded picture, not a refusal.
- [ ] Every check is `ok`/`warn`/`fail` **plus a fix**, never a bare status. The
      fix is the reason the screen exists.

---

## 12. `-n` inspect mode

- [ ] Album — artist (year), then `N tracks, M:SS, from <source>`, then a
      numbered list of fitted titles with durations (`player:3540`).
- [ ] The way to get the track list as plain text; a normal run draws the panel.
- [ ] The year shown here and the year on the panel are now the same year, from
      the same precedence (§10, D6).

---

## 13. Settings (from environment variables)

All eight are documented in the script's own header comment (`player:47`).

| Was | Source | Becomes |
| --- | --- | --- |
| `PLAYER_DIRS` | `player:1023` | Which folders the picker scans |
| `PLAYER_WORK` | `player:197` | Where zips unpack |
| `PLAYER_KEEP` | `player:313` | Keep the scratch directory (debug) |
| `PLAYER_MB` = 0 | `player:81` | Skip MusicBrainz |
| `PLAYER_ART` = 0 | `player:498` | Hide cover art |
| `PLAYER_ART` = blocks | `player:498` | **(terminal)** — no native equivalent |
| `PLAYER_DEV` / `BURNCD_DEV` | `player:76`, `panel.sh:627` | **(terminal)** — cdrecord bus address |
| `PLAYER_COLLECTION` | `player:1622` | Path to the catalogue CSV, picked as a bookmark (§8) |
| `XDG_CACHE_HOME` | `player:197` | Where the scratch and art caches live |
| `XDG_STATE_HOME` | `player:1557` | Where the resume file lives |
| — | — | Volume and mute, persisted (§6.1a) — new |

---

## 14. Native, from `spec.md` — in scope, not stretch

- [ ] Real cover art at real resolution.
- [ ] Media keys; Now Playing in Control Center and on the lock screen.
- [ ] AirPlay and correct route handling — **unplugging headphones pauses, it
      does not blast**.
- [ ] Output sample-rate switching for hi-res material.
- [ ] Dock icon, its own Cmd-Tab identity, album art in the Dock while playing.
- [ ] ffmpeg as a *fallback* decoder only, for what AVFoundation will not take
      (notably Opus and Ogg).
- [ ] Drag-scrubbing on both meters (the terminal could not do it).
- [ ] Reduce Motion and Reduce Transparency honoured.

---

## 15. Vestigial — do not port

Set and never read in the source. Listed so nobody rebuilds them looking for the
consumer: `UNTAGGED` (`player:1451`), `MB_TOC` (`player:2155`), `SRC_DETAIL`
after `open_source` (`player:1367`), `COLL_ART` (`player:1719`),
`ART_COLS`/`ART_ROWS` (`player:3159`). `UNTAGGED` is the one of the five that
looks unfinished rather than left over — see §18.15.

---

## 16. Decisions taken

Raised before the code they touch was written, per `CLAUDE.md` — where a
decision in `player` looks wrong, flag it rather than silently improve it. All
twenty-four are settled. Recorded here with the answer so that a departure from
the script is never mistaken later for a porting mistake.

D1–D8 were settled before any code existed. D9–D12 answer §18.2, §18.12, §18.14
and §18.15, raised there and closed here. D13 came out of writing §2, and D14
answers §18.4, which came due while §5 was being written. D15–D19 were all taken
before §4 was written: **D15** is the one place this port knowingly does
something the script does not because the script is *wrong* rather than because a
decision went the other way; **D16–D19** answer §18.1, §18.6, §18.7 and §18.11.
**D20** came out of writing §4.3, and **D21** out of writing §6 — the second
place, after D15, where the port does better than the script rather than
differently. **D22–D24** came out of writing §7 and §9: two of them are about
*method* rather than behaviour, which is what §9 explicitly asks for — the look
survives, the mechanism cannot — and the third is the shape that keeps §7 from
ever moving the needle.

**D1 — volume. Gained.** The script has none on purpose (README, *No sound, but
the meters are moving*), but an app with its own transport and a Now Playing
widget is in a different position. Its own gain, not the system's. → §6.1a

**D2 — album-meter drag. Confinement lifted.** Bash kept a drag inside its
starting track because it could only have one track-change request outstanding
over a socket (`player:3340`); that is a property of the IPC, not a view about
scrubbing. The hazard underneath it — never act on a position for a track that is
not open yet — survives. → §6.4

**D3 — `n` under REPEAT TRACK. Now advances.** Bash restarted the track
(`player:3414`) and the comment explains only the mechanism. Repeat-track governs
what happens when a track runs out by itself; `n` is you saying otherwise, and a
transport key that visibly does nothing reads as broken. The mode stays on and
the track it lands on is the one that loops. → §6.1

**D4 — shuffle. Rebuilt.** A shuffled order, walked through, every track once
before any track twice; `p` walks the history you actually heard; the order
running out is the end of the album. → §6.1b

**D5 — the collection CSV. A path in Settings, read live.** Default
`~/Sites/cd-collection/data/collection.csv`, overridable through a file picker so
the choice is a security-scoped bookmark. Not an imported copy: that file is
maintained, and a stale note is worse than no note, because being out of date is
the one failure this feature cannot show on the panel. Read-only, always. → §8

**D6 — the year. On the panel.** After the artist, as `(1979)`. One year, from
tags → MusicBrainz → collection; `SHELF` stops repeating it. → §10

**D7 — picker depth. Unified.** The count now looks as deep as playback reads.
The `maxdepth 1` was avoiding forks, not guarding anything, and it hid any album
whose tracks live in `CD1/`. The *scan* for candidate folders stays one level
deep — that part is the guard. → §1.2

**D8 — MU/TH/UR as an interaction conceit. Confined to diagnostics.**

`spec.md` names the diagnostics screen as the one place it would genuinely fit,
and that is exactly as far as it should go. The rule:

- [ ] **Nothing stands between launching and sound.** No boot sequence, no
      dialogue, no acknowledgement to dismiss. The failure mode `spec.md` names —
      an app that makes you read before it will play a record — is the only way
      this goes wrong, and it goes wrong permanently: a joke you cannot skip is
      not a joke by the fourth listen.
- [ ] Diagnostics answers in the first person, flat and declarative, the way a
      ship's computer answers a query. It reports. It does not banter, it is not
      withholding, and it never has anything to say that is not an answer.
- [ ] Everywhere else it is a name on the chassis. In particular the playback
      failure messages stay exactly as blunt as they are — `▪ N OF M TRACKS ARE
      NO LONGER ON DISK`. They already read as a machine talking, which is
      precisely why they work, and dressing them up would put personality between
      you and the reason your record stopped.
- [ ] It is a voice, not a conversation. No prompts, nothing that waits for a
      reply.

This is cheap to reverse in either direction, and worth revisiting only once the
diagnostics screen exists and can be looked at.

**D9 — `row_of_track`. Intent, not confusion.** → §18.2, §3

The script's function returns a *file index* and is named for a *row*. It is
right today only because the sole caller is the CD path and a CDDA volume's scan
order is its track order; the name is what would make the next caller wrong. The
port keeps the behaviour exactly — first match wins, so a duplicate track number
sends the incoming title to whichever file sorted first — and splits the name in
two: `Record.fileIndex(ofTrackNumber:)` for what §4 writes back through, and
`Record.row(ofTrackNumber:)` for the one caller that genuinely wants a position
in the running order. Nothing about what the program does changes. What changes
is that the next person to reach for it gets the one they meant.

**D10 — the `READING · N%` counter. Kept as-is.** → §18.12, §3.1

It counts files it skipped. That is progress through the *folder*, not through
the album, and the folder is what the meter is measuring: the denominator is the
pre-count of the same scan, so the percentage is honest about the work being
done and reaches 100 exactly once. Making it count only the readable files means
a denominator you cannot know until you have finished, which is a meter that
jumps. Left alone deliberately, not inherited by accident.

**D11 — `UNTAGGED`. Finished, as derived data.** → §18.15, §15, §10

The flag looks like the start of a notice that was never built, so build the
notice. But not as a flag: `Record.unnumberedCount` is computed from the rows
whenever it is asked, because §4 rewrites rows after §3 has read them and a
remembered boolean would still be describing the album as it arrived. The number
is also more use than the boolean — "3 of 12 tracks are untitled" is a different
sentence from "this album has no tags", and the panel can tell which it is
looking at. The script's variable stays in §15 as vestigial: what is being
ported is the intention behind it, not the variable.

**D12 — disc numbers. No inference from names; a subdirectory is a disc.**
→ §18.14, §2.2, §3

Two questions were tangled together and they get opposite answers.

*Parsing a number out of a folder called `CD2`* — no. That is guessing structure
from a string, which is the exact move the metadata-not-filenames rule exists to
forbid, and it fails on `Disc Two`, on `bonus`, and on a folder called `CD2` that
is a track. Nothing is inferred from what a directory is called. Ever.

*Noticing that the audio is in more than one directory* — yes. That is not a
name, it is the shape of the archive, and a zip whose maker put the audio in two
folders was telling you something no tag was going to. So: **when a zip's audio
lives in more than one directory, and those directories are siblings, they are
the discs** — numbered by the same byte-order scan the files are, and the number
lands on any file whose own `disc` tag did not say. A tag always wins over the
directory it sits in — the rule fills the gap the script fills with a literal
`1`, it does not overrule anything. An archive with one directory in it behaves
exactly as before.

The sibling requirement is §18.17, and it is what stops a stray file at the top
of a zip becoming disc one of two. In full: discard any audio directory that has
another audio directory under it — that one is the thing the discs are *in*, and
files loose in it fall back to the literal `1`. If two or more directories are
left and they all share a parent, those are the discs. Anything else is not a
shape this can read, and nothing is guessed. It is structural rather than a
threshold, for the same reason nothing is read off a directory's name, and it
keeps a disc that holds a single forty-minute track.

What it costs: **disc one loose at the root with disc two in a folder is not
detected.** That layout is byte-for-byte the same archive as one stray file
beside an album, so there is nothing there to tell them apart. Both fall back to
disc `1`, which is what the script does with either.

The case this is for is the common one: a two-disc rip with no disc tags at all,
which used to interleave both discs into disc 1 and put nine track 1s in a row.
The case it deliberately does not catch is a two-disc rip where every file is
tagged disc 1 — the tags there are wrong rather than absent, and a tag that is
present and wrong is not something this can tell from a tag that is present and
right. Scoped to zips, because that is where it was asked for; folder sources
read at any depth (D7) and have the identical problem, and extending it there is
one argument at one call site when somebody wants it.

**Written, not wired up.** The rule lives behind `Record.read`'s
`discsFromSubdirectories`, which defaults to off, and the only callers passing
`true` are its tests. Turning it on for a real zip needs two things that do not
exist: a source layer (§1) to open the zip in the first place, and something to
carry the fact that it *was* a zip from there to the read. Both are boxes in
§2.2 now. Until they land, an actual two-disc zip behaves exactly as it did
before this decision — the tests are the only place the rule has ever run.

**D13 — the scratch root. Its own, not the script's.** → §2

`player` unpacks into `~/.cache/player/work/player.XXXXXX` and sweeps
`$base/player.*` on the way in. Sharing that base would put two programs' sweeps
over each other's directories, and the sweep's whole job is deleting things it
did not create. So MU/TH/UR takes `~/.cache/muthur/work`, makes
`muthur.XXXXXX`, and sweeps only `muthur.*` — the two can then run at once
without either being able to reach the other's album, which is exactly the
guarantee §2's "two decks at once" box asks for, one program further out than the
script had to think about it. `MUTHUR_WORK` and `MUTHUR_KEEP` are the settings;
`PLAYER_WORK` and `PLAYER_KEEP` are still read as fallbacks, because somebody
with those already exported meant them (§13).

**D14 — the `.none` marker. Only for an answer.** → §5.2, §18.4

`art_fetch` writes the fourteen-day "this record has no cover" marker whatever
happened, including after an attempt where nothing on the machine ever reached
the network (`player:1921`). The wifi being off once then costs the record its
sleeve for a fortnight, and the fortnight is the point: the marker exists so a
record with no scan does not pay two lookups every play, which is a fact about
the record. "Could not ask" is a fact about the machine, and it is not the same
fact — it will be false again the next time the album is put on, whereas the
absent scan will not.

So we mark only when something at the far end replied. Anything it says counts,
including a rate-limit page or an error document: those are the catalogue
talking, and §5.3's ask-twice ladder is already what handles them. A cancelled
fetch never finished asking and marks nothing. `SleeveTransport` had the
distinction from the start — `.couldNotAsk` is not `.body` — so the change was
carrying it out through `ReleaseSearch.Outcome.heard` and one guard in
`SleeveResolver.fetch`.

Not a divergence anybody will see except as an absence: the only visible
difference is a sleeve turning up on the play after the network comes back,
where the script would have gone without one until the marker expired.

**D15 — the disc ID. To the published standard, not to the script.** → §4.3

The one place this port knowingly departs from `player` on the grounds that the
script is *wrong*, rather than because a design decision went the other way.

`mb_discid` builds the 804-character hex string correctly (`player:2154`) and
then hashes the wrong thing:

```
printf '%s' "$hex" | xxd -r -p | shasum -b | cut -d' ' -f1 | xxd -r -p | base64 | tr '+/=' '._-'
```

The *second* `xxd -r -p` is right and necessary — base64 wants the raw twenty-byte
digest. The first one is not. It turns the 804 ASCII hex characters back into 402
raw bytes and hashes those; MusicBrainz, and `libdiscid`, SHA-1 the *characters*.
Verified against `discid_put()` on a fifteen-track table:

```
libdiscid            J5VseIjrnogYWZ4AcpTUXMOI.XY-
the standard method  J5VseIjrnogYWZ4AcpTUXMOI.XY-   ✅
the script's method  cuvuraCP7pjIplh8tHDVqV2hHCU-   ❌
```

So `mb_lookup` has almost certainly never resolved a disc — every lookup asks
about a fingerprint no catalogue has ever seen. §4.3's deliberately silent
failure path is exactly what would let that go unnoticed for years: no network,
an unsubmitted disc, a rate limit and a scrambled ID all print the same
`track numbers` on the panel.

The two halves of parity could not both be honoured either — §4.3 already said
"Disc ID **to spec**" and "the resulting ID must match", so the document
described the intent while the code diverged from it. The intent wins.

`libdiscid` is the oracle rather than the implementation. `discid_put()` computes
an ID from a table of contents with no drive in the machine, which is what makes
this testable today: `DiscIDTests` carries three tables and the IDs the reference
implementation gives them, produced by `Scripts/discid-oracle.c`. The package
neither builds nor links it — adding a system-library target would make a fresh
clone need a brew formula before it would compile, for code that cannot run
without a disc anyway. What the suite pins instead is the thing that went wrong:
**804 characters go into the digest**, not 402 bytes.

**D16 — which release the answer comes from. The one holding the medium.**
→ §18.1, §4.3, §4.4

The script picks the *medium* by disc ID (`player:2201`) and then takes title,
artist, date and the release MBID from `.releases[0]` (`player:2187`), so on a
multi-release answer the two halves of one lookup come out of two different rows:
the track list is this pressing, the album name and the cover-art key are
whichever pressing MusicBrainz happened to list first. That is not a trade-off,
it is an inconsistency — and the cover is where it bites, because a wrong MBID
fetches a *real* sleeve for the wrong pressing and draws it confidently, which is
the failure §5.3 already argues is worse than none.

So: the first release containing a medium whose `discs` list carries our ID, and
the whole answer comes from that release. Where none does, `[0]` still, with the
existing "one medium and no disc IDs listed is still that medium" rule untouched.
On a single-release answer — the common case — `[0]` *is* the matching release
and nothing changes. It differs only where the script was arbitrary.

**D17 — `find_cd`'s `/Volumes` fallback. Gated on the device, not on the
listing.** → §18.6, §1.3

`burncd` is what makes this a fact rather than a better heuristic: `drutil
status` prints the media's device node on the same line as its type — `Type: CD-R
Name: /dev/disk8` (`burncd:322`). So the volume that is the disc is the one whose
backing device is the node drutil named, and no amount of AIFF-counting should be
able to overrule that. The shape test stays exactly as `player` has it; it is now
a second condition rather than the only one. Where drutil names no device, fall
back to the script's ordered scan — degraded, not refused, per §17.

What it prevents: an AIFF-heavy external volume being announced as "in the
drive", and then CD-Text and MusicBrainz answers *about the disc* being written
over its tracks (`player:1009`). Nothing here is written yet — §1.3 is, by your
call, waiting for the drive to be connected.

**D18 — the picker's disc row. Counted like every other row.** → §18.7, §1.2

`ls | grep -ic '\.aiff\?'` (`player:1019`) instead of `audio_count`, which was
right there. A CDDA mount is AIFF, so the common case is byte-identical and this
is right by coincidence; the row it is wrong in is the one offering you the disc,
and `0 tracks · in the drive` beside a disc that plays perfectly reads as a
broken drive. One definition of what counts as audio, used everywhere — which is
also the shape D7 gave the picker's other two row kinds, one line further up.

**D19 — CD-Text's album on a CD-Text failure. Kept.** → §18.11, §4.2

`cd_text` sets `ALBUM` and `ALBUM_ARTIST` and *then* returns failure when no
track title landed (`player:2082`, `player:2111`), and its comment says it means
to. So an album name can come from CD-Text under a faceplate reading `MusicBrainz`
or `track numbers`. Kept, because the label is answering a narrower question than
it looks like it is answering: **it says where the track list came from**, which
is the column you are looking at and the one whose provenance you would ever
doubt. The album is one field, it is right, and throwing it away to make a label
tidier would be trading information for consistency.

Written down here rather than left in the code, because it looks like a bug every
time anyone reads it — which is the actual cost, and the only thing this decision
can do about it.

**D20 — a gap in the `cdrecord -toc` listing. Refused, not zero-filled.** → §4.3

The script writes a literal `0` into a track slot the listing did not mention
(`player:2156`). Zero is a real offset: the result is a well-formed disc ID for a
disc that does not exist, the lookup misses, and the miss is indistinguishable
from a disc nobody has submitted. A Red Book disc numbers its tracks
consecutively, so a gap is a listing that has been misread rather than a disc
that is shaped that way — and of the two ways to be wrong, having no fingerprint
is much cheaper than having a confident wrong one. Came out of writing the parser
rather than out of reading the script.

**D21 — shuffle is gapless too. Improved, not retained.** → §6, §6.1b

Bash gave the whole record to mpv and let mpv advance itself, which is why its
auto-advance is gapless and why it could not shuffle without breaking it: to play
something other than the next entry, it had to reach in and move the playlist
position, and that interrupts the thing that was reading ahead (`player:3437`).
The README says as much, and the parity document said as much until this landed
— shuffle costs the seam, and that is the trade.

Natively there is no playlist to reach into. One node is fed buffers, and the
question *what plays after this* is asked once, in one place, by the thing doing
the reading ahead — which asks `Transport`, and `Transport` answers out of the
shuffled order or out of album order without the caller knowing which. Shuffle
stops being an interruption and becomes an answer. So a shuffled record is
gapless, and on an ambient album — the kind where the seam is audible at all —
that is not a small difference.

Two edges, both real:

- Turning shuffle on, or `n`, or a pick, while the feeder has already read into
  the track that *would* have followed: those frames are queued and the ear has
  not heard them. They are dropped and the deck resyncs, which costs that one
  seam. It is the same cost bash paid, but paid once when you press the key
  rather than once per advance — and a key press is a moment you already expect
  something to happen at.
- Reading ahead means the order can be a step further along than the ear is, so
  `n` and `p` have to be answers about what is *playing*. The history carries an
  index and the engine settles it back to the ear before asking. Otherwise `p`
  during the last two seconds of a track takes you back to the track you are
  still listening to.

This is an improvement over a program that has been used and debugged, so it is
written down rather than made quietly: bash's behaviour here is a consequence of
talking to mpv down a socket, not a decision about what shuffle should sound
like, and the same reasoning D2 uses about drags applies.

**D22 — the analyser's window. A transform, where bash ran a filter.** → §9

The script measures a band by running the samples through an actual bandpass and
asking `astats` for the RMS that comes out — sixteen decoding passes, offline, at
forty times real time (`player:783`). Live, that is sixteen IIRs on the render
thread. Instead one windowed transform is taken per tenth of a second and each
band's level is the transform's power weighted by *that band's* frequency
response — the same RBJ bandpass, `width_type=o`, `w=1.1`, coefficients built
from ffmpeg's own `af_biquads.c` formula, evaluated as `|H(e^{jω})|²` rather than
run as a filter.

The numbers are the same numbers. `AnalyserAgainstFFmpegTests` writes a file with
a tone in every one of the sixteen bands, runs the script's exact chain over it
with real ffmpeg, and compares band for band: they agree to inside 1.5 dB across
the whole spectrum, and a full-scale sine reads −3.01 dB to both. It is one
sixteenth of the work and it needs no decode ahead of the ear.

Two consequences worth having written down. The window is Hann rather than the
square window an offline filter effectively gets — an FFT of a square window
smears every tone across the spectrum through its own skirts, which would light
bands the music is not in — and the transform is normalised by `Σw²` so a Hann
window costs nothing in level. And the readings are of the window alone, with no
memory of what came before, where ffmpeg's IIR carries its whole history; on a
settled signal that is the 1.5 dB above, and on a transient it means this reacts
one window faster than the script did, which is the direction you want.

**D23 — the analyser's two clocks. Kept apart.** → §9, §10

Levels arrive ten times a second (`SPEC_HZ`) and the columns step twenty times a
second (`TICK_HZ`) — the script indexes a ten-a-second table by position once per
tick, so every level is stepped twice (`player:2661`, `player:2878`). `SPEC_FALL`
is 2 eighths per *step*, not per level: forty eighths a second, the whole height
of a column in one.

Recorded as a decision because it is invisible in the source and expensive to get
wrong. Folded into one clock — which is the obvious reading of "ten frames a
second" in §9's own heading — the trails fall at half the rate they should, and a
peak takes two seconds to come down. `Analyser.frame()` is therefore the tick and
not the measurement, and takes the latest reading whether or not it is new, which
is exactly what indexing a table by position does.

**D24 — resume is an observer. The deck never hears from it.** → §7, §6

§7 says the position is offered and never applied, and the code is arranged so
that it cannot be applied by accident: `ResumeWatch` reads `PlaybackEngine.state`
on the tick and writes a file, and has no reference to the engine at all — no
`apply`, no seek, nothing that moves the needle. Spending the offer hands back a
row and a position for §10 to do something with when `u` is pressed.

The consequence is that **§7 required no change to `Play/`**. The engine's own
track changes and its finish are tick-driven, so an observer polling at the same
rate sees both at the moment the engine does; §7's "written before a note of the
new track has played" falls out of that rather than needing a hook. Worth saying
because the alternative — a callback from the deck into a state file — would have
put a filesystem write on the path that advances a record.

**D25 — the resume offer counts rows, not track numbers.** → §7, §18.20

The script's offer prints the *tag's* track number (`player:2828`). A row with no
number in its tags carries 9999 — which is §3.1's sort sentinel, a number chosen
so that untitled rips fall to the end of a running order, and never meant to be
read by a person. On a folder of untagged rips every row is 9999, so the offer
said the same thing about the fourth track as about the first.

The offer now counts the stored row: row 3 is `RESUME AT 4`. That is the number
the panel prints in the list beside it, and it is the number `u` acts on — the
row index has always been what field two holds and what the resume actually uses,
so this makes the sentence agree with the behaviour rather than with the tag.

**The file does not change.** This is display text and nothing else — the same
four tab-separated fields go in and come out, because §18.19 makes that permanent
and the bash player has to keep reading them.

---

## 17. When something is missing

The degraded paths, gathered in one place because they are scattered through the
script and every one of them is easy to skim past. **The rule the whole program
follows: the only thing worth stopping for is not being able to play the
record.** Everything else quietly becomes a worse panel.

### No network

- [ ] Every MusicBrainz and Cover Art Archive failure is silent and
      indistinguishable from every other one. No error, no retry prompt, no
      "offline" indicator anywhere on the panel (`player:2171`).
- [ ] A disc with no CD-Text and no network plays as `Track 01…Track NN`, source
      `track numbers`, and the panel says so (`player:2237`, `player:2254`).
- [ ] A folder plays entirely normally: tags are local, and the only thing lost
      is a cover that was not already beside the record or in the file.
- [x] **The script's one durable consequence — a purely offline art fetch still
      writes a `.none` marker** (`player:1921`), so an album whose cover was
      looked for during an outage has no cover for the next **14 days**. Raised
      as §18.4 and answered: we do not carry it (D14). An outage now costs
      nothing beyond the play it happened on.
- [ ] `--check` reports MusicBrainz as reachable tooling, not as reachability
      (`player:410`). Natively it should actually ask.

### No CD drive, or no disc in it

- [ ] `drutil` absent → `--check` warns `drutil not found — CDs cannot be
      detected` (`player:399`) and `find_cd` returns nothing (`player:965`).
- [ ] `drutil` present, tray empty → `--check` warns `no disc, or no drive`
      (`player:397`); the picker simply has no disc row (`player:1018`); `--cd`
      dies with `no audio CD in the drive` (`player:3528`).
- [ ] **Not having a drive is not a warning worth escalating.** Most Macs have
      not had one for a decade, and the check says so in one line and moves on.

### A disc that will not read

- [ ] `drutil` says media is present but nothing mounts → detection falls through
      to the `/Volumes` scan and finds nothing; the disc is invisible
      (`player:1000`). There is no "the disc is unreadable" message and there
      never was one.
- [ ] A disc that mounts and then stops responding is §6.3: the first failed
      track stops the record, mode `STOPPED`, whole-record stat, and the message
      distinguishes files missing from files unreadable (`player:3285`,
      `player:3315`).
- [ ] CD-Text tooling that errors is treated exactly as CD-Text absent
      (`player:2064`) — down to MusicBrainz, then to track numbers.
- [ ] A partially readable disc plays what it can: `read_metadata` skips files
      ffprobe cannot open (`player:1445`), and only zero readable files is fatal
      (`player:1494`).

### A folder with mixed formats

- [ ] Thirteen extensions, case-insensitive, in one album with no special case
      anywhere (`player:1046`). A folder of FLACs with one MP3 bonus track is one
      album.
- [x] **Gapless must bridge a format, rate or layout change**, which is the
      §6 requirement restated: this is exactly the album where the seam would
      show (`player:2481`). Measured both ways round, and honestly: see §6.
- [x] Per-file decoding is per-file. Natively that means the AVFoundation path
      and the ffmpeg fallback path can be in use in the same record, and the
      transition between two tracks that took different paths still has to be
      gapless. It is: the fallback decodes at the file's **native** rate rather
      than at the record's, so both decoders present the same kind of frames and
      the graph never finds out which one produced which. Measured across a WAV →
      Opus join in both directions — not one frame lost through a subprocess and
      a pipe, and the join no worse than Opus is in mid-track.

### A folder with no metadata at all

- [ ] Every track sorts on key 9999 and is ordered by natural filename
      (`player:1451`, `player:1511`) — which for `01 … 12` is the right answer
      by accident, and for `Track A/Track B` is the only answer available.
- [ ] Every title is the file's basename (`player:1481`).
- [ ] Album is the folder's own name, or the zip's minus `.zip`
      (`player:1497`). Artist and year stay empty and the panel simply has less
      on it — no placeholder, no "Unknown Artist".
- [ ] Source stays `tags` even when there were none, because for a folder there
      is nothing else it could be. Only a CD gets a fallback chain (§4).
- [ ] The sleeve is still looked for beside the record (§5.1), which for an
      untagged folder is usually the only thing that finds one — the name-based
      MusicBrainz search (§5.3) has an album name and no artist and returns
      nothing, on purpose (`player:1803`).

### The album disappears mid-play

- [x] The case §2 exists to prevent, and §6.3 exists to explain: fifty tracks
      failing in two seconds must not read as `END OF ALBUM` (`player:3285`).
- [x] When the source was a zip the message names the cause:
      `— THE UNPACKED COPY IS GONE. Q, THEN PLAY IT AGAIN` (`player:3315`).
      Tested by deleting the files out from under a record that is playing.

### No ffmpeg

- [ ] Bash: `--check` warns `no ffmpeg — the columns fall back to a pattern`
      (`player:367`, `player:374`); `SPEC_OK` goes to 0 (`player:253`) and the
      analyser draws
      two travelling waves that never settle into a loop (`player:928`).
- [ ] Native: ffmpeg is the *fallback decoder* only (`CLAUDE.md`), so its absence
      means Opus and Ogg will not play — a different and larger consequence than
      the script's. The analyser is a live tap and does not depend on it at all.
      `--check` has to say the new thing, not the old one.

---

## 18. Unsure whether these are features

Found while reading, and not obviously either intended behaviour or a bug. Per
`CLAUDE.md`, a decision in `player` that looks wrong gets flagged rather than
silently improved: each needs a yes or a no before the code it describes gets
written, and nothing is ported or "fixed" until it has one.

Thirteen are answered — **1, 2, 4, 6, 7, 11, 12, 14, 15, 16, 17, 19 and 20**,
each marked below and carrying the decision it became. The other eight are still
open. **17** and **18** are the odd ones: not `player` behaviours at all, but
holes in decisions made here, which is why 17 was answered as fast as it was
found. **21** is odder still — not a question but a consequence, listed because
it is a difference from the script that nobody chose, and it stays open until it
has been watched on a real record.

Six of the seven open ones describe code that has not been written yet. **4** was
the exception until §5 landed around it and forced the question; it is now D14.
**1**, **6**, **7** and **11** came due together when §4 was about to be written
and were answered before a line of it existed — 1 and 11 in the code that landed,
6 and 7 in §1, which is still ahead.

**5** is the other exception, and it needs an answer it has not been asked for:
§2's port has one unpacker rather than `unzip` and `tar`, and it already prints
`nothing came out of <source>` on the empty-archive path (`Unpacker`,
`player:1308`). The asymmetry the item is about cannot occur here, so the
question is only whether that was the right half to keep. It reads as yes.

**Probably bugs, but they have shipped and been lived with:**

1. **`.releases[0]` decides the album name.** Title, artist, date and the release
   MBID all come from the first release in the disc-ID answer, while the medium
   is correctly chosen by disc ID (`player:2187`, `player:2201`). A disc ID
   resolving to several releases takes its name — and its cover-art key — from
   whichever MusicBrainz happened to list first. *Match on the release that
   actually contains the matched medium, or keep `[0]`?* — **Resolved: the
   release that holds the medium, and the whole answer comes from it. → D16.**

2. **`row_of_track` returns a file index, not a row** (`player:1521`). Harmless
   today because only CD sources call it and a CDDA volume's scan order is its
   track order. It is wrong for anything else, and the name hides that. *Port the
   confusion, or port the intent?* — **Resolved: the intent. → D9.**

3. **`collection_lookup`: the last duplicate row silently wins.** The END rule
   accepts multiple hits whenever an album artist is present
   (`if hits==1 || (hits>1 && want_a!="")`, `player:1706`) while the awk body
   overwrites its variables on every match — so two rows for the same
   artist+title give you the later one, with no indication there were two.
   *Prefer the first? Refuse ambiguity the way the no-artist path already does?*

4. **`art_fetch` caches "no cover" after a purely offline attempt**
   (`player:1921`). Fourteen days of no sleeve because the wifi was off once.
   *Distinguish "asked and there is none" from "could not ask"?* — **Resolved:
   distinguish them. → D14.**

5. **`unpack_unzip` never checks that anything came out** (`player:1315`), where
   `unpack_tar` has `[ "$n" -gt 0 ] || die "nothing came out of …"`
   (`player:1308`). An `unzip` that exits 0 having written nothing produces `no
   audio in <source>` from a later function instead of the accurate message.

6. **`find_cd`'s `/Volumes` fallback accepts any volume with two AIFFs** once
   `drutil` reports media (`player:1009`). With a disc in the drive and an
   AIFF-heavy external volume mounted, the external one can win, and then CD-Text
   and MusicBrainz answers about the disc get applied to it. — **Resolved: keep
   the shape test, gate it on the device node `drutil` names. → D17.**

7. **The picker counts CD tracks with `ls | grep -ic '\.aiff\?'`**
   (`player:1019`) rather than `audio_count`. A CDDA mount presenting anything
   other than AIFF would show `0 tracks` in the row it is being offered by. —
   **Resolved: one counter, the same one every other row uses. → D18.**

8. **`time-pos` parsing matches only non-negative numbers** (`player:2758`), so a
   negative position — which mpv can briefly report across a seek — leaves the
   previous position in place rather than being ignored deliberately. Probably
   fine, probably accidental, and it does not survive the port anyway.

9. **`lead` in the CD filename rescue is not declared `local`**
   (`player:1460`). A global leak, not a feature. Noted only so it is not
   faithfully reproduced.

**Deliberate, but entangled with the terminal, so the port has to choose:**

10. **`art_start` refuses to look for a cover at all unless the terminal is
    UTF-8** (`player:2008`). Sensible where the only renderer is half-blocks;
    meaningless natively. *Assumed dropped — the sleeve is a picture in a window
    now — but it is a gate on a whole feature, so it is here rather than assumed
    quietly.*

11. **`cd_text` sets `ALBUM` and `ALBUM_ARTIST` even when it returns failure**
    (`player:2082`, `player:2111`), and the comment says it means to. The effect
    is that an album title can come from CD-Text while the faceplate reads
    `MusicBrainz` or `track numbers`. Defensible — the source label is about the
    *track list*, which is what you are looking at — but it does mean the label
    is not the whole truth. *Keep as-is?* I would. — **Resolved: kept, and what
    the label means is now written down. → D19.**

12. **The `READING · N%` counter includes files it skipped** (`player:1445`).
    Cosmetic and arguably correct: it is progress through the folder, not
    progress through the album. — **Resolved: kept as-is. → D10.**

13. **`resume_save` caps the file at 200 entries with `tail -200`**
    (`player:1588`). An undocumented history limit that behaves as a
    least-recently-*written* eviction. Almost certainly fine; worth being a
    deliberate number rather than an inherited one.

14. **No disc number is inferred from a directory name.** `Album/CD2/` with
    untagged files interleaves into disc 1 (§4.4). The script never claims
    otherwise, and inferring structure from folder names is exactly the kind of
    guess the metadata-not-filenames rule exists to forbid — but a two-disc rip
    with no disc tags is common enough to ask about. — **Resolved: still nothing
    from the name, but a zip's subdirectories are its discs. → D12.**

**Genuinely unclear what it is for:**

15. **`UNTAGGED`** is set (`player:1451`) and cleared (`player:1463`) and never
    read. It looks like the beginning of an "this album has no tags" notice on
    the panel that was never finished. Already in §15 as vestigial — but if the
    notice was the intention, it may be worth having. — **Resolved: finish it,
    as a count computed on demand rather than a flag. → D11.**

**Found afterwards, while writing §3:**

16. **`ALBUM="${SRC_LABEL%.zip}"` matches the suffix exactly** (`player:1497`)
    while §1.1 accepts a source ending `.ZIP`. A zip named in capitals therefore
    puts `KMRU - Kin.ZIP` across the top of the panel where every other album
    shows its name. — **Resolved: fixed. The suffix is stripped without regard to
    case.** The one argument for keeping it — that a `.zip` at the end of an
    album's actual title would be eaten — applies just as well to the lowercase
    form that has shipped for years. There is no album called this, the panel is
    the only consumer, and a capitalised extension across the top of it reads as
    the program failing to notice rather than as fidelity.

**Found afterwards, while writing §2 — and not in `player` at all:**

17. **D12 and the stray file at the top of a zip.** A zip holding one loose
    audio file at its root and the album proper in a subfolder has audio in two
    directories, so D12 fires: the stray takes disc 1 and the whole album takes
    disc 2. The rip is one disc and now claims to be two, and the stray plays
    first. This is not a `player` behaviour — the script has no such rule — it
    is a hole in D12, found by reading it back rather than by a test. *Guard by
    requiring every counted directory to be below the top level, or by ignoring
    a directory holding fewer than N files, or leave it?* — **Resolved: neither
    of those. The discs have to be siblings. → D12.**

    *Below the top level* fixes this archive by accident: it works only because
    the stray happens to sit at the root, and moving the whole thing down one
    level — `Rumours/stray.flac` beside `Rumours/Album/` — brings the bug
    straight back with both directories below the top level.

    *Fewer than N files* is right more often and wrong worse. It has no
    principle behind it, and it loses a real record: a two-disc set whose second
    disc is one forty-minute mix has that disc discarded, which drops the count
    to one, which switches the rule off and interleaves the set. A threshold
    that fails harder than the bug it fixes is a bad trade.

**Found afterwards, while writing §4 — and not in `player` at all:**

18. **Where the table of contents comes off the drive.** §4.3 said "`libdiscid`
    replaces the cdrecord TOC parse", and half of that has happened: the disc ID
    is computed here, in Swift, checked against `libdiscid` as an oracle (D15).
    The other half — *reading the TOC off the device* — is still `cdrecord -toc`,
    parsed the way the script parses it, because that is code that can be written
    and tested against a real listing with no drive in the machine, and
    `discid_read()` is not. Both routes exist and they answer the same question.

    `discid_read()` is one call, it is the reference implementation of the thing
    it is reading, and it removes a text-parsing step from the one input the
    fingerprint is computed from. Against that: it is a system-library target in
    `Package.swift`, so a fresh clone stops compiling until somebody has run
    `brew install libdiscid`, and it opens the device exclusively — which puts it
    squarely behind the `drutil`-first ordering §1.3 now carries (`burncd:278`).
    `cdrecord` is already a dependency of §4.2's CD-Text path, already spoken
    here, and needs nothing installed to *build*.

    *Ask libdiscid for the TOC, or keep the `cdrecord -toc` parse and keep
    libdiscid as a test-time oracle?* Left open deliberately: it is a question
    about the drive, and it should be answered with the drive plugged in, next to
    §1.3. Nothing in §4 changes either way — both produce a
    `TableOfContents`, and everything downstream of that is settled and tested.

**Found while writing §7 and §9:**

19. **Whose resume file is it. — ANSWERED: shared, and frozen.** → §7

    `ResumeFile.standard()` resolves to
    `${XDG_STATE_HOME:-$HOME/.local/state}/player/resume` — the script's path,
    the script's directory name, the script's format, byte for byte
    (`player:1538`). Two programs share one file, and the sharing goes both ways:
    stop a record halfway through in the terminal and MU/TH/UR offers to pick it
    up, and the reverse.

    **That cross-pickup is a feature, and it is now a requirement.** `player` is
    still used — over ssh, in pipes — and a record is a record whichever program
    you happened to be at when you stopped it. The rule that falls out of it and
    binds everything downstream: **MU/TH/UR never changes that file's format.**
    Four tab-separated fields, read and written exactly as bash reads and writes
    them, forever. Not a fifth field, not a header, not a rename of the
    directory. Anything MU/TH/UR wants to remember that bash has no field for
    goes somewhere else — §6.1a's volume is the first such thing and lives in the
    app's own defaults for exactly this reason.

20. **`RESUME AT 9999`. — ANSWERED: fixed, as D25.** → §7, §16

    The offer named a *track number*, and a row with no number in its tags fell
    back to 9999 — §3.1's sort sentinel (`player:2828`, `player:474`). The offer
    now counts the stored row instead and can never say 9999. **The file format
    does not change**: this is display text, computed from the row index that was
    already in field two. See D25.

21. **The autoscale, before it has heard enough to scale.** §9's percentiles are
    over the whole track in the script, which has decoded it before it draws a
    frame. Live, they are over the track *so far*: the same histogram, the same
    two percentiles, the same arithmetic, asked ten times a second of a growing
    pile instead of once of a finished one. The columns therefore settle over the
    opening bars rather than being right from the downbeat, and the 6 dB minimum
    span is what stops the first few readings from being magnified into a full
    column while they are the only readings there are.

    This is not a decision that could have been avoided — a live tap does not
    know the future — so it is listed as a consequence to be looked at rather
    than a question to answer in advance. *How long the settling actually takes
    is a thing to watch on a real record once §10 draws it*, and if it reads
    badly the answer is a warm-up window or a carried-over scale, both of which
    are changes to `BandScale` alone.

    **Left open deliberately, and correctly flagged rather than acted on.** It
    closes when it has been watched on a real record with the panel drawing it,
    and not before.

---

## 19. With a disc in the drive

Everything in §4 is written and tested. Some of it is tested against tables and
listings typed out by hand, which proves the arithmetic and proves nothing about
this drive, this machine's cdrtools, or a disc you actually own. This is that
list, and it is meant to be worked through top to bottom with the drive
connected. Nothing below assumes you have read the rest of this document.

**What you need.** The drive, and three discs if you can find them: an ordinary
album that is certainly in MusicBrainz, one that carries CD-Text (most do not —
that is a fact about the discs and not a fault), and one disc out of a multi-disc
set. For step 10, an external drive with a couple of AIFF files on it, plugged in
at the same time.

**One rule that governs the whole session, before anything else.** `cdrecord
-checkdrive`, `cdrecord -prcap` and any libdiscid device read **open the drive
exclusively**, and for as long as that lasts macOS lets go of the media —
`drutil` will then report `No Media Inserted` about a disc that has not moved,
and keep reporting it (`burncd:278`). So: **`drutil` first, always.** If it
starts denying there is a disc, eject and reinsert rather than believing it.

---

### 1. What `drutil` says

```bash
drutil status
```

- [ ] There is a `Type:` line and it names the media.
- [ ] **The same line carries `Name: /dev/diskN`.** This is the whole premise of
      D17 — the device node is how a `/Volumes` entry is confirmed to *be* the
      disc rather than merely to look like one. `burncd:322` says it is printed
      there; confirm it on this machine and write down the exact spacing, because
      the parse has not been written yet.

Proves: §1.3's first box, and D17's premise. Closes nothing on its own.

### 2. Which device node cdrtools answers on

```bash
for d in IODVDServices/0 IODVDServices/1 IOCompactDiscServices/0 IOCompactDiscServices/1 IOBDServices/0 IOBDServices/1; do echo "== $d"; cdrecord -checkdrive dev=$d 2>&1 | head -3; done
```

- [ ] Exactly one of them answers cleanly. Write it down — every command below
      wants it as `dev=…`.
- [ ] It is the same list `OpticalDrive.detect` walks, in the same order, so if
      one answers here `detect()` finds it. If none does, `detect()` falls back
      to `IODVDServices/0` and reports `answered: false`; `MUTHUR_DEV` overrides
      the lot.

Proves: `OpticalDrive.detect`, which the suite cannot touch at all. Run step 1
before this one — this is the command that makes `drutil` start lying.

### 3. The mount

```bash
mount | grep cddafs
ls /Volumes
```

- [ ] The disc appears as a `cddafs` mount, and the volume name survives the
      split on the **first** ` on ` and the **last** ` (` — a disc called
      `Live (Remastered)` is the case that rule exists for (§1.3).
- [ ] The listing is `N Audio Track.aiff` files, numbered from 1.

Proves: §1.3's primary detection, which is not written yet — this is the step
that tells you what to write it against.

### 4. The table of contents

```bash
cdrecord dev=<device> -toc > /tmp/muthur-toc.txt
```

- [ ] It contains `track:   1 lba: …` lines and one `track:lout lba: …` line.
      That is exactly what `CDRecordTOC.parse` reads. Anything else is the
      interesting outcome — keep the file.

### 5. What libdiscid makes of the same disc

```bash
cc Scripts/discid-oracle.c -I"$(brew --prefix libdiscid)/include" -L"$(brew --prefix libdiscid)/lib" -ldiscid -o /tmp/discid-oracle
/tmp/discid-oracle read
```

- [ ] It prints `id`, `toc` and a submission URL. Write the id down.

### 6. The two against each other — **the step this section exists for**

```bash
MUTHUR_TEST_TOC=/tmp/muthur-toc.txt MUTHUR_TEST_DISCID=<id from step 5> swift test --package-path MUTHURKit
```

Two tests in `§19 — with a disc in the drive` stop being skipped and run.

- [ ] `A real cdrecord listing reads as a table` — this drive's listing parses.
- [ ] `The fingerprint off a real disc is the one libdiscid gets` — our
      arithmetic over a table read by one tool equals the reference
      implementation reading the same disc for itself.

Proves: **D15 on real material**, and `CDRecordTOC` against a real listing rather
than a transcribed one. Until this passes, the disc ID is right about three
tables that were typed into a test file.

### 7. That MusicBrainz actually resolves it

```bash
curl -s -H 'User-Agent: MUTHUR/1.0 ( https://github.com/gvorbeck )' "https://musicbrainz.org/ws/2/discid/<id>?fmt=json&inc=recordings+artist-credits" | head -c 400
```

- [ ] A `releases` list comes back, and it is the album you are holding.

This is the one that has almost certainly never worked in `player` — D15 is the
reason, and this is where it stops being a claim about a hash. A disc genuinely
nobody has submitted answers with a 404 and that is a real answer too; try
another disc before concluding anything.

### 8. CD-Text

```bash
cdda2wav dev=<device> -J -v titles > /tmp/muthur-cdtext.txt 2>&1
grep -c title /tmp/muthur-cdtext.txt
```

- [ ] If that file has no `title` in it, this is the fallback the app takes and
      you should capture it instead:
      `cdrecord dev=<device> -toc -v > /tmp/muthur-cdtext.txt 2>&1`
- [ ] Whichever tool answered, note **which shape it printed** —
      `Track  1 title: 'X' from 'Y'` or `Track  1 title: 'X'`. Both are handled;
      what is unproven is which one this machine produces.

```bash
MUTHUR_TEST_CDTEXT=/tmp/muthur-cdtext.txt swift test --package-path MUTHURKit
```

- [ ] `Every title line this disc printed produced a title` — every line the tool
      printed came out as a title. The failure this is looking for is silent by
      design: a shape the parser does not know leaves the tidy `Track 07` in
      place, so a disc whose CD-Text is printed some other way is
      indistinguishable from a disc with none.
- [ ] Best case, one of the titles has an apostrophe in it. That is the case the
      quote rule exists for — `Don't Stop Me Now` cut down to `Don` is the bug —
      and it is tested against both printed shapes already, but never against a
      disc.

Proves: §4.2's first box, `DriveCDText`'s invocation and its fallback condition.

### 9. The mounted volume, end to end

```bash
MUTHUR_TEST_CDDA="/Volumes/Audio CD" swift test --package-path MUTHURKit
```

- [ ] `A mounted CDDA volume numbers its own tracks` — the numbers come off the
      filenames macOS wrote, and none of them is 9999. Without this every title
      §4 learns lands on the wrong row, which is why the rescue exists (§3).
- [ ] `§4.1 leaves a tidy list on a disc nothing can name` — `1 Audio Track.aiff`
      becomes `Track 01`, and the album falls back to the volume name.

Proves: §3's CD-only rescue and §4.1 against filenames this program did not
invent.

### 10. Two volumes at once — D17

With a disc in the drive **and** an external volume holding two or more AIFFs
mounted:

- [ ] `drutil status` names the disc's device node, and it is not the external
      volume's.
- [ ] Confirm the external volume is the kind of thing that would win under the
      script's rule (`player:1009`): a `/Volumes` entry with two AIFFs in it.

Proves D17 is worth doing. Nothing implements it yet — §1.3 is unwritten by your
call, and this is the material it needs.

### 11. A disc out of a set — D16 and §4.4

- [ ] Its disc ID resolves (step 7) to a release, and the track list that comes
      back is **that disc's**, not disc one's.
- [ ] If the answer carries more than one release, the album name and the release
      MBID come from the same entry the track list did. That is D16; on a
      single-release answer nothing distinguishes it from the script.

### 12. Nothing in the drive, and a data disc

- [ ] With the drive empty: `drutil status` says so, and nothing is offered.
- [ ] With a data CD or a DVD in it: no `cddafs` mount, no `Audio Track` in the
      listing, and it simply is not offered. There is no "this is a data disc"
      message and there should not be one — from here it is a mounted volume like
      any other (§1.3).

---

### What is still unproven after all of this

- **§1.3 in full.** Disc detection is not written. Steps 1, 3, 10 and 12 are what
  it gets written against.
- **§18.18** — whether libdiscid reads the TOC in the shipping app or the
  `cdrecord -toc` parse stays. Step 5 is one half of that comparison and step 4
  is the other; answer it here rather than from a description.
- **Anything above the domain layer.** There is no app, no picker and no panel,
  so "the panel says which source you got" is a value on a struct and not
  something you can look at.
