# AURORA OS - Architecture

## 1. Goals

AURORA OS is a bootable, maintainable, Ubuntu-based desktop distribution with a consistent
aurora-inspired visual identity. It must run in a disposable QEMU virtual machine, be reproducible
from scripts, and never require modifying the host boot configuration or physical disks.

Non-goals for the first milestones:

- A custom Linux kernel.
- A custom bootloader.
- A custom window manager or display server.
- AI features before the base desktop is proven.

## 2. Layered design

```
Host: Windows 11 / HP 250 G8
  |
  +-- WSL2 Ubuntu 26.04 LTS (build environment, /home/aaruto/aurora-os)
        |
        +-- live-build (configuration + package selection)
        |     |
        |     +-- debootstrap: Ubuntu root filesystem
        |     +-- packages: kernel, casper initramfs, systemd (desktop later)
        |     +-- hooks: branding, evidence services, serial console
        |     +-- genisoimage + GRUB: BIOS El Torito ISO (plain, not hybrid)
        |
        +-- artifacts/aurora-os-<version>-amd64.iso + .sha256 + build logs
        |
        +-- QEMU (KVM when available) -> serial log, VNC on 127.0.0.1, screendump evidence
```

Inside the 0.3.0-dev graphical live ISO:

```
GRUB 2.14 (BIOS El Torito)
  -> Linux kernel 7.0.0-42-generic (Ubuntu-supplied)
  -> casper initramfs (initramfs-tools, byte-identical to the known-good image)
  -> squashfs root filesystem mounted through overlayfs
  -> casper-bottom/15autologin writes autologin-user=ubuntu into lightdm.conf
  -> systemd -> graphical.target
  -> aurora-live-password sets the live password, aurora-identity sets the
     gecos/hostname and strips the injected autologin keys
  -> LightDM 1.32 + lightdm-gtk-greeter ("AURORA OS" login page) -> Xorg :0 on vt7
  -> user logs in as ubuntu -> aurora-vt activates VT7
  -> XFCE 4.20 session (xfce4-session, xfwm4, xfce4-panel, xfdesktop)
  -> AURORA wallpaper, Arc-Dark theme, elementary-xfce icons, DejaVu fonts
  -> xfce4-terminal (verified); other applications installed but NOT TESTED
  -> [Next] Plymouth splash, AURORA apps
```

The Milestone 1 image (0.1.0-dev, 2026-10-31) stopped at `multi-user.target` with a text login on
`tty1`; that path is still present underneath the graphical stack.

## 3. Component decisions

| Layer | Choice | Rationale | Status |
|---|---|---|---|
| Base distribution | Ubuntu 26.04 LTS (`resolute`) | Matches the verified build environment; maintained LTS with a large package set | Built and verified (26.04.1 LTS) |
| Kernel | Ubuntu `linux-image-*` | Supported, tested, no custom kernel maintenance | `linux-image-7.0.0-42-generic` verified |
| Bootloader | GRUB 2.14, `grub-pc-bin` | Standard BIOS El Torito boot; UEFI deferred | BIOS verified; UEFI NOT TESTED |
| Initramfs | `casper` + `initramfs-tools` | Matches Ubuntu live layout under `/casper` | Verified |
| Root filesystem | squashfs, read-only with overlayfs | Reproducible and small; writable overlay in RAM | Verified |
| Service manager | systemd | Base default; used for diagnostics | Verified (`multi-user.target`) |
| Display manager | LightDM 1.32 + lightdm-gtk-greeter | Lightweight, themeable, well supported by XFCE | LightDM/session verified 2026-11-05; branded greeter, logout and switch-user exercised in the 0.3.0 run |
| Desktop environment | XFCE 4.20 | Low memory, stable, configurable; suited to 4 threads / 5.7 GiB WSL build host | Verified 2026-11-05 |
| Shell | XFCE panel; Whisker Menu + dock plugin or Plank | Builds on the window manager instead of conflicting with it | Panel/dock present with defaults; deliberate AURORA layout NOT TESTED |
| Terminal | xfce4-terminal | Real shell, tabs, scrollback; color palette can be themed | Verified 2026-11-05 |
| File manager | Thunar | Real filesystem operations, removable media support | Installed; operations NOT TESTED |
| Settings | xfce4-settings plus an AURORA settings hub | Only expose settings that are actually implemented and tested | NOT TESTED |
| Networking | NetworkManager | Standard Wi-Fi/Ethernet management | Not integrated; image is offline in QEMU |
| Audio | PipeWire + WirePlumber | Current Ubuntu default, honest "no device" reporting | NOT TESTED |
| System info | Custom `aurora-system-info` (GTK) | Reads `/proc`, `/sys`, `uname`, systemd; no invented data | Planned (Milestone 4) |
| AI assistant | Optional separate component | Must never be required for boot; explicit consent; no auto-execution | Deferred (Milestone 6) |

Rows marked "Verified" were confirmed by an actual QEMU boot or by inspecting the built image.
Base-layer rows were verified on 2026-10-31 (two boots); LightDM, XFCE, the desktop terminal and
the branding files were verified on 2026-11-05 in a single graphical boot. Everything marked
"NOT TESTED" is installed or planned but has no executed test; do not describe it as working.

## 4. Branding layer

- Identity: `AURORA OS`, credit "Made by Abhishek Solanki".
- Palette tokens: background `#080B14`, surface `#101729`, elevated `#172238`, cyan `#45E6FF`,
  blue `#648BFF`, violet `#A879FF`, text `#F3F6FF`, secondary `#9BA9C7`, error `#FF647C`,
  success `#62E6AE`.
- Boot: Plymouth theme where supported by the live image; fallback is a clean GRUB menu.
  Plymouth is **not implemented**; the current image shows the GRUB menu and text boot messages.
- Login: LightDM greeter configured with the AURORA wallpaper, Arc-Dark, elementary-xfce and
  DejaVu Sans (`/etc/lightdm/lightdm-gtk-greeter.conf.d/50-aurora.conf`). Autologin written by
  casper is overridden by `/etc/lightdm/lightdm.conf.d/90-aurora.conf` and removed by
  `aurora-identity.service`, so the greeter is the first thing a user sees.
- Session menu: XFCE Log Out, Switch User and Lock Screen actions; the desktop launchers call
  `xfce4-session-logout` so they work from the running session.
- Desktop: verified 2026-11-05 — aurora gradient wallpaper, Arc-Dark GTK/window-manager theme, elementary-xfce
  icons, Adwaita cursor, DejaVu fonts, default XFCE panel/dock. Terminal palette not yet themed.
- Assets live under `config/includes.chroot/usr/share/aurora/` and are installed without runtime
  network access. `distribution/branding/` (source assets: wordmark, 1920x1080 wallpaper, palette
  file, licensed font) is still to be created.
- Consistency: one theme package and one set of assets shared by shell and applications; no
  per-application ad-hoc styling.
- Accessibility: focus indicators, keyboard navigation, reduced-motion behavior, high-contrast
  variant. Avoid blur/transparency that harms readability or CPU use.

## 5. AURORA applications

Planned, in dependency order:

1. Shell customization (panel, menu, dock, notifications, clock/calendar) - uses XFCE components.
   Current state: default XFCE panel with Applications menu, clock and session label; no dock
   layout or AURORA menu yet.
2. Settings hub - launches real XFCE/system tools; hides unsupported options. Not started.
3. System information - OS/kernel/CPU/memory/storage/uptime/network/session/display. Not started.
4. Diagnostics - failed units, recent errors, boot and session failures, package errors, with
   credential redaction. Not started.
5. AI assistant (optional) - local or remote model, user-approved context, reviewable commands, no
   automatic execution, credentials outside source control. Deferred.

Each application is only listed as functional after a test in the running live system. Today only
`xfce4-terminal` has been run and verified.

## 6. Build and release design

- Build root: `/home/aaruto/aurora-os` on ext4 (not `/mnt/c`) to avoid Windows filesystem
  permission, case, and speed problems.
- ISO artifacts: `artifacts/aurora-os-amd64.iso`, `artifacts/SHA256SUMS`, build logs under
  `artifacts/logs/`; all ignored by Git.
- Reproducibility: pinned package versions where practical, recorded package manifest, build script
  with `set -eu`, explicit exit codes, and a timestamp/version stamp in `/etc/aurora-release`.
- Source control: small commits; generated images, chroots, caches, and secrets excluded.
- Separation: build process and display process are independent, so a GUI failure cannot destroy
  build output. QEMU runs after the ISO is complete and immutable.

## 7. Testing and evidence design

- Primary display path: QEMU VNC bound to `127.0.0.1` (built into QEMU, no external download).
- Primary evidence: serial console log plus QEMU monitor `screendump` images.
- Optional native WSLg window (GDK X11 backend) for interactive use, never the sole evidence.
- Guest resources: 2 vCPU, 3072 MiB RAM, one disposable qcow2 disk; KVM when the user is in the
  `kvm` group, TCG otherwise.
- Tests and acceptance criteria are defined in `TESTING.md`; results are recorded with timestamps.

## 8. Repository layout (planned)

```
aurora-os/
├── README.md
├── VERSION
├── .gitignore
├── docs/
│   ├── PROJECT_AUDIT.md
│   ├── ARCHITECTURE.md
│   ├── ROADMAP.md
│   ├── BUILD_AND_RUN.md
│   ├── KNOWN_ISSUES.md
│   ├── SECURITY.md
│   └── TESTING.md
├── build/
│   ├── scripts/          # build-iso.sh, test-qemu.sh, checksums
│   └── live-build/       # lb config, package lists, hooks
├── distribution/
│   ├── packages/         # package lists by purpose
│   ├── services/         # systemd units
│   └── filesystem/       # /etc/aurora-release, user defaults, skel
├── desktop/
│   ├── shell/            # panel layouts, menu, dock configuration
│   ├── themes/           # GTK theme, colors, fonts
│   ├── icons/
│   ├── wallpapers/
│   └── applications/     # settings hub, system info, diagnostics, AI panel
├── tests/
│   ├── boot/
│   ├── integration/
│   └── evidence/         # logs and screendumps (ignored by Git)
└── artifacts/            # ISOs and checksums (ignored by Git)
```

This layout is now partly realized: `build/`, `distribution/` (via the live-build chroot tree),
`docs/` and `tests/evidence` exist. `desktop/` and `distribution/branding/` are still planned; the
current branding assets are installed directly from `build/live-build/config/includes.chroot/`.

## 9. Open questions (status after the 0.2.0-dev GUI boot)

1. `live-build` 3.0~a57 on Ubuntu 26.04: **yes**, with GRUB2-only config and two committed GRUB 2.14
   workarounds (prefix wrapper, `i386-pc` module layout). The syslinux path is unusable.
2. LightDM/XFCE availability and a consistent theme toolchain in `resolute`: **yes** — LightDM
   1.32, lightdm-gtk-greeter, XFCE 4.20, Arc-Dark and elementary-xfce installed and rendering
   (2026-11-05). Plymouth and a fully themed greeter are still open.
3. Dock option (docklike, Plank, or panel launcher): **not yet decided**; the default XFCE panel and
   dock are displayed, but no custom layout or running-indicator behavior is tested.
4. Boot under WSL2: BIOS with TCG **verified**; KVM and UEFI/OVMF **not tested**.
5. Measured on this host: 0.1.0 ISO 504,125,440 bytes, 0.2.0-dev ISO 682,000,384 bytes; about
   4 minutes to the M1 serial shell under TCG in an unloaded host, 9 minutes when busy; M1 build
   about 13 minutes. The 0.2.0-dev binary stage was resumed after a WSL teardown, so a clean
   build duration is not yet measured.

## 10. Explicit non-relationship to myOS

`myOS` is a different project: a 32-bit bare-metal kernel and custom GUI with no Linux components.
Its code, build system, and QEMU launchers are preserved at their existing path and are not used by
AURORA. No myOS source will be copied into this repository.
