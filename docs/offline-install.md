# Installing SnapshOT offline with LUKS

The installer (Calamares 3.3) copies the running live system to disk. It needs no
network at any point, so it works the same at an air-gapped site.

## 1. Boot the live system

- Write the ISO to a USB stick (`dd if=snapshot-amd64.hybrid.iso of=/dev/sdX bs=4M
  conv=fsync`, or Ventoy), or attach it to a VM with UEFI firmware. For a test of the
  offline path, give the VM no network adapter.
- The SnapshOT boot menu appears; the first entry starts the live system.
- The live session logs in automatically as user `snapshot`. The password `live` is
  only needed to unlock the screen; `sudo` and the installer do not ask for it.

## 2. Install

1. Double-click **Install SnapshOT** on the desktop. The icon exists only in the live
   session.
2. Welcome page: Calamares checks for at least 10 GiB of disk and 1 GiB of RAM. There
   is no internet check.
3. Location and keyboard.
4. Partitions: choose **Erase disk**, tick **Encrypt system** and enter the disk
   passphrase. The root filesystem defaults to ext4 (btrfs and xfs are offered). Swap
   is off by default; the only other choice is a swap file inside the encrypted root.
5. Users: name, login and password. The password must be at least six characters
   and must not be a dictionary word or contain the login name (libpwquality with
   the cracklib dictionary). This account administers the system through `sudo`;
   there is no root password.
6. Summary, then **Install**. When it finishes, reboot and remove the USB stick.

## 3. Disk layout

| Partition | Size | Filesystem | Encrypted |
|---|---|---|---|
| EFI system partition (UEFI only), `/boot/efi` | 300 MiB | FAT32 | no |
| `/boot` | 1 GiB | ext4 | no |
| `/` | rest of the disk | ext4, btrfs or xfs inside LUKS2 | yes (Argon2id) |
| `/swapfile` (only if chosen) | depends on RAM | file inside the encrypted root | yes |

`/boot` stays outside LUKS because Calamares formats LUKS2 with Argon2id, which
Debian's GRUB cannot unlock. It holds only the kernel, the initramfs and GRUB's
files, but it is neither encrypted nor tamper-protected. Swap is offered only as a
file inside the encrypted root: a swap partition would be a second LUKS volume, and
without a keyfile (there is none when `/boot` is unencrypted) the initramfs would ask
for the passphrase twice. There is no hibernation.

## 4. First boot

1. The themed GRUB menu appears without asking for a passphrase.
2. The Plymouth splash asks for the disk passphrase once; the initramfs unlocks the
   root volume.
3. LightDM shows the login screen; sign in with the account created during the install.

## 5. Administration

- The user is in group `sudo` (plus `plugdev`, `dialout`, `kvm`, `netdev`, `wireshark`,
  `audio`, `video`, `cdrom`, `floppy`, `dip`). Root stays locked.
- Group `wireshark` may run `dumpcap`, so Wireshark, tshark and termshark capture
  without `sudo`. `config/hooks/normal/0600-snapshot-wireshark.hook.chroot` answers
  wireshark-common's install-setuid question at build time: `dumpcap` is
  `root:wireshark 0754` with `cap_net_raw,cap_net_admin`. `tcpdump` still needs `sudo`.
  The live user gets the same groups (minus `sudo`, which live-config grants) from
  `config/includes.chroot/etc/live/config.conf.d/snapshot.conf`.
- `sudo` asks for the user's password. `config/hooks/normal/0500-snapshot-sudo.hook.chroot`
  writes `/etc/sudoers.d/snapshot-operator`, so the password is remembered for 60
  minutes and shared by every terminal.
- The live user's passwordless `sudo` and polkit rule are written by live-config at
  live boot, outside the squashfs, so the installed system never has them.

## 6. What the installer removes

The install starts as a byte copy of the live squashfs. Before it builds the final
initramfs, the `packages` module purges the live-session machinery from the target:
`live-boot`, `live-boot-initramfs-tools`, `live-config`, `live-config-systemd`,
`user-setup`, `calamares` and `calamares-settings-snapshot`, then autoremoves the
dependencies nothing else needs. The Install SnapshOT icon goes with
`calamares-settings-snapshot`: it is placed by that package's autostart entry, and
only when the system was booted live.

## Module configuration

The installer sequence lives in
`packages/calamares-settings-snapshot/rootfs/etc/calamares/settings.conf`, with one
file per module in `modules/`. Debian's `calamares` package ships no module
configuration, and this package replaces `calamares-settings-debian`, so a module with
no file here runs on upstream defaults; `displaymanager` refuses to run at all
without one.

| File | Sets |
|---|---|
| `welcome.conf` | storage, RAM and root checks; no internet check. Also publishes `requiredStorageGiB`, without which the partition page offers neither "replace" nor "alongside". |
| `partition.conf` | erase by default, LUKS2, ext4 default, swap off; the layout above (`partitionLayout` with a 1 GiB unencrypted `/boot`). |
| `users.conf` | the groups above, `sudoersGroup: sudo`, root locked. Without it Calamares falls back to lp/video/network/storage/wheel/audio and the user has no sudo. |
| `mount.conf` | binds `/dev`, `/dev/pts`, `/proc`, `/sys`, `/run`, `/run/udev` and `efivarfs` into the target so `grub-install`, `update-initramfs` and apt work in the chroot. |
| `unpackfs.conf` | copies `/run/live/medium/live/filesystem.squashfs` to the target. |
| `machineid.conf` | a fresh machine-id for systemd and D-Bus. |
| `fstab.conf` | crypttab options and no extra `/tmp` entry (trixie already mounts `/tmp` as tmpfs). The root entry gets key `none` and no options because `/boot` is unencrypted. |
| `displaymanager.conf` | LightDM with the GTK greeter and the Xfce session. |
| `packages.conf` | the removals in section 6 (apt, offline; `update_db: false`). |
| `bootloader.conf` | GRUB, EFI entry `SnapshOT`, plus the removable-media fallback path. |
| `finished.conf` | the restart prompt at the end. |

Run `scripts/check-installer.sh` after changing any of these: it validates every file
against the schema of the Calamares release the image ships (see `docs/build.md`).

## QA checklist (VMware Fusion or any UEFI VM)

1. Create a VM with UEFI firmware and no network adapter; boot the ISO.
2. Install with **Erase disk** and **Encrypt system**; the install completes.
3. Reboot: the themed GRUB menu appears with no text passphrase prompt.
4. Plymouth asks for the passphrase once; LightDM shows the login screen; log in.
5. `lsblk -f` shows the ESP (vfat), `/boot` (ext4) and the root on a `luks-*`
   mapping.
6. `groups` lists `sudo`, `dialout`, `kvm`, `plugdev`, `netdev` and `wireshark`;
   `getcap /usr/bin/dumpcap` shows `cap_net_admin,cap_net_raw=eip`, and
   `tshark -D` lists the interfaces without `sudo`.
7. `sudo -v` asks for the password; a second `sudo -v`, also from another terminal,
   does not ask again within the hour.
8. `dpkg -l 'live-*' 'calamares*' user-setup` reports no installed packages.
9. There is no Install SnapshOT icon on the desktop.
10. `cat /etc/default/grub` and `cat /proc/cmdline` each show `splash` exactly once.
