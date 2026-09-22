```
╔══════════════════════════════════════════════════════════════╗
║ ▓▒░                                                      ░▒▓ ║
║                                                              ║
║       █   █ █   █     █ █████ █   █     █ █   █ ████         ║
║       ██ ██ █   █    █    █   █   █    █  █   █ █   █        ║
║       █ █ █ █   █   █     █   █████   █   █   █ ████         ║
║       █   █ █   █  █      █   █   █  █    █   █ █  █         ║
║       █   █  ███  █       █   █   █ █      ███  █   █        ║
║                                                              ║
║   ░░▒▒▓▓██  AUDIO INTERFACE · BURNER · IMPORTER  ██▓▓▒▒░░    ║
║                                                              ║
║   > SYSTEM READY                                             ║
║   > INSERT RECORD_                                           ║
║ ▓▒░                                                      ░▒▓ ║
╚══════════════════════════════════════════════════════════════╝
```

A macOS music player for whole albums, a CD burner and a CD importer, dressed
as the ship's-computer terminal from *Alien* (1979).

- Plays a **folder**, a **zip**, or the **audio CD** in the drive
- Gapless, in the order the tags say
- Burns an album to audio CD, across as many discs as it needs
- **Imports the disc in the drive** — FLAC by default, tagged and sleeved
- Amber phosphor, scanlines, dot-matrix readouts

It is a port of two bash programs, `player` and `burncd`, which live in the
`cd-collection` repo and are not changed by this one.

**Needs:** macOS 15 or later, Apple silicon or Intel.

░░▒▒▓▓██████████████████████████████████████████▓▓▒▒░░

## ▓▒░ INSTALL

Pick one.

### ▸ A. One command (new machine)

```bash
curl -fsSL https://raw.githubusercontent.com/gvorbeck/muthur/main/Scripts/bootstrap.sh | bash
```

Installs `ffmpeg` and `cdrtools` if missing, then the latest release. Needs
[Homebrew](https://brew.sh) already installed. No password asked.

### ▸ B. By hand

1. Download `MUTHUR.zip` from
   [Releases](https://github.com/gvorbeck/muthur/releases), unzip, and drag
   `MUTHUR.app` to `/Applications`.
2. Run these:

   ```bash
   xattr -dr com.apple.quarantine /Applications/MUTHUR.app
   ```

   ```bash
   brew install ffmpeg cdrtools
   ```

> **▓ WARNING ▓** Don't skip the `xattr` line. Without it, macOS says the app
> is "damaged". It isn't. The app just isn't notarized.

### ▸ C. From this repo (needs Xcode)

```bash
brew install ffmpeg cdrtools
```

```bash
Scripts/install.sh
```

## ▓▒░ UPDATE

1. **Quit MU/TH/UR.**
2. Run the same install again. From source: `git pull`, then
   `Scripts/install.sh`.

Check the version at the top of the window, next to the logo.

░░▒▒▓▓██████████████████████████████████████████▓▓▒▒░░

## ▓▒░ OPERATE

```
┌─────────────────────────────────────────────────────────────┐
│ ▓▒░ CONTROL LEGEND                                          │
├─────────────────────────────────────────────────────────────┤
│  [CMD+O] OPEN FOLDER / ZIP     [ n ] NEXT TRACK             │
│  [SPACE] PAUSE                 [ p ] PREVIOUS TRACK         │
│  [ ← → ] SEEK 5s (SHIFT 30s)   [ s ] SHUFFLE                │
│  [ ↑ ↓ ] MOVE CURSOR           [ r ] REPEAT                 │
│  [ RET ] PLAY THAT TRACK       [- =] VOLUME DOWN / UP       │
│  [  u  ] RESUME (WHEN OFFERED) [ m ] MUTE                   │
│  [  b  ] PLAN A BURN           [ e ] EJECT CD               │
│  [CMD+K] HEALTH CHECK          [ q ] STOP                   │
└─────────────────────────────────────────────────────────────┘
```

Click the meters to jump around in the track or the album.

### ▸ Burning a CD

```
┌────────────────────────────────────────┐
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│  SIDE A  ░  MU/TH/UR  ░  C-80 BLANK    │
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│     ┌────────────────────────────┐     │
│     │  (O)   ░▒▓██████▓▒░   (O)  │     │
│     └────────────────────────────┘     │
│                                        │
└───────/ o ────────────────── o \───────┘
```

1. Open an album.
2. Press `b` to see the burn plan. Fix any titles here.
3. Set options in the **Burn** menu. They reset every launch.
4. Press `b` again. It asks for a blank before anything happens.

> **▓ TIP ▓** Try **Burn ▸ Rehearse** first. It does everything except turn
> the laser on.

### ▸ The two extra tools

| Tool | Used for | Without it |
|---|---|---|
| `ffmpeg` | Opus/Ogg files, and burning | Those files won't play; no burning |
| `cdrtools` | Burning, and reading CD-Text | No burning; CDs show fewer names |

They aren't bundled into the app because of licensing and Intel/ARM builds.
Health Check (⌘K) tells you if one is missing.

░░▒▒▓▓██████████████████████████████████████████▓▓▒▒░░

## ▓▒░ RELEASE (MAINTAINER)

1. Bump the version: `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in
   `MUTHUR.xcodeproj/project.pbxproj`. Each appears twice. Commit and push.
2. Make sure `gh` is on the right account:

   ```bash
   gh auth switch -u gvorbeck
   ```

3. Release:

   ```bash
   Scripts/release.sh 0.4.0
   ```

   You can pass a notes file as a second argument.

The script refuses to run unless the tree is clean, you're on `main`, and
you're pushed. It checks the signature, both architectures, and the version
before uploading.

░░▒▒▓▓██████████████████████████████████████████▓▓▒▒░░

## ▓▒░ STATUS

```
SELF TEST ──────────────────────────────────────────────
PARITY     █████████████████████████████▒  322 / 326
HARDWARE   █████████████████████████▒░░░░   36 / 43
```

The four open parity items need hardware, not code:

- Headphones unplugged → pause (plus AirPlay)
- Hi-res output sample rate
- An Opus/Ogg file that needs ffmpeg
- Resuming a burn at disc 2 (needs two blanks)

Parity counts what the two bash scripts do, so **importing a disc adds nothing
to it** — neither script imports one. It moved the hardware line instead, and
then closed most of what it added: §21 has been run against a real CD, and two
of its three steps are ticked. The third wants a click, not a disc.

The same goes for what the tube does — the strike when a record goes on, the
readouts holding the figure that has just gone, the needle down the run-out, and
now the two old faults getting restless as a record runs out. A terminal has no
raster, so there is nothing there to be parity with. The hardware line stands
exactly where it did.

**The parity line moved by one, and it is the tenth time it has ever moved.** The
latest pass is a settings screen — `,` on the panel, ⌘, in the menu — and it
counts because it is a requirement the window has and the script never did: a
program you start by typing its name takes its settings from the line that starts
it, and a window has no such line. Fourteen switches had accumulated in the menu
bar with nothing behind them, so the format you chose was FLAC again tomorrow.
Now what you set is what you get next time, with one rule: a setting describing
your shelf is remembered, a setting that could make one run behave unlike the run
you are watching is not — which is why Rehearse and Demo are still forgotten at
quit. An environment variable still wins for the launch it is typed on, and is
never written back over what you chose.

The pass before was a read of the whole port rather than a feature: eleven
repairs to boxes that were already ticked. The one worth naming is that a zip
whose last four bytes happened to read like an end-of-archive marker — a
half-finished download, say — took the whole program down rather than being
refused, and it did it during the walk that only asks whether a file is worth
offering. Two of the eleven needed a decision of their own and are D103 and D104.

What to test next, as a checklist: [`TODO.md`](TODO.md).

### ▸ Docs

| File | What's in it |
|---|---|
| [`docs/parity.md`](docs/parity.md) | The checklist, and the full status |
| [`docs/decisions.md`](docs/decisions.md) | Every place this differs from the bash scripts, and why |
| [`docs/hardware.md`](docs/hardware.md) | The step-by-step test with a real drive |
| [`docs/spec.md`](docs/spec.md) | What it has to do |
| [`CLAUDE.md`](CLAUDE.md) | Rules for working on it |

```
░▒▓█ END OF TRANSMISSION █▓▒░
```
