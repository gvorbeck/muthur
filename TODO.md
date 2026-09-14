# Waiting on hardware

Everything here is written and tested as far as code can take it. What is left
needs a drive, a blank, or a particular file. Tick it in `docs/parity.md` or
`docs/hardware.md` when it is done, and move the Status counts with it.

## On the machine with the burner

Use **Burn ▸** in the menu bar. Nothing in it is remembered between launches, so
set it each time.

- [ ] **Rehearse a record.** Open an album, press `B`, choose
      **Burn ▸ Rehearse — Laser Off**, then burn. It should run the whole screen
      and leave the blank still blank.
- [ ] **Burn it for real with Verify.** Turn Rehearse off, turn on
      **Burn ▸ Verify After Burning**, and burn. The summary line should not say
      `DID NOT VERIFY`.
- [ ] **Try the other switches once.** Burn with **Write CD-Text** off, with
      **Level Loudness** set to Album, and with **Split Long Tracks** on a record
      that has a track longer than 80 minutes.
- [ ] **Resume a two-disc job** (`--from-disc`, parity §20). This needs a record
      too long for one disc and **two blanks**. Plan it, choose
      **Burn ▸ Start at Disc ▸ 2**, and burn. Disc 2 should match the disc 2 a
      whole run would have made.
- [ ] **Health Check with the drive empty** should say
      `drive found, no disc inserted` (D87).

## With a disc, a set, or a spare volume (`docs/hardware.md`)

- [ ] **Step 10:** copy two AIFFs to the top of an external volume, mount it
      with a disc in the drive, and check the disc still wins.
- [ ] **Step 11:** a disc two from a multi-disc set. Its track list should be
      disc two's, not disc one's.
- [ ] **Step 12:** with the drive empty, nothing is offered.
- [ ] **Step 12:** with a data CD or DVD in, it is not offered.
- [ ] **Step 12:** Health Check with that data disc in warns about the media
      type, and still says the machine can play.

## Audio hardware and files (parity §14)

- [ ] **Headphones:** unplugging them pauses playback. Also try an AirPlay
      output.
- [ ] **A hi-res file** (for example 24-bit/96 kHz): the output sample rate
      follows it.
- [ ] **An Opus or Ogg file** that AVFoundation will not open: it plays through
      ffmpeg instead.

## Tests that need a file on this machine

Three tests in `swift test` fail when a certain file is missing. The code is not
broken.

- [ ] `RealMaterialTests` "untagged zipped album" and two `GaplessMaterialTests`
      want a zip of an album in **uncompressed AIFF or WAV**, with several
      tracks, in `~/Downloads`. You can also point `MUTHUR_TEST_ZIPS` at a folder
      holding one.
