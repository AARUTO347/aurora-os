#!/usr/bin/env python3
"""Boot the AURORA ISO once, wait for the greeter, and save a QEMU snapshot.

The snapshot lives on the attached qcow2 disk so later launches resume the
login page in seconds with `-loadvm ready`.
"""
import os
import select
import socket
import subprocess
import sys
import time

ISO, DISK = sys.argv[1], sys.argv[2]
MON = "/tmp/aurora-snap.mon"
SER = "/tmp/aurora-snap.ser"
for p in (MON, SER):
    try:
        os.unlink(p)
    except FileNotFoundError:
        pass

qemu = subprocess.Popen([
    "qemu-system-x86_64", "-machine", "q35", "-accel", "tcg",
    "-m", "3072", "-smp", "4", "-cdrom", ISO, "-boot", "d",
    "-vga", "std", "-display", "none", "-nic", "none",
    "-monitor", f"unix:{MON},server=on,wait=off",
    "-serial", f"unix:{SER},server=on,wait=off",
    "-drive", f"file={DISK},if=virtio,format=qcow2",
    "-no-reboot",
])
time.sleep(3)

mon = socket.socket(socket.AF_UNIX)
mon.connect(MON)
mon.settimeout(0.2)
ser = socket.socket(socket.AF_UNIX)
ser.connect(SER)
ser.settimeout(0.2)
buf = bytearray()
deadline = time.time() + 2400
ready = False
last_poll = 0

while time.time() < deadline:
    r, _, _ = select.select([ser], [], [], 1.0)
    if r:
        data = ser.recv(65536)
        if not data:
            break
        buf.extend(data)
    text = buf.decode(errors="replace")
    if "AURORA_M1_SHELL_OK" in text and time.time() - last_poll > 20:
        last_poll = time.time()
        ser.sendall(b"echo __P__; systemctl is-active lightdm; "
                    b"pgrep -u lightdm -f -c lightdm-gtk-greeter; echo __P__\n")
        time.sleep(2)
        r, _, _ = select.select([ser], [], [], 2.0)
        if r:
            buf.extend(ser.recv(65536))
        text = buf.decode(errors="replace")
        tail = text.rsplit("__P__", 2)[-2] if text.count("__P__") >= 2 else ""
        lines = [ln.strip() for ln in tail.replace("\r", "").splitlines()]
        if "active" in lines:
            nums = [ln for ln in lines if ln.isdigit()]
            if nums and int(nums[-1]) >= 1:
                ready = True
                break

if not ready:
    print("SNAPSHOT_FAILED: greeter not reached", flush=True)
    qemu.kill()
    sys.exit(1)

print("greeter ready; saving snapshot", flush=True)
mon.sendall(b"savevm ready\n")
time.sleep(150)
try:
    mon.sendall(b"info snapshots\n")
    time.sleep(2)
    print(mon.recv(65536).decode(errors="replace"), flush=True)
except OSError:
    pass
mon.sendall(b"quit\n")
time.sleep(2)
qemu.wait(timeout=30)
print("SNAPSHOT_DONE", flush=True)
