# Installing SnapshOT offline with LUKS

1. Write the ISO to USB: `dd if=snapshot-*.iso of=/dev/sdX bs=4M conv=fsync` (or Ventoy).
2. Boot the USB; the live session shows an **Install SnapshOT** icon.
3. Calamares runs the offline sequence: it copies the live squashfs (`unpackfs`),
   so no network is used. Choose **erase disk with encryption** to get LUKS2.
4. Set the passphrase, create the user, finish, reboot, unlock.

Module configuration lives in `modules/` next to `settings.conf`:

- `users.conf` — supplementary groups (`sudo`, `plugdev`, `dialout`, `kvm`, ...),
  `sudoersGroup: sudo`, root locked. Without it Calamares falls back to
  lp/video/network/storage/wheel/audio and the user has no sudo.
- `mount.conf` — binds `/dev`, `/proc`, `/sys`, `/run` and `efivarfs` into the
  target so `grub-install` and `update-initramfs` work in the chroot.
- `fstab.conf` — `keyscript=/bin/cat` in crypttab so the initramfs unlocks the
  LUKS root with `/crypto_keyfile.bin` instead of asking for the passphrase a
  second time.
- `welcome.conf` — storage, RAM and root checks; no internet check.
- `partition.conf`, `unpackfs.conf`, `bootloader.conf`, `machineid.conf`,
  `finished.conf` — LUKS2 erase layout, squashfs source, GRUB, machine-id,
  reboot prompt.

Administration on the installed system goes through `sudo` with the user's
password; root stays locked. `config/hooks/normal/0500-snapshot-sudo.hook.chroot`
writes `/etc/sudoers.d/snapshot-operator` so a password is remembered for 60
minutes across all terminals.

The installer sequence and LUKS settings live in
`packages/calamares-settings-snapshot/rootfs/etc/calamares/`. Debian's `calamares`
package ships no module configuration and this package replaces
`calamares-settings-debian`, so every module that needs settings must have its
`.conf` under `modules/` here. A module with no file runs on upstream defaults;
`displaymanager` is one that refuses to run without one. Verify with the QEMU test
in `docs/build.md` using a VM that has no NIC attached.
