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
# release gets its assets replaced. README.md's download table, download links
# and badges are rewritten for the tag; review and commit that change afterwards.
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

# Refresh README.md for this release: the table between the release-table
# markers (rows from SHA256SUMS, sizes from stat), the download links, the
# release badge and the snapshot-pin badge. The script does not commit it.
PRERELEASE=0
for a in "$@"; do [ "$a" = "--prerelease" ] && PRERELEASE=1; done
release_table() {
    local kind=release sum file size gib hw boot link
    [ "$PRERELEASE" = 1 ] && kind=pre-release
    echo "<!-- release-table:start -->"
    echo "**$TAG** ($kind): Debian ${SNAPSHOT_DIST} pinned to snapshot.debian.org \`${SNAPSHOT_DEBIAN_PIN}\`."
    echo
    echo "| Image | Hardware | Boot | Size | SHA-256 |"
    echo "|---|---|---|---|---|"
    while read -r sum file; do
        file="${file#\*}"
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
        gib=$(awk -v b="$size" 'BEGIN { printf "%.2f GiB", b / 1073741824 }')
        case "$file" in
            *amd64*) hw="x86-64 laptops and VMs"; boot="BIOS + UEFI" ;;
            *arm64*) hw="arm64 VMs (UTM, Parallels, VMware Fusion on Apple Silicon) and UEFI arm64 hardware"; boot="UEFI" ;;
            *)       hw="-"; boot="-" ;;
        esac
        if [ -e "$file.part-aa" ]; then
            link="[$file](https://github.com/$REPO/releases/tag/$TAG) (in parts, see below)"
        else
            link="[$file](https://github.com/$REPO/releases/download/$TAG/$file)"
        fi
        echo "| $link | $hw | $boot | $gib | \`$sum\` |"
    done < SHA256SUMS
    echo
    echo "Checksums: [\`SHA256SUMS\`](https://github.com/$REPO/releases/download/$TAG/SHA256SUMS)"
    echo "<!-- release-table:end -->"
}
if grep -q '<!-- release-table:start -->' README.md && grep -q '<!-- release-table:end -->' README.md; then
    block="$(mktemp)"; readme="$(mktemp)"
    release_table > "$block"
    badge_label=release; [ "$PRERELEASE" = 1 ] && badge_label="pre--release"
    badge_tag="${TAG//-/--}"; badge_tag="${badge_tag//_/__}"
    pin_badge="${SNAPSHOT_DEBIAN_PIN:0:4}--${SNAPSHOT_DEBIAN_PIN:4:2}--${SNAPSHOT_DEBIAN_PIN:6:2}"
    awk -v blockfile="$block" '
        /<!-- release-table:start -->/ { while ((getline line < blockfile) > 0) print line; skip = 1; next }
        /<!-- release-table:end -->/   { skip = 0; next }
        !skip
    ' README.md | sed -E \
        -e "s#(github\.com/$REPO/releases/download/)[^/]+/#\1$TAG/#g" \
        -e "s#(github\.com/$REPO/releases/tag/)[^\")[:space:]]+#\1$TAG#g" \
        -e "s#img\.shields\.io/badge/(pre--)?release-[^\"?)]*-F1000E#img.shields.io/badge/$badge_label-$badge_tag-F1000E#g" \
        -e "s#img\.shields\.io/badge/snapshot_pin-[0-9-]+-#img.shields.io/badge/snapshot_pin-$pin_badge-#g" \
        > "$readme"
    cat "$readme" > README.md
    rm -f "$block" "$readme"
    echo "README.md: release table, download links and badges updated for $TAG"
else
    echo "README.md has no release-table markers; not updated" >&2
fi

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

# Create the release as a draft, upload one asset at a time with retries (a
# 1.7 GiB POST over a flaky link fails easily), verify every asset's size, then
# publish. Re-running after a failure resumes into the same draft.
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release create "$TAG" --repo "$REPO" --draft --title "SnapshOT ${TAG#v}" --notes "$NOTES" "$@"
fi
for a in "${ASSETS[@]}"; do
    for try in 1 2 3 4 5; do
        if gh release upload "$TAG" "$a" --repo "$REPO" --clobber; then break; fi
        echo "upload of $a failed (attempt $try); retrying in 30s" >&2; sleep 30
        [ "$try" = 5 ] && { echo "giving up on $a" >&2; exit 1; }
    done
done
ok=1
for a in "${ASSETS[@]}"; do
    local_size=$(stat -f%z "$a" 2>/dev/null || stat -c%s "$a")
    remote_size=$(gh release view "$TAG" --repo "$REPO" --json assets --jq ".assets[] | select(.name==\"$(basename "$a")\") | .size")
    if [ "$local_size" = "$remote_size" ]; then echo "verified $a ($local_size bytes)"; else echo "SIZE MISMATCH $a: local $local_size remote ${remote_size:-missing}" >&2; ok=0; fi
done
[ "$ok" = 1 ] || { echo "not publishing: asset verification failed" >&2; exit 1; }
gh release edit "$TAG" --repo "$REPO" --draft=false
echo "release: https://github.com/$REPO/releases/tag/$TAG"
echo "Next: review README.md (now listing $TAG) and commit it; this script does not commit."
