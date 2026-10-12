# Building SnapshOT

## Requirements
A Debian trixie host (or the `docker/` container) with `live-build`, `dpkg-dev`,
`debhelper`, `xorriso`, `squashfs-tools`, and `mkdocs-material`, `python3-pymdownx`
and `python3-yaml` (the Build-Depends of `packages/snapshot-wiki`, whose site is built
when `scripts/build.sh` runs `dpkg-buildpackage`; the `docker/` image has them).
live-build runs as root. The vendor step needs **Docker and network** but
nothing extra on the host: it builds the Python wheelhouses inside per-arch
trixie containers using the pinned interpreter, so no `pip-tools` (or `uv`) is
installed on the host.

The container path works on macOS too: `docker/build-in-docker.sh` copies the
tree into the container, builds there (live-build cannot build a chroot on a
bind mount), keeps the apt cache in a named volume per architecture
(`snapshot-build-cache-amd64`, `snapshot-build-cache-arm64`), and copies the ISO
and log back out. The container's platform follows the target architecture
(`SNAPSHOT_ARCH`, default `amd64`), and the builder image `docker/Dockerfile`
pins `debian:trixie-slim` by digest. On Apple Silicon:

| Target | Command | Runs | Warm cache |
|---|---|---|---|
| arm64 | `SNAPSHOT_ARCH=arm64 docker/build-in-docker.sh` | native | about 6 minutes |
| amd64 | `docker/build-in-docker.sh` | emulated | about 20 minutes |

A cold cache adds the package downloads from snapshot.debian.org.

## Online steps
1. Set the pin in `config/snapshot.env` (`SNAPSHOT_DEBIAN_PIN` + matching
   `SNAPSHOT_SOURCE_DATE_EPOCH`). Verify the timestamp exists under
   https://snapshot.debian.org/archive/debian/ .
2. Fetch the vendor layer (pinned runtimes + tools + per-arch wheelhouses), which
   needs Docker and network (see [`docs/vendoring.md`](vendoring.md)). Run it
   before the first build and again whenever `vendor/sources.lock` or a
   `vendor/python/*/requirements.in` changes:
   ```
   python3 scripts/vendor.py update-hashes      # fills any TODO sha256 in the lock
   python3 scripts/vendor.py fetch --arch all   # runtimes + builds + wheelhouses, hash-verified
   python3 scripts/vendor.py verify             # re-check sha256 under vendor/src
   ```
   The per-arch `requirements.<arch>.txt` locks are committed; the wheelhouses and
   downloaded archives are gitignored, so this step is required before a build
   that includes the vendor layer. A build without it still works: `vendor.py
   stage` prints a `WARN` for each enabled tool that is not fetched, and
   `SNAPSHOT_VENDOR_REQUIRED=1` turns that into an error.

## Build
```
sudo scripts/build.sh                          # directly on a Debian trixie host
SNAPSHOT_ARCH=arm64 docker/build-in-docker.sh  # arm64, in the build container
docker/build-in-docker.sh                      # amd64, in the build container
```
Output: `snapshot-<arch>.hybrid.iso` in the repo root. The log is
`build/build.log`; `docker/build-in-docker.sh` also keeps it as
`build/build-<arch>.log`, so the logs of both architectures sit side by side.

`scripts/build.sh` stamps `SNAPSHOT_VERSION` from `config/snapshot.env` and the
build commit into `/etc/snapshot-release` and `BUILD-MANIFEST.txt`. For a
release build, bump `SNAPSHOT_VERSION` and commit before building, so the image
names the version and the commit it was built from.

## Checks
All of them run in containers (Docker, network access) and exit non-zero on any
error. CI (`.github/workflows/checks.yml`) runs `reuse lint`,
`check-installer.sh`, `check-desktop.sh` and `check-wiki.sh` on every push to
main and every pull request.
```
scripts/check-installer.sh         # installer configuration (below)
scripts/check-desktop.sh           # desktop files, menu XML, the eight menu folders
scripts/check-fieldkit.sh          # field kit collectors, prep and import tools, the package
scripts/check-wiki.sh              # the wiki (below)
scripts/check-firefox-quiet.sh     # optional, slow: Firefox ESR sends nothing on its own
scripts/test-vendor-hooks.sh arm64 # install the fetched vendor layer and smoke-test it (or amd64)
```

## Checking the installer configuration
Run this before a build whenever `packages/calamares-settings-snapshot`, a
package changelog or the sudo hook changes:
```
scripts/check-installer.sh
```
It runs in a `debian:trixie` container (Docker, network access) and exits
non-zero on any error. It downloads `calamares` from the snapshot pin and
validates every `modules/*.conf` against that release's schema (Python
modules ship theirs in the .deb; C++ modules such as users, welcome and
partition take theirs from the Calamares source at the matching tag). It also
runs `dpkg-parsechangelog` on every `packages/*/debian/changelog`,
`desktop-file-validate` on the installer's `.desktop` files, runs the sudo
hook (which checks its sudoers file with `visudo -cf`), and asserts that the
exec sequence in `settings.conf` runs `packages` before `initramfscfg`. Finally it
checks the Secure Boot setup: `bootloader.conf` runs `snapshot-boot`'s
`grub-install` wrapper with `installEFIFallback` off, and the wrapper, run against
a stub `grub-install`, adds `--uefi-secure-boot --force-extra-removable` for EFI
targets, copies `grub.cfg` to `EFI/BOOT` and leaves BIOS calls unchanged. It
also sources `snapshot-boot`'s `/etc/default/grub.d/*.cfg` the way
`grub-mkconfig` does, with the architecture stubbed: on arm64 the installed
system's kernel command line gains `plymouth.ignore-serial-consoles` once, on
amd64 it is unchanged, and `splash` appears exactly once on both.

## Checking the wiki
`packages/snapshot-wiki` builds the SnapshOT Wiki with MkDocs during
`dpkg-buildpackage` (the builder image carries `mkdocs-material`,
`python3-pymdownx` and `python3-yaml`). Before a build, after changing any page
or launcher:
```
scripts/check-wiki.sh             # strict build, links, launcher coverage, offline-only assets
scripts/check-firefox-quiet.sh    # optional, slow: Firefox ESR sends nothing on its own
```
See [`docs/wiki.md`](wiki.md).

## Releasing
`scripts/release.sh <tag> [--prerelease] [--draft]` publishes the ISOs in the
repo root as a GitHub release (it needs `gh` authenticated with write access):

1. It refuses a tag other than `v$SNAPSHOT_VERSION`, and warns when fewer than
   two `snapshot-*.hybrid.iso` are present. The release title is "SnapshOT" and
   the version with hyphens as spaces (`v0.3.0-alpha`: "SnapshOT 0.3.0 alpha").
2. It writes `SHA256SUMS`, splits any ISO over 2,000,000,000 bytes into 1900 MiB
   parts, and rewrites the README's release table, download links and badges.
   If that changed `README.md`, it stops: review and commit the README, then run
   it again.
3. On the second run it creates an annotated tag at HEAD, pushes the tag,
   creates a draft release with `docs/release-notes/<tag>.md` as its notes (a
   generic text when that file does not exist), uploads the assets one at a time
   with retries, checks every asset's size and SHA-256 against what GitHub
   reports, and publishes. It does not push the branch.

With `--draft`, the second run stops before publishing and prints the draft's
URL, for a review:

- It creates and pushes no tag. The draft names the tag and points at HEAD's
  commit, so push the branch that carries the README commit first; the script
  stops if GitHub does not have that commit.
- To publish, run it again with the same options minus `--draft`. That run
  creates and pushes the tag, refreshes the draft's title, notes and pre-release
  flag, skips the assets GitHub already holds with the same SHA-256, verifies
  every asset and publishes the draft.
- A draft published from the GitHub web page instead gets a lightweight tag,
  which GitHub creates at the commit the draft points at.

Every run refreshes a draft's notes from `docs/release-notes/<tag>.md`, so edit
that file rather than the draft on GitHub. A published release keeps its notes
and only gets its assets replaced. The script does not publish when an asset is
missing or differs, or when the release carries an asset this run did not
produce (it prints the `gh release delete-asset` command); it stops when an
existing tag names a commit whose README does not list these images.

```
scripts/release.sh v0.3.0-alpha --prerelease --draft   # rewrites README.md: commit it, push the branch
scripts/release.sh v0.3.0-alpha --prerelease --draft   # the draft, for review
scripts/release.sh v0.3.0-alpha --prerelease           # after the review: tag and publish
```

## How offline works
- All apt mirrors point at the snapshot timestamp; the live squashfs holds the
  whole system, so the install copies bytes rather than fetching them.
- Every non-apt tool is installed into `/opt/snapshot/<tool>/` with its own
  pinned runtime by the chroot hooks, offline, from the staged layer: Python
  tools from a hash-pinned per-arch wheelhouse (`pip install --no-index
  --no-deps --require-hashes`), archives from `vendor/sources.lock` (sha256
  re-verified). Tools are reached through `/opt/snapshot/bin` on `PATH`. See
  [`docs/vendoring.md`](vendoring.md).

## Reproducibility
`scripts/verify-repro.sh` builds twice from clean state and compares ISO sha256,
running diffoscope on mismatch. Determinism rests on the snapshot pin and
`SOURCE_DATE_EPOCH`.
