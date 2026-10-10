# Known issues

Problems that affect a published image or the current tree, kept here so the
README stays a description of the product. Each release's notes on GitHub repeat
the ones that apply to that release.

## v0.1.0 (published 2026-09-30)

- **v0.1.0 cannot install to disk.** Its installer stops at the display-manager
  step, and the encrypted layout it would have written does not boot: Calamares
  formats LUKS2 with Argon2id, which Debian's GRUB cannot unlock. Use v0.1.0 as a
  live system only. The fixes are on main (`calamares-settings-snapshot` 0.1.3
  and later, now 0.1.5; `snapshot-boot` 0.1.1 and later) and ship with the next
  image.
- An image only includes the vendor layer when `python3 scripts/vendor.py fetch`
  ran before the build; v0.1.0 has none of it.

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
- **Field kit checks not covered by containers.** `scripts/check-fieldkit.sh` does
  not cover PowerShell 2.0 and `cmd.exe` themselves, real USB sticks (udev timing,
  `sdX`/`nvme`/`mmcblk` partition naming), or udisks on a desktop session. The
  manual QA checklist in [fieldkit.md](../fieldkit.md) covers them.
