---
title: binwalk
summary: Firmware analysis and extraction
folder: firmware
launchers: [snapshot-binwalk.desktop]
ships_as: apt
package: binwalk
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Scan and hash the vendor's known-good firmware images, so a dump taken later has a reference to be compared with.
  identification: Examine a firmware file found on a host or downloaded as an update, offline, for file systems, compression and keys, without running it.
  eradication: Extract the device's dump and the known-good image side by side and compare them to find what was changed.
csf: [identify, detect, respond]
attack_ics: [persistence, lateral-movement, inhibit-response-function, impair-process-control]
attack_role: investigates
attack_techniques: [T1693, T1693.001, T1693.002, T1694.002]
upstream: https://github.com/OSPG/binwalk
---

<!-- snapshot:facts -->

## What it is

binwalk looks inside a binary file, usually a firmware image, for the signatures
of things embedded in it: compressed archives, file systems such as SquashFS,
JFFS2 and CramFS, Linux kernels, bootloaders, certificates and keys. It prints
the offset and a description of each one and, when asked, carves them out and
unpacks them into a folder. It can also plot or list the entropy of a file to
show compressed or encrypted regions, guess the CPU architecture from common
opcode patterns, and show a hex diff of two or more files. It only reads files:
nothing in the image is run.

## Why it is on SnapshOT

Firmware is where persistence on a controller, gateway, switch or HMI can hide,
below anything a host triage collects. binwalk is the first look at a dump taken
with [flashrom](flashrom.md) or [OpenOCD](openocd.md), at an update file found
on an engineering workstation, or at a vendor image before it is trusted as the
known-good reference. Comparing the layout and the extracted files of a suspect
image with the vendor's shows what was added or changed.

Debian's binwalk recommends a set of external unpackers, and the image installs
no recommends, so binwalk unpacks only the formats whose tools are on the image
for other reasons, such as SquashFS (`squashfs-tools` comes with the installer)
and gzip. Other formats are still found and reported; carve their bytes out with
`-z` and examine them with other tools.

## On the wire

!!! note "Passive: it never transmits"

    binwalk works on files. The physical risk of getting the firmware off a
    device belongs to [flashrom](flashrom.md) and [OpenOCD](openocd.md); by the
    time binwalk runs, the dump should already be hashed and stored as evidence.

    - Work on a copy of the dump, never on the evidence file itself, and
      re-check the original's hash when you finish.
    - Extraction runs third-party unpackers on untrusted data. Run binwalk as
      your own user, not with `sudo` (it refuses to extract as root unless told
      to, for this reason), and extract into a working folder inside the case.
    - Never use `-1` (`--preserve-symlinks`): it keeps symbolic links that point
      outside the extraction folder.
    - Do not run anything found inside an extracted image on the laptop; scripts
      and binaries from a suspect firmware are evidence, not tools.
    - binwalk only opens a network port if you ask for its status server with
      `-s`; leave it off.

## PICERL mapping

### Preparation

Before the engagement, collect the vendor firmware images for the devices in
scope from the asset owner or the vendor's portal, hash them and run a signature
and entropy scan of each. Keep the output with the images: this is the reference
layout a dump taken later is compared with, and the hash proves which image was
used. See [preparation](../../lifecycle/phases/preparation.md).

### Identification

During [identification](../../lifecycle/phases/identification.md), firmware
files turn up on engineering workstations, file shares and the
[field kit](../forensics/fieldkit.md)'s collections. Scan each one offline: a
layout that differs from the vendor's, an extra file system, a high-entropy
region where the vendor image has none, or a creation date that does not match
the release are reasons to acquire the device's own firmware next.

### Eradication

This is binwalk's main phase in the
[firmware acquisition](../../lifecycle/playbooks/firmware-acquisition.md)
playbook. Extract the device's dump and the known-good image into separate
folders, hash every extracted file and compare the two lists: changed start-up
scripts, added binaries and modified web interface files are the persistence to
remove. A hex diff of the two images finds changes in parts that do not extract.
After a reflash, the read-back dump must match the known-good image exactly.

## MITRE ATT&CK for ICS mapping

binwalk *investigates*. Its main subject is Modify Firmware (T1693), in both of
its forms: System Firmware (T1693.001) and Module Firmware (T1693.002), which
serve the [Persistence](../../lifecycle/attack-ics/persistence.md),
[Inhibit Response Function](../../lifecycle/attack-ics/inhibit-response-function.md)
and [Impair Process Control](../../lifecycle/attack-ics/impair-process-control.md)
tactics. The evidence is the list of offsets and extracted files that differ from
the known-good image.

Extracted file systems also contain password files, keys and certificates. Record
them as findings: anyone holding the same firmware has them too, which is
Hardcoded Credentials (T1694.002), a technique of Persistence and
[Lateral Movement](../../lifecycle/attack-ics/lateral-movement.md).

## Quick start

```sh
# What the menu launcher runs
binwalk -h
# Signature scan: what is inside the image, and at which offset
binwalk dump.bin
# Entropy by region, as text (no plot)
binwalk -E -N dump.bin
# Guess the CPU architecture from opcode signatures
binwalk -A dump.bin
# Extract what it recognizes into a working folder, as your own user
binwalk -e -C work dump.bin
# Recurse into what it extracted, at most 3 levels deep
binwalk -e -M -d 3 -C work dump.bin
# Hex diff of two images, showing only the lines that differ
binwalk -W -i known-good.bin dump.bin
```

`dump.bin` stands for the working copy of a dump. Extraction writes a folder
named `_dump.bin.extracted` under the `-C` directory.

## Output and evidence

Keep the dump untouched, scan a copy, log the scan and hash the extracted tree,
so the comparison with the known-good image can be repeated by anyone:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/firmware/work"
cp "$CASE/firmware/rtu7-spi-20261006T142530Z.bin" "$CASE/firmware/work/rtu7.bin"
cd "$CASE/firmware/work"
# Signature scan to a log file as well as the screen
binwalk -f rtu7-scan.txt rtu7.bin
binwalk -e -C rtu7-x rtu7.bin
# One hash per extracted file, sorted, to compare with the known-good list
( cd rtu7-x && find . -type f -exec sha256sum {} + | sort -k 2 ) > rtu7-files.sha256
sha256sum rtu7-scan.txt rtu7-files.sha256 >> "$CASE/SHA256SUMS"
```

Do the same for the known-good image and compare the two file lists with `diff`.

## Related tools

- [flashrom](flashrom.md) and [OpenOCD](openocd.md): acquire the firmware from
  SPI flash or through a debug port.
- [sdcc](sdcc.md): its `makebin` turns an Intel HEX image into the raw binary a
  dump can be compared with.
- [QEMU](qemu.md): boot an extracted image offline when it targets a machine QEMU
  emulates.
- [The Sleuth Kit](../forensics/sleuthkit.md): examine extracted disk and file
  system images.
- [Ghidra](ghidra.md) and [firmware-mod-kit](firmware-mod-kit.md): defined in the
  vendor layer but not shipped on this image.

## Upstream documentation

- [binwalk on GitHub](https://github.com/OSPG/binwalk): source and usage notes
  for the 2.x line that Debian ships.
