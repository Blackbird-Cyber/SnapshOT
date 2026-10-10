---
title: Ghidra
summary: Software reverse engineering suite
folder: firmware
launchers: [snapshot-ghidra.desktop]
ships_as: vendor
package: ghidra
arch: [amd64, arm64]
status: not-shipped
wire: passive
phases:
  identification: Where shipped, disassemble and decompile a firmware binary or a sample to understand what it does.
  eradication: Where shipped, analyse an implant found in firmware to confirm its behaviour and what to remove.
csf: [identify, respond]
attack_ics: [persistence, impair-process-control]
attack_role: investigates
upstream: https://github.com/NationalSecurityAgency/ghidra
---

<!-- snapshot:facts -->

## What it is

Ghidra is a software reverse engineering suite from the NSA: a disassembler and
decompiler with support for many processor families, used to read compiled code
when no source is available. On a firmware engagement it is the tool for taking a
binary extracted from a device, turning the machine code into readable
pseudo-C, and working out what an unknown or implanted routine does.

## Why it is not shipped

Ghidra is pinned in `vendor/sources.lock` but its stanza is `enabled: false`. It
is a large Java application that runs on a full JDK 21: Ghidra is about 435 MiB
and pulls the 180+ MiB Temurin JDK on both architectures, which would push the
amd64 image toward GitHub's 2 GiB release-asset limit. It is
defined so the shape is recorded but is not fetched or installed in this image,
and its menu launcher stays hidden because the program it points at is absent.
See the [vendor layer](../../platform/vendor-layer.md) platform page for how
disabled tools are handled and how one would be enabled.

## What to use instead

- [binwalk](binwalk.md) identifies, extracts and carves the contents of a
  firmware image, which is the first and most common step; much triage needs no
  full disassembler.
- [QEMU](qemu.md) runs an extracted image or a sample in an offline sandbox to
  observe its behaviour dynamically instead of statically.
- [sdcc](sdcc.md)'s `makebin` normalises firmware between Intel HEX and raw
  binary for hashing and comparison.
- For deep static analysis of a binary, do the work on a separate,
  properly-resourced analysis machine with a reverse-engineering toolchain;
  SnapshOT's role is acquisition and triage.

## Upstream documentation

- [Ghidra on GitHub](https://github.com/NationalSecurityAgency/ghidra): the
  project, releases and documentation.
