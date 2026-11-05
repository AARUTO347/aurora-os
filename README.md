# AURORA OS

<p align="center">
  <img src="distribution/branding/logo-wordmark.svg" alt="AURORA OS — MADE BY AARUTO" width="720">
</p>

**MADE BY AARUTO**

A bootable Linux desktop built on Ubuntu 26.04 LTS (`resolute`) with an
aurora-inspired dark visual identity, a branded login screen, and an XFCE
session designed to run directly from the ISO.

> Credits: **AARUTO (Abhishek Solanki) · DP-_-, DEV**

## Status

**Milestone 2 — identity, login, and graphical live session: PASS for the login path (0.3.0-dev).**

The 0.3.0-dev image boots to the AURORA login page, accepts the password,
opens the XFCE desktop, returns to the greeter on logout, and supports
**Switch User** while the background session keeps running. Autologin is
disabled even though casper tries to inject it at boot. The image is still a
development snapshot: BIOS-only, no installer, no Plymouth splash, and the
serial-console test hook remains until the release profile is split.

| Milestone | State |
|---|---|
| 0. Audit | PASS (2026-10-27) |
| 1. Bootable base ISO | PASS (2026-10-31) |
| 2. AURORA identity + GUI login | PASS for the login path (2026-11-06) |
| 3. Functional desktop | IN PROGRESS (terminal, logout, switch-user verified) |
| 4. System utilities | NOT STARTED |
| 5. Release candidate | NOT STARTED |
| 6. Optional AI / kernel work | NOT STARTED |

## Download

Prebuilt ISO: [AURORA OS 0.3.0-dev](https://github.com/AARUTO347/aurora-os/releases/tag/v0.3.0-dev)
(693,329,920 bytes, SHA256 `ebc54345bbf131c0d63e8c84e2821ae17347f7b18479f68ea103c9aee135af90`,
also attached as `.sha256`). BIOS-only live image, tested in QEMU.

## Screenshots

| Login page | Desktop after login |
|---|---|
| ![AURORA login page](docs/screenshots/greeter.png) | ![AURORA desktop](docs/screenshots/desktop.png) |

| After logout | Switch user |
|---|---|
| ![AURORA greeter after logout](docs/screenshots/after-logout.png) | ![AURORA switch user](docs/screenshots/switch-user.png) |

Captured from the 0.3.0-dev ISO in QEMU; see [docs/screenshots](docs/screenshots/README.md).

## Log in to the live session

| Field | Value |
|---|---|
| User | `ubuntu` |
| Full name shown by the greeter | `AARUTO` |
| Password | `aurora` |
| Session | XFCE |

The live account and password are created by
`aurora-live-password.service` before LightDM starts. Change them with
`passwd` inside the session; nothing is written back to the ISO.

## What is in the image

- Ubuntu 26.04 LTS base with kernel `7.0.0-42-generic` and casper live boot.
- XFCE 4.20 on Xorg with LightDM and the AURORA greeter.
- Arc-Dark theme, elementary-xfce icons, DejaVu fonts, AURORA wallpaper.
- `accountsservice` so the greeter and panel resolve the full name.
- `aurora-identity.service` sets the full name `AARUTO` and hostname `aurora`
  before the greeter starts; the initramfs is left untouched.
- AURORA identity in `/etc/aurora-release`, `/etc/lsb-release`, `/etc/issue`,
  `os-release`, hostname `aurora`, and `/usr/share/aurora/credits.txt`.
- Session actions and desktop icons for logout, switch user, and lock screen.
- A real login page: casper's boot-time `autologin-user=ubuntu` injection is
  overridden by `90-aurora.conf` and removed by `aurora-identity.service`.
- Display blanking disabled for the live session; the X VT is activated
  automatically so the greeter is visible.

## Build

Requirements: Ubuntu 26.04 (or a compatible host with the resolute archive),
`live-build`, `xorriso`, `squashfs-tools`, `grub-pc-bin`, `grub2-common`,
`mtools`, `dosfstools`, and root for the chroot.

```sh
sudo AURORA_BUILD_DIR="$HOME/aurora-build" sh scripts/build-iso.sh
```

Output:

```
$HOME/aurora-build/artifacts/aurora-os-0.3.0-dev-amd64.iso
$HOME/aurora-build/artifacts/aurora-os-0.3.0-dev-amd64.iso.sha256
```

Useful targets:

```sh
make check     # static checks, no root
sudo make iso  # build through scripts/build-iso.sh
make verify    # inspect the ISO without booting it
make boot      # QEMU TCG, loopback VNC on 127.0.0.1:5901
```

Full instructions: [docs/BUILD_AND_RUN.md](docs/BUILD_AND_RUN.md).

## Run in a virtual machine

QEMU (BIOS, TCG, no host disk is touched):

```sh
qemu-system-x86_64 -machine q35 -accel tcg -m 2048 -smp 2 \
  -cdrom aurora-os-0.3.0-dev-amd64.iso -boot d -vga std \
  -display gtk,zoom-to-fit=on -vnc 127.0.0.1:1 \
  -serial file:/tmp/aurora-serial.log -no-reboot
```

VMware Workstation/Player: create a new virtual machine, choose **Installer
disc image (ISO)**, select the ISO, use **BIOS** firmware (not UEFI), 4 GB RAM
or more, and start it. AURORA boots live; it does not install to the virtual
disk. The image is BIOS-only, so a UEFI VM will not boot it (KI-015).

A ready-made VMware bundle lives in [distribution/vmware](distribution/vmware):
copy `aurora-os.vmx` next to the ISO. The VMX uses BIOS firmware, an IDE
CD-ROM, 4 GB RAM, NAT networking, and a read-only shared folder.

## Repository layout

```
build/live-build/          live-build configuration (auto/, config/, hooks/)
  config/includes.chroot/  files copied into the image
  config/package-lists/    package selection
  config/hooks/            build-time identity and GUI setup
distribution/branding/     logo mark, wordmark, login banner, wallpaper, palette
docs/                      architecture, build, testing, known issues, credits
scripts/                   build, verify, run, and static checks
.github/                   workflows, issue forms, PR template
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Build and run](docs/BUILD_AND_RUN.md)
- [Testing and evidence](docs/TESTING.md)
- [Known issues](docs/KNOWN_ISSUES.md)
- [Roadmap](docs/ROADMAP.md)
- [Project audit](docs/PROJECT_AUDIT.md)
- [Security](docs/SECURITY.md)
- [Credits](docs/CREDITS.md)

## License and credits

Source code and distribution configuration: MIT, see [LICENSE](LICENSE) and
[NOTICE](NOTICE). Ubuntu packages keep their upstream licenses.

**AURORA OS is made by AARUTO. Credits: AARUTO (Abhishek Solanki), DP-_-, DEV.**
