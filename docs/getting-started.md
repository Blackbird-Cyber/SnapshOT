# Getting started with SnapshOT

This page takes a SnapshOT image from the download to a running live session and
an encrypted install. The details of the install are in
[offline-install.md](offline-install.md).

## 1. Download

Every release is on the
[releases page](https://github.com/Blackbird-Cyber/SnapshOT/releases), with the
two images and a `SHA256SUMS` file:

- `snapshot-amd64.hybrid.iso` for x86-64 laptops, desktops and VMs. It boots on
  BIOS or UEFI.
- `snapshot-arm64.hybrid.iso` for arm64 VMs on Apple Silicon (UTM, Parallels,
  VMware Fusion) and UEFI arm64 hardware. It boots on UEFI only and does not boot
  an Apple Silicon Mac directly.

The README's [amd64 and arm64 images](../README.md#amd64-and-arm64-images) table
lists every difference between the two. Read the release notes of the release you
download: they list anything that release does not do.

## 2. Verify the download

Compare the hash with the README's release table or with `SHA256SUMS` from the
same release:

```sh
sha256sum -c --ignore-missing SHA256SUMS            # Linux, next to the downloaded ISO
shasum -a 256 snapshot-amd64.hybrid.iso             # macOS
certutil -hashfile snapshot-amd64.hybrid.iso SHA256 # Windows
```

### Images published in parts

GitHub limits a release asset to 2 GiB. An image over the limit is published as
`snapshot-<arch>.hybrid.iso.part-aa`, `.part-ab` and so on. Join the parts in
order, then verify the joined file; `SHA256SUMS` always lists the whole ISO.

```sh
cat snapshot-amd64.hybrid.iso.part-* > snapshot-amd64.hybrid.iso
```

On Windows:

```bat
copy /b snapshot-amd64.hybrid.iso.part-aa + snapshot-amd64.hybrid.iso.part-ab snapshot-amd64.hybrid.iso
```

## 3. Write it to a USB stick

Writing the image erases the whole stick.

- **Linux:** `sudo dd if=snapshot-amd64.hybrid.iso of=/dev/sdX bs=4M conv=fsync status=progress`.
  `/dev/sdX` is the whole stick, not a partition.
- **macOS:** `diskutil unmountDisk /dev/diskN`, then
  `sudo dd if=snapshot-amd64.hybrid.iso of=/dev/rdiskN bs=4m`.
- **balenaEtcher** works as is.
- **Rufus:** when it asks, choose **DD Image** mode, not ISO mode.
- **Ventoy:** copy the ISO onto the Ventoy stick.

## 4. Or run it in a VM

Enable UEFI firmware and give the VM 4 GB of RAM and a 20 GB disk. Use the arm64
image for UTM, Parallels or VMware Fusion on Apple Silicon. To try the offline
install path, remove the VM's network adapter. Secure Boot can stay on, in a VM
or on a laptop: the ISO and the installed system both boot through shim signed by
Microsoft ([offline-install.md](offline-install.md#secure-boot)).

## 5. The live session

The SnapshOT boot menu appears; the first entry starts the live system. The live
session logs in automatically as user `snapshot`. The password `live` is only
needed to unlock the screen: `sudo` and the installer do not ask for it in the
live session. The live user is in group `wireshark`, so Wireshark, tshark and
termshark capture without `sudo`; `tcpdump` still needs it.

Nothing on the image sends traffic until you bring an interface up. Wi-Fi is
switched off, so the laptop sends no probe requests: turn it on from the network
icon in the panel (right-click, **Enable Wi-Fi**) or with `nmcli radio wifi on`,
and off again with `nmcli radio wifi off`. The tools are in the eight numbered
folders of the Whisker menu, at the top left of the panel.

## 6. Install to disk

**Install SnapshOT** on the desktop starts Calamares, which copies the live system
to disk and uses no network. Choose **Erase disk**, tick **Encrypt system** and set
a disk passphrase.

- Layout: an EFI system partition (UEFI only), a 1 GiB unencrypted `/boot`, and the
  root filesystem (ext4 by default) inside LUKS2. Swap is off by default; if you
  choose it, it is a file inside the encrypted root, and there is no hibernation.
- The account you create administers the system through `sudo` with its password,
  remembered for 60 minutes across terminals. Root stays locked.
- The installer removes the live-session packages (`live-boot`, `live-config`,
  `user-setup`) and Calamares itself, so the installed desktop has no Install icon.
- On UEFI the bootloader is shim and Debian-signed GRUB, in `EFI/SnapshOT` and
  again at the removable media path `EFI/BOOT`, so the installed system boots with
  Secure Boot on, also on firmware that has lost its boot entry.

[offline-install.md](offline-install.md) has every step, the disk layout, the
module configuration and the QA checklist.

## 7. First boot

The SnapshOT GRUB menu appears without a passphrase prompt. The boot splash then
asks for the disk passphrase once, and LightDM shows the login screen. Sign in with
the account created during the install.

## 8. The SnapshOT Wiki

Every tool on the image is documented in the SnapshOT Wiki, an offline site in
`/usr/share/snapshot/wiki`. Open it from **08 - Reference > SnapshOT Wiki** or the
Whisker favorites; it is also the home page of Firefox ESR. Start with its
platform guide and the rules of engagement before you connect to a plant network.

Between clients, wipe the laptop and install a fresh image.
[updates.md](updates.md) covers the signed offline USB mirror for the cases where
a package has to be added in the field.
