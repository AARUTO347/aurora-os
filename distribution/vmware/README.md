# VMware bundle

The image is a live ISO. VMware runs it from the virtual CD-ROM; nothing is
written to a virtual hard disk.

1. Install VMware Workstation or Player from Broadcom (an account is required).
2. Copy `aurora-os.vmx` next to the ISO, or edit `ide1:0.fileName` to point at
   the ISO path.
3. Create a `share/` directory beside the VMX if you want the read-only shared
   folder used by `sharedFolder0.hostPath`.
4. Open the VMX. Firmware is BIOS (the image has no UEFI boot record), 4 GB
   RAM, 2 vCPU, IDE CD-ROM, NAT networking.
5. Log in with user `ubuntu`, password `aurora`.

The VMX is intentionally conservative: BIOS firmware, no virtual disk, no
PCI passthrough, and NAT networking only.
