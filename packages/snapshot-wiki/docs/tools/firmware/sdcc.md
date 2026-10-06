---
title: sdcc
summary: Small Device C Compiler for 8-bit microcontrollers
folder: firmware
launchers: []
ships_as: apt
package: sdcc
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  identification: Convert a firmware image between Intel HEX and raw binary so it can be read, hashed and compared in a consistent form.
  eradication: Rebuild or convert firmware for an 8-bit target, and turn HEX images into the binary a dump is compared against.
csf: [identify, respond]
attack_ics: []
attack_role: none
upstream: https://sdcc.sourceforge.net/
---

<!-- snapshot:facts -->

## What it is

SDCC, the Small Device C Compiler, is a C compiler and toolchain for 8-bit and
small microcontrollers: the 8051 (MCS-51) family, Z80 and relatives, STM8,
Padauk and others. Alongside the compiler it installs assemblers, linkers and a
few utilities, of which two matter most for firmware work: `makebin`, which
converts an Intel HEX (`.ihx`) image into a raw binary (padding the gaps), and
`packihx`, which tidies an Intel HEX file. It produces and manipulates firmware
rather than touching any device.

## Why it is on SnapshOT

Firmware for small controllers often comes as Intel HEX, while a dump read from a
chip is raw binary; the two cannot be compared until they are in the same form.
`makebin` converts a vendor HEX release into the binary that lines up with a
[flashrom](flashrom.md) or [OpenOCD](openocd.md) dump, so [binwalk](binwalk.md)
and a hash comparison mean something. When a device runs an 8-bit core, SDCC is
also the toolchain for understanding or rebuilding small pieces of its code on
the bench. It is a developer tool pressed into an analysis role, so it has no
menu launcher; run it from a terminal.

## On the wire

!!! note "Passive: it never transmits"

    SDCC is a compiler and a set of file converters. It reads and writes files on
    the laptop and never connects to a device or a network.

    - Work on copies of firmware images inside the case folder; keep the original
      dump and the vendor release untouched as evidence.
    - A converted image is derived evidence: record the exact command used to
      produce it, and hash both the input and the output.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), firmware found
as an update file or a vendor release may be in Intel HEX. Convert it to a raw
binary with `makebin` so it can be scanned in [binwalk](binwalk.md), hashed, and
held in the same form as a chip dump taken later.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), comparing a device's
dump with the known-good image needs both in one format; `makebin` produces the
binary form of a HEX release for a byte comparison. When the device runs an 8-bit
core, SDCC can also rebuild small code for it, though the reflash itself is done
with [flashrom](flashrom.md) or [OpenOCD](openocd.md).

## MITRE ATT&CK for ICS mapping

SDCC has no direct relationship to an ATT&CK for ICS tactic. It is an offline
compiler and file converter: it prepares and transforms firmware images for
analysis, and the tactics belong to the tools that read or write a device, such
as [flashrom](flashrom.md) and [OpenOCD](openocd.md), and to the comparison done
in [binwalk](binwalk.md).

## Quick start

SDCC has no menu launcher; run it in a terminal.

```sh
# Version and the targets this build supports
sdcc --version
# Compile a small C file for the 8051 (produces an .ihx among other files)
sdcc -mmcs51 blink.c
# Convert an Intel HEX image to a raw binary, truncated to the last byte used
makebin -p firmware.ihx firmware.bin
# Convert and pad to a fixed ROM size, for a byte-for-byte comparison
makebin -s 65536 firmware.ihx firmware-64k.bin
# Tidy an Intel HEX file
packihx firmware.ihx > firmware-packed.ihx
```

`makebin` reads from standard input and writes to standard output when no files
are given, so it fits in a pipeline.

## Output and evidence

A converted image is derived from an original; keep both and record how one came
from the other:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/firmware"
V="$CASE/firmware/rtu7-vendor"
# Convert the vendor HEX release to the binary form for comparison
makebin -p "$V.ihx" "$V.bin"
sha256sum "$V.ihx" "$V.bin" >> "$CASE/SHA256SUMS"
# Compare the chip dump with it, over the length the vendor image covers
cmp -n "$(stat -c %s "$V.bin")" "$V.bin" "$CASE/firmware/rtu7-spi-20261006T142530Z.bin"
```

A chip dump is the size of the whole chip while `makebin -p` stops at the last
byte the HEX file uses, so compare over the vendor image's length (as above), and
check that the HEX addresses start where the dump starts.

## Related tools

- [binwalk](binwalk.md): scan and extract the binary images `makebin` produces.
- [flashrom](flashrom.md) and [OpenOCD](openocd.md): read the chip dump that a
  converted HEX release is compared against, and write a verified image back.

## Upstream documentation

- [SDCC website](https://sdcc.sourceforge.net/): the compiler, the toolchain and
  the `makebin` and `packihx` utilities.
