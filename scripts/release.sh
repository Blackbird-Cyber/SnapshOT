#!/usr/bin/env bash
# Publish built ISOs as a GitHub release of Blackbird-Cyber/SnapshOT.
# Needs the GitHub CLI authenticated with write access (brew install gh; gh auth login).
#
#   scripts/release.sh v0.1.0 [--prerelease]
#
# Uploads every snapshot-*.hybrid.iso in the repo root plus SHA256SUMS. GitHub
# caps a single release asset at 2 GiB, so a larger ISO is uploaded as 1900 MiB
# parts (snapshot-<arch>.hybrid.iso.part-aa, .part-ab, ...). Join them with
#   cat snapshot-<arch>.hybrid.iso.part-* > snapshot-<arch>.hybrid.iso
# and verify against SHA256SUMS, which always lists the whole ISO.
# The tag is created at HEAD and pushed if it does not exist yet; an existing
# release gets its assets replaced.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
TAG="${1:?usage: release.sh <tag> [--prerelease]}"; shift || true
REPO="Blackbird-Cyber/SnapshOT"
LIMIT=2000000000

command -v gh >/dev/null 2>&1 || { echo "gh is not installed: brew install gh && gh auth login" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated: gh auth login" >&2; exit 1; }
. config/snapshot.env

ISOS=(snapshot-*.hybrid.iso)
[ -e "${ISOS[0]}" ] || { echo "no snapshot-*.hybrid.iso in $ROOT; build first" >&2; exit 1; }

if command -v sha256sum >/dev/null 2>&1; then sha256sum "${ISOS[@]}" > SHA256SUMS; else shasum -a 256 "${ISOS[@]}" > SHA256SUMS; fi
ASSETS=(SHA256SUMS)
for iso in "${ISOS[@]}"; do
    size=$(stat -f%z "$iso" 2>/dev/null || stat -c%s "$iso")
    if [ "$size" -gt "$LIMIT" ]; then
        echo "$iso is $size bytes (> 2 GiB): splitting into 1900 MiB parts"
        rm -f "$iso".part-*
        split -b 1900m "$iso" "$iso.part-"
        ASSETS+=("$iso".part-*)
    else
        ASSETS+=("$iso")
    fi
done

if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    git tag -a "$TAG" -m "SnapshOT $TAG"
    git push origin "$TAG"
fi

NOTES="SnapshOT ${TAG#v}: Debian ${SNAPSHOT_DIST} pinned to snapshot.debian.org ${SNAPSHOT_DEBIAN_PIN} (SOURCE_DATE_EPOCH ${SNAPSHOT_SOURCE_DATE_EPOCH}). Each image records its exact build commit in /etc/snapshot-release.

- snapshot-amd64.hybrid.iso: BIOS + UEFI, for x86-64 laptops. Write it to USB with dd or Ventoy.
- snapshot-arm64.hybrid.iso: UEFI only, for arm64 VMs (UTM, Parallels, VMware Fusion on Apple Silicon) and UEFI arm64 hardware. Not bootable on Apple Silicon bare metal.
- Live session: user \`snapshot\`, password \`live\`. Install with the desktop icon (Calamares, LUKS2).
- Any .part-* files are one ISO split for GitHub's 2 GiB asset limit: cat them together in order, then verify against SHA256SUMS.
- This build omits the vendor layer (ICS Python wheelhouse, zeek, ghidra, GRASSMARLIN): run scripts/fetch-vendor.sh before a build to include it."

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "${ASSETS[@]}" --repo "$REPO" --clobber
else
    gh release create "$TAG" "${ASSETS[@]}" --repo "$REPO" --title "SnapshOT ${TAG#v}" --notes "$NOTES" "$@"
fi
echo "release: https://github.com/$REPO/releases/tag/$TAG"
