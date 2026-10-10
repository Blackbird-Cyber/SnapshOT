# Status

Where the project stands, for maintainers. The README describes the current tree;
this page records how the published release and the local build artifacts differ
from it. Known problems are in [known-issues.md](known-issues.md).

## Release state

| | v0.1.0 (published pre-release) | main |
|---|---|---|
| Built from | 2fba3d1, published 2026-09-30 | the current tree |
| Desktop | light Xfce desktop with the SnapshOT wallpaper and a SnapshOT menu with a category per tool group | SnapshOT-Dark theme, Papirus-Dark icons, one top panel, the Whisker menu with eight numbered folders |
| Installer | stops at the display-manager step; its encrypted layout does not boot | fixed (`calamares-settings-snapshot` 0.1.3 and later, `snapshot-boot` 0.1.1 and later) |
| SnapshOT Wiki, field kit, Firefox ESR | not included | included |
| The Sleuth Kit, TestDisk/PhotoRec | not included | included |
| Vendor layer | not included | included when `scripts/vendor.py fetch` ran before the build |
| Radio | ships HackRF and GNU Radio | receive-only: RTL-SDR, gqrx, airodump-ng |

- The ISOs in the repository root on the build Mac are the October 6 builds from
  82115b8, not a release. The `SHA256SUMS` beside them is from October 1 and does
  not match them.
- `SNAPSHOT_VERSION` in `config/snapshot.env` is `0.2.0`, for the v0.2.0
  pre-release; its notes are [`docs/release-notes/v0.2.0.md`](../release-notes/v0.2.0.md).
  `scripts/release.sh` refuses a tag other than `v$SNAPSHOT_VERSION`, uses that
  notes file, refreshes the README's release table and badges, and stops so the
  change can be committed.
- The v0.1.0 release notes on GitHub start with a preview notice (live session
  only; no wiki, field kit or vendor layer), so the README can describe main
  without misleading anyone who downloads v0.1.0.

## Open tasks

1. Master build of both architectures from main
   (`SNAPSHOT_ARCH=arm64 docker/build-in-docker.sh`, then `docker/build-in-docker.sh`).
2. QEMU checks on both images: desktop and menu, the installer end to end with
   LUKS2, the wiki in Firefox ESR, the field kit tools.
3. Field kit manual QA: a real USB stick and Windows XP, 7 and 10 VMs, using the
   checklist in [fieldkit.md](../fieldkit.md).
4. The v0.2.0 pre-release: the version is bumped and the notes are written;
   build, check, then `scripts/release.sh v0.2.0 --prerelease`. Promote it to a
   full release after the VMware Fusion installer run.
5. Re-shoot the screenshots after the master build (see below).
6. CI: `.github/workflows/checks.yml` (`reuse lint`, then `check-installer.sh`,
   `check-desktop.sh` and `check-wiki.sh` with `SNAPSHOT_CHECK_PLATFORM=linux/amd64`)
   passed on its first run, on the merge commit 2802faf (run 38019385569,
   2026-10-10 03:06 UTC). Add the workflow badge
   (`https://github.com/Blackbird-Cyber/SnapshOT/actions/workflows/checks.yml/badge.svg`)
   to the README when the repository goes public: GitHub's image proxy fetches
   badges without credentials, so a private repository's badge renders broken.
7. When the repository goes public: enable private vulnerability reporting
   (`gh api -X PUT repos/Blackbird-Cyber/SnapshOT/private-vulnerability-reporting`;
   GitHub offers it only on public repositories and the call returned 404 while
   the repository was private), upload `branding/splash/snapshot-splash-1920x1080.png`
   as the social preview (Settings > General), and check that GitHub reports the
   license as Apache License 2.0 once `LICENSE` is on main.

## Housekeeping

- `scripts/make-update-usb.sh` publishes to `file://<stick>/snapshot-cache`,
  which aptly 1.6.1 (trixie) rejects ("unknown published storage format:
  file"), so the update stick cannot be built
  ([known-issues.md](known-issues.md)). A fix needs a `FileSystemPublishEndpoints`
  entry in an aptly config and `filesystem:<name>:` as the target.
- The wiki still has British spellings in places (favourites, authorisation,
  coloured, organises, behaviour); house style is American.
- 34 brand PNGs (`branding/` and their copies in `packages/`) carry C2PA manifests
  that name "Anthropic Files" as a possible creator. The SVGs had theirs stripped
  (`branding/README.md`). Decide whether to strip the PNGs too.
- House style has no em-dashes. The only one left in the tree is in
  `scripts/check-wiki.sh`, on purpose: it is the character the wiki check looks for.

## Screenshots

`docs/images/desktop.png`, `docs/images/wiki-graph.png` and `docs/images/wiki.png`
were taken from the October 6 arm64 build (82115b8). Re-shoot them after the next
master build.
