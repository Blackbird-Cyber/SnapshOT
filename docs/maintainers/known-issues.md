# Known issues

Problems that affect a published image or the current tree, kept here so the
README stays a description of the product. Each release's notes on GitHub repeat
the ones that apply to that release.

## v0.2.1 (pre-release, published 2026-10-10)

- **Installer QA is not finished.** The installer configuration passes
  `scripts/check-installer.sh` and the live session passed smoke checks in QEMU,
  but an end-to-end install on VMware Fusion has not been run on this build. Do
  not rely on a v0.2.1 install for an engagement until it has; the release is
  promoted from pre-release after that run.
- v0.2.1 was built from 8a5ba28; every item under "Current tree" below applies
  to it too.
- **No Wi-Fi client.** v0.2.1 carries no `wpasupplicant` (NetworkManager only
  recommends it), so NetworkManager can neither scan for nor join a Wi-Fi
  network, nor do wired 802.1X. Ethernet and airodump-ng surveys work. Fixed
  after v0.2.1: `wpasupplicant` is in the desktop list, and NetworkManager's
  Wi-Fi switch ships off.
- **Installed systems do not boot with Secure Boot on.** The v0.2.1 live ISO
  boots through shim, but the image has neither `shim-signed` nor
  `grub-efi-<arch>-signed`, so the installer lays down an unsigned GRUB (also
  copied to `EFI/boot/bootx64.efi`). Turn Secure Boot off before installing
  v0.2.1. Fixed after v0.2.1 ([offline-install.md](../offline-install.md#secure-boot)).
- Fixed in v0.2.1: the brand images inside the withdrawn v0.2.0 and v0.1.0
  images (the icons, the boot splash lockup, the installer welcome image and the
  wiki favicon) carried embedded content-credential manifests. v0.2.1 was built
  from the clean tree, and the same four files inside both v0.2.1 images carry no
  embedded content-credential or EXIF chunks.

## Current tree

- **No hibernation.** Swap, when chosen, is a file inside the encrypted root, and
  the installer writes no resume parameter.
- **Firefox ESR gets no Remote Settings updates.** Firefox ESR receives no
  certificate revocation or intermediate-certificate updates, add-on blocklists or
  security-list updates: Remote Settings is held off so the browser never calls
  home, and the pinned ESR 140 has no policy for it, so its hosts resolve to
  loopback ([wiki.md](../wiki.md)). Re-image rather than update in place.
  - The pinned Firefox ESR 140 knows neither
    `DisableRemoteSettingsAndAcceptSecurityConsequences` nor
    `DisableRemoteImprovements`, so `snapshot-quiet.js` resolves
    `firefox.settings.services.mozilla.com`,
    `firefox-settings-attachments.cdn.mozilla.net` and
    `content-signature-2.cdn.mozilla.net` to loopback with
    `network.dns.localDomains` and switches off
    `security.remote_settings.crlite_filters.enabled` and
    `security.remote_settings.intermediates.enabled`.
  - The consequence: no certificate revocation (CRLite) or intermediate updates,
    no add-on blocklist updates and no updated search or security lists. When the
    pin moves to an ESR that knows those policies, add them to `policies.json`;
    `scripts/check-firefox-quiet.sh` fails on any policy the pinned Firefox does
    not know.
- **Field kit on bare Windows XP.** The prepared stick is exFAT by default, which
  Windows XP reads only with KB955704. For a bare XP host, prepare the stick with
  `snapshot-fieldkit-prep --fat32`, which brings FAT32's 4 GiB file limit
  ([fieldkit.md](../fieldkit.md)).
- **The offline update stick cannot be built.** `scripts/make-update-usb.sh`
  publishes to a `file://` target, which aptly 1.6.1 (trixie) rejects with
  "unknown published storage format: file". Re-image instead
  ([updates.md](../updates.md)).
- **Field kit checks not covered by containers.** `scripts/check-fieldkit.sh` does
  not cover PowerShell 2.0 and `cmd.exe` themselves, real USB sticks (udev timing,
  `sdX`/`nvme`/`mmcblk` partition naming), or udisks on a desktop session. The
  manual QA checklist in [fieldkit.md](../fieldkit.md) covers them.
