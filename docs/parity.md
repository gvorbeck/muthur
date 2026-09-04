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
  the reasoning and the decision it came from. All sixty-two are settled; they
  are §16, and §16 is now `decisions.md`, so that a difference from `player` is
  never later mistaken for a porting mistake without having to be read past to
  get to the next requirement. *(This number had drifted to thirty-nine while
  §16 said forty-six — two numbers for one set, which is the drift this document
  keeps warning about. Re-derived by counting the decisions themselves, which is
  the only count that is ever authoritative.)*

**Three files, one numbering.** This document is §1–§15, §17, and the five
questions in §18 that are still open. `decisions.md` is §16 and the twenty-three
answered questions of §18. `hardware.md` is §19. The split happened when the
answers had grown to four times the checklist they were answering for; nothing
was renumbered by it, and every `§n`, `§n.n` and `Dn` reference in all three
files, and in the source, means what it meant before. **The counts stay here**,
in the Status paragraph, for all three.

§17 collects the degraded paths — no network, no drive, a disc that will not
read, a folder with nothing in its tags. §18 is the open list: things in the
script that are not obviously either a feature or a bug, each needing an answer
before the code that would inherit it gets written. Neither is a checklist.

**§19 is**, and it is the one section written to be worked through rather than
read: everything §4 does that a machine with an empty drive can only test
structurally, and what to do with a disc in the drive to prove each of it. It
never assumed you had read the rest of this, and the rest of this never assumed
you had read it, which is why it is `hardware.md` now.

Line numbers are against the source as it stands today. Where a behaviour spans
a comment and the code it explains, both are cited — the comment is usually the
part worth porting.

---

## Status

**283 of 287 boxes** outside §19 (§19 is a procedure, not boxes, and is not
counted; it stands separately at 10 of 33). Re-derived by counting the files:
279 ticked and 4 open here, plus the 4 that live inside D8 in `decisions.md`,
and 10 of 33 in `hardware.md`.

**One box, new and ticked, and the denominator moved for the sixth time — the
fifth of them upward.** 286 → 287, on the same grounds as the last move: a
requirement that was not there before. **The keys worked; nothing on the panel
said so.** `-`, `=` and `m` have nudged the level and toggled mute since D1, and
the faceplate has shown the result since the same decision — but the one place
this program states what its keys do had neither, on the reasoning that the row
was already the width of the panel. That reasoning held for the row it was
about and did not extend to leaving two working keys undiscoverable, so `-= VOL`
and `M MUTE` are now a third row, after the one `QUIT` ends — written up as
**D58**, the third entry with no `player` line behind it and the first here to
reverse a clause of an earlier decision (D1) rather than something the script
did. `KeycapTests.fits` measures the new row at 19 of the panel's 69 columns; it
would have reached exactly 69 folded into the row above, which is the same
complaint the withdrawn reasoning made, now avoided rather than repeated.
**Both keys go through `PanelView.perform` now, the same switch every other cap
and key already shared (D30)** — before D58 they called the model directly,
which cost nothing while there was no cap to drift out of step with, and would
have cost exactly that the moment there was one.

**Before that: one box, new and ticked, and the denominator moved for the fifth
time — the fourth of them upward.** 285 → 286, for the same reason as D58 above:
a requirement that was not there before. **There was no way off a
record.** A record that had finished stayed finished, a record playing could only
be quit, and the one binding that did reach past it — ⌘O, live mid-record since
**D36** — is on no keycap and opens a file chooser, so the disc in the drive was
unreachable without quitting the program. `E EJECT` is that box (§14), and the
key is on §6.1's table beside D1's, marked new the way D1's are and adding no box
there. **`player` has nothing behind it and none is claimed**: `pick_source` runs
once before the first frame (`player:3531`) and `q` ends the run, because a
terminal you can retype does not need a way back and a window does — written up
as **D57**, which is the third entry after D45 and D49 with no script line under
it and the second, after D49, that comes of something already built being wrong
rather than missing. The cap went on the second legend row because that is where
it fits — 67 of 69 columns on the transport row against 35 on the row below,
which goes to 47, measured by `KeycapTests.fits` and not by eye. Pressing it
stops the deck, deletes the scratch directory down the same path `q` uses
(`player:312`, in `cleanup`'s order at `player:297`), and asks the drive again on
the way back, so the disc put in mid-record is on the screen you land on. **A
finished record does not do any of this by itself, and that is a decision rather
than an omission**: `FINISHED` is a reading, and taking the reading away
unprompted would be the panel doing something nobody pressed a key for.

**Before that: nothing moved for the tube, and that is the finding, not an
omission.** Five
visual changes landed — all four screws on screen at four written-down angles, a
band that falls down the raster, a wordmark that tears for a tenth of a second,
and a sleeve that shows the artwork it really came with while the pointer is on
it — and not one of them is a box. None has a counterpart in `player`, so none
can be a parity requirement; the requirement lives in `spec.md`'s visual
direction, where the chassis, the sleeve and *the tube is old and slightly
failing* now say so. **The count that moved is the decisions: fifty-one to
fifty-six**, D52–D56, and D52 is the first entry here that overrules something
this repository had already decided rather than something the script did — D28's
*nothing in it moves*, and the same sentence in `Phosphor.swift`'s header, both
amended in place rather than left disagreeing with the code. The two faults are
seeded (`Tube(seed:)`, on `PlaybackEngine.load`'s precedent) so their intervals
are asserted rather than eyeballed, and gated four ways: playing, on screen, not
Reduce Motion, and `MUTHUR_CRT` ≠ 0 — the new switch, documented in
`Usage.swift` beside the others and covered by `UsageTests` like the others.
Screws and sleeve are not gated: they are the chassis, not a fault.

**The falling band picked up a sixth visual change later, and it is still not
a box.** D61 has the band bulge the panel as it crosses it rather than only
lighting it, asked for directly and reusing the same four gates and the same
`Tube` schedule D52–D56 already built — no new requirement in `spec.md`, no
new switch, just the existing fault doing one more thing where it already
was. Still nothing here for `player` to have an opinion on, so still no box.

**Neither figure moved when the document split into three, either.** The count is of
requirements, and a requirement does not stop being one by changing file — which
is why it is now stated as a sum with `decisions.md` in it rather than as one
`grep` of one file. The four in `decisions.md` are D8's, on MU/TH/UR as a voice;
the twenty-three open in `hardware.md` are steps waiting on a disc. **Nothing is
counted twice and nothing is counted nowhere**, which is the only property this
paragraph has ever had to hold.

**Before that: the denominator went down for the first time, and two boxes were
new.** 289 → 285: six requirements came out of §1.2 and two went into §6.0a,
both by decisions taken deliberately and written up as **D50** and **D51** —
which are in `decisions.md`, as §16 now is.

**D50 deletes the source scan.** `scan_sources` walked `PLAYER_DIRS` — default
`~/Music:~/Downloads` — and everything the picker drew came out of it. It is
gone, and the opening screen is now the disc in the drive if there is one, or
`NOTHING IN THE DRIVE` and `B BROWSE` if there is not. **The reason is macOS, and
it was measured before anything was written**: `~/Downloads` sits behind the
Files-and-Folders TCC service and `~/Music/Music` behind Media Library, so the
scan fired two permission prompts at launch — and because this app is **ad-hoc
signed** by the rule in `CLAUDE.md`, every build is a new cdhash, TCC discards
the grant, and the prompts came back every single time. `NSOpenPanel` costs none
of that: the powerbox is another process, the choosing is the consent, and the
app is handed an extension for the one URL. The escape hatch was free and the
list was expensive. **Three call sites, not one** — `PanelModel`,
`Diagnostics.Probes.sources`, and `Inspect.run`'s no-argument branch — so
`--check`, the flag whose whole value is being safe to run, was re-firing both
prompts too. The six boxes that came out are named in §1.2 rather than merely
deleted, so nobody re-derives them. **D47 survives the change**, moved into
`SourceOpener.resolve`, with one clause deliberately inverted: an unreadable
archive was dropped by the scan and is let through by the door, because `BROWSE`
exists precisely so the file the probe would not read can still be tried. The
keycap row was re-measured against the 69-column budget and has two forms now,
45 columns with a disc and 34 without, both in `KeycapTests.fits`. `--check`'s
`records` row stays and reports the capability instead of a count, on the `zips`
row's precedent; it can no longer warn.

**D51 is a parity gap closed toward the script, and it is where the two new boxes
are.** `playlist_build` hands mpv `append-play` (`player:3259`) and `main` ends
`engine_start; play` (`player:3566`) — nothing in the script ever puts a record
on and waits — while `PlaybackEngine.load()` ended at `mode = .stopped` with no
caller starting it. **Every record opened in this port sat silent until a row was
clicked.** Fixed in `load()` rather than at the call site, through `play()` rather
than `pick(row: 0)`, so a record of no rows falls out still stopped without a
guard written for it. The second box is what autoplay could have broken: §7's
saved position survives a record that starts itself at the top, because
`ResumeWatch` reads the file in its **initialiser** and `PanelModel.adopt` builds
the watch above the load. Two tests hold that ordering down. **The resume offer
had never once appeared on screen before this** — `offerToShow` requires a
playing or paused deck — so D51 is also what makes §7 reachable for the first
time. §7's rule that the position is offered and never applied is unchanged and
was not quietly overridden.

**Before that: one box ticked, and it was the first one this document had closed
by taking a requirement out.** §14's Dock box asked for three things and gets two: the icon
and the ⌘⇥ identity are both on screen and were looked at — `App/MUTHUR.icns`,
still the amber-wordmark placeholder `Scripts/make-icon.sh` draws out of `Theme`,
on the tile and in the switcher under the name `MUTHUR` — and `Info.plist` needed
nothing for either, `LSUIElement` already `false` and `CFBundleIconFile` already
`MUTHUR`. The third, the cover in the Dock while playing, was **written, working,
and has been deleted** (`App/DockSleeve.swift`). It rested on a premise that four
captures disproved: the ⌘⇥ switcher draws its image *from* the Dock tile, so
`NSDockTile.contentView` was never the split it was documented as being and there
is no way to have the record in the Dock and the wordmark in ⌘⇥. Made one choice
instead of two, it is not a close one — **the tile is the handle you grab the app
by, not a display**, and an icon that changes with every record is one you have to
read before you can click it. That is **D49**, and it retires a line of `spec.md`
rather than deferring one. The cover still goes where it was always for:
`NowPlaying` pushes it to Control Center and the lock screen, which is the box
directly above this one and was already ticked. **The denominator did not move** —
a clause declined with reasoning is not a requirement removed from the count, and
the box is ticked because all three clauses are now settled rather than because
all three were built. That leaves **four open boxes in the whole document**:
`cdda2wav`'s CD-Text capture, and §14's other three — AirPlay and route handling,
output sample-rate switching, and ffmpeg as a fallback decoder.

**Before that, nothing was ticked or added, and a row was caught lying.** `optical
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
the same `SourceOpener.resolve` a picked row goes through. It is
`PanelModel.browse()`, which is also what ⌘O calls, so the menu item and the cap
are one chooser rather than two kept in agreement. *Written as the escape hatch
for the album outside `MUTHUR_DIRS`, with the scan untouched and still the
default. **D50 later made it the door** and deleted the scan — the paragraph is
left as it was written, because what it says about the mechanism is still exactly
true and only its standing changed.*

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

**The rule, restated so it keeps working.** The denominator has moved five times.
286 → 287, when D44 added §4.3's `.TOC.plist` reader — a requirement this
document did not previously have, discovered by putting a disc in the drive. Then
287 → 289, for D47's archive rule and §14's `BROWSE`, both found the same way:
by opening the picker on this machine and reading what was in it. Then **289 →
285, the first fall**: D50 took six requirements out of §1.2 and D51 put two into
§6.0a. Then 285 → 286, for D57's `E EJECT` — found the third way, by using the
window rather than by reading the script or the drive: there was no way off a
record. **A new requirement is the only thing that may move it up, and a
requirement deliberately withdrawn with its reasoning written down is the only
thing that may move it down** — all five movements were one of those. If it moves
again and no box was added for a behaviour newly discovered to be required, or
none removed by a numbered decision, that is drift — a miscount, a box that got
split, a box quietly reworded into two — and it should be found and reversed
rather than absorbed. **Moving a box to another file is not a movement**, which
is the one other thing that has happened to this figure: the count is
now a sum across `parity.md` and `decisions.md`, and it is the same number it was
before the sum had two terms in it. Both figures here were re-derived by counting
the files, not carried forward from the last edit.

**A withdrawal is not the same as D49's.** D49 declined a *clause* of a box whose
other clauses were met, so the box stayed ticked and the count did not move; D50
deleted six whole boxes because the behaviour they describe no longer exists in
the program at all. The test is whether anything is left to be true.

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

- [x] No argument → the source picker (`player:3531`). Which since **D50** is the
      disc in the drive or an empty bay, never a scanned list.
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
      Since **D50** the first source it finds is the disc, there being no others
      to find; with an empty bay it dies with `nothing to play. Put a CD in the
      drive, or name a zip or a folder`, which is `player:1114`'s sentence minus
      the half of its `:-` that was a path list.
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

**Read D50 before this section.** The scan is deleted. What the picker draws is
the disc in the drive, or nothing; the way to every other record is `BROWSE`. The
reasoning is macOS permissions against ad-hoc signing, and it is written out in
full as §16's D50, in `decisions.md`.

**Six boxes came off this section with it, and the denominator moved** — the D44
and D47 precedent, run backwards. They are named here rather than merely deleted,
because a requirement that vanishes without a trace is a requirement somebody
re-derives: *scans `PLAYER_DIRS`, default `~/Music:~/Downloads`, colon-separated*
(`player:1023`); *`find -maxdepth 1` for loose zips and immediate subdirectories
with audio in them* (`player:1031`); *zips and folders sorted `LC_ALL=C` per
scanned directory*; *a folder is offered only if it contains audio*
(`player:1039`); *D7's count looks two levels deep, not one*; and *one source and
no argument is not a choice — skip the picker* (`player:1117`). The last of those
is the one that is now actively declined rather than merely unreachable, and D50's
closing paragraph says why.

- [x] The disc, when there is one, is **the row** — if there is a disc in the
      drive it is almost certainly what you came to play (`player:1018`). The
      script put it above everything because `scan_sources` appends it before it
      walks the search path at all; since **D50** there is nothing for it to be
      above, and the ordering rule became the whole list.
- [x] Per-row detail column: `N tracks · in the drive`. **Corrected while §1.3
      was being read into.** This box
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
- [x] Row marks: `⊙` disc, `▤` zip, `▸` folder (`player:1073`). Only the first is
      ever drawn since **D50**; the other two survive because `mark` switches
      over `SourceKind` and that enum still has three cases.
- [x] **Changed from bash (D47). An archive is a record only if it contains
      audio.** A new box when it landed, and it moved the denominator on the D44
      precedent: a requirement this document did not previously have, found by
      looking at the picker on a real machine. The script applies the rule to
      folders and lists every `*.zip` unfiltered (`player:1035`) — bash cannot
      see inside one
      without unpacking it, so the rule is not absent there — it is suspended at
      the one place it could not be run. §2.2 reads a central directory where the
      archive lies, so the port can run it: two `pread`s, no entry data, nothing
      written to disk. Audio means `AudioFiles.extensions`, the same twelve the
      folder rows counted with, and dotted paths are excluded because
      `AudioFiles.scan` skips hidden files — an archive whose only `.flac` is a
      `__MACOSX/._Song.flac` stub would open as an empty record.

      **It moved to the door with D50**, out of the scan and into
      `SourceOpener.resolve`, which is now the only place a zip is ever judged:
      picking a zip of PDFs off `BROWSE` says `no audio in Rules.zip` rather than
      opening an empty record. The zip's own timing budget went with the scan —
      there is one archive to look at now, not a directory of them. **One clause
      inverted in the move, deliberately**: an archive whose central directory
      will not read was *dropped* by the scan and is *let through* by the door.
      A list should offer what will play; `BROWSE` exists precisely so the file
      the probe would not read can still be tried, and the unzip is the better
      judge of a damaged archive.
- [x] Nothing to play at all → say so (`player:1114`). **Changed from bash
      (D36).** The script *dies* here; a window cannot. The port says the same
      thing on the empty panel instead and stays up, which is the state
      `EmptyPanelView` exists for and the reason **⌘O is bound** —
      `File ▸ Open Record…` — so the panel it invented is not also a dead end.
      Since **D50** it no longer names the directories it looked in, there being
      none: the picker's own version of the line is `NOTHING IN THE DRIVE`, and
      it names no key because `B BROWSE` is on the legend two rows below it.
- [x] Keys: `⏎` open, `r` rescan (status `▪ RESCANNED`), `q` walk away with exit
      0 (`player:1134`). **`↑↓`/`kj` and `PgUp`/`PgDn` went with D50** — there is
      at most one row, and a cursor with nowhere to go is a lie about the list.
      `⏎ OPEN` is on the legend only when the bay has something in it; `RESCAN`
      is on it always, and an empty bay is when it earns its place, being how a
      disc put in after launch gets noticed.

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
      than the data on it, which is the one rule the palette has. Each pixel's
      level comes from its HSL lightness, not Rec. 709 luma (**D59**) — luma's
      heavy green weight read a green-less magenta as far darker than it looks.
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

### 6.0a A record plays when it is opened — a parity gap, closed (D51)

- [x] **`append-play`.** The playlist is handed to the deck with the flag that
      starts it (`player:3259`, and the comment above it at `player:3245`), and
      `main` ends `engine_start; play` (`player:3566`). Nothing in the script
      ever puts a record on and waits. **Fixed toward the script, not a
      divergence**: `PlaybackEngine.load()` ended at `mode = .stopped` and no
      caller started it, so every record opened in this port sat silent until a
      row was clicked. The fix is in `load()` rather than at the call site — a
      rule kept by the one caller that remembers it is the rule that goes missing
      the day there are two — and goes through `play()` rather than
      `pick(row: 0)` so there is one door into starting a stopped deck, and so a
      record of no rows falls out of `load` still stopped without a guard written
      for it. `togglePause()`'s no-op from `.stopped` (`player:2787`,
      `player:3308`) is untouched and still asserted, now on a deck that has
      never been handed a record — which is the only one that can be in that
      state.
- [x] **A record opened at a saved position can still be resumed there.** The
      thing D51 could have broken: the record now starts at the top the instant
      it is opened, and the deck's first observation writes row nought over the
      line §7 saved. It survives because `ResumeWatch` reads the file in its
      **initialiser** and holds the answer for the session, which is why
      `PanelModel.adopt` builds the watch *above* the load rather than inside it.
      Two tests hold that ordering down, the second from the other side: a watch
      built after the deck started finds nothing at all, so reordering `adopt`
      fails the suite rather than quietly losing people's places. §7's first box
      is unchanged and unchallenged — the position is **offered**, not applied —
      and D51 is what makes that offer reachable for the first time, since
      `offerToShow` requires a deck that is playing or paused.

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
| `e` | take the record off, back to the start screen — **new (D57)** |

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
- [x] **Changed from bash (D58).** On the keycap legend, not only the faceplate
      and the key bindings — `-= VOL` and `M MUTE`, a third row after the one
      `QUIT` ends. The keys and the faceplate readout are original to D1; only
      the legend entry is new, closing the gap between a key that worked and a
      key that could be found.

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

**None of this had ever appeared on screen until D51.** `offerToShow` requires a
deck that is `.playing` or `.paused`, and nothing started a deck after a load, so
the offer was written, tested and unreachable. §6.0a is what made it reachable —
and what could have destroyed it, since a record that starts itself at the top
writes row nought over the saved line within a tick. The ordering that saves it
(the file is read in `ResumeWatch.init`, above the load) is asserted in §6.0a's
second box rather than here, because it is autoplay's obligation and not §7's.

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

**`records` outlived its own subject (D50).** It counted what the scan found, and
in doing so it was a second copy of the scan — so `--check`, the flag whose whole
value is that it is safe to run, re-fired both of D50's permission prompts. The
scan is gone and the row stays, reporting the *capability* rather than a count,
because two readers would come looking for it and read its absence as a bug. It
can no longer warn: a row that cannot look cannot fail to find. That is the
`zips` row's precedent — a row about what this program is able to do, not about
what is currently true — and whether the drive has anything in it is the
`optical drive` row's business two lines up.

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
| `records` | — | **ok** `the disc in the drive, or one you point BROWSE at — no directory is searched, so none can be missing`. **New** (§1). Was `<N> in <dirs>` / **warn** `nothing to play in <dirs>`, the calm form of `player:1114`, until **D50** deleted the scan it counted |

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
| `PLAYER_DIRS` | `player:1023` | ~~Which folders the picker scans~~ — **nothing. D50 deleted the scan**, and `--help` says so under its own name rather than dropping it in silence |
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
The three `PLAYER_` names still honoured (`WORK`, `KEEP`, `COLLECTION`) are named
there as a group, and the suite asserts that the group is complete. `PLAYER_DIRS`
was the fourth until **D50**, and the page keeps a sentence about it for the
person who has had it exported for years and is owed an answer about why it
stopped working.

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
- [x] Dock icon, its own Cmd-Tab identity, album art in the Dock while playing.
      **Two clauses seen on screen, and the third withdrawn on purpose
      (D49).** `App/MUTHUR.icns` is a **placeholder** generated from `Theme` —
      the wordmark in phosphor amber on the CRT ground, meant to be replaced —
      and both halves of it were looked at with the Dock revealed and a record
      on the deck: the tile carries it, and ⌘⇥ carries it under the name
      `MUTHUR`, which is the whole of what a Cmd-Tab identity is. `Info.plist`
      needed nothing for that — `LSUIElement` is already `false` and
      `CFBundleIconFile` is already `MUTHUR`, so the bundle was never an
      accessory and the box was asking to confirm that rather than to change it.
      **The cover is not drawn on either, and the wiring for it is gone**
      (`App/DockSleeve.swift`, deleted). Two things settled that. The first is a
      platform fact this document did not know when the code was written: **the
      ⌘⇥ switcher draws its image from the Dock tile**, so `contentView` was
      never the split it was documented as being — four captures, cover on the
      deck and cover in the switcher, wordmark off the deck and wordmark in the
      switcher. There is no arrangement on macOS 15 that puts the record in the
      Dock and the wordmark in ⌘⇥. The second is that once it is one choice
      rather than two, the choice is easy: **a constant icon is what an app is
      *found* by**, and one that changes with every record is harder to pick out
      of a Dock, not easier. The sleeve still goes to the system — `NowPlaying`,
      Control Center, the lock screen — because that is the other job, and it is
      the one the cover is actually for.
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
      ssh has no file chooser to reach for; a window does. It is
      `PanelModel.browse()`, which is also what ⌘O calls, so the menu item and
      the cap are one file chooser and not two that have to be kept agreeing;
      the selection then goes through `SourceOpener.resolve` and
      `open(source:kind:)` exactly as a picked row does, so a folder chosen here
      cannot behave differently from the same folder found by the scan.

      **This box was written as the escape hatch, and D50 made it the door.**
      What it was escaping from cost two macOS permission prompts on every
      launch and this costs none, because the powerbox hands the file back
      without asking anybody — so the scan came down and `BROWSE` is now how
      every record that is not the disc arrives. The last two sentences of the
      paragraph above are the whole of what survived the change, and they
      survived because they were the part that was carrying the weight. The
      legend was re-measured against the 69-column budget and has two forms now,
      45 columns with a disc in the bay and 34 without; `KeycapTests.fits`
      measures both, along with the playing and check rows.
- [x] **`E EJECT` on the playing panel — the way back to the start screen.** A
      new box on `BROWSE`'s precedent, adding a requirement rather than
      inheriting one, so it moves the denominator again (see Status). The script
      needs no such thing: `pick_source` runs once before the first frame
      (`player:3531`) and `q` ends the program, because the way from one record
      to the next in a terminal is to type `player` again. **A window has no
      again** — quit and you are looking at the Dock, and hearing a different
      record costs the boot sequence, the drive and the scratch sweep. Written up
      as **D57**, which also records what was already there and why it was not
      enough: ⌘O has been live mid-record since **D36**, but no keycap names it
      and it opens `NSOpenPanel`, so **the disc in the drive was the one source
      unreachable without quitting** — the source D50 made the start screen be
      about. ⌘O stays; it is still the shortest way to a named folder.

      `E` was the free letter (`N P S R Q` were spoken for) and *eject* is the
      program's own word for it. It is on the **second** legend row, measured
      rather than guessed: the transport row stands in 67 of the 69 columns and
      the row below it in 35, which goes to 47 — `KeycapTests.fits` measures both
      alongside the picker's two forms. Bound during playback and not only under
      `FINISHED`, since the moment you most want the next record is ninety
      seconds into the wrong one; refused only while a source is coming open,
      where there is no record to take off and `player:1162` draws no legend
      anyway. Pressing it stops the deck, tears down the scratch directory by the
      same path `q` uses — `player:312`'s promise has no exception for records
      you got bored of, in `cleanup`'s order (`player:297`) — and calls
      `pickSource()` on the way back, so **a disc put in while the last record
      was playing is on the screen you land on**. A record that runs out does not
      do this by itself: `FINISHED` is a reading, and the key is the way off it.
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

**Moved to `decisions.md`, whole, and still numbered §16.** Fifty-one decisions
with the reasoning behind each ran to fifteen hundred lines inside a document
whose checklist is three hundred — the answers had swallowed the questions, and
this section had become the reason nobody read to the end of the one it is in.
They are one file over, D1 through D51, in order, with the `→ §n` pointer each of
them carries still pointing back into this document. A reference here to `D44` or
to `§16` means what it has always meant.

The rule that produced them stands and is `CLAUDE.md`'s: where a decision in
`player` looks wrong, flag it rather than silently improve it, and write the
answer down somewhere a difference from the script can never later be mistaken
for a porting mistake. **Somewhere is now `decisions.md`.**

Four ticked boxes went with them, inside D8 — the four that say what MU/TH/UR
being a name on a chassis rather than a voice actually costs. They are still
counted here, in the Status paragraph, because moving file does not retire a
requirement.

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

**Twenty-eight were raised; twenty-three are answered and have moved to
`decisions.md`** under this same number, each keeping the number it has always
had. An answered question is a decision, and having to read twenty-three of them
to find the five that still block something was the wrong way round.

What is left here is the open list — **5, 8, 9, 10 and 13** — and it is the whole
of it. They keep their numbers as written text rather than by their position in a
list, so that closing one moves nothing.

Most of them describe code that has not been written yet, which is why they have
gone so long without an answer: none of them is blocking anything today, and each
is here so that the code which would inherit it cannot be written by accident.

**5 is the exception, and it needs an answer it has not been asked for.** §2's
port has one unpacker rather than `unzip` and `tar`, and it already prints
`nothing came out of <source>` on the empty-archive path (`Unpacker`,
`player:1308`). The asymmetry the item is about cannot occur here, so the
question is only whether that was the right half to keep. It reads as yes.

**Probably bugs, but they have shipped and been lived with:**

**18.5 — `unpack_unzip` never checks that anything came out** (`player:1315`),
where `unpack_tar` has `[ "$n" -gt 0 ] || die "nothing came out of …"`
(`player:1308`). An `unzip` that exits 0 having written nothing produces `no
audio in <source>` from a later function instead of the accurate message.

**18.8 — `time-pos` parsing matches only non-negative numbers**
(`player:2758`), so a negative position — which mpv can briefly report across a
seek — leaves the previous position in place rather than being ignored
deliberately. Probably fine, probably accidental, and it does not survive the
port anyway.

**18.9 — `lead` in the CD filename rescue is not declared `local`**
(`player:1460`). A global leak, not a feature. Noted only so it is not
faithfully reproduced.

**Deliberate, but entangled with the terminal, so the port has to choose:**

**18.10 — `art_start` refuses to look for a cover at all unless the terminal is
UTF-8** (`player:2008`). Sensible where the only renderer is half-blocks;
meaningless natively. *Assumed dropped — the sleeve is a picture in a window now
— but it is a gate on a whole feature, so it is here rather than assumed
quietly.*

**18.13 — `resume_save` caps the file at 200 entries with `tail -200`**
(`player:1588`). An undocumented history limit that behaves as a
least-recently-*written* eviction. Almost certainly fine; worth being a
deliberate number rather than an inherited one.

---

## 19. With a disc in the drive

**Moved to `hardware.md`, whole, and still numbered §19.** It was always the odd
one here — a procedure to be worked through with the drive connected, not a list
of requirements — and it said as much itself: nothing else in this document
assumes you have read it, and it does not assume you have read anything else.
That is a description of a separate document.

It still stands at **10 of 33**, and that figure is still kept in the Status
paragraph above with every other figure, because the counts do not move house.
