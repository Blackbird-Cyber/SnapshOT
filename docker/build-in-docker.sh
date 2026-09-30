#!/usr/bin/env bash
# Build SnapshOT inside the pinned container. live-build needs privileges, so this
# runs the container --privileged with the repo bind-mounted.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
docker build -t snapshot-builder "$ROOT/docker"
docker run --rm --privileged -v "$ROOT":/snapshot snapshot-builder \
    -lc "cd /snapshot && scripts/build.sh"
