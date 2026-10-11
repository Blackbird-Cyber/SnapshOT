#!/usr/bin/env bash
# Publish built ISOs as a GitHub release of Blackbird-Cyber/SnapshOT.
# Needs the GitHub CLI authenticated with write access (brew install gh; gh auth login).
#
#   scripts/release.sh v0.3.0-alpha [--prerelease] [--draft]
#
# The tag must be v$SNAPSHOT_VERSION from config/snapshot.env (the version the
# images carry in /etc/snapshot-release); the script refuses any other tag. The
# release title is "SnapshOT" and the version with hyphens as spaces
# (v0.3.0-alpha: "SnapshOT 0.3.0 alpha").
# Uploads every snapshot-*.hybrid.iso in the repo root plus SHA256SUMS. GitHub
# caps a single release asset at 2 GiB, so a larger ISO is uploaded as 1900 MiB
# parts (snapshot-<arch>.hybrid.iso.part-aa, .part-ab, ...). Join them with
#   cat snapshot-<arch>.hybrid.iso.part-* > snapshot-<arch>.hybrid.iso
# and verify against SHA256SUMS, which always lists the whole ISO.
# README.md's download table, download links and badges are rewritten for the
# tag first; the Download badge of a split ISO points at the release page, since
# there is no single asset to link. If that changed README.md, the script stops
# so you can commit it. On the re-run the release is created as a draft, the
# assets are uploaded one at a time with retries (an asset GitHub already holds
# with the same SHA-256 is skipped), and every asset's size and SHA-256 are
# checked against what GitHub reports. The release notes are
# docs/release-notes/<tag>.md when that file exists, else a generic text; they
# are set when the release is created and refreshed on every run while the
# release is a draft. A published release only gets its assets replaced.
#
# Without --draft, the annotated tag is created at HEAD if it does not exist and
# pushed if GitHub does not have it, and the release is published.
#
# With --draft, the script stops before publishing and prints the draft's URL.
# It creates and pushes no tag: the draft names the tag and points at HEAD's
# commit, so GitHub must already have that commit (push the branch that carries
# the README commit first). To publish after the review, run the script again
# with the same options minus --draft: it creates and pushes the tag, refreshes
# the draft's notes, skips the assets that are already up, verifies them and
# publishes. A draft published from the GitHub web page instead gets a
# lightweight tag at the commit the draft points at.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
USAGE="usage: release.sh <tag> [--prerelease] [--draft]"
TAG="${1:?$USAGE}"; shift
PRERELEASE=0; DRAFT=0
for a in "$@"; do
    case "$a" in
        --prerelease) PRERELEASE=1 ;;
        --draft)      DRAFT=1 ;;
        *) echo "unknown option $a; $USAGE" >&2; exit 2 ;;
    esac
done
REPO="Blackbird-Cyber/SnapshOT"
LIMIT=2000000000
TITLE="SnapshOT ${TAG#v}"; TITLE="${TITLE//-/ }"
PRERELEASE_FLAG=false; PRERELEASE_OPT=""
if [ "$PRERELEASE" = 1 ]; then PRERELEASE_FLAG=true; PRERELEASE_OPT=" --prerelease"; fi

command -v gh >/dev/null 2>&1 || { echo "gh is not installed: brew install gh && gh auth login" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated: gh auth login" >&2; exit 1; }
. config/snapshot.env
if [ "v${SNAPSHOT_VERSION}" != "$TAG" ]; then
    echo "tag $TAG does not match config/snapshot.env (SNAPSHOT_VERSION=\"${SNAPSHOT_VERSION}\", so the tag must be v${SNAPSHOT_VERSION})." >&2
    echo "The images carry that version in /etc/snapshot-release: bump it, commit, rebuild, then release." >&2
    exit 1
fi

sha256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
filesize() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1"; }

ISOS=(snapshot-*.hybrid.iso)
[ -e "${ISOS[0]}" ] || { echo "no snapshot-*.hybrid.iso in $ROOT; build first" >&2; exit 1; }
if [ "${#ISOS[@]}" -lt 2 ]; then
    echo "WARNING: only ${#ISOS[@]} ISO in $ROOT (${ISOS[*]}); a release normally carries both snapshot-amd64 and snapshot-arm64." >&2
fi

sha256 "${ISOS[@]}" > SHA256SUMS
ASSETS=(SHA256SUMS)
split_isos=()
for iso in "${ISOS[@]}"; do
    size=$(filesize "$iso")
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
        size=$(filesize "$file")
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

# The tag. A draft gets none yet: it points at HEAD's commit, which GitHub has
# to know so the draft can be published, by this script or from the web page.
HEAD_SHA="$(git rev-parse HEAD)"
tag_on_github() { git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; }
if [ "$DRAFT" = 1 ]; then
    if ! gh api "repos/$REPO/commits/$HEAD_SHA" --silent >/dev/null 2>&1; then
        echo "GitHub does not have HEAD (${HEAD_SHA:0:7}) yet. --draft pushes no tag, so the draft points at that commit: push the branch that carries it, then re-run." >&2
        exit 1
    fi
else
    if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
        if tag_on_github; then
            git fetch -q origin "refs/tags/$TAG:refs/tags/$TAG"
        else
            git tag -a "$TAG" -m "SnapshOT $TAG"
        fi
    fi
    tag_commit="$(git rev-parse "$TAG^{commit}")"
    if [ "$tag_commit" != "$HEAD_SHA" ]; then
        if ! git diff --quiet "$tag_commit" HEAD -- README.md; then
            echo "tag $TAG names ${tag_commit:0:7}, whose README.md does not list these images. Move the tag to HEAD (git tag -d $TAG; git push origin :refs/tags/$TAG), then re-run." >&2
            exit 1
        fi
        echo "note: tag $TAG names ${tag_commit:0:7}, not HEAD (${HEAD_SHA:0:7}); README.md is the same" >&2
    fi
    tag_on_github || git push origin "refs/tags/$TAG"
fi

# "; about X GiB" (from stat, as release_table) plus the parts, for one ISO.
iso_note() {
    local iso="$1" size parts
    [ -e "$iso" ] || return 0
    size=$(filesize "$iso")
    awk -v b="$size" 'BEGIN { printf "; about %.1f GiB", b / 1073741824 }'
    if [ -e "$iso.part-aa" ]; then
        parts=("$iso".part-*)
        printf ', published as %s parts (%s.part-*)' "${#parts[@]}" "$iso"
    fi
}
NOTES="SnapshOT ${TAG#v}: Debian ${SNAPSHOT_DIST} pinned to snapshot.debian.org ${SNAPSHOT_DEBIAN_PIN} (SOURCE_DATE_EPOCH ${SNAPSHOT_SOURCE_DATE_EPOCH}). Each image records its exact build commit in /etc/snapshot-release.

- snapshot-amd64.hybrid.iso: BIOS + UEFI, for x86-64 laptops and VMs$(iso_note snapshot-amd64.hybrid.iso). Write it to USB with dd or Ventoy.
- snapshot-arm64.hybrid.iso: UEFI only, for arm64 VMs (UTM, Parallels, VMware Fusion on Apple Silicon) and UEFI arm64 hardware$(iso_note snapshot-arm64.hybrid.iso). Not bootable on Apple Silicon bare metal.
- amd64 only: the OPC UA GUI client; see 'amd64 and arm64 images' in README.md.
- Live session: user \`snapshot\`, password \`live\`. Install with the desktop icon (Calamares, LUKS2).
- Any .part-* files are one ISO split for GitHub's 2 GiB asset limit: cat them together in order, then verify against SHA256SUMS (docs/getting-started.md shows how on Linux, macOS and Windows).
- Vendor layer: enabled tools ship under /opt/snapshot/<tool>/ with their own pinned runtime (CPython 3.11 for the ICS Python libs, plcscan, the OPC UA GUI client on amd64; Redpoint NSE scripts in nmap). Ghidra + JDK 21 is defined but disabled. Reached via /opt/snapshot/bin on PATH; BUILD-MANIFEST.txt lists every runtime and tool. Run scripts/vendor.py fetch (network + Docker) before a build to populate it; a build without it still produces a working image."

LISTING="$(mktemp)"; TMP_NOTES=""
trap 'rm -f "$LISTING" ${TMP_NOTES:+"$TMP_NOTES"}' EXIT

# The tag's own notes when they exist; otherwise the generic NOTES above.
NOTES_FILE="docs/release-notes/$TAG.md"
if [ -f "$NOTES_FILE" ]; then
    echo "release notes: $NOTES_FILE"
else
    TMP_NOTES="$(mktemp)"; NOTES_FILE="$TMP_NOTES"
    printf '%s\n' "$NOTES" > "$NOTES_FILE"
    echo "release notes: no docs/release-notes/$TAG.md; using the generic notes" >&2
fi

# Create the release as a draft, or refresh the draft an earlier run left.
state="$(gh release view "$TAG" --repo "$REPO" --json isDraft \
    --jq 'if .isDraft then "draft" else "published" end' 2>/dev/null || echo none)"
target=(); [ "$DRAFT" = 1 ] && target=(--target "$HEAD_SHA")
case "$state" in
    none)
        create=(--repo "$REPO" --draft --title "$TITLE" --notes-file "$NOTES_FILE")
        [ "$PRERELEASE" = 1 ] && create+=(--prerelease)
        [ "$DRAFT" = 1 ] || create+=(--verify-tag)
        gh release create "$TAG" "${create[@]}" ${target[@]+"${target[@]}"}
        ;;
    draft)
        echo "release $TAG is a draft: refreshing its title, notes and pre-release flag"
        gh release edit "$TAG" --repo "$REPO" --title "$TITLE" --notes-file "$NOTES_FILE" \
            --prerelease="$PRERELEASE_FLAG" ${target[@]+"${target[@]}"}
        ;;
    published)
        echo "release $TAG is already published: replacing its assets only" >&2
        ;;
esac

# The SHA-256 of each asset, in the order of ASSETS: a whole ISO's from
# SHA256SUMS, the others' (SHA256SUMS itself, the parts) computed here.
ASSET_SHA=()
for a in "${ASSETS[@]}"; do
    s="$(awk -v f="$a" '$2 == f || $2 == "*" f { print $1 }' SHA256SUMS)"
    [ -n "$s" ] || s="$(sha256 "$a" | awk '{ print $1 }')"
    ASSET_SHA+=("$s")
done
# One line per asset on the release: name, size, digest ("-" when GitHub
# reports none).
remote_assets() {
    gh release view "$TAG" --repo "$REPO" --json assets \
        --jq '.assets[] | "\(.name) \(.size) \(.digest // "-")"' > "$LISTING"
}

# Upload one asset at a time with retries: one POST of up to about 1900 MiB
# (a part, or a whole ISO under the limit) fails easily over a flaky link.
# Re-running after a failure resumes into the same draft.
remote_assets
i=0
for a in "${ASSETS[@]}"; do
    name="$(basename "$a")"; want="sha256:${ASSET_SHA[$i]}"; i=$((i + 1))
    if awk -v n="$name" -v d="$want" '$1 == n && $3 == d { found = 1 } END { exit !found }' "$LISTING"; then
        echo "GitHub already has $name with the same SHA-256; not uploading it again"
        continue
    fi
    for try in 1 2 3 4 5; do
        if gh release upload "$TAG" "$a" --repo "$REPO" --clobber; then break; fi
        if [ "$try" = 5 ]; then echo "giving up on $a" >&2; exit 1; fi
        echo "upload of $a failed (attempt $try); retrying in 30s" >&2; sleep 30
    done
done

# Verify every asset's size and SHA-256 against GitHub's, and that the release
# carries nothing else (an ISO an earlier run uploaded whole and this run split,
# for example).
remote_assets
ok=1; i=0
for a in "${ASSETS[@]}"; do
    name="$(basename "$a")"; want="sha256:${ASSET_SHA[$i]}"; i=$((i + 1))
    local_size=$(filesize "$a")
    remote="$(awk -v n="$name" '$1 == n { print $2, $3 }' "$LISTING")"
    remote_size="${remote%% *}"; remote_digest="${remote#* }"
    if [ -z "$remote" ]; then
        echo "MISSING $name: not on the release" >&2; ok=0
    elif [ "$local_size" != "$remote_size" ]; then
        echo "SIZE MISMATCH $name: local $local_size, GitHub $remote_size" >&2; ok=0
    elif [ "$remote_digest" = "-" ]; then
        echo "verified $name ($local_size bytes; GitHub reports no digest, so by size only)"
    elif [ "$remote_digest" != "$want" ]; then
        echo "SHA-256 MISMATCH $name: local ${want#sha256:}, GitHub ${remote_digest#sha256:}" >&2; ok=0
    else
        echo "verified $name ($local_size bytes, SHA-256 matches)"
    fi
done
while read -r name _; do
    known=0
    for a in "${ASSETS[@]}"; do
        if [ "$(basename "$a")" = "$name" ]; then known=1; fi
    done
    if [ "$known" = 0 ]; then
        echo "UNEXPECTED $name is on the release but not among this run's assets; remove it with: gh release delete-asset $TAG $name --repo $REPO" >&2
        ok=0
    fi
done < "$LISTING"
[ "$ok" = 1 ] || { echo "not publishing: asset verification failed" >&2; exit 1; }

url="$(gh release view "$TAG" --repo "$REPO" --json url --jq .url)"
if [ "$DRAFT" = 1 ] && [ "$state" != published ]; then
    echo "draft ready for review, not published: $url"
    echo "to publish it: scripts/release.sh $TAG$PRERELEASE_OPT"
    exit 0
fi
[ "$state" = published ] || gh release edit "$TAG" --repo "$REPO" --draft=false
echo "release: https://github.com/$REPO/releases/tag/$TAG"
echo "README.md lists $TAG and is committed; push the branch when ready."
