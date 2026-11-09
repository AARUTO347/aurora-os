# AURORA OS - Security

This document defines the safety and security rules for a hobby operating-system project built on a
personal laptop. These rules override convenience.

---

## 1. Host protection (non-negotiable)

1. Never format, repartition, or erase any Windows disk or partition.
2. Never replace or modify the Windows bootloader or boot configuration.
3. Never install AURORA onto the physical laptop as the default workflow.
4. Never run destructive disk commands against the host.
5. Never delete or overwrite the existing myOS project; preserve it as a separate reference.
6. Do not disable Windows security, antivirus, Secure Boot, or other host protections.
7. Use a disposable QEMU virtual machine for all OS testing.
8. Ask for explicit authorization before any irreversible operation or host change.

## 2. WSL configuration changes

- Back up every system file before changing it; record the backup path in the change report.
- Applied on 2026-10-24: explicit mounts for C: and D: in `/etc/fstab`, `[automount] enabled=false`
  and `mountFsTab=true` in `/etc/wsl.conf`, plus the `/mnt/shared_memory` tmpfs. Backups:
  `/root/fstab.backup-20261024`, `/root/fstab.backup-20261024-2`,
  `/root/wsl.conf.backup-20261024`, `/root/wsl.conf.backup-20261024-2`.
- Applied on 2026-11-08 with explicit authorization: `aaruto` added to the `kvm` group and WSL
  restarted (KI-003). Reversible with `sudo gpasswd -d aaruto kvm`.
- Do not change WSL defaults that affect other projects without documenting the effect.

## 3. Virtualization and display security

- QEMU VNC must bind to `127.0.0.1` only. Never use `0.0.0.0` for VNC.
- Do not expose VNC, SSH, or web consoles to the LAN or Internet without authentication and a
  documented tunnel.
- Do not download noVNC or other third-party display code without explicit approval. QEMU's internal
  VNC is sufficient and adds no external code.
- Do not attach host block devices to QEMU. Use qcow2 images under the repo.
- Use a disposable copy of the ISO and a fresh qcow2 disk per test when persistence is involved.
- The guest has no access to Windows drives unless explicitly shared; do not add host shares by
  default.

### 3.1 Milestone 1 test-image caveats

- The current image (`0.1.0-dev`) is a **test build**, not a release. It contains a test-only
  `agetty --autologin root` on `ttyS0` and evidence services, so anyone with access to the serial
  console gets a root shell without a password (KI-018).
- Run it only in a disposable QEMU VM. Never boot it on physical hardware, never attach host disks,
  and never add network access to the VM until autologin is removed.
- The image is BIOS-only (no UEFI) and a plain ISO (not USB-hybrid); this is a functional
  limitation, not a security control. Secure Boot was not touched on the host.

### 3.2 Production authentication gate (Finding 5)

The published development images are not production-safe. They ship a shared `ubuntu:aurora`
password, casper empty-password auth (LightDM `allow-empty-passwords=true`, PAM `nullok`),
passwordless sudo/PolicyKit for the live user, and initramfs autologin injection (`15autologin`,
`25adduser`, `44pk_allow_ubuntu`). The test profile also adds root serial autologin (KI-018).
The earlier claim in the root `SECURITY.md` that the shared password "is not a vulnerability"
was incorrect and has been withdrawn.

`scripts/release-gate.sh` is a **fail-closed** production gate. It inspects BOTH the squashfs and
the initramfs and refuses to certify an image containing any of:

- test-only root serial autologin / evidence service / profile hook;
- shared live-password provisioning (script or enabled service);
- LightDM `allow-empty-passwords=true` or PAM `nullok`;
- `NOPASSWD` sudo or the casper PolicyKit ubuntu bypass;
- casper initramfs injection scripts, or `autologin-user=` / `NOPASSWD` strings.

Exit codes: `0` PASS, `1` FAIL (unsafe element present), `2` FAIL (inspection error). Mount,
extraction, or missing-input errors are never treated as "absent". `scripts/build-release-iso.sh`
stages a release profile (test hooks and the shared-password service removed), builds, and runs
the gate BEFORE copying the artifact to the publish directory; any non-zero exit blocks
publication. `0400-gui.chroot` only enables the shared-password service when it is actually
staged, so the release profile never provisions a common password.

Verified 2026-11-09:

- Regression fixtures (`tests/test-auth-gate.sh`, run by `make check`): clean fixture PASS (0),
  unsafe fixture FAIL (1), missing rootfs FAIL (2), clean rootfs without initrd FAIL (2).
  4/4 assertions PASS.
- The gate run against the existing release remaster (`aurora-release-final.iso`) returns FAIL
  (exit 1): shared-password service present and enabled, `allow-empty-passwords=true`, PAM
  `nullok`, and casper `15autologin`/`25adduser`/`44pk_allow_ubuntu` plus `autologin-user=` /
  `NOPASSWD` in the initramfs. The previous two-filename gate would have passed this image.

Production release is **BLOCKED** (KI-034 build, KI-035 authentication onboarding). No production
image has been built or boot-tested. Removing the credentials from the README alone does not make
an image safe; the gate enforces the actual boundary. Secure first-boot onboarding must replace
casper live provisioning (and the initramfs must be rebuilt without breaking `modprobe overlay`)
before the gate can pass.

## 4. Build and supply chain

- Install packages only from the configured official Ubuntu archives unless a source is reviewed and
  approved.
- Do not execute `curl | bash` or unreviewed downloaded scripts.
- Pin and record package versions where practical; keep build logs.
- Run `sudo` only for the specific steps that need it (package installation, `lb build` if
  required); never run an entire interactive session as root.
- Review build hooks before running them; hooks execute inside a chroot with elevated privileges in
  the build environment.
- Do not commit generated ISOs, chroots, caches, VM disks, or logs.

## 5. Secrets and personal data

- Never commit API keys, passwords, tokens, private keys, or personal information.
- Keep AI provider credentials in a keyring or environment file outside Git; `.env` is ignored.
- Redact credentials, session tokens, usernames, and hostnames from exported diagnostics and logs.
- Do not transmit files or system information to an AI provider without explicit user approval.
- Review serial logs and screenshots before sharing; they can contain system identifiers.
- The documented `ubuntu:aurora` test credential is a public live-session convenience, not a secret;
  it must never appear in a production image (enforced by the gate in §3.2).

## 6. AI assistant rules (future milestone)

- The desktop and all core applications must work with no AI service configured.
- AI is opt-in; no background transmission by default.
- AI-generated shell commands are displayed for review and never executed automatically.
- Use least privilege; the assistant must not request root for normal queries.
- Clearly label when network access or an external provider is required.
- Do not embed provider keys in frontend files or logs.

## 7. Diagnostics and logging

- Diagnostics read real system sources and report unavailable data honestly.
- Do not invent temperatures, battery health, GPU capabilities, or network state.
- Exported reports must be redacted and reviewed before leaving the machine.
- Logs are kept under `/home/aaruto/aurora-build/` (`logs/`, `evidence/<run>/`) outside the Git
  repository, with timestamps.

## 8. Incident response

| Situation | Action |
|---|---|
| Broken WSL mounts or config | Restore the `/root/*.backup-20261024*` files, then `wsl --shutdown` and restart |
| Runaway QEMU | Kill only the QEMU process (`pkill -x qemu-system-x86_64`) and confirm with `pgrep -af '^qemu-system-x86_64'`; never use broad `pkill -f` patterns |
| Corrupted build output | Delete only the repo's generated chroot/artifacts, rebuild from a clean tree |
| Leaked secret | Rotate the secret, remove it from history if committed, review logs |
| Suspicious downloaded script | Do not run it; delete it; re-fetch from an official source if needed |
| Unsafe production artifact | `scripts/release-gate.sh` blocks publication; do not bypass it. Fix the image and re-gate |

## 9. Verification claims

A feature is reported as PASS only with executed-command evidence (serial log, screenshot, checksum,
or test output). Code inspection alone is not proof. If a required test is not run, report
NOT TESTED or BLOCKED. The production auth gate is verified by `make check` (regression fixtures)
and by running it against real images; a gate PASS is required before any production publication,
and no production image has passed it yet.
