#!/usr/bin/env bash
# Publish built ISOs as a GitHub release of Blackbird-Cyber/SnapshOT.
# Needs the GitHub CLI authenticated with write access (brew install gh; gh auth login).
#
#   scripts/release.sh v0.2.0 [--prerelease]
#
# The tag must be v$SNAPSHOT_VERSION from config/snapshot.env (the version the
# images carry in /etc/snapshot-release); the script refuses any other tag.
# Uploads every snapshot-*.hybrid.iso in the repo root plus SHA256SUMS. GitHub
# caps a single release asset at 2 GiB, so a larger ISO is uploaded as 1900 MiB
# parts (snapshot-<arch>.hybrid.iso.part-aa, .part-ab, ...). Join them with
#   cat snapshot-<arch>.hybrid.iso.part-* > snapshot-<arch>.hybrid.iso
# and verify against SHA256SUMS, which always lists the whole ISO.
# README.md's download table, download links and badges are rewritten for the
# tag first; the Download badge of a split ISO points at the release page, since
# there is no single asset to link. If that changed README.md, the script stops
# so you can commit it; on the re-run the tag is created at HEAD (now including
# the README) and pushed if it does not exist yet, and an existing release gets
# its assets replaced. The release notes are docs/release-notes/<tag>.md when that
# file exists, else a generic text; they are set only when the release is created.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
TAG="${1:?usage: release.sh <tag> [--prerelease]}"; shift || true
REPO="Blackbird-Cyber/SnapshOT"
LIMIT=2000000000

command -v gh >/dev/null 2>&1 || { echo "gh is not installed: brew install gh && gh auth login" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated: gh auth login" >&2; exit 1; }
. config/snapshot.env
if [ "v${SNAPSHOT_VERSION}" != "$TAG" ]; then
    echo "tag $TAG does not match config/snapshot.env (SNAPSHOT_VERSION=\"${SNAPSHOT_VERSION}\", so the tag must be v${SNAPSHOT_VERSION})." >&2
    echo "The images carry that version in /etc/snapshot-release: bump it, commit, rebuild, then release." >&2
    exit 1
fi

ISOS=(snapshot-*.hybrid.iso)
[ -e "${ISOS[0]}" ] || { echo "no snapshot-*.hybrid.iso in $ROOT; build first" >&2; exit 1; }
if [ "${#ISOS[@]}" -lt 2 ]; then
    echo "WARNING: only ${#ISOS[@]} ISO in $ROOT (${ISOS[*]}); a release normally carries both snapshot-amd64 and snapshot-arm64." >&2
fi

if command -v sha256sum >/dev/null 2>&1; then sha256sum "${ISOS[@]}" > SHA256SUMS; else shasum -a 256 "${ISOS[@]}" > SHA256SUMS; fi
ASSETS=(SHA256SUMS)
split_isos=()
for iso in "${ISOS[@]}"; do
    size=$(stat -f%z "$iso" 2>/dev/null || stat -c%s "$iso")
    if [ "$size" -gt "$LIMIT" ]; then
        echo "$iso is $size bytes (> 2 GiB): splitting into 1900 MiB parts"
        rm -f "$iso".part-*
        split -b 1900m "$iso" "$iso.part-"
        ASSETS+=("$iso".part-*)
        split_isos+=("$iso")
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
    # A split ISO has no single download asset: its badge goes to the release page.
    sed_split=()
    for iso in ${split_isos[@]+"${split_isos[@]}"}; do
        sed_split+=(-e "s#(github\.com/$REPO/releases/)download/$TAG/${iso//./\\.}\"#\1tag/$TAG\"#g")
    done
    awk -v blockfile="$block" '
        /<!-- release-table:start -->/ { while ((getline line < blockfile) > 0) print line; skip = 1; next }
        /<!-- release-table:end -->/   { skip = 0; next }
        !skip
    ' README.md | sed -E \
        -e "s#(github\.com/$REPO/releases/download/)[^/]+/#\1$TAG/#g" \
        ${sed_split[@]+"${sed_split[@]}"} \
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

if ! git diff --quiet HEAD -- README.md; then
    echo "README.md now lists $TAG. Review and commit it, then re-run this script so the tag includes it." >&2
    exit 1
fi
if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    git tag -a "$TAG" -m "SnapshOT $TAG"
    git push origin "$TAG"
fi

# "; about X GiB" (from stat, as release_table) plus the parts, for one ISO.
iso_note() {
    local iso="$1" size n
    [ -e "$iso" ] || return 0
    size=$(stat -f%z "$iso" 2>/dev/null || stat -c%s "$iso")
    awk -v b="$size" 'BEGIN { printf "; about %.1f GiB", b / 1073741824 }'
    if [ -e "$iso.part-aa" ]; then
        n=$(ls "$iso".part-* | wc -l | tr -d ' ')
        printf ', published as %s parts (%s.part-*)' "$n" "$iso"
    fi
}
NOTES="SnapshOT ${TAG#v}: Debian ${SNAPSHOT_DIST} pinned to snapshot.debian.org ${SNAPSHOT_DEBIAN_PIN} (SOURCE_DATE_EPOCH ${SNAPSHOT_SOURCE_DATE_EPOCH}). Each image records its exact build commit in /etc/snapshot-release.

- snapshot-amd64.hybrid.iso: BIOS + UEFI, for x86-64 laptops and VMs$(iso_note snapshot-amd64.hybrid.iso). Write it to USB with dd or Ventoy.
- snapshot-arm64.hybrid.iso: UEFI only, for arm64 VMs (UTM, Parallels, VMware Fusion on Apple Silicon) and UEFI arm64 hardware$(iso_note snapshot-arm64.hybrid.iso). Not bootable on Apple Silicon bare metal.
- amd64 only: the OPC UA GUI client; see 'amd64 and arm64 images' in README.md.
- Live session: user \`snapshot\`, password \`live\`. Install with the desktop icon (Calamares, LUKS2).
- Any .part-* files are one ISO split for GitHub's 2 GiB asset limit: cat them together in order, then verify against SHA256SUMS (docs/getting-started.md shows how on Linux, macOS and Windows).
- Vendor layer: enabled tools ship under /opt/snapshot/<tool>/ with their own pinned runtime (CPython 3.11 for the ICS Python libs, plcscan, the OPC UA GUI client on amd64; Redpoint NSE scripts in nmap). Ghidra + JDK 21 is defined but disabled. Reached via /opt/snapshot/bin on PATH; BUILD-MANIFEST.txt lists every runtime and tool. Run scripts/vendor.py fetch (network + Docker) before a build to populate it; a build without it still produces a working image."

# The tag's own notes when they exist; otherwise the generic NOTES above.
NOTES_FILE="docs/release-notes/$TAG.md"
if [ -f "$NOTES_FILE" ]; then
    echo "release notes: $NOTES_FILE"
else
    NOTES_FILE="$(mktemp)"
    trap 'rm -f "$NOTES_FILE"' EXIT
    printf '%s\n' "$NOTES" > "$NOTES_FILE"
    echo "release notes: no docs/release-notes/$TAG.md; using the generic notes" >&2
fi

# Create the release as a draft, upload one asset at a time with retries (one
# POST of up to about 1900 MiB, a 1900 MiB part or a whole ISO under the limit,
# fails easily over a flaky link), verify every asset's size, then publish.
# Re-running after a failure resumes into the same draft.
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release create "$TAG" --repo "$REPO" --draft --title "SnapshOT ${TAG#v}" --notes-file "$NOTES_FILE" "$@"
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
echo "README.md lists $TAG and is committed; push the branch when ready."
