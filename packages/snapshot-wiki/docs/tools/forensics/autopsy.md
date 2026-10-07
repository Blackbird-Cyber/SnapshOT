---
title: Autopsy
summary: Graphical case building and evidence analysis on The Sleuth Kit; used on a separate analysis workstation, not on SnapshOT
folder: forensics
launchers: []
ships_as: vendor
package: autopsy
arch: [amd64]
status: not-shipped
wire: passive
phases:
  identification: On the analysis workstation after the hand-off, triage a disk image with hash sets, keyword search and the timeline around the first alert.
  eradication: On the analysis workstation, list every foothold an image shows (dropped tools, scripts, changed project files) so the clean-up misses none.
  lessons-learned: On the analysis workstation, build the case timeline, tag the evidence behind each finding and export the report.
csf: [detect, respond, identify]
attack_ics: [execution, persistence, evasion, lateral-movement]
attack_role: investigates
attack_techniques: [T0853, T0873, T0872, T0867]
upstream: https://sleuthkit.org/autopsy/docs/user-docs/latest/
---

<!-- snapshot:facts -->

## What it is

Autopsy is the graphical digital forensics platform built on The Sleuth Kit. An
examiner creates a case, adds data sources to it (disk images in raw, E01, VMDK
or VHD format, or folders of logical files) and runs ingest modules over them:
hash lookup, file type identification, keyword search over an index of every
file's text, carving of deleted files with PhotoRec, registry parsing with
RegRipper and more. The results appear as a tree of artefacts, a file browser
and a timeline, and the items the examiner tags go into a report. On an OT
engagement it puts the deleted files, unexpected programs and scripts and ICS
project files of an HMI or engineering workstation image into one searchable
case.

## Why it is not shipped

Autopsy is pinned in `vendor/sources.lock`, but since 2026-10-07 its stanza is
`enabled: false`, together with the Java runtime and the native Sleuth Kit
library SnapshOT built for it, and its menu launcher is gone. Autopsy is made
for Windows first, and its Linux build is a documented subset: upstream lists
Recent Activity as partial and LEAPP, plaso, OCR, YARA, HEIF and video
thumbnails as unsupported on Linux. Fitting it into an image that is offline,
read-only and quiet on the wire kept turning up one more assumption: a native
Sleuth Kit library that no Linux release ships, a specific Java version, OCR
language data its first start copies, a Java module its panels need, and an
update check. Rather than chase each of them in every release, SnapshOT keeps
the command-line forensics tools and leaves Autopsy to a machine built for it.
The stanza stays in the lock so its shape is recorded; `docs/vendoring.md`
("Out of scope and why") has the details, and the
[vendor layer](../../platform/vendor-layer.md) page explains how disabled tools
are handled.

## What to use instead

- [The Sleuth Kit](sleuthkit.md): the engine Autopsy is built on, on the
  command line and on both architectures: partitions, file systems, deleted
  entries, file extraction, and a timeline with `fls` and `mactime`.
- [TestDisk and PhotoRec](testdisk-photorec.md): partition recovery, and the
  carver Autopsy runs as an ingest module.
- [SnapshOT field kit](fieldkit.md): read-only live triage of the same hosts,
  imported into the case folder with hashes and a chain-of-custody log.
- **An analysis workstation, after the hand-off.** When a case needs Autopsy's
  keyword index, ingest modules and reports, the case folder goes to a separate
  analysis workstation with Autopsy's Windows build, installed there by the
  operator (SnapshOT does not redistribute it). The field kit page's
  [hand-off](fieldkit.md#hand-off-to-an-analysis-workstation) section covers
  the transfer, and [evidence handling](../../lifecycle/evidence-handling.md)
  the case folder and its hashes.

## Upstream documentation

- [Autopsy User Documentation](https://sleuthkit.org/autopsy/docs/user-docs/latest/):
  cases, data sources, every ingest module, the timeline and reports.
- [Autopsy](https://www.autopsy.com/): the project's home page, downloads and
  training.
