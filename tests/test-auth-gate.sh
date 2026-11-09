#!/bin/sh
# Regression tests for scripts/release-gate.sh.
#
# Builds synthetic rootfs/initramfs fixtures (no root, no ISO, no build) and
# asserts the gate is fail-closed:
#   - a clean fixture           -> PASS (exit 0)
#   - an unsafe fixture         -> FAIL (exit 1)
#   - a missing rootfs          -> FAIL (exit 2, inspection error)
#   - a clean rootfs, no initrd -> FAIL (exit 2, cannot verify initramfs)
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GATE="$ROOT/scripts/release-gate.sh"
WORK=$(mktemp -d /tmp/aurora-gate-test.XXXXXX)
trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0
fail=0

# expect_exit LABEL EXPECTED CMD...
expect_exit() {
	label=$1; want=$2; shift 2
	set +e
	"$@" >"$WORK/out" 2>&1
	got=$?
	set -e
	if [ "$got" -eq "$want" ]; then
		printf 'ok   %s (exit %s)\n' "$label" "$got"
		pass=$((pass + 1))
	else
		printf 'FAIL %s (expected exit %s, got %s)\n' "$label" "$want" "$got"
		sed 's/^/     | /' "$WORK/out"
		fail=$((fail + 1))
	fi
}

# --- clean fixture: none of the unsafe elements ---
SAFE="$WORK/safe"
mkdir -p "$SAFE/rootfs/etc/systemd/system" \
	"$SAFE/rootfs/etc/lightdm/lightdm.conf.d" \
	"$SAFE/rootfs/etc/pam.d" \
	"$SAFE/rootfs/etc/sudoers.d" \
	"$SAFE/initrd/main/scripts/casper-bottom"
printf '[Seat:*]\nallow-empty-passwords=false\n' > "$SAFE/rootfs/etc/lightdm/lightdm.conf.d/50-aurora.conf"
printf 'auth required pam_unix.so\n' > "$SAFE/rootfs/etc/pam.d/common-auth"
printf '# no passwordless rules\n' > "$SAFE/rootfs/etc/sudoers.d/README"
printf '#!/bin/sh\n# clean initramfs, no casper injection\n' > "$SAFE/initrd/main/scripts/casper-bottom/00clean"

# --- unsafe fixture: every finding present ---
BAD="$WORK/unsafe"
mkdir -p "$BAD/rootfs/etc/systemd/system/multi-user.target.wants" \
	"$BAD/rootfs/etc/profile.d" \
	"$BAD/rootfs/usr/local/bin" \
	"$BAD/rootfs/etc/lightdm/lightdm.conf.d" \
	"$BAD/rootfs/etc/pam.d" \
	"$BAD/rootfs/etc/sudoers.d" \
	"$BAD/rootfs/var/lib/polkit-1/localauthority/50-local.d" \
	"$BAD/initrd/main/scripts/casper-bottom"
: > "$BAD/rootfs/etc/systemd/system/aurora-serial-getty.service"
: > "$BAD/rootfs/etc/systemd/system/aurora-evidence.service"
: > "$BAD/rootfs/etc/profile.d/aurora-evidence.sh"
printf '#!/bin/sh\nprintf "ubuntu:aurora\\n" | chpasswd\n' > "$BAD/rootfs/usr/local/bin/aurora-live-password"
: > "$BAD/rootfs/etc/systemd/system/aurora-live-password.service"
ln -s ../aurora-live-password.service "$BAD/rootfs/etc/systemd/system/multi-user.target.wants/aurora-live-password.service"
printf '[Seat:*]\nallow-empty-passwords=true\n' > "$BAD/rootfs/etc/lightdm/lightdm.conf.d/50-aurora.conf"
printf 'auth required pam_unix.so nullok\n' > "$BAD/rootfs/etc/pam.d/common-auth"
printf 'ubuntu ALL=(ALL) NOPASSWD: ALL\n' > "$BAD/rootfs/etc/sudoers.d/casper"
printf '[PolicyKit]\nIdentity=unix-user:ubuntu\nResultAny=yes\n' > "$BAD/rootfs/var/lib/polkit-1/localauthority/50-local.d/44pk_allow_ubuntu.pkla"
printf 'autologin-user=ubuntu\n' > "$BAD/initrd/main/scripts/casper-bottom/15autologin"
printf 'usermod -p "" ubuntu\nubuntu ALL=(ALL) NOPASSWD: ALL\n' > "$BAD/initrd/main/scripts/casper-bottom/25adduser"
: > "$BAD/initrd/main/scripts/casper-bottom/44pk_allow_ubuntu"

echo "== release-gate regression =="
expect_exit "clean fixture passes" 0 sh "$GATE" --rootfs "$SAFE/rootfs" --initrd "$SAFE/initrd"
expect_exit "unsafe fixture fails" 1 sh "$GATE" --rootfs "$BAD/rootfs" --initrd "$BAD/initrd"
expect_exit "missing rootfs is inspection error" 2 sh "$GATE" --rootfs "$WORK/does-not-exist"
expect_exit "clean rootfs without initrd is inspection error" 2 sh "$GATE" --rootfs "$SAFE/rootfs"

echo "----"
echo "assertions passed: $pass"
echo "assertions failed: $fail"
if [ "$fail" -ne 0 ]; then
	echo "RESULT: FAIL"
	exit 1
fi
echo "RESULT: PASS"
