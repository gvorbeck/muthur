#!/bin/bash
#
# Put a real MUTHUR.app in /Applications, where Raycast, Spotlight and the Dock
# will find it by name.
#
# It has to be a copy. Raycast indexes the standard application folders and
# nothing else, so a bundle sitting in DerivedData is invisible to it — and a
# symlink to one is indexed only erratically, which is worse than not at all.
# The cost is that this has to be re-run to pick up changes; during development
# you are launching from Xcode anyway.
#
# /Applications and not ~/Applications: it is `drwxrwxr-x root:admin`, so an
# admin account writes to it without `sudo`, and it is the folder Spotlight and
# every launcher look in first. Pass a directory as the second argument to put
# it somewhere else.
#
# Usage: Scripts/install.sh [Release|Debug] [directory]   (default Release, /Applications)

set -euo pipefail

CONFIG="${1:-Release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${2:-/Applications}/MUTHUR.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

xcodebuild -project "$ROOT/MUTHUR.xcodeproj" -scheme MUTHUR \
	-configuration "$CONFIG" -derivedDataPath "$ROOT/build/DerivedData" \
	build >/dev/null

SRC="$ROOT/build/DerivedData/Build/Products/$CONFIG/MUTHUR.app"
[ -d "$SRC" ] || { echo "no bundle at $SRC" >&2; exit 1; }

# Never clear a path in an application folder without checking what is standing
# there — the more so now that the default one is shared with every other app on
# the machine.
if [ -e "$DEST" ]; then
	EXISTING="$(defaults read "$DEST/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
	if [ "$EXISTING" != "com.gvorbeck.muthur" ]; then
		echo "refusing to replace $DEST — identifier is '${EXISTING:-unreadable}'" >&2
		exit 1
	fi
	rm -rf "$DEST"
fi

cp -R "$SRC" "$DEST"

# Nudge LaunchServices rather than waiting for it to notice on its own.
"$LSREGISTER" -f "$DEST"

echo "$DEST"
