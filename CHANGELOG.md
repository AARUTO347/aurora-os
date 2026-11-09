# Changelog

All notable changes to AURORA OS are recorded here. Versions follow
`MAJOR.MINOR.PATCH` with a `-dev` suffix for images that are not releases.

## [Unreleased]

### Fixed

- `scripts/check.sh` selected files for the shell syntax stage by name glob
  (`*.sh`, `*.chroot`, `aurora-*`), so non-script assets (`.desktop`, `.service`,
  `.svg`, `aurora.list.chroot`) and the Python 3 files failed `sh -n`; `make check`
  printed RESULT: FAIL. Files are now routed by shebang: Python files get an AST
  syntax check, shell files get `sh -n`, everything else is reported as skipped.
- `aurora-vt` waited for a `^Xorg ` ps line, but LightDM execs Xorg by full path,
  so the fallback never matched; the service looped 60 s and `graphical.target`
  finished ~74 s late under KVM (`AURORA_VT_NOT_CONFIRMED`). The pattern now
  matches the full-path invocation. Not boot-verified (rebuild needs root).

### Added

- New AURORA OS logo artwork (`distribution/branding/logo.png`, installed as
  `/usr/share/aurora/login-logo.png` and referenced by the greeter).
- `scripts/release-gate.sh`: fail-closed production authentication gate. Inspects
  both the squashfs and the initramfs and refuses to certify an image carrying
  shared live credentials, empty-password auth (LightDM `allow-empty-passwords` /
  PAM `nullok`), passwordless sudo/PolicyKit, test-only root serial
  autologin/evidence, or casper live-session injection. Any inspection error is
  FAIL, never "absent" (exit 0 PASS / 1 FAIL / 2 FAIL).
- `tests/test-auth-gate.sh`: regression fixtures (clean / unsafe / missing rootfs /
  clean rootfs without initrd), run by `make check` and `make test-gate`; no root
  or build required.
- `make release` (gated release-profile build) and `make test-gate` targets.

### Changed

- Falkon removed from the package list (broken post-install against Qt 6);
  Firefox remains the browser. Release kernel pin moved to `7.0.0-14-generic`.
- `scripts/build-release-iso.sh` now uses fresh work state, stages a release
  profile (test hooks AND the shared-password service removed), and runs the gate
  BEFORE copying the artifact to the publish directory; publication is blocked on
  any non-zero gate exit.
- `0400-gui.chroot` only enables/validates the shared-password service when it is
  actually staged, so the release profile never provisions a common password.
  Test-profile behaviour is unchanged.

### Security

- Finding 5 (public test credentials): production release is BLOCKED and gated.
  The root `SECURITY.md` claim that the shared `ubuntu:aurora` password "is not a
  vulnerability" is withdrawn. README credentials are now labelled test-profile
  only. The gate refuses every existing image (verified 2026-11-09 against
  `aurora-release-final.iso`, exit 1: shared-password service, empty-password auth
  and casper initramfs injection); regression fixtures pass 4/4. Secure first-boot
  onboarding must replace casper live provisioning before a production image can
  pass (KI-035). No production image has been built or boot-tested.

## [0.5.0-dev] — 2026-11-06

### Added

- `polkitd` + `pkexec` so LightDM can update the AccountsService record without
  the "org.freedesktop.PolicyKit1 was not provided" warning.
- `/var/lib/lightdm/data` created by the GUI hook (KI-026).
- Official Mozilla Firefox 159.0.1 in `/opt/firefox` (software WebRender, bundled NSS) as the new `aurora-browser` target; Falkon and Epiphany remain installed.
- SwiftShader/ANGLE flags for Falkon (`--enable-unsafe-swiftshader
  --use-angle=swiftshader --use-gl=angle`) to try to paint the web view without
  a GPU.

### Changed

- Identity bumped to `0.5.0-dev (Milestone 4)`.
- AURORA applications: System Info, Diagnostics (failed units, redacted boot errors,
  resources), Settings (xfce4-settings-manager) and Applications (xfce4-appfinder)
  launchers, plus desktop icons.

## [0.4.0-dev] — 2026-11-06

### Added

- AURORA Browser: Falkon 25.12 (Chromium/QtWebEngine) as the default, with a
  desktop icon and menu entry; GNOME Web (Epiphany 49.2) also ships as a
  fallback. Ubuntu's Firefox/Chromium packages are snap stubs, so real debs
  were required.
- `aurora-session-action` helper used by the Log Out, Switch User and Lock
  Screen icons. It restores `DBUS_SESSION_BUS_ADDRESS` when a launcher starts
  without the session bus and performs Switch User through LightDM's
  `dm-tool switch-to-greeter`, falling back to `xfce4-session-logout`.
- Milestone 3 identity: `/etc/aurora-release`, `os-release` and `lsb-release`
  report `0.4.0-dev (Milestone 3)`.

### Changed

- Session action launchers no longer call `xfce4-session-logout` directly, so
  they cannot hit "Could not connect: Permission denied" outside a session bus.
- Credits page URL corrected to `https://github.com/AARUTO347/aurora-os`.

### Fixed

- Build chroot had a dangling `/etc/resolv.conf` symlink; the build now copies
  the host resolver into the chroot before installing packages (KI-031).

## [0.3.0-dev] — 2026-11-05

### Added

- Branded LightDM greeter with the AURORA login logo, wallpaper, Arc-Dark
  theme, and session/power indicators.
- `MADE BY AARUTO` identity across `/etc/aurora-release`, `/etc/lsb-release`,
  `/etc/issue`, `os-release`, the greeter, and `/usr/share/aurora/credits.txt`.
- Credits limited to AARUTO (Abhishek Solanki), DP-_-, and DEV.
- Desktop and application actions for **Log Out**, **Switch User**, and
  **Lock Screen**.
- `aurora-live-password.service` so the live account can log in through the
  greeter after casper removes its password.
- `accountsservice` so the greeter and panel show the full name `AARUTO`.
- `librsvg2-common` for the SVG login logo and `light-locker` for the lock
  screen.
- `aurora-display-setup` to activate the X VT (fixes the hidden greeter on
  some boots).
- `aurora-session-setup` to disable DPMS blanking in the live session.
- `/etc/lightdm/lightdm.conf.d/90-aurora.conf`, a lightdm drop-in that keeps
  autologin off even though casper writes `autologin-user=ubuntu` at boot.
- System-wide XFCE power-manager channel (`/etc/xdg/xfce4/xfconf`) that keeps
  DPMS and display blanking disabled, including after the power manager starts.
- `aurora-identity.service` sets the live account's full name to `AARUTO` and
  the hostname to `aurora` at boot, so the initramfs stays unmodified.
- `aurora-vt.service` activates the X virtual terminal after LightDM starts.
- Casper identity: full name `AARUTO`, hostname `aurora`, flavour `AURORA`.
- Logo mark, wordmark, login banner, wallpaper, palette, and repository
  templates under `distribution/branding/`.

### Changed

- Autologin is disabled; the greeter is the default login path.
- The live user's full name is no longer `Live session user`.
- Version bumped to `0.3.0-dev`.
- LightDM starts X without `-novtswitch`, so X activates its own VT.

### Fixed

- Greeter hidden behind tty1 on live boots (VT not activated).
- Display blanking after the DPMS timeout; X now starts with `-dpms -s 0` and
  the session re-applies `xset` constraints after the power manager starts.
- Logout, switch-user, and lock actions are available from the desktop.
- LightDM really shows the greeter: casper's initramfs stage
  (`casper-bottom/15autologin`) appends `autologin-user=ubuntu` to
  `/etc/lightdm/lightdm.conf` at boot, which made every live boot skip the
  login page. `90-aurora.conf` overrides it and `aurora-identity.service`
  strips the injected keys before LightDM starts.
- Branding files now agree on the version and the credit line.
- Initramfs is kept byte-identical to the known-good casper image; a manually
  repacked gzip cpio made `modprobe overlay` fail during boot.

## [0.2.0-dev] — 2026-11-05

### Added

- XFCE 4.20 desktop on Xorg with LightDM, Arc-Dark theme, elementary icons,
  DejaVu fonts, and the AURORA wallpaper.
- Graphical boot target and live autologin.
- Console, identity, and wallpaper branding.

### Known limitations

- BIOS-only ISO, no Plymouth splash, autologin bypasses the greeter,
  `accountsservice` missing, DPMS blanking, test-only serial root autologin.

## [0.1.0-dev] — 2026-10-31

### Added

- First bootable image: GRUB 2.14 BIOS El Torito, casper squashfs +
  overlayfs, kernel `7.0.0-42-generic`, serial console, branded identity
  files.
