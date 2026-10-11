# Known issues

Problems that affect a published image or the current tree, kept here so the
README stays a description of the product. Each release's notes on GitHub repeat
the ones that apply to that release.

## v0.3.0-alpha (draft, not yet published)

- **Installer QA is not finished.** The installer configuration passes
  `scripts/check-installer.sh` and its new parts were tested one at a time
  during development, but an end-to-end install of the release build on VMware
  Fusion and on real hardware has not been run. Do not rely on a 0.3.0-alpha
  install for client work until it has.
- v0.3.0-alpha is built from main at [filled in after the release build]; every
  item under "Current tree" below that is not marked fixed applies to it.

Fixed in v0.3.0-alpha (each of these affects v0.2.1):

- **No Wi-Fi client.** v0.2.1 carries no `wpasupplicant` (NetworkManager only
  recommends it), so NetworkManager can neither scan for nor join a Wi-Fi
  network, nor do wired 802.1X. Ethernet and airodump-ng surveys work. Fixed in
  v0.3.0-alpha: `wpasupplicant` is in the desktop list, and NetworkManager's
  Wi-Fi switch ships off.
- **Installed systems do not boot with Secure Boot on.** The v0.2.1 live ISO
  boots through shim, but the image has neither `shim-signed` nor
  `grub-efi-<arch>-signed`, so the installer lays down an unsigned GRUB (also
  copied to `EFI/boot/bootx64.efi`). Turn Secure Boot off before installing
  v0.2.1. Fixed in v0.3.0-alpha
  ([offline-install.md](../offline-install.md#secure-boot)).
- **The passphrase prompt is invisible.** At the first boot of a v0.2.1
  install, the splash shows only the lockup while the initramfs waits for the
  disk passphrase. Fixed in v0.3.0-alpha (`snapshot-boot` 0.1.4 and 0.1.5): the
  prompt, a blinking caret, a hint line and one square per keystroke.
- **The install fails with 2 GiB of RAM.** The LUKS2 format runs the live
  session out of memory and takes the desktop down with it. Fixed in
  v0.3.0-alpha: the welcome page requires 3 GiB.
- **A login that already exists fails the install at its last step**, for
  example `operator`. Fixed in v0.3.0-alpha: the users page refuses it.
- **The installer names "SnapshOT 0.1"** on its partition and summary pages.
  Fixed in v0.3.0-alpha.

## v0.2.1 (pre-release, published 2026-10-10)

To be withdrawn when v0.3.0-alpha is published.

- **Installer QA is not finished.** The installer configuration passes
  `scripts/check-installer.sh` and the live session passed smoke checks in QEMU,
  but an end-to-end install on VMware Fusion has not been run on this build. Do
  not rely on a v0.2.1 install for an engagement until it has.
- v0.2.1 was built from 8a5ba28; every item under "Current tree" below applies
  to it too, and so does every item under "Fixed in v0.3.0-alpha" above.
- Fixed in v0.2.1: the brand images inside the withdrawn v0.2.0 and v0.1.0
  images (the icons, the boot splash lockup, the installer welcome image and the
  wiki favicon) carried embedded content-credential manifests. v0.2.1 was built
  from the clean tree, and the same four files inside both v0.2.1 images carry no
  embedded content-credential or EXIF chunks.

## Current tree

- **arm64 installs with Secure Boot on are untested.** The arm64 live ISO boots
  with Secure Boot enforced (QEMU, AAVMF with Microsoft's keys), and arm64
  installs get the same shim, signed GRUB and `grub-install` wrapper as amd64,
  but no arm64 install has been booted with Secure Boot on.
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
- **The offline update stick cannot be built from the v0.2.1 tree.** Its
  `scripts/make-update-usb.sh` publishes to a `file://` target, which aptly
  1.6.1 (trixie) rejects with "unknown published storage format: file". Fixed
  after v0.2.1: the script publishes through an aptly filesystem endpoint
  ([updates.md](../updates.md)). Verified in `debian:trixie` containers on amd64
  and arm64 with a few small packages, built into a directory and onto FAT32 and
  exFAT images: a clean trixie client with only the public key installed passed
  `apt-get update` with signature verification and installed from the `file:`
  source, and refused a wrong key and an edited `InRelease`, `Release`,
  `Packages` index or `.deb`. A full mirror of `trixie main` (154.5 GiB for both
  architectures) has not been run.
- **Field kit checks not covered by containers.** `scripts/check-fieldkit.sh` does
  not cover PowerShell 2.0 and `cmd.exe` themselves, real USB sticks (udev timing,
  `sdX`/`nvme`/`mmcblk` partition naming), or udisks on a desktop session. The
  manual QA checklist in [fieldkit.md](../fieldkit.md) covers them.
