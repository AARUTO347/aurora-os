#!/bin/sh
# Boot an AURORA ISO in a disposable QEMU VM. VNC stays on loopback.
# Usage: scripts/run-qemu.sh PATH_TO_ISO
set -eu

ISO=${1:?usage: run-qemu.sh PATH_TO_ISO}
MEM=${AURORA_MEM:-2048}
MON=/tmp/aurora-monitor.sock
SERIAL=/tmp/aurora-serial.log

[ -f "$ISO" ] || { echo "run-qemu.sh: no such file: $ISO" >&2; exit 1; }
rm -f "$MON"

exec qemu-system-x86_64 \
	-machine q35 \
	-accel tcg \
	-m "$MEM" \
	-smp 2 \
	-cdrom "$ISO" \
	-boot d \
	-vga std \
	-display "${AURORA_DISPLAY:-gtk,zoom-to-fit=on}" \
	-monitor "unix:$MON,server,nowait" \
	-vnc 127.0.0.1:1 \
	-serial "file:$SERIAL" \
	-no-reboot
