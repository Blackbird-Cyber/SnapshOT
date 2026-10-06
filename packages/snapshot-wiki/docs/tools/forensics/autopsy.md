---
title: Autopsy
summary: Case building and evidence analysis on The Sleuth Kit (amd64 only)
folder: forensics
launchers: [snapshot-autopsy.desktop]
ships_as: vendor
package: autopsy
arch: [amd64]
status: shipped
wire: passive
phases:
  identification: Triage a disk image of a suspect HMI or engineering workstation with hash sets, keyword search and the timeline around the first alert.
  eradication: List every foothold the image shows (dropped tools, scripts, changed project files) so the clean-up misses none.
  lessons-learned: Build the case timeline, tag the evidence behind each finding and export the report.
csf: [detect, respond, identify]
attack_ics: [execution, persistence, evasion, lateral-movement]
attack_role: investigates
attack_techniques: [T0853, T0873, T0872, T0867]
upstream: https://sleuthkit.org/autopsy/docs/user-docs/latest/
---

<!-- snapshot:facts -->

## What it is

Autopsy is the graphical digital forensics platform built on The Sleuth Kit. You
create a case, add data sources to it (disk images in raw, E01, VMDK or VHD
format, or folders of logical files) and run ingest modules over them: hashing
and hash-set lookup, file type identification, extension mismatch detection,
embedded file extraction, keyword search over an index of every file's text,
carving of deleted files with PhotoRec, and registry parsing with RegRipper. The
results appear as a tree of artefacts, a file browser and a timeline; items you
tag go into the report. A case is a folder on disk that can be closed and
reopened.

## Why it is on SnapshOT

The [field kit](fieldkit.md) records what was running on a host; Autopsy reads
what is on its disk. When an image of an HMI or engineering workstation is
available (a virtual machine's disk file, a backup image, or a disk the site has
taken out of service), Autopsy puts deleted files, unexpected programs and
scripts, ICS project files and their times into one searchable case, with the
evidence for each finding one click away.

It is part of the [vendor layer](../../platform/vendor-layer.md): installed under
`/opt/snapshot/autopsy` with its own Temurin Java runtime and a `libtsk_jni` that
SnapshOT builds from The Sleuth Kit. It is present only on images built with the
vendor layer, that is when `vendor.py fetch` ran before the build; v0.1.0 has
none of it, and the [build manifest](../reference/build-manifest.md) of the
running image says whether it is there. It runs on **amd64 only**: its release
ships JavaFX and other native libraries for x86-64 Linux, and upstream does not
support arm64 Linux; the launcher ships on both images and is hidden on arm64
(see [architectures](../../platform/architectures.md)). Give it memory: in a VM,
8 GB or more.

### What the Linux build can and cannot do

| Works | Partial or missing |
|---|---|
| Cases, disk images (raw, E01, AFF, VMDK, VHD) and logical files | Recent Activity is partial on Linux (upstream) |
| Hash lookup, file type, extension mismatch, embedded files | LEAPP (mobile), plaso, OCR, YARA and HEIF are unsupported on Linux (upstream) |
| Keyword search through its embedded Solr server | Video thumbnails are unsupported on Linux (upstream) |
| PhotoRec carving, using the system `photorec` from [testdisk](testdisk-photorec.md) | SnapshOT prunes the release's Windows and macOS binaries, plaso, Volatility, the Tesseract OCR engine, 7-Zip and LEAPP among them |
| RegRipper, run with perl | |
| Timeline, tagging, reports; media played through the system GStreamer | |

## On the wire

!!! note "Passive: it never transmits"

    Autopsy works on images and files on the laptop; it never connects to a
    device on the plant network.

    - **Never analyse an original.** Image the disk first, hash the image, and
      add a verified copy to the case. Autopsy reads its data sources without
      changing them, but the original stays sealed for the chain of custody.
    - **Keep evidence on the laptop.** Do not enable any module or option that
      sends hashes or files to an online lookup service: the client's data does
      not leave the case folder.
    - **Its Solr server is local.** Keyword search runs an embedded Solr process
      on the laptop, which keeps its pid file and logs under `~/.autopsy/dev`.
    - **Ingest is heavy.** It takes CPU, memory and disk for a long time; do not
      run it on the laptop that is also capturing a SPAN port, where packets
      could be dropped.
    - **Removing a disk from a running HMI or controller is not your call**: it is
      the process owner's decision, made when containment or eradication is
      planned.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), Autopsy
triages an image fast: hits in the hash sets you import for known tools, keyword
hits for the indicators already found in captures (an IP address, a file name, a
domain), and the timeline around the first alarm or operator report. Set the
data source's time zone to that of the original host so times line up with the
plant's logs.

### Eradication

Before a host is cleaned or rebuilt during
[eradication](../../lifecycle/phases/eradication.md), the case lists every
foothold the image shows: dropped executables and scripts, files that arrived
with them, autostart entries from the registry, and project files changed outside
an engineering change. The clean-up plan covers each one, and an image of the
rebuilt host can be checked against the same list.

### Lessons Learned

For [lessons learned](../../lifecycle/phases/lessons-learned.md), the timeline
and the tagged items become the incident narrative: when the first tool arrived,
what ran, what was deleted. Tag each item that backs a finding, add a comment,
and generate the report for the appendix; the
[reporting handover](../../lifecycle/playbooks/reporting-handover.md) playbook
covers the rest.

## MITRE ATT&CK for ICS mapping

Autopsy *investigates*: it explains, from a disk image, what an adversary did on
a host.

- **Execution**: scripts and executables that do not belong, found by type,
  hash and location, and the times they were created and run (Scripting, T0853).
- **Persistence**: ICS project files whose times or hashes differ from the
  engineer's known-good copy (Project File Infection, T0873); autostart entries
  in the registry hives RegRipper parses.
- **Evasion**: deleted tools and logs recovered from the file system or carved
  from unallocated space (Indicator Removal on Host, T0872).
- **Lateral Movement**: tools copied onto the host from elsewhere, and when they
  arrived (Lateral Tool Transfer, T0867).

The tactic pages, for example [Evasion](../../lifecycle/attack-ics/evasion.md)
and [Persistence](../../lifecycle/attack-ics/persistence.md), list the other
tools that see the same activity.

## Quick start

```sh
# What the menu launcher runs
/opt/snapshot/autopsy/bin/autopsy
# Whether this image has the vendor layer and Autopsy in it
grep -i autopsy /usr/share/snapshot/reference/BUILD-MANIFEST.txt
# Autopsy's cases go under analysis/ in the case folder
mkdir -p ~/cases/site-a/analysis/autopsy
# Hash the image before adding it, and record the value
sha256sum ~/cases/site-a/images/hmi01.E01 | tee -a ~/cases/site-a/SHA256SUMS
# Check that the image opens: its format, size and recorded MD5
img_stat ~/cases/site-a/images/hmi01.E01
```

`img_stat` is the [Sleuth Kit](sleuthkit.md) command-line tool; on an E01 it
prints its report and then `Segmentation fault` as it closes the image, a fault
in the trixie build that does not touch the image.

Then, in Autopsy (the labels are those of the upstream 4.23 user guide):

1. **New Case**, on the welcome screen: the case name,
   `~/cases/site-a/analysis/autopsy` as the base directory, then the case
   number and examiner.
2. **Add Data Source**: let Autopsy generate a host from the data source name,
   choose **Disk Image or VM File**, pick the image and set the time zone of
   the original host (FAT file systems record local times). Choose **Logical
   Files** instead for a folder, such as an imported field kit collection.
3. **Ingest modules**: start with hash lookup, file type identification,
   extension mismatch, embedded files, keyword search and Recent Activity; add
   the PhotoRec carver when deleted files matter. Ingest runs in the
   background, and results appear in the tree as they are found.
4. **Review**: the tree on the left holds the data sources, the views by file
   type and date, and the results of each ingest module; the **Timeline**
   (Tools menu or toolbar) puts file and artifact times in order.
5. **Tag**: right-click each item that supports a finding and add a file or
   result tag (**Bookmark**, or **Notable item**); Ctrl+B bookmarks the
   selected file directly.
6. **Generate Report** (toolbar): choose **HTML Report** and the tagged
   results only, so the report holds exactly the items the findings cite. It
   is written to the case's `Reports` folder.

## Output and evidence

Everything Autopsy produces lives in the case folder: the case file
(`<case>.aut`), its database, the keyword index, exported and carved files, and
the generated reports in `Reports/`. Autopsy never writes to the data sources.
Close the case before copying or archiving it, then hash the reports:

```sh
CASE=~/cases/site-a
# Hash every generated report into the case's hash list
find "$CASE/analysis/autopsy" -path '*/Reports/*' -type f \
    -exec sha256sum {} + >> "$CASE/SHA256SUMS"
```

Record in the case notes which ingest modules ran and on which data source:
another examiner must be able to reproduce the result. See [evidence
handling](../../lifecycle/evidence-handling.md).

## Related tools

- [The Sleuth Kit](sleuthkit.md): the same engine on the command line, on both
  architectures; the quick way to look into an image on arm64.
- [TestDisk and PhotoRec](testdisk-photorec.md): partition recovery and the
  carver Autopsy calls.
- [SnapshOT field kit](fieldkit.md): live triage data from the same hosts, which
  Autopsy can search as logical files.
- [CherryTree](../reporting/cherrytree.md) and
  [LibreOffice](../reporting/libreoffice.md): notes and the report the findings
  go into.

## Upstream documentation

- [Autopsy User Documentation](https://sleuthkit.org/autopsy/docs/user-docs/latest/):
  cases, data sources, every ingest module, the timeline and reports.
- [Autopsy](https://www.autopsy.com/): the project's home page and training.
