# AURORA OS - Known Issues

Last updated: 2026-11-06 (0.4.0-dev browser and session-action fixes).

Severity: Low / Medium / High. Status: Open / Mitigated / Resolved / Informational.

## Image and boot issues

| ID | Issue | Severity | Status | Details and workaround |
|---|---|---|---|---|
| KI-015 | Image is BIOS-only (no UEFI boot) | Medium | Open | `xorriso -report_el_torito plain` shows only the BIOS El Torito image; no EFI system partition or EFI boot record exists. Verification explicitly reports "EFI boot record NOT PRESENT". UEFI/OVMF boot is NOT TESTED. Planned for a later milestone; never change host Secure Boot. |
| KI-016 | ISO is not USB-hybrid | Low | Open | Built with `--binary-images iso`, so there is no MBR hybrid signature. `isohybrid` rejects GRUB El Torito images (`boot loader does not have an isolinux.bin hybrid signature`). The image is for optical/QEMU `-cdrom` use only until a hybrid mastering step is added (Milestone 5). |
| KI-017 | Serial getty fails on slow TCG boots | Medium | Mitigated (test image) | The device unit generated from `console=ttyS0` waits for `dev-ttyS0.device`; on this host udev coldplug took longer than the 90 s device timeout, so `serial-getty@ttyS0.service` failed with "Dependency failed". The test hook masks that unit and runs `agetty` directly against `/dev/ttyS0` (`aurora-serial-getty.service`). Verified on 2026-10-31. A release image should fix ordering instead of masking. |
| KI-018 | Root autologin on the serial console | High (for release) / Informational (test) | Open (test-only) | `config/hooks/0100-serial-autologin.chroot` creates `agetty --autologin root` on `ttyS0` and prints an evidence marker. This exists only to prove the shell automatically in CI-style boots. It must be removed or gated before any release or physical use. |
| KI-019 | casper runs `apt update` at boot without network | Informational | Open | The guest logs `Temporary failure resolving 'archive.ubuntu.com'` and continues. Expected for an offline QEMU boot; no package data is needed at runtime. The minimal image does not include a network stack configuration beyond the base. |
| KI-020 | Non-fatal failed units in QEMU | Informational | Open | `networkd-dispatcher.service` and `casper-md5check.service` fail in the offline minimal image (no dispatcher config / no checksum file). Multi-user target is still reached and the console works. Revisit when networking and release checksums are added. |
| KI-021 | casper crash-file warnings | Low | Open | `touch/rm /root/var/crash/crash.init: No such file or directory` during casper-bottom. Cosmetic; remove by ensuring `/var/crash` exists in the chroot if it becomes noisy. |
| KI-010 | Desktop features incomplete | Medium | Mitigated (M2) / Open (M3+) | As of 0.2.0-dev the image boots to XFCE 4.20 through LightDM with a terminal, file manager, panel and desktop. Logout/restart/shutdown, deliberate panel/dock layout, settings entry points, AURORA applications, and session recovery are still missing and remain NOT TESTED. |
| KI-023 | Panel shows "Live session user" | Low | Resolved 2026-11-05 | `accountsservice` 23.13.9 is installed and `accounts-daemon.service` is enabled; `aurora-identity.service` sets the gecos to `AARUTO`. The panel and the session menu show `AARUTO` (evidence `aurora-test/final/04-login-again-desktop.png`). |
| KI-024 | X DPMS blanks the screen after idle | Low | Resolved 2026-11-06 | X now starts with `-dpms -s 0`; `aurora-display-setup` and `aurora-session-setup` also run `xset s off -dpms`, and the session retries the xfconf power-manager settings for 20 s so it wins the race against `xfce4-power-manager`. `xset q` in the 0.3.0 session reports `Server does not have the DPMS Extension` (TESTING.md H-09). |
| KI-025 | `casper-md5check.service` fails in the GUI image | Informational | Open | Same cause as KI-020: the image has no `md5sum.txt`. Does not block `graphical.target` or LightDM. Will be resolved when release checksums are generated (Milestone 5). |
| KI-026 | LightDM warning about missing data directory | Low | Open | LightDM logs that `/var/lib/lightdm/data` is absent; the greeter still starts. Create the directory in a chroot hook or via the package's tmpfiles entry in a later build. |
| KI-027 | VT7 stays inactive after XFCE starts | Medium | Resolved 2026-11-05 | `xserver-command=X -nolisten tcp ...` drops LightDM's `-novtswitch`, and `aurora-vt.service` reads `vtN` from the Xorg command line and calls `chvt`. Serial evidence: `fgconsole` = `7`, `aurora-vt` = `active`. The black screendumps in the same run were caused by KI-028 (the autologin session had not drawn yet), not by the VT. |
| KI-028 | casper forces a passwordless autologin, hiding the greeter | High (for the login page) | Resolved 2026-11-06 | The initramfs script `casper-bottom/15autologin` appends `[SeatDefaults] autologin-user=ubuntu` to `/etc/lightdm/lightdm.conf` at every boot. That is why early 0.3.0 boots showed an `ubuntu seat0` session and no `lightdm-gtk-greeter` process even though the image ships no autologin setting. `90-aurora.conf` (read after `lightdm.conf`) sets `autologin-user=`, and `aurora-identity.service` strips the injected keys before LightDM starts. Verified in TESTING.md H-02. |
| KI-030 | Session launchers failed with "Could not connect: Permission denied" | Medium | Resolved 2026-11-06 | `xfce4-session-logout` needs `DBUS_SESSION_BUS_ADDRESS`; a launcher started outside the session bus failed. The desktop icons now call `/usr/local/bin/aurora-session-action`, which restores the bus address and switches user through LightDM `dm-tool switch-to-greeter` (falling back to `xfce4-session-logout`). |
| KI-031 | Chroot apt failed to resolve `archive.ubuntu.com` | Medium | Resolved 2026-11-06 | The build chroot's `/etc/resolv.conf` is a dangling symlink to `/run/systemd/resolve/stub-resolv.conf`, which does not exist inside the chroot. The 0.4.0 build copies the host resolver into the chroot before installing packages; make this part of `build-iso.sh`. |
| KI-032 | Browser page surface is not rendered under the TCG VM | Medium | Open | WebKitGTK needs unprivileged user namespaces for bubblewrap; the live image does not load the AppArmor profile that grants them, and the emulated Xorg has no hardware GL. `/usr/local/bin/aurora-browser` launches Falkon (Chromium/QtWebEngine) with `QTWEBENGINE_DISABLE_SANDBOX=1`, `--no-sandbox --disable-gpu --disable-gpu-compositing --single-process`, XDG_RUNTIME_DIR and HOME. Falkon opens a window but the web view stays transparent; Epiphany/WebKit aborted with SIGABRT (empty log). Probably needs a GPU-capable VM or real hardware. |
| KI-029 | TCG boot to the desktop takes 8-10 minutes | Informational | Open (test image) | Without KVM (KI-003) the first XFCE session needs several minutes to draw under TCG, so a screendump taken right after LightDM starts can show a black root window with only the cursor. The harness now waits for lit pixels instead of a fixed delay. Physical hardware and KVM boots are not affected. |

## Build-environment issues

| ID | Issue | Severity | Status | Details and workaround |
|---|---|---|---|---|
| KI-003 | `aaruto` cannot open `/dev/kvm` | Medium | Open | Device is `root:kvm 0660`; the user is not in the `kvm` group. QEMU uses TCG (slow). The group change and WSL restart still require explicit authorization; no change was made. |
| KI-004 | ISO toolchain missing | High | Resolved 2026-10-28 | `live-build`, `debootstrap`, `xorriso`, `grub-pc-bin`, GRUB modules, `mtools`, `dosfstools`, `cpio` installed after authorization and version checks. |
| KI-011 | `live-build` 3.0~a57 vs Ubuntu 26.04 | Medium | Mitigated | The fork's syslinux+casper path is unusable (theme packages and `/casper` layout mismatch). Verified path is GRUB2-only with two workarounds: a `grub-mkimage -p /boot/grub` wrapper (GRUB 2.14 requires a prefix) and copying modules into `binary/boot/grub/i386-pc/` (GRUB 2.14 module layout). Both are committed in `build/live-build/`. |
| KI-022 | WSL distro terminated mid-build | Medium | Mitigated by procedure | A build started as a child of an interactive tool session was killed when the launcher timed out; WSL then tore down the session (`DBG_TERMINATE_PROCESS`). Long builds/tests now run detached (`setsid nohup ... &`) and are polled. |
| KI-007 | WSL RAM limited to 5.7 GiB of 11.8 GiB | Medium | Open | Keep the guest at 2048 MiB and avoid running QEMU during a build. `.wslconfig` was not changed. |
| KI-008 | apt 403 User-Agent blocking (past) | Low | Mitigated | `/etc/apt/apt.conf.d/99local-useragent` remains in place. `scripts/diagnose-apt.sh --quick` is the build preflight; if 403s return, inspect UA and source backups before changing anything else. |
| KI-001 | WSLg copy mode / shared-memory failure | Medium | Mitigated | WSLg can fail `rdp_allocate_shared_memory`, leaving QEMU taskbar-only. Evidence path is loopback VNC + `screendump`, not WSLg. |
| KI-002 | `wsl: Failed to mount G:\` on every start | Medium | Resolved 2026-10-24 | Automount disabled; C:, D:, and `/mnt/shared_memory` mounted via `/etc/fstab`. Backups exist under `/root/`. |
| KI-005 | myOS is not under version control | Low | Open | Preserved as-is, separate from AURORA. Do not clean up its artifacts without a backup. |
| KI-009 | X11 window capture is not proof of Windows-side visibility | Low | Informational | Use QEMU VNC/screendump for evidence. |
| KI-012 | Legacy timezone warning in WSL boot log | Low | Informational | `Asia/Calcutta` zoneinfo warning; use `Asia/Kolkata` if a timezone is configured. |
| KI-013 | No VNC client installed in WSL | Low | Open | A Windows VNC viewer or tunnel is needed for interactive use. Do not add noVNC or third-party code without approval; keep VNC on loopback. |
| KI-014 | Duplicate QEMU instances possible | Low | Mitigated by procedure | Check `pgrep -af '^qemu-system-x86_64'` before launch; never use broad `pkill -f` patterns that can match the calling shell. |

## Reporting a new issue

Record: date, command, expected result, actual result, serial log path, screenshot path, host state
(WSL restart or not). Do not include credentials or personal data. Update this table and
`docs/PROJECT_AUDIT.md` if the issue changes the environment assessment.
