#!/usr/bin/env python3
"""Boot an AURORA ISO in a disposable QEMU (TCG) and capture boot evidence.

Evidence written to /home/aaruto/aurora-build/evidence/<timestamp>/:
serial.log, qemu-stderr.log, monitor.sock, console.ppm, result.json.
Exit status is 0 only when the serial shell marker and command transcript were
actually observed, so this script never reports a boot it did not see.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

MARK_ROOTFS = "AURORA_M1_ROOTFS_OK"
MARK_SHELL = "AURORA_M1_SHELL_OK"
MARK_CMD_BEGIN = "AURORA_CMD_BEGIN"
MARK_CMD_END = "AURORA_CMD_END"


def iso_sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def monitor_command(sock_path, command, wait=1.5):
    deadline = time.time() + 10
    last = None
    while time.time() < deadline:
        try:
            conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            conn.connect(str(sock_path))
            conn.sendall((command + "\n").encode())
            time.sleep(wait)
            conn.close()
            return True
        except OSError as exc:
            last = exc
            time.sleep(0.2)
    print(f"monitor command failed ({command}): {last}", file=sys.stderr)
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("iso")
    ap.add_argument("--timeout", type=int, default=1200, help="seconds to wait for the shell marker")
    ap.add_argument("--ram", default="2048")
    ap.add_argument("--cpus", type=int, default=2)
    ap.add_argument("--vnc", default="127.0.0.1:1")
    ap.add_argument("--evidence", default=None)
    args = ap.parse_args()

    iso = Path(args.iso).resolve()
    if not iso.is_file():
        sys.exit(f"ISO not found: {iso}")

    qemu = shutil.which("qemu-system-x86_64")
    if not qemu:
        sys.exit("qemu-system-x86_64 not found in PATH")

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    ev = Path(args.evidence) if args.evidence else Path("/home/aaruto/aurora-build/evidence") / stamp
    ev.mkdir(parents=True, exist_ok=True)
    serial_log = ev / "serial.log"
    stderr_log = ev / "qemu-stderr.log"
    mon_sock = ev / "monitor.sock"
    shot = ev / "console.ppm"
    result_path = ev / "result.json"

    if mon_sock.exists():
        mon_sock.unlink()

    cmd = [
        qemu,
        "-name", "aurora-m1",
        "-machine", "pc",
        "-accel", "tcg",
        "-m", args.ram,
        "-smp", str(args.cpus),
        "-cdrom", str(iso),
        "-boot", "d",
        "-display", f"vnc={args.vnc}",
        "-monitor", f"unix:{mon_sock},server=on,wait=off",
        "-serial", "stdio",
        "-no-reboot",
    ]

    started = datetime.now(timezone.utc)
    result = {
        "iso": str(iso),
        "iso_size_bytes": iso.stat().st_size,
        "iso_sha256": iso_sha256(iso),
        "qemu": qemu,
        "qemu_version": subprocess.run([qemu, "--version"], capture_output=True, text=True).stdout.splitlines()[0],
        "accelerator": "tcg",
        "command": cmd,
        "started_utc": started.isoformat(timespec="seconds"),
        "serial_log": str(serial_log),
        "stderr_log": str(stderr_log),
        "screendump": str(shot),
    }

    stdout_fh = open(serial_log, "wb")
    stderr_fh = open(stderr_log, "wb")
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr_fh)
    buf = bytearray()
    lock = threading.Lock()

    def reader():
        while True:
            chunk = proc.stdout.read1(65536)
            if not chunk:
                break
            with lock:
                buf.extend(chunk)
            stdout_fh.write(chunk)
            stdout_fh.flush()

    threading.Thread(target=reader, daemon=True).start()

    def transcript():
        with lock:
            return bytes(buf).decode("utf-8", "replace")

    def wait_for(marker, deadline):
        while time.time() < deadline:
            if marker in transcript():
                return True
            if proc.poll() is not None:
                return False
            time.sleep(1.0)
        return False

    def say(line):
        proc.stdin.write((line + "\n").encode())
        proc.stdin.flush()

    deadline = time.time() + args.timeout
    shell_ok = wait_for(MARK_SHELL, deadline)
    result["rootfs_marker"] = MARK_ROOTFS in transcript()
    result["shell_marker"] = shell_ok

    cmd_ok = False
    if shell_ok:
        time.sleep(1.0)
        say("echo " + MARK_CMD_BEGIN)
        time.sleep(0.5)
        for line in ("uname -a", "cat /etc/os-release", "id", "ls -l /", "df -h /", "cat /etc/aurora-release"):
            say(line)
            time.sleep(0.4)
        say("echo " + MARK_CMD_END)
        cmd_ok = wait_for(MARK_CMD_END, time.time() + 180)
        result["command_transcript"] = cmd_ok

    if not proc.poll() is not None:
        monitor_command(mon_sock, f"screendump {shot}")
        if shell_ok:
            say("sync; poweroff -f")

    try:
        exit_code = proc.wait(timeout=180)
    except subprocess.TimeoutExpired:
        proc.kill()
        exit_code = proc.wait()
        result["terminated"] = "timeout-kill"

    time.sleep(0.5)
    stdout_fh.close()
    stderr_fh.close()

    text = transcript()
    result["qemu_exit_code"] = exit_code
    kernel = re.search(r"Linux version (\S+)", text)
    result["kernel_version"] = kernel.group(1) if kernel else None
    result["base_distribution"] = "Ubuntu 26.04 LTS (resolute)" if "Ubuntu 26.04" in text else None
    result["finished_utc"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    result["verified"] = bool(shell_ok and cmd_ok)
    result_path.write_text(json.dumps(result, indent=2) + "\n")

    print(f"evidence={ev}")
    print(f"rootfs_marker={result['rootfs_marker']} shell_marker={shell_ok} command_transcript={cmd_ok}")
    print(f"kernel={result['kernel_version']} qemu_exit={exit_code} verified={result['verified']}")
    sys.exit(0 if result["verified"] else 1)


if __name__ == "__main__":
    main()
