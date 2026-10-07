---
title: The Sleuth Kit
summary: "Disk image and filesystem forensics: mmls, fsstat, fls, icat, tsk_recover"
folder: forensics
launchers: [snapshot-sleuthkit.desktop]
ships_as: apt
package: sleuthkit
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  identification: Look into a disk image quickly from a terminal, on either architecture, to list recent, deleted and unexpected files.
  eradication: Find the files and autostart entries a foothold left on a host's image, and copy them out for analysis without mounting it.
  lessons-learned: Build a file system timeline with fls and mactime for the incident narrative.
csf: [detect, respond, identify]
attack_ics: [evasion, lateral-movement]
attack_role: investigates
attack_techniques: [T0872, T0867]
upstream: https://www.sleuthkit.org/sleuthkit/
---

<!-- snapshot:facts -->

## What it is

The Sleuth Kit (TSK) is a set of command-line tools that read disk images and
file systems directly, without mounting them. Each tool works at one layer:
`img_stat` the image file, `mmls` the partition table, `fsstat` the file system,
`fls` the file names (including deleted ones), `istat` and `icat` one file's
metadata and content, `tsk_recover` whole directory trees, and `mactime` turns a
file listing into a timeline. It reads raw, split raw, E01, AFF, VMDK and VHD
images and NTFS, FAT, exFAT, ext2/3/4, HFS+, APFS, UFS and ISO 9660 file systems.
`img_cat` writes an image's raw contents out, which turns an E01 into a raw
image for tools that read only raw. [Autopsy](autopsy.md), the graphical front
end on the same library, is not shipped on this image; it runs on an analysis
workstation after the field kit
[hand-off](fieldkit.md#hand-off-to-an-analysis-workstation).

## Why it is on SnapshOT

Many HMIs and engineering workstations are virtual machines or have backup
images, and the quickest way to answer "was this file there, and when did it
change?" is to read the image without booting or mounting it. TSK does that from
a terminal, on both amd64 and arm64 images. Its one-line commands are easy to
record in the case notes, and nothing it does changes the image.

## On the wire

!!! note "Passive: it never transmits"

    TSK reads image files on the laptop and never touches the network or the
    plant.

    - **Work on a copy.** Hash the image when it is made, keep the original
      sealed, and run TSK on a verified copy. TSK opens images read-only, but a
      copy keeps a slip elsewhere from mattering.
    - **Raw devices need `sudo`.** Reading `/dev/sdX` directly needs root;
      image the disk once and work on the file instead.
    - **Extraction writes to the laptop**, not to the image: `icat` and
      `tsk_recover` write where you point them, which should be the case folder.
      Recovered executables are evidence, not tools: never run them.
    - Taking a disk out of a running HMI or controller is the process owner's
      decision, not part of using this tool.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), TSK gives a
first look at an image in minutes: the partitions, the file system, the files in
the directories that matter (startup folders, temporary folders, the engineering
software's project folders) and the deleted entries next to them. Indicators
already found in captures or in a [field kit](fieldkit.md) collection, such as a
file name or a tool's location, can be checked against the listing straight
away. On SnapshOT this is the way into a disk image; a case that needs a full
GUI examination goes to the analysis workstation after the
[hand-off](fieldkit.md#hand-off-to-an-analysis-workstation).

### Eradication

Before a host is cleaned during
[eradication](../../lifecycle/phases/eradication.md), list and copy out every
file a foothold left: the dropped tools, scripts and autostart files. They are
what the clean-up must remove and what the report must describe. On a rebuilt
host's image, the same `fls` listing shows they are gone.

### Lessons Learned

For [lessons learned](../../lifecycle/phases/lessons-learned.md), a body file
from `fls -m` and a CSV timeline from `mactime` put every file's modified,
accessed, changed and created times in one sorted list, which places the
incident's file activity next to the network evidence and the operators'
reports. The CSV opens in [LibreOffice](../reporting/libreoffice.md) Calc for
filtering to the incident window. Keep the exact commands with the timeline in
the case notes, so another examiner can rebuild it from the same image.

## MITRE ATT&CK for ICS mapping

The Sleuth Kit *investigates*. On a disk image it shows:

- **Evasion**: deleted tools, scripts and logs, still listed by `fls -d` or
  recovered by `tsk_recover`, which is the evidence of Indicator Removal on Host
  (T0872).
- **Lateral Movement**: tools copied onto the host from elsewhere, and in the
  timeline the moment they arrived (Lateral Tool Transfer, T0867).

The timeline also dates what other tools found: a project file changed outside
an engineering change, or an autostart entry written during the incident window.

## Quick start

```sh
# What the menu launcher runs
mmls -V
# An E01's format, size and the MD5 recorded when it was acquired
img_stat hmi01.E01
# A raw working copy of the E01; its md5sum must match that MD5
img_cat hmi01.E01 > hmi01.raw
# The partition table, with each partition's start sector
mmls hmi01.raw
# The file system of the partition that starts at sector 2048
fsstat -o 2048 hmi01.raw
# Every file and directory, with full paths (add -d for deleted entries only)
fls -r -p -o 2048 hmi01.raw
# Copy one file out by the inode number fls printed
icat -o 2048 hmi01.raw 1234 > hosts.copy
# Recover every file, allocated and deleted, into a folder
tsk_recover -e -o 2048 hmi01.raw recovered/
```

`-o` is the partition's start sector from `mmls`; leave it out for an image of a
single partition. Without `-e`, `tsk_recover` recovers only deleted files. `-i
list` and `-f list` show the image and file system types TSK accepts.

!!! warning "E01 images: work on a raw copy"

    The trixie build of TSK reads E01 images but ends with `Segmentation fault`
    as it closes one, on both architectures. In a terminal the output is all
    there; redirected into a file, the end of it can be lost. So run TSK on an
    E01 only to look, make a raw copy with `img_cat` once, check it with
    `md5sum` against the MD5 `img_stat` reports, hash it into `SHA256SUMS`, and
    run everything that writes a file on the raw copy.

## Output and evidence

TSK prints to the terminal; redirect everything into the case folder and hash
it. To image a disk first (the device name comes from `lsblk`):

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/images" "$CASE/analysis/tsk"
# A raw image; a block that cannot be read is written as zeros
sudo dd if=/dev/sdX of="$CASE/images/hmi01.raw" bs=4M conv=noerror,sync \
    status=progress
sha256sum "$CASE/images/hmi01.raw" >> "$CASE/SHA256SUMS"
```

A timeline of one partition, as CSV with ISO 8601 UTC times:

```sh
# Body file: one line per file with its four times
fls -r -m C: -o 2048 "$CASE/images/hmi01.raw" > "$CASE/analysis/tsk/hmi01.body"
# Sorted timeline, comma separated
mactime -b "$CASE/analysis/tsk/hmi01.body" -d -y \
    > "$CASE/analysis/tsk/hmi01-timeline.csv"
sha256sum "$CASE/analysis/tsk/hmi01.body" "$CASE/analysis/tsk/hmi01-timeline.csv" \
    >> "$CASE/SHA256SUMS"
```

`dd` with `conv=noerror,sync` replaces a whole block with zeros when any sector
in it cannot be read; on a failing disk, use a small block size such as
`bs=4096` so less is lost. `mactime` may print warnings about an old package
separator; they do not affect the output. Deleted entries show `(deleted)` after
the file name. More on the case folder in [evidence
handling](../../lifecycle/evidence-handling.md).

## Related tools

- [TestDisk and PhotoRec](testdisk-photorec.md): rebuild a lost partition table,
  or carve files the file system no longer lists.
- [SnapshOT field kit](fieldkit.md): what was running on the host, to compare
  with what is on its disk.
- [Autopsy](autopsy.md): the same engine with a GUI, keyword search and reports;
  not shipped on this image, used on the analysis workstation.
- [binwalk](../firmware/binwalk.md): for firmware images rather than disk
  images.

## Upstream documentation

- [The Sleuth Kit](https://www.sleuthkit.org/sleuthkit/): overview, the tools by
  layer and links to the documentation.
- Each tool prints its options when run without arguments, for example `fls` or
  `mmls`.
