#!/bin/bash
#
# Put MU/TH/UR on a machine that has never had it, in one command.
#
#     curl -fsSL https://raw.githubusercontent.com/gvorbeck/muthur/main/Scripts/bootstrap.sh | bash
#
# This is the second-machine script. `Scripts/install.sh` is for a machine with
# the repository on it and builds from source; this one has no repository, no
# Xcode and no clone — it takes the latest release, installs the two tools the
# port shells out to, and lifts the quarantine that would otherwise make
# Gatekeeper call the download damaged.
#
# It is written to be read before it is run, because a script piped into a
# shell deserves that much. Everything it does is above: `brew install`, a
# download into a temporary directory, a copy into an application folder, and
# one `xattr`. It asks for no password and runs no `sudo`.
#
# Re-running it is how you update — it replaces whatever it finds, having first
# checked that what it found is MU/TH/UR.
#
# Usage: bootstrap.sh [directory]      (default /Applications)

set -euo pipefail

REPO=gvorbeck/muthur
DEST_DIR="${1:-/Applications}"
DEST="$DEST_DIR/MUTHUR.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

die() { echo "bootstrap: $*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || die "this is a macOS app"
[ -d "$DEST_DIR" ] || die "no directory at $DEST_DIR"

# Homebrew is not installed for you. It is a large thing to put on somebody's
# machine and the decision is theirs; all this does is say where it lives.
if ! command -v brew >/dev/null; then
	die "Homebrew is not installed — see https://brew.sh, then run this again"
fi

# `ffmpeg` decodes what AVFoundation will not take and converts every track on
# the way to a burn. `cdrtools` is `cdrecord` and `cdda2wav`, the drive's
# writer and the reader that lifts CD-Text out of a lead-in. Both are genuinely
# optional to the player and neither is optional to the burner.
#
# Asked one at a time and only when missing, so that a machine already carrying
# ffmpeg is not made to sit through Homebrew deciding whether to upgrade it.
for FORMULA in ffmpeg cdrtools; do
	if brew list --formula "$FORMULA" >/dev/null 2>&1; then
		echo "$FORMULA is already installed"
	else
		echo "installing $FORMULA…"
		brew install "$FORMULA"
	fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# `releases/latest/download/…` is GitHub's own redirect to whatever the newest
# release's asset is, so this script does not have to know a version number and
# does not go stale when one is cut.
URL="https://github.com/$REPO/releases/latest/download/MUTHUR.zip"
echo "downloading $URL…"
curl -fsSL --retry 3 -o "$WORK/MUTHUR.zip" "$URL" \
	|| die "could not download the release — is there one yet?"

# `ditto` and not `unzip`: the code signature lives partly in extended
# attributes, and a bundle unpacked by something that drops them is a bundle
# that will not launch.
ditto -x -k "$WORK/MUTHUR.zip" "$WORK/x"
SRC="$WORK/x/MUTHUR.app"
[ -d "$SRC" ] || die "the download did not contain MUTHUR.app"

codesign --verify --deep --strict "$SRC" 2>/dev/null \
	|| die "the downloaded bundle does not verify — do not install it"

# Never clear a path in an application folder without checking what is standing
# there. The same guard as `Scripts/install.sh`, for the same reason: the
# default destination is shared with every other app on the machine.
if [ -e "$DEST" ]; then
	EXISTING="$(defaults read "$DEST/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
	[ "$EXISTING" = com.gvorbeck.muthur ] \
		|| die "refusing to replace $DEST — identifier is '${EXISTING:-unreadable}'"
	rm -rf "$DEST"
fi

cp -R "$SRC" "$DEST"

# The line the README exists to tell you about. The app is ad-hoc signed, and
# a file that arrived over the network carries `com.apple.quarantine`;
# Gatekeeper rejects that pair outright and Finder reports it as damage. The
# attribute goes because you just watched where this came from.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

"$LSREGISTER" -f "$DEST"

echo
echo "installed $DEST"
echo "open it from Spotlight, Raycast or the Dock."
