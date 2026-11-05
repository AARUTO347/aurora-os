#!/bin/sh
# Build the AURORA ISO reproducibly. Requires root (live-build uses a chroot).
# Usage: sudo [AURORA_BUILD_DIR=/path] scripts/build-iso.sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(cat "$ROOT/VERSION")
BUILD_DIR=${AURORA_BUILD_DIR:-$HOME/aurora-build}
WORK=$BUILD_DIR/work
ARTIFACTS=$BUILD_DIR/artifacts

if [ "$(id -u)" -ne 0 ]; then
	echo "build-iso.sh: live-build needs root; run with sudo" >&2
	exit 1
fi

mkdir -p "$WORK" "$ARTIFACTS"

# Seed live-build with the tracked configuration. Generated state from a
# previous build is kept, so this also works as an incremental rebuild.
cp -a "$ROOT/build/live-build/." "$WORK/"

cd "$WORK"
AURORA_VERSION=$VERSION lb config
AURORA_VERSION=$VERSION lb build

iso=$(ls -t "$WORK"/*.iso 2>/dev/null | head -n1 || true)
if [ -z "$iso" ]; then
	echo "build-iso.sh: no ISO produced in $WORK" >&2
	exit 1
fi

out=$ARTIFACTS/aurora-os-$VERSION-amd64.iso
cp "$iso" "$out"
(
	cd "$ARTIFACTS"
	sha256sum "$(basename "$out")" > "$(basename "$out").sha256"
)

echo "ISO:    $out"
echo "SHA256: $(cut -d' ' -f1 "$out.sha256")"
