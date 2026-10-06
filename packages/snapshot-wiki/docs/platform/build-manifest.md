---
title: Build manifest and release identity
summary: Where SnapshOT records exactly what an image contains, and why the wiki never prints a version number.
---

Every SnapshOT image records where it came from and what is in it, so a finding
can be reproduced and an engagement's toolset can be trusted. Two files hold
that record.

## The two files

- **`/usr/share/snapshot/reference/BUILD-MANIFEST.txt`** is the full record:
  SnapshOT version, architecture and build commit, the Debian snapshot pin and
  `SOURCE_DATE_EPOCH`, the kernel, every installed package with its version, and
  every vendored runtime and tool under `/opt/snapshot`. It is written at build
  time by the image's manifest hook and opened from **08 - Reference > Build
  manifest**.
- **`/etc/snapshot-release`** carries the same identity fields (version,
  architecture, Debian pin, `SOURCE_DATE_EPOCH`, build commit) without the
  package list, stamped into the image by the build.

## Why the wiki has no version numbers

This is where the package versions live, and that is deliberate: a tool's exact
version drifts with the Debian pin, so the rest of the wiki points here instead
of printing a number that would go stale. To find the version of any tool on the
running image, read the manifest: each package is a line of its name and
version, so `grep '^tshark ' /usr/share/snapshot/reference/BUILD-MANIFEST.txt`
prints tshark's. Vendored tools follow in their own section, one block per
`MANIFEST`.

## Why it matters on an engagement

Because every build from the same pin resolves the same packages, two images with
the same manifest are the same image. The report quotes the image identity and
the relevant versions from the manifest, so a reader knows precisely which build
produced the evidence. Copy `BUILD-MANIFEST.txt` and `/etc/snapshot-release` into
the case folder and hash them to tie the engagement to a specific image.

## Related pages

- [Build manifest tool page](../tools/reference/build-manifest.md): the manifest
  in the tools section, with quick-start commands.
- [Offline reference data](reference-data.md): the folder the manifest lives in.
- [The vendor layer](vendor-layer.md): the vendored tools the manifest records.
