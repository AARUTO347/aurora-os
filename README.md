<div align="center">

<img src="assets/logo.png" alt="AURORA OS Logo" width="200"/>

# AURORA OS

### A bootable Ubuntu 26.04 LTS live desktop with XFCE, branded LightDM login, and AURORA identity

[![Release](https://img.shields.io/github/v/release/AARUTO347/aurora-os?style=for-the-badge&color=7c3aed)](https://github.com/AARUTO347/aurora-os/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-x86__64-blue?style=for-the-badge)]()
[![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04%20LTS-e95420?style=for-the-badge&logo=ubuntu)]()

**Made by [AARUTO](https://github.com/AARUTO347) (Abhishek Solanki)**

*Credits: DP-_-, DEV*

[Features](#-features) • [Download](#-download) • [Installation](#-installation) • [Documentation](#-documentation) • [Building](#-building)

</div>

---

## About

AURORA OS is a custom bootable Linux desktop built on **Ubuntu 26.04 LTS** with an aurora-inspired dark visual identity, a branded login screen, and an XFCE session designed to run directly from the ISO — no installation required.

## Current Status

**0.5.0-dev — login, logout, switch-user and polkit verified; browser page rendering still failing under TCG** (Milestone 4 in progress)

Next work is tracked in [docs/ROADMAP.md](docs/ROADMAP.md#immediate-next-actions): browser
rendering under a GPU VM (KI-032), KVM for the test host (KI-003), and the release/test profile
split (KI-018).

| Milestone | Description | Status |
|:---------:|-------------|:------:|
| 0 | Audit | PASS |
| 1 | Bootable base ISO | PASS |
| 2 | AURORA identity + GUI login | PASS |
| 3 | Functional desktop | In Progress |
| 4 | System utilities | Not Started |
| 5 | Release candidate | Not Started |
| 6 | Optional AI / kernel work | Not Started |

## Features

- **Ubuntu 26.04 LTS** base with kernel `7.0.0-42-generic`
- **XFCE 4.20** desktop environment on Xorg
- **LightDM** with custom AURORA greeter
- **Arc-Dark** theme with elementary-xfce icons
- **AURORA branding** throughout — wallpaper, identity files, hostname
- **Live session** — runs entirely from ISO, no installation needed
- **AURORA Browser** (Falkon, Chromium engine) with a launcher — opens a window, but page rendering needs a GPU-capable VM (KI-032)
- **Session actions** — Log Out, Switch User (LightDM dm-tool) and Lock Screen
- **Fast boot** — offline-only units masked, 30 s systemd job timeouts, apt fast-fail
- **BIOS-only image** — tested in QEMU (UEFI not supported; no installer)

## Download

| Version | Size | SHA256 |
|---------|------|--------|
| [v0.5.0-dev](https://github.com/AARUTO347/aurora-os/releases/tag/v0.5.0-dev) | 856 MB | `7ecbf55d5c7eef3198692fef1a2e75af16fcc52b515672a8b0be8229ccb1fe5c` |

> **Note:** BIOS-only live image. UEFI boot not yet supported (KI-015).

## Installation

### Quick Start (QEMU)

```bash
qemu-system-x86_64 -machine q35 -accel tcg -m 2048 -smp 2 \
  -cdrom aurora-os-0.5.0-dev-amd64.iso -boot d -vga std \
  -display gtk,zoom-to-fit=on -vnc 127.0.0.1:1 \
  -serial file:/tmp/aurora-serial.log -no-reboot
```

### VMware

1. Download the ISO from [Releases](https://github.com/AARUTO347/aurora-os/releases)
2. Create a new VM → Choose **Installer disc image (ISO)**
3. Select **BIOS** firmware (not UEFI)
4. Allocate 4 GB RAM or more
5. Boot and enjoy!

A ready-made VMware bundle is available in [`distribution/vmware`](distribution/vmware).

### Login Credentials

| Field | Value |
|-------|-------|
| User | `ubuntu` |
| Display Name | `AARUTO` |
| Password | `aurora` |
| Session | XFCE |

## Building

### Prerequisites

- Ubuntu 26.04 (or compatible host with resolute archive)
- `live-build`, `xorriso`, `squashfs-tools`, `grub-pc-bin`, `grub2-common`, `mtools`, `dosfstools`
- Root access for chroot operations

### Build Commands

```bash
# Full ISO build
sudo AURORA_BUILD_DIR="$HOME/aurora-build" sh scripts/build-iso.sh

# Or use make targets
make check        # Static checks (no root required)
sudo make iso     # Build ISO
make verify       # Inspect ISO without booting
make boot         # QEMU TCG with loopback VNC on 127.0.0.1:5901
```

### Build Output

```
$HOME/aurora-build/artifacts/aurora-os-0.5.0-dev-amd64.iso
$HOME/aurora-build/artifacts/aurora-os-0.5.0-dev-amd64.iso.sha256
```

Full build instructions: [docs/BUILD_AND_RUN.md](docs/BUILD_AND_RUN.md)

## Repository Structure

```
aurora-os/
├── build/live-build/          # live-build configuration
│   ├── config/includes.chroot/  # Files copied into image
│   ├── config/package-lists/    # Package selection
│   └── config/hooks/            # Build-time identity & GUI setup
├── distribution/branding/     # Logo, wordmark, login banner, wallpaper, palette
├── distribution/vmware/       # VMware VMX configuration
├── docs/                      # Architecture, build, testing, known issues
├── scripts/                   # Build, verify, run, and static checks
└── .github/                   # Workflows, issue forms, PR template
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | System design and component overview |
| [Build & Run](docs/BUILD_AND_RUN.md) | Complete build instructions |
| [Testing](docs/TESTING.md) | Test procedures and evidence |
| [Known Issues](docs/KNOWN_ISSUES.md) | Current limitations and bugs |
| [Roadmap](docs/ROADMAP.md) | Future development plans |
| [Project Audit](docs/PROJECT_AUDIT.md) | Comprehensive project review |
| [Security](docs/SECURITY.md) | Security considerations |
| [Credits](docs/CREDITS.md) | Acknowledgments |

## Screenshots

| Login | Desktop |
|:-----:|:-------:|
| ![Login](docs/screenshots/greeter.png) | ![Desktop](docs/screenshots/desktop.png) |

| After Logout | Switch User |
|:------------:|:-----------:|
| ![Logout](docs/screenshots/after-logout.png) | ![Switch](docs/screenshots/switch-user.png) |

| AURORA Browser (Falkon) |
|:------------------------:|
| ![Browser](docs/screenshots/browser.png) |



## License

Source code and distribution configuration: **MIT** — see [LICENSE](LICENSE) and [NOTICE](NOTICE).

Ubuntu packages retain their upstream licenses.

---

<div align="center">

**AURORA OS** — Made with care by [AARUTO](https://github.com/AARUTO347)

[GitHub](https://github.com/AARUTO347/aurora-os) • [Releases](https://github.com/AARUTO347/aurora-os/releases) • [Issues](https://github.com/AARUTO347/aurora-os/issues)

</div>
