# Screenshots

All images are QEMU `screendump` captures from the 0.3.0-dev ISO
(SHA256 `ebc54345bbf131c0d63e8c84e2821ae17347f7b18479f68ea103c9aee135af90`),
1280x800, `-vga std`, TCG.

| File | What it shows | Run |
|---|---|---|
| `greeter.png` | Branded LightDM login page: aurora wallpaper, hostname `aurora`, date, `AARUTO` account, password field, **Log In** | `/home/aaruto/aurora-test/h4` |
| `desktop.png` | XFCE session after login: panel with `AARUTO`, desktop icons (Home, File System, AURORA Switch User, AURORA Log Out, AURORA Lock Screen), dock | `/home/aaruto/aurora-test/h1` |
| `after-logout.png` | Greeter after logging out; the `ubuntu` session is gone | `/home/aaruto/aurora-test/h4` |
| `switch-user.png` | Greeter in unlock mode after **Switch User**; the background session keeps running | `/home/aaruto/aurora-test/h4` |

The serial logs, `result.json`-style evidence and PPM originals stay outside Git
under `/home/aaruto/aurora-test/<run>/` as required by `docs/TESTING.md`.
