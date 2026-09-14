#!/bin/bash
#
# Cut a GitHub release: build it, check it, zip it, tag it, publish it.
#
# The app is ad-hoc signed and has no Developer ID, so what goes up is a plain
# zip of the bundle and the release notes carry the `xattr -dr` line — see the
# README. Nothing here notarizes anything, because nothing here can.
#
# It is deliberately unwilling. A release is the one artifact that outlives a
# mistake: it has a URL, somebody downloads it, and taking it down does not
# un-download it. So every precondition is checked before the first byte is
# built, and a failure at any of them is an exit rather than a prompt.
#
# Usage: Scripts/release.sh <version> [notes-file]
#        Scripts/release.sh 0.2.0
#        Scripts/release.sh v0.2.0 docs/notes-0.2.0.md
#
# The version may be written with or without its `v`; the tag always has one.
# `notes-file`, if given, is prepended to the install instructions rather than
# replacing them — the instructions are the part a downloader cannot do
# without, so they are not something a caller can forget to include.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

die() { echo "release: $*" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: Scripts/release.sh <version> [notes-file]"

# Accept `0.2.0` and `v0.2.0` and mean the same thing, then insist on the shape
# from here on: a tag is what the release is named after and what `brew` and
# every changelog reader will sort, so it is not the place to be relaxed.
VERSION="${1#v}"
TAG="v$VERSION"
NOTES_FILE="${2:-}"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
	|| die "version must be MAJOR.MINOR.PATCH, got '$1'"
[ -z "$NOTES_FILE" ] || [ -f "$NOTES_FILE" ] || die "no notes file at $NOTES_FILE"

command -v gh >/dev/null || die "gh is not installed — brew install gh"
gh auth status >/dev/null 2>&1 || die "gh is not logged in — gh auth login"

# Everything that must be true of the repository, asked before anything is
# built. A release built from a dirty tree is a binary nobody can reproduce
# from the tag it claims to be.
[ -z "$(git status --porcelain)" ] || die "working tree is dirty"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = main ] || die "on branch '$BRANCH', not main"

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists"
gh release view "$TAG" >/dev/null 2>&1 && die "a release named $TAG already exists"

git fetch --quiet origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] \
	|| die "HEAD and origin/main differ — push or pull first"

echo "building $TAG from $(git rev-parse --short HEAD)…"

xcodebuild -project "$ROOT/MUTHUR.xcodeproj" -scheme MUTHUR \
	-configuration Release -derivedDataPath "$ROOT/build/DerivedData" \
	build >/dev/null

APP="$ROOT/build/DerivedData/Build/Products/Release/MUTHUR.app"
[ -d "$APP" ] || die "no bundle at $APP"

# Four questions of the thing about to be published, none of which xcodebuild
# answers by succeeding.
#
# The architectures matter most and are the easiest to lose: the machines this
# is for are one Apple silicon and one Intel, and a build that quietly came out
# arm64-only installs fine and then will not launch on the other one. Asking
# `lipo` is a second's work and the alternative is finding out by download.
codesign --verify --deep --strict "$APP" || die "the bundle does not verify"
for ARCH in arm64 x86_64; do
	lipo -archs "$APP/Contents/MacOS/MUTHUR" | grep -qw "$ARCH" \
		|| die "the binary has no $ARCH slice — check the target's ARCHS"
done
[ "$(defaults read "$APP/Contents/Info" CFBundleIdentifier)" = com.gvorbeck.muthur ] \
	|| die "that bundle is not MU/TH/UR"

# The version is asked of the bundle, not of the project file, because the
# bundle is what gets downloaded. `Info.plist` quotes `MARKETING_VERSION` rather
# than repeating it (761464a) — v0.1.0 went out saying `0.1` while the tag said
# otherwise — so bumping the project setting and committing is the whole of
# naming a release, and this is what notices when that step was skipped.
BUILT="$(defaults read "$APP/Contents/Info" CFBundleShortVersionString)"
[ "$BUILT" = "$VERSION" ] \
	|| die "the bundle says $BUILT, not $VERSION — set MARKETING_VERSION and commit first"

# `ditto` and not `zip`, because the code signature lives partly in extended
# attributes and `zip` drops them — the bundle would arrive unsigned and
# refuse to launch for a reason nothing on screen would explain.
ZIP="$(mktemp -d)/MUTHUR.zip"
ditto -c -k --keepParent --sequesterRsrc "$APP" "$ZIP"

NOTES="$(mktemp)"
if [ -n "$NOTES_FILE" ]; then
	cat "$NOTES_FILE" >>"$NOTES"
	printf '\n\n' >>"$NOTES"
fi

cat >>"$NOTES" <<'EOF'
## Install

One command, which also installs the two tools the port shells out to:

    curl -fsSL https://raw.githubusercontent.com/gvorbeck/muthur/main/Scripts/bootstrap.sh | bash

Or by hand: unzip `MUTHUR.zip`, drag `MUTHUR.app` to `/Applications`, and then

    xattr -dr com.apple.quarantine /Applications/MUTHUR.app
    brew install ffmpeg cdrtools

**The `xattr` line is not optional.** The app is ad-hoc signed — a personal
app, no Developer ID and no notarization. Anything that arrived over the
network carries `com.apple.quarantine`, and Gatekeeper rejects that pair
outright; Finder's way of saying so is a dialog claiming the app is damaged.

`ffmpeg` decodes what AVFoundation will not take and converts every track on
the way to a burn; `cdrtools` is `cdrecord` and `cdda2wav`, the drive's writer
and the reader that lifts CD-Text out of a lead-in. Both are optional in the
sense that nothing crashes without them — you get a smaller set of things the
app can tell you, which §11 reports — but the burner does not run at all.

`MUTHUR.zip` is one universal bundle, arm64 and x86_64.
EOF

# The tag is pushed before the release is created rather than left to `gh` to
# create from a branch, so that a release always names a tag that exists in the
# repository and not one invented at the API.
git tag -a "$TAG" -m "MU/TH/UR $TAG"
git push --quiet origin "$TAG"

gh release create "$TAG" "$ZIP" \
	--title "MU/TH/UR $TAG" \
	--notes-file "$NOTES"

rm -f "$NOTES"

# Ask GitHub what it actually has, rather than trusting that the upload that
# returned 0 is the file somebody will get.
gh release view "$TAG" --json assets \
	--jq '.assets[] | "published \(.name) — \(.size) bytes, \(.digest)"'
