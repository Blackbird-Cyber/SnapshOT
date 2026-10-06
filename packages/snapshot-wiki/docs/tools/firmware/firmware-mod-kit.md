---
title: firmware-mod-kit
summary: Extract and rebuild firmware images
folder: firmware
launchers: [snapshot-firmware-mod-kit.desktop]
ships_as: vendor
package: firmware-mod-kit
arch: [amd64, arm64]
status: not-shipped
wire: passive
phases:
  eradication: Where shipped, extract a Linux-based firmware image, make a change and rebuild it for a reflash.
csf: [identify, respond]
attack_ics: [persistence, impair-process-control]
attack_role: investigates
upstream: https://code.google.com/archive/p/firmware-mod-kit/
---

<!-- snapshot:facts -->

## What it is

The Firmware Mod Kit is a collection of scripts that extract a Linux-based
firmware image into its parts, let you change the file system or the device's web
interface, and rebuild the image so it can be flashed back. It automates the
unpack-modify-repack cycle for the common consumer and embedded firmware formats,
on top of carvers such as the one [binwalk](binwalk.md) uses.

## Why it is not shipped

Firmware Mod Kit is defined in `vendor/sources.lock` as a disabled placeholder.
As its lock note and the "Out of scope and why" list in the vendoring guide
(`docs/vendoring.md` in the SnapshOT source) record, it needs its own build stage
and has not yet been vendored, so the stanza is `enabled: false`: the shape is
recorded but nothing is fetched or installed, and its menu launcher stays hidden
because the program it points at is absent. See the
[vendor layer](../../platform/vendor-layer.md) platform page for how disabled
tools are handled.

## What to use instead

- [binwalk](binwalk.md) does the extraction half of the same job, identifying and
  carving the file systems and components of a firmware image for analysis and
  comparison; this is what most of an incident needs.
- [flashrom](flashrom.md) and [OpenOCD](openocd.md) read a device's firmware and,
  with the engineer, write a verified known-good image back. The SnapshOT
  doctrine is to restore a vendor-verified image, not to hand-modify and repack
  firmware on an engagement.
- [QEMU](qemu.md) runs an extracted image offline to observe it.

## Upstream documentation

- [Firmware Mod Kit](https://code.google.com/archive/p/firmware-mod-kit/): the
  original project archive.
