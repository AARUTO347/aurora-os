# Contributing to AURORA OS

AURORA OS is a live Linux desktop image built with live-build on Ubuntu
26.04 LTS. Contributions that keep the image reproducible and documented are
welcome.

## Before you start

- Read `docs/ARCHITECTURE.md`, `docs/BUILD_AND_RUN.md`, and
  `docs/KNOWN_ISSUES.md`.
- Check open issues for the area you want to change.
- Do not include secrets, tokens, private keys, or personal data.
- Do not propose changes that repartition or modify a host system as part of
  the build or test flow. All testing happens in disposable virtual machines.

## Making a change

1. Fork the repository and create a topic branch.
2. Keep the change focused: one logical change per branch.
3. Put distribution files under `build/live-build/config/includes.chroot/`.
   Build-time actions belong in `build/live-build/config/hooks/`.
4. Keep shell code POSIX `sh` where the existing scripts use it, use tabs for
   indentation, and avoid new runtime dependencies unless they are added to
   `package-lists/aurora.list.chroot`.
5. Update the relevant docs and `CHANGELOG.md`.
6. Run `make check` and, when changing the image, build and boot it in QEMU.

## Testing

```sh
make check                 # syntax and static checks, no root required
sudo make iso              # build the ISO
make verify                # inspect the ISO without booting
make boot                  # boot the ISO in QEMU (TCG)
```

Record what you actually ran and saw. Reports use `PASS`, `FAIL`, `BLOCKED`,
or `NOT TESTED`; never claim a build or boot that was not observed.

## Pull requests

- Describe the problem, the change, and the verification performed.
- Link the issue being fixed, if any.
- Include a screenshot or serial log for user-visible changes.
- Keep the credit list unchanged unless the project owners say otherwise.
