# Installing SnapshOT offline with LUKS

The installer (Calamares 3.3) copies the running live system to disk. It needs no
network at any point, so it works the same at an air-gapped site.

## 1. Boot the live system

- Write the ISO to a USB stick (`dd if=snapshot-amd64.hybrid.iso of=/dev/sdX bs=4M
  conv=fsync`, or Ventoy), or attach it to a VM with UEFI firmware and at least 3 GB of
  RAM (4 GB recommended). For a test of the offline path, give the VM no network
  adapter.
- Secure Boot can stay on: the ISO and the installed system both boot through
  shim ([Secure Boot](#secure-boot)).
- The SnapshOT boot menu appears; the first entry starts the live system.
- The live session logs in automatically as user `snapshot`. The password `live` is
  only needed to unlock the screen; `sudo` and the installer do not ask for it.

## 2. Install

1. Double-click **Install SnapshOT** on the desktop. The icon exists only in the live
   session.
2. Welcome page: Calamares checks for at least 10 GiB of disk and 3 GiB of RAM. There
   is no internet check. The RAM floor is for the encrypted root: cryptsetup formats
   LUKS2 with Argon2id, which takes up to 1 GiB of memory (half the RAM, if that is
   less) on top of the live session, and the live system has no swap. With 2 GiB the
   kernel killed cryptsetup for lack of memory, which also stopped the system D-Bus
   (the KPMcore helper that runs cryptsetup is started by it), so the desktop session
   restarted with "Unable to contact settings server" on a black screen and the
   install was lost. Below 3 GiB the welcome page now stops before anything is
   written.
3. Location and keyboard.
4. Partitions: choose **Erase disk**, tick **Encrypt system** and enter the disk
   passphrase. The root filesystem defaults to ext4 (btrfs and xfs are offered). Swap
   is off by default; the only other choice is a swap file inside the encrypted root.
5. Users: name, login and password. The password must be at least six characters
   and must not be a dictionary word or contain the login name (libpwquality with
   the cracklib dictionary). This account administers the system through `sudo`;
   there is no root password. The login must not already exist on the system:
   names such as `operator`, `daemon` or `wireshark` are refused on this page,
   because the install would otherwise fail at its last step.
6. Summary, then **Install**. The restart is the last step: the line under the
   progress bar reads "Restarting in 5 seconds" while the bar still stands at about
   96% (the bar advances as each step finishes, and this one finishes only as the
   machine goes down, so 100% shows for a moment at most), and five seconds later
   the machine reboots on its own; remove the USB stick as the screen goes dark.
   The Finished page only appears if that reboot fails.

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
2. The Plymouth splash asks for the disk passphrase once: under the lockup it shows
   "Please unlock disk luks-...", a blinking red caret, and the hint "Type the
   passphrase, then press Enter". Each keystroke adds a red square. The initramfs
   then unlocks the root volume.
3. LightDM shows the login screen; sign in with the account created during the install.

### arm64: the prompt on screen, or on a serial console

On arm64 the installed system's kernel command line ends in
`plymouth.ignore-serial-consoles`. It comes from `snapshot-boot`'s
`/etc/default/grub.d/61-snapshot-arm64-console.cfg`, which `update-grub` applies
after `/etc/default/grub` and which adds the word on arm64 only; amd64 installs
carry the same file, and their command line does not change.

arm64 firmware often names a serial port as the console: QEMU's `virt` machine,
which UTM uses, names its PL011 port in the device tree, and ACPI firmware can do the
same with an SPCR table. The kernel console is then that serial port, and Plymouth,
when it finds a serial console, shows only a text prompt there and nothing on the
screen: the boot stops at a black screen on which typing does nothing, while the
passphrase prompt waits on the serial port. With the parameter, Plymouth leaves
serial consoles alone and the splash asks for the passphrase on the display. The
live ISO's boot entries do not carry it: the live session asks for nothing, so on
such firmware its boot only shows a black screen until the desktop appears.

To unlock over a serial console instead (a headless board, or a VM whose serial
port is the only console you use): at the GRUB menu press `e`, delete
`plymouth.ignore-serial-consoles` from the end of the `linux` line and press Ctrl-x;
the passphrase prompt then appears on the serial console. To do that on every boot,
delete `/etc/default/grub.d/61-snapshot-arm64-console.cfg` and run `sudo
update-grub`; dpkg does not bring back a configuration file that was deleted.

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

## Secure Boot

The live ISO and the installed system both boot with Secure Boot on, on UEFI
firmware that trusts Microsoft's UEFI CA (most laptops, and the Secure Boot option
of VMware, Hyper-V and OVMF). The image carries `shim-signed` (shim, signed by
Microsoft, and MokManager) and `grub-efi-amd64-signed` or `grub-efi-arm64-signed`
(GRUB signed by Debian); the kernel is Debian's signed kernel.

Calamares' bootloader step runs `/usr/lib/snapshot-boot/grub-install` instead of
`grub-install`. The wrapper ships in `snapshot-boot`, which stays installed, because
the `packages` step has already removed `calamares-settings-snapshot` from the target
when the bootloader step runs. On UEFI it adds `--uefi-secure-boot
--force-extra-removable` to Calamares' `--target`, `--efi-directory`,
`--bootloader-id=SnapshOT` and `--force`, copies `grub.cfg` to the removable media
path and names the fallback's boot entry, so the EFI system partition holds (amd64
names; arm64 has `aa64` in place of `x64`):

| Directory | Files |
|---|---|
| `EFI/SnapshOT/` | `shimx64.efi` (shim), `grubx64.efi` (signed GRUB), `mmx64.efi` (MokManager), `fbx64.efi` (shim's fallback), `BOOTX64.CSV` (the boot entry the fallback recreates), `grub.cfg` (finds `/boot` by its UUID and loads `/boot/grub/grub.cfg`) |
| `EFI/BOOT/` | `BOOTX64.EFI` (shim), `fbx64.efi`, `grubx64.efi`, `mmx64.efi`, `grub.cfg` (a copy) |

The firmware's boot entry `SnapshOT` starts `\EFI\SnapshOT\shimx64.efi`. A machine
with no boot entry (its NVRAM was reset, or a VM got a fresh variable store) starts
the removable media path `\EFI\BOOT\BOOTX64.EFI`: shim runs its fallback, which
recreates the `SnapshOT` entry from `EFI/SnapshOT/BOOTX64.CSV` and boots it (shim's
own copy of that file names the entry `debian`; the wrapper rewrites it). If the
fallback cannot help, shim starts the signed GRUB beside it, which reads `grub.cfg`
from its own directory, else from its built-in prefix `/EFI/debian`, which a SnapshOT
install does not have: hence the copy. `bootloader.conf` turns Calamares' `installEFIFallback` off, because it copies
`grubx64.efi` to `EFI/boot/bootx64.efi`, over the shim, and firmware with Secure
Boot on refuses GRUB started without shim. BIOS installs (amd64) pass through the
wrapper unchanged (`--target=i386-pc`). `config/preseed/snapshot-grub.cfg.chroot`
answers `grub2/force_efi_extra_removable` with true, so a `grub-efi-*` or
`shim-signed` upgrade from the offline mirror refreshes `EFI/BOOT` along with
`EFI/SnapshOT`.

With Secure Boot on, Debian's kernel runs in lockdown (integrity mode): it loads
only signed modules (an out-of-tree module needs a Machine Owner Key enrolled with
`mokutil --import`) and refuses raw access to memory and I/O ports, so flashrom's
`internal` programmer, which reads and writes the laptop's own firmware, does not
work; external SPI programmers are unaffected. `mokutil --sb-state` prints the state,
and `sudo dmesg | grep -i secure` shows `secureboot: Secure boot enabled`.

## Module configuration

The installer sequence lives in
`packages/calamares-settings-snapshot/rootfs/etc/calamares/settings.conf`, with one
file per module in `modules/`. Debian's `calamares` package ships no module
configuration, and this package replaces `calamares-settings-debian`, so a module with
no file here runs on upstream defaults; `displaymanager` refuses to run at all
without one.

| File | Sets |
|---|---|
| `welcome.conf` | storage (10 GiB), RAM (3 GiB, for the LUKS2 format) and root checks; no internet check. Also publishes `requiredStorageGiB`, without which the partition page offers neither "replace" nor "alongside". |
| `partition.conf` | erase by default, LUKS2, ext4 default, swap off; the layout above (`partitionLayout` with a 1 GiB unencrypted `/boot`). |
| `users.conf` | the groups above, `sudoersGroup: sudo`, root locked. Without it Calamares falls back to lp/video/network/storage/wheel/audio and the user has no sudo. `user.forbidden_names` lists every user and group name in the image plus `autologin`: Calamares creates the user with `useradd -m -U`, which fails at the end of the install when the name is taken, and itself refuses only `root` and `nobody`. Hook `0950-snapshot-installer-reserved-names` rewrites the list between its BEGIN and END lines at image build, from the image's `/etc/passwd` and `/etc/group`. |
| `mount.conf` | binds `/dev`, `/dev/pts`, `/proc`, `/sys`, `/run`, `/run/udev` and `efivarfs` into the target so `grub-install`, `update-initramfs` and apt work in the chroot. |
| `unpackfs.conf` | copies `/run/live/medium/live/filesystem.squashfs` to the target. |
| `machineid.conf` | a fresh machine-id for systemd and D-Bus. |
| `fstab.conf` | crypttab options and no extra `/tmp` entry (trixie already mounts `/tmp` as tmpfs). The root entry gets key `none` and no options because `/boot` is unencrypted. |
| `displaymanager.conf` | LightDM with the GTK greeter and the Xfce session. |
| `packages.conf` | the removals in section 6 (apt, offline; `update_db: false`). |
| `bootloader.conf` | GRUB through `snapshot-boot`'s wrapper `/usr/lib/snapshot-boot/grub-install`: on UEFI, shim, MokManager and the Debian-signed GRUB in `EFI/SnapshOT` (boot entry `SnapshOT`) and at the removable media path `EFI/BOOT`; `installEFIFallback: false`, because Calamares' fallback would copy GRUB over that shim ([Secure Boot](#secure-boot)). |
| `finished.conf` | the restart prompt at the end, reached only if the automatic restart fails. |
| `shellprocess.conf` | the automatic restart: last in the sequence, after `umount`, it waits five seconds with "Restarting in 5 seconds" in the progress line and runs `systemctl -i reboot` on the live system. |

Run `scripts/check-installer.sh` after changing any of these: it validates every file
against the schema of the Calamares release the image ships (see `docs/build.md`).

## QA checklist (VMware Fusion or any UEFI VM)

1. Create a VM with UEFI firmware and no network adapter; boot the ISO.
2. Install with **Erase disk** and **Encrypt system**; the install completes.
3. "Restarting in 5 seconds" appears under the progress bar while the bar stands at
   about 96%, and the installer reboots on its own five seconds later (the bar may
   flick to 100% as the screen goes dark); the themed GRUB menu appears with no
   text passphrase prompt.
4. Plymouth asks for the passphrase once, on screen, with a blinking caret, the hint
   line and one red square per keystroke (BackSpace removes one), also on arm64 VMs
   whose firmware names a serial console; LightDM shows the login screen; log in.
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
    On arm64 `/proc/cmdline` ends in `plymouth.ignore-serial-consoles`; on amd64 it
    does not contain it.
11. A VM with 2 GB of RAM stops at the welcome page: Calamares reports that it needs
    at least 3 GiB and Next stays disabled.
12. `nmcli radio wifi` prints `disabled`. On a machine with a Wi-Fi adapter,
    `nmcli radio wifi on` makes it available and `nmcli device wifi list` lists
    networks; `nmcli radio wifi off` switches it off again.
13. `sudo ls /boot/efi/EFI/SnapshOT /boot/efi/EFI/BOOT` shows shim, GRUB, MokManager
    and `grub.cfg` in both directories ([Secure Boot](#secure-boot)).
14. Secure Boot, on a second VM with Secure Boot on and Microsoft's keys (VMware:
    "Enable secure boot"; QEMU: OVMF's `OVMF_CODE_4M.secboot.fd` with a copy of
    `OVMF_VARS_4M.ms.fd`): the ISO boots, the install completes, and the installed
    system boots and unlocks; `mokutil --sb-state` prints `SecureBoot enabled`.
    Then power off, reset the VM's NVRAM (VMware: delete the `.nvram` file; QEMU: a
    fresh copy of the variable store) and boot again: the removable media path
    starts the same system, and shim's fallback recreates the `SnapshOT` boot entry.
    The image has no `efibootmgr` (install it from the
    [update stick](updates.md) if you want it); read the boot entries from the
    firmware variables instead (`tail` cannot seek in efivarfs files, hence the
    `cat`):

    ```sh
    cd /sys/firmware/efi/efivars
    g=8be4df61-93ca-11d2-aa0d-00e098032b8c
    od -An -tx2 -j4 BootCurrent-$g   # the entry that started this boot
    od -An -tx2 -j4 BootOrder-$g
    for f in Boot0*-$g; do          # each entry: its name and loader path
        printf '%s:' "${f%%-*}"
        cat "$f" | tail -c +11 | iconv -f UTF-16LE -t UTF-8 -c 2>/dev/null |
            tr -c '[:print:]' ' ' | tr -s ' '
        echo
    done
    ```

    After the NVRAM reset, `BootCurrent` names the firmware's removable-media entry
    (QEMU: `UEFI Misc Device`) and a new `SnapshOT` entry starts
    `\EFI\SnapshOT\shimx64.efi` (`shimaa64.efi` on arm64); on the next boot from
    the variable store the installer wrote, `BootCurrent` is the `SnapshOT` entry.
15. On the users page, the login `operator` shows "'operator' is not allowed as
    username." and **Next** stays disabled; `operator1` is accepted.
