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
`scripts/make-update-usb.sh /media/usb <package>...`. The mirror holds `trixie
main` from the release's snapshot pin only, with no security or updates suite,
and keeps only the packages explicitly asked for, without their dependencies,
so name every package the laptop is missing. One stick serves both
architectures, amd64 and arm64; apt on a laptop reads only its own
architecture's index. The script signs the mirror with the key the builder
names (or aptly's default key) and publishes it to `snapshot-cache/` on the
stick.

On the laptop:

- no signing key ships with SnapshOT: the laptop is given the public half of the
  key that signed the stick, by hand;
- the mirror is trusted only through a pinned `sources.list.d` entry pointing at
  the stick that trusts **only that key**, also added by hand;
- an unsigned mirror is never trusted.

In this release the script stops at its last step: the aptly in trixie rejects
its `file://` publish target. Until that is fixed, re-image instead.

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
