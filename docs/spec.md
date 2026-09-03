# MU/TH/UR — specification

Read this in full before writing code. See `CLAUDE.md` for naming, the
read-only constraint on the source repository, and stack decisions.

## Read the source first — it is the spec

Read `player` end to end before anything else. It is unusually heavily
commented, and the comments are not descriptions of what the code does — they
are the reasoning behind why it does it that way. That reasoning is the most
valuable thing being ported, and it is what a rewrite normally loses and then
rediscovers through bugs.

One example of the kind of thing to look for: zips are unpacked into a scratch
directory under `~/.cache/player/work` rather than `$TMPDIR`, and the comment
explains why — macOS is entitled to reclaim `$TMPDIR` while a long record is
still playing out of it, and it does. Details like that are hard-won. Find them
and carry them across.

Derive the feature list from the source, not from the summary below. The summary
is partial and secondhand.

## Feature parity is the hard constraint

Anything the bash version does, this must do. Known areas, to be verified and
expanded by reading the source:

**Sources.** Play an album from a folder, from a zip without the user unpacking
it first, or from the audio CD in the drive. Accept aiff, flac, mp3, ogg, wav,
m4a, opus — anything ffmpeg reads.

*How you reach one has diverged from the script, deliberately: see **D50** in
`decisions.md`.* The bash picker scans `PLAYER_DIRS` — `~/Music:~/Downloads` by
default — and lists what it finds. **This port does not scan anything.** The
opening screen offers the disc in the drive if there is one, and `BROWSE`
otherwise; a folder or a zip arrives through an open panel, or as an argument on
the command line, and opens by exactly the path a scanned row used to take. The
reason is macOS: reading those two directories at launch fires two TCC prompts,
and ad-hoc signing means they come back on every build, while the open panel goes
through the powerbox and needs no grant at all. Nothing about **what** can be
played changed — only what the program is allowed to go looking for uninvited.

**A record plays when it is opened**, as the script's `append-play` does
(`player:3259`). Not a divergence — it was a gap, and `parity.md` §6.0a is where
it is written down.

**Track ordering** comes from embedded metadata, not filenames. This is
deliberate and is not negotiable.

**CD identification** reads the disc's own table of contents, with a documented
fallback chain: CD-Text when the disc carries it, MusicBrainz when it does not
and the network is up, plain track numbers when neither can say. The UI must
show which of the three it got — the script's rationale is that a track list is
only as good as its source, and that applies here unchanged.

**Artwork resolution** — embedded art first, then network. Read the actual
resolution order in the source and preserve it.

**Transport.** The bash version binds: space to pause, left/right to seek,
shift-left/right to seek further, up/down to walk the track list, enter to play
the track you are looking at, `n` and `p` for next and previous. Preserve every
one of these as keyboard shortcuts.

**The meters are controls, not just readouts.** Clicking the album meter puts
the playhead anywhere in the record, whichever track that lands in. Clicking the
track meter seeks within the track. Preserve this, and add drag-scrubbing, which
the terminal could not do.

**CLI flags become app features rather than disappearing:**

- `--check` becomes a diagnostics screen: can this machine play anything, what
  is missing, what will the cover look like. Keep the spirit — it exists so that
  "why is mine not working" has an answer.
- `-n` (read it, show the album, play nothing) becomes an inspect mode.
- `--no-mb` becomes a setting to skip MusicBrainz.
- `--cd` is just the CD source.
- `PLAYER_ART=0` becomes a setting to hide cover art.

## What going native is for

These features are the justification for this project existing at all. They are
in scope, not stretch goals:

- Real cover art at real resolution.
- Media keys, and the Now Playing widget in Control Center and on the lock
  screen.
- AirPlay and correct audio device route handling — unplugging headphones should
  pause, not blast.
- Output sample-rate switching for hi-res material.
- A Dock icon and its own Cmd-Tab identity. **Not** the album art in the Dock
  while playing: that was asked for here, built, and then withdrawn once it was
  seen — the Cmd-Tab switcher draws from the same tile, so the cover cannot go in
  one without going in the other, and a constant icon is what the app is found
  by. See `decisions.md` D49. The sleeve goes to Now Playing instead.

## Visual design: cassette futurism

The app should look like a terminal screen — but a terminal from a future
imagined in about 1982. Cassette futurism / 80s retro-futurism, executed
seriously rather than as pastiche.

**Reference points:** the Nostromo's displays in _Alien_, the Esper machine in
_Blade Runner_, 1980s hi-fi separates (Nakamichi and Technics tape decks
especially), Braun and Dieter Rams industrial design, early Macintosh,
laboratory oscilloscopes and spectrum analysers.

**The vocabulary:**

- Monospace type throughout. CRT phosphor palette — amber or green as the
  primary, used with restraint.
- Subtle scanlines, a faint vignette, gentle screen curvature. Emphasis on
  _subtle_: atmosphere, not a filter applied on top.
- **The tube is old _and slightly failing_** (D52). Not merely aged: a soft band
  walks down the raster every several seconds, and the wordmark loses its line
  for a tenth of a second every minute or so. Rare, faint, brief — thirty years
  of service, not a machine coming apart. Neither fault may cost a character of
  legibility and neither may move the layout.
- Chunky beveled hardware panels around the screen area — the physical chassis
  the CRT is mounted in. **All four of its screws are on screen**, and no two sit
  at the same angle — hand-tightened, by fixed constants and never at random: a
  screw that finds a new angle on redraw reads as a bug rather than as a fixing.
- **The sleeve tells the truth under the pointer.** Hovering the cover takes
  every effect off it — the phosphor quantisation, the veils, the falling band —
  and leaves the artwork the record actually came with. Off the cover it goes
  back the way it came, on a fade and not a snap.
- VU meters with real needle ballistics, not linear bars.
- Segmented LED / nixie-style numerals for time and track numbers.
- Tape-deck transport controls with mechanical weight to them.
- Dot-matrix or bitmap-derived lettering for labels and headers.

**Treat the character grid as a design grid, not a constraint.** The bash
version's layout arithmetic — where the sleeve starts, how tall it may be, where
the analyser goes — exists because a terminal has cells. Keep the visual rhythm
that produced; drop the constraint where it only ever existed because of the
terminal. The cover art in particular is no longer limited to a column range.

**Restraint rules.** Readability wins over effect, every time. No gratuitous
flicker or animated noise — the two faults above are the entire budget for
movement, and they are spent where they cost nothing to read. Both are gated:
they run only while a record is playing and the window is on screen, Reduce
Motion holds them still, and `MUTHUR_CRT=0` holds them still for anyone who
wants the tube steady without turning the whole system's animation off. Honor
Reduce Motion and Reduce Transparency. The retro treatment has to survive being
looked at for an hour of listening.

## Open question — do not decide unilaterally

Whether MU/TH/UR-the-mainframe becomes an interaction conceit — a computer that
answers you — or stays purely a name on a chassis.

The diagnostics screen is the one place it would genuinely fit: the script's own
rationale for `--check` is that "why is mine not working" deserves an answer,
and a terminal that answers in the voice of a ship's computer serves that rather
than decorating it.

Raise this before implementing either way. The failure mode to avoid is an app
that makes you read dialogue before it will play a record.

## Build order

1. **Feature inventory** derived from reading the source. Write it to
   `docs/parity.md` as a checklist, and **stop for review before writing code** —
   this is the artifact parity gets measured against. *(It has since split in
   three: `docs/decisions.md` holds §16 and the answered questions of §18,
   `docs/hardware.md` holds §19. The numbering runs across all three.)*
2. **Domain layer, headless, with tests** — disc TOC reading, the CD-Text →
   MusicBrainz → track-numbers fallback chain, metadata-based track ordering,
   artwork resolution, zip handling and its scratch-directory behavior. This is
   where the real logic lives and where parity is won or lost.
3. **Playback engine** — AVFoundation, gapless, with the ffmpeg fallback path.
4. **The UI last**, so that it is shaped by the model rather than the reverse.

Do not start on the visual design until 1–3 are working. It is the most enjoyable
part and the least load-bearing, and building it early will distort the model
underneath it.
