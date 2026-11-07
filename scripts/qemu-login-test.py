#!/usr/bin/env python3
"""Boot the AURORA ISO headless and verify greeter login, logout, switch-user.

Slow TCG boots are handled by polling for readiness instead of fixed sleeps.
Commands are acknowledged by a marker printed on its own line, because the
serial shell echoes the command text (including the marker) back.
Evidence: PPM/PNG screenshots, serial log, and a readable test log.
"""
import os
import re
import select
import socket
import struct
import subprocess
import sys
import threading
import time
import zlib

ISO = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
MON = os.path.join(OUT, "mon.sock")
SER = os.path.join(OUT, "ser.sock")
for p in (MON, SER):
    try:
        os.unlink(p)
    except FileNotFoundError:
        pass

qemu = subprocess.Popen([
    "qemu-system-x86_64",
    "-machine", "q35", "-accel", "tcg", "-m", "3072", "-smp", "4",
    "-cdrom", ISO, "-boot", "d", "-vga", "std", "-display", "none",
    "-nic", "none",
    "-monitor", f"unix:{MON},server=on,wait=off",
    "-serial", f"unix:{SER},server=on,wait=off",
    "-no-reboot",
])

time.sleep(3)
mon = socket.socket(socket.AF_UNIX)
mon.connect(MON)
mon.settimeout(0.2)

ser = socket.socket(socket.AF_UNIX)
ser.connect(SER)
ser.settimeout(0.2)
serial_buf = bytearray()
stop = threading.Event()


def serial_reader():
    while not stop.is_set():
        try:
            r, _, _ = select.select([ser], [], [], 0.2)
            if r:
                data = ser.recv(65536)
                if not data:
                    return
                serial_buf.extend(data)
        except OSError:
            return


threading.Thread(target=serial_reader, daemon=True).start()


def serial_writer():
    while not stop.is_set():
        try:
            with open(os.path.join(OUT, "serial.log"), "w", errors="replace") as f:
                f.write(serial_buf.decode(errors="replace"))
        except OSError:
            pass
        stop.wait(20)


threading.Thread(target=serial_writer, daemon=True).start()


def mon_cmd(cmd, wait=0.6):
    mon.sendall((cmd + "\n").encode())
    time.sleep(wait)
    try:
        return mon.recv(65536).decode(errors="replace")
    except OSError:
        return ""


def ppm_to_png(ppm, png):
    with open(ppm, "rb") as f:
        if f.readline().strip() != b"P6":
            return False
        line = f.readline()
        while line.startswith(b"#"):
            line = f.readline()
        w, h = map(int, line.split())
        f.readline()
        data = f.read()
    raw = b"".join(b"\x00" + data[y * w * 3:(y + 1) * w * 3] for y in range(h))

    def chunk(tag, body):
        return (struct.pack(">I", len(body)) + tag + body +
                struct.pack(">I", zlib.crc32(tag + body) & 0xffffffff))

    out = b"\x89PNG\r\n\x1a\n"
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(raw, 6))
    out += chunk(b"IEND", b"")
    with open(png, "wb") as f:
        f.write(out)
    return True


def ppm_lit(path):
    """Count sampled bytes brighter than the black root window.

    A blank X root window with a cursor has almost none; a greeter or desktop
    has thousands. Used to wait for the compositor instead of guessing.
    """
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            if f.tell() < 1024:
                return 0
            f.seek(64)
            data = f.read()
    except OSError:
        return 0
    return sum(1 for b in data[::301] if b > 40)


def shot(name):
    path = os.path.join(OUT, name + ".ppm")
    mon_cmd(f"screendump {path}", 1.5)
    if not os.path.exists(path) or os.path.getsize(path) < 1024:
        return None
    ppm_to_png(path, os.path.join(OUT, name + ".png"))
    return path


def shot_when_drawn(name, timeout=120):
    """Screendump until the screen shows real content, then keep it."""
    end = time.time() + timeout
    attempt = 0
    while time.time() < end:
        attempt += 1
        path = shot(name)
        lit = ppm_lit(path) if path else 0
        log(f"{name}: attempt {attempt} lit_samples={lit}")
        if lit >= 20:
            return path
        time.sleep(10)
    return shot(name)


def serial_text():
    return serial_buf.decode(errors="replace")


def wait_serial(needle, timeout):
    end = time.time() + timeout
    while time.time() < end:
        if needle in serial_text():
            return True
        time.sleep(1)
    return False


_ANSI = re.compile(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-9;?]*[A-Za-z]"
                   r"|\x1b\\|\x1b[()][A-Z0-9]")
_counter = 0


def _clean_lines(text):
    return [_ANSI.sub("", ln).replace("\r", "").strip()
            for ln in text.splitlines()]


def _marker_hits(lines, marker):
    return sum(1 for ln in lines if ln == marker)


def ser_cmd(cmd, timeout=30):
    """Run a command in the serial shell and return only its output lines.

    The shell integration prints OSC-3008 metadata without a trailing newline,
    so the first marker can be glued to the previous line. Wait for a clean
    marker line, then take everything after the echoed command up to it.
    """
    global _counter
    _counter += 1
    marker = f"__DONE{_counter}__"
    echo_needle = f"echo {marker};"
    start = len(serial_buf)
    ser.sendall((f"echo {marker}; " + cmd + f"; echo {marker}\n").encode())
    end = time.time() + timeout
    lines = []
    while time.time() < end:
        # Slice bytes, then decode: a str offset drifts once the log contains
        # multi-byte characters.
        lines = _clean_lines(bytes(serial_buf[start:]).decode(errors="replace"))
        if _marker_hits(lines, marker) >= 2 and any(echo_needle in ln for ln in lines):
            break
        time.sleep(0.5)
    starts = [i for i, ln in enumerate(lines) if echo_needle in ln]
    ends = [i for i, ln in enumerate(lines) if ln == marker]
    if starts and ends and ends[-1] > starts[-1]:
        body = [ln for ln in lines[starts[-1] + 1:ends[-1]] if ln != marker]
    else:
        body = [ln for ln in lines if ln != marker and echo_needle not in ln]
    return "\n".join(body)


def log(msg):
    print(msg, flush=True)
    with open(os.path.join(OUT, "test.log"), "a") as f:
        f.write(msg + "\n")


def type_password():
    # The greeter focuses the password field once it has drawn (see the
    # 01-greeter screenshot), so type directly and submit.
    for key in "aurora":
        mon_cmd(f"sendkey {key}", 0.25)
    mon_cmd("sendkey ret", 3.0)


def session_lines():
    out = ser_cmd("loginctl list-sessions --no-legend", 40)
    return [ln for ln in out.splitlines() if ln.strip()]


def greeter_sessions():
    return [ln for ln in session_lines() if "greeter" in ln]


def logged_in():
    return any(re.search(r"\s1000\s+ubuntu\s+seat0", ln) for ln in session_lines())


def wait_panel(timeout=300):
    end = time.time() + timeout
    while time.time() < end:
        out = ser_cmd("pgrep -x -c xfce4-panel", 40).split()
        if out and out[-1].isdigit() and int(out[-1]) >= 1:
            log("xfce4-panel running")
            return True
        time.sleep(10)
    log("xfce4-panel NOT running")
    return False


def greeter_alive():
    # comm is truncated to 15 chars, so match the full command line. pgrep is
    # cheap; loginctl can block for a minute while a session is starting.
    out = ser_cmd("pgrep -u lightdm -f -c lightdm-gtk-greeter", 30).split()
    return bool(out) and out[-1].isdigit() and int(out[-1]) >= 1


def wait_greeter(label, timeout=300, need_no_session=False):
    end = time.time() + timeout
    while time.time() < end:
        if greeter_alive():
            if not need_no_session:
                log(f"{label}: greeter ready")
                return True
            sessions = session_lines()
            session = any(re.search(r"\s1000\s+ubuntu\s", ln) for ln in sessions)
            if not session:
                log(f"{label}: greeter ready session_present=False")
                return True
        time.sleep(5)
    log(f"{label}: greeter NOT ready")
    return False


def login(label, timeout=300):
    log(f"== {label}: typing greeter password ==")
    ok = False
    for attempt in (1, 2):
        if attempt > 1:
            # The greeter may have kept focus on the user list.
            mon_cmd("sendkey tab", 0.5)
            mon_cmd("sendkey tab", 0.5)
        type_password()
        end = time.time() + timeout
        while time.time() < end:
            if logged_in():
                ok = True
                break
            time.sleep(5)
        log(f"{label}: login attempt {attempt} detected={ok}")
        if ok:
            break
        time.sleep(5)
    if ok:
        wait_panel()
        # The panel process starts before its window is mapped; under TCG the
        # panel and dock can take minutes to finish drawing.
        time.sleep(120)
        log(str(shot_when_drawn(label + "-desktop", 240)))
    return ok


def as_ubuntu(command, timeout=35, background=False):
    # The session bus address is what xfce4-session-logout needs; without it
    # the request dies with "Could not connect: Permission denied".
    script = (
        "pid=$(pgrep -u ubuntu -x -n xfce4-session); "
        "if [ -z \"$pid\" ]; then echo NO_SESSION; else "
        "disp=$(tr '\\0' '\\n' < /proc/$pid/environ | sed -n 's/^DISPLAY=//p'); "
        "auth=$(tr '\\0' '\\n' < /proc/$pid/environ | sed -n 's/^XAUTHORITY=//p'); "
        "bus=$(tr '\\0' '\\n' < /proc/$pid/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p'); "
        "seat=$(tr '\\0' '\\n' < /proc/$pid/environ | sed -n 's/^XDG_SEAT_PATH=//p'); "
        "spath=$(tr '\\0' '\\n' < /proc/$pid/environ | sed -n 's/^XDG_SESSION_PATH=//p'); "
        "{ runuser -u ubuntu -- env DISPLAY=$disp XAUTHORITY=$auth "
        "DBUS_SESSION_BUS_ADDRESS=$bus XDG_SEAT_PATH=$seat XDG_SESSION_PATH=$spath "
        "XDG_RUNTIME_DIR=/run/user/1000 HOME=/home/ubuntu " + command +
        (" & }" if background else " ; }") + "; fi"
    )
    return ser_cmd(script, timeout)


def launch_browser(label="07-browser"):
    log("== browser ==")
    log(as_ubuntu("epiphany --version 2>&1"))
    as_ubuntu("setsid /usr/local/bin/aurora-browser about:blank >/home/ubuntu/aurora-browser.log 2>&1", 25, background=True)
    end = time.time() + 300
    running = False
    while time.time() < end:
        out = ser_cmd("pgrep -u ubuntu -f -c falkon", 30).split()
        if out and out[-1].isdigit() and int(out[-1]) >= 1:
            running = True
            break
        time.sleep(10)
    log(f"{label}: browser running={running}")
    log(as_ubuntu("tail -n 20 /home/ubuntu/aurora-browser.log 2>&1", 30))
    time.sleep(120)
    mon_cmd("sendkey alt-tab", 1.0)
    time.sleep(15)
    log(str(shot_when_drawn(label, 180)))
    return running


def logout(label):
    as_ubuntu("/usr/local/bin/aurora-session-action logout")
    end = time.time() + 240
    gone = False
    while time.time() < end:
        if not logged_in():
            gone = True
            break
        time.sleep(5)
    log(f"{label}: ubuntu session gone={gone}")
    ok = wait_greeter(label, 600, need_no_session=True)
    log(str(shot_when_drawn(label, 180)))
    return ok


def switch_user(label):
    before = len(greeter_sessions())
    out = as_ubuntu("/usr/local/bin/aurora-session-action switch")
    log(out)
    end = time.time() + 600
    ok = False
    while time.time() < end:
        if len(greeter_sessions()) > before and logged_in():
            ok = True
            break
        time.sleep(8)
    log(f"{label}: new greeter session={ok} (before={before})")
    log(str(shot_when_drawn(label, 180)))
    return ok


log("booting")
ready = wait_serial("AURORA_M1_SHELL_OK", 1200)
log(f"serial shell ready: {ready}")
if not ready:
    wait_serial("aurora login:", 60)

log("== waiting for LightDM ==")
active = False
end = time.time() + 1500
while time.time() < end:
    state = ser_cmd("systemctl is-active lightdm", 30)
    if "active" in [ln.strip() for ln in state.splitlines()]:
        active = True
        break
    time.sleep(10)
log(f"lightdm active: {active}")

log("== lightdm diagnostics ==")
log(ser_cmd("journalctl -b -u lightdm --no-pager | tail -n 20", 60))
log("== autologin keys in lightdm config ==")
log(ser_cmd("grep -rn 'autologin' /etc/lightdm/lightdm.conf "
            "/etc/lightdm/lightdm.conf.d/*.conf; echo ----; "
            "grep -i 'AURORA_IDENTITY_READY' /var/log/syslog 2>/dev/null | tail -n 2", 40))

greeter_ok = wait_greeter("01-greeter", 1200, need_no_session=True)
log("== VT state ==")
log(ser_cmd("fgconsole; ps -eo args= | grep '^/usr/lib/xorg/Xorg' | head -n1; "
            "systemctl is-active aurora-vt", 25))

log("== boot timing ==")
log(ser_cmd("systemd-analyze; echo --; systemd-analyze blame | head -n 12", 60))
log("== pre-login evidence ==")
log(ser_cmd("systemctl is-active lightdm; systemctl is-enabled lightdm; "
            "loginctl list-sessions --no-legend; getent passwd ubuntu", 25))
log(ser_cmd("cat /etc/aurora-release; hostname; "
            "systemctl is-active aurora-identity", 25))
log(str(shot_when_drawn("01-greeter", 600)))
log(f"greeter ready={greeter_ok}")

first = login("02-login")
if first:
    log("== session identity ==")
    log(ser_cmd("getent passwd ubuntu; hostname; "
                "loginctl list-sessions --no-legend", 25))
    log("== DPMS ==")
    log(as_ubuntu("xset q | grep -i -A1 'DPMS\\|screen saver'"))
    browser_ok = launch_browser("03-browser")
    log(f"browser ok={browser_ok}")
    log("== syslog session actions ==")
    log(ser_cmd("journalctl -t aurora -b --no-pager | tail -n 8", 40))
    if os.environ.get("AURORA_BROWSER_ONLY"):
        log("browser-only mode: stopping after the browser check")
    else:
        log("== logout ==")
        logout("04-after-logout")

        log("== second login after logout ==")
        second = login("05-login-again")
        if second:
            log("== switch user ==")
            switch_user("06-after-switch")
            log("== syslog session actions ==")
            log(ser_cmd("journalctl -t aurora -b --no-pager | tail -n 6", 40))
            log("== cleanup: log out the background session ==")
            logout("07-cleanup")
else:
    log("== stopping after failed first login ==")

log("== stopping qemu ==")
with open(os.path.join(OUT, "serial.log"), "w", errors="replace") as f:
    f.write(serial_text())
mon_cmd("quit", 1.0)
try:
    qemu.wait(timeout=15)
except subprocess.TimeoutExpired:
    qemu.kill()
stop.set()
log("done")
