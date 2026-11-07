# Screenshots

All images are QEMU `screendump` captures from the 0.4.0-dev ISO
(SHA256 `f80a65e016fc630acdce8dc6ca5d99129a3518839428b0a20d043a45712db38f`),
1280x800, `-vga std`, TCG.

| File | What it shows | Run |
|---|---|---|
| `greeter.png` | Branded LightDM login page: aurora wallpaper, hostname `aurora`, date, `AARUTO` account, password field, **Log In** | `/home/aaruto/aurora-test/p7` |
| `desktop.png` | XFCE session after login: panel with `AARUTO`, desktop icons (Home, File System, AURORA Switch User, AURORA Log Out, AURORA Lock Screen, AURORA Browser), dock | `/home/aaruto/aurora-test/p7` |
| `browser.png` | GNOME Web running: the panel lists the browser window as `Blank page` with the Epiphany icon; WebKit page painting lags under TCG (KI-032) | `/home/aaruto/aurora-test/p7` |
| `after-logout.png` | Greeter after logging out through `aurora-session-action`; the `ubuntu` session is gone | `/home/aaruto/aurora-test/p4` |
| `switch-user.png` | Greeter after **Switch User** through LightDM `dm-tool`; the background session keeps running | `/home/aaruto/aurora-test/p4` |

The serial logs and PPM originals stay outside Git under
`/home/aaruto/aurora-test/<run>/` as required by `docs/TESTING.md`.
