---
title: Offline reference data
summary: The fixed, versioned reference material the image carries so an engagement needs no network.
---

A SnapshOT laptop is deliberately offline, so the references an engagement relies
on have to be on the image already. SnapshOT keeps them in one place:
`/usr/share/snapshot/reference`, opened from **08 - Reference > Offline reference
data**.

## What it holds

The folder carries fixed, versioned reference material. Today that is the
[build manifest](build-manifest.md) (`BUILD-MANIFEST.txt`), written at build
time, and a short `README.md` describing the folder. The offline Exploit-DB data
that [searchsploit](../tools/reference/exploitdb-searchsploit.md) would search
belongs in `exploitdb/` here, but its vendor stanza is disabled, so no image
carries it yet and its launcher stays hidden. The folder is the intended home
for other offline references too, such as a copy of ATT&CK for ICS, CISA ICS
advisories and vendor default-credential lists, added as fixed data at build
time rather than fetched on site.

## How to use it

Browse it from the menu, or read it as an ordinary directory
(`ls /usr/share/snapshot/reference`). When a reference supports a finding, copy
the exact file into the case folder and hash it, so the report cites the version
on the image rather than a URL that may have changed. Because the references are
fixed on the image and changed only by re-imaging, two laptops on the same
release carry the same references.

## Related pages

- [Offline reference data tool page](../tools/reference/reference-data.md): the
  folder in the tools section, with its PICERL and quick-start detail.
- [Build manifest](build-manifest.md): the record of exactly what the image
  contains, which lives in this folder.
- [The vendor layer](vendor-layer.md): how the Exploit-DB data would be added.
