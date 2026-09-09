# MU/TH/UR

A native macOS music player for whole albums — from a folder, from a zip, or
from the audio CD in the drive.

**Read `docs/spec.md` before starting any work on features, playback, or UI.**
It holds the feature parity requirements, the visual design direction, and the
build order. This file holds only what is true in every session.

## Name

Stylized **MU/TH/UR**, after the Nostromo's mainframe in _Alien_ (1979) — the
CRT terminal this app's aesthetic is imitating.

- Bundle directory: `MUTHUR.app` (a `/` is illegal in a filename; Finder
  renders it as `:`)
- `CFBundleName`: `MUTHUR`
- Bundle identifier: `com.gvorbeck.muthur`
- Repository / product / Swift module: `MUTHUR`

Use the slashed form **MU/TH/UR** only where it is drawn as text and never
touches the filesystem: window title, about box, boot/splash sequence, headers
in the UI.

## This is a port, and the original is read-only

The specification is a working 3,568-line bash TUI at

    /Users/garrett.vorbeck/Sites/cd-collection/scripts/player/player

with a 284-line README beside it at

    /Users/garrett.vorbeck/Sites/cd-collection/scripts/player/README.md

**There is a second program, on exactly the same terms.** `burncd` — 2,742
lines at `../burncd/burncd`, with a README beside it — burns a folder to an
audio CD, and it shares `lib/panel.sh` with `player`: the two are one instrument
at two moments of the same disc, which is the whole reason its port lives in
this repository. It is §20 of `docs/parity.md`.

**Never modify anything under `cd-collection`.** Those programs continue to
exist and be used independently — over ssh, in pipes, as a shell command — and
nothing here should assume either will change or disappear.

Do not shell out to either bash script at runtime. Port the logic.

Where any description conflicts with the script, the script is right.

## Stack — already decided

- **SwiftUI**, macOS. Target the current macOS and one version back.
- **AVFoundation** for playback. Gapless across tracks is a requirement.
- **ffmpeg** as a _fallback_ decoder only, for what AVFoundation won't take
  (notably Opus and Ogg).
- **AVAudioEngine tap + Accelerate/vDSP** for the analyser FFT.
- **libdiscid** for MusicBrainz disc IDs.
- Ad-hoc signing. Personal app; no notarization needed.

Ask before adding any dependency beyond these.

## Working notes

- `docs/parity.md` is the definition of done. Keep it current as features land.
- **It is three files, and the numbering runs across all three.** `parity.md` is
  §1–§15, §17, the still-open questions of §18, and §20; it is the only one
  carrying the Status paragraph and the counts. `docs/decisions.md` is §16 —
  every deliberate departure from either script, D1 onwards — plus the answered half of
  §18. `docs/hardware.md` is §19, the procedure to work through with a disc in
  the drive. Nothing was renumbered when they split, so `§16`, `§18.24` and
  `D44` mean in any of the three, and in the source, exactly what they always
  meant. A new decision goes in `decisions.md` and is numbered on from the last
  one there.
- **The Status paragraph is part of ticking a box, not a separate step.** A box
  ticked without the count and the narrative moving with it is a half-done edit,
  not a done feature — it has drifted five times, always the same way. Tick the
  box, re-derive the count by counting the files — the boxes are in `parity.md`
  and, for D8's four, in `decisions.md` — and rewrite the paragraph to describe
  the section that just landed, all in the one pass.

  **A tally written in words is a count and goes stale exactly like a digit —
  but no `grep` will catch it.** "The nine open boxes", "its last ten", "all
  sixty-eight", or any sentence saying what is not written yet. So after the
  count, re-read as English: the Status section entire, the preamble of every
  section the work touched, and this document's front matter. A section's
  preamble is the likeliest, because work lands under it and nothing forces a
  reader back to the top. The structural half — the census living directly under
  the count in `parity.md`, which says *which* boxes those are — is the part
  doing the real work.
- **`README.md` carries the same figure and is part of the same pass.** It had
  drifted two behind and was also still naming the wrong four boxes as the open
  ones, which is the failure above wearing a second hat: one number, written
  down twice, is two numbers the moment only one of them is updated. The Status
  paragraph in `parity.md` is where it is *derived*; `README.md` quotes it, and
  quoting it is not optional.
- Where a decision in `player` or `burncd` looks wrong, do not silently improve
  it. It has been used and debugged. Flag it and ask. The answer, once it is
  given, is a numbered entry in `docs/decisions.md`.
- The script's vocabulary is the personality of the program — a cover is a
  _sleeve_, you put the _needle_ anywhere in the _record_. Use it in the UI, in
  the code, and in comments.
- Comment in the register of the original: explain why, not what.
- **A rule the kernel does not honour is worse than no rule.** When a test or a
  parser asserts a shape the system never promised — a device node always
  looking like `/dev/diskN`, a mount line always having a device on the left,
  a filename always having an extension — the assertion is not strictness, it
  is a guess that will fail on a machine we have not seen. Assert only what was
  observed to be true and what the platform actually guarantees; where neither
  covers it, assert the weak thing (non-empty, present, parses) and say in a
  comment why the tighter rule was not written. This applies to `#expect`, to
  every parse of another program's output, and to any place the port is tempted
  to be tidier than the system it is reading.
