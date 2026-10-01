# Building SnapshOT

## Requirements
A Debian trixie host (or the `docker/` container) with `live-build`, `dpkg-dev`,
`debhelper`, `xorriso`, `squashfs-tools`, and `pipx` (`pipx install pip-tools`
for the vendor step; trixie has no pip-tools package). live-build runs as root.

The container path works on macOS too: `docker/build-in-docker.sh` copies the
tree into the container, builds there (live-build cannot build a chroot on a
bind mount), keeps the apt cache in a named volume, and copies the ISO and log
back out. On Apple Silicon it runs under amd64 emulation and takes hours.

## One-time, online
1. Set the pin in `config/snapshot.env` (`SNAPSHOT_DEBIAN_PIN` + matching
   `SNAPSHOT_SOURCE_DATE_EPOCH`). Verify the timestamp exists under
   https://snapshot.debian.org/archive/debian/ .
2. Pin Python versions in `vendor/python/requirements.in`.
3. Fill `vendor/sources.lock` URLs, then:
   ```
   scripts/fetch-vendor.sh --update-hashes   # records sha256 into the lock
   scripts/fetch-vendor.sh                    # builds wheelhouse, verifies hashes
   ```

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
- ICS Python libs come from a pinned wheelhouse installed with
  `pip install --no-index --require-hashes` into `/opt/snapshot/venv`.
- Non-apt tools come from `vendor/sources.lock` artifacts, hash-verified.

## Reproducibility
`scripts/verify-repro.sh` builds twice from clean state and compares ISO sha256,
running diffoscope on mismatch. Determinism rests on the snapshot pin and
`SOURCE_DATE_EPOCH`.
