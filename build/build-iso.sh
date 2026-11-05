#!/bin/sh
# Build the AURORA OS live ISO from the versioned live-build configuration.
# Must run as root (debootstrap and chroot mounts). Build state, logs and
# artifacts live under $AURORA_BUILD_ROOT, never inside the Git repository.
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(cat "$REPO_DIR/VERSION")
BUILD_ROOT=${AURORA_BUILD_ROOT:-/home/aaruto/aurora-build}
WORK_DIR="$BUILD_ROOT/work"
ARTIFACT_DIR="$BUILD_ROOT/artifacts"
LOG_DIR="$BUILD_ROOT/logs"

if [ "$(id -u)" -ne 0 ]; then
	echo "build-iso.sh: must run as root (debootstrap and chroot mounts)" >&2
	exit 1
fi

case "$WORK_DIR" in
	"$BUILD_ROOT"/work) ;;
	*) echo "build-iso.sh: refusing unsafe work directory: $WORK_DIR" >&2; exit 1 ;;
esac

mkdir -p "$WORK_DIR" "$ARTIFACT_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/build-$(date +%Y%m%d-%H%M%S).log"

# Fail fast when the archive is unreachable: a doomed debootstrap wastes a
# long download and hides the real cause. See scripts/diagnose-apt.sh.
if ! "$REPO_DIR/scripts/diagnose-apt.sh" --quick; then
	echo "build-iso.sh: APT connectivity preflight failed; not starting the build" >&2
	exit 1
fi

# Reset only our own known build paths; lb clean finishes the job when it can.
if [ -d "$WORK_DIR/chroot" ] || [ -d "$WORK_DIR/binary" ]; then
	( cd "$WORK_DIR" && lb clean --purge ) >>"$LOG_FILE" 2>&1 || true
fi
rm -rf "$WORK_DIR/.build" "$WORK_DIR/chroot" "$WORK_DIR/binary" \
	"$WORK_DIR/cache" "$WORK_DIR/auto" "$WORK_DIR/config"

cp -a "$REPO_DIR/build/live-build/auto" "$WORK_DIR/auto"
cp -a "$REPO_DIR/build/live-build/config" "$WORK_DIR/config"
chmod +x "$WORK_DIR/auto/config" "$WORK_DIR"/config/hooks/*.chroot "$WORK_DIR"/config/hooks/*.binary

export AURORA_VERSION="$VERSION"
cd "$WORK_DIR"
{
	echo "=== AURORA OS build: $VERSION ($(date -Is)) ==="
	lb config
	lb build
} 2>&1 | tee -a "$LOG_FILE"

# live-build's Ubuntu fork names the mastered image binary[-.hybrid].iso.
ISO="$WORK_DIR/binary.hybrid.iso"
[ -f "$ISO" ] || ISO="$WORK_DIR/binary.iso"
if [ ! -f "$ISO" ]; then
	echo "build-iso.sh: ISO not produced; see $LOG_FILE" >&2
	exit 1
fi

OUT="$ARTIFACT_DIR/aurora-os-$VERSION-amd64.iso"
mv -f "$ISO" "$OUT"
( cd "$ARTIFACT_DIR" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )

echo "ISO=$OUT"
echo "SIZE=$(stat -c %s "$OUT")"
echo "SHA256=$(cut -d' ' -f1 "$ARTIFACT_DIR/$(basename "$OUT").sha256")"
echo "LOG=$LOG_FILE"
