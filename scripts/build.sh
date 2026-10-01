#!/usr/bin/env bash
# SnapshOT build orchestrator. Run on a Debian trixie host (or in the pinned
# container from docker/) as root, because live-build needs root.
#
#   sudo scripts/build.sh
#
# Steps: build branding .debs -> stage them -> stage the vendor layer (pinned
# runtimes + tools + per-arch wheelhouses for this arch) -> lb config -> lb build.
# Reproducibility comes from the snapshot pin in config/snapshot.env plus
# SOURCE_DATE_EPOCH.
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

# 2. Stage the vendor layer (pinned runtimes, tools, per-arch wheelhouses) for
#    this arch. vendor.py copies only what is fetched; a build without the vendor
#    layer still works (the hooks skip when nothing is staged). Set
#    SNAPSHOT_VENDOR_REQUIRED=1 to turn "enabled but not fetched" into an error.
STAGE="config/includes.chroot/usr/local/share/snapshot/vendor"
rm -rf "$STAGE"
python3 scripts/vendor.py stage --arch "$SNAPSHOT_ARCH" --dest "$STAGE"

# 3b. Stamp the release identity into the image: read by the manifest hook and
#     available as /etc/snapshot-release on live and installed systems.
mkdir -p config/includes.chroot/etc
cat > config/includes.chroot/etc/snapshot-release <<REL
SNAPSHOT_VERSION="${SNAPSHOT_VERSION:-0.0.0}"
SNAPSHOT_ARCH="${SNAPSHOT_ARCH}"
SNAPSHOT_DIST="${SNAPSHOT_DIST}"
SNAPSHOT_DEBIAN_PIN="${SNAPSHOT_DEBIAN_PIN}"
SNAPSHOT_SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}"
SNAPSHOT_GIT="${SNAPSHOT_GIT:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
REL
echo "release identity: $(tr '\n' ' ' < config/includes.chroot/etc/snapshot-release)"

# 4. Configure and build.
lb clean || true            # keeps cache/ so a rerun does not refetch the snapshot
mkdir -p build
auto/config
auto/build

echo "SnapshOT: build finished. ISO:"; ls -1 *.iso 2>/dev/null || echo "(no .iso produced — check build/build.log)"
