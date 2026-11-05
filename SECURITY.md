# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 0.3.x (development) | Yes |
| 0.2.x | No |
| 0.1.x | No |

AURORA OS is a live image under active development. It is not yet a
production operating system.

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

- The live image uses the public local account `ubuntu` with the documented
  password `aurora`. That is intentional for a live session and is not a
  vulnerability.
- The development image may contain test-only services. They are tracked in
  `docs/KNOWN_ISSUES.md`; report any that are reachable from the network.
- Vulnerabilities in Ubuntu packages should be reported to Ubuntu/upstream,
  but a note to this project is welcome if the image needs a mitigation.
