---
title: TestDisk and PhotoRec
summary: Recover lost partitions with TestDisk and carve deleted files with PhotoRec, from disk images
folder: forensics
launchers: []
ships_as: apt
package: testdisk
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  identification: Carve deleted files out of an image when the adversary removed tools or logs, before the timeline is built.
  recovery: Rebuild a lost partition table or undelete project and configuration files on a copy of a damaged disk, so the engineer can restore from them.
  lessons-learned: Add the carved and undeleted files, with their hashes, to the evidence behind the incident narrative.
csf: [detect, recover, identify]
attack_ics: [evasion, inhibit-response-function]
attack_role: investigates
attack_techniques: [T0872, T0809]
upstream: https://www.cgsecurity.org/wiki/TestDisk
---

<!-- snapshot:facts -->

## What it is

TestDisk and PhotoRec are two data recovery tools from the same package, both
with a text-mode menu interface. **TestDisk** finds lost or deleted partitions by
scanning a disk or image for file system signatures, shows what it found, and
can rebuild the partition table and boot sectors; it can also list and copy out
deleted files on FAT, exFAT, NTFS and ext2 file systems. **PhotoRec** ignores the
file system altogether and carves files by their content signatures (documents,
archives, images, databases and many more), so it works on formatted or badly
damaged media. Both read raw devices and raw (dd) image files. Debian builds
them without EWF support (`photorec /version` shows `ewf lib: none`), so an E01
image is first turned into a raw one with `img_cat` from
[The Sleuth Kit](sleuthkit.md). The package also has `fidentify`, which names a
file's type the way PhotoRec does. There is no menu launcher: both run in a
terminal.

## Why it is on SnapshOT

An adversary who deletes tools and logs, or wipes a disk on the way out, leaves
evidence that the file system no longer lists. PhotoRec gets it back from an
image by content alone; TestDisk recovers the partitions and files when the
damage is to the structure rather than the data. For an OT site the second use
matters as much as the first: the project files, HMI configuration or recipe
data on a damaged engineering workstation may be the quickest way back to a
working process.

## On the wire

!!! danger "Writes: TestDisk can rewrite partition tables and boot sectors"

    Neither tool touches the network or the plant; the care needed is about
    disks, not packets. **PhotoRec is read-only**: it opens its source
    read-only and never writes to it. **TestDisk writes**: its **Write**
    command and its boot sector and MBR repairs change whatever it opened,
    which is why the pair carries the writes class.

    - **Run both on image copies.** Image the disk first, hash the image, and
      point TestDisk and PhotoRec at a copy of it, never at evidence or at an
      original disk.
    - **Repairing a client's disk is a recovery action**, done with the asset
      owner and the engineer for that machine present, on a disk already
      imaged and hashed, and recorded in the case notes.
    - **Raw devices need `sudo`.** Opening `/dev/sdX` directly needs root, which
      is one more reason to image the disk first and work on the file.
    - **Save to another disk.** PhotoRec's output goes to the case folder on the
      laptop, never to the medium being carved. Carved executables are evidence:
      never run them.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), when the
file listing of an image shows deleted entries or gaps where logs should be,
PhotoRec carves what remains from unallocated space. The file names are lost
(`f0000100.png` and so on), but the content and type are not, and the carved
files can be hashed, searched and compared with known tools.

### Recovery

During [recovery](../../lifecycle/phases/recovery.md), TestDisk rebuilds the
partition table of a damaged disk image so its file systems can be read again,
and its undelete function copies out deleted project, configuration and recipe
files. The engineer decides whether what was recovered is good enough to restore
from; the original disk is only repaired with the asset owner's agreement.

### Lessons Learned

For [lessons learned](../../lifecycle/phases/lessons-learned.md), carved and
undeleted files join the case evidence with their hashes and the log of the run
that produced them, so the report can show what the adversary removed and how it
was found.

## MITRE ATT&CK for ICS mapping

TestDisk and PhotoRec *investigate* what an adversary tried to remove:

- **Evasion**: tools, scripts and logs deleted to hide activity, carved back by
  PhotoRec or undeleted by TestDisk (Indicator Removal on Host, T0872).
- **Inhibit Response Function**: partitions, project files and backups destroyed
  so that recovery is slower, rebuilt or carved from an image of what is left
  (Data Destruction, T0809).

The tactic pages, [Evasion](../../lifecycle/attack-ics/evasion.md) and [Inhibit
Response Function](../../lifecycle/attack-ics/inhibit-response-function.md), list
the tools that see the same activity from other angles.

## Quick start

```sh
# An E01 image as a raw copy first: these builds do not read E01
img_cat hmi01.E01 > hmi01.raw
# The partitions TestDisk finds in an image, without changing anything
testdisk /list hmi01.raw
# TestDisk's menus on an image, logging to testdisk.log
testdisk /log hmi01.raw
# PhotoRec's menus on an image; carved files go to carved/photorec.1/
photorec /log /d carved/photorec hmi01.raw
# What kind of file each carved file is, by content
fidentify carved/photorec.1
# Version of TestDisk, for the case notes
testdisk /version
# Version of PhotoRec, for the case notes
photorec /version
```

`img_cat` comes from [The Sleuth Kit](sleuthkit.md), which ends with a
`Segmentation fault` as it closes an E01 on trixie: check the raw copy with
`md5sum` against the MD5 that `img_stat hmi01.E01` reports before using it.

In PhotoRec's menus, pick the partition (or the whole disk), the file system
family and whether to search free space only or the whole partition; **File
Opt** limits the file types. In TestDisk, **Analyse** and **Quick Search** find
partitions; **Advanced**, then **Undelete** (or **List** on ext2), shows the
deleted files to copy out.

## Output and evidence

PhotoRec writes carved files into numbered folders (`photorec.1`, `photorec.2`
and so on) next to the name given with `/d`, with a `report.xml` of what it
found. `/log` writes `photorec.log` or `testdisk.log` in the current directory,
so start both tools from the output folder:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/analysis/carved"
cd "$CASE/analysis/carved"
photorec /log /d "$CASE/analysis/carved/photorec" "$CASE/images/hmi01.raw"
# Hash every carved file and the log of the run (photorec.log is in this folder)
find "$CASE/analysis/carved" -type f -exec sha256sum {} + >> "$CASE/SHA256SUMS"
```

A raw copy made from an E01 with `img_cat` belongs in `images/` next to the E01,
with its own line in `SHA256SUMS`. Record the image, the options chosen in the
menus and the time of the run in the case notes; see [evidence
handling](../../lifecycle/evidence-handling.md).

## Related tools

- [The Sleuth Kit](sleuthkit.md): list the partitions and files first; carve
  only what the file system cannot give back.
- [binwalk](../firmware/binwalk.md): signature carving for firmware images
  rather than disks.
- [nwipe](../reporting/nwipe.md): the opposite job, for media leaving an
  engagement.

## Upstream documentation

- [TestDisk](https://www.cgsecurity.org/wiki/TestDisk): partition recovery,
  step-by-step walk-throughs and the undelete function.
- [PhotoRec](https://www.cgsecurity.org/wiki/PhotoRec): file carving, the menus
  and the supported file formats.
