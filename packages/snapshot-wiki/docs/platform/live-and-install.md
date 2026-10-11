---
title: Live session and install
summary: Booting SnapshOT live, running from USB, and the offline encrypted install to disk.
---

SnapshOT is a Debian 13 (trixie) live image for OT and ICS assessment and
incident response. It boots to an Xfce desktop with the discovery, traffic,
protocol, firmware, radio, forensics and reporting tools documented in this
wiki, and it installs to disk with LUKS2 encryption and no network. Between
clients the laptop is wiped and re-imaged. This page is the operator's short
version; the authoritative detail is in the repository's
`docs/getting-started.md` and `docs/offline-install.md`.

## Writing the image and booting

Write the ISO to a USB stick or attach it to a VM with UEFI firmware. The amd64
image is for x86-64 laptops, desktops and VMs and boots on BIOS or UEFI; the
arm64 image is for arm64 VMs on Apple Silicon (UTM, Parallels, VMware Fusion)
and UEFI arm64 hardware, boots UEFI only, and does not boot an Apple Silicon Mac
directly. See [architectures](architectures.md) for the full comparison.
balenaEtcher works as is; with Rufus choose DD Image mode, not ISO mode; with
Ventoy copy the ISO onto the stick. For a VM, enable UEFI, give it 4 GB of RAM
and a 20 GB disk; remove the network adapter to test the offline install path.

Secure Boot can stay on. The ISO starts through shim, signed by Microsoft, then
GRUB and the kernel signed by Debian, and an installed system boots the same way.
With Secure Boot on, the kernel runs in lockdown: it loads only signed modules and
blocks raw access to memory and I/O ports, which stops
[flashrom](../tools/firmware/flashrom.md)'s `internal` programmer (the laptop's
own firmware) but not its external SPI programmers. `mokutil --sb-state` shows
whether Secure Boot is on.

## The live session

The live session logs in automatically as user `snapshot`. The password `live`
is only needed to unlock the screen: `sudo` and the installer do not ask for it
in the live session. The live user already has the groups needed for the work,
including `wireshark` for capture and `dialout` for serial; see
[administration and capture](admin-and-capture.md). The
[desktop page](desktop.md) shows where the tools are in the menu and the
keyboard shortcuts. Wi-Fi is switched off until you turn it on from the network
icon or with `nmcli radio wifi on`; see
[quiet network defaults](network-defaults.md#wi-fi).

## Installing to disk

**Install SnapshOT** on the desktop starts Calamares, which copies the running
live system to disk and uses no network, so it behaves the same at an air-gapped
site. Choose **Erase disk** and **Encrypt system** and set a disk passphrase.
The layout is an EFI system partition (on UEFI), a 1 GiB unencrypted `/boot`, and
the root filesystem (ext4 by default) inside LUKS2; swap is off by default and,
if chosen, is a file inside the encrypted root, so there is no hibernation.
`/boot` is left outside LUKS because Calamares formats LUKS2 with Argon2id, which
Debian's GRUB cannot unlock.

The account created in the installer administers the system through `sudo`; root
stays locked. Its login must not already exist on the system: the installer
refuses names such as `operator`, `daemon` or `wireshark` on its users page. The installer removes the live-session packages (`live-boot`,
`live-config`, `user-setup`) and Calamares itself, so the installed desktop has
no Install icon.

On UEFI the installer puts shim, signed GRUB and MokManager in the EFI system
partition twice: under `EFI/SnapshOT`, which the firmware's `SnapshOT` boot
entry starts, and at the removable media path `EFI/BOOT`, which the firmware
starts when it has no boot entry (after an NVRAM reset, or in a VM given a fresh
variable store); shim then recreates the `SnapshOT` entry. Either way the
installed system boots with Secure Boot on.

## First boot

The themed GRUB menu appears without a passphrase prompt; the Plymouth splash
then asks for the disk passphrase once and the initramfs unlocks the root volume;
LightDM shows the login screen. Sign in with the account created during the
install.

## Related pages

- [The desktop, menu and shortcuts](desktop.md): the tool folders, the
  favorites and the field kit.
- [Administration and capture](admin-and-capture.md): the sudo model, root
  terminal, and packet capture without root.
- [Quiet network defaults](network-defaults.md): how the image stays silent on a
  plant network.
- [Architectures](architectures.md): amd64 against arm64.
- [Field updates](field-updates.md): re-imaging, and the signed offline mirror
  exception.
