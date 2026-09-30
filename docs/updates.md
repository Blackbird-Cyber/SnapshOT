# Updating SnapshOT in the field

Primary model: **re-image**. Build a new release ISO, wipe, reinstall. This also
clears prior-client data — the reset between engagements.

Secondary model: a signed offline apt mirror on USB for adding a package without
a full re-image:
```
scripts/make-update-usb.sh /media/usb <package>...
```
Laptops trust only the SnapshOT signing key. Configure a pinned
`sources.list.d` entry pointing at the USB cache; never trust an unsigned mirror.
