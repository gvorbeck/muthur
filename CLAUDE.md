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

**Never modify anything under `cd-collection`.** That program continues to exist
and be used independently — over ssh, in pipes, as a shell command — and nothing
here should assume it will change or disappear.

Do not shell out to the bash script at runtime. Port the logic.

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
- Where a decision in `player` looks wrong, do not silently improve it. It has
  been used and debugged. Flag it and ask.
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
