#!/usr/bin/env bash
# Compatibility shim: the vendor layer is driven by scripts/vendor.py now.
# `scripts/fetch-vendor.sh [args]` == `scripts/vendor.py fetch [args]`.
# See docs/vendoring.md. Needs network + Docker (per-arch wheel builds).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/scripts/vendor.py" fetch "$@"
