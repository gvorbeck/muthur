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
  the reasoning and the decision it came from. All forty-eight are settled; §16
  lists them together so a difference from `player` is never later mistaken for
  a porting mistake. *(This number had drifted to thirty-nine while §16 said
  forty-six — two numbers for one set, which is the drift this document keeps
  warning about. Re-derived here by counting §16, and it is §16 that is
  authoritative.)*

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

**284 of 289 boxes** outside §19 (§19 is a procedure, not boxes, and is not
counted; it stands separately at 10 of 33). Re-derived by counting the file:
284 ticked and 5 open above §19, 10 and 23 below it.

**Nothing was ticked or added this time — a row was caught lying.** `optical
drive` still said `media: <type> — the disc source is not built yet, so it cannot
be played` after §1.3 built it, and it went on saying so because that sentence is
unreachable on a machine with an empty bay. It is now the script's
own `ok` (`player:396`) with where the disc is mounted, and a warning kept for
media §1.3 will not open — four outcomes where bash has three, because the media
*type* cannot tell the two apart: a real audio CD reports `Type: CD-ROM` (§19
step 1), the same word a data disc gives, so the row asks `DiscFinder` instead,
which opens nothing either. §11.1a carries the reasoning and the suite now pins
both media outcomes. **The row still cannot fail**, so `scratch space` remains
the only one that can and nothing about the exit code moved; the denominator did
not move because a message that was wrong is not a new requirement. **§19 grew
31 → 33**, one box in step 12 and one in step 13, both of them "read this row
with a disc in the drive" — which is the only thing that would have caught it,
and §19 is uncounted, so the figure below the line moves and the figure above it
does not.

**Before that, the denominator moved twice, and that is the whole of what is left
to explain about this figure.** 287 → 289, both of them requirements this document did not
previously have and neither of them a box that got split or reworded. **The first
is D47**: an archive is offered only if it holds audio, which is `player:1039`'s
folder rule applied to the one kind of row the script could not apply it to.
`scan_sources` lists every `*.zip` unfiltered because bash cannot see inside one
without unpacking it (`player:1035`), so on this machine the picker's top rows
were three RPG rulebooks out of `~/Downloads`. §2.2 already reads a central
directory where the archive lies, so the port can ask the question for two
`pread`s and no bytes of entry data; six archives in `~/Downloads` become two.
Audio is `AudioFiles.extensions` and nothing else — the same twelve the folder
rows count with, D7's lesson pointed the other way — and dotted paths are out,
because `AudioFiles.scan` skips hidden files and an archive whose only `.flac` is
a `__MACOSX/._Song.flac` stub would open as an empty record. One second,
wall-clock, shared across a directory's archives and probed together rather than
in turn; a `pread` into a sleeping disk cannot be cancelled, so what the deadline
buys is the right to stop waiting. **The second is `BROWSE`**, §14's new cap:
`NSOpenPanel` on `B`, between `RESCAN` and `QUIT`, opening its selection through
the same `SourceOpener.resolve` a picked row goes through. The scan is untouched
and still the default — `BROWSE` is the escape hatch for the album outside
`MUTHUR_DIRS`, the one two folders deep, and now the archive D47 declined to
offer. It is `PanelModel.browse()`, which is also what ⌘O calls, so the menu item
and the cap are one chooser rather than two kept in agreement.

**Seven boxes ticked, and six of them were waiting on being looked at rather than
on being written.** **D8's four** closed on the diagnostics screen existing: the
conceit turned out to want *less* room than was reserved for it — `Report.verdict`
is the only first-person line in the program, the twelve rows above it report
plainly in the script's own register, and nothing anywhere prompts or waits.
**§5.4's `§18.24`** closed as **D48**: the letterboxing stays, and it is recorded
as a divergence rather than an override because `scale=$w:$((h*2))`
(`player:2974`) carries no aspect term and every number around it is the terminal
cell's 2:1 shape being undone. The script was written as if every cover were
square; a case it never met is not a decision being overruled. That leaves §18 at
twenty-three of twenty-eight answered, and **five open boxes in the whole
document** — `cdda2wav`'s CD-Text capture, and §14's four, three of which are
blocked on hardware and material rather than on work.

**Three corrections carried in from the last report, all three verified before
anything was written.** The check screen has **twelve** rows on this machine, not
fourteen; the stale count is gone from `Faceplate.checkMeta`'s examples and from
§10's faceplate note. **`SELF TEST · N CHECKS` never reaching `--check` is
intended**: `--check` prints `Report.plainText`, which is `ck`'s terminal layout
(`panel.sh:583`, `panel.sh:588`), and the script's `run_check` prints with no
panel up — there is no plate to write on, and inventing one over a terminal
report would be chrome the original never had. `checkMeta` is the screen
version's plate and is reached only from `PanelModel.faceplateMeta`. Said outright
in §11.1a so the question is not asked a third time. And `player:2330` is
`player:2329` — the `printf … SOURCE … fit "$SRC_LABEL" 52` line; 2330 is the
comment under it. Fixed here and in the three source files that cited it.

**Before that, the denominator did not move, and §10 closed.** Its last two boxes were one
box wearing two hats: the loading stage is the fifth screen this panel has, and
"the faceplate on every stage" could not be shown true until there were enough
stages for *every* to mean something. Porting it found a divergence and reversed
it — the port had grown a fourth stage word, `UNPACKING`, which the script does
not have: `open_source` says `OPENING` before the archive is touched
(`player:1398`) and the unpack counts up under that same word (`player:1290`,
`player:1360`). Three words, and the percentage says how far in it is. The
opener's progress callback used to hand over a formatted string, which spent the
two numbers `load_stage` puts the bar's head at and threw them away; it now
hands over a `LoadingStage` — what the script hands `load_stage` — and the screen
does the wording. Two oddities are kept and flagged rather than tidied: the
second label always reads `READING` whatever the plate says (`player:1170`), and
`SOURCE` is printed whole here where `np_frame` fits it to 52 (`player:1169`
against `player:2329`), so a very long archive name overruns this line and no
other.

**The denominator did not move for §12, either.** §12 ticked five — the last two §1.1
flags, `-n` and `--help`, and all three of §12 — and added none. **`-n` is the
first flag whose whole subject is printing**, so it lands in `App/main.swift`
beside `--check` rather than in the panel — but not before the read:
`player:3540` sits after `open_source`, so a dry run does every expensive thing
a real run does except put a needle down. Four things about its layout look wrong and are
kept, listed at §12. With no source argument it takes the first one scanned,
where the script would draw a picker — `player:1118` is the script's own rule
for a run with no screen, and `player -n | cat` has always behaved that way.
One box needed wiring rather than inheriting: the script has a single `YEAR`
that the panel and `-n` both print, where this port has three sources and a
precedence, so both now call `HeaderBlock.year` and `Inspect` consults the
catalogue the way `PanelModel` does.

**`--help` is the only thing in this port that is a straight loss, and it is
D46.** `usage` prints the script's own header by reading `$0` (`panel.sh:270`),
so the help and the header are not two things that agree — they are one thing.
A compiled binary has no `$0`, so the text is a literal in `Usage.swift` and a
literal can drift. What stands in for the mechanism is `UsageTests`, which
reads `Sources` back off disk and checks both directions: no switch and no
environment variable undocumented, and nothing documented that has since been
removed. Weaker than the shell's guarantee, and written down as weaker.

**No new box for the unknown-option refusal, and that is on purpose.**
`MUTHUR --rip` used to open a window and sit there because `main.swift` parsed
through a `try?`; it now prints `unknown option: --rip (try --help)` on stderr
and exits 1, which is `player:336` word for word. **It is counted under §1.1's
`-h` / `--help` box**, not given one of its own: the script's refusal is an
instruction to run `--help`, so a `--help` that cannot be reached by getting
something wrong is half a flag. See §1.1's prose for the detail.

**The denominator did not move the time before, either, and that is the point of
recording it.** §1.3 ticked thirteen boxes — one in §1.1 (`--cd`), two in §1.2 (the
disc row, D18's count), all seven of §1.3, and the last three of §17 — and added
none, because everything it implements was already written down as a requirement.
§19 grew 28 → 31 for step 13, and §19 is uncounted, so the figure below the line
moves and the figure above it does not. That is the shape a section landing
cleanly should have. `--no-mb` landed after it and ticks the fourteenth, again
adding nothing: the requirement was already written, and what was missing was
the wire from the flag to the opener.

**The rule, restated so it keeps working.** The denominator has moved three
times. 286 → 287, when D44 added §4.3's `.TOC.plist` reader — a requirement this
document did not previously have, discovered by putting a disc in the drive. Then
287 → 289, for D47's archive rule and §14's `BROWSE`, both found the same way:
by opening the picker on this machine and reading what was in it. **A new
requirement is the only thing that may move it**, and all three were. If it moves
again and no box was added for a behaviour newly discovered to be required, that
is drift — a
miscount, a box that got split, a box quietly reworded into two — and it should
be found and reversed rather than absorbed. Both figures here were re-derived by
counting the file, not carried forward from the last edit.

§5,
§5.1, §5.2 and §5.3 are done whole — nineteen boxes, none held back — and D14
takes one of §17's with them, the only durable consequence an outage used to
have. §4, §4.1, §4.3 and §4.4 are done bar one box, and §4.2 bar one: both of
those are the same box in different clothes — the command that runs a tool
against a drive there is no drive for. §2, §2.1 and §2.2 are done bar two: both of
those need the source layer. §3 and
§3.1 are done whole, the CD-only filename rescue included. **§6 and all six of
its subsections are now done whole** — §10 closed the eleven boxes that were
waiting on a panel to exist: the cursor against the playhead, browsing, the key
bindings themselves, the wheel, the mouse buttons, the status line's `u`, and
the four that §6.1a's volume needed a faceplate for. It takes four of §17's with
it: the two degraded paths for an album that vanishes while it is playing, and
the two about a folder of mixed formats, which is the same requirement §6 opens
with and the album it would be audible on.

**§10 is now done whole** — the loading stage and the faceplate, described
above. Two of the four boxes that were open here were §8's and §8 closed them:
`SHELF`/`NOTE` are drawn, and the year now has all three of its sources.

**§8 is the new one, and it is done whole** — thirteen boxes, the file picker and
D5's bookmark included. `Shelf/` is three files: a CSV walk, the catalogue and
the lookup, and the one place that opens a file. It reads
`~/Sites/cd-collection/data/collection.csv` and **nothing anywhere in it writes,
creates or moves anything under that repository** — there is exactly one
filesystem call in the section and it is a read. The panel change is one
argument: `HeaderBlock` had carried the `Shelf` seam since §10, `HeaderView`
already drew an annotated row in amber, and `PanelView` already budgeted the
track list against the header's own height — so `COLL_ROWS` (`player:2443`) and
the mouse row offset (`player:3221`) both arrive without a line of arithmetic.
Two decisions came out of it, **D34** (a duplicate row: the last one still wins,
which closes §18.3) and **D35** (the file is walked as one stream, which is what
made a CRLF catalogue readable at all), and one question, **§18.26** — D6 and the
script disagreed about whether tags or MusicBrainz wins the year — which is now
answered by following the script, with D6 amended in place rather than written
twice. Nothing observes the swap until §1.3; it was settled early so §1.3 does
not have to stop and ask.

**§7 and §9 are the new ones, and both are done whole** — twenty boxes, and
§6.2's resume entry with them, which had been waiting for §7 to have one to
clear. Neither needed a line changed in `Play/`: §7 watches the deck's published
state and never speaks to it (D24), and §9 taps whatever node it is handed, which
is a question §10 answers. §9 is the numbers only — the bands, the levels, the
scales and the column state, all of it measured in `swift test` with no window
open. Nothing is drawn.

**§11 is the newest, and it is done whole** — seven boxes, and `--check` out of
§1.1 and MusicBrainz out of §17 with them, nine in all. It is the right thing to
have written now precisely because §1 and §8 exist for it to report on: eight of
its twelve rows would have had nothing to say a week ago. `Diagnostics.run()`
returns the twelve rows and derives the verdict; `Report.plainText` lays them out
the way `ck` does (`panel.sh:587`) and `App/main.swift` answers the flag before
`NSApplication` starts, so `--check` prints and exits the way `player:531` does
rather than opening a window first. `CheckView` draws the same report on the
panel, reachable from the menu. **D8's boundary holds on both**: the MU/TH/UR
voice is the verdict line and nothing above it, which is a test and not a
convention. Three decisions came out of it — **D37** (`drutil`'s `Type:` line is
read `burncd`'s way, not `player:396`'s), **D38** (the three marks climb the
panel's own amber instead of the terminal's three hues, and the detail turns over
rather than being cut), and **D39** (the check does not go to the network, which
declines the improvement §17 asked for) — and no new questions. Every other entry
in this document should be read as outstanding.

**§17 stopped at a seam rather than finishing, and §1.3 closed it.** Fifteen of
its eighteen boxes were closed and three were not, and those three were three
halves of §1.3 rather than three failures — `find_cd` returning nothing
(`player:965`), the picker having no disc row (`player:1018`), and media that is
present but never mounts (`player:1000`). The `--check` halves already existed
and were tested; a box with one half standing is still an open box, so they
stayed open. **All eighteen are closed now.** Note what did *not* change to close
them: nothing in §17 or §1.3 goes near the drive. Detection reads the mount table
and `drutil status`, which are answers about the drive and not conversations with
it, so the whole section is still reachable with stubs.

The section is mostly assertions that a message does *not* exist, which is not
something a feature test ever accidentally covers: the panel has no vocabulary
for an outage, no row can say "pattern", and nothing about the drive can change
`--check`'s exit code or the first four words of its verdict. One real hole
turned up and is closed — **D40**: bash asked after `ffmpeg` on its `analyser`
row (`player:367`), §9 made that row a live tap rather than a shell-out, and the
question
went with it, leaving `--check` reporting `ok` on a machine that could not play
an Opus. It now lives on `playback`, asks after both `ffmpeg` and `ffprobe`, and
names whichever is missing. Two questions came out of it. **§18.27** is already
closed: D11's untitled-track notice is **deliberately not drawn**, and D11 is
amended in place to say so — the script has no such notice, drawing one would
need three invented numbers, and it contradicts the "no placeholder" box §17 has
just ticked. The counting half stays and earns its keep feeding the sort.
**§18.28** was left open by that section and is now closed as **D43** — it turned
out not to need a disc after all.

**A third thing came out of the test run rather than the section, and is D41.**
§17's own report showed two of §6's real-material seam tests had stopped running
on 24 August and said nothing about it, and four §3.1 assertions going red and
then green again inside one afternoon as albums moved through the zip directory.
One cause both times: a fixture taken **by position** out of a directory that
changes, while the material it wanted was on the machine the whole time. Fixtures
now hunt by criterion, a cached cut is checked for bytes rather than existence,
and a hunt that comes back empty **with audio present** is a failure that names
what it wanted. Skipping for genuine absence is untouched and stays everywhere it
already was — no `Rumours`, no catalogue, no music library, no ffmpeg, no disc.

Two corrections: the mixed-format box said thirteen extensions and there are
twelve (`player:1046–1048`), and the untagged-sleeve box read as though the
script declined to ask MusicBrainz without an artist. It asks (`player:1825`);
it is the quoted phrase that misses.

**Where a fresh session picks up.** Two things are ahead and neither blocks the
other. **The UI** — gate 4's second half — is what §6's eleven open
boxes are waiting for, along with the whole of §10; the deck underneath them is
written and measured, the analyser behind them is measured too, and what they are
missing is somebody to press their keys and a surface to draw on. **§1, the
source layer**, now opens folders and zips and hands the result to §3 —
`SourceOpener`, `SourceScanner` and the picker are landed, `OpenRecord.swift` is
deleted, and everything that was waiting on the source layer to carry
`SourceKind` and `TitleSource` is unblocked. The two §2.2 boxes (zip provenance
reaching `Record.read`, D12 switched on for real zips) are ticked. `TitleSource`
is stamped `.tags` on every folder and zip by `SourceOpener.open`. What remained
of §1 was **§1.3** (disc detection) and four of the five §1.1 flags; `--check`
was ticked with §11.

**§1.3 is written.** `DiscFinder` ports `find_cd` behind a probes seam like
§11's — `mount`, `drutil status`, the `/Volumes` glob, a listing, `[ -d ]` and
`command -v drutil` are six closures — so every branch is reachable with an empty
drive, and thirty-four tests take them; `LaunchOptions` gets ten of its own. It
parses the flag set, and `--cd` is ticked out of §1.1 with it; the picker's disc
row and D18's count land with §1.2; §17's last three boxes close. **What it does not have is a disc**: the
one D44 was learned on was ejected before any of this was written, so the
disc-present half rests on output transcribed off that disc and replayed through
the seam, and §19 step 13 is the three assertions that will settle it the next
time one goes in. The split between what ran on hardware and what ran on stubs is
written into §1.3's boxes one at a time rather than summarised, because they are
different kinds of confidence and a summary blurs them.

**§1.1 is now done whole.** The last two flags were open on the same grounds —
**the parse is not the flag**: `--dry-run` and `--help` were recognised so they
would not be mistaken for a path, and nothing consumed them. Both are consumed
now, in `App/main.swift` and before `NSApplication` starts. `--no-mb` was the
third of these and was threaded first — one merge of flag and environment,
asked by §11's row and §4's disc path alike.

Closing them exposed a fourth thing the parse was doing and the flag was not.
`main.swift` read the arguments through a `try?`, so an argument the parse
rejected fell through to the panel and `MUTHUR --rip` opened a window and sat
there, where `player:336` is
`-*) die "unknown option: $1 (try --help)" ;;`. The `try?` is gone; an unknown
switch now prints exactly that on stderr and exits 1, and a bad source path
prints its own refusal the same way. **This lands under §1.1's `--help` box** —
it is that flag's other half, because the message the script prints is an
instruction to run it.

**§18.4** came due while §5 was being written and is answered — **D14**: the
`.none` marker is written only when something at the far end actually replied.
**§18.1, §18.6, §18.7 and §18.11** came due together before §4 was written and
are answered as **D16–D19**; §18.6 and §18.7 land in §1, which is still ahead.
**§18.18** was left open for the drive, closed as **D42** — the `cdrecord -toc`
parse stays, libdiscid stays the oracle — and then **reversed as D44 by the first
disc that was ever put in the drive**. D42 was taken on the belief that both
routes work and only their cost differs; on macOS neither works, because
`diskarbitrationd` holds a mounted audio CD and cdrtools demands an exclusive
open. The table now comes off `.TOC.plist` on the mount, which costs less than
D42 did and is the one route that can read a disc macOS has mounted. **§18.19,
§18.20 and §18.21** are newer still and come out of §7 and §9: whether the resume
file is shared with the bash script or owned outright, what the offer says for a
row with no track number, and how long a live autoscale takes to settle. The
first two want an answer before §10 draws anything that depends on them; the
third was a thing to watch on a real record rather than a question, and **it has
now been watched, measured and answered** — the cold scale read high by three and
a half rows over the opening of a track that fades in, which was worse than
§18.21 assumed and was a direction rather than a delay. **D33** answers it in three
passes: the prior's shape, then its location, then its weight swept against
the script's own opening.
**§18.22 and §18.23** came out of §10 and are both answered as fast as they were
found — the missing fourth line in `np_scroll` goes in (**D31**), and the two
places the port measures a character wider than `cwidth` does stay as they are
(**D32**). **§18.24** is open: the script scales a cover to the sleeve box
exactly and stretches a cover that is not square; the port keeps the aspect
instead. **§18.25** was newest and is now closed unguarded — D30 made `QUIT` a
switch, and §7 is why that is safe. **§18.3** came due with §8 and is closed as
**D34** — two rows for the same record, and the last one still wins. **§18.26**
was new with §8 and is already closed: D6 had the tag year beating MusicBrainz
and the script (`player:2215`) has MusicBrainz overwriting the tag year, so D6
was amended in place to the script's order. It is unobservable until §1.3 lets a
tagged record be looked up on a disc, and that is precisely why it was worth
settling before §1.3 arrives. **§18.27 and §18.28** are the newest, both out of
§17. §18.27 is **closed the same turn it was raised** — D11's notice is not
built, deliberately, and D11 is amended in place rather than joined by a second
decision. **§18.28** is closed too, as **D43** — the port *may* narrow
`cd_text`'s fallback test, and does, by asking `CDTextParser` whether the capture
holds any CD-Text rather than asking the string whether it says `title`. The
divergence is one shape of input and it is the fault: a capture that mentions
titles in something that is not a CD-Text line. Everywhere the script's grep was
right the two agree, and there are tests on all four shapes.

**Six open items remain in §18** — 5, 8, 9, 10, 13 and 24. Neither of the two
that closed that turn needed a disc in the end, which was worth noticing: both
had been filed as drive questions and neither was. D42 and D43 each kept a
condition a real disc still had to meet — §19 steps 4 and 5 for the first, step 8
for the second — held as confirmations of a decision taken rather than the
decision.

**Then a disc went in, and D42's condition was the one that fired.** It is worth
being exact about what that cost and what it did not. D43 is untouched: it was
reasoned from the shape of a capture, and a real cdda2wav failure has since
confirmed the reasoning without exercising the divergence (both greps return 0 on
it, so §18.28's fault does not trigger on that particular failure). D15 is
confirmed on real material — §4.3's arithmetic reproduces libdiscid's ID for the
disc in the drive, exactly. D17's premise is confirmed on real hardware:
`drutil status` really does print `Type: CD-ROM               Name: /dev/disk10`.
What did not survive was the one decision taken on a cost comparison between two
options that were never compared against a disc. **The lesson §19 exists to
teach, taught by §19 on its first run.**

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
- **§10 — the panel, first pass.** `App/Panel/`. `PanelModel` is the other half
  of the script's `while read_key` loop: what is on screen, what a key does to
  it, and a twenty-a-second tick that sleeps between frames rather than queueing
  them — `player:2643`'s lesson, that a window behind another window drains
  slowly and queued ticks replay as visible catch-up lag. `Grid` is what makes
  the character grid literally true rather than nearly true: every measurement is
  a column count out of `MUTHURKit/Panel` times one measured cell, so the 52
  columns `TrackColumns` gives the titles are 52 columns on screen. The blocks
  are `FaceplateView`, `HeaderView`, `TrackListView`, `MeterView`, `AnalyserView`
  and `KeycapsView`, and they are monospaced `Text` runs everywhere the script
  printed text and `Canvas` for the two meters and the analyser — drawn rather
  than typed, so a band boundary lands where it falls instead of on the nearest
  of eight glyphs.

  **The amber, the glyphs and the type are not this pass.** Everything about how
  it looks is in `Theme` and nowhere else, so tuning any of it is one file.
- **§8 — the shelf.** `MUTHURKit/Sources/MUTHURKit/Shelf/`. `CSV` is the walk —
  quoted fields, doubled quotes, and the whole file as one stream rather than a
  line at a time (**D35**); `Catalogue` is the header read by name, the
  normalisation, and the lookup with its artist gate and its exactly-one rule;
  `CatalogueFile` is where the file lives (**D5**) and is the only thing in the
  section that touches a disk. **That one call is a read.** `cd-collection` is
  not ours to write to, and nothing here writes to it, creates anything in it or
  assumes its layout will change. The panel side is one argument on
  `HeaderBlock(record:shelf:)` and a `Collection…` menu item that leaves a
  security-scoped bookmark behind — there is no Settings screen for it to live in
  until §11 and §13, and what matters about it is the bookmark rather than where
  the control is drawn.
- **531 tests in 40 suites**, `swift test --package-path MUTHURKit`. Two tiers,
  and the distinction is the whole value of the number: the **rules** tier runs
  anywhere, and the **material** tier reads files already on the machine and
  skips itself when they are absent. On the machine this was last run,
  **five skipped and every other material test ran** — the five are §4's, and
  they need a disc in the drive, which is what §19 is for. The others gate on
  `ffmpeg` (the cross-decoder seam and §9's three against the script's own filter
  chain), on a record with continuous audio across a track boundary, on a music
  library, and on §8's catalogue being beside this repository. Each is
  overridable by environment variable — `MUTHUR_TEST_MUSIC`, `MUTHUR_TEST_ZIPS`,
  `MUTHUR_TEST_TOC`, `MUTHUR_TEST_COLLECTION` — and nothing in either tier copies
  material into the tree.
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
  `Analyser/` §9, `Shelf/` §8. Every one of them now has the above in it —
  `Shelf/` was the last empty frame and §8 filled it — with the one gap being
  that `Disc/` holds §4 but not §1.3. It is a package
  and not a folder inside the app target so that these suites run without
  standing up an app, and so that nothing in here can import SwiftUI by
  accident — the moment it can, parity stops being testable in isolation. §6
  earns that arrangement twice over: an audio engine that can only be tested by
  listening to it is an audio engine nobody tests.
- `MUTHUR.xcodeproj` and `App/` — the app target. Ad-hoc signed, links
  `MUTHURKit`, and now draws §10's panel in its one window.

  `App/OpenRecord.swift` is deleted — §1's source layer has landed. The app
  now opens sources through `SourceOpener` (folders and zips), shows the picker
  via `SourceScanner` when launched with no argument, and takes a path as
  `argv[1]` in `MUTHURApp.swift`. §1.3 (disc) is stubbed at the boundary.

  *Corrected while writing §8: this said the app handles `MUTHUR_RECORD` and
  Cmd-O, and it handled neither. `MUTHUR_RECORD` does not exist and is not
  coming back — a path as `argv[1]` is what the script takes. The **⌘O was
  worse: promised on the faceplate (`NO RECORD ON THE DECK — ⌘O`) and bound to
  nothing**, a lie on screen that this port introduced when the source layer
  landed. Now fixed: `File ▸ Open Record…` is bound to ⌘O in `MUTHURApp.swift`
  and opens a folder or a zip through `SourceOpener.resolve`, with a refusal
  going to `model.die` in the panel's own voice, as `player:3524` prints it.*

  *Binding it was the right half of that choice rather than rewording the line,
  because **the script has no empty-panel state to compare against**:
  `pick_source` dies where it stands with nothing to scan (`player:1114`), exits
  0 if the user walks away from it (`player:3532`), and `open_source` runs
  before the first frame (`player:3535`). A terminal program may say one line
  and stop; a window may not. `EmptyPanelView` is therefore a **port invention**,
  now labelled as one in its own comment, and a state this port invented is a
  state this port owes a way out of.*
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
§16 D8 was a constraint on the UI until the UI arrived; the diagnostics screen it
was waiting for exists, has been looked at, and closed all four of its boxes.

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

- [x] No argument → the source picker (`player:3531`).
- [x] A directory argument → play that folder (`player:3519`).
- [x] A `.zip`/`.ZIP` argument → unpack and play (`player:3523`).
- [x] Anything else that exists → `not a zip or a folder` (`player:3524`).
- [x] A path that does not exist → `no such file or directory` (`player:3518`).
- [x] Exactly one source argument; a second is an error (`player:337`).
- [x] `--cd` → the disc, or die `no audio CD in the drive` (`player:3527`).
      **A path beats it**, both orders, which is `player:3517`'s own precedence:
      naming a record and asking for the disc in the same breath is not an error
      and the record wins. `LaunchOptions` parses the whole flag set rather than
      just this one, so `-*` dies as an unknown option instead of being opened as
      a file — the failure mode of guessing is opening something nobody asked
      for.
- [x] `-n` / `--dry-run` → read it, print the album, play nothing
      (`player:331`, `player:3540`). Answered in `App/main.swift` alongside
      `--check`, and for the same reason: it prints and *ends*. §12 has the
      layout and the four oddities kept in it.
      **With no source argument it takes the first one it finds**, where the
      script would run the picker (`player:3531`). The picker here is a window
      and a window cannot hand its answer back to a pipe — but the script
      already has a rule for a run that cannot draw one, one line into
      `pick_source`: `[ "$SCREEN" -eq 1 ] || { PICKED=${SRC[0]}; return 0; }`
      (`player:1118`). `player -n | cat` has always behaved this way.
      **`--check` beats it**, which is the script's own order — `CHECK` is
      tested at `player:531` and `DRY_RUN` at `player:3540`.
- [x] `--check` → diagnostics, exit non-zero on hard failure (`player:332`,
      `player:531`). **Answered before `NSApplication` starts**, in `App/main.swift`
      rather than by `@main` on `MUTHURApp`: the flag's whole value is that it
      prints, sets a code and *ends*, and an answer that arrives after a Dock
      icon has bounced and a window has opened is not that flag. Printed in
      `ck`'s own layout without the colour (`Report.plainText`, `panel.sh:588`).
- [x] `--no-mb` → never ask MusicBrainz (`player:334`, `player:81`).
      **Two names for one state, merged once.** The script has the same pair —
      `USE_MB="${PLAYER_MB:-1}"` and `--no-mb) USE_MB=0` — and merges them into
      one variable before anything reads it, which is why `run_check`
      (`player:410`) and the lookup (`player:1839`) can never disagree.
      `SourceOpener.musicBrainzSwitch` is that merge: §11's row and §4's disc
      path both ask it, and neither reads the environment on its own any more.
      Either switch alone is enough and nothing switches it back on, which is
      what `[ "$USE_MB" = 1 ]` says. `MUTHUR_NO_MB` is inverted from
      `PLAYER_MB` and reads like every other `NO_` variable: unset, `0` and
      empty are on.
      The flag rides on `SourceOpener.open` rather than on `openDisc`, and is
      latched on `PanelModel` at launch — a disc put in later and opened off the
      picker (`r`, §1.2) is still this session's disc, and a flag that only
      worked when the disc was named on the command line would be a flag that
      quietly stopped working. `--check --no-mb` warns without a variable set,
      which is the one thing that could not be reached before.
      **One divergence in the wording**: `player:411` names `--no-mb` whichever
      switch did it, because the script had one message to write. The port has
      two names in play, so the row names the one that is actually set — naming
      the wrong one sends the reader to the wrong switch.
- [x] `-h` / `--help` → the header comment, reprinted (`panel.sh:269`).
      **It stops the parse where it stands.** The script's arm is
      `-h|--help) usage 0 ;;` and `usage` *exits* (`panel.sh:271`) from inside
      the loop, so nothing to the right of it was ever looked at:
      `--help --rip` prints the help and leaves 0, `--rip --help` dies on
      `--rip`. `LaunchOptions.parse` returns on the flag rather than collecting
      everything and picking a winner afterwards.
      **What does not survive is the mechanism, and it was the good part.**
      `usage` runs `awk` over `$0`, so the help and the file's own header are
      the same forty-nine lines (`player:3`–`player:51`) and cannot drift. A
      compiled binary has no `$0` to read, so the text is a literal in
      `Usage.swift` — the only copy in the repository, with the suite reading
      `Sources` back off disk to check that no switch and no environment
      variable was added without a line about it, and that nothing named there
      has since been removed. Weaker than the shell's guarantee, and the
      strongest one available.
      Two small departures, both **mine**: the examples are written in the name
      it was invoked under rather than a hard-coded `player`, since `usage` was
      already reading `$0` for the text; and the page describes this port, so
      it says AVFoundation where the script says ffmpeg and documents no art
      switch, there being no `MUTHUR_ART` to document (`player:49`).

### 1.2 The picker

- [x] Scans `PLAYER_DIRS` (default `~/Music:~/Downloads`), colon-separated
      (`player:1023`).
- [x] `find -maxdepth 1`: loose zips, and immediate subdirectories that contain
      audio. The *scan* stays one level deep — the picker offers albums, not
      every folder on the disk (`player:1031`).
- [x] The disc, when there is one, is listed **first** — if there is a disc in
      the drive it is almost certainly what you came to play (`player:1018`).
      Above every scanned directory, not merely above the first one, because
      `scan_sources` appends it before it walks the search path at all.
- [x] Per-row detail column: `N tracks · in the drive`, `<du -h> · zip`,
      `N tracks · folder`. **Corrected while §1.3 was being read into.** This box
      was ticked with `PickerEntry.discDetail` returning `N tracks · disc`, and
      nothing noticed because nothing calls it until the disc row exists — the
      other two strings are drawn and tested, the third was written ahead of its
      caller and never read back against `player:1019`. The script says
      `in the drive`, and the difference is not cosmetic: the other two rows name
      the *kind of thing* and this one names *where it is*, because there is only
      ever one drive and what is in it is the fact you are choosing on. Same
      shape of fault as D41 and found the same way, by going back to the source
      rather than to the code.
- [x] **Changed from bash (D18).** The disc's count is the same count every other
      row uses, not `ls | grep -ic '\.aiff\?'` (`player:1019`). A CDDA mount is
      AIFF today and the grep is right today; it is right by coincidence, and the
      row it is wrong in is the one offering you the disc — `0 tracks · in the
      drive` beside a disc that plays perfectly reads as a broken drive. One
      counter for all three source kinds, which is also the shape D7 gave the
      other two.

      **D18 does not widen the AIFF grep in §1.3, and that is not an
      inconsistency.** The grep survives, unchanged, where `find_cd` uses it to
      decide *whether a volume is a disc at all* — widening that would make any
      shelf of mp3s answer to "is there a CD in the drive". D18 is about the
      other question, *how many tracks this disc has*, and there the wide count
      is right. Two counts, two questions; the mistake would be assuming one
      definition because they are spelled the same way in bash.
- [x] Row marks: `⊙` disc, `▤` zip, `▸` folder (`player:1073`).
- [x] Zips sorted `LC_ALL=C`, folders likewise, per scanned directory.
- [x] A folder is offered only if it contains audio (`player:1039`).
- [x] **Changed from bash (D47). An archive is offered only if it contains audio
      too.** A new box, and it moves the denominator (see Status) on the D44
      precedent: a requirement this document did not previously have, found by
      looking at the picker on a real machine. The script applies the rule to
      folders and lists every `*.zip` unfiltered (`player:1035`) — bash cannot
      see inside one
      without unpacking it, so the rule is not absent there — it is suspended at
      the one place it could not be run. §2.2 reads a central directory where the
      archive lies, so the port can run it: two `pread`s, no entry data, nothing
      written to disk. On this machine it takes `~/Downloads` from six archives to
      two. Audio means `AudioFiles.extensions`, the same twelve the folder rows
      count with, and dotted paths are excluded because `AudioFiles.scan` skips
      hidden files — an archive whose only `.flac` is a `__MACOSX/._Song.flac`
      stub would open as an empty record. One second, wall-clock, shared across a
      directory's archives; anything that has not answered by then is skipped
      rather than waited on, and `BROWSE` (§14) is how you reach it anyway.
- [x] **Changed from bash (D7).** The count that decides this looks two levels
      deep, not one. In bash the picker counted at `maxdepth 1` while playback
      reads at any depth (`player:1050` vs. `player:1422`) — so an album whose
      tracks live in `CD1/` showed up as having none and was dropped. Depth 2
      rescues multi-disc albums without making a library root like
      `~/Music/Music` (audio at depth 5) present as a record.
- [x] One source and no argument is not a choice, it is the answer — skip the
      picker entirely (`player:1117`).
- [x] Nothing to play at all → say so, naming the directories it looked in
      (`player:1114`). **Changed from bash (D36).** The script *dies* here; a
      window cannot. The port says the same thing on the empty panel instead and
      stays up, which is the state `EmptyPanelView` exists for and the reason
      **⌘O is bound** — `File ▸ Open Record…` — so the panel it invented is not
      also a dead end.
- [x] Keys: `↑↓`/`kj` move, `PgUp`/`PgDn` a screenful, `⏎` open, `r` rescan
      (status `▪ RESCANNED`), `q` walk away with exit 0 (`player:1134`).

### 1.3 The disc

**Where the confidence in this section comes from, before the boxes.** `find_cd`
sits behind a probes seam like §11's — `mount`, `drutil status`, the `/Volumes`
glob, a directory listing, `[ -d ]` and `command -v drutil` are six closures, so
every branch below is reachable from the suite with nothing in the drive.
Thirty-four tests do that. **That is not the same confidence as a disc, and the two are
not blurred here**: each box says which it has. Two of the tests are not stubbed
at all — they run the real probes against whatever this machine currently is and
assert that `mount`, `drutil` and the finder agree with *each other*, which holds
with a disc, without one, and without a drive.

At the time these boxes were ticked **the drive was empty** — `Type: No Media
Inserted`, no `cddafs` line, `/Volumes` holding only `Macintosh HD` and
`My Passport`. The disc that D44 was learned on had been ejected. So the
disc-present halves rest on output transcribed off that disc while it was in
(§19) and replayed through the seam, and on three new §19 tests that will run the
real thing the next time one is loaded. **Nothing here has been through a
`cddafs` mount end to end in this port.**

- [x] `drutil status` is asked **before** any `/Volumes` scan. The drive knows
      about a disc that has not finished mounting, and a directory listing cannot
      tell an album from an external drive of field recordings — without the
      drive's answer that drive gets announced as "in the drive" and then has
      CD-Text and MusicBrainz answers about some entirely other disc applied to
      it (`player:965`, `player:994`, `player:1000`). **Stubs**, and the case
      that shows why: an external volume of AIFFs called `Field Recordings`
      passes every shape test `find_cd` has, and only the drive's answer keeps it
      out. Also load-bearing in the other direction — the `cddafs` route returns
      before `drutil` is called at all, so the ordering is "drutil before the
      listing", never "drutil before everything".
- [x] Primary detection: a `cddafs` mount, parsed off `mount` output. Split on
      the **first** ` on ` and the **last** ` (` so a volume called
      `Live (Remastered)` keeps its name (`player:985`).
      **Both splits on stubs; the parse itself on hardware.** The real `mount`
      table is parsed in an ungated test, and it turned out to hold two lines
      that are not device mounts at all — `devfs on /dev` and `map auto_home on
      /System/Volumes/Data/home`, the second with a space *before* the first
      ` on `. Neither is a problem, for the uninteresting reason that neither is
      `cddafs`, and the test asserts nothing tighter about the device end than
      non-empty: a rule the kernel does not honour is worse than no rule. The
      space-in-a-volume-name case is not hypothetical either — this machine
      mounts `/dev/disk5s2 on /Volumes/My Passport (exfat, …)`, and it is in the
      suite as observed.
- [x] Fallback: a `/Volumes` entry whose listing contains `Audio Track`, or ≥ 2
      `.aif`/`.aiff` files — only once `drutil` has confirmed media
      (`player:1002`). **Stubs only, and this one may never run on this
      platform**: macOS mounts an audio CD `cddafs`, so the kernel route answers
      first and the fallback is dead code on a healthy Mac. It is kept because
      the script keeps it and because it is the path a half-mounted disc takes.
      The ungated hardware test asserts that a `.shape` answer can only happen
      with no `cddafs` mount and the drive reporting media — so if this fallback
      ever does fire on real hardware, the suite says so rather than quietly
      passing.
- [x] **Changed from bash (D17).** The shape test above stays exactly as it is
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

      **Stubs, plus one observation.** The gate goes *after* the count guard and
      *before* the shape tests, so a volume on the wrong node is skipped and the
      scan carries on rather than giving up. The comparison is a function and not
      a prefix test, because `/dev/disk1` is a prefix of `/dev/disk10` and the
      naive version would confirm an internal volume against the disc in the
      drive; a slice has to be `s` followed by digits. What was seen on the disc
      itself is that a CDDA mount is the **whole-disk** node —
      `/dev/disk10 on /Volumes/Deluxe (cddafs, …)` against `drutil`'s
      `Name: /dev/disk10` — so on a real audio CD it is the *equality* case that
      fires and the slice case is purely for the fallback. A §19 test now asserts
      that agreement instead of trusting the one reading.
- [x] **`drutil` runs before anything opens the device.** `cdrecord -checkdrive`
      and `-prcap` — and any libdiscid read — open the drive *exclusively*, and
      for as long as that lasts macOS lets go of the media, so `drutil` then
      reports `No Media Inserted` about a disc that never moved, and keeps
      reporting it until something spins the drive back up (`burncd:278`).
      Ask drutil first, keep the answer, and never let a device read run ahead of
      it. Not in `player` — `burncd` is where this was learned — but it is the
      same ordering the first box argues for on entirely different grounds, which
      is a good sign about both.

      **By construction rather than by test, and stated as such.** `find_cd`
      opens nothing at all: it reads the mount table and asks the drive for its
      status, both of which are answers *about* the drive. There is no ordering
      to get wrong because there is no second thing in the sequence — which is
      why this can run on every scan and every rescan without consequence. The
      rule still binds §4.2, where CD-Text does open the device.

      This is also the box that no longer rests on the rule alone. **Directly
      observed on the disc** (§19): six `cdrecord -checkdrive` invocations exited
      255 on every device node, `cdrecord -toc` exited 255 with no `track:` line,
      `cdda2wav -J -v titles` exited 1 — and `drutil` was unaffected throughout,
      because a *failed* exclusive open never took the media. The ordering
      matters for the opens that succeed; what this run showed is that on a
      mounted audio CD there are none, which is D44.
- [x] No ripping step. The mounted CDDA volume is played as it stands
      (`player:1371`). The volume already presents the audio as files; copying
      them somewhere first would buy nothing and cost the time.
- [x] A data disc is correctly ignored: it is not a `cddafs` mount
      (`player:985`), and its `/Volumes` listing carries neither `Audio Track`
      nor two AIFFs (`player:1006`). It falls out of detection rather than being
      rejected — there is no "this is a data disc" message and there should not
      be one, because from here it is simply a mounted volume like any other.
      **Stubs.** Held as three separate refusals, because they fail at three
      different places: no AIFFs at all never reaches the name test, one AIFF
      with no `Audio Track` in it passes neither test, and a volume of mp3s is
      not a disc shape however loaded the drive is.

**One path in this section that no hardware has touched, said plainly.** §4.1's
rescue — the disc macOS cannot name, whose tracks arrive as `1 Audio Track.aiff`
— has never fired on a real disc here. The one that was in the drive came with
real track names, so the rescue was inert on it and §19's tidy-list test had to
be rewritten to assert the rule on the rows it governs rather than on that disc's
material. Every branch of `find_cd` that keys on the string `Audio Track` is
therefore **stub-only**, and stays that way until a disc that macOS cannot name
goes in. That includes the `/Volumes` fallback's first test, which is the branch
most likely to matter on such a disc.

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
- [x] Teardown on **every** exit path — clean quit, `die()`, Ctrl-C, SIGTERM
      (`player:285`, `player:324`). `AppDelegate.applicationShouldTerminate`
      calls `model.cleanup()` on every exit AppKit delivers — Cmd-Q, Dock quit,
      system shutdown, SIGTERM. `die()` shows the message on screen and does not
      exit; no terminal to restore.
- [x] Teardown order: screen first (so a message below lands on a terminal that
      can show it), then the player process, then any background analysis, then
      the directory. Nothing in the handler may be skipped because something
      earlier in it failed (`player:293`). `cleanup()` cancels the ticker and
      sleeve, then `engine.shutdown()`, then `tearDownScratch()`. Screen restore
      does not apply — GUI app.
- [x] `MUTHUR_KEEP` set (or `PLAYER_KEEP` — D13) → the directory survives, is
      marked with a `keep` file so the next session's sweep spares it, and its
      path is printed to stderr (`player:313`). `tearDownScratch()` reads the
      environment, calls `scratch.tearDown(keep:)`, prints the path to stderr.
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
- [x] **The album knows it came out of a zip.** D12's rule only applies to a zip
      source, so something has to carry that fact from whatever opened the
      source to whatever reads the album. `SourceOpener.open` carries
      `SourceKind` through to `Record.read`, so the zip path now knows it is a
      zip.
- [x] **D12 is switched on for real zips.** `Record.read` takes
      `discsFromSubdirectories`, and `SourceOpener.openZip` passes `true` when
      the unpacked result spans more than one directory. → D12

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

- [x] `tags` — embedded metadata. The normal case, and the only source a folder
      or a zip ever has (`player:1417`). Stamped by `SourceOpener.open` — the
      source layer now carries `TitleSource.tags` on every folder and zip.
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
      installed. **Where the TOC itself comes from is settled — D44.** It comes
      off `.TOC.plist` at the root of the mounted volume, which is the only one
      of the three routes that can read a disc macOS has mounted — and macOS
      mounts every audio CD. D42 said `cdrecord -toc` and was reversed on the
      first real disc; libdiscid stays on this side of the line, as the oracle,
      which is what keeps a fresh clone compiling and keeps §4.3's arithmetic
      checked against somebody else's.
- [x] `.TOC.plist` is read into that table (**D44**): the first session's
      `First Track`, `Last Track`, `Leadout Block` and one `Start Block` per
      track. Blocks are already in TOC form — track one reads 150 — so `fromLBA`
      is *not* in the way, and the first session is taken rather than the last
      because an enhanced CD's fingerprint is over its audio session alone. Lead-in
      descriptors (points 160–162) are not tracks, and a hole in the table is
      refused for the same reason D20 refuses one from `cdrecord`.
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
      `player:2035`). **Asked at `front-1200` first and `front-500` second —
      D45.** The script asks for one size only, `front-500` (`player:1916`),
      because the biggest sleeve a terminal can draw is a few dozen columns
      wide. §14's is a Retina display.
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
      archive, whose sizes are named in the request (D45) and are every one of
      them far over the floor.

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

### 5.4 Drawing it

Everything above is the finding. This is the last step, and it is a view: by the
time a sleeve reaches it the bytes are on disk and nothing is waiting on
anything.

- [x] **Column 74, row 3** — the gutter takes 72 and 73 and the cover starts
      level with the album title (`player:504`, `player:1746`). This is what the
      fixed panel width is *for*.
- [x] `art_tick`'s three bounds, ported to `SleeveFrame` (`player:3133`): as wide
      as the window spares, no taller than the rows above the analyser, and
      nothing at all below `ART_MIN` (12 columns). **No `ART_MAX`** — the ceiling
      is deliberately dropped (**D2**), so a window dragged wider keeps giving
      the sleeve more.
- [x] The sleeve stops where the analyser starts. In bash the reason was the
      strobing repaint (`player:3119`); here the analyser does not erase what is
      beside it, but the rule stays because the *layout* reason stands — the
      instrument's rows are the instrument's.
- [x] Decoded straight to the size it is drawn at, and re-decoded when that size
      changes, rather than a full decode and a scale.
- [x] No cover means no cover: the panel is unchanged and the window keeps its
      shape.
- [x] **The treatment: phosphor.** The cover is quantised to the panel's own
      ramp with a 4×4 ordered dither, which is the halftone in a printed sleeve
      as much as it is a dither. A crisp JPEG beside an instrument is brighter
      than the data on it, which is the one rule the palette has.
- [x] **And capped.** The sleeve's ramp is the panel's resampled to stop two
      steps below the brightest, so the cover can be as bright as the badge and
      no brighter (`Theme.sleeveRamp`). Eight levels either way: the ceiling is
      bought by resampling, not by throwing stops away, because the levels are
      what stop a sky becoming stripes.
- [x] **The edge: the bezel.** A lit rectangle against the dark reads as a hole
      in the screen rather than an object on it. Two were built — a dim rule, and
      the rule with the picture darkened into its own edges — and the bezel won:
      the darkening is what turns the rule from a line drawn *near* the picture
      into the picture's own edge, so the sleeve sits on the panel instead of
      being cut out of it. `MUTHUR_SLEEVE_EDGE=rule` keeps the other.
- [x] **The ceiling is level with the plate**, at 5 along the ramp
      (`Theme.sleeveCeiling`) — settled, and the number the ramp is cut at.
- [x] **§18.24 — a cover that is not square. The letterboxing stays, as
      D48.** The script fills the box exactly and stretches
      (`scale=$w:$((h*2))`, `player:2974`); the port preserves the aspect and
      leaves ground above and below. *Closed as a divergence rather than as a
      question, because there was never an opposing decision to override:
      `scale` is given two exact numbers and **no aspect term at all** — no
      `force_original_aspect_ratio`, no `-1` — and every number around it is the
      cell being un-squashed (`h=$((w/2))`, then `w=$((h*2))`), which is about
      the terminal and not about the picture. The script was written as if every
      cover were square and, on the material it was written against, every cover
      was. That makes stretching an **unmet case**, not a settled preference,
      and a port that inherits it inherits nothing that was chosen. The flag
      comes down; the divergence is on the record with its reasoning.*

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

- [x] All of the above (`player:2687`). Bound in `PanelView.handle` and
      `PanelView.letter`; the arrows and the vi pair go to the same call so there
      is one behaviour and two ways to reach it.
- [x] **Cursor and playhead are two different things.** `♪` is the track the
      music is coming out of (`‖` when paused); the highlighted row with `▶` in
      the gutter is the cursor. Usually they agree; when you browse ahead they do
      not, and the panel has to be able to say so — which is why the playing mark
      is not a second arrow (`player:2344`).
- [x] Moving the cursor is browsing, and browsing stops the cursor chasing the
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
- [x] Status line messages: `▪ SHUFFLE ON/OFF`, `▪ REPEAT OFF/ALBUM/TRACK`
      (`player:2702`, `player:2704`). `u` takes the resume offer and is bound
      only while there is one (`player:2720`) — the key returns `.ignored` with
      no offer on the panel, so it is the offer being *readable* that makes the
      key live, which is the whole of why the script bound it that way.
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
- [x] The hardware volume keys stay the system's. macOS handles them above the
      app and they never arrive here — nothing to bind, nothing to fight. What
      the media keys owe us is play/pause/next/previous (§14), which is separate.
- [x] The level survives a quit. A deck left at 3 is at 3 when you come back.
      It lives in the app's own `UserDefaults` and **not** in the resume file:
      §18.19 froze that file's four fields so the bash player goes on reading it,
      and a level is not one of the four.
- [x] Shown on the faceplate, in the chrome amber, not as data — `VOL 88`, or
      `MUTE`, last in the meta run after the mode, the count and the title
      source.
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
- [x] Click a row to select, click it again to play it. The first click moves the
      cursor and the second starts it, which is the difference between reading
      the list with the pointer and being made to listen to whatever the pointer
      happened to land on (`player:3213`).
- [x] The wheel walks the track list (`player:3188`). A local `NSEvent` monitor
      rather than a view that catches scrolls: a view that catches scrolls has to
      sit over the panel, and it would then be in the way of every click on it.
      There is one panel and one window, and its one long list is the track list,
      so a scroll anywhere in it means the list. The accumulator carries the
      remainder between events so a trackpad's small deltas still add up to whole
      rows rather than being thrown away.
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
- [x] Middle and right buttons mean nothing here; answering them with a seek
      would be a nasty surprise (`player:3194`). Structurally true rather than
      filtered for: `DragGesture` and `onTapGesture` only ever hear the left
      button, so there is nothing to ignore.

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

- [x] Looks the playing album up in a catalogue CSV (`PLAYER_COLLECTION`, else
      the CSV two directories up from the script) and prints two extra faceplate
      lines: `SHELF` (parent genre · tags) and `NOTE`, the note in amber.
      *The script's `SHELF` opens with the catalogue's year (`player:1725`);
      **D6 took the year off this line** and put it beside the artist, from one
      precedence, so it is one year on the panel rather than two.*
- [x] **This is the one thing a general-purpose player cannot do.** MusicBrainz
      knows what a disc is; only the shelf it came off knows that you bought it
      used at Amoeba and that it skips on track seven — and track seven skipping
      is precisely the moment you want to be told you already knew.
- [x] **Nothing here is allowed to matter.** No file, a renamed header, an album
      not in the collection — the panel is exactly what it would have been. A
      missing note is not a reason to interrupt a record (`player:1618`).
- [x] Columns found **by name, not by number** — the two CSVs in that repository
      do not agree on column order, and a lookup that silently reads the wrong
      column is worse than one that finds nothing (`player:1645`).
- [x] Real CSV field parsing, quoted fields included: `"riot grrrl, compilation,
      punk rock"` is one field with two commas in it.
- [x] Matching is normalised — lowercased, leading `the ` dropped,
      non-alphanumerics stripped — so `The Beatles` finds `Beatles` and
      punctuation never decides it (`player:1679`).
- [x] Artist must agree when there is one. With no album artist at all, a title
      match is accepted **only if exactly one** record answers to it — two would
      be a coin toss (`player:1698`).
- [x] Assembled once per session, not per frame. *The file is opened on the
      first record that asks and kept for the session (`player:1723` assembles
      `COLL_SHELF` once "rather than on every frame"); choosing a different one
      through the picker drops it and rebuilds the header.*

**Where the file lives (D5, decided).** Bash resolves it relative to `$0`,
following symlinks, to `../../data/collection.csv` (`player:1631`) — a `.app` has
no such relative path.

- [x] A **path in Settings**, defaulting to
      `~/Sites/cd-collection/data/collection.csv`, overridable through a file
      picker so the choice is a security-scoped bookmark rather than a string
      that stops working the day the app is sandboxed. `PLAYER_COLLECTION`
      becomes that setting.
- [x] **The live file, read fresh each session. Not a copy imported into the app.**
      That CSV is maintained — it is the data behind the collection site in the
      same repository — and a copy would go stale silently. A stale note is worse
      than no note: the entire value of this feature is that it remembers what
      you do not, so a note that is merely out of date is the one failure mode
      that cannot be spotted from the panel.
- [x] **Read only, ever.** `cd-collection` is not ours to write to (`CLAUDE.md`),
      and nothing here needs to.
- [x] Header as it stands today:
      `Number,Book,Artist,Title,Year,Parent Genre,Tags,Art URL,Notes,Barcode` —
      recorded as a fact about the file, not as an assumption. Columns are still
      found by name, and a renamed or missing one still means the panel is
      exactly what it would have been.
- [x] No file, no setting, no match — nothing happens, silently. Not a
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
- [x] Peak-hold trail: `SPEC_FALL` is 2, and it is 2 eighths **a frame** — the
      tick's twenty a second, not the levels' ten (`player:105`, `player:2661`,
      `player:2878`, and **D23** on why those are different numbers). Forty
      eighths a second is the whole column in one second. It dims with age down
      the amber ramp, so it reads as the same light going out, and a fast
      transient stays visible for longer than the tenth of a second it lasted
      (`player:667`).

      *This is the VU ballistics, and they were already here: fast attack is the
      box above, slow decay is `SPEC_FALL` on the trail, and the falling peak cap
      is the trail itself. `AnalyserColumns.step` is `spec_step` (`player:609`)
      and nothing was added on top of it — a second layer of damping would be a
      silent divergence from a script that has been used and debugged.*
- [x] **The column is not damped, and that is decided, not pending.** The script
      damps the trail only and lets the column drop instantly (`player:611`).
      Damping both is what a VU meter does, and the temptation to do it here
      comes from the phrase "VU ballistics" rather than from anything on the
      panel. **This is not a VU meter.** `spec.md`'s reference points are
      oscilloscopes and spectrum analysers, and those damp exactly the way the
      script does — for the reason that makes the whole display work: *the column
      is the instantaneous reading and the trail is the memory of it*. Damping
      both collapses two instruments into one, and the moment the column is slowed
      toward the trail the trail stops reading as a peak-hold, because a peak-hold
      is only legible as the distance between a fast thing and a slow one.
      **Closed against. Do not reopen it from the phrase alone.**
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
      their whole height. **Over the record, not over the track** (D33): the
      script can scale each track by itself because it has decoded the whole of
      it before it draws a frame, and a live tap cannot, so the sample is the
      band's history since the record went on. §18.21 is the measurement that
      settles it and the arithmetic above is untouched.
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
step. The autoscale is the one thing that could not be ported as it stood,
because the difference is the sample it is taken over: **§18.21**, measured and
answered as **D33** — the scales now live across a track change, and the
histogram starts as though the band had been at full scale all along, so the
scale comes down onto the record instead of up to meet it. How long it stays at
the ceiling is a duration, and it is fitted to the script rather than chosen.

`Analyser.tap` takes any `AVAudioNode`, on purpose. The deck's graph is not
reachable from here and does not need to be, which is why §9 landed without
touching `Play/` and why the whole of it is tested against an engine rendering
offline with no sound card in the room. §6.1a — that the analyser reads the
signal *before* the gain, so a record turned down still moves the columns — is a
question about *which* node, and it was answered when §10 wired the two together:
the player node, ahead of the main mixer that carries the gain.

Wiring them cost two lines in `Play/`, and both were the same bug wearing
different clothes — **the player node is only in the graph while a record is on
the deck.** It is attached in `startGraph` and detached again in `teardown`, and
AVAudioEngine does not treat a detached node as an empty room: it raises. §10
starts its clock with the *window*, not with the record, so it does two things
the offline suites never did — it asks the analyser to listen before anything is
loaded, and it pumps an empty deck twenty times a second while you decide what to
play. Both terminated the app on launch. So `listen(_:)` now remembers who wants
to listen and hands them the player each time there is one to hand over — which
also fixes the second record, where the tap would otherwise have been lost with
the node it was on — and `pump()` returns immediately when there is no graph.
Both are §10 genuinely requiring `Play/`, and both were found by running the app
rather than by a test, because the suites always load a record first.

---

## 10. Panel and layout

The character-grid arithmetic is documented here so the *visual rhythm* survives
even where the constraint does not. `spec.md`: treat the grid as a design grid,
drop the constraint where it only ever existed because of the terminal.

- [x] Faceplate on every stage — badge, rule, and the machine's state stamped at
      the far end the way a deck prints its mode. Every screen wearing the same
      one is most of why they read as one instrument (`panel.sh:256`).
      *Closed by the loading stage below, which was the fifth screen and the
      third the script has. There are now enough of them for "every" to mean
      something, and `Faceplate` holds all five metas rather than the views
      holding their own, so the claim is a thing the suite can be asked about.
      Three are the script's — `N SOURCES` (`player:1063`), the loading stage's
      own title (`player:1167`), `PLAYING · 9 TRACKS · tags` (`player:2322`).
      Two are the port's, because the screens are: `SELF TEST · 12 CHECKS · 2 !`
      on §11's check, which in bash is a terminal and wears no plate at all, and
      `STOPPED · 0 TRACKS` on the empty deck, which in bash cannot exist. The
      check's wording is **mine** — the state word is `SELF TEST` and not
      `HEALTH CHECK` because `CheckView`'s own first line already says the
      latter, and the plate saying what the machine is doing while the block
      under it says what is being looked at is the same split the now-playing
      panel already has. The two tests that matter are that all five put badge,
      rule and meta in that order, and that all five land flush on the panel's
      right-hand edge with a rule still in them.*
- [x] Faceplate meta on the now-playing panel: `PLAYING · 9 TRACKS · tags`
      (`player:2320`). Mode labels: `PLAYING`, `PAUSED`, `STOPPED`, `FINISHED`.
- [x] Header block: `ALBUM`, `ARTIST`, `SOURCE`, then `SHELF`/`NOTE` when the
      record is in the collection. **The metadata source is not repeated here** —
      the faceplate says it, and saying it twice on one screen reads like two
      different facts (`player:2325`).
      *Closed by §8. Both extra lines are drawn, each only when it has something
      on it, and the track list gives up exactly the rows they took — which is
      the script's `COLL_ROWS` (`player:2443`) arriving for free, because
      `PanelView` has always budgeted the tracks against the header's own
      height rather than against a count.*
- [x] **Changed from bash (D6). The year is on the panel**, set after the artist
      as `(1979)`, the same shape `-n` prints. In bash it appeared only in `-n`
      (`player:3542`) while the panel's `SHELF` line carried the *collection's*
      year (`player:2333`) — so a record not in the collection showed no year
      anywhere, and one that was in it showed a year that had not come from the
      record.
- [x] One year: the MusicBrainz release date where it answered, the tags where
      it did not, the collection last. *§8 supplied the third and last of the
      three. The first two were in the other order until §18.26 was answered by
      following the script (`player:2215`) and D6 was amended in place; nothing
      can observe the swap until §1.3, because a mounted CD has no tags.*
      `HeaderBlock.year` and `DiscTitles.swift:178` now agree on it from both
      ends. `SHELF` stops carrying it and keeps
      genre and tags, by the same rule as the source label above — where the two
      disagree, that disagreement is not worth two lines on a faceplate.
- [x] **Amber is the chrome — rules, labels, the badge — and never the data, so
      the titles stay the brightest thing on the screen** (`panel.sh:84`). Left
      unticked for a while on a misreading: titles are the brightest thing drawn,
      which looked like a violation. It is not. **The rule constrains the amber,
      not the brightness** — titles are `Theme.text` and not amber at all, and
      track titles being the brightest thing on a music player is the rule
      working, because they are the thing being read. Row numbers and durations
      are `Theme.etch`, which is the chrome, which is where the amber lives.
- [x] Band colours zigzag light/dark/light/dark around the panel's own amber, so
      neighbouring bands separate on brightness even where the hues are cousins
      and the edges survive without colour vision (`panel.sh:92`, `panel.sh:97`).
- [x] **The artist column is dropped on an album and kept on a compilation.** On
      an album every row would carry the same name and that name is already at
      the top: a column that repeats one fact fifty times is not a column, it is
      a margin with writing on it. Dropping it is the difference between
      `Libet's all joyful camarad…` and the title the record actually has
      (`player:2270`).
- [x] The test is against the *album artist*, not merely "they all agree": a
      record whose tracks say `Miles Davis Quintet` under an album credited to
      `Miles Davis` is not repeating the header, it is saying something else
      (`player:2301`).
- [x] Decided once per record, not per row — this gives the titles the slack, it
      does not make the edges ragged (`player:2284`).
- [x] The artist column is sized to the longest name the record actually
      contains, and right-aligned against the durations: two ragged edges facing
      each other read as a gap of no particular width, two flush ones read as a
      margin (`panel.sh:362`, `panel.sh:366`).
- [x] Truncation is visible — a cut title ends in `…` (`panel.sh:338`,
      `panel.sh:358`).
- [x] Two meters, because they answer different questions and each is the wrong
      answer to the other's: the track bar is "how much of this song is left",
      which is what you want when deciding whether to skip; the album meter is
      the whole record divided into its tracks in proportion, so you can see the
      shape of the record and where in that shape you are (`player:2260`).
- [x] Album meter band widths by **largest remainder**, so a longer track can
      never be drawn narrower than a shorter one. Truncating each running total
      independently made exactly that happen — a 3:14 rounded down while the 2:58
      after it landed on a boundary and got more — which is the one comparison
      the meter exists to support (`panel.sh:406`, `panel.sh:414`).
- [x] A track too short to earn any width gets no band and consumes no colour, so
      the two tracks either side of it still contrast (`panel.sh:448`,
      `panel.sh:453`).
- [x] The head — the playhead — wins over any band boundary in the cell it is
      in. It is the one thing on the bar that is moving (`panel.sh:484`,
      `panel.sh:505`).
- [x] Eighth-cell resolution: a boundary falling mid-column is drawn as a partial
      block of the outgoing colour over the incoming one as background. Eight
      times the resolution without one extra column, which is what lets a few
      cells still say that a 3:14 is longer than a 2:58 (`panel.sh:398`,
      `panel.sh:500`).
      *Reasoning kept, mechanism improved. `Meter` still works in eighths — that
      is the arithmetic deciding which band a column belongs to, and it is what
      the suite checks against the script. What changes is the last step: the
      strips are drawn rather than typed, so the boundary lands where it actually
      falls instead of being rounded to the nearest of eight glyphs on the way to
      the screen. The script wanted eighths because a terminal gave it nothing
      finer; it is the only reason it wanted them.*
- [x] `▾ N MORE` when the list is clamped, worded the same wherever that happens
      (`panel.sh:384`).
- [x] Keycap legend rows, both of them (`player:2429`, `player:2430`).
- [x] Loading stage: the album meter with no bands yet, one per file as they
      land, which is the honest picture of the wait. Distinct stages `OPENING`,
      `READING`, `READING DISC` with a per-file/per-step line
      (`player:1148`).
      *`LoadingStage` is what the script hands `load_stage` — a heading, a
      source, a detail and the two numbers the bar's head sits at — and
      `LoadingView` is the frame at `player:1162`: `SOURCE`, `READING`, and one
      `trackbar` under them, in the header block's own column because it is the
      same column. **`SourceOpener`'s `progress` used to hand over a formatted
      sentence**, which meant the two numbers were spent on the wording and
      thrown away, so the panel could say `READING · 62%` and had nothing to
      draw a meter with. It hands over the stage now.*
      ***A fourth stage word went away.*** *The port had grown `UNPACKING`,
      which the script has nowhere: `open_source` says `OPENING` before the
      archive is touched (`player:1398`) and the unpack counts up under the same
      word (`player:1290`, `player:1360`). Three words, and the percentage is
      what says how far in it is.*
      *Four oddities kept and written up in `LoadingStage`: the second label is
      always `READING` whatever the heading says (`player:1170`); `SOURCE` is
      **not** cut here and is cut on the now-playing panel (`player:1169` against
      `player:2329`); `head` is computed and never used (`player:1160`); and
      `bands` is called with its answer thrown away (`player:1161`) — the frame
      prints `$TRACKBAR` and nothing else. The last two are dead in the original
      and are not carried over; the first two are visible and are.*
      *While it is up there are no keycaps, no status row, no meters and no
      burn-in — `load_stage` prints none of them, and a legend that lights up
      and does nothing is the lie the dead ⌘O was.*
- [x] **Clickable keycaps** (**D30**). The legend was a picture of a keyboard on
      an instrument that answered the pointer everywhere else (§6.4), and a drawn
      switch that does nothing when you push it reads as broken rather than as
      decoration. Every cap is now a switch: it lights while the contact is made,
      and `←→` and `↑↓` are **rockers**, split at the two glyphs they are drawn
      with, so the half you push is the direction you get. The two rockers repeat
      while held, at the system's own key-repeat delay and interval rather than at
      a rate invented here; the single-throw caps fire once, because a held `S`
      toggling shuffle twenty times a second is a coin being flipped. Shift is
      carried, so a shift-click on `←→` seeks the thirty seconds a shift-arrow
      does.

**The look pass** — `spec.md:78–110`, the aging and CRT treatment. This is where
the panel stops being a layout and starts being an object:

- [x] Phosphor: one colour throughout, running brighter toward white in the core
      and dimmer at the edge. **A glowing cell does not change hue** — a lit
      character is the same phosphor harder, which is the rule the whole ramp is
      built on and the reason nothing on the panel is allowed a second colour.
- [x] Bloom, tight. A wide bloom is the thing that turns a letter into a smear,
      and this has to survive an hour of being looked at (`Theme.bloomRadius`).
- [x] Scanlines, uneven raster, vignette, sheen, bowed glass, rounded corners,
      and a chassis with real thickness around all of it.
- [x] **The glass is the deep one and the text is the bright one** (**D28**). The
      veils are drawn over the panel and the levels into it, so the deep optics
      sit over console-brightness lettering. `Theme.vignetteClear` starts the
      fall-off outside the column the panel is set in: the corners go deep and
      the track list pays nothing.
- [x] **The curvature is the glass's, not the text's** (**D29**). The glass
      curves; the words do not, because a bowed layout makes every column sum in
      this section a lie about where things are.
- [x] **Type for chrome and readouts** (**D28**). The dotted lettering and the
      segmented figures stay behind `MUTHUR_LETTERING=matrix` and
      `MUTHUR_NUMERALS=segment`. Both paths are drawn in a `Canvas` on the same
      cell, so the columns agree and neither can ellipsize.
- [x] **The wordmark is dots** (**D27**) — the character generator's own, at
      twice the pitch, so the name is made of the same light as the titles and
      ages with them. The stamped plate was built and rejected.
- [x] **Changed from bash (D26). The room under the last track is filled with a
      run-out** — a tightening spiral of grooves ending on the dead groove.
      **This diverges from `player:2341`**, where `np_frame`'s loop stops at the
      last track and everything below the list is ground. The script is right for
      a terminal, where those rows are the shell's; an app window's bottom edge
      belongs to the instrument. `MUTHUR_COMPOSITION=deck` restores the script's
      behaviour.
- [x] **No flicker, by construction rather than by tuning.** Nothing in the
      treatment is a function of time: the scanlines, the unevenness, the
      vignette, the sheen, the bow and the burn are all drawn once and do not
      move. A CRT that flickers is a CRT in a film; one you have been sitting in
      front of for nine months just sits there being slightly uneven.
- [x] **Reduce Transparency honoured** — every one of these is a veil over the
      content, which is exactly what the setting is asking about, so `Bloom` and
      `ScreenEffects` simply are not there when it is on.
- [x] **Reduce Motion has nothing here to turn off, and that is the answer, not
      an omission.** The only things on this panel that move are the analyser
      columns and the two playheads, and all three are *readings* — the setting
      asks for decorative animation to stop, and freezing a level meter over
      sound is the same lie §9 refuses in the other direction, where columns
      dance over silence. Nothing decorative animates, so there is nothing to
      suppress.

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

- [x] Per-item pass / warn / fail with a fix, and a verdict. Non-zero exit on a
      hard failure only; a warning is worth saying out loud but is not a reason
      to refuse (`panel.sh:595`, `panel.sh:598`, `player:531`). `Check` is the
      mark, the label and the detail; `Diagnostics.Report` derives `CHECK_FAIL`
      and `CHECK_WARN` rather than accumulating them, because the script only
      keeps two globals for them since `ck` is a printf with nowhere to put a
      return value (`panel.sh:578`).
- [x] Items to carry across, re-pointed at the native stack: decoder
      availability, the ffmpeg fallback path (Opus/Ogg), zip handling, optical
      drive and media, CD-Text tooling, MusicBrainz reachability (and whether it
      is disabled), **scratch space — free bytes, writability, and whether the
      `$TMPDIR` fallback is in force**, and audio output route. All present, and
      one of them diverges: **reachability is not probed (D39)** — the row says
      what the lookup *will* try, because a diagnostic that hangs on a captive
      portal is worse than one that admits it has not asked.
- [x] **What the cover will look like, and whether it can be shown at all.** This
      is the question the check is really there for: a sleeve that is silently
      absent looks exactly like a sleeve that failed to download, and the two
      have nothing to do with each other (`player:454`). The `sleeve` row keeps
      the question and none of bash's answers, which were all about columns and
      iTerm2 — a window has pixels.
- [x] Warnings are usually fine — "no disc, or no drive" just means the drive is
      empty (README). Said in the verdict's middle case, which is the one most
      machines land on.

**Two more rows than bash has, and both are §8's and §1's doing.** `the shelf`
and `records` exist because those two subsections gave the port something that
can be silently absent: a `SHELF` line that is simply not drawn looks identical
whether the record is not in the catalogue or the catalogue was never found, and
`nothing to play in …` used to be a `die` at the moment it mattered (`player:1114`)
and now has to be a calm line on a screen instead (D36). `audio output` is the
third addition and is §14's — a terminal hands its sound to mpv and neither is
in a position to say where it went.

**The screen and the flag are the same report.** `Diagnostics.run` is headless
and returns `[Check]`; `CheckView` draws it on the panel's grid and
`Report.plainText` prints it to a terminal. Nothing about the check knows which
one it is in.

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
| 14 | — | `player:466` | verdict, **three of them**: `Not ready to play.` `Fix the ✗ items above.` · `Mostly ready.` `Warnings above are usually fine.` · `Ready to play.` (`panel.sh:598`–`panel.sh:604`) | Keep all three, and this is where D8's voice belongs |
| — | audio output | — | not in bash | **New** — the route, per §14 |

- [x] **`fail` is the only thing that changes the exit code**; `warn` is printed
      and counted and does not (`panel.sh:577`, `panel.sh:598`). Ten of the
      fourteen can only ever warn — the check exists to explain, not to gate.
      `Report.exitCode` is `failed ? 1 : 0` and nothing else feeds it.
- [x] The gate is separate from the check and comes after it: `--check` exits on
      its own verdict (`player:531`), and a normal run dies independently if mpv,
      ffprobe or `nc` are missing (`player:538`). Natively the second gate is
      almost empty, and that is the point — most of what could go wrong is a
      degraded picture, not a refusal. **Here it is empty outright**: none of the
      three binaries the script gates on is needed, so there is no second gate to
      write.
- [x] Every check is `ok`/`warn`/`fail` **plus a fix**, never a bare status. The
      fix is the reason the screen exists — and on a 69-column panel a fix that
      does not fit **turns over** rather than being cut (`Columns.wrap`), because
      the half of the line that gets cut is the half that tells you what to do.

### 11.1a What this port prints, row by row

The list above is bash's. This is the screen as it stands, walked against it:
twelve rows where bash has fourteen, and **nothing goes silent** — a subsystem
the port cannot yet report on says so in its own row rather than being left off.

**`--check` and the check screen are the same twelve rows and deliberately not
the same output**, which is worth stating because the faceplate makes it look
like a discrepancy. `--check` prints `Report.plainText` — `ck`'s own layout with
the colour left out (`panel.sh:583`, `panel.sh:588`) — and never prints `SELF
TEST · 12 CHECKS`. It cannot and should not: the script's `run_check` prints to a
terminal with no panel up, so there is no plate to write on, and a faceplate over
a terminal report would be the port inventing chrome the original never had.
`Faceplate.checkMeta` is the *screen* version's plate and is reached only from
`PanelModel.faceplateMeta`. Intended, not an omission.

| Port row | Was | Marks and details, verbatim |
| --- | --- | --- |
| `playback` | `mpv` (`player:349`) | **ok** `AVFoundation — the engine is part of the system`. Cannot fail; kept because "where did the mpv check go" is a question this screen exists to answer |
| `metadata` | `ffprobe` (`player:361`) | **ok** `AVFoundation, with ffprobe at <path>` · **warn** `AVFoundation only — no ffprobe, so Opus and Ogg may not read. brew install ffmpeg`. **A fail becomes a warn**: bash needed ffprobe for every tag, this needs it only for what AVFoundation will not take |
| `analyser` | `analyser` (`player:371`) | **ok** `an AVAudioEngine tap — the columns are the audio itself`. §9's FFT is the audio, so the pattern fallback has nothing left to fall back from |
| `zips` | `mpv archives` + `zips` (`player:355`, `player:379`) | **ok** `read where they lie — no tar, no unzip, no charset to get wrong`. Two rows collapse into one and bash's hard fail disappears with them (§2.2, `player:256`) |
| `optical drive` | `optical drive` (`player:395`) | **ok** `media: <type> — mounted at <path>` · **warn** `media: <type> — not mounted as an audio CD, so --cd has nothing to open` · **warn** `no disc, or no drive` · **warn** `drutil not found — CDs cannot be detected`. Four outcomes where bash has three: §1.3 split the media case in two |
| `CD-Text` | `CD-Text` (`player:402`) | **ok** `cdda2wav present` / `cdrecord present` · **warn** `no cdrtools — discs fall back to MusicBrainz or numbers`. Presence only — **nothing here opens the drive** |
| `MusicBrainz` | `MusicBrainz` (`player:410`) | **ok** `URLSession — no curl, no jq. Reached when a disc needs naming, never before` · **warn** `disabled with --no-mb — untitled discs stay untitled` · **warn** `disabled with MUTHUR_NO_MB — …`, the same row naming whichever switch is set |
| `scratch space` | `scratch space` (`player:423`) | **ok** `<N> free in <dir>` · **warn** `<N> free in <dir> — cache dir unwritable, so long albums may be reclaimed mid-play` · **fail** `cannot write to <dir> — zips cannot be opened`. All three, and it is the only row that can fail |
| `sleeve` | `cover` (`player:454`) | **ok** `beside the record, then the tags, then the archive — at the size the window has` · **ok** `off — no picture is looked for` |
| `audio output` | — | **warn** `<device> — the route is read once, and changing it mid-record is not handled yet` · **warn** `CoreAudio named no default output device`. **New** (§14) |
| `the shelf` | — | **ok** `<N> records in <path>` · **warn** `no catalogue at <path> — records play, they just arrive unannotated` · **warn** `<path> has no title column — nothing can be looked up in it`. **New** (§8) |
| `records` | — | **ok** `<N> in <dirs>` · **warn** `nothing to play in <dirs>`. **New** (§1, and the calm form of `player:1114`) |

**`optical drive` asks §1.3, because the media type cannot answer the question
the row is for.** It is still asked first, with `drutil` and nothing that opens
the device (`burncd:278`), and `DiscFinder` is asked after it for the same reason
it is safe on every rescan: it opens nothing either, it reads the mount table and
a status. That second question is not decoration. **A real audio CD reports
`Type: CD-ROM`** — §19 step 1, the disc that mounted as `/Volumes/Deluxe` — which
is the same word a data disc gives, so a list of playable type strings would be a
rule the kernel never promised. Whether §1.3 found a record on the media is a
thing the port actually knows: found is the script's own `ok` back again,
`media: <type>` (`player:396`), plus where it is mounted; media the disc source
will not open stays a warning, because `media: DVD-R` on its own would read as a
promise.

**This row went on saying `the disc source is not built yet` after §1.3 landed**,
and it is worth recording why it survived: the sentence is only reachable with a
disc in the drive, and the drive was empty every time the screen was looked at.
A row that can only be read on hardware nobody has loaded is a row that goes
stale silently — the same shape as the count-and-narrative drift this document
keeps warning about, one floor down. The suite now pins both media outcomes
through the probe seam, so the next one cannot wait for a disc to be noticed.

**Five bash rows are gone and each one is gone for a reason**, not by omission:
`mpv` and `unix sockets` (there is no mpv to drive), `mpv archives` (zips are
read where they lie), `terminal` and `window size` (there is no terminal, and
the window's own arithmetic is §10's, checked every frame rather than once at
startup).

---

## 12. `-n` inspect mode

- [x] Album — artist (year), then `N tracks, M:SS, from <source>`, then a
      numbered list of fitted titles with durations (`player:3540`).
      **Four things about the layout look wrong and are kept.** `%d tracks` is
      unconditionally plural, so a single prints `1 tracks` — the picker got
      this right (§1.2) and nobody came back here. The separator between album
      and artist is an em dash and so is the `${X:-—}` fallback for all three
      fields, so a record with nothing tagged prints `— — — (—)`, which reads
      as a rule. `%2d` is the *row* rather than the track number and is two
      places wide, so a hundred-track set steps one column right from a hundred
      on. And the title is padded to exactly 52 with the duration right-aligned
      in 6 whether or not either needed it — reproduced by hand rather than
      through `Columns.fit`, because `fit` truncates with an ellipsis where
      `%6s` does not truncate at all.
- [x] The way to get the track list as plain text; a normal run draws the panel.
      It runs *after* the read and before the panel (`player:3535`), so a dry
      run does every expensive thing a real run does except put a needle down:
      a zip is unpacked in full and then torn down, and `MUTHUR_KEEP` says so
      on stderr the way the exit trap does (`player:317`).
- [x] The year shown here and the year on the panel are now the same year, from
      the same precedence (§10, D6).
      **This one had to be wired, not merely inherited.** The script has a
      single `YEAR` global that MusicBrainz overwrites (`player:2215`) and that
      both the panel and `-n` print, so they could not disagree. Here the tag
      year, the lookup and the shelf are three separate values, and `-n`
      printing `record.year` would have shown the tag year where the panel
      showed the shelf's. Both now call `HeaderBlock.year`, and `Inspect` looks
      the record up in the catalogue the same way `PanelModel` does — not to
      print the note, for which `-n` has no line, but because the shelf is one
      of the three places the year can come from.

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

**This table is no longer the only place they are written down.** `--help`
lists them too, as the script's header did (`player:45`), and D46's suite holds
the two in step: a variable the kit reads and the page does not name is a
failure, and so is a variable the page names and nothing reads. `PLAYER_ART`
has no row on the page for that second reason — there is no `MUTHUR_ART`, and
a help page that lists a switch that does not exist is worse than a short one.
The four `PLAYER_` names still honoured (`DIRS`, `WORK`, `KEEP`, `COLLECTION`)
are named there as a group, and the suite asserts that the group is complete.

---

## 14. Native, from `spec.md` — in scope, not stretch

**Nothing in this section is a port.** `player` is a bash TUI: it has no bundle,
no Dock tile, and no way to be told that ⏯ was pressed while another window was
in front. Every decision below was made for the native app under `spec.md` and
this file, and where one was arguable it is marked as such at the code. Do not
look for a line in the script to justify any of it; there is none.

- [x] Real cover art at real resolution. The sleeve is decoded at the panel's
      `displayScale` rather than at its point size, and the Archive is asked at
      `front-1200` before `front-500` (**D45**) so there is something at that
      resolution to decode. Local and embedded art were always full size (§5.1).
- [x] Media keys; Now Playing in Control Center and on the lock screen.
      `App/NowPlaying.swift` — `MPRemoteCommandCenter` for play, pause,
      play/pause, next, previous and the scrubber, and `MPNowPlayingInfoCenter`
      for what the system draws. The pushes are event-driven, not ticked: see
      the file. Verified against Control Center on two real records: the row
      carries the right track, artist, album and cover, shows ∥ while the panel
      says PLAYING and ▶ while it says PAUSED, advances the panel on ⏭, resumes
      it on ⏯, and vanishes from the list on `q` rather than leaving a record
      the app is no longer playing. The transport buttons were confirmed by
      hand.
- [ ] AirPlay and correct route handling — **unplugging headphones pauses, it
      does not blast**.
- [ ] Output sample-rate switching for hi-res material.
- [ ] Dock icon, its own Cmd-Tab identity, album art in the Dock while playing.
      **Written, and one of the three clauses seen.** `App/MUTHUR.icns` is a
      **placeholder** generated from `Theme` — the wordmark in phosphor amber on
      the CRT ground, meant to be replaced — and the app does appear in the Dock
      under it. The cover goes on `NSDockTile.contentView` rather than on
      `applicationIconImage`, so that the Dock can show the record while ⌘⇥ goes
      on showing the app (`App/DockSleeve.swift`); neither of those two has been
      looked at with a Dock on screen and a record playing, and until it has,
      this stays a box that is two-thirds of a box. Note also that *while
      playing* is read here as **while a record is on the deck** — a paused deck
      keeps its cover, because the alternative is a tile that flickers back to
      the wordmark every time you press ␣.
- [ ] ffmpeg as a *fallback* decoder only, for what AVFoundation will not take
      (notably Opus and Ogg).
- [x] Drag-scrubbing on both meters (the terminal could not do it) — §6.4, and
      the clickable keycaps (**D30**) are the same argument finished.
- [x] **`BROWSE` on the picker — a record from outside the search path.** A new
      box, and one of the few things in this document that adds a requirement
      rather than inheriting one, so it moves the denominator (see Status).
      `scan_sources` is one level down `MUTHUR_DIRS` and nothing else
      (`player:1036`), which is right nearly always and useless for the album on
      the external drive, the one two folders deep, or — since **D47** — the
      archive whose central directory would not open. The script's only answer
      is to export a different `PLAYER_DIRS` and start again, because a TUI over
      ssh has no file chooser to reach for; a window does. **The scan stays the
      default and this is the escape hatch**, not the other way round: the list
      is still what the picker opens on, and `BROWSE` is a fifth cap on the same
      row (`B`, between `RESCAN` and `QUIT`). It is `PanelModel.browse()`, which
      is also what ⌘O calls, so the menu item and the cap are one file chooser
      and not two that have to be kept agreeing; the selection then goes through
      `SourceOpener.resolve` and `open(source:kind:)` exactly as a picked row
      does, so a folder chosen here cannot behave differently from the same
      folder found by the scan. The row still fits — five caps, 59 of 69 columns
      — and `KeycapTests.fits` now measures all three legends rather than only
      the playing one, which is the thing standing between the next cap and a
      wrapped legend.
- [x] Reduce Motion and Reduce Transparency honoured — see §10. Transparency
      drops the veils; Motion has nothing to act on, because everything that
      moves on this panel is a reading and not an animation.

**Three of these are blocked on hardware and material, not on work.** They are
untouched deliberately, and each for a reason that no amount of code removes:

- **AirPlay and route handling.** The whole box is the *unplug*. A route change
  that is only ever simulated proves that the notification was subscribed to,
  which was never the doubt — the doubt is what the engine does in the tenth of
  a second after the jack comes out. Nothing was written for it, because
  something written and not pulled would be a green box over an unheard blast.
- **Output sample-rate switching.** There is no hi-res material on this machine.
  Every zip to hand is 44.1 kHz, so the code that switches would run once, do
  nothing, and be indistinguishable from code that does not switch.
- **ffmpeg for Opus and Ogg.** Same reason, one step further along: there is no
  Opus and no Ogg here to fail on. The fallback's *shape* is settled — D40 — and
  the row it lives on is §12's; what is missing is a file AVFoundation refuses.

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
forty-eight are settled. Recorded here with the answer so that a departure from
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
ever moving the needle. **D25–D33** came out of the panel — §7's offer, §10's
keycaps and widths and scroll window, and §9's autoscale, which is the one that
had to be measured before it could be decided. **D34 and D35** came out of §8:
the first answers §18.3 and is a decision *not* to improve the script, the second
is a divergence the script's own comment invites and turned out to be the
difference between reading the real catalogue and reading nothing at all. **D36**
came out of binding ⌘O, and **D37–D39** out of §11: the third place after D15 and
D21 where the port takes the better of two readings — and it is the *author's own*
better reading, in `burncd` rather than in `player` — plus one about drawing the
check in the panel's single colour, and one that declines an improvement §17 had
asked for, on the grounds that the screen you run when nothing works is the last
screen that should be allowed to hang. **D40–D45** each came out of the thing it
names: D40 out of §12, D41 out of the fixtures, D42–D44 out of the disc — the
last of them reversing the first two on the evidence of a real pressing — and
**D45** out of §14, which is the first section with no `player` behind it at
all. **D46** came out of §1.1 and is the only one here that is a *loss*: a
mechanism the script had and a compiled binary cannot, written down with what
was put in its place. **D47 and D48 are the pair that are not departures at
all**, and they are opposite shapes of that: D47 *closes* an inconsistency the
script left open — the picker's audio rule applies to folders and is suspended
for archives, because bash cannot see inside one — so the port lists fewer things
than `player` would while following `player`'s own rule more completely. D48
records a difference where there was never a decision on the other side of it:
`scale=$w:$((h*2))` carries no aspect term, so a non-square cover is a case the
script never met rather than one it settled. It closes §18.24, which was the
oldest question here that had been waiting on material.

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
MusicBrainz → tags → collection; `SHELF` stops repeating it. → §10, §18.26

*Amended once, and the amendment is the precedence.* This first read tags →
MusicBrainz → collection, first source wins. **The script does the opposite**:
`[ -n "$t" ] && YEAR="${t%%-*}"` (`player:2215`) overwrites whatever the tags put
in `YEAR` with the MusicBrainz date, so MusicBrainz is last-writer and wins
wherever it spoke. `CLAUDE.md` settles which of the two is authoritative, and it
is not this document. So: **MusicBrainz wins where it answered, tags fill in
where it did not, and the collection is still last.** Amended in place rather
than written twice, because there is only ever one rule about the year.

What is *not* changed: the collection's position at the back, and everything §10
draws. `SHELF` still carries genre and tags without the year, which is the part
of D6 that was ever a departure from the script — the script put the catalogue's
year on that line and nowhere else (`player:1725`), so a record not on the shelf
showed no year at all and one that was showed a year that had not come from the
record.

**None of this is observable yet, and that is the point of settling it now.**
MusicBrainz is asked on the CD path and a mounted audio CD carries no tags
whatsoever, so the two sources are never both present and no test can tell the
orders apart. **§1.3 is where they first can be** — a tagged rip whose disc gets
looked up, or a tagged folder that grows a disc ID. Deciding it here means §1.3
inherits a rule instead of stopping to ask for one. Nobody should read the
amended order as having been tested; it has been *chosen*, against the script,
and §1.3 is where it becomes checkable.

**D7 — picker depth. Depth 2.** The script's `maxdepth 1` was avoiding forks,
not guarding anything, and it hid any album whose tracks live in `CD1/`. The
port counts to depth 2: deep enough for a multi-disc album (`Album/CD1/track`)
but not so deep that a library root like `~/Music/Music` — whose audio is at
depth 5 via `Media.localized/Music/Artist/Album/track` — presents as a
66-track record. The *scan* for candidate folders stays one level deep — that
part is the guard. Playback still reads at any depth. → §1.2

**D8 — MU/TH/UR as an interaction conceit. Confined to diagnostics.**

`spec.md` names the diagnostics screen as the one place it would genuinely fit,
and that is exactly as far as it should go. The rule:

- [x] **Nothing stands between launching and sound.** No boot sequence, no
      dialogue, no acknowledgement to dismiss. The failure mode `spec.md` names —
      an app that makes you read before it will play a record — is the only way
      this goes wrong, and it goes wrong permanently: a joke you cannot skip is
      not a joke by the fourth listen.
      *Closed by there being nothing to point at. `main.swift` answers `--check`
      and `--help` and otherwise goes straight to `open_source`'s work
      (`player:3517`): a named record opens, `--cd` opens the disc, and anything
      else scans. The one screen between launch and sound is `LoadingView`, and
      it is a progress meter carrying `OPENING`/`READING`/`SCANNING` — the
      script's own three words (`player:1398`), not a greeting. The suite cannot
      prove a negative, so what is on record instead is that no view in `App/`
      waits on a dismissal and nothing is drawn before the source is asked for.*
- [x] Diagnostics answers in the first person, flat and declarative, the way a
      ship's computer answers a query. It reports. It does not banter, it is not
      withholding, and it never has anything to say that is not an answer.
      *Closed on the screen, and it came out narrower than the box allows.
      **`Report.verdict` is the only first-person line in the program** — `I
      CANNOT PLAY A RECORD. THE ✗ ITEMS ABOVE ARE WHY.` and its two siblings,
      which are `check_summary`'s three cases (`panel.sh:598`) said as a machine
      answering rather than as a status printed. The twelve rows above it stay in
      the third person and in the script's register: `drutil not found — CDs
      cannot be detected`, `<N> free in <dir>`. That split is the finding, not an
      accident of drafting — the verdict is the only line on the screen that is a
      **reply to a question**, and the rows are readings. A row that spoke as
      `I` would be the machine narrating its own instruments.*
- [x] Everywhere else it is a name on the chassis. In particular the playback
      failure messages stay exactly as blunt as they are — `▪ N OF M TRACKS ARE
      NO LONGER ON DISK`. They already read as a machine talking, which is
      precisely why they work, and dressing them up would put personality between
      you and the reason your record stopped.
      *Closed unchanged, which is the whole claim. `Readout.status` is still `▪`
      and a shouted clause, `die` still prints the script's own words
      (`player:3524`, `player:1114`), and the faceplate still says `PLAYING`
      rather than anything about itself. Outside `Report.verdict` the string
      `MU/TH/UR` appears only where it is the product's name: `Faceplate.badge`
      — literally a name on the chassis, in the corner of every screen — plus the
      window title, the check's heading, `usage`'s first line and the icon.*
- [x] It is a voice, not a conversation. No prompts, nothing that waits for a
      reply.
      *Closed. The verdict is a sentence the screen ends on; nothing anywhere
      asks a question or holds a key. The check screen's own legend is `RETURN`
      and `RECHECK` (§11) — two ways out and no acknowledgement — and even
      `QUIT` is unguarded on purpose (§18.25). The one modal thing in the app is
      `NSOpenPanel` under `BROWSE`/⌘O (§14), which is the system asking for a
      file and not the program asking you anything.*

**Settled by the screen existing, which is what this decision was waiting for.**
It said it was worth revisiting once the diagnostics screen could be looked at;
it has been, on this machine, and the conceit turned out to want *less* room than
was reserved for it — one line, at the bottom, where a question is being
answered. Still cheap to reverse in either direction, and there is now something
to reverse it against.

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

**D11 — `UNTAGGED`. Finished, as derived data. The notice is deliberately not
drawn.** → §18.15, §18.27, §15, §10, §17

Not as a flag: `Record.unnumberedCount` is computed from the rows whenever it is
asked, because §4 rewrites rows after §3 has read them and a remembered boolean
would still be describing the album as it arrived. The script's variable stays
in §15 as vestigial: what is being ported is the intention behind it, not the
variable.

**Amended after §17, in place.** This decision originally read "the flag looks
like the start of a notice that was never built, so build the notice", on the
argument that "3 of 12 tracks are untitled" is a different sentence from "this
album has no tags" and the panel can tell which it is looking at. That is still
true and the notice is still **not being built**, which is a decision and not an
omission — recorded here so that nobody finds the undrawn counts later and
builds it thinking it was forgotten.

Three reasons, and the first is decisive:

1. **The script has no such notice.** `UNTAGGED=1` (`player:1451`) is set and
   then only ever read to pick a sort key. There is nothing to port.
2. **It would need three inventions** — where the line goes, what it says, and
   the threshold at which it says it — and none is derivable from anything.
   It would be the first line in the program with no ancestor.
3. **It contradicts §17.** The "no metadata at all" box is explicit that artist
   and year stay empty and the panel simply has less on it: no placeholder, no
   "Unknown Artist". A row that appears only on thin records is a placeholder
   wearing a number.

**The counting half stays and earns its keep**: `unnumberedCount` is what feeds
9999 into the sort (`player:1451`, `player:1511`), and `unreadableCount` is what
lets §6.3 tell *missing* from *unreadable* in the sentence it stops on. Both are
measured, both are tested, and neither is drawn on its own. If a notice is ever
wanted, this is the decision to reopen — not a gap to fill in.

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

**D26 — the room under the last track. Filled with a run-out.** → §10

`np_frame`'s track loop stops at the last track and the meters go on the next
line, so on a short record everything below the list is ground (`player:2341`).
That is faithful and it is right *for a terminal*, because a terminal window **is**
the terminal — the empty rows under the frame are the shell's own, and reading
them as nothing is reading them correctly.

An app window is not the terminal. Its bottom edge belongs to the instrument, and
an instrument that stops halfway down its own chassis leaves a void under the
keycaps rather than a floor. So the room is filled: the record's lead-out, a
tightening spiral of grooves ending on the dead groove, drawn dim enough to be
surface and not data. **The object being built is a machine that reaches the
bottom of its own case**, and the run-out is what a record does with the space
after the music for exactly the same reason.

`runout` is the default and this is a **deliberate divergence from
`player:2341`**, flagged in §10. `MUTHUR_COMPOSITION=deck` restores the script's
behaviour, kept because the divergence is a taste call and taste calls should be
answerable at runtime.

The grooves are not evenly spaced. Even spacing reads as a table with nothing in
it; what says *lead-out* is the pitch closing as the spiral runs in. The first
attempt stepped the pitch down by a constant factor per groove, which tightens in
principle and is invisible over the height this field actually gets — the eye
read it as regular. They are placed against the height instead, the gap falling
away as `(1 − t)^p`, so the closing is visible at whatever size the window is.

**D27 — the wordmark. Driven onto the tube, not screwed to the front of it.**
→ §10

Two were built: the character generator's own dots at twice the pitch, and a
stamped metal nameplate with the name cut into it and lit from above. The plate
lost. A plate does not glow and cannot burn in, because it is not part of the
display — it stays factory-fresh while everything around it ages, and on a screen
it reads as a chip stuck on the glass rather than as something the machine drew.

The dots are doing something type cannot. **MU/TH/UR is the thing that is
*running*, and the panel is what it says** — so the name has to be made of the
same light as the track titles, and has to get old with them. This is also why it
is drawn from shapes and never imported as a picture.

Note that this is the one place the dots win. Everywhere else they lost, which is
D28's other half.

**D28 — the glass is the deep one and the text is the bright one.** → §10, §5.4

Two complete looks were built and each was internally consistent and wrong in one
half. The deep tube had the better glass — real curvature, a heavy vignette,
rounded corners, sheen — and took the lettering down into the murk with it. The
console had the better text — bright, crisp, legible at a glance — and a glass too
timid to be worth having.

They were never a package. The veils are drawn **over** the panel and the levels
are drawn **into** it, so there is nothing coupling the depth of the glass to the
brightness of the type. What ships is the half of each that was right: the deep
tube's optics over the console's lettering.

The mechanism that makes this literally true is `Theme.vignetteClear` — the
vignette stays completely clear out to 0.62 of its radius, so the fall-off starts
*outside* the column the panel is set in. The corners go as deep as the tube look
wanted and the track list pays nothing for it. **The glass goes around the text,
not on it.** Readability wins every time, because this has to survive an hour of
being looked at.

The same call settles the character generator: **type is the default for chrome
and readouts.** Monospaced type is already a readout on a character grid — the
column arithmetic was written for it — and at 13pt it keeps the one thing seven
segments give away, a `1` that cannot be mistaken for anything else. The dotted
lettering and the segmented figures are the period-correct answer and they cost
legibility, which is a trade to be looked at rather than assumed, so they stay
behind `MUTHUR_LETTERING=matrix` and `MUTHUR_NUMERALS=segment`.

Nothing downstream cares which is on. Both are laid on the same cell and **both
are drawn in a `Canvas`**, so the columns land in the same place and neither can
be truncated — which was the point of dotting the faceplate in the first place,
and it turns out the guarantee was bought by drawing, not by the dots (§10,
`FaceplateView`).

**D29 — the curvature is the glass's, not the text's.** → §10

A bowed raster is a property of the tube: the phosphor is on a curved surface, so
the *light* bends. Bending the layout with it — running the panel through a
distortion so the lines themselves bow — would mean the character grid no longer
lands on the character grid, and every column arithmetic in §10 becomes a lie
about where things are. It also makes text at the edges permanently harder to
read, at every window size, forever.

So `Theme.bow` is small even at the deep setting, and it is applied to the raster
and the veils. **The glass curves; the words do not.**

**D30 — the keycaps are switches, and one place decides what they mean.**
→ §10, §6.4, §14

§6.4 had already put the meters and the track list under the pointer, which left
the legend as the one drawn control on the panel that did nothing when pushed.
That is worse than not drawing it: a picture of a keyboard is documentation, but
a *lit keycap on a chassis* is a switch, and a switch that does not answer reads
as broken rather than as decoration.

Three calls inside it.

**The rockers.** `←→` and `↑↓` are two glyphs on one plate, which is a rocker and
not a button, so the plate is split in the order the glyphs are drawn and the end
you push is the direction you get. `Readout.Cap` carries one press or two, and the
view divides the plate by how many there are — the geometry is not written down
twice.

**What repeats.** The two rockers, and nothing else. Holding `←→` to run through
a track and `↑↓` to run down the list is the entire point of them being rockers,
and the keyboard already does it (`onKeyPress(phases: [.down, .repeat])`). The
single-throw caps fire once: a held `S` toggling shuffle twenty times a second is
not a faster way of doing anything, it is a coin being flipped. The repeat delay
and interval are `NSEvent`'s, asked for rather than invented, because a cap
repeating at some rate of this panel's own choosing would be a *different* switch
from the key it depicts and the whole claim is that it is the same one.

**One dispatcher.** `PanelView.perform(_:shift:)` is the only thing that knows
what a press means, and both the key and the drawn cap go through it. A binding
added to one is added to both or to neither — which is the only arrangement in
which a legend can be trusted to still be true a year from now. Shift is carried
through it, so a shift-click on `←→` seeks the thirty seconds a shift-arrow does:
the cap is the key, including the parts of the key that are not printed on it.

The cap **lights** when pressed rather than sinking, one step up the plate and one
up the ink, both off the panel's own ramp — an illuminated pushbutton says the
contact is made by drawing more current, and the phosphor rule holds: it does not
change colour, it runs harder.

`Q` is now one click from quitting mid-record, where before it was one keystroke.
A pointer can land somewhere a finger cannot, so this is not quite the same
hazard — flagged as **§18.25** rather than quietly guarded, because putting a
confirmation on a one-key quit would be improving the script rather than porting
it.

**D31 — the scroll window's fourth line. Added.** → §18.22, §6, §10

`np_scroll` has three lines (`player:2904`): a cursor above the window pulls the
top up to it, a cursor below pushes the bottom down, a cursor inside moves
nothing. There is no fourth line pulling the top back up when the window has more
room than it needs, so a terminal made taller draws a short list with blank space
under it until the cursor next moves.

**The environment changed, not the script's judgement.** A `SIGWINCH` is a rare
event and the next arrow key fixes it, so in bash this is nearly invisible. Here
the window is dragged by its corner and the list re-lays out continuously while
it is being dragged — the same three lines are asked hundreds of times where bash
was asked twice, and the blank space stops being a stale frame and becomes the
thing you are looking at while you drag.

The fourth line is one `if`, it only ever shrinks `top`, and it only fires when
the list cannot fill the window from where it is. It is therefore silent in every
case bash was actually in, which is the test a divergence like this has to pass:
it is not a different judgement, it is the same judgement asked a question the
script was never asked. `Cursor.reflow` is where it lives and two tests hold both
halves down.

**D32 — the two width divergences. The port is right, and stays.** → §18.23, §10

`cwidth` (`panel.sh:274`) decides how many columns a character occupies, and the
port disagrees with it twice. Conjoining jamo `U+1160–U+11FF` render as part of
the preceding syllable; bash counts them one column each and the port counts them
zero, as it does every other combining mark. And bash's fullwidth-Latin test is a
bracket comparison against collation order, which on this machine puts `Ａ-Ｚ`
outside the range its own comment says is wide; the port takes the comment.

Both are the port being **right** rather than merely different, which is exactly
the case `CLAUDE.md` says to flag rather than quietly fix — so it was flagged, and
this is the answer. **Do not port a measurement bug.** A width function exists to
stop a row overrunning, and a `cwidth` that measures a Hangul title longer than it
draws fails at the one job it has. `PanelAgainstBashTests` checks the port against
the script everywhere else and carries these two as named exceptions, so the
divergence is a decision and cannot drift back into an accident.

**D33 — the scale starts at the ceiling, and how long it stays there is fitted
to the script.** → §18.21, §9

The autoscale is the one thing in §9 that could not be ported as it stood: the
script has the whole track before it draws a frame and the port does not.
Measured, that cost more than the entry assumed — 27.9 eighths of a 40-eighth
column over the opening five seconds of a track that fades in, peaking at the
whole column, and **wrong upward on every track tried**, because a scale that has
not yet heard the loud part puts both its percentiles too low and maps everything
above where it belongs.

Three changes, and they answer three separate questions: *carry or not*, *where
the prior sits*, and *how long it lasts*.

**The scales live across a track change.** The previous track is by far the best
evidence available about this one — same record, same room, same mastering — and
the script can only afford to start each track cold because it has the future.
`Analyser.newTrack` now clears the columns alone; `Analyser.newRecord` is where
the scales go, because another record's scale is another record's scale.
Measured, it takes the openings from 11.3, 16.1 and 21.0 eighths out to 4.1, 6.5
and 6.8. It does nothing at all for track one.

**The prior sits at full scale.** A band that has heard nothing is claimed to
have been **at 0 dBFS all along** — a point mass at the top bin, not a flat
spread. Both anchors start at the ceiling and the scale descends onto the record
rather than rising to meet it. Measured against the alternatives at one fixed
mass, so that only the shape varied (first five seconds, mean / peak / signed,
positive being the port drawing taller):

| prior on Second Hand News | result |
| --- | --- |
| none | 27.9 / 40 / **+27.9** |
| flat, *anything is possible* | 14.0 / 27 / **+14.0** |
| full scale, weight 1 | 27.2 / 40 / **+27.2** |
| full scale, same mass as flat | 0.0 / 4 / **−0.0** |

The flat prior halves the error and cannot turn it over, for a reason that is
arithmetic rather than taste: a scale ninety decibels wide still maps a −60 dBFS
fade-in a third of the way up. Only raising the **bottom** anchor puts a fade-in
under the floor. And weight one is no prior at all — it dilutes inside a tenth of
a second.

**The weight is a duration, and that is the second number this was supposed to
avoid.** It was recorded here as "not a second number", on the grounds that the
mass was inherited from the flat control rather than chosen. That was wrong, and
the algebra says so plainly: the bottom anchor comes off the seed once
`0.25(N + w) ≤ N` and the top once `0.90(N + w) ≤ N`, so at ten windows a second
the weight *is* a length of time. At the flat mass that is five seconds of dark
panel and two and three-quarter minutes of pinned ceiling. A warm-up window was
rejected at the top of §18.21 for needing an invented length; picking a mass
picked a length anyway. **The warm-up window and the point-mass prior are the
same number in different clothes**, and it could not have been avoided.

**So it is fitted rather than invented.** The objective, stated before the sweep
and unchanged after: the mean absolute difference in percentage points between
the port's lit-band curve and the script's, over seconds 0–9, across the first
four sides of *Rumours*, each decoded **cold** — because the scales carry only
within a sitting, so any track can be the one you dropped the needle on. Forty
points, no weighting between tracks, no tie-breaks. Swept 0 to 400.

| weight | 0 | 25 | 45 | **55** | 70 | 100 | 181 | 400 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| mean \|Δ lit%\| | 34.0 | 29.7 | 27.8 | **27.2** | 28.5 | 28.4 | 34.5 | 65.0 |

**55**, and the basin is broad: everything from 40 to 105 scores within 1.6
points of the minimum, so the value is not balanced on a knife edge and a change
of a few either way is not a regression. The two ends are the two failures, and
they score almost identically — 34.0 for inventing a song, 34.5 for erasing one.

**This is fitting, not tuning, and the difference is the target.** The objective
is the script's own behaviour, and `CLAUDE.md` makes the script the authority
where anything conflicts with it. No part of the sweep was scored against how the
panel looks to anyone. It should not be re-litigated as taste.

**What it does**, as the percentage of the sixteen bands drawing anything, second
by second, cold — the script, the fitted weight, and the heavy prior it replaces:

| track | | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Second Hand News | script | 0 | 0 | 0 | 0 | 2 | 24 | 100 | 100 | 98 |
| | **×55** | 0 | 30 | 100 | 100 | 100 | 100 | 100 | 100 | 100 |
| | ×181 | 0 | 0 | 0 | 0 | 0 | 10 | 100 | 100 | 100 |
| Dreams | script | 45 | 75 | 86 | 59 | 58 | 82 | 78 | 52 | 82 |
| | **×55** | 0 | 18 | 84 | 80 | 92 | 96 | 99 | 94 | 98 |
| | ×181 | 0 | 0 | 0 | 0 | 0 | 3 | 19 | 44 | 89 |
| Never Going Back Again | script | 36 | 66 | 96 | 84 | 98 | 90 | 91 | 95 | 100 |
| | **×55** | 0 | 28 | 98 | 100 | 100 | 96 | 99 | 100 | 100 |
| | ×181 | 0 | 0 | 0 | 0 | 0 | 8 | 90 | 96 | 100 |
| Don't Stop | script | 42 | 34 | 48 | 64 | 78 | 56 | 69 | 92 | 97 |
| | **×55** | 0 | 26 | 96 | 100 | 100 | 100 | 100 | 100 | 100 |
| | ×181 | 0 | 0 | 0 | 0 | 0 | 7 | 96 | 100 | 100 |

**One dark second at the top of a record, not five**, and every side is past four
fifths of its bands by the third. Both ends are pinned by
`neitherBlankNorFlooded` so neither failure can return: nothing may open above
half its bands lit, and nothing may still be under four fifths at two seconds.

**And the eighths, which the fit did not optimise**, so they are a report rather
than a target. Cold, first five seconds:

| track | none | **×55** | ×181 |
| --- | --- | --- | --- |
| Second Hand News | 27.9 / 40 / +27.9 | **9.4 / 21 / +9.4** | 0.0 / 4 / −0.0 |
| Dreams | 11.3 / 40 / +10.9 | **10.2 / 40 / −8.3** | 13.0 / 40 / −13.0 |
| Never Going Back Again | 16.1 / 40 / +16.1 | **7.0 / 35 / −5.8** | 12.7 / 40 / −12.7 |
| Don't Stop | 21.0 / 40 / +21.0 | **5.0 / 24 / +2.5** | 3.8 / 30 / −3.8 |

**The direction claim is gone and D33 no longer makes one.** The fitted weight
reads *tall* over the fade-in — +9.4 eighths, peaking at 21 — where the heavy
prior read nothing. That is the trade, taken deliberately: one fade-in reading
just over a row tall beats three loud openings reading blank, and the failure
that started this was a peak of forty over a track that had not begun. No cold
column reaches the top row from nothing, and `nothingRunsTheColumn` holds that.

**The steady-state cost is a known permanent divergence, not a cost that is going
to be addressed.** The scale is made of the record rather than of the track, so a
track quieter than its neighbours reads low for its whole length. Measured over
55–60 s on all four sides: **carried**, against **scaled by itself** — a live
scale started fresh on that track, prior and all, which is exactly what the app
does when you drop the needle there.

| a minute in, eighths | carried | by itself | what the carry costs |
| --- | --- | --- | --- |
| Second Hand News | 3.2 | 3.2 | — (it *is* the first side) |
| Dreams | 5.4 | 3.1 | +2.3 |
| Never Going Back Again | 7.2 | 2.9 | +4.3 |
| Don't Stop | 4.2 | 2.0 | +2.2 |

**The carry costs less than this entry used to imply.** 7.2 is the whole
divergence, not the price of carrying: 2.9 of it is there whether anything
carried or not, because a live scale a minute in still has not heard the rest of
the track and the script has. The carry's own share is **4.3 eighths on the worst
side and 2.3 across the three that carry** — half a row. That is the number to
argue with, if anyone ever does. Nobody should reopen this looking for a fix:
there isn't one coming. `steadyStateCost` computes both columns and holds them.

The first side is the check on the arithmetic. With nothing to carry the two
columns have to be the same figure, and they are, to the last digit.

**The fitted prior is not quite spent at a minute on a quiet track.** By itself
with *no* prior at all Never Going Back Again reads 1.7 rather than 2.9: the top
anchor comes off the seed at 9w windows, which at w = 55 is 49.5 s, so a track
this quiet still carries a trace of the prior into the 55–60 s bucket. A fifth of
a row, and it is part of the fitted weight's price rather than a fault in it.

*(Two corrections to earlier revisions of this entry, both of the same kind —
a number attributed to the carry that belonged to the prior. The first put the
figure at 7.7 and blamed the carry for all of it; that was measured under the
heavy prior, where the top anchor is still pinned a minute in, so a third of it
was the prior. The second is that 2.9 was right but unsourced, and a per-track
baseline that nothing computes is a number waiting to drift. It is now measured
rather than quoted.)*

Per-record scaling does show something the script hides — the dynamics *between*
tracks, a quiet track reading quiet next to a loud one instead of every track
being renormalised to fill its own column. **That is not the justification**, and
it is written here only so it is not mistaken for one. Preferring it because it
is better would be improving the script, which is not what a port does. The
justification is narrower and it is the whole of it: of two divergences that
could not both be avoided, this is the cheaper.

The *arithmetic* — the two anchors, the 0.60, the 6 dB minimum span — is
unchanged, and the tests that hold it down still ask it of an unseeded scale,
because the sum is the script's and only the starting point moved.

**D34 — two rows for the same record: the last one still wins.** → §18.3, §8

`collection_lookup` accepts more than one hit whenever an album artist is present
(`player:1706`) while the awk body overwrites its captured fields on every match
(`player:1703`), so the later row is the one you get and nothing says there were
two. §18.3 asked whether to prefer the first or refuse the ambiguity the way the
no-artist path already does. **Ported as it stands.**

Refusing is the tempting one and it is wrong here, because the two ambiguities
are not the same ambiguity. The no-artist path refuses because it has *nothing
left to go on* — two records called `Greatest Hits` and no artist is a coin toss,
and a coin toss that annotates the wrong record is worse than no annotation.
Duplicate artist+title rows are a different thing: the catalogue has the same
record in it twice, which is a data entry mistake in a file this port does not
own and is not allowed to write to. Refusing would make §8 go silent on a record
that *is* on the shelf, which is the one failure mode the section is built to
avoid — and it would go silent for a reason the panel cannot show you, since
"nothing happens" is also what not being in the catalogue looks like.

Preferring the first is the same amount of arbitrary as preferring the last and
costs a divergence to get it. So: last wins, and it is a **test rather than an
accident** —
`twoRowsMatchingBothTitleAndArtistTakeTheLast`. Arbitrary in a way you can
predict is worth more here than arbitrary twice, and a rule that read the same
catalogue on two machines and answered differently would be worse than either.

**D35 — the catalogue is read as one stream, not a line at a time.** → §8

`csvsplit` is handed a single line by awk, and `player:1651` says outright that
a quoted field containing a newline would defeat it and that none of the ways
this catalogue is produced can make one — an acknowledged gap rather than a
judgement. The port walks the whole file instead. The flag that decides whether a
comma is a separator is the same flag that decides whether a newline ends the
record, so reading it as a stream **costs nothing and is the shorter thing to
write in Swift anyway**. On every file the script parses correctly the two agree
field for field; the only file they disagree about is one the script's own
comment says it cannot read.

Two consequences, both wanted. A newline that arrives inside a field is
**flattened to a space** along with the tab the script already flattens
(`player:1712`) — the panel draws these on a grid it works to keep square, so
this is the same reason the tab goes, applied to a character the script could
never have received. And line endings: **LF, CRLF and a bare CR all end a
record.** The real catalogue is a CRLF file — it is written by a spreadsheet —
and awk splits on `\n` alone, so the script leaves a `\r` on the end of every
record's last field, which is `Barcode`, a column it never reads. It gets away
with it by accident. The port cannot: `"\r\n"` is a **single `Character`** in
Swift rather than two, so a walk watching only for `"\n"` reads all 248 rows as
one record and the catalogue silently matches nothing. That is exactly what it
did until `crlfEndsARecordWithoutLeavingACarriageReturn` was written, and it is
why the material tier of §8 reads the real file rather than a fixture: every
rules-tier test passed on LF strings while the live catalogue found nothing at
all.

**D36 — the empty panel is a port invention, and ⌘O is its way out.** → §1.2, §10

The script never has a panel with no record in it. `pick_source` **dies where it
stands** when the scan found nothing — `die "nothing to play. Put an album in
${PLAYER_DIRS:-~/Music or ~/Downloads}, or a CD in the drive"` (`player:1114`) —
and **exits 0** when the user walks away from the picker (`screen_off; exit 0`,
`player:3532`). `open_source` runs before a frame is drawn (`player:3535`). It
either picks or it dies; there is no third state and therefore nothing for a
third state to say.

**A window cannot die on the user like that.** Launched from the Dock with an
empty `~/Music`, this app has to stay on screen and account for itself, so
`EmptyPanelView` exists here and nowhere in the original. It is marked as an
invention in its own comment rather than left looking like parity.

Having invented the state, the port owes it an exit — which is why this is
settled by **binding the key rather than rewording the line**. `File ▸ Open
Record…` carries ⌘O and opens a folder or a zip through `SourceOpener.resolve`;
anything else is refused into `model.die` in the panel's own voice, the same
words `player:3524` uses. Rewording would have made the faceplate honest and the
panel a dead end, which is the worse of the two, and the keystroke the empty
panel already named is the one a Mac user would have reached for regardless.

**D37 — `drutil`'s `Type:` line is read `burncd`'s way, not `player`'s.** → §11,
§1.3

`player:396` takes the media type with `awk -F: '/Type:/ { print $2; exit }'`.
On a colon split, `$2` is everything between the first colon and the *second* —
and `drutil` packs two columns onto that line, so on a drive with a disc in it
the field is `CD-ROM       Name` and the script prints `media: CD-ROM Name`. The
empty-bay test has the same shape of hole: `[ -n "$v" ]` (`player:397`) cannot
catch `No Media Inserted`, because that is a perfectly good non-empty string.

**This is not the port second-guessing the author.** `burncd` is the same author
reading the same command's output and getting it right, with the trap written
down beside the fix: *"drutil packs two columns onto the Type line … so take the
first word after the label and leave the rest of the row"* (`burncd:322`), then
`sed -n 's/.*Type:[[:space:]]*\([^[:space:]]*\).*/\1/p'` (`burncd:324`), and a
case-insensitive `no media` test on the whole status (`burncd:319`). Where two
implementations by one author disagree, the later one wins — particularly the
one that carries its own reasoning. `Diagnostics.mediaType` is `burncd`'s.

Found by a test that expected the type and got `DVD-R\t  Name: /dev/disk4`. §1.3
inherits this when it arrives; nothing in `cd-collection` is touched.

**D38 — the check screen is drawn in one colour.** → §11, §10

`ck` marks its rows in three hues — `✓` green, `!` yellow, `✗` red
(`panel.sh:588`–`panel.sh:591`). This panel is an amber phosphor and §10's rule
is already settled: *"one colour throughout, running brighter toward white in the
core — a brighter character is the same phosphor harder."* Three hues would be
the one place the whole screen breaks its own rule, and it would break it on the
screen that exists to be trusted.

So the marks climb the panel's own ramp instead of crossing it: `✓` sits back in
the chassis (`amber(.deep)`), `!` is lit (`amber(.amber)`), `✗` is lit hard
(`amber(.lit)`). Monotone, and it runs the same direction the trouble does —
which is what the hues were doing in the terminal anyway. The detail beside an
`ok` row is `Theme.dim` and beside a `warn` or `fail` row is `Theme.text`, so the
lines you have to read are the bright ones. The verdict is the single amber line,
which is D8's boundary and not a fourth mark.

One consequence: **the detail wraps rather than truncating.** The panel is 69
columns whatever the window does, which leaves 44 after the margin, the mark and
the twenty-column label — and `no cdrtools — discs fall back to MusicBrainz or
numbers` is fifty-four. §11 requires every check to carry a fix, so a line too
wide turns over onto a second row indented to the detail column (`Columns.wrap`).
`--check` on a terminal wraps nothing, because a terminal is as wide as it is.

**D39 — the check does not go to the network.** → §11, §17, §4.1

§17 asks for MusicBrainz *reachability* rather than bash's test for `curl` and
`jq` (`player:410`), on the fair argument that the native stack could actually
ask. It does not, and this settles it in the negative.

`--check` is the thing you run when nothing works, and *when nothing works* very
often means a captive portal, a VPN half up, or DNS that will take thirty seconds
to admit defeat. A diagnostic that hangs is worse than one that is candid about
what it has not tried. The row reports what the lookup will do and when —
`URLSession — no curl, no jq. Reached when a disc needs naming, never before` —
and reports the one thing that is both knowable and locally true, which is
whether the lookup has been switched off. §4.1's own failure paths already say
what an unreachable MusicBrainz costs, at the moment it costs it.

**D40 — the ffmpeg question lives on the `playback` row, and asks after both
binaries.** → §11, §17

Bash asked about `ffmpeg` on its `analyser` row and was explicit about why:
"ffmpeg itself, not ffprobe: the analyser measures a track's spectrum ahead of
playing it" (`player:367`), warning `no ffmpeg — the columns fall back to a
pattern` (`player:374`). §9 taps the engine instead, so that row lost its
subject — and **the binary went with it**. Nothing in `--check` asked after
`ffmpeg` any more, while `AudioSourceOpener` still refused to open an Opus
without it. A machine with `ffprobe` and no `ffmpeg` reported `ok` on every row
and then would not play four formats.

The question goes to `playback` because that is the row whose subject is what
plays the audio — the row bash's hard-failing `mpv` check (`player:349`) became.
The engine itself cannot fail there, since it ships with the machine, but half
of what plays the audio is still a binary.

It asks after **both** `ffmpeg` and `ffprobe`, and names whichever is missing.
The fallback needs both — `ffprobe` to find out what is in the file, `ffmpeg` to
decode it — and `open` refuses on either (`AudioSource.swift:78`). A row that
only asked after `ffmpeg` would be the same hole one binary along.

Rejected: leaving it on `analyser`. The row would have been asking after a
binary it no longer uses to explain a consequence it no longer has, and the
sentence it printed would have been false in both halves. The `analyser` row
now depends on nothing, and there is a test that says so.

The four formats are named in one place — `AudioSourceOpener.fallbackOrder`, an
array rather than a set precisely because §11 reads them out to a person and a
set would name them in a different order every launch.

**D41 — a fixture may skip for what is absent. It may not go quiet about what is
there.** → §3.1, §6, §19

The material tier is full of skips and stays that way. Six §9 autoscale tests and
two in §3 want `Rumours`; §8's catalogue tests want the CSV; §1's opener wants a
music library; §3's zip-name test wants any zip at all; §19's five want a disc
through `MUTHUR_TEST_TOC` and friends; §9's ffmpeg comparison, §17's cross-decoder
seam and the bash panel tests want a binary that may not be installed. **All of
those are correct and none of them changes.** A fresh clone should be green rather
than red about somebody else's record collection, somebody else's Homebrew, or a
disc nobody has. If the thing is not there, the test cannot run, and saying so is
honest.

The rule is about a narrower and nastier case: **a fixture that stops covering
its case while the material it needs is still on the machine.** That is not
absence, it is a silent loss of coverage, and it has now happened twice.

- **Position picked the wrong file.** `audioZips().first` chose §3.1's
  untagged-rip fixture. On 26 August a tagged FLAC album landed in the zip
  directory, sorted ahead of the AIFF rip, and four assertions about the 9999
  path went red; later the same day that album was moved away and they went green
  again. Nothing about the program changed in either direction, and the rip the
  test was written against was on the machine the whole time.
- **A cached empty cut stood in for music.** The same drift on 24 August broke
  §6's seam fixture — a FLAC album cannot be cut with `-c:a copy` into an AIFF
  container, so ffmpeg left the zero-byte file `-y` had opened and the fixture
  returned `nil`. The two tests were `.enabled(if: seam != nil)`, so they simply
  stopped running. They are the strongest claims §6 makes — sample-for-sample
  identity across a real join, and no step at it — and the suite reported green
  without them for two days. Worse, `exists()` would have handed that zero-byte
  file back for ever after as though it were music.

So, three things, and only the third is new law:

1. **Fixtures hunt by criterion, never by position.** `untaggedZippedAlbum()`
   looks for an album with no title, album or track tag;
   `continuousSeam()` for two or more uncompressed tracks. The alphabet is not a
   specification.
2. **A cached artefact is checked for content, not existence.** `hasBytes`, not
   `exists`.
3. **When the material is present and the hunt comes back empty, that is a
   failure that names what it wanted** — not a skip. Audio in the zip directory
   and no untagged rip in it means the rip is gone or has been through a tagger,
   and somebody has to know. Three tests do this, and the message tells you what
   to put back and that `MUTHUR_TEST_ZIPS` will redirect them.

**The ffmpeg case is decided as a skip**, which is where the contradiction was.
`continuousSeam()` needs `ffmpeg` and the tag probe needs `ffprobe`, and for one
turn those two absences made three tests fail while three other sites in the same
suite skipped for exactly the same missing binary. A missing tool cannot be both.
It is absence, it goes with `Rumours` and the drive, and `canHuntZipFixtures`
gates all three tests on the binaries **and** on there being any audio zip to look
through — so a bare machine skips, and only a furnished one can fail.

**D42 — the shipping app reads the table of contents with `cdrecord -toc`.
libdiscid stays the oracle. — REVERSED by D44 on the first real disc. The
reasoning is kept below because it is what got tested.** → §4.3, §18.18

§18.18 asked which of the two routes survives into the app, and the answer is
the one that is already there. Both produce a `TableOfContents` and everything
downstream of that is settled, so this is decided entirely on what it costs to
have in the repository.

`discid_read()` costs a `systemLibrary` target in `Package.swift`, and with it a
clone that does not compile until somebody has run `brew install libdiscid`.
Every other outside tool this program uses is optional at *runtime* and invisible
at build time — `command -v … || return 1` is the first line of both `cd_text`
and `mb_discid`, and §11's whole job is to report on what is missing rather than
to require it. A build dependency is a different kind of thing, and the disc
path is not where this program should acquire its first one.

Against that, the case for libdiscid was that it removes a text-parsing step
from the one input the fingerprint is computed from. **D15 already answers
that**: the disc ID is computed here, in Swift, and libdiscid checks it as an
oracle. The parse is not unexamined — it is examined by the reference
implementation, which is the strongest position the port could be in and is
strictly better than trusting either alone. Keeping libdiscid at test time keeps
that, and keeps `swift build` working on a bare clone.

`cdrecord` is also already spoken here: §4.2's CD-Text fallback runs it, and the
`drutil`-first ordering §1.3 carries covers it either way, since libdiscid opens
the device exclusively too (`burncd:278`).

**Held open on one condition.** §19 steps 4 and 5 put `cdrecord -toc` and
`discid_read()` side by side on a real disc for the first time. If the two
disagree there, that is evidence this decision was taken without, and it gets
retaken. Agreement is what this assumes and what has not yet been observed.

**The condition fired. See D44, which reverses this.**

**D43 — `cd_text`'s fallback asks the parser, not the capture. A deliberate
divergence.** → §4.2, §17, §18.28

The script decides whether to try `cdrecord` by asking whether cdda2wav's
capture mentions a title at all (`player:2073`). The *reasoning* behind that is
right and is kept: the question is not whether cdda2wav exited cleanly, because
on a disc with no CD-Text it exits however it likes. The question is whether it
printed any titles.

What the script cannot do is ask that precisely. `2>&1` has already folded
stderr into the same string, and the verbose keyword being passed is literally
`titles` — which tools of this vintage echo back in a usage banner. So an
unhappy cdda2wav satisfies the test that exists to notice it is unhappy, the
fallback is skipped, and a machine with a perfectly good `cdrecord` silently
never asks it. The disc then degrades exactly as though it had no CD-Text, which
is why this has never looked like anything.

`DriveCDText.wantsFallback` asks `CDTextParser.parse(capture).isEmpty` instead —
the parser that is going to read the capture anyway. Put that way the divergence
is provably confined to the fault:

| capture | `qgrep -i 'title'` | `parse(…).isEmpty` |
| --- | --- | --- |
| real `Album title:` / `Track N title:` lines | no fallback | no fallback — **same** |
| blank, or never says `title` | fallback | fallback — **same** |
| error text mentioning `titles` | **no fallback** | fallback — **differs** |

`isEmpty` and not "no *track* titles", which would have been the obvious
alternative: an album title on its own goes on suppressing the fallback, exactly
as the grep does. Aligning the gate with the condition `readCDText` actually
succeeds on is a defensible second change and it is not this one. This entry
earns one divergence and takes one.

Two tests hold the line — one asserting the three shapes where the port and the
script agree, so the fourth is known to be the only difference, and one on a
usage banner that satisfies the script's grep and not this. §19 step 8 is where
it meets a real tool.

**D44 — the table of contents comes off the mount, not off the device:
`/Volumes/…/.TOC.plist`. This reverses D42.** → §4.3, §18.18

D42's condition fired on the first disc that was ever put in the drive, and it
fired harder than the condition anticipated. §19 step 4 could not be carried out
at all.

**What a real disc showed.** With an audio CD mounted at `/Volumes/Deluxe`:

- `cdrecord -checkdrive dev=…` exits **255** on all six device nodes
  `OpticalDrive.detect()` walks.
- `cdrecord dev=… -toc` exits **255** and prints no `track:` lines at all.
- `cdda2wav dev=… -J -v titles` exits **1**.
- `discid_read()` reads the same disc, repeatedly, at exit 0, as an ordinary
  user, with the disc still mounted.
- `drutil status` is unaffected throughout, which is consistent with the
  `burncd:278` ordering rather than a counter-example to it: those exclusive
  opens *failed*, so they never took the media away.

The cause is `diskarbitrationd`. It holds a mounted audio CD, and cdrtools
insists on an exclusive SCSI open it therefore cannot get. **`burncd` is not a
counter-example either** — it calls `cdrecord` bare, with no `sudo`, and works
because it burns *blank* discs, which `diskarbitrationd` never mounts. Nothing
in the reference implementation ever asked cdrtools to read a disc that macOS
had already mounted, so nothing in it could have shown this.

This is not a degraded corner to be handled. An audio CD on macOS is *always*
mounted, so `cdrecord -toc` is not a route that usually works and sometimes does
not — on this platform it is a route that never works, for every disc anyone
would want to play.

**The third route, which §18.18 never considered.** When macOS mounts an audio
CD, cddafs writes the disc's whole table of contents to `.TOC.plist` at the root
of the volume: `First Track`, `Last Track`, `Leadout Block`, and a `Start Block`
per track, in TOC form with the pre-gap already on them. It costs nothing —
no build dependency, no `Package.swift` target, no tool to locate, no device to
open, and therefore no interaction with the `drutil`-first ordering at all. And
it is readable *because* the disc is mounted, which is the same fact that makes
the other two routes impossible.

So D42's cost argument survives its own reversal: the reason not to take
libdiscid as a build dependency was that a fresh clone should still compile, and
D44 pays even less than D42 did. libdiscid remains exactly what D15 made it —
the oracle, at test time, over `Scripts/discid-oracle.c`.

**Checked, not assumed.** On the disc in the drive, `.TOC.plist` yields

    1 13 241195 150 20598 34465 52830 74545 95468 119415 138775 145965 157710
    175460 194835 213178

which is `discid_read()`'s own `toc` line for that disc, field for field, and
`rY66UjjiuCdVtE8hXkJ2Y6mLVZQ-` out of §4.3's arithmetic either way. That is the
comparison D42 was held open on, finally made, by the pair of readers that can
both actually run.

**Held open on one condition.** The disc this was proved on is a plain
single-session audio CD. The enhanced-CD rule — first session only, including
that session's own lead-out — is asserted against a constructed plist and not
against a pressing. §19 step 6 is where a hybrid disc would test it, and a
disagreement with libdiscid there is a fault in `VolumeTOC.parse`, not a reason
to revisit D44.

**`cdrecord -toc` is not deleted.** `CDRecordTOC.parse` and
`DriveTableOfContents` stay: they are tested, they are the script's own route,
and an unmounted disc — one `diskarbitrationd` has released, or a drive on some
other platform — is exactly what they are for. They are simply no longer what
§1.3 reaches for first.

**D45 — the sleeve is asked for at `front-1200`, and only then at `front-500`.**
→ §5, §5.1, §14

`player:1916` asks for exactly one size:

    "https://coverartarchive.org/release/$id/front-500" 2>/dev/null

500 px is not a judgement about covers. It is a judgement about *terminals*:
the script draws the sleeve in half-blocks across a column count, and D2 is the
decision that removed that ceiling for this port. §14 then asks for "real cover
art at real resolution" on a display that has twice the pixels the panel has
points, and a 500 px picture blown up to a 480 pt sleeve on a Retina screen is
visibly soft. So the request goes to `front-1200` first.

**Two sizes, not one, and in that order.** The Archive has only had the 1200 px
thumbnail since 2017, and entries older than that have `front-250`/`front-500`
and nothing else. A single request at 1200 would silently lose the sleeve for
every one of those releases — so a 404 there falls through to `front-500`, which
is the size the script would have got and therefore the floor this can never
land below.

**The retry loop is unchanged, and the sizes go inside it.** `player:1913`
tries each candidate twice because "a first failure is more often a sick archive
node than a missing cover"; that reasoning is about the *node*, not about the
size, so the two sizes are walked within each of the two tries rather than
alongside them. The candidate cap stays at five (`player:1910`). The worst case
therefore goes from 5 × 2 = 10 requests to 5 × 2 × 2 = 20, and the ordinary case
— a release the Archive has a large thumbnail for — stays at one.

**Not `/front`.** The Archive will also serve the original upload, which is
sometimes 3000 px and sometimes a 40 MB scan of a booklet. Nothing ever waits
for this fetch (§5), but it is still someone's connection, and the panel cannot
draw more than the thumbnail already gives it.

**D46 — `--help` is a literal, and the suite is what stands in for `$0`.**
→ §1.1, §13

`usage` is four lines and the whole of it is a trick (`panel.sh:269`):

    awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "$0"

It prints the script's own header comment — lines 3 to 51 of `player`,
forty-nine of them — by reading the file it is running from. The help and the
header are therefore not two things that agree; they are one thing. **That
cannot be ported.** A compiled binary has no `$0` worth reading, the bundle
carries no copy of the source, and a literal in `Usage.swift` can drift from
the code the moment somebody adds a flag.

What replaces it is weaker and is written down as weaker: `UsageTests` reads
`Sources` back off disk through `#filePath` and asserts that every switch
`LaunchOptions.parse` accepts is spoken for in the text, that every
`MUTHUR_`/`PLAYER_`/`XDG_` name the kit reads is named, and — the direction a
literal is likeliest to get wrong — that nothing the page *offers* has since
been removed. `#filePath` is what the compiler saw and not a promise about this
machine, so those checks are conditional on finding the directory rather than
asserting a layout nobody guaranteed.

**Spoken for, not named**, because the original is not stricter than that: the
script's header lists `-n` and not `--dry-run` (`player:10`), and does not
mention `-h` or `--help` at all. The two alias pairs are carried by hand in the
suite; a switch with no alias to hide behind must appear under its own name.

Two departures inside the text itself. The examples are written in the name the
binary was invoked under rather than a hard-coded `player` — `usage` was
already reading `$0` for the text, so reading it for the name seemed the smaller
lie. And the page describes *this* program: AVFoundation where the script says
ffmpeg, `~/.cache/muthur/work`, the keys the panel actually binds, and no art
switch at all, there being no `MUTHUR_ART` to document (`player:49`). A help
page that lists a variable nothing reads is worse than a short one, so
`theHelpListsNothingImaginary` asserts that too.

**D47 — the picker's audio rule applies to archives too. Closing an
inconsistency in the script, not diverging from it.** → §1.2, §2.2, §14

`scan_sources` gates its two kinds of row differently, and only one of them is
gated at all (`player:1014`–`player:1043`). A folder appears if it has audio in
it — `audio_count` is `find … "${AUDIO_GLOB[@]}" | wc -l` (`player:1050`), and
the gate is one line (`player:1039`):

    n=$(audio_count "$z")
    [ "$n" -gt 0 ] || continue

An archive appears because it is called `*.zip` (`player:1035`):

    find "$d" -maxdepth 1 -type f -iname '*.zip' 2>/dev/null | LC_ALL=C sort

**Nothing there is a decision about archives.** It is the same rule, stopped
short at the one place the script cannot apply it — bash has no way to see
inside a zip without unpacking it, and unpacking every archive in `~/Downloads`
to decide whether to list it is obviously worse than listing it. So the rule
exists, applies to one kind of row, and is silently suspended for the other. The
consequence on this machine is a picker whose top three rows are RPG PDFs.

**§2.2 is what changes the arithmetic.** `ZipArchive` reads a central directory
where the archive lies — two `pread`s of a few kilobytes, nothing written to
disk, no entry data touched — so a member list is already in hand the moment the
file is opened. Asking `audio_count > 0` of that costs microseconds, which puts
the port in a position bash was never in. `ZipArchive.holdsAudio` asks it and
`SourceScanner` drops the rows that answer no.

**The definition of audio is `AudioFiles.extensions`, and that is the point.**
The same twelve extensions the folder rows count with and the same ones
`Record.read` will use on the scratch directory after the unpack. D7's lesson
was that a picker counting by a different rule from playback drops albums that
play perfectly; this is that lesson applied in the other direction, and the two
rules being one is what keeps *offered* and *playable* the same set. Members
under a dotted path are not audio, because `AudioFiles.scan` walks with
`.skipsHiddenFiles` — so an archive whose only `.flac` is a `__MACOSX/._Song.flac`
stub, which is most archives a Mac made, would open as an empty record. It is
not offered.

**A short deadline, and skipping rather than hanging.** One second, wall-clock,
shared across every archive in a directory — probed together rather than in
turn, so the budget does not multiply by however many zips are sitting there,
and one archive on a stalled mount loses only itself. The budget is never spent
on work; it is spent on a `pread` into a sleeping external disk or a network
volume that has stopped answering, which cannot be cancelled from here. What the
deadline buys is the right to **stop waiting** and draw the picker without that
row. A picker missing a row you can still reach with `BROWSE` (§14) beats a
picker that never appears, and that is the honest way round to state the trade.
An archive that will not open at all — truncated, not a zip under a `.zip` name,
encrypted so hard the directory will not read — answers no and is not offered,
which is exactly what the folder rows have always done with a directory that
turns out to hold nothing.

**Written down as a decision even though it changes no behaviour the script
chose**, because the picker after this lists fewer things than `player` would
and the next person to notice deserves to find the reason here rather than
guess at a porting mistake.

**D48 — a sleeve that is not square keeps its aspect. A divergence, not an
override.** → §5.4, §18.24

`art_render_blocks` hands ffmpeg `scale=$w:$((h*2))` (`player:2974`), which is an
exact size and not a fit: a 1500×1200 cover is squashed into the square box and a
1200×1500 one is stretched out into it. The port preserves the aspect and
letterboxes inside the same box.

What kept this open in §18 for as long as it was open is the worry that the port
was overruling a choice. **It is not, and the call is its own evidence.** There
is no aspect term in it — no `force_original_aspect_ratio`, no `-1` for an axis
to be computed from — and the arithmetic around it (`h=$((w/2))`, then
`w=$((h*2))`) is the terminal cell's 2:1 shape being undone and has nothing to
do with the picture's proportions. Nowhere in `art_tick` is stretching weighed
against fitting. The script was written as if every cover were square, and on the
material it was written against every cover was.

**A case the script never met is not a decision the port is overriding.** That is
the distinction `CLAUDE.md` draws, and it is why this is recorded here as a
divergence with reasoning rather than as one of the places the port corrects the
script (D15, D21, D39). The box in §5.4 comes down; the reasoning stays up.

---

## 17. When something is missing

The degraded paths, gathered in one place because they are scattered through the
script and every one of them is easy to skim past. **The rule the whole program
follows: the only thing worth stopping for is not being able to play the
record.** Everything else quietly becomes a worse panel.

### No network

- [x] Every MusicBrainz and Cover Art Archive failure is silent and
      indistinguishable from every other one. No error, no retry prompt, no
      "offline" indicator anywhere on the panel (`player:2171`). Asserted as the
      **absence of a vocabulary** — every string the panel can draw is gathered
      and none of them contains `OFFLINE`, `NETWORK`, `CONNECTION`, `RETRY`,
      `UNAVAILABLE` or `LOOKUP FAILED`. Not `MUSICBRAINZ`, which the faceplate
      says out loud and should: it is the title *source*, and it appears only
      when the lookup answered.
- [x] A disc with no CD-Text and no network plays as `Track 01…Track NN`, source
      `track numbers`, and the panel says so (`player:2237`, `player:2254`).
      Resolved with no CD-Text and a dead transport: nine tracks, faceplate
      `PLAYING · 9 TRACKS · track numbers`, and all three stages of the chain
      tried in order before it settled there.
- [x] A folder plays entirely normally: tags are local, and the only thing lost
      is a cover that was not already beside the record or in the file.
- [x] **The script's one durable consequence — a purely offline art fetch still
      writes a `.none` marker** (`player:1921`), so an album whose cover was
      looked for during an outage has no cover for the next **14 days**. Raised
      as §18.4 and answered: we do not carry it (D14). An outage now costs
      nothing beyond the play it happened on.
- [x] `--check` reports MusicBrainz as reachable tooling, not as reachability
      (`player:410`). Natively it should actually ask — **and answered: it does
      not (D39)**. The row says what the lookup will try and when, which is a
      true statement that costs nothing; a probe would make the one screen you
      run when nothing works the one screen that hangs.

### No CD drive, or no disc in it

**This is where §17 used to split.** Each of the first two boxes is one sentence
with two halves — a `--check` half and a detection half — and for a long while
only the first existed, so the boxes stayed open because half a box is not a box.
**§1.3 closed the other halves.** Both are now whole.

- [x] `drutil` absent → `--check` warns `drutil not found — CDs cannot be
      detected` (`player:399`) — **done** — and `find_cd` returns nothing
      (`player:965`) — **done**. Note *where* it returns nothing: after the
      `cddafs` route, not before it. A machine with no `drutil` and a mounted
      audio CD still finds the disc, because the kernel answered and nothing
      needed asking. Only the `/Volumes` fallback is switched off, which is
      right — it is the branch that has nothing to check its guess against.
- [x] `drutil` present, tray empty → `--check` warns `no disc, or no drive`
      (`player:397`) — **done**; the picker simply has no disc row
      (`player:1018`) and `--cd` dies with `no audio CD in the drive`
      (`player:3528`) — **done**, the script's words kept. The empty-drive half
      is the one half of §1.3 that **was** exercised on this machine's real
      drive, for the ordinary reason that the drive was empty.
- [x] **Not having a drive is not a warning worth escalating.** Most Macs have
      not had one for a decade, and the check says so in one line and moves on.
      Held against all three drutil outcomes crossed with a machine that has the
      fallback tooling and one that does not: `warn` every time, exit code 0
      every time, and the verdict still opens `I CAN PLAY A RECORD`. Nothing
      about the drive can gate the program.

### A disc that will not read

- [x] `drutil` says media is present but nothing mounts → detection falls through
      to the `/Volumes` scan and finds nothing; the disc is invisible
      (`player:1000`). There is no "the disc is unreadable" message and there
      never was one. **Done, on stubs** — the drive reports `CD-ROM`, no `cddafs`
      line exists, no `/Volumes` entry passes, and `find_cd` returns nothing with
      nothing said about it. The silence is the behaviour, so what is asserted is
      the nil and not a message.
- [x] A disc that mounts and then stops responding is §6.3: the first failed
      track stops the record, mode `STOPPED`, whole-record stat, and the message
      distinguishes files missing from files unreadable (`player:3285`,
      `player:3315`). The two sentences are held apart by assertion, not by
      inspection: `9 OF 9 TRACKS ARE NO LONGER ON DISK — STOPPED HERE` and the
      unreadable line share no wording.
- [x] CD-Text tooling that errors is treated exactly as CD-Text absent
      (`player:2064`) — down to MusicBrainz, then to track numbers. Three
      different error strings through the reader, `track numbers` each time.
- [x] A partially readable disc plays what it can: `read_metadata` skips files
      ffprobe cannot open (`player:1445`), and only zero readable files is fatal
      (`player:1494`). Nine files with the fourth unreadable gives an eight-track
      record numbered 1,2,3,5,6,7,8,9 — **the counter still advances over the
      skipped file**, which is why the numbers have a hole in them and the
      progress percentages are ninths, not eighths. Both fatal cases throw: no
      readable audio, and no audio at all.

### A folder with mixed formats

- [x] **Twelve** extensions, case-insensitive, in one album with no special case
      anywhere (`player:1046`). A folder of FLACs with one MP3 bonus track is one
      album. This box said *thirteen* until it was counted against
      `player:1046–1048`: aif, aiff, flac, mp3, ogg, opus, wav, m4a, wma, ape,
      alac, mp4 — twelve `-iname` terms, and the port carries the same twelve.
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

- [x] Every track sorts on key 9999 and is ordered by natural filename
      (`player:1451`, `player:1511`) — which for `01 … 12` is the right answer
      by accident, and for `Track A/Track B` is the only answer available.
- [x] Every title is the file's basename (`player:1481`) — **with the
      extension**, because that is what `basename "$f"` gives and the script
      never strips it.
- [x] Album is the folder's own name, or the zip's minus `.zip`
      (`player:1497`). Artist and year stay empty and the panel simply has less
      on it — no placeholder, no "Unknown Artist". Asserted as a header block of
      exactly `ALBUM`, `ARTIST`, `SOURCE` whose artist value is `—` and which
      contains none of "Unknown", "Various", "N/A" or "Untitled". D11's
      untitled-track notice would have been the exception to this box, and
      §18.27 closed it in this box's favour: the notice is deliberately not
      drawn. Nothing appears on a thin record that is not on a full one.
- [x] Source stays `tags` even when there were none, because for a folder there
      is nothing else it could be. Only a CD gets a fallback chain (§4).
- [x] The sleeve is still looked for beside the record (§5.1), which for an
      untagged folder is usually the only thing that finds one — the name-based
      MusicBrainz search (§5.3) has an album name and no artist and **still
      asks**, and returns nothing on purpose. The box used to read as though the
      script skipped the query; it does not. `mb_query` at `player:1825` drops
      only the `artist:` clause and sends `release:"Some Rip"` anyway
      (`player:1803–1807`) — the miss comes from the **quoted phrase**, which
      has to match the release title exactly, not from declining to ask.

### The album disappears mid-play

- [x] The case §2 exists to prevent, and §6.3 exists to explain: fifty tracks
      failing in two seconds must not read as `END OF ALBUM` (`player:3285`).
- [x] When the source was a zip the message names the cause:
      `— THE UNPACKED COPY IS GONE. Q, THEN PLAY IT AGAIN` (`player:3315`).
      Tested by deleting the files out from under a record that is playing.

### No ffmpeg

- [x] Bash: `--check` warns `no ffmpeg — the columns fall back to a pattern`
      (`player:367`, `player:374`); `SPEC_OK` goes to 0 (`player:253`) and the
      analyser draws
      two travelling waves that never settle into a loop (`player:928`).
      Recorded, not carried: no row in the port can say "pattern" or
      "travelling", and nothing is left to fall back from.
- [x] Native: ffmpeg is the *fallback decoder* only (`CLAUDE.md`), so its absence
      means Opus and Ogg will not play — a different and larger consequence than
      the script's. The analyser is a live tap and does not depend on it at all.
      `--check` has to say the new thing, not the old one. **It now does — D40.**
      The question moved onto the `playback` row, which is where the script's
      `mpv` row went and the only row whose subject is what plays the audio. The
      row asks after **both** binaries, and names whichever is missing.

---

## 18. Unsure whether these are features

Found while reading, and not obviously either intended behaviour or a bug. Per
`CLAUDE.md`, a decision in `player` that looks wrong gets flagged rather than
silently improved: each needs a yes or a no before the code it describes gets
written, and nothing is ported or "fixed" until it has one.

Of twenty-eight, twenty-three are answered — **1, 2, 3, 4, 6, 7, 11, 12, 14, 15,
16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27 and 28** — each marked below and
carrying the decision it became. The other five are open: **5, 8, 9, 10 and 13**.
**24 is the newest closure and the one that took longest**, because it was held
open waiting for material — a non-square cover to look at — and closed in the end
on the script instead: `scale=$w:$((h*2))` carries no aspect term, so there was
never a choice there to override (**D48**). **18** and **28** closed before it and were the two the drive was
holding — both answered before a disc went in, on the reasoning that neither
turned out to be a question about the disc. **One of those two answers survived
contact with a disc and one did not.** 28 stands: it is a question about what the
parser downstream reads (**D43**), and it was reasoned from the shape of a
capture. 18 was reasoned as a question about what a clone costs to build
(**D42**) — which presumed both routes work, and on macOS neither does. It is
answered again, as **D44**, and answered by a third route nobody had looked for:
`.TOC.plist` on the mount. **17**, **25** and **26** are the odd
ones: not `player` behaviours at all, but holes in decisions made here, which is
why each was answered as fast as it was found — 26 is two rules
about the year that cannot be asked the same question until §1.3, and was settled
anyway so that §1.3 inherits one. **21** is odder still — not a
question but a consequence, listed because it is a difference from the script
that nobody chose. It was **watched on a real record and measured**, the
measurement found something worse than the entry assumed *and pointing in a
direction*, and it is now closed as **D33**. **22** and **23** came out of §10
and were answered the same day: both were flagged rather than fixed first, which
is what `CLAUDE.md` asks for even when the port is the one that is right, and
they went opposite ways — 22 adds a line the script does not have, 23 keeps two
the port already had. **24** is the same shape and is still waiting: the sleeve
is drawn now, and the one thing about drawing it that the script and the port do
not agree on is what to do with a cover that is not square.

Most of the open ones describe code that has not been written yet. **4** was
the exception until §5 landed around it and forced the question; it is now D14.
**1**, **6**, **7** and **11** came due together when §4 was about to be written
and were answered before a line of it existed — 1 and 11 in the code that landed,
6 and 7 in §1, which is still ahead. **3** is the newest closure and came due the
same way: §8 could not be written without the loop either keeping the last
duplicate row or not, and it keeps it (**D34**). **26** is new, and it is the
same shape as 17, 18 and 25 — not a `player` behaviour but two decisions taken
here that disagree with each other, found by writing the second one.

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

3. **`collection_lookup`: the last duplicate row silently wins. — ANSWERED:
   ported as it stands, as D34.** → §8, §16 The END rule
   accepts multiple hits whenever an album artist is present
   (`if hits==1 || (hits>1 && want_a!="")`, `player:1706`) while the awk body
   overwrites its variables on every match — so two rows for the same
   artist+title give you the later one, with no indication there were two.
   *Prefer the first? Refuse ambiguity the way the no-artist path already does?*

   Came due when §8 was written and had to be answered rather than deferred,
   because the loop either keeps the last hit or it does not. **Neither.** The
   two ambiguities are not the same ambiguity: the no-artist path refuses because
   it has nothing left to go on, while duplicate artist+title rows mean the same
   record is in the catalogue twice — a mistake in a file this port may not
   write to, and refusing would make §8 go silent on a record that *is* on the
   shelf, for a reason the panel cannot show. Kept, and held down by a test
   rather than left as an accident. **D34.**

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

18. **Where the table of contents comes off the drive. — ANSWERED TWICE. First
    as D42, the `cdrecord -toc` parse; that condition then fired on the first
    real disc and D42 is reversed. Answered now as D44: macOS's own
    `.TOC.plist`, off the mount.** → §4.3, §16

    The reasoning that produced D42 is left standing below because it is the
    reasoning that got tested, and D44 records what the test said. The short
    version: **both routes §18.18 considered open the device exclusively, and on
    this platform neither can.** `diskarbitrationd` holds a mounted audio CD, and
    an audio CD on macOS is always mounted. There was a third route and nobody
    had looked for it.

    §4.3 said "`libdiscid`
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
    libdiscid as a test-time oracle?* **The parse stays** — D42. Nothing in §4
    changes either way, which is what left the decision to be taken on cost
    alone, and the cost that settled it is a clone that stops compiling. D15
    already has the reference implementation checking this parse, which was the
    only thing libdiscid was going to buy. The condition D42 carries — steps 4
    and 5 agreeing on a real disc — is the half of this question that still has
    not been observed.

    **Observed, and the answer is neither.** Step 4 could not be performed at
    all: `cdrecord -toc` does not disagree with `discid_read()` on this disc, it
    fails to read it. The whole framing above — two routes, same answer, decide
    on cost — was wrong about the premise it shared, which is that both routes
    work. See **D44**.

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

    **MEASURED, AND IT WAS WORSE THAN THIS ENTRY ASSUMED.** Both scales were run
    over the same real record window for window and compared in the unit the
    difference is visible in — eighths of a cell, of which a column has forty.
    `AutoscaleSettlingTests` is the measurement and holds the shape down.

    Mean disagreement across all sixteen bands, in eighths, over the first four
    sides of *Rumours*, in five-second buckets from the downbeat:

    | | 0–5s | 5–10s | 10–15s | 20–25s | 55–60s |
    |---|---|---|---|---|---|
    | Second Hand News | **28** | 17 | 13 | 8 | 3 |
    | Dreams | 11 | 7 | 7 | 5 | 4 |
    | Never Going Back Again | 16 | 8 | 5 | 4 | 2 |
    | Don't Stop | **21** | 16 | 11 | 7 | 3 |

    Peak disagreement in the first bucket is **40 eighths on all four** — the
    whole column, floor to ceiling. Second Hand News fades in: the script draws
    a mean height of 0 over the first five seconds and the port draws 28, which
    is three and a half of the five rows. That is not a settling anyone would
    describe as "over the opening bars"; it is *a different picture* for the
    first ten seconds and a visibly different one for thirty.

    **And the error has a direction.** It is upward, on every track, by more
    than three to one: the live scale has not yet heard the loudest part of the
    track, so its 25th percentile sits too low and every level maps above where
    the finished scale puts it. This is the same failure §9's autoscale exists
    to prevent — bands pinned near the top — arriving by the other road.

    Of the two fixes named above, **the carried-over scale was measured too**.
    Starting side two from side one's finished histogram takes its opening
    bucket from 11 eighths to 4 and its peak from 40 to 19; sides three and four
    improve as much. It is a real fix for every track but the first — **and it
    can do nothing whatever for the first**, which is the track you are on every
    time you put a record on. So it is half an answer at best.

    The warm-up window was not built, because choosing its length and what the
    scale does during it means inventing two numbers, and §18 items do not get
    code before they get an answer.

    **ANSWERED — D33, and it took three passes to get right.** Carry the scales
    between tracks, which is measured and free; and for the track you start on,
    do not build a warm-up but *flip the initial condition*, so that a band which
    has heard nothing is claimed to have been at full scale all along and the
    scale comes **down** onto the record instead of up to meet it.

    **Pass one got the shape wrong.** "Assume the loud part is coming" was
    implemented as "assume anything is possible" — one count in every bin, a flat
    spread. Those are different claims and only the second one can work: a scale
    ninety decibels wide still maps a −60 dBFS fade-in a third of the way up the
    column. It is the **bottom** anchor that has to move.

    **Pass two got the location right and the duration by accident.** A point
    mass at 0 dBFS turns the bias over on track one — 27.9 eighths to 0.0, peak
    40 to 4. But it was measured at the mass a *flat* prior over this histogram
    has by construction, 181, which was the correct control for isolating shape
    and is not a shipping value. At that weight the panel is **blank for five
    seconds** at the top of every record, over audible music, on sides where the
    script is already drawing on a third to a half of the bands. That is the
    opening objection pointed the other way: an analyser that looks broken at the
    moment you press play. Past that point the direction of the error is no
    longer the thing that matters.

    **And the weight is a duration, which is the second number this entry claimed
    to have avoided.** The bottom anchor comes off the seed once
    `0.25(N + w) ≤ N` and the top once `0.90(N + w) ≤ N`; at ten windows a second
    the weight is a length of time and nothing else. The warm-up window rejected
    above for needing an invented length, and the point-mass prior, are **the
    same number in different clothes**. It was not avoidable. Recorded here
    rather than quietly corrected, because the claim that it had been avoided is
    in this document's history.

    **Pass three fits it.** Objective, stated before the sweep and unchanged
    after: the mean absolute difference in percentage points between the port's
    lit-band curve and the script's, over seconds 0–9, across the same four
    sides, each decoded **cold** — the scales carry only within a sitting, so any
    track can be the one you dropped the needle on. Forty points, no weighting,
    no tie-breaks. Swept 0 to 400.

    | weight | 0 | 25 | 45 | **55** | 70 | 100 | 181 | 400 |
    |---|---|---|---|---|---|---|---|---|
    | mean \|Δ lit%\| | 34.0 | 29.7 | 27.8 | **27.2** | 28.5 | 28.4 | 34.5 | 65.0 |

    **55.** The basin is broad — 40 through 105 all score within 1.6 points — so
    the value is robust rather than knife-edge. The two ends score almost the
    same, 34.0 for inventing a song and 34.5 for erasing one, which is the whole
    shape of the problem in two numbers.

    **This is fitting, not tuning.** The target is the script, which `CLAUDE.md`
    makes the authority; nothing was scored against how the panel looks to
    anyone. Full lit-band and eighths tables are in D33.

    **What it costs, stated as the trade it is.** The dark start goes from five
    seconds to one. In exchange the fade-in now reads *tall* — +9.4 eighths,
    peaking at 21 — where the heavy prior read nothing, and D33 no longer claims
    a direction, because it no longer has one. One fade-in reading just over a
    row tall beats three loud openings reading blank. No cold column reaches the
    top row from nothing, which was the original failure at a peak of forty.

    **The steady-state cost is a known permanent divergence, not a cost that is
    going to be addressed.** The scale is made of the record rather than of the
    track, so a track quieter than its neighbours reads low for its whole length
    — worst measured, 7.2 eighths a minute in on Never Going Back Again, against
    2.9 for the same side scaled by itself. **The carry's own share is the
    difference, 4.3 eighths, not the 7.2**: a live scale a minute in has still
    not heard the rest of the track, and that half of the gap would be there
    with nothing carried. Nobody should reopen this looking for a fix: there
    isn't one coming. `steadyStateCost` computes the per-track baseline rather
    than quoting it, and holds both columns under a row of five.

    Two figures in this entry were corrected, both the same mistake — a number
    charged to the carry that belonged to the prior. The earlier 7.7 was
    measured under the heavy prior; and 2.9, though right, was unsourced until
    now. D33 has the table.

    Per-record scaling does show something the script hides — the dynamics
    *between* tracks. **That is not the justification**, and it is written down
    only so it is not mistaken for one: preferring it because it is better would
    be improving the script, which is not what a port does. The justification is
    that of two divergences that could not both be avoided, this is the cheaper.

    **A note on the rig, found while closing this.** The one test that fed the
    analyser through an `AVAudioEngine` in `enableManualRenderingMode` was
    asserting something it could never have established: measured, eight seconds
    pushed through an offline graph reached the tap as seventeen buffers and
    74,970 frames of 356,352 — under a fifth. Offline, a tap proves what a window
    *measures* and can prove nothing that depends on **how many** windows have
    gone by, which since D33 includes every column height. The rest of the suite
    was audited and nothing else was making the claim; `Analyser.tap` now carries
    the rule.

22. **The scroll window is never pulled back up. — ANSWERED: the fourth line
    goes in.** → §6, §10 `np_scroll` has three lines
    (`player:2904`): a cursor above the window pulls the top up to it, a cursor
    below pushes the bottom down to it, a cursor inside moves nothing. There is
    no fourth line pulling the top back up when the window has more room than it
    needs — so a terminal made *taller* leaves `np_top` where it was and draws a
    short list with blank space under it until the cursor next moves.

    **The environment changed, not the script's judgement.** In bash this is
    nearly invisible: a `SIGWINCH` is a rare event and the next arrow key fixes
    it. Here the window is dragged by its corner and the list re-lays out
    continuously while it is being dragged, so the same three lines are asked the
    question hundreds of times where bash was asked it twice — and the blank
    space under a short list stops being a stale frame and becomes the thing you
    are looking at while you drag. The fourth line is one `if`, it only ever
    shrinks `top`, and it only fires when the list cannot fill the window from
    where it is, so it is silent in every case bash was actually in. Two tests
    hold both halves down. → **D31.**

23. **Two width divergences. — ANSWERED: the port is correct, and stays.** →
    §10 `cwidth`
    (`panel.sh:274`) decides how many columns a character occupies, and the port
    disagrees with it twice — in both cases having chosen the answer that keeps a
    row from overrunning:

    - **Conjoining jamo.** `U+1160–U+11FF` render as part of the preceding
      syllable and bash counts them as one column each. The port counts them
      zero, as it does every other combining mark, because counting them as one
      makes a Hangul title measure longer than it draws.
    - **Fullwidth Latin.** Bash's wide range is a bracket comparison against
      collation order, which on this machine puts `Ａ-Ｚ` outside the range its
      own comment says is wide. The port takes the comment.

    Both are the port being *right* rather than different, which is exactly the
    case `CLAUDE.md` says to flag rather than quietly fix. **Confirmed: do not
    port a measurement bug.** A width function exists to stop a row overrunning,
    and a `cwidth` that measures a Hangul title longer than it draws fails at the
    one job it has. The divergence stands and is a decision now, not a drift.
    → **D32.**

24. **A sleeve that is not square. — ANSWERED: keep the aspect, and it is a
    divergence, not an override.** → §5, §10, **D48** `art_render_blocks` hands ffmpeg
    `scale=$w:$((h*2))` (`player:2974`), which is an exact size and not a fit: a
    cover that is 1500×1200 is squashed into the square box, and one that is
    1200×1500 is stretched out into it. The port preserves aspect and letterboxes
    inside the same box instead.

    **This is flagged, not fixed.** The rest of `art_tick` is written as if every
    cover were square — `h=$((w/2))` then `w=$((h*2))` is the *cell's* aspect
    being undone, nothing to do with the picture's — so there is no sign the
    script ever weighed the two and picked stretching. Which makes it look like a
    case it did not meet rather than one it settled, and that is the shape of
    thing `CLAUDE.md` says to raise.

    Almost every cover is square, so this is invisible on almost every record.
    Where it is not: a gatefold scan or a CD booklet photographed off-centre. The
    two answers are *fill the box exactly, as bash does* — the sleeve is always
    the size `art_tick` computed and the panel's rhythm is never broken — or
    *keep the aspect*, which is what is written now and what leaves a band of
    ground above and below a wide cover.

    **Held open on purpose**, and then closed on the reading rather than on the
    picture. What kept it open was the worry that the port was overriding a
    choice. It is not, and the `scale` call is its own evidence: **two exact
    numbers and no aspect term** — no `force_original_aspect_ratio`, no `-1` for
    the axis to be computed from — sitting inside arithmetic (`h=$((w/2))`,
    `w=$((h*2))`) that is entirely about undoing the terminal cell's 2:1 shape
    and says nothing about the image's. There is no place in `art_tick` where
    stretching was weighed against fitting. **A case the script never met is not
    a decision the port is overriding**, which is the distinction `CLAUDE.md`
    draws, and it is why this closes as a divergence with reasoning rather than
    as a correction. Letterboxing ships. → **D48.**

25. **A `QUIT` cap that is one click from the end of the record. — ANSWERED:
    leave it, unguarded.** → §10, D30 Not a `player` behaviour: a hole in a decision made
    here. `q` quits with no confirmation and that is the script's (`player:2547`),
    correctly ported and not in question. **D30 then drew it as a switch**, and a
    pointer can land somewhere a finger cannot — a mis-aimed click on the second
    keycap row now ends a record where before it took a deliberate keystroke.

    The three answers are: leave it, because the cap is the key and the key
    quits — which is the consistent one and the reason nothing has been done;
    move `QUIT` off the clickable set while leaving it on the legend, which makes
    one cap a picture and the other eight switches and is the worst of the three;
    or hold the cap, so quitting by pointer takes a press of some duration where
    quitting by key takes none.

    **Flagged rather than guarded**, which was right — putting a confirmation on
    a one-key quit would be improving the script rather than porting it, and this
    is exactly the shape `CLAUDE.md` says to raise instead.

    **Closed as the first of the three: leave it, and no guard.** The reason it
    is safe is already in the build, and it is §7. **The resume file means a
    mis-clicked `QUIT` costs nothing** — the position is written as the record
    plays, so reopening offers you the record back at the spot you were at. The
    hazard D30 introduced is a hazard about *losing your place*, and losing your
    place is the one thing this program already refuses to let happen. A hold
    would guard against a cost that is not there, at the price of making the cap
    a different switch from the key it depicts, which is the whole claim D30
    makes.

26. **Two decisions here disagree about the year. — ANSWERED: follow the
    script, and D6 is amended in place.** → §4, §8, §10, D6

    **D6 says first source wins:** "one year, from the first source that has one:
    tags, then the MusicBrainz release date, then the collection", and
    `HeaderBlock.year` does exactly that — the tag year beats MusicBrainz.
    **The script says last source wins:** `[ -n "$t" ] && YEAR="${t%%-*}"`
    (`player:2215`) overwrites whatever the tags put in `YEAR` with the
    MusicBrainz date, and `DiscTitles.swift` follows the script.

    They do not differ today, and that is the only reason this has not shown up.
    MusicBrainz is asked on the CD path (§4) and a mounted audio CD carries no
    tags at all, so the tag year is always empty exactly when the MusicBrainz one
    is present. **§1.3 is where they meet** — the moment a tagged folder can also
    be looked up, or a disc's titles get written back over a tagged rip, one of
    these two rules starts producing a year the other would not.

    Which one is right is a real question and not a formality. *Tags first* says
    the record in front of you knows more about itself than a database does,
    which is the rule the rest of §3 is built on. *MusicBrainz last* says a
    release date off a catalogue beats whatever a ripper stamped on the file, and
    it is what the script actually does — and per `CLAUDE.md` the script is the
    authority where a description conflicts with it.

    Flagged rather than settled, because the two answers put the year in
    different places on real records and neither is a tidy-up. **Nothing was
    blocked on it** — §8 shipped with D6's original order because that is what
    §10 already drew.

    **Closed as the script's: MusicBrainz wins where it spoke, tags fill in where
    it did not, the collection last.** `CLAUDE.md` decides which of the two is
    authoritative where a description conflicts with the source, and it is not
    this document. D6 is **amended in place** rather than joined by a second
    decision about the same question — there is one rule about the year and it
    now reads `MusicBrainz → tags → collection`. D6's collection-last position is
    untouched and §10 keeps drawing exactly what it drew.

    **Still unobservable, and recorded as such.** A mounted audio CD has no tags,
    so the only path that asks MusicBrainz is the only path where the tag year is
    always empty — no test on this machine can tell the two orders apart, and
    none pretends to. It is settled now so that **§1.3 inherits a rule instead of
    stopping to ask for one**, which is the whole value of answering it early.

27. **D11's untitled-track notice was decided and never drawn. — ANSWERED: it
    stays undrawn, and that is a decision. D11 amended in place.** → §17, §10,
    §16

    D11 reads that the untagged flag "looks like the start of a notice that was
    never built, so build the notice", and draws the distinction sharply: "*3 of
    12 tracks are untitled* is a different sentence from *this album has no
    tags*, and the panel can tell which it is looking at." The counting half is
    done — `Record` carries `unnumberedCount` and `unreadableCount`, both
    correct, both tested — and **nothing draws them**. §17 walked straight into
    the gap: the notice would appear on exactly the records §17's "no metadata at
    all" boxes are about.

    Three things would have to be invented to build it, and none is derivable
    from the script, because **the script has no such notice**. `UNTAGGED=1`
    (`player:1451`) is set and then only ever read to pick a sort key. So:

    - **Where it goes.** The header block is `ALBUM / ARTIST / SOURCE` and §17
      has just fixed that as exactly three rows with no placeholders. A fourth
      row is a new row on every record that has one, which the box above
      explicitly does not want.
    - **What it says.** D11 gives two example sentences, not the wording, and the
      script has no vocabulary to match against — this would be the first line in
      the program with no ancestor.
    - **When it says it.** A record with one untitled track and a record with
      twelve are the same flag in bash. D11 implies a threshold. There is no
      number in the script to take one from.

    It is in tension with §17's "no placeholder, no 'Unknown Artist'" box, which
    is now ticked: both cannot be maximally true.

    **Answered: do not build it.** D11 is amended in place rather than joined by
    a second decision about the same question — the counting half stays and feeds
    the sort, the drawing half is deliberately not drawn, and D11 now says so in
    as many words so that the undrawn counts are never mistaken for an unfinished
    job. Reopen D11 if a notice is ever wanted; do not fill in a gap.

28. **`cd_text`'s fallback can be suppressed by the error that should trigger
    it. — ANSWERED: narrowed, as D43. The gate asks the parser rather than the
    capture.** → §4.2, §16, §17

    Found walking §17's "CD-Text tooling that errors is treated exactly as
    CD-Text absent" box. That box is true, and this is the case where it is true
    in a way that costs something.

    `cd_text` runs `cdda2wav dev="$DEV" -J -v titles 2>&1` (`player:2071`) and
    then decides whether to try `cdrecord` by asking whether the capture
    mentions a title at all:

    ```
    if ! printf '%s' "$out" | qgrep -i 'title'; then
      command -v cdrecord >/dev/null && out=$(...cdrecord... 2>&1) || true
    fi
    ```

    (`player:2073–2074`.) The test is deliberately not "did it exit cleanly" —
    the comment on the port's copy says why, and it is right: cdda2wav on a disc
    with no CD-Text exits however it likes, so the only useful question is
    whether it printed any titles. **But `2>&1` has already folded stderr into
    the same string.** Any diagnostic containing the substring `title` — and the
    verbose keyword being passed is literally `titles`, which tools of this
    vintage echo back in usage and error banners — satisfies the grep. The
    fallback is then skipped, `$out` is a page of error text, no `^Track N
    title:` line matches, and `[ "$titles" -gt 0 ] || return 1` (`player:2111`)
    returns failure.

    Net effect: **a machine with a broken or unhappy `cdda2wav` and a perfectly
    good `cdrecord` silently never asks `cdrecord`.** It degrades to MusicBrainz
    and then to track numbers, which is why nothing ever looked wrong — the
    failure is indistinguishable from a disc that genuinely has no CD-Text, which
    is exactly §17's point and exactly what makes it invisible.

    The port inherited this verbatim while the question was open. It no longer
    does. `Tooling.output` still puts stdout and stderr on one pipe
    (`Tooling.swift:58–59`) — that half is the script's and stays — but the test
    is now `DriveCDText.wantsFallback`, which asks
    `CDTextParser.parse(capture).isEmpty`.

    The narrowings on offer were `title:` with the colon, or anchoring on
    `^Album title:` / `^Track`. **Both were guesses at what the parser looks
    for; asking the parser is neither.** It cannot drift out of step with the
    thing it is standing in for, and it makes the divergence something that can
    be stated exactly rather than argued about — three shapes where the port and
    the script agree, one where they differ, and that one is the fault. **D43**
    has the table and the reasoning. §19 step 8 is where it meets a real tool.

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

- [x] There is a `Type:` line and it names the media. On this machine, with an
      audio CD in a MATSHITA DVD-RAM UJ8E2 S over USB, it says `Type: CD-ROM`.
- [x] **The same line carries `Name: /dev/diskN`.** This is the whole premise of
      D17 — the device node is how a `/Volumes` entry is confirmed to *be* the
      disc rather than merely to look like one. `burncd:322` says it is printed
      there; confirm it on this machine and write down the exact spacing, because
      the parse has not been written yet.

      **Confirmed.** The line reads, verbatim:

      ```
        Type: CD-ROM               Name: /dev/disk10
      ```

      D17's premise is real. The padding is generous and `Name:` is nowhere near
      running into the type, so the parse can split on the literal `Name:` rather
      than on column positions — which is what it should have done anyway, but
      now that is a fact rather than a hope.

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

- [x] The disc appears as a `cddafs` mount, and the volume name survives the
      split on the **first** ` on ` and the **last** ` (` — a disc called
      `Live (Remastered)` is the case that rule exists for (§1.3). Mounted here
      as `/Volumes/Deluxe` on `/dev/disk10`, 13 CD_DA tracks.
- [x] The listing is `N Audio Track.aiff` files, numbered from 1 — **and on this
      disc it is not.** macOS resolved the track names itself and wrote
      `1 In The Blood.aiff` … `8 [Untitled].aiff` … `13 Coyote.aiff`. Both kinds
      of disc are real and the port has to be right on both:

      - §4.1's rescue is unaffected either way — it rewrites only the rows that
        say `Audio Track`, so on a named disc it correctly does nothing.
      - **Names are unpadded**, so the byte-order scan runs `1, 10, 11, 12, 13,
        2, …`. Scan order is not track order on any disc with ten or more
        tracks, and §3.1 is what puts it right. Two §19 tests asserted otherwise
        and had never run; both were wrong about the material rather than about
        the rule, and both are fixed.
      - A track the disc itself does not name comes through as `[Untitled]`,
        which is macOS's word and not `Audio Track` — so §4.1 leaves it alone,
        correctly: it is a name, and it is the only one there is.

Proves: §1.3's primary detection, which is not written yet — this is the step
that tells you what to write it against.

### 4. The table of contents

```bash
cdrecord dev=<device> -toc > /tmp/muthur-toc.txt
```

- [x] It contains `track:   1 lba: …` lines and one `track:lout lba: …` line.
      That is exactly what `CDRecordTOC.parse` reads. Anything else is the
      interesting outcome — keep the file.

      **The interesting outcome happened. This step cannot be performed on a
      mounted disc at all, and that is D44.** `cdrecord` exits 255 with no
      `track:` lines, on every device node, because `diskarbitrationd` is holding
      the disc and cdrtools wants an exclusive open. macOS mounts every audio CD,
      so this is not a corner. The shipping reader moved to `.TOC.plist` and the
      real comparison is step 6 — this step is retained because "cdrtools cannot
      read a mounted disc" is a fact about the platform worth being able to
      re-confirm, and because an *unmounted* disc is what `CDRecordTOC.parse` is
      still for.

- [x] **The volume's own table**, which is the one the app now reads:

      ```bash
      plutil -p "/Volumes/<name>/.TOC.plist" | head -20
      ```

      A `Sessions` array whose first entry carries `First Track`, `Last Track`,
      `Leadout Block` and a `Track Array` of `Point`/`Start Block` pairs. Track
      one's `Start Block` should read **150**, not 0 — that is how you know the
      pre-gap is already on and `fromLBA` must stay out of the way.

### 5. What libdiscid makes of the same disc

```bash
cc Scripts/discid-oracle.c -I"$(brew --prefix libdiscid)/include" -L"$(brew --prefix libdiscid)/lib" -ldiscid -o /tmp/discid-oracle
/tmp/discid-oracle read
```

- [x] It prints `id`, `toc` and a submission URL. Write **both** the id and the
      whole `toc` line down — the `toc` line is what step 6 compares against, and
      it is already in `tocString`'s format.

      Confirmed working on this machine, mounted disc and all, as an ordinary
      user. libdiscid is the one device reader `diskarbitrationd` does not
      obstruct, which is what makes it usable as the oracle in the first place.

### 6. The readers against each other — **the step this section exists for**

```bash
MUTHUR_TEST_CDDA="/Volumes/<name>" MUTHUR_TEST_DISCID=<id from step 5> MUTHUR_TEST_DISCID_TOC="<toc line from step 5>" swift test --package-path MUTHURKit
```

Tests in `§19 — with a disc in the drive` stop being skipped and run. `MUTHUR_TEST_TOC`
goes on the same line if step 4's capture ever succeeds on an unmounted disc.

- [x] `The fingerprint off a real disc is the one libdiscid gets — via libdiscid`
      — §4.3's arithmetic over the oracle's own table gives the oracle's own ID,
      and the table round-trips back to the `toc` line it arrived as.
- [x] `The volume's own table is the table libdiscid reads off the device` —
      field for field, and the same disc ID out of both. **This is the
      comparison D42 was held open on, made at last between the two readers that
      can both actually run.**
- [x] `The volume's table agrees with the volume's own track list` — the mount
      and the table are describing the same disc.
- [ ] `A real cdrecord listing reads as a table` — needs an unmounted disc; see
      step 4.
- [ ] `The fingerprint off a real disc is the one libdiscid gets` — same.

Proves: **D15 on real material** — confirmed, `rY66UjjiuCdVtE8hXkJ2Y6mLVZQ-` out
of both — and **D44**, the reader §1.3 reaches for.

**This step did its job the first time it ran, and what it caught was D42.** The
condition read: "A failure here is not a failing test; it is D42 having been
decided on an assumption that turned out to be false, and it comes straight back
open." It came straight back open, and closed again as D44.

**Still to meet D44's own condition:** a hybrid/enhanced CD, whose data session
would exercise the first-session rule against a real pressing rather than a
constructed plist. A disagreement with libdiscid there is a fault in
`VolumeTOC.parse`, not a reason to revisit D44.

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
cdda2wav dev=<device> -J -v titles > /tmp/muthur-cdda2wav.txt 2>&1
grep -c title /tmp/muthur-cdda2wav.txt
grep -cE "^(Album|Track[ ]*[0-9]+)[ ]*title:" /tmp/muthur-cdda2wav.txt
```

- [ ] **The two counts.** The first is the script's test (`player:2073`); the
      second is roughly what **D43** replaced it with. On a disc with CD-Text
      both are non-zero and nothing is being tested. **The count worth having is
      on a disc with none** — if the first is non-zero and the second is zero,
      that is §18.28 caught on this machine: the script would have stopped there
      and the port asks cdrecord. Keep that file either way; it is the fixture
      D43's tests are currently standing in for by hand.

      **Run once, on a mounted disc, and it does not settle anything.** cdda2wav
      exits **1** for the D44 reason — `diskarbitrationd` has the disc — and
      **both counts come back 0**. So this particular failure does not trigger
      §18.28's fault: the script would fall back here too, and D43 changes
      nothing about it. The banner shape D43's test uses by hand is still the
      shape that has not been seen in the wild. To get a real capture the disc
      would have to be unmounted first, which is the same obstacle as step 4.
- [ ] If the second count is zero, this is the fallback the app takes and you
      should capture it as well:
      `cdrecord dev=<device> -toc -v > /tmp/muthur-cdtext.txt 2>&1`
      (otherwise `cp /tmp/muthur-cdda2wav.txt /tmp/muthur-cdtext.txt`)
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

Proves: §4.2's first box, `DriveCDText`'s invocation, and **D43's condition** —
the narrowed fallback gate against what this machine's cdda2wav really prints,
rather than against a banner typed out from memory.

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

Proves D17 is worth doing. **§1.3 is now written and the gate is in it**, so this
step has changed from "material §1.3 needs" to "the case that would catch §1.3
getting it wrong". It has still never been set up: it wants AIFFs copied onto a
second volume — `/Volumes/My Passport` is the one on this machine — with a disc
in the drive at the same time. Until then, the *only* evidence that two eligible
volumes resolve correctly is a stub.

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
- [ ] `--check` with that same data disc in: `optical drive` warns
      `media: <type> — not mounted as an audio CD, so --cd has nothing to open`,
      and the verdict is still one that can play a record. **The picker says
      nothing about a data disc and this row does**, which is the difference
      between a chooser and a diagnostic (§11.1a).

### 13. `find_cd` against the drive — new with §1.3

Three tests, all `.enabled(if:)` on `MUTHUR_TEST_CDDA`. They need no capture
file: the material is the machine. **Nothing here opens the device** — the whole
point of §1.3's design is that detection is answers *about* the drive — so this
step is safe to run first, before anything in steps 4 through 8.

```bash
MUTHUR_TEST_CDDA=/Volumes/<the disc> swift test --package-path MUTHURKit \
  --filter DiscMaterialTests
```

- [ ] `find_cd` with the real probes lands on that volume, by the `cddafs` route,
      with a device node — proving `mount` on this macOS prints the shape the
      parser was written against.
- [ ] The node `drutil` names is the node the volume is mounted from. **This is
      D17's premise, and until this runs D17 rests on one reading taken by
      hand.**
- [ ] The picker row built off the real mount: mark `⊙`, the volume's own name,
      and a count that equals the track count in `.TOC.plist`. The only place
      D18's count and the drive's count are ever compared.
- [ ] `--check` with the disc in: `optical drive` is a `✓` reading
      `media: <type> — mounted at <the volume>`, and the path is the one step 3
      printed. **Read the whole row rather than the mark.** This is the line that
      went on saying `the disc source is not built yet` after §1.3 built it, for
      the only reason such a line ever survives — it cannot be seen from an empty
      bay (§11.1a).

If the first of these ever comes back `.shape` rather than `.cddafs`, the
`/Volumes` fallback is load-bearing on this platform after all and §1.3's second
box wants rewriting.

---

### What is still unproven after all of this

- **~~§1.3 in full~~ — written, and unproven on a disc.** Detection now exists
  and is exhaustively tested through a probes seam, against output transcribed
  off the disc while it was in (steps 1 and 3). But the disc was ejected before
  §1.3 was written, so **the disc-present half has never run**: no `cddafs` mount
  has been through `find_cd`, no picker row has been built off a real volume, and
  D17's premise still rests on one reading taken by hand rather than on step 13's
  assertion. What *was* exercised on this machine's real drive is the empty-drive
  half, and the real `mount` table, which turned out to hold two non-device lines
  the parser had never been shown.
- **The disc macOS cannot name.** The disc that was in the drive arrived with
  real track names, so §4.1's rescue never fired on it and every `find_cd` branch
  that keys on the string `Audio Track` — including the `/Volumes` fallback's
  first test — is **stub-only**. This is not a gap in the tests; it is a gap in
  the material, and only a differently-pressed disc closes it.
- **~~D42's condition~~ — met, and D42 did not survive it.** This was the entry
  that read "if they do not produce the same disc ID, D42 was taken without
  evidence it assumed, and it gets retaken here." It got retaken. `cdrecord`
  cannot read a mounted disc at all, so the comparison could not even be made in
  the terms it was written in; **D44** replaces D42 with `.TOC.plist`, and the
  comparison that *was* made — `.TOC.plist` against libdiscid — agrees field for
  field. **This is the single best argument for §19 existing.** The decision was
  carefully reasoned, correctly recorded, conditioned on the right observation,
  and wrong, and only a disc could say so.
- **D44's condition.** The enhanced-CD rule — first session only — is asserted
  against a constructed plist and has never seen a hybrid pressing. Step 6 on
  such a disc is what would prove it.
- **D43's condition, still open.** §18.28 is answered and the narrowed gate is
  tested against four hand-written captures. Step 8 has now been run once and
  settled nothing either way: on a *mounted* disc cdda2wav fails for D44's
  reason and prints nothing at all, so both counts are 0 and the two gates agree.
  What is still unseen is the capture where they differ — a cdda2wav that fails
  while echoing its own `titles` keyword — and reaching it means unmounting the
  disc first, which is the same obstacle as step 4.
- **Playback off a disc.** §3 reads a CDDA mount's `.aiff` files fine, and every
  §19 volume test now passes against a real one, but nothing has yet *played*
  from a disc — the AIFF the mount synthesises is read over the drive at the
  drive's pace, and whether gapless survives that is unproven.
- **~~Anything above the domain layer.~~** This entry said there was no app, no
  picker and no panel, so that "the panel says which source you got" was a value
  on a struct and not something you could look at. All three exist and have for
  some time; the sentence outlived the condition it described. What is still
  unproven above the domain layer is narrower and worth saying instead: the
  panel has never been looked at **with a disc in the drive**, so the SOURCE line
  reading `Audio CD` is still a value on a struct even though every other line
  of it is not.
