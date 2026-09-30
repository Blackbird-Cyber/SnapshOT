#!/usr/bin/env bash
# Build a signed, offline apt mirror on a USB stick for in-field package adds,
# limited to the release snapshot plus explicitly requested packages. Laptops
# trust only the SnapshOT signing key. Run on a networked Debian host with aptly.
#
#   scripts/make-update-usb.sh /media/usb pkg1 pkg2 ...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
. config/snapshot.env
DEST="${1:?usage: make-update-usb.sh <usb-mount> [pkg ...]}"; shift || true
PKGS=("$@")
command -v aptly >/dev/null 2>&1 || { echo "aptly not installed" >&2; exit 1; }

REPO="snapshot-$(date -u +%Y%m%d)"
aptly mirror create -architectures=amd64 \
    "$REPO" "${SNAPSHOT_MIRROR_DEBIAN}" "${SNAPSHOT_DIST}" main || true
aptly mirror update "$REPO"
SNAP="${REPO}-snap"
if [ "${#PKGS[@]}" -gt 0 ]; then
    aptly snapshot filter "$REPO" "$SNAP" "$(printf '%s | ' "${PKGS[@]}" | sed 's/ | $//')"
else
    aptly snapshot create "$SNAP" from mirror "$REPO"
fi
# Signed publish; key id from SNAPSHOT_GPG_KEY env or default keyring.
aptly publish snapshot -distribution="${SNAPSHOT_DIST}" \
    ${SNAPSHOT_GPG_KEY:+-gpg-key="$SNAPSHOT_GPG_KEY"} "$SNAP" "file://${DEST}/snapshot-cache"
echo "SnapshOT update mirror written to ${DEST}/snapshot-cache"
echo "On the laptop, add it with a pinned sources.list.d entry trusting only the SnapshOT key."
