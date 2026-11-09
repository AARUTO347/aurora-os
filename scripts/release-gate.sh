#!/bin/sh
# Fail-closed production authentication gate for AURORA OS.
#
# Refuses to certify any image that still carries test-only or passwordless
# access. Production publication (build-release-iso.sh) runs this BEFORE the
# artifact reaches the publish directory; a non-zero exit blocks publication.
#
# Checks the rootfs (squashfs) for:
#   - root serial autologin + evidence service/profile hook (KI-018)
#   - shared live-password provisioning (script or enabled service)
#   - LightDM allow-empty-passwords / PAM nullok (empty-password auth)
#   - passwordless sudo (NOPASSWD) and the casper PolicyKit ubuntu bypass
# and the initramfs for casper live-session injection:
#   - 15autologin / 25adduser / 44pk_allow_ubuntu
#   - autologin-user= and NOPASSWD strings
#
# Exit codes:
#   0  PASS  - no unsafe element found; safe to publish
#   1  FAIL  - an unsafe element is present
#   2  FAIL  - inspection error (mount/extract/missing input); NEVER "absent"
#
# Usage:
#   release-gate.sh --iso FILE                 Extract and inspect a built ISO (root).
#   release-gate.sh --rootfs DIR [--initrd DIR] Inspect extracted trees (tests, no root).
set -eu

fail=0
err=0

note_fail() { printf 'FAIL  %s\n' "$1"; fail=1; }
note_pass() { printf 'pass  %s\n' "$1"; }
note_err()  { printf 'ERROR %s\n' "$1"; err=1; }

ISO=""
ROOTFS=""
INITRD=""
while [ $# -gt 0 ]; do
	case "$1" in
		--iso)
			[ $# -ge 2 ] || { note_err "--iso needs a value"; exit 2; }
			ISO=$2; shift 2 ;;
		--rootfs)
			[ $# -ge 2 ] || { note_err "--rootfs needs a value"; exit 2; }
			ROOTFS=$2; shift 2 ;;
		--initrd)
			[ $# -ge 2 ] || { note_err "--initrd needs a value"; exit 2; }
			INITRD=$2; shift 2 ;;
		*)
			note_err "unknown argument: $1"; exit 2 ;;
	esac
done

TMP=""
cleanup() {
	if [ -n "$TMP" ]; then
		umount "$TMP/iso" 2>/dev/null || true
		rm -rf "$TMP"
	fi
}
trap cleanup EXIT INT TERM

# --- ISO mode: extract once, checking every exit code (fail-closed) ---
if [ -n "$ISO" ]; then
	[ -f "$ISO" ] || { note_err "ISO not found: $ISO"; exit 2; }
	[ "$(id -u)" -eq 0 ] || { note_err "--iso needs root to mount the image"; exit 2; }
	for t in unsquashfs unmkinitramfs mount; do
		command -v "$t" >/dev/null 2>&1 || { note_err "missing tool: $t"; exit 2; }
	done
	TMP=$(mktemp -d "${AURORA_GATE_TMP:-/tmp}/aurora-gate.XXXXXX")
	mkdir -p "$TMP/iso"
	if ! mount -o loop,ro "$ISO" "$TMP/iso"; then
		note_err "cannot mount ISO: $ISO"; exit 2
	fi
	SQ="$TMP/iso/casper/filesystem.squashfs"
	if [ ! -f "$SQ" ]; then
		note_err "no casper/filesystem.squashfs in ISO"; exit 2
	fi
	if ! unsquashfs -no-progress -d "$TMP/rootfs" "$SQ" >/dev/null 2>&1; then
		note_err "unsquashfs extraction failed (cannot verify rootfs)"; exit 2
	fi
	ROOTFS="$TMP/rootfs"
	# Ubuntu live-build names the initramfs initrd.img-<version>; older
	# layouts use initrd / initrd.lz / initrd.gz. Match any casper/initrd*.
	IRD=""
	for c in "$TMP/iso/casper"/initrd*; do
		if [ -f "$c" ]; then IRD="$c"; break; fi
	done
	if [ -z "$IRD" ]; then
		note_err "no casper initrd found in ISO"; exit 2
	fi
	if ! unmkinitramfs "$IRD" "$TMP/initrd" >/dev/null 2>&1; then
		note_err "unmkinitramfs extraction failed (cannot verify initramfs)"; exit 2
	fi
	INITRD="$TMP/initrd"
fi

# --- rootfs checks ---
[ -n "$ROOTFS" ] || { note_err "no rootfs to inspect (use --iso or --rootfs)"; exit 2; }
[ -d "$ROOTFS" ] || { note_err "rootfs is not a directory: $ROOTFS"; exit 2; }
R=$ROOTFS

echo "== rootfs: test-only artifacts (KI-018) =="
for p in \
	etc/systemd/system/aurora-serial-getty.service \
	etc/systemd/system/aurora-evidence.service \
	etc/profile.d/aurora-evidence.sh; do
	if [ -e "$R/$p" ] || [ -L "$R/$p" ]; then
		note_fail "test-only artifact present: $p"
	else
		note_pass "absent: $p"
	fi
done

echo "== rootfs: shared live-password provisioning =="
for p in \
	usr/local/bin/aurora-live-password \
	etc/systemd/system/aurora-live-password.service; do
	if [ -e "$R/$p" ] || [ -L "$R/$p" ]; then
		note_fail "shared-password provisioning present: $p"
	else
		note_pass "absent: $p"
	fi
done
if [ -d "$R/etc/systemd/system" ] &&
	find "$R/etc/systemd/system" -path '*.wants/*' -name 'aurora-live-password.service' 2>/dev/null | grep -q .; then
	note_fail "shared-password service is enabled (multi-user want symlink)"
else
	note_pass "shared-password service not enabled"
fi

echo "== rootfs: empty-password authentication =="
if [ -f "$R/etc/lightdm/lightdm.conf.d/50-aurora.conf" ]; then
	if grep -Eq '^[[:space:]]*allow-empty-passwords[[:space:]]*=[[:space:]]*true' \
		"$R/etc/lightdm/lightdm.conf.d/50-aurora.conf"; then
		note_fail "LightDM allow-empty-passwords=true (50-aurora.conf)"
	else
		note_pass "LightDM does not allow empty passwords"
	fi
fi
for p in etc/pam.d/common-auth etc/pam.d/common-password; do
	if [ -f "$R/$p" ] && grep -Eq 'pam_unix\.so.*nullok' "$R/$p"; then
		note_fail "PAM nullok (empty-password auth) in $p"
	else
		note_pass "no PAM nullok in $p"
	fi
done

echo "== rootfs: passwordless privilege escalation =="
if [ -f "$R/etc/sudoers" ] && grep -Eq 'NOPASSWD' "$R/etc/sudoers"; then
	note_fail "NOPASSWD in etc/sudoers"
else
	note_pass "no NOPASSWD in etc/sudoers"
fi
if [ -d "$R/etc/sudoers.d" ] && grep -rEq 'NOPASSWD' "$R/etc/sudoers.d" 2>/dev/null; then
	note_fail "NOPASSWD in etc/sudoers.d/"
else
	note_pass "no NOPASSWD in etc/sudoers.d/"
fi
for d in etc/polkit-1 var/lib/polkit-1; do
	if [ -d "$R/$d" ] &&
		find "$R/$d" -type f \( -name '*allow_ubuntu*' -o -name '*pk_allow*' \) 2>/dev/null | grep -q .; then
		note_fail "casper PolicyKit ubuntu bypass present under $d"
	else
		note_pass "no casper PolicyKit bypass under $d"
	fi
done

# --- initramfs checks (casper live-session injection) ---
echo "== initramfs: casper live provisioning =="
if [ -n "$INITRD" ]; then
	[ -d "$INITRD" ] || { note_err "initrd is not a directory: $INITRD"; exit 2; }
	I=$INITRD
	for name in 15autologin 25adduser 44pk_allow_ubuntu; do
		if find "$I" -type f -name "$name" 2>/dev/null | grep -q .; then
			note_fail "casper initramfs injection script present: $name"
		else
			note_pass "initramfs clean of: $name"
		fi
	done
	if grep -rIl 'autologin-user=' "$I" 2>/dev/null | grep -q .; then
		note_fail "initramfs injects autologin-user"
	else
		note_pass "initramfs does not inject autologin-user"
	fi
	if grep -rIl 'NOPASSWD' "$I" 2>/dev/null | grep -q .; then
		note_fail "initramfs injects NOPASSWD sudo"
	else
		note_pass "initramfs does not inject NOPASSWD"
	fi
else
	note_err "no initramfs inspected; production gate requires initrd checks"
fi

echo "----"
if [ "$err" -ne 0 ]; then
	echo "RELEASE GATE: FAIL (inspection error; artifact NOT verified safe)"
	exit 2
fi
if [ "$fail" -ne 0 ]; then
	echo "RELEASE GATE: FAIL (unsafe production artifacts present)"
	exit 1
fi
echo "RELEASE GATE: PASS (no test-only or passwordless access found)"
exit 0
