#!/bin/sh
# Fast AURORA launcher.
#
# The first run boots the ISO once and saves a QEMU snapshot to a qcow2 disk;
# every later run resumes the saved login page in seconds with -loadvm.
set -u

ISO=${AURORA_ISO:-/home/aaruto/aurora-build/artifacts/aurora-os-0.4.0-dev-amd64.iso}
DISK=${AURORA_STATE:-/mnt/d/AURORA/state.qcow2}
SNAP=${AURORA_SNAPSHOT:-ready}

if [ ! -f "$ISO" ]; then
	echo "AURORA ISO not found: $ISO" >&2
	exit 1
fi

if [ ! -f "$DISK" ]; then
	mkdir -p "$(dirname "$DISK")"
	qemu-img create -f qcow2 "$DISK" 64M >/dev/null
	python3 "$(dirname "$0")/aurora-snapshot.py" "$ISO" "$DISK"
	exit $?
fi

qemu-system-x86_64 -machine q35 -accel tcg -m 3072 -smp 4 \
	-cdrom "$ISO" -boot d -vga std -display "gtk,zoom-to-fit=on" -nic none \
	-drive "file=$DISK,if=virtio,format=qcow2" \
	-loadvm "$SNAP" -monitor unix:/tmp/aurora-vm.mon,server=on,wait=off
rc=$?

if [ "$rc" -ne 0 ]; then
	# Snapshot missing or unusable: rebuild it from a clean boot.
	echo "Snapshot '$SNAP' missing; rebuilding (one long boot)..." >&2
	rm -f "$DISK"
	qemu-img create -f qcow2 "$DISK" 64M >/dev/null
	exec python3 "$(dirname "$0")/aurora-snapshot.py" "$ISO" "$DISK"
fi
