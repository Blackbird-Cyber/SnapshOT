---
title: Offline reference data
summary: Browse the offline reference data folder
folder: reference
launchers: [snapshot-reference-folder.desktop]
ships_as: snapshot
package: snapshot-menu
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Hold the fixed reference material the engagement relies on, assembled before the kit leaves for site.
  lessons-learned: Cite the versioned reference data that supported a finding, so the report is reproducible from the image.
csf: [identify]
attack_ics: []
attack_role: none
upstream: https://github.com/Blackbird-Cyber/SnapshOT
---

<!-- snapshot:facts -->

## What it is

The offline reference data folder is `/usr/share/snapshot/reference` on the
image, opened from **08 - Reference > Offline reference data** in the file
manager. It is where SnapshOT keeps fixed, versioned reference material that an
engagement can rely on with no network. The folder is not a Debian package: the
image build fills it, with a short `README.md` from the image's own files and the
[build manifest](build-manifest.md) (`BUILD-MANIFEST.txt`) written by a build
hook. The offline Exploit-DB data that
[searchsploit](exploitdb-searchsploit.md) would search belongs here too, but its
vendor-layer stanza is disabled, so this image does not carry it. The README
names the other references the folder is meant for, such as copies of ATT&CK for
ICS, CISA ICS advisories and vendor default-credential lists, added as fixed,
versioned data at build time.

## Why it is on SnapshOT

A field laptop is deliberately offline, so the references an engagement needs
must already be on the image. Keeping them in one versioned folder means the
responder reaches them the same way every time, and the [build
manifest](build-manifest.md) records exactly which data an image shipped. That
keeps a finding reproducible: the reference that supported it is pinned to the
image, not fetched from a site that may have changed.

## On the wire

!!! note "Passive: it never transmits"

    The reference folder is local files. Browsing it sends nothing on the
    network, and nothing in it reaches out: the data is fixed on the image and
    updated only by re-imaging. This is reference material, not a live service.

## PICERL mapping

### Preparation

The reference data is assembled into the image before the kit leaves for site,
as part of preparing a known, offline toolset. Check what the folder holds before
leaving: on this image that is the README and the build manifest, and any
advisory set or default-credential list the engagement needs has to be added to
the build or carried in with the engagement material. During the engagement it
is the place to confirm a fact without a network.

### Lessons Learned

When a finding rests on a reference, cite the versioned copy on the image rather
than a URL: the [build manifest](build-manifest.md) ties it to a specific image,
so the report can be reproduced from the same release.

## MITRE ATT&CK for ICS mapping

The reference folder has no relationship to an ATT&CK for ICS tactic. It is
static reference material, not a tool that acts on the network or analyzes
adversary activity. An offline ATT&CK for ICS copy, one of the references the
folder is meant to hold, would help map findings to tactics, but the folder
itself detects, investigates and resembles nothing. On this image, the
[ATT&CK for ICS pages](../../lifecycle/attack-ics/index.md) of this wiki carry
the tactics and technique ids offline.

## Quick start

The folder is opened from the menu; on the command line it is an ordinary
directory.

```sh
# What the menu launcher runs: open the folder in the file manager
exo-open --launch FileManager /usr/share/snapshot/reference
# List what the image shipped in the reference folder
ls -la /usr/share/snapshot/reference
# What the folder is for and how it is filled
cat /usr/share/snapshot/reference/README.md
# Read the build manifest
less /usr/share/snapshot/reference/BUILD-MANIFEST.txt
```

## Output and evidence

The folder is read-only reference data; it produces no output of its own. To
record which reference supported a finding, copy the relevant file into the case
folder and hash it, so the report carries the exact version used:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/reference"
cp /usr/share/snapshot/reference/BUILD-MANIFEST.txt "$CASE/reference/"
sha256sum "$CASE"/reference/* >> "$CASE/SHA256SUMS"
```

## Related tools

- [Build manifest](build-manifest.md): the record of exactly what the running
  image contains, which lives in this folder.
- [searchsploit (Exploit-DB offline)](exploitdb-searchsploit.md): would search
  offline Exploit-DB data kept here; not shipped in this image.

## Upstream documentation

- [SnapshOT](https://github.com/Blackbird-Cyber/SnapshOT): how the image is
  built and what the reference folder is for.
