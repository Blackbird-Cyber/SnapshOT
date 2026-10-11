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
`scripts/make-update-usb.sh /media/<user>/<stick> <package>...`. The mirror
holds `trixie main` from the release's snapshot pin only, with no security or
updates suite, and keeps only the packages explicitly asked for, without their
dependencies, so name every package the laptop is missing. One stick serves both
architectures, amd64 and arm64; apt on a laptop reads only its own
architecture's index. The script signs the mirror with the key the builder
names (or gpg's default key), publishes it to `snapshot-cache/` on the stick
and prints the key's fingerprint with the commands below.

On the laptop:

- no signing key ships with SnapshOT: the laptop is given the public half of the
  key that signed the stick, by hand, and not from the stick it checks;
- the mirror is trusted only through a `sources.list.d` entry pointing at the
  stick that trusts **only that key**, also added by hand;
- an unsigned mirror is never trusted: no `[trusted=yes]`.

```sh
# Once per laptop: the public key, handed over apart from the stick
sudo install -D -m 0644 snapshot-update.gpg /etc/apt/keyrings/snapshot-update.gpg
# A source for the mounted stick that trusts only that key
echo 'deb [signed-by=/etc/apt/keyrings/snapshot-update.gpg] file:/media/<user>/<label>/snapshot-cache trixie main' | sudo tee /etc/apt/sources.list.d/snapshot-update.list
# apt checks the stick's signature, then installs from it
sudo apt-get update
sudo apt-get install <package>
# Remove the source when done: apt-get update fails while the stick is gone
sudo rm /etc/apt/sources.list.d/snapshot-update.list
```

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
