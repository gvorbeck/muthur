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
