# AURORA OS - Project Audit

- Audit date: 2026-10-27
- Auditor: Qoder (automated inspection; every result below was produced by an executed command, not assumed)
- Scope: host environment, WSL 2 development environment, QEMU, existing myOS project, available build tooling
- Result: **Milestone 0 PASS** (the existing state is now understood; no AURORA image exists yet)

Status labels used in this document: **PASS** (verified working), **FAIL** (tested and broken),
**BLOCKED** (cannot proceed until a dependency or permission is resolved), **NOT TESTED** (no verification performed).

---

## 1. Executive summary

- The host and WSL environment are suitable for building an Ubuntu-derived ISO.
- QEMU 10.2.1 is installed with `tcg`, `mshv`, and `kvm` accelerators. KVM works when run as root,
  but the default user `aaruto` cannot open `/dev/kvm` (not in the `kvm` group), so user-level QEMU
  currently falls back to TCG.
- The ISO-building toolchain is incomplete. `live-build`, `debootstrap`, `xorriso`, GRUB ISO modules,
  `mtools`, `dosfstools`, `genisoimage`, `cpio`, and syslinux tools are missing. All have install
  candidates in the configured Ubuntu 26.04 repositories (`apt-get -s install` returned 0).
- The existing `myOS` project is a 32-bit bare-metal hobby kernel with a custom GUI. It is **not a
  Linux distribution** and is not a usable AURORA base. It builds and boots successfully and is
  preserved unchanged.
- A new, empty AURORA repository was created at `/home/aaruto/aurora-os` on the WSL ext4 filesystem.
  No ISO, root filesystem, initramfs, or bootloader exists for AURORA yet.
- The smallest safe next step is Milestone 1: install the missing ISO tooling, add the user to the
  `kvm` group, and produce a minimal bootable Ubuntu-based live ISO, tested in QEMU.

---

## 2. Host environment (verified 2026-10-27)

| Item | Value | Status |
|---|---|---|
| Host model | HP 250 G8 Notebook PC | PASS |
| CPU | Intel Core i3-1005G1, 2 cores / 4 threads | PASS |
| Host RAM | 12,656,099,328 bytes (about 11.8 GiB) | PASS |
| Windows | Windows 11 Home Single Language, 10.0.26200.9278 | PASS |
| WSL | 2.7.12.0 | PASS |
| WSL kernel | 6.18.33.2-microsoft-standard-WSL2 (x86_64) | PASS |
| WSL distro | Ubuntu 26.04 LTS, codename `resolute` | PASS |
| Default user | `aaruto`, uid 1000, member of sudo | PASS |
| systemd in WSL | `systemctl is-system-running` = `running` | PASS |
| vCPU seen by WSL | 4 | PASS |
| RAM seen by WSL | 5.7 GiB total, 2.0 GiB swap | PASS |
| WSL root filesystem | ext4, 1.0 TB virtual disk, 953 GiB available | PASS |
| C: free space | 128 GiB of 272 GiB | PASS |
| D: free space | 153 GiB of 204 GiB | PASS |
| WSLg | 1.0.73.2; MSRDC 1.2.7214; Direct3D 1.611.1 | NOT TESTED (current session) |

Note: Windows reports `VirtualizationFirmwareEnabled = False`. That value is unreliable when
Hyper-V/WSL owns virtualization; `/dev/kvm` exists and a KVM boot was verified, so nested
virtualization is functional.

### 2.1 WSL mounts

| Mount | Type | Status |
|---|---|---|
| `/mnt/c` | drvfs (C:) | PASS |
| `/mnt/d` | drvfs (D:) | PASS |
| `/mnt/shared_memory` | tmpfs | PASS |
| G: | not mounted | PASS (intentionally excluded) |

On 2026-10-24 WSL auto-mounting was replaced with explicit fstab entries for C: and D: because G:
is an empty 256 MB FAT32 volume that drvfs cannot mount (`fsconfig system call failed: Operation
not supported`) and produced `wsl: Failed to mount G:\` on every start. Backups:
`/root/fstab.backup-20261024`, `/root/fstab.backup-20261024-2`,
`/root/wsl.conf.backup-20261024`, `/root/wsl.conf.backup-20261024-2`.

### 2.2 Virtualization and QEMU

| Check | Result | Status |
|---|---|---|
| QEMU version | 10.2.1 (Debian 1:10.2.1+ds-1ubuntu3.3) | PASS |
| QEMU targets | `qemu-system-x86_64`, `qemu-system-i386`, `qemu-img` present | PASS |
| Accelerators reported | `tcg`, `mshv`, `kvm` | PASS |
| `/dev/kvm` | present, `crw-rw---- root:kvm` | PASS (device) |
| `aaruto` opens `/dev/kvm` | `PermissionError: [Errno 13]` | **BLOCKED** |
| KVM boot as root | myOS self-test passed, desktop started | PASS |
| TCG boot as `aaruto` | myOS self-test passed, desktop started | PASS |

The KVM permission issue is solved by `sudo usermod -aG kvm aaruto` followed by one WSL restart.
Until then, QEMU must run with `-accel tcg` (slow) or through root.

---

## 3. Build toolchain

Present:

| Tool | Version / path |
|---|---|
| gcc | 15.2.0 (`/usr/bin/gcc`) |
| make | present |
| git | 2.53.0 |
| python3 | 3.14.4 |
| QEMU | 10.2.1 |
| mksquashfs | squashfs-tools 4.7.5 |
| rsync, curl, wget, gzip, xz | present |
| OVMF firmware | 2025.11-3ubuntu7.3 installed (UEFI QEMU boot possible) |

Missing (install candidates confirmed in Ubuntu 26.04 repositories):

| Package / command | Candidate |
|---|---|
| live-build (`lb`) | 3.0~a57-1ubuntu54 |
| debootstrap | 1.0.142ubuntu2 |
| xorriso | 1:1.5.6-1.1ubuntu4 |
| grub-pc-bin / grub-mkrescue | 2.14-2ubuntu2.1 |
| grub-efi-amd64-bin | 2.14-2ubuntu1 |
| mtools (`mcopy`, `mmd`) | 4.0.49-1 |
| dosfstools (`mkfs.vfat`) | 4.2-1.2build1 |
| genisoimage | not installed |
| cpio | not installed |
| isolinux / syslinux-common / isohybrid | 3:6.04~git20190206...+dfsg1-3.2ubuntu1 |

`apt-get -s install --no-install-recommends live-build debootstrap xorriso grub-pc-bin
grub-efi-amd64-bin mtools dosfstools isolinux syslinux-common cpio` exited 0, so the set is
resolvable without changing the system.

Git has no configured identity (`~/.gitconfig` absent). The AURORA repository is initialized but has
no commits; an author name and email must be configured before the first commit.

---

## 4. Existing myOS project

- Root: `C:\Users\AARUTO\Documents\Qoder\2026-10-23\3dc41ae1\myos`
  (WSL: `/mnt/c/Users/AARUTO/Documents/Qoder/2026-10-23/3dc41ae1/myos`).
- Version control: none (the workspace is not a Git repository).
- Size: about 3,900 lines of C, assembly, and headers, plus generated `.o` files and `kernel.elf`.
- Architecture: 32-bit x86 multiboot kernel, loaded directly by QEMU with `-kernel`.
  - `boot.S` multiboot header, `linker.ld`.
  - GDT, IDT with catch-all handlers, PIC, PIT, PS/2 keyboard and mouse.
  - Physical memory manager, paging, kernel heap, string/console routines.
  - VBE linear framebuffer at 1024x768, font rendering, custom compositor/window manager.
  - Seven in-kernel applications: Terminal, Monitor, Settings, About, Files, Notepad, Clock
    (`apps.h`: `APP_TERMINAL`, `APP_MONITOR`, `APP_SETTINGS`, `APP_ABOUT`, `APP_FILES`,
    `APP_NOTEPAD`, `APP_CLOCK`).
- What it is not: no Linux kernel, no bootloader, no initramfs, no root filesystem, no ring 3 user
  space, no scheduler, no networking, no persistent storage. It cannot be extended into a Linux
  distribution; AURORA is a separate project.
- Generated versus source: `*.o` and `kernel.elf` are generated; `*.c`, `*.h`, `*.S`, `linker.ld`,
  `Makefile`, `run.sh`, `run-myOS.cmd`, and `tools/*.py` are source; `shots/*.png` are test evidence.
- Launchers: `run.sh` runs `GDK_BACKEND=x11 qemu-system-i386 -kernel kernel.elf -m 256
  -serial file:/tmp/myos.log`; `run-myOS.cmd` is the Windows double-click launcher.
- Verification:
  - 2026-10-27: `make` (up to date), 8-second headless QEMU boot: `self-test passed`,
    `gfx: 1024x768 framebuffer, starting desktop`, `gui: desktop started (1024x768)` - PASS.
  - 2026-10-24: GUI capture `myos-shots/live.png` via X11 window capture; RTC displayed
    `Sat 24 Oct 2026 17:06` at capture time - PASS.
  - 2026-10-27: KVM boot as root reached the same desktop-started message - PASS.
- The project remains untouched by this audit. It is **not** part of the AURORA build.

---

## 5. Findings by classification

### Verified working

1. WSL 2 / Ubuntu 26.04 LTS boots with systemd and 4 vCPUs.
2. C: and D: are mounted; `/mnt/shared_memory` is mounted for WSLg.
3. QEMU 10.2.1 supports both 32-bit and 64-bit x86 guests.
4. KVM acceleration works at the hypervisor level (verified as root).
5. TCG boot of the existing myOS kernel succeeds.
6. myOS builds and boots; its GUI was verified by capture.
7. Ubuntu package metadata is present and the ISO toolchain is resolvable.
8. OVMF firmware is installed for later UEFI boot tests.

### Verified broken / blocked

1. `aaruto` cannot access `/dev/kvm` (not in the `kvm` group). Accelerated QEMU as the normal user
   is BLOCKED until the group change is applied and WSL is restarted.
2. ISO build tooling is missing (Section 3). This blocks Milestone 1 until installed.
3. G: auto-mount failure was a host/WSL configuration defect; it is resolved and no longer appears.
4. WSLg copy-mode (`rdp_allocate_shared_memory` failure) occurred before the 2026-10-24 fix and
   remains an intermittent risk. It is a host GUI defect, not a guest-kernel defect. Prefer QEMU
   VNC on loopback and QEMU `screendump` for deterministic display and evidence.

### Not tested

- Any AURORA ISO build, live boot, login, desktop session, networking, audio, persistence,
  installer, Secure Boot, or physical-hardware boot.
- `live-build` compatibility with Ubuntu 26.04 (`resolute`).
- XFCE, LightDM, PipeWire, or NetworkManager availability and behavior in a live image.
- WSLg rendering in the current boot (no GUI captured in this audit session).

### Proposed improvements

1. Add `aaruto` to the `kvm` group, restart WSL once, and verify `qemu-system-x86_64 -accel kvm`.
2. Install the missing packages listed in Section 3, recording versions in build logs.
3. Establish the repository layout, `.gitignore`, and a first commit after configuring Git identity.
4. Use QEMU VNC bound to 127.0.0.1 plus serial logs as the default display/evidence path; treat
   native WSLg as optional.
5. Keep myOS frozen as a reference project; do not mix its kernel code into AURORA.

---

## 6. Risk assessment

| Risk | Severity | Mitigation |
|---|---|---|
| No KVM for user, slow TCG builds/boots | Medium | Add user to `kvm`; use `-m 3072 -smp 2`; keep ISO minimal |
| WSLg copy-mode hides the VM window | Medium | Use QEMU VNC on 127.0.0.1 and `screendump`; no external tools required |
| `live-build` on Ubuntu 26.04 is old (3.0~a57) | Medium | Test early; fallback is debootstrap + xorriso + GRUB manually |
| Only 5.7 GiB RAM in WSL | Medium | Limit guest to 3 GiB; serialize builds; monitor memory |
| apt download blocked by User-Agent filtering (past incident) | Low | `/etc/apt/apt.conf.d/99local-useragent` fix is in place; verify on first install |
| Large ISO/chroot disk usage | Low | 953 GiB free; keep artifacts under repo `artifacts/`; clean caches |
| Scope creep (AI, custom kernel) | High | Defer to Milestone 6; each feature needs its own plan and evidence |
| Data loss to host disks | Low | No disk writes outside QEMU images; follow SECURITY.md |

---

## 7. Milestone 0 acceptance

- Actual project root and state: identified and documented.
- Environment, dependencies, and virtualization: verified by command output.
- Existing desktop and kernel: verified as a bare-metal project, not a Linux OS.
- Risks and missing dependencies: documented.
- Prioritized plan: see `ROADMAP.md`.

**Milestone 0: PASS.**

Next action: Milestone 1, Step 1 - install the ISO toolchain and apply the KVM group change (after
the user authorizes the system change), then scaffold a minimal live-build configuration.

---

## 8. Update 2026-10-31 - environment changes after Milestone 1

- ISO toolchain installed 2026-10-28 with authorization: `live-build 3.0~a57-1ubuntu54`,
  `debootstrap 1.0.142ubuntu2`, `xorriso`, `grub-pc-bin`/`grub-efi-amd64-bin` (GRUB 2.14),
  `mtools`, `dosfstools`, `cpio`. See `BUILD_AND_RUN.md` section 2.
- KVM group membership was **not** changed; AURORA boot tests use QEMU with `-accel tcg`.
  `/dev/kvm` is still `root:kvm 0660`, so the audit finding A-09 remains FAIL.
- Milestone 1 result: `artifacts/aurora-os-0.1.0-dev-amd64.iso` (504,125,440 bytes, SHA256
  `6d078451d07659ee3023cbd78601e29e8042aedd10f0e15637e64171baefba02`) boots twice in QEMU to a
  serial shell with a clean poweroff. Details and evidence paths are in `TESTING.md`.
- The audit's risk item "live-build on 26.04" is now mitigated by GRUB2-only configuration plus two
  GRUB 2.14 workarounds; the syslinux path is confirmed unusable.
