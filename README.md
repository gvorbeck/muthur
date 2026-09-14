# MU/TH/UR

A macOS music player for whole albums, and a CD burner.

- Plays a **folder**, a **zip**, or the **audio CD** in the drive
- Gapless, in the order the tags say
- Burns an album to audio CD, across as many discs as it needs
- Looks like a CRT terminal

It is a port of two bash programs, `player` and `burncd`, which live in the
`cd-collection` repo and are not changed by this one.

**Needs:** macOS 15 or later, Apple silicon or Intel.

---

## Install

Pick one.

### A. One command (new machine)

```bash
curl -fsSL https://raw.githubusercontent.com/gvorbeck/muthur/main/Scripts/bootstrap.sh | bash
```

Installs `ffmpeg` and `cdrtools` if missing, then the latest release. Needs
[Homebrew](https://brew.sh) already installed. No password asked.

### B. By hand

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

> **Don't skip the `xattr` line.** Without it, macOS says the app is "damaged".
> It isn't. The app just isn't notarized.

### C. From this repo (needs Xcode)

```bash
brew install ffmpeg cdrtools
```

```bash
Scripts/install.sh
```

## Update

1. **Quit MU/TH/UR.**
2. Run the same install again. From source: `git pull`, then
   `Scripts/install.sh`.

Check the version at the top of the window, next to the logo.

---

## Use

| Key | Does |
|---|---|
| ⌘O | Open a folder or zip |
| Space | Pause |
| ← → | Seek 5 s (⇧ for 30 s) |
| ↑ ↓, Enter | Move the cursor, play that track |
| `n` / `p` | Next / previous track |
| `s` / `r` | Shuffle / repeat |
| `-` / `=` / `m` | Volume down / up / mute |
| `u` | Resume where you left off, when offered |
| `b` | Plan a burn of this album |
| `e` | Eject the CD |
| `q` | Stop |
| ⌘K | Health Check |

Click the meters to jump around in the track or the album.

### Burning a CD

1. Open an album.
2. Press `b` to see the burn plan. Fix any titles here.
3. Set options in the **Burn** menu. They reset every launch.
4. Press `b` again. It asks for a blank before anything happens.

**Tip:** try **Burn ▸ Rehearse** first. It does everything except turn the laser
on.

### The two extra tools

| Tool | Used for | Without it |
|---|---|---|
| `ffmpeg` | Opus/Ogg files, and burning | Those files won't play; no burning |
| `cdrtools` | Burning, and reading CD-Text | No burning; CDs show fewer names |

They aren't bundled into the app because of licensing and Intel/ARM builds.
Health Check (⌘K) tells you if one is missing.

---

## Release (maintainer)

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

---

## Status

**Parity: 321 of 325** checklist items done. The four open ones need hardware,
not code:

- Headphones unplugged → pause (plus AirPlay)
- Hi-res output sample rate
- An Opus/Ogg file that needs ffmpeg
- Resuming a burn at disc 2 (needs two blanks)

**Hardware walkthrough: 34 of 40** steps done.

What to test next, as a checklist: [`TODO.md`](TODO.md).

### Docs

| File | What's in it |
|---|---|
| [`docs/parity.md`](docs/parity.md) | The checklist, and the full status |
| [`docs/decisions.md`](docs/decisions.md) | Every place this differs from the bash scripts, and why |
| [`docs/hardware.md`](docs/hardware.md) | The step-by-step test with a real drive |
| [`docs/spec.md`](docs/spec.md) | What it has to do |
| [`CLAUDE.md`](CLAUDE.md) | Rules for working on it |
