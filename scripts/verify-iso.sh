#!/bin/sh
# Inspect a built AURORA ISO without booting it. Read-only.
# Usage: scripts/verify-iso.sh PATH_TO_ISO
set -eu

ISO=${1:?usage: verify-iso.sh PATH_TO_ISO}
[ -f "$ISO" ] || { echo "verify-iso.sh: no such file: $ISO" >&2; exit 1; }

fail=0
pass() { printf 'PASS  %s\n' "$*"; }
bad()  { printf 'FAIL  %s\n' "$*"; fail=1; }
info() { printf '%s\n' "$*"; }

info "== image =="
info "path:   $ISO"
info "size:   $(stat -c %s "$ISO") bytes"
info "sha256: $(sha256sum "$ISO" | cut -d' ' -f1)"
info "file:   $(file -b "$ISO")"

info ""
info "== volume metadata =="
xorriso -indev "$ISO" -pvd_info 2>/dev/null | sed -n 's/^/  /p'

info ""
info "== boot records =="
torito=$(xorriso -indev "$ISO" -report_el_torito plain 2>/dev/null || true)
printf '%s\n' "$torito" | sed -n 's/^/  /p'
if printf '%s\n' "$torito" | grep -q 'BIOS'; then
    pass "El Torito BIOS boot record present"
else
    bad "no El Torito BIOS boot record"
fi
if printf '%s\n' "$torito" | grep -qi 'EFI'; then
    pass "El Torito EFI boot record present"
else
    info "NOT PRESENT: EFI boot record (this image is BIOS-only)"
fi
xorriso -indev "$ISO" -report_system_area plain 2>/dev/null | sed -n 's/^/  /p'

info ""
info "== GRUB payload =="
grub_tmp=$(mktemp -d)
if xorriso -osirrox on -indev "$ISO" \
    -extract /boot/grub/grub_eltorito "$grub_tmp/grub_eltorito" \
    -extract /boot/grub/grub.cfg "$grub_tmp/grub.cfg" >/dev/null 2>&1; then
    elt_size=$(stat -c %s "$grub_tmp/grub_eltorito")
    info "grub_eltorito size: $elt_size bytes"
    if [ "$elt_size" -gt 2048 ]; then
        pass "GRUB core image embedded in grub_eltorito"
    else
        bad "grub_eltorito is only $elt_size bytes: core.img missing (GRUB would hang)"
    fi
    if grep -q '^linux' "$grub_tmp/grub.cfg"; then
        pass "grub.cfg contains boot entries"
    else
        bad "grub.cfg contains no boot entries"
    fi
else
    bad "could not extract GRUB payload"
fi
rm -rf "$grub_tmp"

info ""
info "== /casper contents =="
listing=$(xorriso -indev "$ISO" -find /casper -type f -exec lsdl 2>/dev/null || true)
printf '%s\n' "$listing" | sed -n 's/^/  /p'
for f in vmlinuz initrd.img filesystem.squashfs; do
    if printf '%s\n' "$listing" | grep -q "/casper/$f"; then
        pass "/casper/$f present"
    else
        bad "/casper/$f missing"
    fi
done
if printf '%s\n' "$listing" | grep -q '/casper/filesystem.manifest'; then
    pass "/casper/filesystem.manifest present"
else
    info "NOT PRESENT: /casper/filesystem.manifest"
fi

if printf '%s\n' "$listing" | grep -q '/casper/filesystem.manifest'; then
    tmp=$(mktemp -d)
    if xorriso -osirrox on -indev "$ISO" \
        -extract /casper/filesystem.manifest "$tmp/manifest" 2>/dev/null; then
        info ""
        info "== key packages (from filesystem.manifest) =="
        for pkg in linux-image casper initramfs-tools systemd-sysv; do
            line=$(grep -E "^${pkg}(-|[[:space:]])" "$tmp/manifest" | head -3 || true)
            if [ -n "$line" ]; then
                printf '%s\n' "$line" | sed -n 's/^/  /p'
                pass "package $pkg recorded"
            else
                bad "package $pkg not in manifest"
            fi
        done
    else
        bad "could not extract filesystem.manifest"
    fi
    rm -rf "$tmp"
fi

info ""
if [ "$fail" -eq 0 ]; then
    info "RESULT: PASS"
else
    info "RESULT: FAIL"
fi
exit "$fail"
