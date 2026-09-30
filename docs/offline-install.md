# Installing SnapshOT offline with LUKS

1. Write the ISO to USB: `dd if=snapshot-*.iso of=/dev/sdX bs=4M conv=fsync` (or Ventoy).
2. Boot the USB; the live session shows an **Install SnapshOT** icon.
3. Calamares runs the offline sequence: it copies the live squashfs (`unpackfs`),
   so no network is used. Choose **erase disk with encryption** to get LUKS2.
4. Set the passphrase, create the user, finish, reboot, unlock.

The installer sequence and LUKS settings live in
`packages/calamares-settings-snapshot/rootfs/etc/calamares/`. Verify with the QEMU
test in `docs/build.md` using a VM that has no NIC attached.
