# MU/TH/UR — with a disc in the drive

**This is §19 of `docs/parity.md`.** It moved out because it was never really a
section of it: it is a procedure to be worked through with the drive connected,
and it says so in its own first paragraph — nothing else in that document assumes
you have read this, and this does not assume you have read anything else. Two
documents that do not need each other are two documents.

Nothing was renumbered. It is still §19, every reference to it still says §19,
and the `§n` and `Dn` pointers below still point into `parity.md` and
`decisions.md`.

**Its boxes are not counted with the parity boxes** and never were — they are
steps in a procedure, not requirements — but the figure they stand at is kept
with all the other figures, in `parity.md`'s Status paragraph.

Source references are `player:NNNN` for
`/Users/garrett.vorbeck/Sites/cd-collection/scripts/player/player`,
`panel.sh:NNNN` for `../lib/panel.sh`, and `burncd:NNNN` for
`../burncd/burncd` — which this section leans on more than the rest of the
document does, because it is the program in that repository that actually drives
this hardware. All three are read-only.

---

## 19. With a disc in the drive

Everything in §4 is written and tested. Some of it is tested against tables and
listings typed out by hand, which proves the arithmetic and proves nothing about
this drive, this machine's cdrtools, or a disc you actually own. This is that
list, and it is meant to be worked through top to bottom with the drive
connected. Nothing below assumes you have read `parity.md`.

**What you need.** The drive, and three discs if you can find them: an ordinary
album that is certainly in MusicBrainz, one that carries CD-Text (most do not —
that is a fact about the discs and not a fault), and one disc out of a multi-disc
set. For step 10, an external drive with a couple of AIFF files on it, plugged in
at the same time. **Step 14 wants a blank**, and wants it last: it is the only
step here that spends anything, and every other step gets a disc out of it.

**Two of those three turned out to be one disc, and §20 made it.** The blank
`burncd`'s port burnt is in MusicBrainz — its disc ID resolves to four real
pressings of the album it was copied from — and it carries 742 bytes of CD-Text,
because the port wrote the CD-Text on. It is also, unexpectedly, the disc nothing
can name: macOS mounts it as `Audio CD` with thirteen files called `Audio Track`,
which is the material step 9 had been waiting on since the beginning. What is
still missing is a disc out of a set (step 11), a data disc (step 12), and two
AIFFs on the external volume (step 10).

**One rule that governs the whole session, before anything else.** `cdrecord
-checkdrive`, `cdrecord -prcap` and any libdiscid device read **open the drive
exclusively**, and for as long as that lasts macOS lets go of the media —
`drutil` will then report `No Media Inserted` about a disc that has not moved,
and keep reporting it (`burncd:278`). So: **`drutil` first, always.** If it
starts denying there is a disc, eject and reinsert rather than believing it.

**And the rule that runs the other way, which the script never needed.** An
exclusive open is also something macOS can refuse, and the thing that refuses it
is `diskarbitrationd`: while the disc in the drive is mounted, cdrtools cannot
open the device at all. It says so —

```
cdrecord: This machine seems to run the DiskArbitration daemon ...
cdrecord: Unable to get exclusive access to device.
```

— and every `-atip`, `-toc` and write in this document is one of those opens. So
**unmount the disc before any of them**, and expect to: an audio CD is mounted
the moment it is inserted, and a finished write can leave a mount behind too.

```bash
diskutil unmount "/Volumes/Audio CD"
```

The port does this for itself now (**D77**), before every write and before the
media check's capacity read. It is written down here because when you are
driving these commands by hand nothing is doing it for you, and because the
failure it causes is legible in a terminal and silent in the app: `media_check`
that cannot read ATIP does not stop — it warns once and goes ahead on trust,
which is exactly what a good burn looks like.

**§4.2 does it too now, and step 8 is where that was decided (D80).** Reading a
disc's CD-Text is an exclusive open like any other, so it is refused for as long
as the disc is mounted — and unlike a write, a lookup happens on a disc the
program is about to *play*, which is to say on a mount it needs. So the port
borrows the mount for the length of the read and gives it straight back, **when
the user opens the record and never when §1 scans the drive**: a scan has not
been handed the disc. Step 8 has the readings on both sides of that.

**One more thing about this drive, and it is not in any script.** `drutil tray
close` exits 0 and does nothing here; the tray has to be pushed shut by hand.
`drutil eject` works. So a step that ends with the tray open ends with a person
walking over to the machine, and a session that ejects a disc it did not need to
eject has cost somebody a trip.

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
      the parse had not been written when this step was.

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

- [x] Exactly one of them answers cleanly. Write it down — every command below
      wants it as `dev=…`. **On this machine it is `IODVDServices/0`**, which
      prints `Vendor_info : 'MATSHITA'`, `Identifikation : 'DVD-RAM UJ8E2 S '`
      and `Driver flags : MMC-3 SWABAUDIO BURNFREE`. The other five print their
      own name back and nothing else.
- [x] It is the same list `OpticalDrive.detect` walks, in the same order, so if
      one answers here `detect()` finds it. If none does, `detect()` falls back
      to `IODVDServices/0` and reports `answered: false`; `MUTHUR_DEV` overrides
      the lot.

      **Confirmed, and on the exit status rather than on the text**, which is
      what `detect()` actually reads: `IODVDServices/0` exits 0 and
      `IOCompactDiscServices/0` exits 255. `classes` is
      `["IODVDServices", "IOCompactDiscServices", "IOBDServices"]` walked
      `0...1` inside each — the loop above in the same order — and the drive
      that answers is the first name asked, so `detect()` reaches it without
      ever touching the other five.

Proves: `OpticalDrive.detect`, which the suite cannot touch at all. Run step 1
before this one — this is the command that makes `drutil` start lying.

**Except that here it did not.** Run against the blank, all six probes in a row,
`drutil status` afterwards still reported `Type: CD-R`, `Name: /dev/disk7`,
`Writability: appendable, blank, overwritable` — the media it had reported
before. That is one observation on one drive and it does not retire the rule:
the rule is the script's, it is defensive, and `burncd:278` was written by
somebody who had been bitten. Read `drutil` first anyway. What this does say is
that a machine where the order was got wrong is not necessarily a machine that
has to eject and reinsert before it can be trusted again.

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

      **And an unmounted disc is one `diskutil unmount` away**, which was not
      known when this was written — see the second rule at the top. That does
      not undo D44: the app cannot go taking somebody's disc away to read a
      table it can read off the mount instead. It does mean this step, and the
      two boxes of step 6 that waited on it, were performable by hand rather than
      blocked — **and they have been performed.** The audio CD they wanted is the
      one §20 stage 3b burnt, and the capture is fourteen `track:` lines that
      `CDRecordTOC.parse` reads.

      **One more thing the unmount turned up, and it is not `diskarbitrationd`.**
      With the disc playing, `diskutil unmount` was refused outright:

      ```
      Volume Audio CD on disk7 failed to unmount:
      dissented by PID 86779 (/Applications/MUTHUR.app/Contents/MacOS/MUTHUR)
      ```

      D77 is about the daemon holding the disc; this is the *app* holding it, and
      the app is the same program that is going to want the exclusive open. Any
      read-back of a disc somebody is listening to — `--verify` most obviously,
      since the disc it verifies is the disc just burnt and listening to it is
      the first thing anyone does — has to stop playback before it unmounts, or
      be told no by itself. Forcing the unmount out from under a reading process
      is not the answer.

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
- [x] `A real cdrecord listing reads as a table` — **run at last, against an
      unmounted disc**, and `CDRecordTOC.parse` reads what cdrecord printed:
      thirteen `track:` lines and one `track:lout`.
- [x] `The fingerprint off a real disc is the one libdiscid gets` — the disc ID
      out of cdrecord's own listing is `tbonDFn643nTGHTHA1pMedaG3ZI-`, which is
      what libdiscid reads off the device and what `cdda2wav` prints as its
      `CDINDEX discid`. **Three readers, one fingerprint.**

      **The disc these two ran against is the one §20 burnt**, which is the
      quietest thing on this page and possibly the most useful: the step had been
      waiting for material, and the other half of the port made some.

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

- [x] A `releases` list comes back, and it is the album you are holding.

      **Four of them came back, and all four are the album.** `Bon Jovi —
      Slippery When Wet`: a 2010 JP SHM-CD, two 2010 GB pressings, and a 2013 JP
      `Slippery When Wet +3`. Thirteen tracks, `Let It Rock` first, offsets
      matching to the sector.

      **And the disc that asked was a CD-R burnt an hour earlier**, which is a
      better result than a pressing would have been. It means the port laid the
      tracks out in the positions a real 2010 pressing has them in, closely
      enough that libdiscid's hash of the table lands on the same twenty-eight
      characters. A gap inserted anywhere, a track a frame long or short, and the
      ID would be a different ID answering 404. **This is the strongest evidence
      on this page that the burn is gapless** — stronger than reading the TOC
      back, because it is checked against somebody else's disc.

This is the one that has almost certainly never worked in `player` — D15 is the
reason, and this is where it stops being a claim about a hash. A disc genuinely
nobody has submitted answers with a 404 and that is a real answer too; try
another disc before concluding anything.

**One thing this step did not answer, and it is on screen rather than in a
capture.** Playing this disc, the app drew the right thirteen tracks at the right
lengths, an `ALBUM` of `Audio CD` and an `ARTIST` of `—` — the CD-Text failure
above — and, for a sleeve, **the cover of an Elton John SACD sampler**. The
lookup this step just ran by hand gives four correct releases for that exact ID,
so whatever put that sleeve on the screen is not this query answering wrongly.
Something between the disc and the sleeve is; it wants its own look, and it is a
§4 question rather than a §19 one. Recorded here because this is where it was
seen.

### 8. CD-Text

```bash
cdda2wav dev=<device> -J -v titles > /tmp/muthur-cdda2wav.txt 2>&1
grep -c title /tmp/muthur-cdda2wav.txt
grep -cE "^(Album|Track[ ]*[0-9]+)[ ]*title:" /tmp/muthur-cdda2wav.txt
```

**This is the step that caught something, and it caught it on the disc §20 had
just burnt.** Run against an unmounted disc at last, everything below either
answered differently from how it was written or answered in a way that made a
shipped bug visible. Read the four boxes together; separately they mislead.

- [x] **The two counts.** The first is the script's test (`player:2073`); the
      second is roughly what **D43** replaced it with. On a disc with CD-Text
      both are non-zero and nothing is being tested. **The count worth having is
      on a disc with none** — if the first is non-zero and the second is zero,
      that is §18.28 caught on this machine: the script would have stopped there
      and the port asks cdrecord.

      **Both counts came back 1, on a disc carrying 742 bytes of CD-Text and
      thirteen named tracks.** Not zero, so neither gate misfires and §18.28's
      fault is not triggered — and not fourteen either. The one line both counts
      can see is `Album title:`; the thirteen track lines are invisible to both,
      because on this cdda2wav they carry no `title:` at all:

      ```
      Album title: 'Slippery When Wet (Special Edition)'	[from Bon Jovi]
      Track  1: 'Let It Rock'
      ```

      So the gates were right to pass and the *parser* was wrong — see the last
      box. The earlier note here said a mounted disc gives both counts 0 and a
      cdda2wav exit of 1, which is still true and is the D44 reason; the fix for
      it is `diskutil unmount` and the second rule at the top of this file.
- [x] If the second count is zero, this is the fallback the app takes and you
      should capture it as well:
      `cdrecord dev=<device> -toc -v > /tmp/muthur-cdtext.txt 2>&1`
      (otherwise `cp /tmp/muthur-cdda2wav.txt /tmp/muthur-cdtext.txt`)

      **Captured anyway, and it is worth knowing what it holds: nothing.** On
      this drive `cdrecord -vv -toc` prints exactly one line about the lead-in's
      text — `CD-Text len: 742` — and not one title. It knows the text is there
      and will not say what it is. **So the fallback D43 narrowed the gate for
      cannot answer this machine at all**, and cdda2wav is not the preferred
      reader here, it is the only one. That does not retire D43: a gate that
      falls back too eagerly is still worth not having, and the banner case it
      was narrowed against is unaffected by a fallback that would have been
      useless anyway.
- [x] Whichever tool answered, note **which shape it printed** —
      `Track  1 title: 'X' from 'Y'` or `Track  1 title: 'X'`. Both are handled;
      what is unproven is which one this machine produces.

      **Neither. It printed a third shape and a fourth**, and this was the whole
      value of the step: `Track  1: 'Let It Rock'` with no `title:`, and the
      album artist as a tab and `[from Bon Jovi]` rather than a quoted `from`
      clause. `cdda2wav 3.02a09`, the build Homebrew installs and the one
      `DriveCDText` spawns.

```bash
MUTHUR_TEST_CDTEXT=/tmp/muthur-cdtext.txt swift test --package-path MUTHURKit
```

- [x] `Every title line this disc printed produced a title` — every line the tool
      printed came out as a title. The failure this is looking for is silent by
      design: a shape the parser does not know leaves the tidy `Track 07` in
      place, so a disc whose CD-Text is printed some other way is
      indistinguishable from a disc with none.

      **That is precisely what was happening, and it was on screen before it was
      in a test.** The app played the burnt disc and showed `ALBUM Audio CD`,
      `ARTIST —` and thirteen rows reading `Track 01` … `Track 13` — a disc with
      full CD-Text on it, displayed as a disc with none, exactly as this box
      predicted the failure would look. `CDTextParser` knew two shapes and the
      disc printed two others; it now knows all four, and this test passes
      against the real capture, thirteen titles out of thirteen printed lines.

      **This test could not have caught it before, either**, and that is its own
      lesson: it selected the lines to count with `hasPrefix("Track") &&
      contains("title:")`, so the only output it could ever run against was
      output the parser already read. The selector now matches on what every
      shape has — `Track`, a number, a colon, a quoted value — which is the rule
      in `CLAUDE.md` about asserting only what the platform actually guarantees,
      applied to a test rather than to a parser.
- [x] Best case, one of the titles has an apostrophe in it. That is the case the
      quote rule exists for — `Don't Stop Me Now` cut down to `Don` is the bug —
      and it is tested against both printed shapes already, but never against a
      disc.

      **Two of them have.** `Livin' On A Prayer` and `I'd Die For You` came back
      whole, off the disc, in the shape that had never been parsed before today.
      A lazy match would have given `Livin`.

Proves: `DriveCDText`'s invocation, `CDTextParser` against a real lead-in, and
**D43's condition** — the narrowed fallback gate against what this machine's
cdda2wav really prints, rather than against a banner typed out from memory. And
it proves the point of the whole section: two shapes had been reasoned about, and
the machine printed two others.

**Every reading above was taken with the disc unmounted by hand, and that is the
thing this step turned into a decision.** Run the way the port actually runs it —
the disc mounted, because macOS mounts every audio CD and §3 needs the mount to
play from — `cdda2wav dev=IODVDServices/0 -J -v titles` answers:

    Warning, 'diskarbitrationd' is running and does not allow us to
    send SCSI commands to the drive.
    cdda2wav: No such file or directory. Unable to get exclusive access to device.

which is D77's exclusive-open problem arriving at the *read* end of the program
rather than the write end. The fallback cannot cover it: `cdrecord -toc` cannot
open a mounted disc either, and on this drive it has no titles to give even when
it can. **So §4.2, on this machine, has no path to a title that does not begin by
unmounting the disc** — and the script has exactly the same hole, for exactly the
same reason, which is why it was a question rather than a bug to go and fix.

- [x] **The answer is D80, and §4.2's first box is ticked on the strength of
      this step.** Mounted, the read returns 1,431 bytes of refusal. Unmounted
      with the `DriveRelease` §20 already uses, the same call returns the album,
      the artist and all thirteen titles, and `diskutil mount /dev/disk7` puts
      the volume back with Finder none the wiser. The port now takes the mount
      away for the length of that one read and gives it straight back —
      **when the user opens the record, and never when §1 merely scans the
      drive.** The distinction is the decision; the mechanism was already here.

      Proved against a CD-R burnt by §20 this afternoon, not against a pressing,
      which is the caveat carried over into §4.2's box.

The disc was not left unnamed even before that: §4.3 reads `.TOC.plist` off the
mounted volume (D44), and step 7 resolved this very disc to its release through
MusicBrainz without touching the device once. That is why D80 is worded as an
upgrade rather than a rescue — CD-Text arriving is better than the volume name,
and worse than MusicBrainz, so the fall-through past it stays silent.

### 9. The mounted volume, end to end

```bash
MUTHUR_TEST_CDDA="/Volumes/Audio CD" swift test --package-path MUTHURKit
```

- [x] `A mounted CDDA volume numbers its own tracks` — the numbers come off the
      filenames macOS wrote, and none of them is 9999. Without this every title
      §4 learns lands on the wrong row, which is why the rescue exists (§3).
- [x] `§4.1 leaves a tidy list on a disc nothing can name` — `1 Audio Track.aiff`
      becomes `Track 01`, and the album falls back to the volume name.

      **The disc §20 burnt is the disc this box was written for, and step 3's
      second box is the other one.** There, macOS had resolved the track names
      itself and written `1 In The Blood.aiff`; the note under it said both kinds
      of disc are real and the port has to be right on both. Here is the other
      kind: thirteen files reading `1 Audio Track.aiff` … `13 Audio Track.aiff`,
      on a volume called `Audio CD`, because nothing macOS asks knows a CD-R
      pressed this afternoon. **Both kinds have now been seen, on this drive, and
      the rescue is right on both.**

      Worth saying plainly, because it looks like a contradiction and is not:
      macOS names those files from *its own* lookup and takes no notice of the
      CD-Text in the lead-in. The disc has thirteen titles written into it and
      the mount still says `Audio Track` — which is why §4.2 reads the lead-in
      itself rather than trusting the filenames, and why step 8 above matters at
      all.

Proves: §3's CD-only rescue and §4.1 against filenames this program did not
invent.

### 10. Two volumes at once — D17

With a disc in the drive **and** an external volume holding two or more AIFFs
mounted:

- [x] `drutil status` names the disc's device node, and it is not the external
      volume's.
- [ ] Confirm the external volume is the kind of thing that would win under the
      script's rule (`player:1009`): a `/Volumes` entry with two AIFFs in it.

**The first ran with the disc §20 burnt in the bay and `/Volumes/My Passport`
mounted beside it**: `drutil` said `/dev/disk7`, the external volume is
`/dev/disk4s2`, and `find_cd` took the disc (step 13). Two volumes were up at
once and the drive's node was not the external's.

**The second did not, and it is worth saying why rather than leaving it blank.**
It was checked, and the answer was no: `/Volumes/My Passport` holds `Books`,
`Comics`, `FLAC`, `Games`, `Home Movies` and `Music`, and not one AIFF at its top
level — so under `player:1009` it is not an eligible volume and cannot lose a
contest it was never in. Staging D17 properly wants two AIFFs copied to the root
of that volume, which is somebody's backup drive and not this port's to write to.
Until that is done deliberately, the *only* evidence that two eligible volumes
resolve correctly is a stub.

Proves D17 is worth doing. **§1.3 is now written and the gate is in it**, so this
step has changed from "material §1.3 needs" to "the case that would catch §1.3
getting it wrong".

### 11. A disc out of a set — D16 and §4.4

- [ ] Its disc ID resolves (step 7) to a release, and the track list that comes
      back is **that disc's**, not disc one's.
- [ ] If the answer carries more than one release, the album name and the release
      MBID come from the same entry the track list did. That is D16; on a
      single-release answer nothing distinguishes it from the script.

Open for want of a disc, not for want of code. The disc §20 burnt is a single, and
step 7 resolved it to four releases of the same album rather than to one release
of several discs — which exercises the *second* box's tie-break machinery but says
nothing about the first, because every one of the four had the same thirteen
tracks. A physical disc two is the only thing that closes this.

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

All three are open on purpose and none of them is waiting on code. The first
wants the bay empty, and the bay holds the disc §20 burnt, which was closed into
it deliberately and has been the material for half this document since. Getting
it out costs a walk to the machine to put it back — `drutil tray close` exits 0
and does nothing here — so it comes out when somebody asks for it and not to read
one line. The second and third want a data CD or a DVD, and there is not one to
hand. Both are minutes of work the day the material is there.

### 13. `find_cd` against the drive — new with §1.3

Three tests, all `.enabled(if:)` on `MUTHUR_TEST_CDDA`. They need no capture
file: the material is the machine. **Nothing here opens the device** — the whole
point of §1.3's design is that detection is answers *about* the drive — so this
step is safe to run first, before anything in steps 4 through 8.

```bash
MUTHUR_TEST_CDDA=/Volumes/<the disc> swift test --package-path MUTHURKit \
  --filter DiscMaterialTests
```

- [x] `find_cd` with the real probes lands on that volume, by the `cddafs` route,
      with a device node — proving `mount` on this macOS prints the shape the
      parser was written against.
- [x] The node `drutil` names is the node the volume is mounted from. **This is
      D17's premise, and until this runs D17 rests on one reading taken by
      hand.**
- [x] The picker row built off the real mount: mark `⊙`, the volume's own name,
      and a count that equals the track count in `.TOC.plist`. The only place
      D18's count and the drive's count are ever compared.
- [x] `--check` with the disc in: `optical drive` is a `✓` reading
      `media: <type> — mounted at <the volume>`, and the path is the one step 3
      printed. **Read the whole row rather than the mark.** This is the line that
      went on saying `the disc source is not built yet` after §1.3 built it, for
      the only reason such a line ever survives — it cannot be seen from an empty
      bay (§11.1a).

**All four ran against the disc §20 burnt**, which is how this step finally got a
disc-present drive to answer at all. `drutil` reported `Name: /dev/disk7`, `mount`
printed

    /dev/disk7 on /Volumes/Audio CD (cddafs, local, nodev, nosuid, read-only, noowners)

and `find_cd` came back `.cddafs` with that node — so the fallback below stays a
fallback and §1.3's second box holds. The `--check` row read

    ✓  optical drive        media: CD-ROM — mounted at /Volumes/Audio CD

which is a `✓` and a path, and the row that used to say `the disc source is not
built yet` is gone for good. One honest correction to the box as written: the
path is not the one step 3 printed, because step 3 was run on a different disc
and printed `/Volumes/Deluxe`. It is the path the *current* `mount` prints, which
is what the box was always reaching for; the old wording assumed one disc would
last the section.

If the first of these ever comes back `.shape` rather than `.cddafs`, the
`/Volumes` fallback is load-bearing on this platform after all and §1.3's second
box wants rewriting.

### 14. The other program — §20 against this drive

Every step above reads a disc somebody else made. This one makes the disc, and
it is the only part of the port that spends something: a blank is a blank once.
So the four commands below are four environment variables and not one, in the
order they are written — each proves what the next one is allowed to assume, and
the third is irreversible.

**Build the record first, without going near the drive.** A real album is where
apostrophes, variable bit rates and a running time that will not divide come
from; a rehearsal that fails on any of those has taken the drive for a minute to
tell you something a conversion would have said for free.

```bash
W=$(mktemp -d); S="/path/to/an/album"
MUTHUR_TEST_BURN_WORK="$W" MUTHUR_TEST_BURN_SOURCE="$S" \
  swift test --package-path MUTHURKit --filter BurnMaterialTests
```

- [x] `A real album builds to an image and a cue` — one disc, a cue whose
      `FILE` points at the image beside it, and a `CDTEXT` block in it. Run on a
      thirteen-track FLAC album; the shedding ladder never had to shed.

**Then rehearse, which is free and repeatable.** `--dummy` runs at write speed
with the laser off, so it takes a minute of real drive time and gives the blank
back. It is the last thing between a vector and a coaster.

```bash
MUTHUR_TEST_BURN_WORK="$W" MUTHUR_TEST_BURN_SOURCE="$S" MUTHUR_TEST_REHEARSE=1 \
  swift test --package-path MUTHURKit --filter BurnMaterialTests
```

- [x] `A rehearsal drives the real drive, and cdrecord takes -text` — the verb
      reads `REHEARSING`, the panel reaches the last track, and the log carries
      `Lead-in write time`, which is the evidence `-text` was accepted rather
      than merely passed. **Rehearsed three times** before the blank was spent.

**Then the burn. This is the irreversible one**, and it is its own variable for
that reason: a hand that meant to rehearse and typed the wrong name should get a
rehearsal.

```bash
MUTHUR_TEST_BURN_WORK="$W" MUTHUR_TEST_BURN_SOURCE="$S" MUTHUR_TEST_BURN_FOR_REAL=1 \
  swift test --package-path MUTHURKit --filter BurnMaterialTests
```

- [x] `The laser comes on and the blank is spent` — thirteen tracks, 58:57.42,
      an average 8.0x with the drive's buffer never below 96%. What came out
      plays. Steps 4, 6, 7, 8, 9 and 13 above are all standing on it.

**Then read it back, which is what `--verify` is.** The tray has to still hold
the disc — the burn gives up its own `-eject` when a verify is coming — and the
disc has to be off macOS, which `DiscVerify` does for itself (**D77**) and which
is why nothing may be *playing* it: an unmount is dissented by whoever holds the
volume, this app included (step 4).

```bash
MUTHUR_TEST_BURN_WORK="$W" MUTHUR_TEST_BURN_SOURCE="$S" MUTHUR_TEST_VERIFY_DISC=1 \
  swift test --package-path MUTHURKit --filter verifyTheDiscInTheDrive
```

- [x] `The disc in the drive reads back as the record that was burnt` — all
      three checks green on the disc §20 burnt:

      ```
      VERIFYING disc 1...
        ✓ table of contents — 13 tracks
        ✓ full read — every sector came back
        ✓ CD-Text — album title reads back
      ```

      **The full read is four and a half minutes and it is the point of the
      step**: 265,307 sectors off the disc with no read error anywhere, which is
      the same walk a player has to make. It is not proof the drive is a gapless
      *source* — that is a question about timing and this one is about sectors —
      but it is the first evidence that the drive can get through this disc at
      all. The album title is checked against the shed title rather than the
      folder's, so this box also says the shedding ladder wrote what it thought
      it wrote.

      The record it is checked against is derived again from the folder, because
      the image was deleted with the disc (**D79**) and the folder is the only
      copy left.

**What this step cannot do is `--from-disc n`.** Resuming a job needs the job to
have been interrupted between two discs, which needs two blanks, and there is
one blank in this building and it is now a Bon Jovi record. Everything above the
drive is tested — the layout of a resumed disc is byte-identical to the same disc
in a whole-job run, the discs before it are planned and then not built, and a
disc number past the end is refused before anything converts. §20's last box
stays open for the one thing nobody in this building can supply: a second blank.

---

### What is still unproven after all of this

- **~~§1.3 in full~~ — run on a disc, and it held.** This entry read "written,
  and unproven on a disc" through everything above, because §1.3 was written
  after the first disc had been ejected and the disc-present half had never
  executed once. Step 13 has now run all four of its boxes against the disc §20
  burnt: `find_cd` took the `cddafs` route with a real node, the picker row came
  off the real mount with the right count, `--check` printed a `✓` and a path,
  and **D17's premise is an assertion rather than a reading taken by hand.** The
  empty-drive half and the real `mount` table — which turned out to hold two
  non-device lines the parser had never been shown — were already exercised
  before it.
- **~~The disc macOS cannot name~~ — burnt, mounted, and read.** This entry read
  "only a differently-pressed disc closes it", and the differently-pressed disc
  turned out to be one this program pressed itself. `/Volumes/Audio CD` came up
  holding `1 Audio Track.aiff` … `13 Audio Track.aiff`, so §4.1's rescue fired on
  real filenames and every `find_cd` branch keyed on the string `Audio Track` has
  seen the string it was written for (step 9). Both kinds of disc have now been
  through the port: the one macOS names, and the one it cannot.
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
- **D43's condition, still open — and now open for a better reason.** §18.28 is
  answered and the narrowed gate is tested against four hand-written captures.
  Step 8 has been run twice. The first time, on a *mounted* disc, cdda2wav failed
  for D44's reason and printed nothing, so both counts were 0 and the two gates
  agreed by both saying nothing. The second time, unmounted, on the disc §20
  burnt, cdda2wav printed the whole lead-in and both counts are 1 — the gates
  agree again, and this time they agree about something. What is still unseen is
  the capture where they differ: a cdda2wav that fails while echoing its own
  `titles` keyword. **What step 8 did establish is that the fallback D43 narrows
  cannot answer this machine anyway** — `cdrecord -vv -toc` on the burnt disc
  reports `CD-Text len: 742` and does not print a single title, so on this drive
  the narrowed gate can only ever choose between one reader that works and one
  that says nothing. That makes D43 cheap insurance rather than a live path, and
  it is worth knowing before spending another disc on it.
- **Gapless off a disc.** This entry read "nothing has yet *played* from a disc",
  and that half is closed: the disc §20 burnt was played in MU/TH/UR, off the
  `cddafs` mount, with the thirteen track lengths right on the screen. What is
  still unproven is the part that was always the hard part — **whether gapless
  survives being read over the drive.** The AIFF the mount synthesises arrives at
  the drive's pace rather than off a local file, and nobody has yet sat through a
  track boundary on this disc listening for the seam.

  **The audio itself, though, has now been through §6's seam tests, and it came
  off this disc.** Tracks 1 and 2 were copied from `/Volumes/Audio CD`, stored
  uncompressed in a zip, and handed to `GaplessMaterialTests`: 706,080 frames,
  the engine's output identical to the concatenation of the two files sample for
  sample, and a join step of 0.000244 against the music's own largest step of
  0.19 — a ratio of 0.0013. That is a third independent argument for the burn
  being gapless, and the only one made at the level of the samples rather than
  the sectors: the write log said the boundaries had no pregaps, the read-back
  TOC agreed, MusicBrainz matched the result to four real pressings, and now the
  decoder says the two tracks join without a step in them. What is left is the
  drive as a *source*, which is a different question from the disc as a record.

  **Cut again off the same disc, the join step is 0.000 exactly** — the same
  706,080 frames, against the music's own largest step of 0.962, a ratio of zero
  to four places. The earlier 0.000244 was one part in 4,096 and belonged to the
  copy rather than to the disc; whatever put it there is not in the tracks. Worth
  knowing how to remake this material, because the zip it wants is a working file
  and working files get cleared out: two tracks off the mount, stored rather than
  deflated, anywhere `MUTHUR_TEST_ZIPS` points.

  ```bash
  cp "/Volumes/Audio CD/1 Audio Track.aiff" "/Volumes/Audio CD/2 Audio Track.aiff" "$D"
  (cd "$D" && zip -0 seam.zip *.aiff)
  MUTHUR_TEST_ZIPS="$D" swift test --package-path MUTHURKit --filter GaplessMaterialTests
  ```
- **~~Anything above the domain layer.~~** This entry said there was no app, no
  picker and no panel, so that "the panel says which source you got" was a value
  on a struct and not something you could look at. All three exist and have for
  some time; the sentence outlived the condition it described. What is still
  unproven above the domain layer is narrower and worth saying instead: the
  panel has never been looked at **with a disc in the drive**, so the SOURCE line
  reading `Audio CD` is still a value on a struct even though every other line
  of it is not.
