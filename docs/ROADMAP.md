# AURORA OS - Roadmap

Status: Milestone 1 complete on 2026-10-31. Milestone 2 is in progress: the 0.2.0-dev image boots
to a branded XFCE desktop through LightDM (verified 2026-11-05). Remaining M2 work is the
test/release profile split, Plymouth, the complete brand asset set, and greeter capture.

Every milestone is complete only when its acceptance criteria have been verified by executed tests
and recorded evidence. The labels are: PASS, FAIL, BLOCKED, NOT TESTED, IN PROGRESS.

---

## Milestone 0 - Audit (PASS, 2026-10-27)

Deliverables:

- Verified project structure (new repo at `/home/aaruto/aurora-os`; myOS preserved).
- Environment report (host, WSL, QEMU, KVM, disk, memory).
- Dependency report (toolchain present/missing).
- Risk assessment.
- Prioritized implementation plan (this document).

Acceptance: existing implementation and its current state are understood. Verified by
`docs/PROJECT_AUDIT.md`.

---

## Milestone 1 - Bootable base (PASS, verified 2026-10-31)

Objective: produce a minimal Ubuntu 26.04 live ISO that boots to a working login/console in QEMU,
with logs and a repeatable build.

### Result

- ISO: `artifacts/aurora-os-0.1.0-dev-amd64.iso`, 504,125,440 bytes, SHA256
  `6d078451d07659ee3023cbd78601e29e8042aedd10f0e15637e64171baefba02`.
- Build: `build/build-iso.sh` from a reset work tree, about 13 minutes, completion summary printed.
- Boot: two QEMU TCG runs produced `AURORA_M1_ROOTFS_OK`, `AURORA_M1_SHELL_OK`, the command
  transcript, and a clean `poweroff -f`; `result.json` `verified: true` in both runs.
- Guest: Ubuntu 26.04.1 LTS (`resolute`), kernel `7.0.0-42-generic`, casper squashfs on
  overlayfs, systemd `multi-user.target`, login prompt on `tty1`.
- Deviations: GRUB2 BIOS only (no UEFI), plain ISO (no USB hybrid), text mode only, and a
  test-only root autologin on the serial console that must be removed for release.
- See `BUILD_AND_RUN.md`, `TESTING.md`, and `KNOWN_ISSUES.md` (KI-015 to KI-022).

### Step 1 - Prepare the environment (done)

- Toolchain installed 2026-10-28 after version checks: `live-build debootstrap xorriso
  grub-pc-bin grub-efi-amd64-bin mtools dosfstools cpio`.
- KVM group membership was **not** changed (no authorization given); QEMU runs with `-accel tcg`.
- Verified: `lb --version` `3.0~a57-1ubuntu54`, debootstrap `1.0.142ubuntu2`, GRUB `2.14`,
  QEMU `10.2.1`.

### Step 2 - Scaffold the build (done)

- `build/live-build/` holds the versioned `auto/config`, package list, GRUB template, and hooks;
  `build/build-iso.sh` resets the work tree, runs `lb config` + `lb build`, moves the image to the
  artifact directory, and writes its `.sha256`.
- Actual stack: GRUB2 BIOS + casper (not live-boot), pinned `linux-image-7.0.0-42-generic`,
  `systemd-sysv`, no desktop, no recommends.
- Two GRUB 2.14 workarounds are required and committed (prefix wrapper and `i386-pc` module
  layout); see `BUILD_AND_RUN.md` section 3.2.

Exit criteria met: `lb build` produced the image and the log records the package manifest.

### Step 3 - Boot test (done)

- Test command: `python3 build/test-qemu.py <iso> --timeout 600 --evidence <dir>` with
  `-accel tcg`, 2 vCPU, 2048 MiB, VNC on `127.0.0.1:1`.
- Verified: GRUB loads, kernel and casper initramfs start, squashfs mounts via overlayfs, systemd
  reaches multi-user, `tty1` shows a login prompt, serial shell and command transcript are
  captured, shutdown is clean.
- Repeated once (2026-10-31): both runs `verified: true`.
- UEFI is NOT TESTED; the image has no EFI boot record.

Exit criteria met for BIOS. UEFI remains a separate untested case.

### Step 4 - Fallback path

Not needed: live-build worked once the GRUB 2.14 and syslinux/casper incompatibilities were
resolved. Keep debootstrap + xorriso as a documented fallback only.

### Milestone 1 acceptance

A fresh build from a clean tree produces a bootable ISO using documented commands, boots in QEMU,
and the evidence is recorded. No desktop requirement yet.

---

## Milestone 2 - AURORA identity (IN PROGRESS, GUI boot verified 2026-11-05)

Objective: make AURORA look and identify as AURORA OS from the first moment the ISO starts.
The base booted reliably after Milestone 1, so branding work began here; the XFCE session that
verifies the branded login was pulled into this milestone because the desktop and the greeter are
tested together (Milestone 3 now refines, not introduces, the desktop).

Reference design: `Aurora OS Design Showcase.png` (dark aurora gradient, cyan/blue/violet accents,
clean typography). Palette tokens are fixed in `ARCHITECTURE.md` section 4.

### Result (0.2.0-dev, verified 2026-11-05)

- ISO: `artifacts/aurora-os-0.2.0-dev-amd64.iso`, 682,000,384 bytes (651 MiB), SHA256
  `22ce1c653c6927c6b93fbe22cee889a209743ddf896df96ea330f4d88cd50a16`.
- `scripts/verify-iso.sh`: **RESULT: PASS** (BIOS El Torito, GRUB payload, `/casper` payload).
- Boot: QEMU 10.2.1 TCG, 2 vCPU, 2048 MiB, `-vga std`, VNC on `127.0.0.1:1`. Serial log reached
  `graphical.target`; tty1 shows `AURORA OS 0.2.0-dev ubuntu tty1`; login as `ubuntu` (blank)
  succeeded.
- Desktop: LightDM active on `:0 vt7 -novtswitch`, pam `lightdm-autologin` opened a session for
  `ubuntu`; `xfce4-session`, `xfwm4`, `xfce4-panel`, `xfdesktop` running. Screendumps
  `aurora-v2-desktop.png` (wallpaper, panel, dock, desktop icons) and `aurora-v2-demo.png`
  (terminal with `cat /etc/aurora-release`, `uname -r`, `free -h`).
- Identity in the guest: `/etc/aurora-release` = `AURORA OS 0.2.0-dev (Milestone 2)`, base line
  `Ubuntu 26.04 LTS (resolute)`; kernel `7.0.0-42-generic`; hostname hook sets `aurora` (the live
  session still reports `ubuntu` because casper rewrites the live hostname).
- Caveat: the ISO was produced by resuming `lb binary` after WSL tore down the first build at the
  squashfs stage. The chroot and package set are complete, but a clean end-to-end rebuild is still
  required before any reproducibility claim.
- Not done: test/release profile split (root serial autologin is still present, KI-018), Plymouth,
  full `distribution/branding/` asset set, greeter screenshot with autologin disabled.

### Result (0.3.0-dev, 2026-11-06)

- ISO: `artifacts/aurora-os-0.3.0-dev-amd64.iso`, 693,329,920 bytes, SHA256
  `ebc54345bbf131c0d63e8c84e2821ae17347f7b18479f68ea103c9aee135af90`; casper initrd kept
  byte-identical to the known-good image (`d203e1a3...`).
- Login page: the branded LightDM greeter is the first thing on screen (wallpaper, `AURORA`
  hostname, date, `AARUTO` account, password field, **Log In**).
- Autologin: casper's initramfs stage injects `autologin-user=ubuntu` into
  `/etc/lightdm/lightdm.conf`; `90-aurora.conf` overrides it and `aurora-identity.service` strips
  it before LightDM starts (`AURORA_IDENTITY_READY ... autologin=no`).
- Session: password login opens XFCE as `ubuntu` with the panel, dock and AURORA desktop icons
  (Log Out, Switch User, Lock Screen); the panel shows `AARUTO`.
- Logout returns to the greeter; a second login succeeds; **Switch User** opens the greeter in
  unlock mode while the background session keeps running.
- Display: X starts with `-dpms -s 0`, so the DPMS extension is absent and cannot blank the
  screen; `fgconsole` is 7 and `aurora-vt` is active.
- Open: test/release profile split (KI-018), polkit is missing so LightDM logs an AccountsService
  permission warning (cosmetic), `/var/lib/lightdm/data` is still absent (KI-026).

### Result (0.4.0-dev, 2026-11-06)

- ISO: `artifacts/aurora-os-0.4.0-dev-amd64.iso`, 742,064,128 bytes, SHA256
  `ad7317af165926d39b29443a1cda43cc061ecaefdc1d9310f2df748ca4178d44`; initrd kept at
  `d203e1a3...`.
- Browser: GNOME Web (Epiphany 49.2) ships in the image with an **AURORA Browser** launcher;
  `aurora-browser` disables WebKit's sandbox/compositing for the live Xorg session (KI-032).
- Session actions: Log Out, Switch User and Lock Screen call `aurora-session-action`, which
  restores the session bus and switches user through LightDM `dm-tool` (fallback
  `xfce4-session-logout`). Verified: `method=dm-tool`, new greeter session, background session
  alive.
- Boot tuning: `networkd-dispatcher`, `casper-md5check`, `e2scrub_reap`, `grub-*`, `ua-*`,
  `ubuntu-advantage` and the apt-daily timers are masked; systemd job timeouts are 30 s; apt has
  3 s timeouts and no retries, so an offline boot fails fast instead of waiting minutes.
- Identity: `0.4.0-dev (Milestone 3)`; credits URL corrected to `AARUTO347`.
- Open: browser page painting under TCG (window appears, capture lagged), test/release split,
  polkit warning, `/var/lib/lightdm/data`.

### Step 1 - Separate test and release profiles

- [ ] Move the test-only hooks (`0100-serial-autologin.chroot`, `0300-evidence-service.chroot`) out
      of the release config into a test-only overlay, or gate them behind an explicit
      `AURORA_TEST_HOOKS=1` switch in `build-iso.sh`.
- [ ] Keep boot automation working: the test profile still produces the serial shell markers; the
      release profile must boot to a normal login prompt with no root autologin (clears KI-018).
- [ ] Verify by inspecting the chroot/ISO: no `autologin.conf`, no `aurora-evidence.service` in the
      release profile.

### Step 2 - Identity files and hostname

- [x] `/etc/os-release`: `NAME`/`PRETTY_NAME` = AURORA OS, `ID=aurora`, `ID_LIKE="ubuntu debian"`,
      `VERSION_ID=0.2`, `VERSION_CODENAME=aurora`, `UBUNTU_CODENAME=resolute`; Ubuntu compatibility
      fields kept. Written by `hooks/0200-branding.chroot` (overrides `/usr/lib/os-release`).
- [x] `/etc/issue` (and the same banner applied to `/etc/issue.net`): `AURORA OS 0.2.0-dev  \n \l`.
- [x] `/etc/aurora-release`: `AURORA OS 0.2.0-dev (Milestone 2)` plus base line and build stamp.
- [x] Hostname via chroot hook: `/etc/hostname` = `aurora`, `127.0.1.1 aurora` in `/etc/hosts`.
      The casper live session still shows `ubuntu`; documented, not claimed as fixed.
- [x] `VERSION` bumped to `0.2.0-dev`; ISO named `aurora-os-0.2.0-dev-amd64.iso`.
- [x] Acceptance: serial transcript and the desktop terminal show `cat /etc/aurora-release`,
      `uname -r`, `free -h`; tty1 banner renders `AURORA OS 0.2.0-dev`.

### Step 3 - Boot visuals

- [~] GRUB: text menu kept with AURORA title and dark palette; "Start AURORA OS" labels and the
      timeout were already verified in Milestone 1. A new capture of this menu is NOT TESTED.
- [ ] Plymouth: add `plymouth` and a script-based AURORA theme (background `#080B14`, wordmark,
      subtle aurora accent, no spinner-only generic theme); enable `quiet splash` only if serial
      evidence and the text fallback still work. If Plymouth cannot be made reliable in the live
      image, document the clean GRUB-only fallback instead of shipping a broken splash.
- [ ] Acceptance: `screendump`/VNC capture of the GRUB menu and the splash; serial log still shows
      kernel/initramfs messages; removing `splash` restores text boot.

### Step 4 - Brand asset and theme foundation

- [~] `distribution/branding/` is not yet populated; the wallpaper currently lives at
      `config/includes.chroot/usr/share/aurora/wallpaper.png` (1792x1024 aurora gradient).
      Logo/wordmark SVG, palette file, login background and a licensed font are still missing.
- [x] Assets installed to `/usr/share/aurora/` by the chroot tree; no runtime network access.
- [x] GTK theme Arc-Dark, elementary-xfce icons, Adwaita cursors, DejaVu fonts, and the XFCE
      xfconf defaults (`xsettings.xml`, `xfwm4.xml`, `xfce4-desktop.xml`) are installed and are
      the default session. Terminal palette is not yet customized.
- [x] Acceptance (visual): theme, icons, cursor and wallpaper are visible in
      `aurora-v2-desktop.png`; file presence confirmed in the built chroot.

### Step 5 - Login identity groundwork

- [x] Greeter chosen: LightDM 1.32 + `lightdm-gtk-greeter`, configured to use the AURORA wallpaper,
      Arc-Dark, elementary-xfce, Adwaita cursor, DejaVu Sans 11.
- [x] Greeter configuration staged in
      `config/includes.chroot/etc/lightdm/lightdm-gtk-greeter.conf.d/50-aurora.conf`.
- [x] Graphical session enabled: `graphical.target` is the default and `lightdm.service` is enabled
      (`hooks/0400-gui.chroot`). Autologin is overridden by `90-aurora.conf` and removed by
      `aurora-identity.service`, so the greeter is the default login path (0.3.0-dev).
- [x] Acceptance (visual): greeter screenshot with autologin disabled (`01-greeter.png`,
      2026-11-06); login, logout and switch-user exercised in the same run.

### Step 6 - Verify, document, version

- [~] One graphical boot verified 2026-11-05 (serial + two screendumps + in-guest terminal). A
      second boot and a clean end-to-end rebuild are still outstanding; the release profile does
      not exist yet.
- [x] Milestone 2 tests registered in `TESTING.md` Phase G with PASS evidence.
- [x] `README.md`, `ROADMAP.md`, `TESTING.md`, `KNOWN_ISSUES.md`, `ARCHITECTURE.md` and
      `BUILD_AND_RUN.md` updated for the 0.2.0-dev GUI image.
- [ ] Exit criteria: release-profile ISO boots to a branded login prompt with identity files
      verified by serial transcript, GRUB/splash captured, no root autologin. Only the identity
      and desktop-session portions are met so far.

### Milestone 2 constraints

- No changes to Windows disks, bootloader, Secure Boot, or WSL system configuration.
- UEFI remains NOT TESTED; do not block Milestone 2 on it.
- The image stays BIOS-only and plain ISO (not USB-hybrid) unless a separate mastering task is
  approved.
- Cosmetic-only controls or fake settings are not acceptable; branding must reflect real system
  values.

---

## Milestone 3 - Functional desktop (IN PROGRESS)

Started ahead of plan because the branded login is only verifiable together with a session.

- [x] XFCE session and LightDM greeter login verified 2026-11-06 (0.3.0-dev).
- [x] Real terminal launched and ran commands (`aurora-v2-demo.png`).
- [x] Logout returns to the greeter and a second login works; switch-user is verified. Restart and
      shutdown from the session menu are NOT TESTED.
- [~] Top panel exists (Applications menu, clock, session label); dock and workspaces need a
      deliberate layout instead of the XFCE defaults.
- [ ] Application menu with dynamic discovery, dock with running indicators.
- [ ] Real file manager operations (Thunar), window controls, keyboard shortcuts.
- [ ] Settings entry points that perform real system operations.
- [ ] Session recovery path for a broken desktop configuration.

Acceptance: every control performs a real operation and is tested in QEMU; no decorative-only
buttons; screenshots and serial logs recorded.

---

## Milestone 4 - System utilities (NOT STARTED)

- System information from real sources.
- Diagnostics: failed units, boot/session errors, package errors, with redaction.
- NetworkManager integration with honest failure reporting.
- Audio status with honest "no device" handling.
- Application management view.
- Installed AURORA version surfaced in About/System Info.

Acceptance: data matches the running system; missing hardware/permissions are reported honestly;
no fabricated temperatures, battery health, or GPU capabilities.

---

## Milestone 5 - Release candidate (NOT STARTED)

- Versioned ISO with version stamp.
- Repeatable build from clean checkout.
- Automated smoke tests and checksums.
- QEMU screenshots and serial logs.
- Build, boot, recovery, and known-limitations documentation.

Acceptance: another developer can follow `BUILD_AND_RUN.md` and reproduce the same release.

---

## Milestone 6 - Optional advanced work (DEFERRED)

- AI assistant: opt-in, local/remote provider, no file transmission without approval, no automatic
  command execution, credentials outside source control.
- Custom kernel configuration track with a working fallback kernel.
- Shell refinements, accessibility, additional hardware support.

Acceptance: each feature has its own plan, isolation, and test evidence; absence of the feature
never prevents normal OS use.

---

## Immediate next actions

1. Clean rebuild of `0.3.0-dev` end to end with `build/build-iso.sh` (the current image was
   produced with `lb binary` from the stage-050 pipeline) before any reproducibility claim.
2. Milestone 2, Step 1: split the test-only hooks (serial autologin, evidence services) from the
   release profile and keep the boot harness working through the test profile.
3. Done in 0.3.0-dev: `accountsservice` (panel shows `AARUTO`), DPMS disabled at the X server,
   branded greeter verified. Next: add `policykit-1` so LightDM can update the AccountsService
   record without the permission warning, and create `/var/lib/lightdm/data` (KI-026).
4. Milestone 2, Step 3: Plymouth theme (or a documented GRUB-only fallback) and a fresh GRUB menu
   capture.
5. Milestone 2, Step 4: complete `distribution/branding/` (logo SVG, 1920x1080 wallpaper, palette
   file, licensed font).
6. Milestone 3: real logout/restart/shutdown, deliberate panel/dock/workspace layout, Thunar
   operations, settings entry points, session recovery.
7. Decide whether UEFI support is required before the desktop milestone (currently BIOS-only).
8. Optional: request authorization for the KVM group change to speed up QEMU tests.

## Metrics to record per build

- ISO size; build duration; package count.
- QEMU boot time to login; idle RAM; idle CPU (guest).
- Failed systemd units; serial-log errors.
- Host disk consumed; WSL memory peak.
- QEMU measurements are separate from any future physical-hardware measurements.

## Dependencies and constraints

- Host: HP 250 G8, i3-1005G1, 11.8 GiB RAM; WSL sees 5.7 GiB.
- WSL: Ubuntu 26.04 LTS, QEMU 10.2.1, KVM device present, user group pending.
- No changes to Windows disks, bootloader, or security settings at any milestone.
- myOS stays frozen and separate.
