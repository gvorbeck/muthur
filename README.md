# MU/TH/UR

A native macOS player for whole albums — from a folder, from a zip, or from the
audio CD in the drive. Gapless, metadata-ordered, with the sleeve at real
resolution and a cassette-futurism CRT face.

A port of a bash TUI that lives in another repository and stays there. See
`CLAUDE.md` for the constraints and `docs/spec.md` for what it has to do. Parity
is tracked across three files sharing one numbering: `docs/parity.md` (§1–§15,
§17, and the still-open questions of §18), `docs/decisions.md` (§16, every
deliberate departure from the script, and the answered half of §18), and
`docs/hardware.md` (§19, the procedure to work through with a disc in the drive).

## Status

It builds, installs with `Scripts/install.sh`, and plays records. Parity stands
at **281 of 285 boxes**; the four still open are D8's, on MU/TH/UR as a voice.
§19 is a procedure rather than boxes and is counted separately, at 10 of 33 —
the rest are steps waiting on a disc in the drive. MUTHURKit carries close to
seven hundred tests.
