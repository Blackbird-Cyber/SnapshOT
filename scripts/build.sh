#!/usr/bin/env bash
# SnapshOT build orchestrator. Run on a Debian trixie host (or in the pinned
# container from docker/) as root, because live-build needs root.
#
#   sudo scripts/build.sh
#
# Steps: build branding .debs -> stage them -> stage the offline wheelhouse and
# source tools -> lb config -> lb build. Reproducibility comes from the snapshot
# pin in config/snapshot.env plus SOURCE_DATE_EPOCH.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

. config/snapshot.env
export SOURCE_DATE_EPOCH="${SNAPSHOT_SOURCE_DATE_EPOCH}"
export SNAPSHOT_DEBIAN_PIN
export SNAPSHOT_ARCH="${SNAPSHOT_ARCH:-amd64}"
echo "SnapshOT: arch=${SNAPSHOT_ARCH} debian-pin=${SNAPSHOT_DEBIAN_PIN} SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }
need lb; need dpkg-buildpackage

# 1. Build the four branding packages into config/packages.chroot/.
mkdir -p config/packages.chroot
for pkg in packages/*/; do
    [ -f "${pkg}debian/control" ] || continue
    echo "== building ${pkg}"
    ( cd "$pkg" && dpkg-buildpackage -b -us -uc )
done
find packages -maxdepth 1 -name '*.deb' -exec mv -t config/packages.chroot/ {} + 2>/dev/null || \
  mv packages/*.deb config/packages.chroot/ 2>/dev/null || true
# dpkg-buildpackage drops artifacts in the parent of each source dir:
mv packages/*.deb config/packages.chroot/ 2>/dev/null || true
echo "staged .debs:"; ls -1 config/packages.chroot/ || true

# 2. Stage the offline wheelhouse + requirements (if fetched).
STAGE="config/includes.chroot/usr/local/share/snapshot"
mkdir -p "$STAGE"
if [ -d vendor/python/wheelhouse ]; then
    rm -rf "$STAGE/wheelhouse"; cp -a vendor/python/wheelhouse "$STAGE/wheelhouse"
    cp -a vendor/python/requirements.txt "$STAGE/requirements.txt"
    echo "staged wheelhouse ($(ls vendor/python/wheelhouse | wc -l | tr -d ' ') files)"
else
    echo "WARN: no vendor/python/wheelhouse — ICS Python libs will be skipped. Run scripts/fetch-vendor.sh."
fi

# 3. Stage vendored source/binary tools (if fetched).
if [ -d vendor/src ] && [ -n "$(ls -A vendor/src 2>/dev/null)" ]; then
    rm -rf "$STAGE/src"; mkdir -p "$STAGE/src"
    cp -a vendor/src/. "$STAGE/src/"
    echo "staged source tools: $(ls -1 vendor/src | tr '\n' ' ')"
else
    echo "WARN: no vendor/src — zeek/ghidra/grassmarlin etc. will be skipped."
fi

# 4. Configure and build.
lb clean || true            # keeps cache/ so a rerun does not refetch the snapshot
mkdir -p build
auto/config
auto/build

echo "SnapshOT: build finished. ISO:"; ls -1 *.iso 2>/dev/null || echo "(no .iso produced — check build/build.log)"
