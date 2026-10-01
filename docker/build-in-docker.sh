#!/usr/bin/env bash
# Build SnapshOT inside the pinned container. live-build needs privileges, so
# this runs the container --privileged.
#
# The tree is copied into the container's own filesystem before building:
# live-build creates device nodes and a full chroot, which do not work on a bind
# mount from macOS and are slow on any bind mount. A named volume keeps
# live-build's apt cache across runs so a failed build does not refetch the
# snapshot. The ISO and build log are copied back to the repo root.
#
#   docker/build-in-docker.sh                      # amd64 (default)
#   SNAPSHOT_ARCH=arm64 docker/build-in-docker.sh  # arm64 (UEFI only)
#
# The container platform follows the target architecture, so the build is
# native when host and target match and emulated otherwise. On Apple Silicon the
# arm64 build is native; the amd64 build runs under emulation and takes hours.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${SNAPSHOT_ARCH:-amd64}"
case "$ARCH" in amd64) OTHER=arm64 ;; arm64) OTHER=amd64 ;; *) OTHER="" ;; esac
PLATFORM="${SNAPSHOT_DOCKER_PLATFORM:-linux/${ARCH}}"
CACHE_VOLUME="${SNAPSHOT_CACHE_VOLUME:-snapshot-build-cache-${ARCH}}"

docker build --platform "$PLATFORM" -t "snapshot-builder:${ARCH}" "$ROOT/docker"
docker run --rm --privileged --platform "$PLATFORM" \
    -e SNAPSHOT_ARCH="$ARCH" \
    -e SNAPSHOT_OTHER_ARCH="$OTHER" \
    -e SNAPSHOT_GIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
    -v "$ROOT":/snapshot \
    -v "$CACHE_VOLUME":/build/cache \
    "snapshot-builder:${ARCH}" -lc '
        set -euo pipefail
        # Do not carry the other architecture'"'"'s fetched vendor artifacts into
        # the builder: stage only needs this arch, and they are large.
        other_excludes=""
        if [ -n "${SNAPSHOT_OTHER_ARCH:-}" ]; then
            other_excludes="--exclude /vendor/src/${SNAPSHOT_OTHER_ARCH} --exclude vendor/python/*/wheelhouse/${SNAPSHOT_OTHER_ARCH}"
        fi
        rsync -a --exclude /.git --exclude /chroot --exclude /binary --exclude /.build \
              --exclude /cache --exclude /build --exclude "/*.iso" $other_excludes /snapshot/ /build/
        cd /build && mkdir -p build
        status=0
        scripts/build.sh || status=$?
        mkdir -p /snapshot/build
        cp -f /build/build/build.log /snapshot/build/ 2>/dev/null || true
        cp -f /build/*.iso /snapshot/ 2>/dev/null || true
        exit $status
    '
