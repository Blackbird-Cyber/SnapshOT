# Status

Where the project stands, for maintainers. The README describes the current tree;
this page records how the published release and the local build artifacts differ
from it. Known problems are in [known-issues.md](known-issues.md).

## Release state

| | v0.1.0 (withdrawn) | v0.2.0 (withdrawn) | v0.2.1 (published pre-release) | v0.3.0-alpha (draft, not yet published) |
|---|---|---|---|---|
| Built from | 2fba3d1 (now 88ba816), published 2026-09-30 | 3a77bad (now 5150f10, see [history-rewrite.md](history-rewrite.md)), published 2026-10-10 | 8a5ba28, published 2026-10-10; the tag also carries the README release-table commit | 26cd8d7, built 2026-10-12 (UTC), after the first build (63e1680, 2026-10-11) showed the arm64 passphrase prompt on the serial port only; staged as a draft of the pre-release "SnapshOT 0.3.0 alpha" that points at the README release-table commit |
| Images | amd64 1,731,487,744 bytes (1.61 GiB), arm64 1,751,322,624 bytes (1.63 GiB) | amd64 1,879,412,736 bytes (1.75 GiB), arm64 1,837,701,120 bytes (1.71 GiB) | amd64 1,879,400,448 bytes (1.75 GiB), arm64 1,837,686,784 bytes (1.71 GiB), neither split | amd64 1,887,596,544 bytes (1.76 GiB), arm64 1,845,569,536 bytes (1.72 GiB), neither split |
| Withdrawn | 2026-10-10: release, assets and tag deleted | 2026-10-10: release, assets and tag deleted | to be withdrawn when v0.3.0-alpha is published: release made a hidden draft, tag removed | |
| Verified | live boot | both images booted in QEMU to the live desktop with smoke checks; the installer was not run | both images booted in QEMU to the live desktop with smoke checks of the menu, `/etc/snapshot-release`, capture without sudo, the vendor layer, package versions, the wiki and the brand files (no embedded chunks); the installer was not run | QEMU: both live ISOs with smoke checks of `/etc/snapshot-release`, the Wi-Fi switch, capture without sudo, the vendor layer and the package list (no Autopsy; the menu, the wiki and `about:policies` were checked on the 63e1680 build); arm64 without Secure Boot on the `virt` machine with its serial port: a full install (Erase disk, Encrypt system) that restarted on its own, then the splash asked for the passphrase on screen with no GRUB edit, keyboard unlock and login, `plymouth.ignore-serial-consoles` on the command line, checklist items 1 to 10, 12 and 13, and the serial-console unlock with the word removed at GRUB; amd64 with Secure Boot enforced (OVMF, Microsoft's keys): `operator` refused, a full install that restarted on its own, then the installed system booted from a fresh variable store (removable path) and from the `SnapshOT` entry, splash prompt, unlock and login, no arm64 parameter, checklist items 1 to 10 and 12 to 14; not run on VMware Fusion, Parallels, UTM or real hardware |
| Brand images | carry embedded content-credential manifests | carry embedded content-credential manifests | no embedded content-credential or EXIF chunks | the same files as v0.2.1 |
| Desktop | light Xfce desktop with the SnapshOT wallpaper and a SnapshOT menu with a category per tool group | SnapshOT-Dark theme, Papirus-Dark icons, one top panel, the Whisker menu with eight numbered folders | same as v0.2.0 | same as v0.2.0 |
| Installer | stops at the display-manager step; its encrypted layout does not boot | fixed (`calamares-settings-snapshot` 0.1.5, `snapshot-boot` 0.1.2); not run end to end on VMware Fusion | fixed (`calamares-settings-snapshot` 0.1.6, `snapshot-boot` 0.1.3); not yet run end to end on VMware Fusion | `calamares-settings-snapshot` 0.1.11, `snapshot-boot` 0.1.7: Secure Boot installs (shim, signed GRUB, removable path), 3 GiB RAM check, existing logins refused, automatic restart, visible passphrase prompt, on arm64 also with a serial console (`plymouth.ignore-serial-consoles`); not yet run end to end on VMware Fusion |
| SnapshOT Wiki, field kit, Firefox ESR | not included | included (`snapshot-wiki` 0.1.5, `snapshot-fieldkit` 0.1.3) | included (`snapshot-wiki` 0.1.6, `snapshot-fieldkit` 0.1.3) | included (`snapshot-wiki` 0.1.10, `snapshot-fieldkit` 0.1.4) |
| The Sleuth Kit, TestDisk/PhotoRec | not included | included | included | included |
| Vendor layer | not included | included: CPython 3.11.16, ics-python, plcscan, Redpoint NSE, and opcua-client on amd64 | same as v0.2.0 | same as v0.2.0 |
| Radio | ships HackRF and GNU Radio | receive-only: RTL-SDR, gqrx, airodump-ng | same as v0.2.0 | same as v0.2.0 |
| Wi-Fi client, Secure Boot | not recorded | no `wpasupplicant`; Secure Boot for the live ISO only | same as v0.2.0 | `wpasupplicant` with NetworkManager's Wi-Fi switch off; Secure Boot for the live ISO and installed systems (arm64 installs untested with it on) |

- main is v0.3.0-alpha: `SNAPSHOT_VERSION` in `config/snapshot.env` is
  `0.3.0-alpha`, both images were built from 26cd8d7 on 2026-10-12 (UTC), and
  [`docs/release-notes/v0.3.0-alpha.md`](../release-notes/v0.3.0-alpha.md)
  carries the build commit, the verification and the image sizes and SHA-256.
  The README describes main; `scripts/release.sh` rewrites its release table
  for v0.3.0-alpha when the draft is staged.
- v0.2.1 is the only published release. When v0.3.0-alpha is published, v0.2.1
  is withdrawn: its release becomes a hidden draft and its tag is removed.
  v0.2.0 and v0.1.0 were withdrawn on 2026-10-10 when v0.2.1 was published,
  because their brand images still carried embedded content-credential
  manifests: their releases, assets and tags were deleted from GitHub. The
  v0.2.0 and v0.2.1 notes stay in [`docs/release-notes/`](../release-notes/).
- The ISOs in the repository root on the build Mac are the v0.3.0-alpha images,
  and the `SHA256SUMS` beside them is the one uploaded to the draft. The build
  logs are `build/build-amd64.log` and `build/build-arm64.log`.
- `scripts/release.sh` refuses a tag other than `v$SNAPSHOT_VERSION`, uses the
  tag's notes file, refreshes the README's release table and badges, and stops
  so the change can be committed. With `--draft` it stops before publishing and
  pushes no tag ([build.md](../build.md#releasing)).

## Open tasks

Done for v0.3.0-alpha: the version and the README's alpha notice, the release
notes, `release.sh --draft`, the builder digest checked (a trixie-slim index for
amd64 and arm64), and the hygiene sweep for going public: gitleaks and
trufflehog found no secrets in the history or the tree, `.mailmap` (the last
copy of the work mailbox in the tree) is gone, the wiki, the field kit texts and
`docs/` use American spelling, the installer no longer says "SnapshOT 0.1", and
`SECURITY.md` names GitHub as the only contact and says which releases get fixes.
The update stick is fixed (item 7).

1. Merge `release/v0.3.0-alpha-prep`: done (63e1680).
2. Build both images from main, fill in the release notes and the table above,
   and stage the release for review with
   `scripts/release.sh v0.3.0-alpha --prerelease --draft`: built from 63e1680
   and verified in QEMU on 2026-10-11, then staged as a draft; rebuilt from
   26cd8d7 with the arm64 prompt fix (item 10), verified in QEMU on 2026-10-12
   (the table above and the release notes), and the draft's assets replaced.
3. VMware Fusion installer QA on the v0.3.0-alpha build, and an install on real
   hardware: install end to end (LUKS2 root, unencrypted `/boot`), reboot,
   unlock, log in, and work through the QA checklist in
   [offline-install.md](../offline-install.md), including Secure Boot (item 14),
   also on arm64 where the hypervisor offers it, and on UTM and Parallels for
   arm64 (the splash prompt on screen, item 4).
4. After the review, publish: `scripts/release.sh v0.3.0-alpha --prerelease`.
   Then withdraw v0.2.1: `gh release edit v0.2.1 --repo Blackbird-Cyber/SnapshOT
   --draft=true`, and delete its tag on GitHub and locally.
5. Promotion, once the Fusion run passes: either
   `gh release edit v0.3.0-alpha --repo Blackbird-Cyber/SnapshOT --prerelease=false`
   with the README's release badge and release-table label changed from
   pre-release to release, or a release without the alpha suffix; the owner
   decides.
6. Field kit manual QA: a real USB stick and Windows XP, 7 and 10 VMs, using the
   checklist in [fieldkit.md](../fieldkit.md).
7. Update stick: done, merged to main in 5d092bc. `scripts/make-update-usb.sh`
   published to
   `file://<stick>/snapshot-cache`, which aptly 1.6.1 (trixie) rejects ("unknown
   published storage format: file"). It now writes its own aptly config with a
   `FileSystemPublishEndpoints` entry and publishes to `filesystem:<name>:`
   ([updates.md](../updates.md)). A full mirror of `trixie main` (154.5 GiB)
   has not been run.
8. CI: `.github/workflows/checks.yml` (`reuse lint`, then `check-installer.sh`,
   `check-desktop.sh` and `check-wiki.sh` with `SNAPSHOT_CHECK_PLATFORM=linux/amd64`)
   passed on its first run, on the merge commit 2802faf (run 38019385569,
   2026-10-10 03:06 UTC). Add the workflow badge
   (`https://github.com/Blackbird-Cyber/SnapshOT/actions/workflows/checks.yml/badge.svg`)
   to the README when the repository goes public: GitHub's image proxy fetches
   badges without credentials, so a private repository's badge renders broken.
9. When the repository goes public: make it public, enable private vulnerability
   reporting
   (`gh api -X PUT repos/Blackbird-Cyber/SnapshOT/private-vulnerability-reporting`;
   GitHub offers it only on public repositories and the call returned 404 while
   the repository was private), add the CI badge (item 8), upload
   `branding/splash/snapshot-splash-1920x1080.png` as the social preview
   (Settings > General), and check that GitHub reports the license as Apache
   License 2.0. `SECURITY.md`, `CONTRIBUTING.md`, the code of conduct and the
   issue forms already point at private vulnerability reporting.
10. arm64 passphrase prompt on QEMU: done. On QEMU's arm64 `virt` machine the
    kernel console is the serial port, so Plymouth asked for the disk passphrase
    only there and the screen stayed black. `snapshot-boot` 0.1.7 (e4f390f)
    ships `/etc/default/grub.d/61-snapshot-arm64-console.cfg`, which adds
    `plymouth.ignore-serial-consoles` to `GRUB_CMDLINE_LINUX_DEFAULT` on arm64
    only; `scripts/check-installer.sh` checks both architectures, and the 26cd8d7
    build was verified in QEMU (release notes). UTM, Parallels and VMware Fusion
    are still to be checked (item 3). The arm64 live ISO keeps its boot entries,
    so its boot shows a black screen until the desktop on such firmware
    ([known-issues.md](known-issues.md)).

## Before going public

- The repository was recreated on 2026-10-10 from the rewritten history (see
  [history-rewrite.md](history-rewrite.md)): only `main` and the two release tags
  were pushed, and both releases were re-uploaded with their original notes and
  verified assets. Both releases and their tags were withdrawn later the same day,
  when v0.2.1 was published. The previous repository was renamed `SnapshOT-old`,
  stays private, and is deleted by the owner; nothing else needs to come over
  from it.
- The work mailbox that GitHub web-editor commits once carried is still in the
  history, in the `.mailmap` added on 2026-10-10 (d56ce66) and removed for
  v0.3.0-alpha; no commit carries it as an author or committer. Only another
  history rewrite would remove it; the secrets scans found nothing else.

## Housekeeping

- The wiki, the field kit texts and `docs/` use American spelling (snapshot-wiki
  0.1.10, snapshot-fieldkit 0.1.4). British forms remain only where they are not
  prose: code identifiers (the Plymouth script's `CentredText`), comments in
  scripts, the theme's upstream notes, TestDisk's own "Analyse" menu entry and
  historical changelog entries.
- House style has no em-dashes. The only one left in the tree is in
  `scripts/check-wiki.sh`, on purpose: it is the character the wiki check looks for.

## Screenshots

`docs/images/desktop.png` (the Whisker menu on 01 Recon & Discovery) is from the
v0.2.0 arm64 build (3a77bad, now 5150f10), taken in QEMU on 2026-10-10; the v0.2.1
and v0.3.0-alpha desktops look the same (`snapshot-themes` and `snapshot-menu` are
unchanged since v0.2.1). `docs/images/wiki.png`
and `docs/images/wiki-graph.png` were taken from the October 6 arm64 build
(82115b8); the v0.2.0 wiki looks the same. Re-shoot them when the wiki's look
changes.
