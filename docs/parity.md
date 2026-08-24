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
  the reasoning and the decision it came from. All eight are settled; §16 lists
  them together so a difference from `player` is never later mistaken for a
  porting mistake.

§17 collects the degraded paths — no network, no drive, a disc that will not
read, a folder with nothing in its tags. §18 is the open list: things in the
script that are not obviously either a feature or a bug, each needing an answer
before the code that would inherit it gets written. Neither is a checklist.

Line numbers are against the source as it stands today. Where a behaviour spans
a comment and the code it explains, both are cited — the comment is usually the
part worth porting.

---

## Status

**0 of 256 boxes.** Nothing below has been ported. No entry in this document
should be read as anything but outstanding.

What exists is the empty frame the domain layer gets written into:

- `MUTHURKit/` — the headless package, one folder per section here: `Record/`
  §3, `Disc/` §1.3 and §4, `Scratch/` §2, `Sleeve/` §5, `Shelf/` §8, `Resume/`
  §7. All six are empty. It is a package and not a folder inside the app target
  so that these suites run without standing up an app, and so that nothing in
  here can import SwiftUI by accident — the moment it can, parity stops being
  testable in isolation.
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
domain layer, is where the first box gets ticked. Nothing in §9–§12 or §14 is
reachable until step 4, and §16 D8 is a constraint on the UI when it arrives,
not work that can be started early.

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
- [ ] No ripping step. The mounted CDDA volume is played as it stands
      (`player:1371`).
- [ ] A data disc is correctly ignored: it is not a `cddafs` mount
      (`player:985`), and its `/Volumes` listing carries neither `Audio Track`
      nor two AIFFs (`player:1006`). It falls out of detection rather than being
      rejected — there is no "this is a data disc" message and there should not
      be one, because from here it is simply a mounted volume like any other.

### 1.4 Accepted audio

- [ ] `.aif .aiff .flac .mp3 .ogg .opus .wav .m4a .wma .ape .alac .mp4`,
      case-insensitive (`player:1046`). Mixed formats in one album are fine.
- [ ] Audio is found at **any depth** under the album directory — a zip
      unpacking to `Album/CD1/…` alongside `Album/scans/…` is read whole and the
      non-audio ignored (`player:1422`).

---

## 2. Zips and the scratch directory

The single most load-bearing piece of hard-won reasoning in the program.

- [ ] Zips unpack to `~/.cache/player/work` (`XDG_CACHE_HOME` respected,
      `PLAYER_WORK` overrides). **Not `$TMPDIR`**: macOS is entitled to reclaim
      `/var/folders/…/T` whenever the disk gets tight and does not care that
      something is playing out of it. A six-hour record on a tight volume can
      simply cease to exist halfway through, and what that looks like from here
      is every remaining track failing to open inside two seconds and the album
      quietly "finishing" (`player:170`).
- [ ] If the cache directory cannot be made or written, `$TMPDIR` is taken
      anyway. A read-only or missing home is a reason to accept the worse
      directory, not a reason to refuse to play a record (`player:196`).
- [ ] One `mktemp -d "$base/player.XXXXXX"` per session. `rm -rf` is only ever
      pointed at a path this process created (`player:241`).
- [ ] The session's pid is written to `$WORK/pid` **before anything else goes
      in** — until that file exists the directory is indistinguishable from an
      abandoned one (`player:243`).
- [ ] Startup sweep of `$base/player.*` (`player:207`):
  - a directory whose pid does not answer `kill -0` is removed;
  - a directory with no pid file is removed only if older than 5 minutes, so a
    player starting this instant is not swept by one starting the next;
  - a directory containing `keep` is never swept — somebody asked for it.
  - Two decks at once is allowed, and the second must not delete the first
    one's album out from under it.
- [ ] Teardown on **every** exit path — clean quit, `die()`, Ctrl-C, SIGTERM
      (`player:285`, `player:324`).
- [ ] Teardown order: screen first (so a message below lands on a terminal that
      can show it), then the player process, then any background analysis, then
      the directory. Nothing in the handler may be skipped because something
      earlier in it failed (`player:293`).
- [ ] `PLAYER_KEEP` set → the directory survives, is marked with a `keep` file so
      the next session's sweep spares it, and its path is printed to stderr
      (`player:313`).
- [ ] The **whole** zip is unpacked, not just the audio, so the cover art comes
      along (`player:1181`).

### 2.1 Fit, before a byte is written

- [ ] Uncompressed size is asked of the archive and compared against free space
      **before** unpacking starts. A lossless record is two to three times its
      zip; finding out afterwards means a half-unpacked album and a disk with
      nothing left on it (`player:1381`).
- [ ] Headroom margin: 32 MiB (`33554432`). A record that only just fits must not
      leave the volume at zero — an album is not worth wedging a Mac for.
- [ ] Failure message names the unpacked size, the free space, and
      `PLAYER_WORK` as the way out.

### 2.2 Unpacking, and its failure taxonomy

- [ ] `bsdtar` (`/usr/bin/tar` on any Mac) is preferred; `unzip` is the fallback.
      Apple's `unzip` runs a UTF-8 name through a conversion to the local charset
      first, so a decomposed `ô` — which is how a Mac writes `Hôtel` — comes out
      as two bytes no filesystem will take, and `unzip` reports that as exit 50,
      the same code it uses for a full disk (`player:256`). **On a Swift port
      this is the argument for reading the zip directly rather than shelling out
      to either.** Whatever does the work must take the archive's name bytes as
      the archive stores them.
- [ ] Encrypted archives are refused with one sentence, not a prompt. The bash
      version hands `tar` a passphrase it will certainly not accept and `unzip`
      an empty one, purely to turn a hang nobody can see into an error
      (`player:267`, `player:1339`).
- [ ] Progress is per entry, driving the loading meter (`player:1290`).
- [ ] **One bad entry is not a bad album.** A resource fork or a corrupt booklet
      scan is skipped and the record still plays; something wrong with the
      *archive*, or an archive that yielded nothing, ends it (`player:1298`).
- [ ] Disk-full is asked of the **disk**, never inferred from an exit code. That
      inference is exactly what once put "ran out of room" on a screen with a
      hundred gigabytes free (`player:1226`, `player:1350`).
- [ ] Distinct messages for: out of room, encrypted, truncated, not-a-zip,
      unreadable, source vanished mid-unpack, interrupted (`player:1230`).

---

## 3. Metadata and ordering

- [ ] One metadata read per file for: duration, track, disc, title, album,
      artist, album_artist/albumartist, date/year/originalyear (`player:1426`,
      `player:1439`).
- [ ] A file whose duration cannot be read is **skipped, not fatal** — one bad
      track in a zip, and eleven good ones are still an album worth playing
      (`player:1443`, `player:1445`).
- [ ] `track`/`disc` tags of the form `3/12` keep the part before the slash.
      Leading zeros are base ten, not octal — taggers write `08`, and bash reads
      a leading zero as octal and rejects `08` outright (`player:1447`,
      `player:1451`, `player:1466`).
- [ ] Missing track number → sort key 9999, so tagged files keep their album
      order regardless (`player:1451`).
- [ ] Missing disc number → 1 (`player:1452`).
- [ ] **CD only:** with no track tag, the number comes off the leading digits of
      the filename macOS gave it (`1 Audio Track.aiff`). This matters more than
      ordering — CD-Text and MusicBrainz both answer in track numbers, and
      without it every one of them would be applied to the wrong row, because a
      plain sort puts track 10 between 1 and 2 (`player:1454`, `player:1459`).
- [ ] Tab, newline and CR are flattened to a space in every text tag, once, on
      the way in — a newline bends the frame the width code works to keep square,
      and a tab is the separator every record in the resume file is split on
      (`player:1468`, `player:1472`).
- [ ] Durations round **up**, never down: a track that ends before the meter says
      it does looks like a skip (`player:1478`, `player:1480`).
- [ ] Title falls back to the file's basename (`player:1481`).
- [ ] Album/album-artist/year are taken from the first file that carries them.
      Album artist falls back to artist. Year is truncated at the first `-`, so a
      full ISO stamp becomes a year (`player:1485`, `player:1486`,
      `player:1488`).
- [ ] Album falls back to the folder or zip's own name minus `.zip`, which is
      nearly always the album (`player:1496`, `player:1497`).
- [ ] **Ordering: disc, then track number, then a natural (`sort -V`) filename
      sort** — the last of the three only ever separating files that share key
      9999 (`player:1501`, `player:1504`). Order comes from metadata, not
      filenames. Not negotiable.
- [ ] `TOTAL` is the sum of the ordered durations (`player:1513`).
- [ ] Nothing may index a track number as `n - 1`. CD-Text and MusicBrainz answer
      in track numbers while the arrays are in scan order, and those are not the
      same thing — there is an explicit track-number → row lookup
      (`player:1518`, `player:1521`).

### 3.1 Ordering, exactly

Written out in full because the interesting cases are the degenerate ones, and
they are three lines of `sort` flags in the script.

- [ ] **Scan order** is `find "$AUDIO_DIR" -type f \( "${AUDIO_GLOB[@]}" \) |
      LC_ALL=C sort` — byte order, not locale order, so the scan is the same on
      any machine (`player:1492`). The pre-count that drives the loading meter
      uses the identical `find` (`player:1422`), and zero results is
      `no audio in <source>` (`player:1423`).
- [ ] **The sort key is a three-column tab-separated record**, `%04d` disc,
      `%04d` track, basename, then the scan index as the payload
      (`player:1509`). Sorted `-k1,1n -k2,2n -k3,3V` and `cut -f4`
      (`player:1511`). The `%04d` matters: it is what makes the *fallback*
      ordering stable even where the numeric flags are not consulted.
- [ ] **Missing track numbers** all land on 9999 together and are then separated
      among themselves by the natural filename sort — `track2.flac` before
      `track10.flac`, which a plain sort would reverse. Tagged files are
      unaffected, because 9999 sorts after every real track number
      (`player:1451`, `player:1501`).
- [ ] **Duplicate `(disc, track)`** — two files both tagged track 3, which is
      what a folder holding `03 Song.flac` and `03 Song (alt take).flac`
      produces — is **not** an error and does not stop anything. The pair falls
      through to the natural basename sort and is ordered by name; the album is
      one track longer than the tags claim and both copies play
      (`player:1511`). Port this as-is. A record that plays a bonus take twice
      in a row is self-evidently what is happening; a record that refuses to
      play is not.
- [ ] **`row_of_track` returns the first match**, so with a duplicate track
      number the CD-Text or MusicBrainz title for track 3 lands on whichever of
      the two sorted first, and the other keeps whatever it had
      (`player:1521`). See §18 — the function name says "row" and the value is a
      *file index*.
- [ ] **A file that is unreadable still counts** toward the loading percentage:
      `n` is incremented on the skip path as well (`player:1445`). "READING ·
      80%" can therefore count files it did not read. Cosmetic; §18.
- [ ] **Nothing is ever sorted by filename alone.** Where the script has to fall
      back that far it is because two files agreed on both numbers, and that is
      already a broken tagging job. Not negotiable, per `spec.md`.

---

## 4. Where the titles came from

Four sources, tried in order of trust, and **the panel always says which one you
got**. A track list is only as good as its source, which is why it is on screen
rather than in a log (README, `player:2054`).

- [ ] `tags` — embedded metadata. The normal case, and the only source a folder
      or a zip ever has (`player:1417`).
- [ ] `CD-Text` — read off the disc's lead-in (`player:2251`).
- [ ] `MusicBrainz` — looked up by disc ID (`player:2253`).
- [ ] `track numbers` — nothing could say (`player:2237`), and the panel says
      `no titles on this disc` (`player:2254`).

### 4.1 CD default

- [ ] Before anything is asked, every title matching `*Audio Track*` becomes
      `Track %02d` from its track number, so a failure below still leaves a tidy
      list rather than filenames (`player:2240`).
- [ ] Album falls back to the volume name — the basename of the mount point
      (`player:2248`).

### 4.2 CD-Text

- [ ] `cdda2wav dev=… -J -v titles`, falling back to `cdrecord dev=… -toc -v`
      (`player:2070`).
- [ ] Both printed shapes are matched: `Track  1 title: 'X' from 'Y'` and
      `Track  1 title: 'X'`. **The quote that ends a value is the one before
      ` from '` or the one at the end of the line — not simply the next one
      along.** Matching to the next one along cuts `Don't Stop Me Now` down to
      `Don`, and there is no way to tell that from a disc that really is called
      that (`player:2058`).
- [ ] A title that does not match a known shape leaves the tidy `Track 07`
      alone rather than blanking it (`player:2092`).
- [ ] **An album title on its own does not count as CD-Text.** Returning success
      for one would stamp `CD-Text` on the faceplate over a column of bare track
      numbers *and* rob the disc of the MusicBrainz lookup that could have named
      them. Album/artist found this way stay put either way; MusicBrainz
      overwrites what it knows better and leaves the rest alone (`player:2106`).

### 4.3 MusicBrainz

- [ ] Disc ID to spec: SHA-1 over first track, last track, lead-out offset and
      all 99 track offsets as uppercase hex; base64; then `+/=` → `._-`
      (`player:2123`, `player:2163`). Offsets are TOC frames plus the 150-frame
      pre-gap.
      It fingerprints the *pressing*, which is why it tells the 1984 CD from the
      2011 remaster with the bonus tracks. **`libdiscid` replaces the cdrecord
      TOC parse; the resulting ID must match.**
- [ ] Lookup `…/ws/2/discid/<id>?fmt=json&inc=recordings+artist-credits`
      (`player:2181`).
- [ ] **The User-Agent is not optional and not decoration.** MusicBrainz requires
      an identifying one and blocks generic ones; the script sends
      `player/1.0 ( https://github.com/gvorbeck )` on **all three** requests it
      makes — the release search (`player:1827`), the Cover Art Archive fetch
      (`player:1915`) and the disc-ID lookup (`player:2180`). Port it with the
      app's own name and version and a URL that resolves —
      `MUTHUR/<version> ( <contact url> )`. One string, set once, used by every
      request the app makes.
- [ ] **Timeouts are per-endpoint and deliberately different:** disc ID 12s
      (`player:2180`), release search 15s (`player:1827`), cover art 25s
      (`player:1915`). The cover gets the longest because it is a redirect chain
      to an Internet Archive node and nothing is waiting on it (§5); the disc ID
      gets the shortest because the panel is.
- [ ] Nothing is retried on a **timeout**, only on an empty answer, and only for
      the searches — see §5.3 and §5.2. The disc-ID lookup is asked exactly once
      (`player:2180`): it either resolves or the track numbers stay.
- [ ] **Take the medium matching the disc ID that was asked about**, not every
      medium on the release. A release is one entry per disc in the box, so
      taking them all concatenates disc two's track list onto disc one's
      (`player:2194`, `player:2201`).
- [ ] A release with one medium and no disc IDs listed is still that medium —
      a single-disc answer is worth taking on its own (`player:2204`,
      `player:2206`).
- [ ] Release title, artist credit and date overwrite album/artist/year when
      present — and only when present, so a lookup that answers with half an
      answer does not blank the other half (`player:2213`).
- [ ] Titles are written **through the track-number → row lookup**, and the
      source is only stamped `MusicBrainz` if at least one title actually landed
      (`player:2223`, `player:2228`). An answer with an empty track list is a
      failure, not a success with nothing in it.
- [ ] The release MBID is kept for the sleeve — a disc ID resolves to one
      release exactly, which is the strongest identification anything here ever
      gets (`player:2190`, `player:2193`).
- [ ] Every failure — no network, an unsubmitted disc, a rate limit, malformed
      JSON — means the same thing: the track numbers stay and the panel says so
      (`player:2171`). There is no error, no retry prompt and no diagnostic; the
      one place any of this is ever reported is `--check` (§11).
- [ ] Skipped entirely under `--no-mb` / `PLAYER_MB=0` (`player:2176`), and with
      no `curl` (`player:2177`) or no `jq` (`player:2186`, `player:2210`) — all
      three land in the same place as a failed lookup.

### 4.4 Multi-disc sets

Handled, but thinly, and the thin parts are worth knowing before they are
rebuilt.

- [ ] **A disc in the drive is one disc.** The medium is picked out of the
      release by the disc ID that asked the question, so disc two of a box set
      gets disc two's titles (`player:2194`, `player:2201`). Bracketed and
      indexed rather than `select`-piped, because one medium carries several disc
      IDs for the same pressing and `select` would emit it once per ID
      (`player:2198`).
- [ ] **A folder or zip holding a whole set is one album.** `find` reads at
      unlimited depth (`player:1492`), so `Album/CD1/` and `Album/CD2/` come back
      as one record, ordered disc-then-track by `DISCNOS`/`TRKNOS`
      (`player:1509`). This is right: a two-CD album is an album, the album meter
      shows the whole thing in proportion, and gapless carries across the
      boundary. It is also the case D7 fixed in the picker (§1.2) — the count
      used to stop at depth 1 and so reported such a folder as empty.
- [ ] **Disc numbers are the only thing separating the two halves.** A rip whose
      `CD2` files carry no disc tag lands every one of them on disc 1 and
      interleaves the two discs by track number. Untagged is untagged; the script
      does not infer a disc number from a directory name and neither should this.
      Flagged in §18 rather than fixed.
- [ ] **`.releases[0]` is arbitrary.** Album, artist, date and the release MBID
      all come off the first release in the answer (`player:2187`), while only
      the *medium* is chosen by disc ID. A disc ID that resolves to several
      releases — a reissue sharing a pressing, which is the common case for a
      box set — therefore takes its album name and its cover-art key from
      whichever one MusicBrainz listed first. §18.

---

## 5. The sleeve

Resolution order, and it is deliberate (`player:2004`, `player:2005`):

- [ ] **1. A picture beside the record** — searched first and preferred to the
      network, because it is the artwork *this copy* shipped with, where the
      archive can only offer a scan of whichever release the album *name*
      matched, and the name is the weakest thing there is to match on
      (`player:1942`, `player:2020`).
- [ ] **2. A picture in the tags** — the attached-pic stream. Mapped as "every
      video stream less the ones that are really video", or a music video sitting
      in the folder has its opening frame pulled out and hung beside the panel as
      a sleeve (`player:1973`, `player:1985`). Copied, not re-encoded — whatever
      was in there at whatever size. Only the first **three** tracks are asked: a
      record that tags its artwork tags it on track one (`player:2025`).
- [ ] **3. The Cover Art Archive**, in the background, cached (`player:1903`,
      `player:2035`).
- [ ] Nothing ever waits for it. No cover, no network, no window — the panel is
      exactly the panel it would have been (`player:1892`, `player:2035`). The
      fetch is backgrounded and nothing ever joins it; the picture appears when
      it appears, or never, and either way the record is playing.

### 5.1 Ranking pictures beside the record

- [ ] `find -maxdepth 3` over `jpg jpeg png webp gif bmp tif tiff`
      (`player:1925`, `player:1951`) — deeper than the picker's scan and
      shallower than playback's, because a sleeve turns up in `Scans/` or
      `Artwork/CD1/` but not at the bottom of an arbitrary tree.
- [ ] Names folded: separators → spaces, so `front-cover` is a front cover and
      `discovery` is not a disc (`player:1956`).
- [ ] **Thrown out, not ranked last:** `back inlay booklet tray obi spine label
      matrix inside thumb thumbnail`, and `disc|cd|dvd` with optional digits.
      Drawing one of those confidently beside the panel is worse than the network
      answer it displaced.
- [ ] Rank 1 exact `cover|front|folder|album|albumart|artwork|sleeve`; rank 2 the
      word `cover`/`front` anywhere as a word; rank 3 the substring; rank 4
      anything else — which is what it takes to find the `Artist - Album.jpg` a
      Bandcamp download leaves you. Ties break on shallowest path
      (`player:1952`, `player:1961`).
- [ ] Anything under **200 px** on a side is skipped as a thumbnail or a label
      logo (`player:1949`). Applies to local files and embedded art, not to the
      archive, which only ever sends one size.

### 5.2 Validation and caching

- [ ] **Whether a decoder can read the bytes is the only test worth making.** The
      Cover Art Archive redirects to Internet Archive nodes, and a sick one has
      been seen serving an nginx error page under a 200 — labelled
      `image/jpeg`. Neither the status line nor the content type can be believed
      (`player:1858`).
- [ ] Cache under `~/.cache/player/art` (`player:2028`, `player:2030`), keyed on
      the release MBID when there is one, otherwise artist+album folded to
      lowercase alphanumerics so the same
      album tagged two slightly different ways lands on one file (`player:1783`).
- [ ] Downloaded to a `.part` beside the cache entry and moved onto it, so a file
      in the cache is always a whole one. The part file is named after the album,
      not the process, so a killed fetch leaves one file the next attempt
      overwrites rather than a new one every time (`player:1896`).
- [ ] Up to 5 candidate releases, each tried **twice** — a first failure is more
      often a sick archive node than a missing cover, and the redirect lands
      elsewhere next time (`player:1913`).
- [ ] A record with no cover is remembered in a `.none` marker, **expiring after
      14 days**, so an album with no scan does not cost two network lookups every
      single time it is played, and a cover uploaded in the meantime still turns
      up (`player:1879`).
- [ ] A cache entry that will not decode is one that will not decode next second
      either — stop asking. Cleared, not deleted: another player may be part way
      through writing it (`player:3162`).

### 5.3 Searching by name (no disc ID)

- [ ] Quoted-phrase Lucene query, `artist:"…" AND release:"…"`, limit 5. Strict
      on purpose: asked for an artist and an album that do not belong together
      the catalogue answers with nothing rather than with its best guess, and a
      wrong cover drawn confidently beside the panel would be worse than none
      (`player:1803`).
- [ ] Terms are URL-encoded, and quotes are stripped out of them first — they
      are the syntax that holds the phrase together (`player:1809`).
- [ ] Asked **twice**, a second apart. An empty answer is at least as often the
      rate limiter or a timed-out search index as it is the catalogue
      (`player:1815`).
- [ ] Retry ladder for folder-name albums (`player:1842`):
  1. album as tagged;
  2. brackets and parens stripped, underscores collapsed — `Comfort Eagle
     (1998) [FLAC]`, `OK_Computer_(Remastered)`;
  3. `Artist - Album` split, **only** when no album-artist tag stands to
     contradict it.

---

## 6. Playback

- [ ] **Gapless is a requirement.** The whole record is handed to the engine at
      once, in panel order, so it can read ahead into the next file while the
      current one is still playing. A file opened at the moment the previous one
      ends is a file being opened during the silence (`player:2453`).
- [ ] Gapless must bridge a boundary **even when the two files disagree on sample
      rate or channel layout** — mpv's "weak" default does not, and a folder with
      one 48k track in it is exactly the album you would notice the gap on
      (`player:2481`).
- [ ] Row index and playlist index are the same integer, deliberately
      (`player:3239`).
- [ ] **One source of truth for what is playing.** Nothing assumes a track
      change; it is asked for and waited on. A track that simply ran out and a
      track picked with the cursor arrive by the same route, so a track started
      by hand and one started by the record itself cannot come to disagree
      (`player:2461`, `player:3265`).
- [ ] Sequential auto-advance is left alone — it is already right and already
      gapless. Only shuffle interrupts it, and interrupting costs the seam, which
      is the trade shuffle makes by its nature (`player:3437`).

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
- [ ] `p` behaves like every deck ever made: within the first 3 seconds it goes
      to the previous track, after that to the start of this one. On track one it
      always restarts (`player:3457`). Under shuffle, "the previous track" is the
      one you actually heard — see §6.1b.
- [ ] **Changed from bash (D3).** `n` under REPEAT TRACK **advances**, and the
      mode stays on so the track it lands on is the one that then loops. In bash
      it restarted the current track instead (`player:3414`), which the comment
      there explains as mechanism — setting the playlist position to the row it
      is already on is a no-op — rather than as intent. Repeat-track governs what
      happens when a track runs out on its own; `n` is you saying otherwise, and
      a transport key that visibly does nothing reads as a broken one.
- [ ] REPEAT TRACK is the engine's own loop, not a reload on end: a track told to
      start again after it has finished is a file being opened during the
      silence. REPEAT ALBUM stays ours, because it is where shuffle has to be
      asked and one place deciding what follows the last track is easier to be
      sure of than two (`player:2704`, `player:3486`).
- [ ] Shuffle — see §6.1b. **Changed from bash (D4).**
- [ ] Status line messages: `▪ SHUFFLE ON/OFF`, `▪ REPEAT OFF/ALBUM/TRACK`
      (`player:2702`, `player:2704`). `u` takes the resume offer and is bound
      only while there is one (`player:2720`).
- [ ] Starting a track clears the status line — including "end of album", which a
      track starting has just made untrue (`player:3398`).

### 6.1a Volume — new, not in bash (D1)

The script has none, on purpose: it plays at whatever the system is set to
(README, *No sound, but the meters are moving*). A terminal program can defer to
the system that way; an app carrying its own transport, its own faceplate and a
Now Playing widget cannot, because it looks like a deck and a deck has a level.

- [ ] Its **own** output gain, not the system's. Turning a record down must not
      turn a video call down with it — a player that moves the system slider has
      reached outside its own window (`AVAudioEngine` main mixer).
- [ ] The hardware volume keys stay the system's. macOS handles them above the
      app and they never arrive here — nothing to bind, nothing to fight. What
      the media keys owe us is play/pause/next/previous (§14), which is separate.
- [ ] The level survives a quit. A deck left at 3 is at 3 when you come back.
- [ ] Shown on the faceplate, in the chrome amber, not as data.
- [ ] Mute is a state you can see, not a level of zero you have to infer — "no
      sound and I do not know why" is exactly the question the panel exists to
      answer, and §11 answers the other half of it.
- [ ] **The analyser reads the signal before the gain, not after.** A record
      turned down is not a record playing quietly into its own bands: the columns
      would drop, the per-band autoscale (§9) would spend the next few seconds
      hauling them back up, and the panel would end up saying nothing about the
      music and something about the volume knob.

### 6.1b Shuffle — changed from bash (D4)

Bash re-rolls `RANDOM % n` per advance and rejects only the current track
(`player:3423`, `player:3441`, `player:3479`). Three separate consequences, none
of them intended: a track can come round again two tracks later, a track can go
a whole sitting without being played, and — because `p` is still `cur_track - 1`
(`player:3462`) — "previous" under shuffle means the row above in album order,
which is a track you have not heard.

- [ ] A shuffled **order**, not a die roll per advance: one permutation of the
      rows, walked through. Every track plays once before any track plays twice,
      which is what people mean by the word.
- [ ] Switching shuffle on mid-record: the track playing now stays playing, and
      the shuffle covers what is left to hear. Switching it off returns to album
      order from wherever the needle is.
- [ ] When the order runs out, **that is the end of the album** — every track has
      had its turn, which is the honest reading and the one bash could not make.
      Under REPEAT ALBUM it reshuffles instead, and the new order may not open
      with the track that just closed the old one, or the reshuffle is audible as
      a track playing twice in a row.
- [ ] `p` walks back through what was actually played. A history, not `row - 1`.
      `n` at the end of the history resumes the shuffled order rather than
      re-rolling — walking back and forward again should land where you were.
- [ ] Picking a row with `⏎` under shuffle plays it and the order continues from
      there; it does not reshuffle and it does not turn shuffle off.
- [ ] Retained from bash: shuffle interrupts the engine's own gapless
      auto-advance, and interrupting costs the seam — that is the trade shuffle
      makes by its nature (`player:3437`).
- [ ] Retained from bash: falling off the bottom of the list is meaningless under
      shuffle. The engine walks entries in order and ran out of them; the row it
      fell off is the last one by accident (`player:3473`). What ends a shuffled
      record is the order being exhausted, nothing else.

### 6.2 End of album

- [ ] Mode label `FINISHED`, status
      `▪ END OF ALBUM — PRESS Q TO QUIT, ⏎ TO PLAY A TRACK`. The panel says so
      rather than sitting there looking like it hung (`player:3470`,
      `player:3497`).
- [ ] Both meters are parked at **full**, not at the fraction-before-the-end the
      last position report carried (`player:3499`, `player:3501`).
- [ ] The resume entry is cleared — a record heard to the end is not a record you
      are partway through (`player:3493`, `player:3496`).

### 6.3 A track that will not open

- [ ] **The first failure stops the record where it stands.** Left alone, the
      engine walks straight on to the next entry, which for a record whose files
      have all become unreadable means fifty failures in about two seconds and a
      panel saying END OF ALBUM — the same thing it says when a record has simply
      finished. The difference between "you have heard this" and "this is gone"
      is the whole of what the panel is for (`player:3285`).
- [ ] Mode label `STOPPED`, not `PAUSED`: a deck that is paused is waiting for
      you, and this one is not (`player:3308`).
- [ ] The failure pause must not be reported as the space-bar pause
      (`player:2787`).
- [ ] The **whole record is stat-ed**, not the failing file guessed at — the
      interesting case is not a bad rip, it is a whole unpacked album
      disappearing underneath itself (`player:3292`):
  - files missing → `▪ N OF M TRACKS ARE NO LONGER ON DISK`, plus
    `— THE UNPACKED COPY IS GONE. Q, THEN PLAY IT AGAIN` when the source was a
    zip, else `— STOPPED HERE`;
  - files present → `▪ CANNOT READ THIS TRACK · <error> — STOPPED HERE, ⏎ TO TRY
    ANOTHER`.
- [ ] Picking a track by hand clears the failure **and takes off the pause it
      put on** — without the unpause, choosing another track after a bad one
      looks like a second failure: the row changes and nothing plays
      (`player:3273`).
- [ ] While walking off entries behind a failure, the panel stays on the track
      that actually stopped (`player:2811`).

### 6.4 The meters as controls

- [ ] Click the **album** meter → put the needle anywhere in the record,
      whichever track that lands in. The target row is the last one starting at
      or before the point; the remainder is an offset into it (`player:3329`).
- [ ] Click the **track** meter → seek within the track.
- [ ] Click a row to select, click it again to play it. The first click moves the
      cursor and the second starts it, which is the difference between reading
      the list with the pointer and being made to listen to whatever the pointer
      happened to land on (`player:3213`).
- [ ] The wheel walks the track list (`player:3188`).
- [ ] **Changed from bash (D2).** A drag on the album meter crosses track
      boundaries freely — drag the whole length of the record and the needle
      follows. Bash confined a drag to the track it started in (`player:3340`)
      because a drag reports a position per cell crossed and its loop could only
      have one track-change request outstanding at a time; that is a property of
      talking to another process down a socket, not a decision about scrubbing.
- [ ] What survives the lift is the reason underneath it: **do not act on a
      position for a track that is not open yet.** The mechanism differs
      natively, the hazard does not — a drag can outrun the loading of the item
      it has landed in, and the last position the drag reported is the one that
      must take effect when it opens, not the first (see the pending-offset rule
      below).
- [ ] A seek that lands in another track is a track change with the offset left
      **pending** until the new track is genuinely playing. A seek sent alongside
      the move lands in the track being left, not the one arriving
      (`player:3336`). The native equivalent — do not seek an item that is not
      the current item — has to be preserved even though the mechanism differs.
- [ ] Middle and right buttons mean nothing here; answering them with a seek
      would be a nasty surprise (`player:3194`).

---

## 7. Resume

Not in `spec.md`. It is in the program (`player:1529`).

- [ ] Where you had got to is **offered, never applied**. The panel says where it
      left off and waits for `u`. A player that jumps to the middle of side two
      because you played it last week has taken a decision that was yours to
      take, and the one thing you cannot do once it has is un-hear the surprise.
- [ ] The key is what the record *is*, not where it lives: the disc ID when there
      is one, otherwise a hash of album-artist + album + track count + total
      duration. A folder that has been moved, and a zip unpacked into a different
      scratch directory every single run, are both still the same album, and a
      key made out of the path would lose them both (`player:1543`).
- [ ] Stored at `~/.local/state/player/resume` (`XDG_STATE_HOME` respected), tab
      separated, upserted via a temp file and a rename so a player killed halfway
      through a write leaves the old file whole (`player:1579`). Capped at ~200
      other albums.
- [ ] **Not offered** for row 0 at under 30 seconds — that is where the record
      starts anyway, and by the time reading the offer is over you could have
      been there. Anything further in was a real listening session
      (`player:1568`).
- [ ] Offer text: `▪ RESUME AT <track no> · <m:ss> — PRESS U`, shown after the
      first track has started, because starting a track clears the status line
      and this is the one thing on it that has to outlive that (`player:2825`).
- [ ] Written on every track change (before a note of the new track has played,
      so quitting between tracks comes back to the right one) and then every 5
      seconds of position. A file write a second for the length of a record is a
      lot of writing to save a number that is read once, and five seconds is
      inside the margin of where you would say you had got to anyway
      (`player:2772`).
- [ ] Cleared when the record finishes.

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

- [ ] Band centres: `40 59 88 132 197 294 439 655 976 1456 2171 3237 4827 7197
      10731 16000` Hz — even steps in octaves, because that is how the ear
      divides it and how the low end earns enough bands to move independently
      instead of as one lump (`player:109`).
- [ ] Bandpass just over an octave wide (`w=1.1` octaves): enough overlap that no
      frequency falls in a gap, tight enough that neighbours still move
      independently (`player:783`).
- [ ] Column travel is 40 steps (5 rows × 8 eighths) — the range the falling
      trail needs to actually be seen falling. Fewer and a column is at the floor
      before the eye has followed it down (`player:96`).
- [ ] **A column jumps to its new level instantly; only the fall is slowed.** An
      analyser that eased upward would read as a slow analyser, not a smooth one
      (`player:605`).
- [ ] Peak-hold trail: it sinks 2 eighths a frame and dims with age down the
      amber ramp, so it reads as the same light going out. A fast transient stays
      visible for longer than the tenth of a second it lasted (`player:667`).
- [ ] Filled cells are graded **by row, not by band**: the top is brightest, so a
      column that reaches the ceiling *arrives* there rather than merely being
      tall (`player:632`).
- [ ] **Per-band autoscaling, and this is the whole trick** (`player:831`): each
      band is scaled by what *that band* actually does over the track, anchored
      at the **25th and 90th percentile** of its own level distribution, placed a
      quarter and six-sevenths of the way up the column. Not the extremes. A
      record mastered in this century spends its life within a few decibels of
      its own ceiling with a long thin tail down into the gaps between songs;
      scale the tail and every band ends up pinned near the top, twitching —
      which is what this did at first. Throw the tail away and the columns use
      their whole height.
- [ ] Minimum scale width 6 dB, so a band that genuinely does not move — a
      constant hiss, a held tone — stays honestly flat a quarter of the way up
      rather than having its own noise magnified to fill the column
      (`player:866`).
- [ ] Digital silence is floored at −90 dB, not treated as 0 dB — which is the
      loudest thing there is (`player:819`).
- [ ] **It stops dead when there is no sound**, and the test is "is anything
      coming out" rather than "is it paused". A record that has finished, a track
      that would not open, a buffer still filling — all of them are silence, and
      columns dancing over silence is the panel lying about what you are hearing
      (`player:740`, `player:736`).
- [ ] The idle state is a floor row lit, not a blank panel — blank is what a
      broken one shows (`player:697`, `player:699`).
- [ ] Columns reset at every track change; carrying the last track's heights into
      the next one reads as a glitch (`player:3389`).
- [ ] Fallback pattern when levels are unavailable: two travelling waves at rates
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

Raised before any code was written, per `CLAUDE.md` — where a decision in
`player` looks wrong, flag it rather than silently improve it. All eight are
settled. Recorded here with the answer so that a departure from the script is
never mistaken later for a porting mistake.

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
- [ ] **The one durable consequence: a purely offline art fetch still writes a
      `.none` marker** (`player:1921`), so an album whose cover was looked for
      during an outage has no cover for the next **14 days**. Listed under §18 —
      it is a bug the port should not carry, but it is a change from the script.
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
- [ ] **Gapless must bridge a format, rate or layout change**, which is the
      §6 requirement restated: this is exactly the album where the seam would
      show (`player:2481`).
- [ ] Per-file decoding is per-file. Natively that means the AVFoundation path
      and the ffmpeg fallback path can be in use in the same record, and the
      transition between two tracks that took different paths still has to be
      gapless.

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

- [ ] The case §2 exists to prevent, and §6.3 exists to explain: fifty tracks
      failing in two seconds must not read as `END OF ALBUM` (`player:3285`).
- [ ] When the source was a zip the message names the cause:
      `— THE UNPACKED COPY IS GONE. Q, THEN PLAY IT AGAIN` (`player:3315`).

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

Found while reading, and not obviously either intended behaviour or a bug.
Nothing here has been ported or "fixed" — per `CLAUDE.md`, a decision in `player`
that looks wrong gets flagged rather than silently improved. Each needs a yes or
a no before the code it describes gets written.

**Probably bugs, but they have shipped and been lived with:**

1. **`.releases[0]` decides the album name.** Title, artist, date and the release
   MBID all come from the first release in the disc-ID answer, while the medium
   is correctly chosen by disc ID (`player:2187`, `player:2201`). A disc ID
   resolving to several releases takes its name — and its cover-art key — from
   whichever MusicBrainz happened to list first. *Match on the release that
   actually contains the matched medium, or keep `[0]`?*

2. **`row_of_track` returns a file index, not a row** (`player:1521`). Harmless
   today because only CD sources call it and a CDDA volume's scan order is its
   track order. It is wrong for anything else, and the name hides that. *Port the
   confusion, or port the intent?*

3. **`collection_lookup`: the last duplicate row silently wins.** The END rule
   accepts multiple hits whenever an album artist is present
   (`if hits==1 || (hits>1 && want_a!="")`, `player:1706`) while the awk body
   overwrites its variables on every match — so two rows for the same
   artist+title give you the later one, with no indication there were two.
   *Prefer the first? Refuse ambiguity the way the no-artist path already does?*

4. **`art_fetch` caches "no cover" after a purely offline attempt**
   (`player:1921`). Fourteen days of no sleeve because the wifi was off once.
   *Distinguish "asked and there is none" from "could not ask"?* My instinct is
   yes, and it is a two-line change.

5. **`unpack_unzip` never checks that anything came out** (`player:1315`), where
   `unpack_tar` has `[ "$n" -gt 0 ] || die "nothing came out of …"`
   (`player:1308`). An `unzip` that exits 0 having written nothing produces `no
   audio in <source>` from a later function instead of the accurate message.

6. **`find_cd`'s `/Volumes` fallback accepts any volume with two AIFFs** once
   `drutil` reports media (`player:1009`). With a disc in the drive and an
   AIFF-heavy external volume mounted, the external one can win, and then CD-Text
   and MusicBrainz answers about the disc get applied to it.

7. **The picker counts CD tracks with `ls | grep -ic '\.aiff\?'`**
   (`player:1019`) rather than `audio_count`. A CDDA mount presenting anything
   other than AIFF would show `0 tracks` in the row it is being offered by.

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
    is not the whole truth. *Keep as-is?* I would.

12. **The `READING · N%` counter includes files it skipped** (`player:1445`).
    Cosmetic and arguably correct: it is progress through the folder, not
    progress through the album.

13. **`resume_save` caps the file at 200 entries with `tail -200`**
    (`player:1588`). An undocumented history limit that behaves as a
    least-recently-*written* eviction. Almost certainly fine; worth being a
    deliberate number rather than an inherited one.

14. **No disc number is inferred from a directory name.** `Album/CD2/` with
    untagged files interleaves into disc 1 (§4.4). The script never claims
    otherwise, and inferring structure from folder names is exactly the kind of
    guess the metadata-not-filenames rule exists to forbid — but a two-disc rip
    with no disc tags is common enough to ask about.

**Genuinely unclear what it is for:**

15. **`UNTAGGED`** is set (`player:1451`) and cleared (`player:1463`) and never
    read. It looks like the beginning of an "this album has no tags" notice on
    the panel that was never finished. Already in §15 as vestigial — but if the
    notice was the intention, it may be worth having.
