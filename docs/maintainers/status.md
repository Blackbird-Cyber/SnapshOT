# Status

Where the project stands, for maintainers. The README describes the current tree;
this page records how the published release and the local build artifacts differ
from it. Known problems are in [known-issues.md](known-issues.md).

## Release state

| | v0.1.0 (withdrawn) | v0.2.0 (withdrawn) | v0.2.1 (published pre-release) |
|---|---|---|---|
| Built from | 2fba3d1 (now 88ba816), published 2026-09-30 | 3a77bad (now 5150f10, see [history-rewrite.md](history-rewrite.md)), published 2026-10-10 | 8a5ba28, published 2026-10-10; the tag also carries the README release-table commit |
| Images | amd64 1,731,487,744 bytes (1.61 GiB), arm64 1,751,322,624 bytes (1.63 GiB) | amd64 1,879,412,736 bytes (1.75 GiB), arm64 1,837,701,120 bytes (1.71 GiB) | amd64 1,879,400,448 bytes (1.75 GiB), arm64 1,837,686,784 bytes (1.71 GiB), neither split |
| Withdrawn | 2026-10-10: release, assets and tag deleted | 2026-10-10: release, assets and tag deleted | |
| Verified | live boot | both images booted in QEMU to the live desktop with smoke checks; the installer was not run | both images booted in QEMU to the live desktop with smoke checks of the menu, `/etc/snapshot-release`, capture without sudo, the vendor layer, package versions, the wiki and the brand files (no embedded chunks); the installer was not run |
| Brand images | carry embedded content-credential manifests | carry embedded content-credential manifests | no embedded content-credential or EXIF chunks |
| Desktop | light Xfce desktop with the SnapshOT wallpaper and a SnapshOT menu with a category per tool group | SnapshOT-Dark theme, Papirus-Dark icons, one top panel, the Whisker menu with eight numbered folders | same as v0.2.0 |
| Installer | stops at the display-manager step; its encrypted layout does not boot | fixed (`calamares-settings-snapshot` 0.1.5, `snapshot-boot` 0.1.2); not run end to end on VMware Fusion | fixed (`calamares-settings-snapshot` 0.1.6, `snapshot-boot` 0.1.3); not yet run end to end on VMware Fusion |
| SnapshOT Wiki, field kit, Firefox ESR | not included | included (`snapshot-wiki` 0.1.5, `snapshot-fieldkit` 0.1.3) | included (`snapshot-wiki` 0.1.6, `snapshot-fieldkit` 0.1.3) |
| The Sleuth Kit, TestDisk/PhotoRec | not included | included | included |
| Vendor layer | not included | included: CPython 3.11.16, ics-python, plcscan, Redpoint NSE, and opcua-client on amd64 | same as v0.2.0 |
| Radio | ships HackRF and GNU Radio | receive-only: RTL-SDR, gqrx, airodump-ng | same as v0.2.0 |

- main is v0.2.1 plus whatever has merged since; the README describes main.
- v0.2.1 is the only published release. v0.2.0 and v0.1.0 were withdrawn on
  2026-10-10 when v0.2.1 was published, because their brand images still carried
  embedded content-credential manifests: their releases, assets and tags were
  deleted from GitHub. The v0.2.0 notes stay in
  [`docs/release-notes/v0.2.0.md`](../release-notes/v0.2.0.md).
- The ISOs in the repository root on the build Mac are the v0.2.1 images, and the
  `SHA256SUMS` beside them is the one published with the release. The build logs
  are `build/build-amd64.log` and `build/build-arm64.log`.
- `SNAPSHOT_VERSION` in `config/snapshot.env` is `0.2.1`; its notes are
  [`docs/release-notes/v0.2.1.md`](../release-notes/v0.2.1.md). Bump it before
  the next release build. `scripts/release.sh` refuses a tag other than
  `v$SNAPSHOT_VERSION`, uses the tag's notes file, refreshes the README's release
  table and badges, and stops so the change can be committed.

## Open tasks

1. VMware Fusion installer QA on v0.2.1: install end to end (LUKS2 root,
   unencrypted `/boot`), reboot, unlock, log in, and work through the QA
   checklist in [offline-install.md](../offline-install.md).
2. Promote the pre-release once that run passes:
   `gh release edit v0.2.1 --repo Blackbird-Cyber/SnapshOT --prerelease=false`,
   then change the README's release badge and release-table label from
   pre-release to release.
3. Field kit manual QA: a real USB stick and Windows XP, 7 and 10 VMs, using the
   checklist in [fieldkit.md](../fieldkit.md).
4. Fix the update stick: `scripts/make-update-usb.sh` publishes to
   `file://<stick>/snapshot-cache`, which aptly 1.6.1 (trixie) rejects ("unknown
   published storage format: file"). A fix needs a `FileSystemPublishEndpoints`
   entry in an aptly config and `filesystem:<name>:` as the target
   ([known-issues.md](known-issues.md)).
5. CI: `.github/workflows/checks.yml` (`reuse lint`, then `check-installer.sh`,
   `check-desktop.sh` and `check-wiki.sh` with `SNAPSHOT_CHECK_PLATFORM=linux/amd64`)
   passed on its first run, on the merge commit 2802faf (run 38019385569,
   2026-10-10 03:06 UTC). Add the workflow badge
   (`https://github.com/Blackbird-Cyber/SnapshOT/actions/workflows/checks.yml/badge.svg`)
   to the README when the repository goes public: GitHub's image proxy fetches
   badges without credentials, so a private repository's badge renders broken.
6. When the repository goes public: enable private vulnerability reporting
   (`gh api -X PUT repos/Blackbird-Cyber/SnapshOT/private-vulnerability-reporting`;
   GitHub offers it only on public repositories and the call returned 404 while
   the repository was private), upload `branding/splash/snapshot-splash-1920x1080.png`
   as the social preview (Settings > General), and check that GitHub reports the
   license as Apache License 2.0 once `LICENSE` is on main.

## Before going public

- The repository was recreated on 2026-10-10 from the rewritten history (see
  [history-rewrite.md](history-rewrite.md)): only `main` and the two release tags
  were pushed, and both releases were re-uploaded with their original notes and
  verified assets. Both releases and their tags were withdrawn later the same day,
  when v0.2.1 was published. The previous repository was renamed `SnapshOT-old`, stays
  private, and is to be deleted; nothing else needs to come over from it.

## Housekeeping

- The wiki still has British spellings in places (favourites, authorisation,
  coloured, organises, behaviour); house style is American.
- House style has no em-dashes. The only one left in the tree is in
  `scripts/check-wiki.sh`, on purpose: it is the character the wiki check looks for.

## Screenshots

`docs/images/desktop.png` (the Whisker menu on 01 Recon & Discovery) is from the
v0.2.0 arm64 build (3a77bad, now 5150f10), taken in QEMU on 2026-10-10; the v0.2.1
desktop is the same. `docs/images/wiki.png`
and `docs/images/wiki-graph.png` were taken from the October 6 arm64 build
(82115b8); the v0.2.0 wiki looks the same. Re-shoot them when the wiki's look
changes.
