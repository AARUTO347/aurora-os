# AURORA OS - Testing

This is the test plan and the current result register. Only executed tests receive PASS/FAIL.
Planned cases are marked NOT TESTED.

Evidence policy:

- Every build produces a log with versions and artifact checksum; the script reaches its completion
  summary only under `set -eu`.
- Every boot test records the QEMU command, serial log, result JSON, and a QEMU `screendump`.
- Evidence lives outside Git under `/home/aaruto/aurora-build/` (logs, artifacts, evidence/<run>).
- QEMU measurements are kept separate from any physical-hardware measurements.
- VNC stays bound to `127.0.0.1`; no external viewer is used for evidence.
- A boot is only PASS when the serial shell marker and command transcript were actually observed
  by `build/test-qemu.py` and `result.json` says `verified: true`.

---

## Phase A - Environment (Milestone 0)

| ID | Test | Result | Evidence |
|---|---|---|---|
| A-01 | Windows host identity, CPU, RAM | PASS | 2026-10-27 audit; HP 250 G8, i3-1005G1, 11.8 GiB |
| A-02 | WSL distro, kernel, systemd | PASS | Ubuntu 26.04 LTS, 6.18.33.2, `systemd running` |
| A-03 | WSL CPU/RAM/disk | PASS | 4 vCPU, 5.7 GiB RAM, 953 GiB free |
| A-04 | C: and D: mounted | PASS | `grep drvfs /proc/mounts` |
| A-05 | G: excluded, no warning | PASS | automount disabled 2026-10-24; boot log clean |
| A-06 | `/mnt/shared_memory` mounted | PASS | tmpfs entry verified |
| A-07 | QEMU installed and targets available | PASS | QEMU 10.2.1; i386 + x86_64 |
| A-08 | KVM device present | PASS | `/dev/kvm` `root:kvm 0660` |
| A-09 | KVM usable as normal user | **FAIL** | `aaruto` not in `kvm` group; unchanged, requires authorization |
| A-10 | KVM usable as root | PASS | myOS booted, desktop started |
| A-11 | TCG boot as normal user | PASS | myOS headless boot; AURORA also uses TCG |
| A-12 | ISO toolchain present | PASS 2026-10-28 | live-build, debootstrap, xorriso, GRUB modules installed after authorization |
| A-13 | Package candidates resolvable | PASS | `apt-get -s install ...` exit 0 |
| A-14 | OVMF available | PASS | ovmf 2025.11 installed (UEFI AURORA image not built) |

## Phase B - Build (Milestone 1)

Build #6: started 2026-10-31 11:15:25 UTC, completed 11:28:27 UTC (about 13 minutes) from a work
tree that the script reset before starting. Log:
`/home/aaruto/aurora-build/logs/build-20261031-111525.log`. The script printed its completion
summary (`ISO`, `SIZE`, `SHA256`, `LOG`); no error was emitted under `set -eu`.

| ID | Test | Result | Evidence |
|---|---|---|---|
| B-01 | `build-iso.sh` completes and produces an ISO | PASS | `artifacts/aurora-os-0.1.0-dev-amd64.iso`, 504,125,440 bytes |
| B-02 | ISO is non-empty and checksum is recorded | PASS | SHA256 `6d078451d07659ee3023cbd78601e29e8042aedd10f0e15637e64171baefba02`; `.sha256` written |
| B-03a | El Torito BIOS boot record present | PASS | `verify-iso.sh`: BIOS image at LBA 99, `/boot/grub/grub_eltorito`, `boot-info-table` |
| B-03b | EFI boot record present | **FAIL (by design)** | No EFI record exists; image is BIOS-only. UEFI is a documented limitation (KI-015) |
| B-03c | GRUB payload complete | PASS | `grub_eltorito` is 31,662 bytes (core.img embedded); `grub.cfg` has boot entries |
| B-04 | Package manifest and versions recorded | PASS | `linux-image-7.0.0-42-generic 7.0.0-42.42`, `casper 26.04.2`, `initramfs-tools 0.151ubuntu1`, `systemd-sysv 259.9-0ubuntu0.1` |
| B-05 | Clean rebuild produces a valid image | PASS | Build #6 reset the work tree first; verification PASS. Byte-identical rebuilds are NOT TESTED (no reproducible-build claim) |
| B-06 | `/casper` payload complete | PASS | `vmlinuz-7.0.0-42-generic`, `initrd.img-7.0.0-42-generic`, `filesystem.squashfs` (428 MB), manifest |
| B-07 | Image is USB-hybrid | **FAIL (by design)** | Plain ISO 9660; no MBR hybrid signature (KI-016). Not claimed bootable from USB |

## Phase C - Boot (Milestone 1)

Verified twice on 2026-10-31 with QEMU 10.2.1, `-accel tcg`, 2 vCPU, 2048 MiB, ISO as `-cdrom`.
Run 1: 11:31:20-11:36:10 UTC (4 min 50 s wall). Run 2: 11:39:54-11:48:52 UTC (8 min 58 s wall;
slower because the host was busy). Both produced `verified: true` and QEMU exit code 0.

Evidence:

- `/home/aaruto/aurora-build/evidence/final/` (serial.log, result.json, console.ppm)
- `/home/aaruto/aurora-build/evidence/final2/` (serial.log, result.json, console.ppm)

| ID | Test | Result | Evidence |
|---|---|---|---|
| C-01 | QEMU starts GRUB from the ISO | PASS | Kernel command line in serial log proves GRUB loaded and passed `boot=casper ...` |
| C-02 | Kernel and initramfs load | PASS | `Linux version 7.0.0-42-generic`; casper initramfs messages |
| C-03 | Live root filesystem mounts | PASS | `loop0` squashfs + overlayfs messages; casper-bottom completes |
| C-04 | systemd reaches the expected target | PASS | `Reached target multi-user.target`, `graphical.target` |
| C-05 | Login prompt or configured session appears | PASS | VGA screenshot: `AURORA OS 0.1.0-dev  ubuntu tty1` / `ubuntu login:`; serial root shell via test-only autologin |
| C-06 | Serial log contains no fatal errors | PASS (with non-fatal failures) | `networkd-dispatcher`, `casper-md5check`, offline `apt update` warnings; none block multi-user (KI-019, KI-020) |
| C-07 | Second boot reproduces the result | PASS 2026-10-31 | `final2/result.json`: `verified: true`, exit 0 |
| C-08 | UEFI boot with OVMF | NOT TESTED | No EFI boot record in the image |
| C-09 | Clean shutdown | PASS | `sync; poweroff -f` -> `reboot: Power down`, QEMU exit 0 |
| C-10 | Command transcript in the guest | PASS | `uname -a`, `/etc/os-release`, `id`, `ls -l /`, `df -h /`, `/etc/aurora-release` all returned expected output |

Verified guest identity from the serial transcript:

```
Linux ubuntu 7.0.0-42-generic #42-Ubuntu SMP PREEMPT_DYNAMIC Thu Oct 15 08:06:44 UTC 2026 x86_64 GNU/Linux
PRETTY_NAME="Ubuntu 26.04.1 LTS"
VERSION_CODENAME=resolute
uid=0(root) gid=0(root) groups=0(root)
AURORA OS 0.1.0-dev (Milestone 1)      # /etc/aurora-release
```

## Phase D - Desktop (Milestone 3, partial)

| ID | Test | Result |
|---|---|---|
| D-01 | Launcher opens installed applications | NOT TESTED |
| D-02 | Dock shows running applications and switches windows | NOT TESTED |
| D-03 | Terminal runs real commands with correct PATH | PASS 2026-11-05 — `xfce4-terminal` opened from the running session and ran `cat`, `uname`, `free`; output in `aurora-v2-demo.png` |
| D-04 | File manager creates, copies, moves, renames, deletes | NOT TESTED |
| D-05 | Settings change the corresponding system value | NOT TESTED |
| D-06 | Clock shows the actual system time | NOT TESTED (clock widget visible, time not compared) |
| D-07 | Logout, restart, shutdown work from the session | NOT TESTED |
| D-08 | Keyboard navigation and focus indicators work | NOT TESTED |

## Phase E - Reliability (Milestone 5, NOT TESTED)

| ID | Test | Result |
|---|---|---|
| E-01 | Reboot persistence behavior is documented and tested | NOT TESTED |
| E-02 | Missing network is reported honestly | NOT TESTED (offline `apt` warnings observed, not yet a UI behavior) |
| E-03 | Missing audio device is reported honestly | NOT TESTED |
| E-04 | Application crash does not take down the session | NOT TESTED |
| E-05 | Broken desktop configuration can be recovered | NOT TESTED |
| E-06 | Low-memory behavior is observed within reason | NOT TESTED |

## Phase F - Release (Milestone 5, NOT TESTED)

| ID | Test | Result |
|---|---|---|
| F-01 | Versioned ISO and SHA256SUMS exist | NOT TESTED (versioned ISO and `.sha256` exist; release process not defined) |
| F-02 | Instructions reproduce the build on a clean checkout | NOT TESTED |
| F-03 | Known limitations and recovery steps documented | NOT TESTED |
| F-04 | Test-only serial autologin removed | **FAIL (open)** | The M1 image has root autologin on `ttyS0` (KI-018) |

## Phase G - GUI image 0.2.0-dev (Milestone 2, verified 2026-11-05)

Image: `/home/aaruto/aurora-build/artifacts/aurora-os-0.2.0-dev-amd64.iso`, 682,000,384 bytes,
SHA256 `22ce1c653c6927c6b93fbe22cee889a209743ddf896df96ea330f4d88cd50a16`.
One graphical boot, QEMU 10.2.1 TCG, 2 vCPU, 2048 MiB, `-vga std`, VNC `127.0.0.1:1`, monitor
socket and serial log in `evidence/`. Caveat: the ISO was produced by resuming `lb binary` after
the first build was killed at the squashfs stage (see G-00).

| ID | Test | Result | Evidence |
|---|---|---|---|
| G-00 | Clean end-to-end build | **NOT TESTED** | Binary stage resumed from a complete chroot; a full `build/build-iso.sh` rebuild is required before any reproducibility claim |
| G-01 | `verify-iso.sh` on the GUI image | PASS | RESULT: PASS — BIOS El Torito at LBA 99, GRUB payload 31,662 bytes, `/casper` kernel/initramfs/filesystem.squashfs present |
| G-02 | systemd reaches `graphical.target` | PASS | serial log: `Reached target graphical.target` |
| G-03 | LightDM starts and opens a session | PASS | `systemctl status lightdm` active; Xorg `:0 ... vt7 -novtswitch`; `pam_unix(lightdm-autologin:session): session opened for user ubuntu` |
| G-04 | XFCE session components run | PASS | `pgrep` shows `xfce4-session`, `xfce4-panel`, `xfwm4`, `xfdesktop` |
| G-05 | AURORA wallpaper and dark theme render | PASS | `aurora-v2-desktop.png`: aurora gradient backdrop, Arc-Dark windows, panel and dock |
| G-06 | AURORA identity files in the guest | PASS | terminal: `/etc/aurora-release` -> `AURORA OS 0.2.0-dev (Milestone 2)`, `Base: Ubuntu 26.04 LTS (resolute)`; kernel `7.0.0-42-generic`; tty1 banner `AURORA OS 0.2.0-dev` |
| G-07 | Desktop terminal launches and runs commands | PASS | `aurora-v2-demo.png`: `cat /etc/aurora-release`, `uname -r`, `free -h` (`1.9Gi` total, `850Mi` free, no swap) |
| G-08 | LightDM greeter screenshot | NOT TESTED | Autologin for `ubuntu` bypasses the greeter; requires a build with autologin disabled |
| G-09 | Second graphical boot reproduces the result | NOT TESTED | Only one GUI boot so far |
| G-10 | Session logout / restart / shutdown | NOT TESTED | Not exercised in this run |
| G-11 | Panel shows the real user name | **FAIL** | Panel shows "Live session user"; `accountsservice` is not installed (KI-023) |
| G-12 | Screen stays awake without input | **FAIL** | X DPMS blanks the screen after idle; a keypress on VT7 wakes it (KI-024) |
| G-13 | Failed systemd units in the GUI image | PASS (with known non-fatal units) | `casper-md5check.service`, `networkd-dispatcher.service` fail; `graphical.target` still reached (KI-020, KI-025) |

Note on G-00: `verify-iso.sh` PASS on a resumed-stage image shows the artifact is structurally
valid and boots, not that the build is reproducible. Do not cite it as reproducible-build evidence.

---

## Phase H - GUI login, logout, switch-user (0.3.0-dev, 2026-11-06)

Image: `artifacts/aurora-os-0.3.0-dev-amd64.iso`, 693,329,920 bytes, SHA256
`ebc54345bbf131c0d63e8c84e2821ae17347f7b18479f68ea103c9aee135af90`. Built with
`lb binary` after the stage-050 sync (`/home/aaruto/aurora-build/logs/rebuild-050.log`,
`BUILD_EXIT=0`); the casper initrd is the known-good `d203e1a3...` image.

QEMU 10.2.1, `-machine q35 -accel tcg -m 3072 -smp 2 -vga std -display none -nic none`, ISO as
`-cdrom`, monitor + serial on unix sockets. Runs: `/home/aaruto/aurora-test/h4`
(20:40-21:05 UTC, full flow), `/home/aaruto/aurora-test/h5` (21:06-21:28 UTC, repeat of the full
flow: logout `ubuntu session gone=True`, second login `attempt 1 detected=True`, switch-user
`new greeter session=True`) and `/home/aaruto/aurora-test/h1` (19:46-20:04 UTC, first greeter run).
Screenshots are copied to `docs/screenshots/`; serial logs and PPM originals stay outside Git.

| ID | Test | Result | Evidence |
|---|---|---|---|
| H-01 | Build contains the login/session fixes | PASS | squashfs: `lightdm.conf.d/90-aurora.conf`, `50-aurora.conf` with `xserver-command=X -nolisten tcp -dpms -s 0`, `aurora-identity` with the autologin cleanup |
| H-02 | casper autologin no longer bypasses the greeter | PASS | pre-login sessions are root `ttyS0` + a `lightdm` class-`greeter` seat0 session only; no `autologin-user=` key in `/etc/lightdm/lightdm.conf`; syslog `AURORA_IDENTITY_READY user=ubuntu fullname=AARUTO host=aurora autologin=no` |
| H-03 | Branded greeter is drawn with the AURORA identity | PASS | `docs/screenshots/greeter.png` (aurora wallpaper, hostname `aurora`, date, `AARUTO`, password field, **Log In**) |
| H-04 | Password login opens the XFCE session | PASS | `02-login: login attempt 1 detected=False`, `attempt 2 detected=True` (the first keystrokes landed before the greeter took focus); `loginctl` shows `1000 ubuntu seat0`; `xfce4-panel` running |
| H-05 | Desktop shows panel, dock and AURORA actions | PASS | `docs/screenshots/desktop.png` (h1 run): panel with `AARUTO`, desktop icons Home/File System/AURORA Switch User/AURORA Log Out/AURORA Lock Screen, dock |
| H-06 | Logout returns to the greeter | PASS | `03-after-logout: ubuntu session gone=True`; `greeter ready session_present=True`; `docs/screenshots/after-logout.png` |
| H-07 | Second login works after logout | PASS | `04-login-again: login attempt 1 detected=True`; panel running |
| H-08 | Switch User keeps the session and shows the greeter | PASS | `docs/screenshots/switch-user.png` (greeter in unlock mode); h1 serial shows a second `lightdm` `greeter` session (`c2`) on `fgconsole` 8 while the `ubuntu` seat0 session stayed alive |
| H-09 | The display cannot be blanked by DPMS | PASS | `xset q` in the session: `Server does not have the DPMS Extension` (X started with `-dpms`) |
| H-10 | X runs on the foreground VT | PASS | `fgconsole` = `7`; `Xorg -nolisten tcp -dpms -s 0 ... vt7 -novtswitch`; `aurora-vt` = `active` |
| H-11 | Test VM stops without a crash | PASS | harness sends `quit` to the QEMU monitor and waits for the process; guest-initiated shutdown/restart is NOT TESTED |

Caveats recorded with the PASS:

- LightDM still appends `-novtswitch` to the X command line (H-10); `aurora-display-setup` and
  `aurora-vt` make the VT active, so H-10 passes with that workaround.
- LightDM logs an AccountsService permission warning because `policykit-1` is not installed; the
  greeter and the `AARUTO` name still work. `/var/lib/lightdm/data` is still missing (KI-026).
- TCG makes the first XFCE draw take minutes; the harness waits for the panel process and lit
  pixels instead of fixed sleeps (KI-029).
- The desktop capture comes from the h1 run; h4 produced the greeter/login/logout/switch frames.


---

## Phase I - 0.4.0-dev browser, session actions and boot tuning (2026-11-06)

Image: `artifacts/aurora-os-0.4.0-dev-amd64.iso`, 896,860,160 bytes, SHA256
`ad7317af165926d39b29443a1cda43cc061ecaefdc1d9310f2df748ca4178d44`. The squashfs was built
directly from the verified chroot and remapped into the ISO; the casper initrd is the known-good
`d203e1a3...` image. QEMU 10.2.1 TCG, 4 vCPU, 3072 MiB, `-vga std`.

Runs: `/home/aaruto/aurora-test/p4` (full flow), `/home/aaruto/aurora-test/p7` (browser check),
`/home/aaruto/aurora-test/p8` (browser rendering retry).

| ID | Test | Result | Evidence |
|---|---|---|---|
| I-01 | Image contains the browser and session-action changes | PASS | squashfs: `usr/bin/epiphany`, `usr/local/bin/aurora-browser`, `aurora-session-action`, `etc/skel/Desktop/aurora-browser.desktop`, `etc/systemd/system.conf.d/aurora-timeouts.conf`, masked `networkd-dispatcher.service`/`casper-md5check.service`; identity `AURORA OS 0.4.0-dev (Milestone 3)` |
| I-02 | Boot reaches the branded greeter | PASS | serial shell marker, `lightdm active`, greeter `session_present=False`; `01-greeter.png` |
| I-03 | Password login opens the XFCE session | PASS | `02-login: login attempt 1 detected=True`; session `1000 ubuntu seat0`; `xfce4-panel` running |
| I-04 | Desktop shows the AURORA Browser launcher | PASS | `docs/screenshots/desktop.png` (Home, File System, Switch User, Log Out, Lock Screen, Browser; dock) |
| I-05 | Browser opens and renders a page | **FAIL** (window opens, page not painted) | Chromium-engine Falkon opens a real window (`browser running=True`; `docs/screenshots/browser.png`) but the web view stays transparent under the software-only Xorg; earlier Epiphany/WebKit aborted with SIGABRT. Sandbox/GPU/compositing disabled, software GL, XDG/HOME set (KI-032) |
| I-06 | Log Out uses the session helper | PASS | `AURORA_SESSION_ACTION action=logout`; `04-after-logout: ubuntu session gone=True`; greeter redrawn |
| I-07 | Second login works | PASS | `05-login-again: login attempt 1 detected=True` |
| I-08 | Switch User uses LightDM dm-tool | PASS | `AURORA_SESSION_ACTION action=switch method=dm-tool`; `06-after-switch: new greeter session=True` while the `ubuntu` session stayed alive |
| I-09 | DPMS cannot blank the screen | PASS | `xset q`: `Server does not have the DPMS Extension` |
| I-10 | Offline-only units no longer stall the boot | PASS (partial measurement) | `networkd-dispatcher` and `casper-md5check` are masked symlinks to `/dev/null`; `DefaultTimeoutStartSec=30s`; p4/p7 boot logs no longer show the 2-minute network job waits. `systemd-analyze` output was not captured reliably under TCG |
| I-11 | Test VM stops without a crash | PASS | harness quits QEMU; guest-initiated shutdown/restart NOT TESTED |

Caveats:

- The browser is the one FAIL in this phase: Falkon (Chromium) opens a window but its page surface
  is not rendered by the emulated adapter; Epiphany/WebKit aborted outright. It remains untested on
  VMware or real hardware (KI-032).
- The image remains test-profile only: root serial autologin (KI-018), BIOS-only (KI-015), no
  installer, no Plymouth.


---

## Phase J - 0.5.0-dev polkit, LightDM data dir, browser retry (2026-11-07)

Image: `artifacts/aurora-os-0.5.0-dev-amd64.iso`, 896,991,232 bytes, SHA256
`7ecbf55d5c7eef3198692fef1a2e75af16fcc52b515672a8b0be8229ccb1fe5c`; identity
`AURORA OS 0.5.0-dev (Milestone 4)`; initrd `d203e1a3...`. QEMU TCG, 4 vCPU, 3072 MiB.

Run: `/home/aaruto/aurora-test/p11` (browser-only flow).

| ID | Test | Result | Evidence |
|---|---|---|---|
| J-01 | polkit present, LightDM AccountsService warning gone | PASS | `polkitd`/`pkexec` in the squashfs; zero `PolicyKit1` messages in the p11 serial log (previously logged twice per boot) |
| J-02 | `/var/lib/lightdm/data` exists | PASS | created by `0400-gui.chroot`; the "Could not enumerate user data directory" warning is absent |
| J-03 | Branded greeter + password login | PASS | greeter ready, `login attempt 1 detected=True` |
| J-04 | Browser window renders a page | **FAIL** | Falkon starts (`browser running=True`) but no window is visible at capture; the SwiftShader/ANGLE flags did not fix the page surface under the software-only Xorg (KI-032) |


---

## Phase K - Firefox browser rendering (0.5.0-dev, 2026-11-08)

The Falcon/WebKit/QtWebEngine attempts do not paint under the emulated adapter. The image was
rebuilt with the official Mozilla Firefox tarball (`/opt/firefox`, version 159.0.1) and
`aurora-browser` now sets `LD_LIBRARY_PATH=/opt/firefox`, `GDK_BACKEND=x11`, software GL, and the
content sandbox disabled. Firefox can render with software WebRender, which is the most likely
fix for a GPU-less VM.

- ISO: `artifacts/aurora-os-0.5.0-dev-amd64.iso`, 1,049,690,112 bytes, SHA256
  `d631d18b688f00bb75c1ed36add853d982237b724d5a812abb440a2e976dbf9e` (zstd squashfs).
- Verification: **PASS**. Run `/home/aaruto/aurora-test/p14` (QEMU TCG, 4 vCPU, 3072 MiB):
  `Mozilla Firefox 159.0.1`, `browser running=True`, and the screendump shows the full browser
  window (tab bar, address bar, toolbar) rendered on the XFCE desktop — see
  `docs/screenshots/browser.png`. This confirms Firefox's software WebRender works without a GPU.
- A GPU-capable VM could not be provisioned here (no VMware installer; QEMU virgl has no DRM in
  WSL), so the PASS is for the software path, which is what the live image uses.

---

## Existing myOS tests (reference only, not AURORA)

| ID | Test | Result | Evidence |
|---|---|---|---|
| M-01 | myOS builds without error | PASS 2026-10-27 | `make` (up to date) |
| M-02 | Headless QEMU self-test | PASS 2026-10-27 | `self-test passed`; desktop started 1024x768 |
| M-03 | GUI renders desktop | PASS 2026-10-24 | `myos-shots/live.png` |
| M-04 | myOS clock matches host at capture | PASS 2026-10-24 | Screenshot showed `24 Oct 2026 17:06` |

myOS tests do not validate AURORA and must not be counted toward any AURORA milestone.

---

## Standard AURORA test invocation (VERIFIED)

```bash
python3 /home/aaruto/aurora-os/build/test-qemu.py \
    /home/aaruto/aurora-build/artifacts/aurora-os-0.1.0-dev-amd64.iso \
    --timeout 600 --evidence /home/aaruto/aurora-build/evidence/<run>
```

The harness exits 0 only when `AURORA_M1_SHELL_OK` and the command transcript were observed;
`result.json` records ISO size/SHA256, QEMU version and command, markers, kernel version, and exit
code. Run it detached (`setsid nohup ... &`) when the surrounding shell has a short timeout.

GUI invocation (VERIFIED 2026-11-05; manual, the harness does not yet automate the desktop):

```bash
qemu-system-x86_64 -accel tcg -m 2048 -smp 2 -cdrom <iso> \
  -vga std -display none -vnc 127.0.0.1:1 \
  -monitor unix:/home/aaruto/aurora-build/evidence/gui-run.mon,server,nowait \
  -serial file:/home/aaruto/aurora-build/evidence/gui-run-serial.log -daemonize
```

`-display gtk` can be added for a native WSLg window, but evidence must come from the monitor
`screendump` files. Wake the display with `ctrl-alt-f7` plus any key before capturing if the
screen is black (DPMS, KI-024).

Record: date/time, command, guest memory/CPU, TCG, boot time, failed units, serial errors,
screenshot path, and any deviation from this document.
