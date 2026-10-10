# Updating SnapshOT in the field

Primary model: **re-image**. Build a new release ISO, wipe, reinstall. This also
clears prior-client data: the reset between engagements.

Secondary model: a signed offline apt mirror on USB for adding a package without
a full re-image, built on a networked Debian host with aptly:
```
scripts/make-update-usb.sh /media/usb <package>...
```
What the script does today:

- It mirrors `trixie main` from the snapshot pin in `config/snapshot.env` and
  nothing else: no `trixie-security` or `trixie-updates` suite and no other
  component. aptly downloads all of `main` for each architecture before the
  filter, so the first run is a large download.
- It keeps only the named packages. The aptly filter runs without
  `-with-deps`, so a package whose dependencies are not already on the laptop
  needs them named too. With no package named, it keeps the whole mirror.
- The mirror carries both image architectures, amd64 and arm64, so one stick
  serves every SnapshOT laptop; apt on the laptop fetches only its own
  architecture's index. Set `SNAPSHOT_UPDATE_ARCHES` to narrow it, for example
  `SNAPSHOT_UPDATE_ARCHES=amd64` when no arm64 laptop is in the field, which
  halves the download.
- It signs the published repository with the key named in `SNAPSHOT_GPG_KEY`,
  or with aptly's default key when that is unset, and publishes it to
  `snapshot-cache/` on the stick.

No signing key ships in the tree or on the image. Before a laptop uses the
stick, give it the public half of that key and a pinned `sources.list.d` entry
for the stick that trusts only that key (`signed-by=`). Both are done by hand;
never trust an unsigned mirror.

Known issue: the publish step fails with the aptly in trixie (1.6.1), which
rejects the script's `file://` target with "unknown published storage format:
file". Until the script is fixed, re-image instead.
