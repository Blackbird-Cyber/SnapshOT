# Building SnapshOT

## Requirements
A Debian trixie host (or the `docker/` container) with `live-build`, `dpkg-dev`,
`debhelper`, `xorriso`, `squashfs-tools`, `pip-tools`. live-build runs as root.

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
