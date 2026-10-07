---
title: Architectures
summary: How the amd64 and arm64 images differ, and which tools are amd64 only.
---

SnapshOT is built for two architectures from the same tree and the same Debian
snapshot pin. They differ only where the hardware or an upstream tool forces it.
The figures and the full table are in the repository's `README.md`; this page is
the operator's summary.

## Which image to use

- **amd64**: x86-64 laptops, desktops and VMs (VMware, VirtualBox, Hyper-V,
  QEMU/KVM). The live ISO boots on BIOS or UEFI.
- **arm64**: arm64 VMs on Apple Silicon (UTM, Parallels, VMware Fusion) and UEFI
  arm64 hardware. The live ISO boots UEFI only, and **does not boot an Apple
  Silicon Mac directly**: run it in a VM.

## What differs

| | amd64 | arm64 |
|---|---|---|
| Use it on | x86-64 laptops, desktops and VMs | arm64 VMs on Apple Silicon and UEFI arm64 hardware |
| Live ISO boots with | BIOS or UEFI | UEFI only |
| Installed bootloader | GRUB for BIOS or UEFI, matching how the live system started | GRUB for UEFI |
| Kernel | Debian amd64 kernel | Debian arm64 kernel |
| CPU microcode | Intel and AMD microcode | none (those packages are x86 only) |
| OPC UA GUI client (*opcua-client*) | yes | no: PyQt5 publishes no Linux aarch64 wheels, and the vendor layer installs wheels only |
| The Sleuth Kit CLI, TestDisk/PhotoRec | yes | yes |
| Image size with the vendor layer | slightly larger | slightly smaller |

Everything else is the same on both: the Debian package lists, the other
vendored tools (the ICS Python libraries and OPC UA command-line tools, plcscan,
[Redpoint NSE](../tools/recon/redpoint-nse.md)), the desktop, the installer and
the [quiet network defaults](network-defaults.md).

## Launchers for amd64-only tools

The launcher for the one amd64-only tool, opcua-client, ships on both images and
is simply hidden on arm64, so the menu is consistent and a tool appears only
where it can run. The [build manifest](build-manifest.md) of a
given image lists what it actually contains.

## Related pages

- [Live session and install](live-and-install.md): writing and booting each
  image.
- [The vendor layer](vendor-layer.md): why opcua-client is amd64 only, and why
  [Autopsy](../tools/forensics/autopsy.md) is not shipped on either image.
- [Build manifest](build-manifest.md): the exact contents of the image in hand.
