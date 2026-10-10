# Updating SnapshOT in the field

Primary model: **re-image**. Build a new release ISO, wipe, reinstall. This also
clears prior-client data: the reset between engagements.

Secondary model: a signed offline apt mirror on USB for adding a package without
a full re-image:
```
scripts/make-update-usb.sh /media/usb <package>...
```
The mirror carries both image architectures, amd64 and arm64, so one stick
serves every SnapshOT laptop; apt on the laptop fetches only its own
architecture's index. Set `SNAPSHOT_UPDATE_ARCHES` to narrow it, for example
`SNAPSHOT_UPDATE_ARCHES=amd64` when no arm64 laptop is in the field, which
halves the download.

Laptops trust only the SnapshOT signing key. Configure a pinned
`sources.list.d` entry pointing at the USB cache; never trust an unsigned mirror.
