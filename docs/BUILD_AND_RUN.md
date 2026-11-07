# AURORA OS - Build and Run

This document separates **verified** commands from **planned** ones. Planned commands have not
been executed for AURORA and must not be reported as working until they are.

Verified on 2026-10-31 (Milestone 1, bootable base ISO) and updated 2026-11-05 after the
0.2.0-dev graphical image booted to XFCE through LightDM.

---

## 1. Paths and environment

| Item | Value |
|---|---|
| AURORA repository (WSL ext4) | `/home/aaruto/aurora-os` |
| Build root (outside Git) | `/home/aaruto/aurora-build` |
| Build work tree | `/home/aaruto/aurora-build/work` |
| Artifacts | `/home/aaruto/aurora-build/artifacts` |
| Build logs | `/home/aaruto/aurora-build/logs` |
| Boot evidence | `/home/aaruto/aurora-build/evidence` |
| Windows access to repository | `\\wsl.localhost\Ubuntu\home\aaruto\aurora-os` |
| Existing myOS project (preserved) | `C:\Users\AARUTO\Documents\Qoder\2026-10-23\3dc41ae1\myos` |
| WSL distro | Ubuntu 26.04 LTS (`resolute`), kernel 6.18.33.2, systemd |
| QEMU | 10.2.1, TCG (`-accel tcg`); KVM is not used by `aaruto` (group unchanged) |

Build on ext4. Do not build inside `/mnt/c`.

---

## 2. Toolchain (installed and verified)

Installed on 2026-10-28 with authorization, after the compatibility checks:

```bash
sudo apt install -y live-build debootstrap xorriso \
    grub-pc-bin grub-efi-amd64-bin mtools dosfstools cpio
```

Verified versions include: live-build `3.0~a57-1ubuntu54`, debootstrap `1.0.142ubuntu2`,
xorriso, GRUB `2.14`, QEMU `10.2.1`. `scripts/verify-iso.sh` and the build/log paths below are the
source of truth for each run.

The historical apt 403 (User-Agent) incident remains mitigated by
`/etc/apt/apt.conf.d/99local-useragent`; `scripts/diagnose-apt.sh --quick` is the preflight used by
the build.

---

## 3. Build (VERIFIED)

```bash
cd /home/aaruto/aurora-os
sudo bash build/build-iso.sh
```

The script:

1. runs `scripts/diagnose-apt.sh --quick` and aborts if the archive is unreachable;
2. removes only its own work tree (`lb clean --purge` plus known paths) and copies
   `build/live-build/{auto,config}` into it;
3. runs `lb config` then `lb build` (about 13 minutes on this host);
4. moves the mastered image to
   `/home/aaruto/aurora-build/artifacts/aurora-os-<VERSION>-amd64.iso` and writes a `.sha256`;
5. prints `ISO`, `SIZE`, `SHA256`, `LOG`.

Verified result (build `2026-10-31 11:15:25` -> `11:28:27`, log
`/home/aaruto/aurora-build/logs/build-20261031-111525.log`):

| Item | Value |
|---|---|
| ISO | `artifacts/aurora-os-0.1.0-dev-amd64.iso` |
| Size | 504,125,440 bytes (481 MiB) |
| SHA256 | `6d078451d07659ee3023cbd78601e29e8042aedd10f0e15637e64171baefba02` |
| Base | Ubuntu 26.04.1 LTS (`resolute`) |
| Kernel | `7.0.0-42-generic` (`#42-Ubuntu SMP PREEMPT_DYNAMIC Thu Oct 15 08:06:44 UTC 2026`) |
| Root filesystem | squashfs + overlayfs, mounted by casper |
| Bootloader | GRUB 2.14, BIOS El Torito only |

0.2.0-dev graphical image (built 2026-11-04/05, verified by `verify-iso.sh` and one QEMU boot):

| Item | Value |
|---|---|
| ISO | `artifacts/aurora-os-0.2.0-dev-amd64.iso` |
| Size | 682,000,384 bytes (651 MiB) |
| SHA256 | `22ce1c653c6927c6b93fbe22cee889a209743ddf896df96ea330f4d88cd50a16` |
| Desktop | XFCE 4.20 via LightDM 1.32, Xorg on vt7, greeter login as live user `ubuntu` |
| Verify | `scripts/verify-iso.sh`: RESULT: PASS |
| Build caveat | Binary stage resumed with `lb binary` after WSL tore down the original build; a clean end-to-end rebuild is still required |

### 3.1 live-build configuration

`build/live-build/auto/config` (executed inside the work tree by `lb config`):

| Flag | Value | Why |
|---|---|---|
| `--mode ubuntu` | Ubuntu archive layout | Base distribution |
| `--distribution resolute` | 26.04 LTS | Verified base |
| `--binary-images iso` | plain ISO 9660 | `iso-hybrid` runs isohybrid, which rejects GRUB El Torito images |
| `--bootloader grub2` | GRUB 2 BIOS | syslinux + casper is broken in this fork |
| `--initramfs casper` | casper | Matches Ubuntu live layout (`/casper/vmlinuz-*`, `/casper/initrd.img-*`) |
| `--linux-packages linux-image` + `--linux-flavours 7.0.0-42-generic` | pinned kernel | `linux-generic` pulled a second kernel; generic meta pulls firmware/microcode/ZFS |
| `--apt-recommends false` | lean image | Prevents desktop/X11 from creeping in |
| `--debian-installer false` | no d-i | `none` is rejected by this fork |
| `--bootappend-live "boot=casper console=tty0 console=ttyS0,115200n8 systemd.show_status=1"` | serial + VGA console | Deterministic evidence capture |

Package list `config/package-lists/aurora.list.chroot` (0.2.0-dev): `linux-image-7.0.0-42-generic`,
`linux-modules-7.0.0-42-generic`, `initramfs-tools`, `casper`, `systemd-sysv`, plus the GUI stack:
`xserver-xorg-core`, `xserver-xorg-input-libinput`, `xserver-xorg-video-vesa`,
`xserver-xorg-video-fbdev`, `xinit`, `x11-xserver-utils`, `dbus-x11`, `lightdm`,
`lightdm-gtk-greeter`, `xfce4`, `xfce4-terminal`, `arc-theme`, `elementary-xfce-icon-theme`,
`adwaita-icon-theme`, `xcursor-themes`, `fonts-dejavu-core`, `epiphany-browser`. `--apt-recommends false` is still
set; every installed package is listed explicitly.

### 3.2 GRUB 2.14 workarounds (required)

The Ubuntu live-build fork predates GRUB 2.14 and produces an unbootable El Torito image. Two
committed fixes make the image boot:

1. `config/includes.chroot/usr/local/bin/grub-mkimage` is a wrapper that calls
   `/usr/bin/grub-mkimage -p /boot/grub "$@"`. Without `-p`, GRUB 2.14 refuses to build `core.img`
   and the ISO carries only a 2 KB `cdboot.img` (the guest hangs at `Boot from CD`).
2. `config/hooks/0100-branding.binary` copies the flat `binary/boot/grub/*.mod|*.lst|*.pf2|*.o`
   files into `binary/boot/grub/i386-pc/` (and rewrites the GRUB menu labels to `AURORA OS`).
   GRUB 2.14 searches `$prefix/i386-pc`; the flat layout booted into `grub rescue>` with
   `file '/boot/grub/i386-pc/normal.mod' not found`.

A third rule: keep `--binary-images iso`. `isohybrid` only understands syslinux signatures and
fails with `boot loader does not have an isolinux.bin hybrid signature`.

### 3.3 Test-only serial console hook

`config/hooks/0100-serial-autologin.chroot` installs `aurora-serial-getty.service`
(`agetty --autologin root --noclear ttyS0 115200 linux`), masks the generated
`serial-getty@ttyS0`, and prints `AURORA_M1_SHELL_OK` from `/etc/profile.d/aurora-evidence.sh`
when a shell starts on `/dev/ttyS0`. It also installs `aurora-evidence.service`, which writes
`AURORA_M1_ROOTFS_OK` and `uname -a` to `/dev/console`.

**This hook is test-only and must be removed before any release image.** On slow TCG boots the
device-generated getty failed because `dev-ttyS0.device` timed out before udev coldplug finished;
the dedicated unit opens the device node directly and is not subject to that race.

### 3.4 GUI layer (0.2.0-dev)

Files live under `build/live-build/config/includes.chroot/` and are copied into the chroot by
live-build; no runtime network access is required.

| Path | Purpose |
|---|---|
| `etc/lightdm/lightdm.conf.d/50-aurora.conf` | greeter session, `user-session=xfce`, X started with `-nolisten tcp -dpms -s 0`, VT display-setup script |
| `etc/lightdm/lightdm.conf.d/90-aurora.conf` | overrides the `autologin-user=ubuntu` that casper injects at boot |
| `etc/lightdm/lightdm-gtk-greeter.conf.d/50-aurora.conf` | wallpaper, Arc-Dark, elementary-xfce, Adwaita cursor, DejaVu Sans 11 |
| `etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml` | GTK/icon/cursor/font defaults |
| `etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml` | Arc-Dark window decorations, DejaVu Sans Bold titles |
| `etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml` | wallpaper for `monitorVirtual-1` |
| `usr/share/aurora/wallpaper.png` | 1792x1024 aurora gradient |
| `usr/local/bin/aurora-wallpaper` | waits for xfconf, sets the backdrop, logs `AURORA_GUI_SESSION_OK` |
| `usr/local/bin/aurora-session-action` | logout/switch/lock helper: restores the session bus, uses `dm-tool switch-to-greeter` for switch-user |
| `etc/skel/Desktop/aurora-browser.desktop` | **AURORA Browser** icon launching Epiphany |
| `etc/xdg/autostart/aurora-wallpaper.desktop` | runs the wallpaper script in the XFCE session |

`config/hooks/0400-gui.chroot` sets `graphical.target` as default, enables `lightdm.service`, and
fails the build if any of the files above are missing. `config/hooks/0200-branding.chroot` writes
the AURORA identity files (`/etc/os-release`, `/usr/lib/os-release`, `/etc/lsb-release`,
`/etc/issue`, `/etc/aurora-release`) and the hostname.

The image deliberately has no autologin: casper's `casper-bottom/15autologin` script appends
`autologin-user=ubuntu` to `/etc/lightdm/lightdm.conf` at boot, which is why a drop-in with a
higher priority (`90-aurora.conf`) and a pre-LightDM cleanup in `aurora-identity.service` are
both required. The live password is `aurora` (set by `aurora-live-password.service`). See KI-018
for the separate test-only root serial autologin.

---

## 4. Verify an ISO (VERIFIED)

```bash
bash /home/aaruto/aurora-os/scripts/verify-iso.sh \
    /home/aaruto/aurora-build/artifacts/aurora-os-0.2.0-dev-amd64.iso
```

Checks: size, SHA256, `file` type, PVD metadata, El Torito BIOS record, GRUB core size and
`grub.cfg` entries, `/casper` kernel/initrd/squashfs/manifest, and key package versions.
Result for 0.2.0-dev: **PASS**. It also reports explicitly that no EFI boot record exists
(this image is BIOS-only).

---

## 5. QEMU boot test (VERIFIED)

```bash
python3 /home/aaruto/aurora-os/build/test-qemu.py \
    /home/aaruto/aurora-build/artifacts/aurora-os-0.1.0-dev-amd64.iso \
    --timeout 600 --evidence /home/aaruto/aurora-build/evidence/final
```

`build/test-qemu.py` launches QEMU with `-machine pc -accel tcg -m 2048 -smp 2 -cdrom <iso>
-boot d -display vnc=127.0.0.1:1 -monitor unix:<evidence>/monitor.sock -serial stdio -no-reboot`,
waits for `AURORA_M1_SHELL_OK`, types a command transcript, takes a `screendump`, powers off
(`sync; poweroff -f`), and writes `result.json`. It exits 0 only when the shell marker and the
command transcript were actually observed.

Evidence directory contents: `serial.log`, `qemu-stderr.log`, `monitor.sock`, `console.ppm`,
`result.json`.

Because the build/boot can take longer than an interactive shell tool timeout, run long jobs
detached inside WSL (`setsid nohup ... &`) and poll the log/result file.

### 5.1 Verified boot result (2026-10-31)

| Item | Result |
|---|---|
| QEMU command | see `result.json` (TCG, 2 vCPU, 2048 MiB) |
| Kernel | `7.0.0-42-generic` |
| Base distribution | Ubuntu 26.04.1 LTS (`resolute`) |
| Root filesystem | casper squashfs mounted through overlayfs (`loop0`) |
| systemd | reached `multi-user.target` / `graphical.target` |
| Console | login prompt on `tty1` (`AURORA OS 0.1.0-dev  ubuntu tty1`); root shell on `ttyS0` |
| Markers | `AURORA_M1_ROOTFS_OK`, `AURORA_M1_SHELL_OK`, `AURORA_CMD_BEGIN/END` |
| Shutdown | clean `reboot: Power down`, QEMU exit 0 |
| Wall time | 4 min 50 s from QEMU start to poweroff (TCG) |
| `result.json` | `verified: true` |

Non-fatal messages observed in the guest: `networkd-dispatcher.service` and
`casper-md5check.service` fail (no network / no checksum file in this minimal image), casper tries
`apt update` and reports `Temporary failure resolving ...` because the VM is offline, and casper's
`/root/var/crash/crash.init` touch/rm warnings are cosmetic. None prevented reaching multi-user.

### 5.2 GUI boot (0.2.0-dev, VERIFIED 2026-11-05)

The automated harness above only understands the Milestone 1 serial markers. The graphical image
was booted manually with a monitor socket so the desktop could be captured:

```bash
qemu-system-x86_64 -machine pc -accel tcg -m 2048 -smp 2 \
  -cdrom /home/aaruto/aurora-build/artifacts/aurora-os-0.2.0-dev-amd64.iso \
  -vga std -display none -vnc 127.0.0.1:1 \
  -monitor unix:/home/aaruto/aurora-build/evidence/gui-run.mon,server,nowait \
  -serial file:/home/aaruto/aurora-build/evidence/gui-run-serial.log -daemonize
```

`-display gtk` may be added for a WSLg window. Drive the monitor with
`socat - UNIX-CONNECT:<sock>`: `screendump file.ppm`, `sendkey ctrl-alt-f7`, `sendkey shift-d`,
`mouse_move`, `quit`. PPM files were converted to PNG with a small pure-Python zlib/struct script
(PIL is not installed).

The scripted login test is `scripts/qemu-login-test.py`. It boots the ISO, waits for the greeter,
types the live password, waits for the XFCE panel, logs out, logs in again, switches user, and
keeps screenshots plus the full serial log:

```bash
mkdir -p /home/aaruto/aurora-test/run1
python3 scripts/qemu-login-test.py \
    /home/aaruto/aurora-build/artifacts/aurora-os-0.4.0-dev-amd64.iso \
    /home/aaruto/aurora-test/run1
```

Run it detached (`setsid nohup ... &`) because a TCG boot takes 10-25 minutes.

### 5.4 Instant start from a saved VM state

`scripts/aurora-vm.sh` keeps a QEMU snapshot on a small qcow2 disk. The first
run boots once and saves the greeter state (`scripts/aurora-snapshot.py`);
later runs resume it with `-loadvm ready` in seconds:

```bash
/home/aaruto/aurora-os/scripts/aurora-vm.sh
```

Measured on this host: 22 s from launch to the greeter with a warm page cache,
40 s cold, against 15-25 minutes for a full TCG boot. The state disk is
`/home/aaruto/aurora-build/aurora-state.qcow2` (1.2 GiB, saved with
`savevm ready`).

On Windows, the desktop shortcut **AURORA OS** runs that script through WSL and
uses `D:\AURORAurora.ico`. If the snapshot is missing or unusable the
script deletes it and performs one full boot to recreate it.

Result: serial log reached `graphical.target`; tty1 showed `AURORA OS 0.2.0-dev ubuntu tty1`;
LightDM started Xorg `:0 ... vt7 -novtswitch` and opened a session for `ubuntu`; `xfce4-session`,
`xfwm4`, `xfce4-panel` and `xfdesktop` were running. `aurora-v2-desktop.png` and
`aurora-v2-demo.png` are the evidence. Notes:

- The screen may capture black with only the X cursor after idle; this is DPMS blanking. Send
  `ctrl-alt-f7` and a key, then capture again (KI-024).
- Under TCG, a newly launched terminal can take ~15 s to appear.
- Killing QEMU: use `pkill -x qemu-system-x86`, not `qemu-system-x86_64` — Linux truncates the
  process name to 15 characters, so the long name matches nothing.

### 5.3 Interactive use

The QEMU display is VNC on loopback only: `127.0.0.1:5901` (VNC display `:1`). Never bind VNC to
`0.0.0.0` and do not expose it without authentication. The serial console is attached to the
launching terminal when `test-qemu.py` runs.

To stop a test manually, kill only the QEMU process and confirm with
`pgrep -af '^qemu-system-x86'`; do not use broad `pkill -f` patterns (they can match the calling
shell).

---

## 6. Display notes for WSL2

- Native WSLg windows can fall back to `[WARN: COPY MODE]` and become taskbar-only; this is a host
  WSLg defect. Use loopback VNC and QEMU `screendump` as the evidence path.
- `/mnt/shared_memory` must be mounted (it is, via `/etc/fstab`).
- For GTK/QEMU native windows, `GDK_BACKEND=x11` avoids the Wayland path that fails on this host.

---

## 7. Existing myOS commands (VERIFIED, reference only)

```bash
cd /mnt/c/Users/AARUTO/Documents/Qoder/2026-10-23/3dc41ae1/myos
make
timeout 8 qemu-system-i386 -kernel kernel.elf -m 256 -display none \
    -serial file:/tmp/myos-audit.log
./run.sh                              # GUI launcher (GDK_BACKEND=x11)
```

myOS is not part of AURORA and must not be modified as part of this roadmap.

---

## 8. Troubleshooting (all observed in this project)

| Symptom | Cause | Action |
|---|---|---|
| `grub-mkimage: Prefix not specified` | GRUB 2.14 requires `-p` | Keep the `/usr/local/bin/grub-mkimage` wrapper (hook 3.2 item 1) |
| Guest hangs after `Boot from CD` | `grub_eltorito` is only 2048 bytes (`core.img` missing) | Verify with `xorriso -osirrox` (verify-iso.sh); fix prefix wrapper |
| `grub rescue>` + `file '/boot/grub/i386-pc/normal.mod' not found` | Flat GRUB module layout | Keep the i386-pc copy in the binary hook |
| `isohybrid: ... no isolinux.bin hybrid signature` | GRUB El Torito is not hybrid-bootable by isohybrid | Use `--binary-images iso`; document USB limitation |
| `serial-getty@ttyS0` dependency failure | `dev-ttyS0.device` timeout on slow TCG boots | Test hook runs agetty directly (3.3) |
| Build killed when the launching WSL client is terminated | WSL ties the session to the client | Run long builds/tests detached (`setsid nohup ... &`) and poll |
| Build killed at "Preparing squashfs image..." | Binary stage never finished after a WSL teardown | The chroot is complete; resume with `su -c 'lb binary' - build` in the work tree after removing `work/.lock`. A clean rebuild is still required for released artifacts |
| Black screendump with only the X cursor | X root window not drawn yet (TCG) or DPMS blanking | X now starts with `-dpms -s 0` and the session re-runs `xset s off -dpms` (KI-024); on TCG wait for lit pixels before capturing (KI-029) |
| An `ubuntu seat0` session exists before any password is typed | casper injects `autologin-user=ubuntu` into `lightdm.conf` at boot | `90-aurora.conf` plus the cleanup in `aurora-identity.service` (KI-028) |
| Panel says "Live session user" | `accountsservice` missing | Resolved in 0.3.0-dev (KI-023) |
| apt 403 on all mirrors | User-Agent filtering | Inspect `/etc/apt/apt.conf.d/99local-useragent`; run `scripts/diagnose-apt.sh` |
| Boot stalls 2 minutes before the desktop | offline `networkd-dispatcher`/checksum units | masked by `0400-gui.chroot`; `DefaultTimeoutStartSec=30s`; apt retries disabled |
| Out of memory during build/boot | WSL limit (5.7 GiB) | Serialize build and QEMU; keep guest at 2048 MiB |
