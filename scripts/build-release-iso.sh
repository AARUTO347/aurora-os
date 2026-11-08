#!/bin/sh
# Build a release-profile ISO: no test-only root serial autologin and no
# evidence service (KI-018). The test profile remains build-iso.sh.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(cat "$ROOT/VERSION")
BUILD_DIR=${AURORA_BUILD_DIR:-$HOME/aurora-build}
WORK=$BUILD_DIR/work-release
ARTIFACTS=$BUILD_DIR/artifacts

if [ "$(id -u)" -ne 0 ]; then
	echo "build-release-iso.sh: live-build needs root; run with sudo" >&2
	exit 1
fi

mkdir -p "$WORK" "$ARTIFACTS"
cp -a "$ROOT/build/live-build/." "$WORK/"

# Test-only pieces, removed from the release profile.
rm -f "$WORK/config/hooks/0100-serial-autologin.chroot" \
      "$WORK/config/hooks/0300-evidence-service.chroot"

cd "$WORK"
AURORA_VERSION=$VERSION lb config
AURORA_VERSION=$VERSION lb build

iso=$(ls -t "$WORK"/*.iso 2>/dev/null | head -n1 || true)
if [ -z "$iso" ]; then
	echo "build-release-iso.sh: no ISO produced in $WORK" >&2
	exit 1
fi

out=$ARTIFACTS/aurora-os-$VERSION-amd64.iso
cp "$iso" "$out"
(
	cd "$ARTIFACTS"
	sha256sum "$(basename "$out")" > "$(basename "$out").sha256"
)

# Release gate: the serial autologin must not exist in the image.
mkdir -p /tmp/aurora-release-check
mount -o loop,ro "$out" /tmp/aurora-release-check
if unsquashfs -l /tmp/aurora-release-check/casper/filesystem.squashfs \
	etc/systemd/system/aurora-serial-getty.service 2>/dev/null |
	grep -q aurora-serial-getty; then
	echo "build-release-iso.sh: FAIL - serial autologin present" >&2
	umount /tmp/aurora-release-check
	exit 1
fi
if unsquashfs -l /tmp/aurora-release-check/casper/filesystem.squashfs \
	etc/profile.d/aurora-evidence.sh 2>/dev/null |
	grep -q aurora-evidence; then
	echo "build-release-iso.sh: FAIL - evidence hook present" >&2
	umount /tmp/aurora-release-check
	exit 1
fi
umount /tmp/aurora-release-check

echo "RELEASE ISO: $out"
echo "SHA256:      $(cut -d' ' -f1 "$out.sha256")"
echo "Serial autologin: absent (KI-018 cleared)"
