---
title: Build manifest
summary: View the image build manifest
folder: reference
launchers: [snapshot-build-manifest.desktop]
ships_as: snapshot
package: snapshot-menu
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Confirm which image, pin and tool versions the kit carries before an engagement.
  lessons-learned: Quote the exact image identity and package versions in the report, from the record on the laptop.
csf: [identify]
attack_ics: []
attack_role: none
upstream: https://github.com/Blackbird-Cyber/SnapshOT
---

<!-- snapshot:facts -->

## What it is

The build manifest is `/usr/share/snapshot/reference/BUILD-MANIFEST.txt`, opened
from **08 - Reference > Build manifest**. It is written at build time by the
image's manifest hook and records exactly what the running image contains: the
SnapshOT version, architecture and build commit, the Debian snapshot pin and
`SOURCE_DATE_EPOCH`, the kernel, every installed dpkg package with its version,
and every vendored runtime and tool under `/opt/snapshot`. The same identity
fields, without the package list, are also in `/etc/snapshot-release`, which the
build stamps into the image.

## Why it is on SnapshOT

This is where the package versions live, which is why the rest of the wiki never
prints a version number: a tool's exact version drifts with the Debian pin, so
the wiki points here instead of stating a figure that would go stale. For a
responder, the manifest answers "what, precisely, am I running?", the question a
report must answer to be reproducible and an engagement must answer to be
trusted. Because every SnapshOT build from the same pin resolves the same
packages, two images with the same manifest are the same image.

## On the wire

!!! note "Passive: it never transmits"

    The manifest is a text file generated at build time. Opening or reading it
    sends nothing on the network and reaches out to nothing. It is a record, not
    a live query, and it changes only when the image is rebuilt.

## PICERL mapping

### Preparation

Before the kit leaves for site, the manifest confirms which image is on the
laptop: the version, the Debian pin and the exact tool versions. An engagement
that must use a known, fixed toolset starts by checking this record.

### Lessons Learned

The report quotes the image identity and the relevant package versions from the
manifest, so a reader can tell precisely which build produced the evidence and,
if needed, reproduce it. The build commit and the pin make that unambiguous.

## MITRE ATT&CK for ICS mapping

The build manifest has no relationship to an ATT&CK for ICS tactic. It is a
record of the image's contents, not a tool that touches the network or analyses
adversary activity.

## Quick start

```sh
# What the menu launcher runs: open the manifest in the default text viewer
exo-open /usr/share/snapshot/reference/BUILD-MANIFEST.txt
# Read the whole manifest in the terminal
less /usr/share/snapshot/reference/BUILD-MANIFEST.txt
# The image identity line (version, architecture, build commit)
grep -E '^version:' /usr/share/snapshot/reference/BUILD-MANIFEST.txt
# The same identity fields that the build stamps into the image
cat /etc/snapshot-release
# Find the version of one installed package
grep '^tshark ' /usr/share/snapshot/reference/BUILD-MANIFEST.txt
```

## Output and evidence

The manifest is itself an evidence artefact: the record of the toolset behind
every finding. Copy it into the case folder and hash it so the report is tied to
a specific build:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/reference"
cp /usr/share/snapshot/reference/BUILD-MANIFEST.txt "$CASE/reference/"
cp /etc/snapshot-release "$CASE/reference/"
sha256sum "$CASE"/reference/* >> "$CASE/SHA256SUMS"
```

## Related tools

- [Offline reference data](reference-data.md): the folder the manifest lives in,
  alongside the other fixed references.
- [Platform: build manifest and release identity](../../platform/build-manifest.md):
  the operator-facing explanation of what the manifest proves.

## Upstream documentation

- [SnapshOT](https://github.com/Blackbird-Cyber/SnapshOT): reproducible builds,
  the snapshot pin and how the manifest is produced.
