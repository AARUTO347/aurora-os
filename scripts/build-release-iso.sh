#!/bin/sh
# Build a release-profile ISO and refuse to publish it unless the fail-closed
# production authentication gate (scripts/release-gate.sh) passes. The test
# profile remains scripts/build-iso.sh and is never gated.
#
# Production is currently BLOCKED: KI-034 (a clean lb build does not complete
# on this host) and KI-035 (casper live provisioning + shared credentials must
# be replaced by secure first-boot onboarding). This script will not emit a
# publishable artifact until the build completes AND the gate passes.
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

# Reset only our own known build path; never reuse a prior (possibly test) chroot.
case "$WORK" in
	"$BUILD_DIR"/work-release) ;;
	*) echo "build-release-iso.sh: refusing unsafe work directory: $WORK" >&2; exit 1 ;;
esac
mkdir -p "$ARTIFACTS"
rm -rf "$WORK"
mkdir -p "$WORK"
cp -a "$ROOT/build/live-build/." "$WORK/"

# Release profile: strip test-only hooks AND shared-credential provisioning.
# Removing the service file also makes 0400-gui.chroot skip enabling it.
rm -f "$WORK/config/hooks/0100-serial-autologin.chroot" \
      "$WORK/config/hooks/0300-evidence-service.chroot"
rm -f "$WORK/config/includes.chroot/usr/local/bin/aurora-live-password" \
      "$WORK/config/includes.chroot/etc/systemd/system/aurora-live-password.service"

cd "$WORK"
AURORA_VERSION=$VERSION lb config
AURORA_VERSION=$VERSION lb build

iso=$(ls -t "$WORK"/*.iso 2>/dev/null | head -n1 || true)
if [ -z "$iso" ]; then
	echo "build-release-iso.sh: no ISO produced in $WORK" >&2
	exit 1
fi

# Fail-closed gate BEFORE the artifact reaches the publish directory. Any
# non-zero exit (unsafe element OR inspection error) blocks publication.
if ! "$ROOT/scripts/release-gate.sh" --iso "$iso"; then
	echo "build-release-iso.sh: RELEASE GATE FAILED; artifact NOT published." >&2
	echo "build-release-iso.sh: inspect $iso (left in the work directory)." >&2
	exit 1
fi

out=$ARTIFACTS/aurora-os-$VERSION-amd64.iso
cp "$iso" "$out"
(
	cd "$ARTIFACTS"
	sha256sum "$(basename "$out")" > "$(basename "$out").sha256"
)

echo "RELEASE ISO: $out"
echo "SHA256:      $(cut -d' ' -f1 "$out.sha256")"
echo "Production authentication gate: PASS"
