# MU/TH/UR — decisions

Every deliberate departure from the bash `player`, with the reasoning that
produced it, and every question about the script that has been answered.
**This is §16 of `docs/parity.md` and the answered half of its §18**, moved out
on the day the answers grew longer than the thing they were answering for: two
thousand lines of decision under a checklist of three hundred, in a document
whose first job is to be read through.

Nothing was renumbered and nothing was rewritten to suit the move. A reference
anywhere — in that document, in this one, in a comment in the source — to `D44`
or `§16` or `§18.24` means exactly what it has always meant. The `→ §n` pointer
each entry carries still points into `parity.md`, and the pointers here from
`parity.md` are the same shape in reverse.

**The count does not live here.** Four ticked boxes came over inside D8, and they
are still counted by `parity.md`'s Status paragraph, which is the one place in
this project where a total is allowed to be written down. A requirement does not
stop being one by changing file.

Source references are `player:NNNN` for
`/Users/garrett.vorbeck/Sites/cd-collection/scripts/player/player` and
`panel.sh:NNNN` for `../lib/panel.sh`. Both are read-only.

---

## 16. Decisions taken

Raised before the code they touch was written, per `CLAUDE.md` — where a
decision in `player` looks wrong, flag it rather than silently improve it. All
fifty-six are settled. Recorded here with the answer so that a departure from
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
oldest question here that had been waiting on material. **D49** is the second out
of §14 after D45, and it is the only decision in this list that *removes* a
requirement: `spec.md` asks for the cover in the Dock, the cover was in the Dock,
and it has been taken out — because the ⌘⇥ switcher turned out to draw from the
same tile, and between a Dock that shows the record and a Dock you can find the
app in, the app wins. **D50** is the largest single subtraction in this list —
the picker's source scan, deleted rather than ported, because on macOS reading
two directories uninvited costs two TCC prompts and an ad-hoc signature brings
them back on every build. **D51** is the opposite motion and the only entry that
closes a gap *toward* the script: nothing in `player` ever puts a record on and
waits, and this port did, until `load` was made to start it. **D52–D56 came out
of the tube itself**, and they are the first ones with no `player` behind them
at all — §14 had none either, but these also overrule something this repository
had already written down. D52 is the overrule: the tube is now allowed to be
slightly *failing* and not merely old, which retires one clause of D28 and one
sentence of `Phosphor.swift`'s header. **D53 and D54** are the two faults that
budget buys — a band falling down the raster, and the wordmark losing its line
for a tenth of a second — each recorded with the mechanism it chose and the
cheaper ones it turned down. **D55** is the chassis: four screws on screen
instead of two under the title bar, at four angles that are constants rather
than dice. **D56** is the sleeve under the pointer, which is the only one of the
five that takes an effect *off*.

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
      else is the picker — one screen with the disc on it, or `BROWSE` (**D50**;
      this sentence said "and anything else scans" until the scan went). The one
      screen between launch and sound is `LoadingView`, and it is a progress
      meter carrying `OPENING`/`READING`/`READING DISC` — the script's own
      words (`player:1398`), not a greeting. The suite cannot
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

**And the name is now allowed to fail with the rest of the tube (D54).** It is
made of the same light as the track titles, which was the whole argument above —
so when the tube loses its line, the name loses it too. A nameplate could not
have done that either.

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

**One clause of this is superseded by D52.** The veils were settled here as a
still picture — `Phosphor.swift` said so in as many words, *atmosphere, not a
filter, and nothing in it moves* — and two of them now move. What D28 actually
decided is untouched: the glass still goes around the text, `Theme.vignetteClear`
still starts the fall-off outside the column the panel is set in, and readability
still wins every time. The falling band and the wordmark's tear are held to that
same bar rather than exempted from it, which is why one is 3.5% of a lit amber
and the other is over before you are sure it happened.

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

**D49 — the Dock tile keeps the wordmark. The cover goes to the system, not to
the icon.** → §14

`spec.md` asks for "the album art visible in the Dock while playing", and the app
had it: `DockSleeve` put the decoded cover on `NSDockTile.contentView`, chosen
over `applicationIconImage` on the stated grounds that the Dock draws the tile
and ⌘⇥ does not. **That premise is false, and it was checked rather than
reasoned about.** Four captures with the Dock revealed: record on the deck —
cover on the tile, cover in the switcher; no record — wordmark on the tile,
wordmark in the switcher, labelled `MUTHUR` both times. The App Switcher takes
its image *from* the Dock tile. There is no seam between them to write code into,
so the two clauses of §14's box that looked independent are one clause, and the
port had to pick a side.

**It picks the constant icon.** The reason is not that the cover looks wrong on
the tile — it looks rather good — but that the tile is not a display. It is the
handle you grab the app by. An icon that is a different photograph every time you
put a record on is an icon you have to *read* before you can click it, and the
whole point of the amber wordmark on the CRT ground is that you do not. This is
the user's call, made looking at it, and it is recorded here because it **retires
a line of `spec.md`** rather than merely leaving a box unticked: the cover in the
Dock is not deferred, not blocked, and not a stretch goal. It is declined.

None of that touches the cover's real audience. `NowPlaying` still pushes it to
`MPNowPlayingInfoCenter`, so the record's sleeve is what Control Center and the
lock screen draw — that is the surface built to show what is playing, and it is
already ticked two boxes above. **What the system is shown and what the app is
found by are different jobs**; the mistake the deleted file made was treating
them as one. `PanelModel` carries a comment at the old call site saying so, so
that this does not come back as an omission somebody helpfully fixes.

---

**D50 — the source scan is deleted. The picker is the disc, or `BROWSE`.** → §1.2

**The largest divergence in this document.** `scan_sources` (`player:1023`) is
the first thing `pick_source` does and the whole of what the picker draws: walk
`PLAYER_DIRS`, default `~/Music:~/Downloads`, one level down, offer the loose
zips and the subdirectories with audio in them. That is gone. What is left on the
opening screen is the disc in the drive if there is one, and `BROWSE`.

**The reason is macOS, and it was measured before anything was written.**
Launching MUTHUR fired two TCC prompts, every launch:

- `~/Downloads` is one of the three folders behind the **Files and Folders**
  service. Reading its contents at startup is the prompt.
- `~/Music` contains `~/Music/Music`, the Apple Music library, which is behind
  the **Media Library** service. The scan descends into it — D7's depth-2 count
  is what reaches the tracks — and that is the second prompt.

Neither prompt is a bug in the scan. Both are the correct behaviour of a program
that reads two protected directories without being asked to. What made them
intolerable is the *other* half of this app's setup, recorded in `CLAUDE.md`:
**ad-hoc signing**. TCC keys a grant to the code-signing identity, and an ad-hoc
signature is a fresh cdhash on every build, so the grant is discarded and the
prompts come back — not once, but on every rebuild, for a program whose entire
job is to be launched and play a record. The alternative is a Developer ID and
notarization, which the same file rules out for a personal app.

`NSOpenPanel` has none of this. The powerbox is a separate process; the user
picks the file there, and the app is handed a sandbox extension for exactly that
URL. **No grant, no prompt, ever** — the choosing *is* the consent. So the port
already owned a way to reach any record on the machine that costs nothing, and it
was sitting behind a keycap as an escape hatch from a list that could not reach
far enough. The list is what was expensive; the escape hatch is what worked.

**What the scan was actually worth** is worth being honest about, because it is a
real loss. It listed a shelf you could arrow through, and it made "put a record
on" two keys from launch. Against that: it looked in exactly two directories,
neither of which is where a real collection lives on this machine; it could not
see the album on the external drive or the one two folders deep; and since D47 it
could not see a damaged archive at all. It bought a convenience over a slice of
the disk that was not the interesting slice, and it charged two permission
prompts a launch for it.

**Three call sites, not one.** This is the part that would have been missed by
changing the picker alone: `SourceScanner.scan` was called by `PanelModel`, by
`Diagnostics.Probes.sources` — so `--check` re-fired both prompts, from a flag
whose whole purpose is to be safe to run — and by `Inspect.run`'s no-argument
branch, so `muthur -n` did too. All three are gone. `SourceScanner.swift` and
`SourceScannerTests.swift` are deleted.

**What was kept, deliberately.** `SourceOpener.resolve` and `open` are untouched,
and both the disc row and `BROWSE` go through them — a browsed folder or zip
opens by the same path a scanned row did, which is why nothing downstream of §1.1
changes. **D47's archive rule came with them**, into `resolve`: it was the scan's
rule, and losing it would mean picking a zip of PDFs off `BROWSE` and being shown
an empty record instead of being told. One clause of it **inverted** in the move,
and that inversion is the point of the decision — an archive whose central
directory will not read was *dropped* by the scan, because a list should offer
what will play; at the door it is *let through*, because `BROWSE` exists
precisely so the file the probe would not read can still be tried, and the unzip
is a better judge of a damaged archive than a two-`pread` peek at the end of it.
`Failure.noAudioInArchive` says `no audio in Rules.zip`, in `Record.Failure`'s
words, because it is the same finding arrived at earlier.

**The keycap row was re-measured**, which the 69-column budget requires. It now
has two forms. With a disc: `⏎ OPEN`, `R RESCAN`, `B BROWSE`, `Q QUIT` — 36
columns of caps and 9 of gaps, **45**. With an empty bay `OPEN` is absent, because
a cap for a key that does nothing is the panel promising what the bay cannot
deliver: 28 and 6, **34**. The row it replaces was 59. `↑↓ SELECT` went from both:
there is at most one row, and a cursor with nowhere to go is a lie about the
list. `RESCAN` **stays**, and an empty bay is exactly when it earns its place —
it is how a disc put in after launch gets noticed, which is the only meaning it
had that did not depend on the scan.

**`--check`'s `records` row stays and can no longer warn.** It used to say
`3 in /x/Music` or warn `nothing to play in /x/Music`, which was the calm version
of `die "nothing to play…"` (D36) — and, as above, a second copy of the scan. The
temptation was to delete it, and the reason not to is that two readers of
`--check` would come looking for it and read its absence as a bug. So it stays
and reports the *capability* rather than a count, on the precedent already set by
the `zips` row: `the disc in the drive, or one you point BROWSE at — no directory
is searched, so none can be missing`. It is `ok` unconditionally, because a row
that cannot look cannot fail to find, and whether the drive has anything in it is
the `optical drive` row's business two lines up.

**Smaller things that went with it, listed so they are findable.**
`PLAYER_DIRS`/`MUTHUR_DIRS` is no longer read anywhere, and `--help` says so out
loud rather than quietly dropping the name, because somebody with it exported is
owed an answer about why it stopped working. `PickerEntry.folderDetail`,
`zipDetail` and the `du -h` formatter under them are deleted: they rendered rows
for sources that had been *found*, and nothing finds one now. `Inspect.run` with
no argument asks the drive and dies with `nothing to play. Put a CD in the drive,
or name a zip or a folder` — `player:1114`'s sentence, minus the half of its `:-`
that was a path list, there being no paths to name.

**One place it declines to follow the script.** `player:1117` — a single source
is the answer, skip the picker — would now mean that launching from the Dock with
a disc in the drive starts playing it unasked, because of **D51**. Two decisions
that are each right alone and wrong together; the picker stays.

---

**D51 — a record plays when it is opened. A parity gap, closed toward the
script.** → §6.1a

Not a divergence. `playlist_build` hands mpv `append-play` (`player:3259`, and
the comment above it at `player:3245`), and `main` ends `engine_start; play`
(`player:3566`). **Nothing in the script ever puts a record on and waits.**
`PlaybackEngine.load()` ended at `mode = .stopped` and no caller started it, so
every record opened in this port sat silent until a row was clicked.

It is fixed in `load()` rather than at the call site. A rule kept by the one
caller that remembers it is the rule that goes missing the day there are two, and
`load` is the only place that knows a record has just been put on. It goes
through `play()` rather than `pick(row: 0)` so there is one door into starting a
stopped deck — and so that a record of no rows falls out of `load` still stopped,
which it does, without a guard written for it.

**`togglePause()`'s no-op from `.stopped` is untouched** (`player:2787`,
`player:3308`). It was never wrong; what was wrong is that anything was sitting
in `.stopped` after a load for it to be reached from. The suite still asserts it,
on an engine that has never been handed a record — which is now the only deck
that can be in that state.

**The interesting consequence is §7.** `ResumeWatch.offerToShow` requires
`.playing` or `.paused`, so with nothing ever playing after a load, **the resume
offer had never once appeared** in this port. D51 makes it reachable for the first
time, and it also creates the way it could be destroyed: the record now starts at
the top the instant it is opened, and the deck's first observation writes row
nought over the line that says where you had got to. It survives because
`ResumeWatch` reads the file in its **initialiser** and keeps the answer in memory
for the session, which is why `PanelModel.adopt` builds the watch *above* the
load rather than inside it. Two tests hold that ordering down, one of them from
the other side: a watch built after the deck started finds nothing at all.

**§7's first box is unaffected and stays as it is.** The offer is offered and
never applied — `player:2827` starts the record at the beginning and puts
`RESUME AT … — PRESS U` beside it, and `ResumeWatch` has no `apply` for anything
to call. A record opened at a saved position therefore starts from the top *and
can be resumed with one key*, which is what the script does. Flagged here rather
than changed, because applying it silently would be a divergence wearing a
parity fix's clothes.

---

**D52 — the tube is allowed to be failing, not just old.** → §10

`Phosphor.swift` opened with a rule of its own: the effects are atmosphere and
not a filter, **and nothing in it moves**. Two of them now move. This is an
overrule made with that paragraph in front of us, and the paragraph was rewritten
rather than left to disagree with the code beneath it — a rule the file does not
keep is worse than no rule.

**It is one more thing, not two.** The tube was old: uneven coating, a vignette, a
sheen, burn-in, a bowed raster. It is now old *and slightly failing* — a
deflection fault that walks a soft band down the raster (D53) and a wordmark that
tears for a tenth of a second every minute or so (D54). Both are faults of a
**tube**. Neither says anything about the state of the deck, which is the line
that keeps them honest on a panel whose entire job is to report state, and it is
also why the third obvious glitch vocabulary — characters briefly resolving to
something that is not the word — never got built.

**Four gates, and any one of them holds both still.** They run only while a record
is playing: a silent machine that twitches is a broken machine, and a paused one
is waiting rather than failing. They stop when the window is not on screen
(`NSApplication.occlusionState`), because an effect nobody is looking at is a
timer nobody is looking at. Reduce Motion stops them, per the spec's restraint
rules. And `MUTHUR_CRT=0` stops them for anyone who wants the tube steady without
turning the whole system's animation off — documented in `Usage.swift` with the
rest of the switches. The screws, the chassis and the true sleeve under the
pointer are not faults and are not gated by any of it.

**The schedules come from `Tube`, which lives in the kit and takes an optional
seed** — the precedent is `PlaybackEngine.load(seed:)`, and there are two reasons
rather than one. A random interval that cannot be seeded cannot be asserted, and
`UsageTests` scans only `Sources/MUTHURKit` for `MUTHUR_*` literals, so a switch
read from the app target would be a switch the help could not be checked against.
Production passes nil and takes the system generator.

**The cost was measured, not assumed.** Release, a three-track album playing, a
900×679 window, about fifty-five one-second samples of `top` per run, the two
builds interleaved on the same machine: before, 14.08 / 14.25 / 14.93% of one
core; after, 15.45 / 15.43 / 17.05%; the same shipping binary with `MUTHUR_CRT=0`,
14.43 / 14.66 / 14.35% — which is the before, and is the switch doing exactly what
it says. Both faults together cost roughly two and a half points of one core.

**D53 — the falling band. One translating layer, not a repaint.** → §10

A deflection fault, drawn as a soft gradient about five rows deep, at 3.5% of a
lit amber, added with `plusLighter` so it lightens what it crosses and darkens
nothing. It takes five to eight and a half seconds to fall, with two and a half
to nine seconds of nothing between passes. **The gaps are the point**: a band on a
fixed timer is a barber's pole, and the eye locks onto it within a minute. Drawn
from `Tube`, so the intervals are assertable rather than eyeballed.

**One layer over the whole window, translated.** The panel already redraws with the
analyser's FFT tap, and a band that made the panel repaint itself would have put
the fault's cost on top of the instrument's. This is a single view whose `offset`
is animated from above the top edge to below the bottom one; the compositor moves
it and nothing underneath is asked to draw again. That is what D52's measurement
is showing.

`.task(id:)` starts and stops it, so when the gates close mid-fall the animation
is left to finish rather than cut. It ends off the bottom edge either way, which
is the one place a band can leave without being seen to.

**D54 — the wordmark tears. A slice offset, not a colour split.** → §10

Three glitch vocabularies were available and two of them are wrong here. **An RGB
split** needs three channels to pull apart; this panel is one colour by rule, so
the split would not read as a fault in the machine, it would read as a different
machine. **Character corruption** — the badge briefly spelling something that is
not the name — is a lie about state on a panel whose job is not to lie about
state, and on eight glyphs at that pitch it is far too legible to be a
hundredth-of-a-second event: you would read the wrong word and believe it. **A
horizontal slice offset** says *the beam did not get back to the left edge in
time*, which is a thing a failing tube does and is not a claim the program is
making. That is the one that ships.

Two to four slices, each six to eighteen percent of the badge's height, each
displaced up to three dots — about half a character — held for seven to seventeen
hundredths of a second, once every twenty-two to eighty seconds. Long enough to
have happened, short enough that you are not sure it did.

**It cannot move the layout.** The tear happens inside the same fixed-width canvas
`WordmarkView` already had, drawn band by band with the badge clipped to each, so
the rule and the faceplate meta beside it never hear about it (`panel.sh:257`).
The slices arrive sorted and may still overlap, so the bands are walked with a
cursor and each takes only what is left below the last — two bands over the same
rows would draw the badge twice there, which reads as a ghost and not as a tear.
And none of it is animated: a tear that eases in is a transition, and the point of
this one is that it was over before you looked up.

**D55 — the chassis keeps its top edge, and no two screws sit at the same
angle.** → §10

The chassis called `.ignoresSafeArea()` on all four edges and put each screw at
half the surround in from its corner, which meant the top pair lived under the
title bar. **A fixing you cannot see is not a fixing** — the panel was mounted in
nothing at the top and screwed down at the bottom.

Three mechanisms were on the table. Padding the top by a title bar's height needs
a number this program does not know and macOS is free to change, and it would be
wrong on the day it changed. `.windowStyle(.hiddenTitleBar)` would have given the
whole window back and put the traffic lights on the brushed face of the chassis,
floating over it with no bezel of their own. What ships is the third: **the top
edge is the one that gives.** `edges: [.horizontal, .bottom]` bleeds the other
three, the window's own top inset holds the chassis down, and the surround then
holds the wordmark clear of the title bar exactly as it always did. One
expression, no constant in it, and it holds on resize because it is the safe area
doing the work rather than arithmetic about it. Checked at the smallest window the
app allows — 571×588, where the OS clamp bites before the declared minimum does —
and at 1920×1055, the whole screen: four screws on screen and the wordmark clear
at both ends.

**The angles are constants, and that is not laziness.** The screw canvas is re-run
on every resize and every change of backing scale, so a tilt drawn from a
generator would be a screw that turns itself while you drag the corner of the
window: uncanny once, a bug report twice. Four written-down angles, about a dozen
degrees either side of where the single one used to be — enough to notice with two
in view, not enough to read as a head somebody has chewed with the wrong driver.
**A screw is allowed to be crooked and is not allowed to move.**

**D56 — the sleeve tells the truth under the pointer.** → §10, §5.4

The cover on the panel is quantised to the phosphor ramp and then has every veil
in `ScreenEffects` drawn over it, which is correct — it is on the tube, and
everything on the tube is. It also means the artwork the record actually came with
is never visible in this program at all. Hovering the cover brings the true decode
up on a cross-fade and **takes the veils off with it, the falling band included**:
a true form under a scan line is not a true form.

The hole is punched in each veil's own mask rather than in the assembled stack.
That ordering is forced — `.mask` has to be applied *before* `.blendMode`, or the
blend is isolated into its own compositing group and `.multiply` has nothing left
to multiply against but transparency.

**Where the hole goes comes from a preference anchor, not from `@State`.** The
obvious route — measure the picture, keep the rect, read it back next frame — is
the one `rowsToAnalyser` already has a paragraph about not taking: the write lands
after the pass that wanted it. `.anchorPreference` on the picture and
`.overlayPreferenceValue` on the container resolve in the same pass, which makes
it the right tool and not merely the tidier one. It is reported from the picture
rather than from the square it is laid in, so hovering the empty band beside a
cover that is not square does nothing.

The fade is 0.28s each way and the mask outlives it. Three pieces of state rather
than one — whether the pointer is on the cover, how far the truth has come up, and
whether there is a hole to punch at all — the last cleared in the animation's
completion handler, so the veils come back over a cover that has finished fading
instead of snapping onto one half way. The second picture costs a second image in
memory and no second trip to the file: the true cover and the treated one are the
same bytes, read once and quantised twice as far.

---

## 18. Unsure whether these are features — the twenty-three answered

Found while reading, and not obviously either intended behaviour or a bug. Per
`CLAUDE.md`, a decision in `player` that looks wrong gets flagged rather than
silently improved: each needs a yes or a no before the code it describes gets
written, and nothing is ported or "fixed" until it has one. These are the
twenty-three that got one, each carrying the decision it became — which is why
they are on this page. **An answered question is a decision.**

The five still open are in `parity.md` §18, in full, because an open question
belongs beside the work it is blocking. They appear below as a line each, so that
the numbering this document has been citing since it was written does not shift
under anyone.

Of twenty-eight, twenty-three are answered — **1, 2, 3, 4, 6, 7, 11, 12, 14, 15,
16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27 and 28** — and the other five are
**5, 8, 9, 10 and 13**. **24 is the newest closure and the one that took
longest**, because it was held open waiting for material — a non-square cover to
look at — and closed in the end on the script instead: `scale=$w:$((h*2))`
carries no aspect term, so there was never a choice there to override (**D48**).
**18** and **28** closed before it and were the two the drive was holding — both
answered before a disc went in, on the reasoning that neither turned out to be a
question about the disc. **One of those two answers survived contact with a disc
and one did not.** 28 stands: it is a question about what the parser downstream
reads (**D43**), and it was reasoned from the shape of a capture. 18 was reasoned
as a question about what a clone costs to build (**D42**) — which presumed both
routes work, and on macOS neither does. It is answered again, as **D44**, and
answered by a third route nobody had looked for: `.TOC.plist` on the mount.
**17**, **25** and **26** are the odd ones: not `player` behaviours at all, but
holes in decisions made here, which is why each was answered as fast as it was
found — 26 is two rules about the year that cannot be asked the same question
until §1.3, and was settled anyway so that §1.3 inherits one. **21** is odder
still — not a question but a consequence, listed because it is a difference from
the script that nobody chose. It was **watched on a real record and measured**,
the measurement found something worse than the entry assumed *and pointing in a
direction*, and it is now closed as **D33**. **22** and **23** came out of §10
and were answered the same day: both were flagged rather than fixed first, which
is what `CLAUDE.md` asks for even when the port is the one that is right, and
they went opposite ways — 22 adds a line the script does not have, 23 keeps two
the port already had.

**4** was the first to be forced by the code landing around it: §5 was written on
top of it and it is now D14. **1**, **6**, **7** and **11** came due together
when §4 was about to be written and were answered before a line of it existed —
1 and 11 in the code that landed, 6 and 7 in §1. **3** came due the same way: §8
could not be written without the loop either keeping the last duplicate row or
not, and it keeps it (**D34**). **26** is the same shape as 17, 18 and 25 — not a
`player` behaviour but two decisions taken here that disagree with each other,
found by writing the second one.

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

5. **`unpack_unzip` never checks that anything came out. — STILL OPEN**, and it
   is in `parity.md` §18 in full: which message an empty archive earns.

6. **`find_cd`'s `/Volumes` fallback accepts any volume with two AIFFs** once
   `drutil` reports media (`player:1009`). With a disc in the drive and an
   AIFF-heavy external volume mounted, the external one can win, and then CD-Text
   and MusicBrainz answers about the disc get applied to it. — **Resolved: keep
   the shape test, gate it on the device node `drutil` names. → D17.**

7. **The picker counts CD tracks with `ls | grep -ic '\.aiff\?'`**
   (`player:1019`) rather than `audio_count`. A CDDA mount presenting anything
   other than AIFF would show `0 tracks` in the row it is being offered by. —
   **Resolved: one counter, the same one every other row uses. → D18.**

8. **`time-pos` parsing matches only non-negative numbers. — STILL OPEN**, and
   it is in `parity.md` §18 in full. It does not survive the port anyway.

9. **`lead` in the CD filename rescue is not declared `local`. — STILL OPEN**,
   and it is in `parity.md` §18 in full. Noted so it is not reproduced.

**Deliberate, but entangled with the terminal, so the port has to choose:**

10. **`art_start` gates the cover on a UTF-8 terminal. — STILL OPEN**, and it is
    in `parity.md` §18 in full. A gate on a whole feature, so it is not dropped
    quietly.

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

13. **`resume_save` caps the file at 200 entries. — STILL OPEN**, and it is in
    `parity.md` §18 in full. Worth being a deliberate number rather than an
    inherited one.

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
