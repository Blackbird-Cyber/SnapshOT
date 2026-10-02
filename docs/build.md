# Building SnapshOT

## Requirements
A Debian trixie host (or the `docker/` container) with `live-build`, `dpkg-dev`,
`debhelper`, `xorriso`, `squashfs-tools`. live-build runs as root. The vendor
step needs **Docker and network** but nothing extra on the host: it builds the
Python wheelhouses inside per-arch trixie containers using the pinned
interpreter, so no `pip-tools` (or `uv`) is installed on the host.

The container path works on macOS too: `docker/build-in-docker.sh` copies the
tree into the container, builds there (live-build cannot build a chroot on a
bind mount), keeps the apt cache in a named volume, and copies the ISO and log
back out. On Apple Silicon it runs under amd64 emulation and takes hours.

## One-time, online
1. Set the pin in `config/snapshot.env` (`SNAPSHOT_DEBIAN_PIN` + matching
   `SNAPSHOT_SOURCE_DATE_EPOCH`). Verify the timestamp exists under
   https://snapshot.debian.org/archive/debian/ .
2. Fetch the vendor layer (pinned runtimes + tools + per-arch wheelhouses), which
   needs Docker and network (see [`docs/vendoring.md`](vendoring.md)):
   ```
   python3 scripts/vendor.py update-hashes      # fills any TODO sha256 in the lock
   python3 scripts/vendor.py fetch --arch all   # runtimes + builds + wheelhouses, hash-verified
   python3 scripts/vendor.py verify             # re-check sha256 under vendor/src
   ```
   The per-arch `requirements.<arch>.txt` locks are committed; the wheelhouses and
   downloaded archives are gitignored, so this step is required before a build
   that includes the vendor layer. A build without it still works.
   For amd64, `fetch` also downloads the 1.16 GiB Autopsy zip and builds
   `libtsk_jni` from The Sleuth Kit source in a pinned trixie container (about
   5 minutes under emulation on Apple Silicon).

## Build
```
sudo scripts/build.sh        # or: docker/build-in-docker.sh
```
Output: `snapshot-*.iso` in the repo root; log in `build/build.log`.

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
exec sequence in `settings.conf` runs `packages` before `initramfscfg`.

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
