#!/usr/bin/env bash
# Build twice from clean state and compare the ISO sha256. On mismatch, run
# diffoscope if available. Run as root on the build host.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
mkdir -p build/repro

run_once() { # $1 = label
    echo "== repro build $1"
    git clean -xfd config/binary config/chroot 2>/dev/null || true
    scripts/build.sh
    iso="$(ls -1 *.iso | head -n1)"
    cp -f "$iso" "build/repro/snapshot-$1.iso"
    sha256sum "build/repro/snapshot-$1.iso" | tee "build/repro/snapshot-$1.sha256"
}
run_once A
run_once B
if cmp -s build/repro/snapshot-A.iso build/repro/snapshot-B.iso; then
    echo "REPRODUCIBLE: identical ISOs."
else
    echo "NOT REPRODUCIBLE: ISOs differ." >&2
    command -v diffoscope >/dev/null 2>&1 && \
        diffoscope build/repro/snapshot-A.iso build/repro/snapshot-B.iso | head -n 200 || \
        echo "install diffoscope to see the diff" >&2
    exit 1
fi
