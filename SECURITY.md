# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 0.5.x (development) | Yes |
| 0.4.x and earlier | No |

AURORA OS is a live image under active development. It is **not yet a
production operating system**. No production image has been built or
boot-tested; production release is BLOCKED (see `docs/KNOWN_ISSUES.md`
KI-034 and KI-035).

## Reporting a vulnerability

Do **not** open a public issue for a security problem.

Use GitHub's private vulnerability reporting on the repository
(`Security` → `Advisories` → `Report a vulnerability`) or contact the
maintainer through the GitHub profile `AARUTO347`.

Include:

- the AURORA version and ISO checksum,
- the environment (QEMU/VMware/model of machine),
- reproduction steps,
- impact and any suggested fix.

## Scope notes

- The published images are **development/test builds**, not production
  releases. For the convenience of a disposable live session they ship a
  public local account `ubuntu` with the documented password `aurora`, and
  they inherit Ubuntu casper live provisioning: empty-password authentication
  (LightDM `allow-empty-passwords=true`, PAM `nullok`), passwordless sudo and
  PolicyKit for the live user, and initramfs autologin injection. **These are
  unsafe for production or physical use.** Earlier wording that called the
  shared password "not a vulnerability" was incorrect and is withdrawn.
- A production image must not carry any of the above. `scripts/release-gate.sh`
  is a **fail-closed** gate: it inspects both the squashfs and the initramfs and
  refuses to certify an image that contains shared-password provisioning,
  empty-password auth, passwordless privilege escalation, test-only root serial
  autologin/evidence, or casper live-session injection. Any inspection error is
  treated as FAIL, never as "absent". `scripts/build-release-iso.sh` runs the
  gate **before** an artifact reaches the publish directory.
- The gate currently refuses every existing AURORA image, which is the correct
  result: production authentication onboarding does not exist yet (KI-035).
  Removing the credentials from the README alone would not make an image safe;
  the gate enforces the actual boundary.
- The development image may contain test-only services. They are tracked in
  `docs/KNOWN_ISSUES.md`; report any that are reachable from the network.
- Vulnerabilities in Ubuntu packages should be reported to Ubuntu/upstream,
  but a note to this project is welcome if the image needs a mitigation.
