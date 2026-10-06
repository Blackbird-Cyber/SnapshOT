---
title: Field updates
summary: The re-image model, and the signed offline USB mirror for the rare in-field package add.
---

SnapshOT is meant to be re-imaged, not updated in place. The detail is in the
repository's `docs/updates.md`; this is the operator's summary.

## Primary model: re-image

Build a new release ISO, wipe the laptop and reinstall. Re-imaging is also the
reset between engagements: it clears the previous client's data along with the
old image. One client per image is part of the security posture, so an update is
normally a rebuild, not a patch on a running system.

## Secondary model: a signed offline mirror

When a single package must be added in the field without a full re-image,
SnapshOT supports a **signed offline apt mirror on a USB stick**, built on a
networked Debian host with aptly by
`scripts/make-update-usb.sh /media/usb <package>...`. It is limited to the
release snapshot plus the packages explicitly asked for, and is published to
`snapshot-cache/` on the stick. As the script stands, it mirrors the amd64
architecture only.

On the laptop:

- the mirror is trusted only through a pinned `sources.list.d` entry pointing at
  the stick that trusts **only the SnapshOT signing key**;
- an unsigned mirror is never trusted.

This is the exception, not the routine. Because the image is never updated
online, and its browser never receives certificate, blocklist or security-list
updates (see the [browser](browser.md) page and the quiet posture), a laptop
that has drifted from its known state is re-imaged rather than nursed along.

## Related pages

- [Live session and install](live-and-install.md): building and installing a
  fresh image.
- [Build manifest](build-manifest.md): confirming exactly what an image carries
  before and after a change.
- [The vendor layer](vendor-layer.md): changing the vendored toolset means a
  rebuild.
