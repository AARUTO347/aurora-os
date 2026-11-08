# Changelog

All notable changes to AURORA OS are recorded here. Versions follow
`MAJOR.MINOR.PATCH` with a `-dev` suffix for images that are not releases.

## [0.5.0-dev] — 2026-11-06

### Added

- `polkitd` + `pkexec` so LightDM can update the AccountsService record without
  the "org.freedesktop.PolicyKit1 was not provided" warning.
- `/var/lib/lightdm/data` created by the GUI hook (KI-026).
- SwiftShader/ANGLE flags for Falkon (`--enable-unsafe-swiftshader
  --use-angle=swiftshader --use-gl=angle`) to try to paint the web view without
  a GPU.

### Changed

- Identity bumped to `0.5.0-dev (Milestone 4)`.

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
