# MU/TH/UR

A native macOS player for whole albums — from a folder, from a zip, or from the
audio CD in the drive. Gapless, metadata-ordered, with the sleeve at real
resolution and a cassette-futurism CRT face.

A port of two bash TUIs that live in another repository and stay there —
`player`, and now `burncd`, which shares its faceplate. See `CLAUDE.md` for the
constraints and `docs/spec.md` for what it has to do. Parity is tracked across
three files sharing one numbering: `docs/parity.md` (§1–§15, §17, the still-open
questions of §18, and §20), `docs/decisions.md` (§16, every deliberate departure
from either script, and the answered half of §18), and `docs/hardware.md` (§19,
the procedure to work through with a disc in the drive).

## Status

It builds, installs with `Scripts/install.sh`, and plays records. Parity stands
at **307 of 321 boxes**. Of the fourteen still open, four are the ones §14 marks
as blocked on hardware and material — AirPlay's unplug, hi-res output switching,
and an Opus or Ogg file to make the ffmpeg fallback fail on — and ten are §20's
stages 2 and 3, the conversion and the drive. §19 is a procedure rather than
boxes and is counted separately, at 10 of 33 — the rest are steps waiting on a
disc in the drive.

**`burncd` stage 1 has landed**: a folder becomes a burn plan, the plan is cut
across as many discs as it takes and balanced so the last one is not a stub, the
CD-Text that would go in the lead-in is settled and measured, and `B` on the deck
opens the editor that lets a wrong tag be fixed before any of it is written. It
burns nothing yet, and says so. MUTHURKit carries just over seven hundred tests.
