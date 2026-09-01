#!/bin/bash
#
# Regenerate the placeholder app icon at App/MUTHUR.icns.
#
# This does not need running to build the app — the .icns is committed, the way
# artwork normally is. It is here so the placeholder can be regenerated after a
# change to the palette, and so that "where did this icon come from" has an
# answer that is a program rather than a memory.
#
# The awkward part is deliberate. `MakeIcon.swift` is compiled *against the
# app's own* Theme.swift and DotMatrix.swift so that the icon cannot drift away
# from the panel it is the icon for, and those two drag in three more App files
# and the kit. The alternative was eight RGB triples and sixty glyph bitmaps
# copied into the generator, which is how the Dock ends up a slightly different
# amber from the screen.
#
# Usage: Scripts/make-icon.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The kit, for Columns/PanelGrid/AnalyserColumns/Meter, which Theme reads.
swift build --package-path "$ROOT/MUTHURKit" >/dev/null

MODULES="$ROOT/MUTHURKit/.build/debug/Modules"
OBJECTS=("$ROOT"/MUTHURKit/.build/debug/MUTHURKit.build/*.o)

xcrun swiftc -swift-version 6 -target arm64-apple-macosx15.0 -O \
	-I "$MODULES" \
	"$ROOT/App/Panel/Theme.swift" \
	"$ROOT/App/Panel/Grid.swift" \
	"$ROOT/App/Panel/DotMatrix.swift" \
	"$ROOT/App/Panel/Phosphor.swift" \
	"$ROOT/App/Panel/Segments.swift" \
	"$ROOT/Scripts/MakeIcon.swift" \
	"${OBJECTS[@]}" \
	-o "$WORK/make-icon"

"$WORK/make-icon" "$WORK/MUTHUR.iconset"

# iconutil writes the whole bundle at once; a half-written .icns beside a build
# is worse than none, so it lands in the work directory and is moved on.
iconutil --convert icns --output "$WORK/MUTHUR.icns" "$WORK/MUTHUR.iconset"
mv -f "$WORK/MUTHUR.icns" "$ROOT/App/MUTHUR.icns"

echo "$ROOT/App/MUTHUR.icns"
