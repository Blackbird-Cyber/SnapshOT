#!/usr/bin/env bash
# Re-import the two vendored JavaScript files the SnapshOT Wiki ships.
#
# Developer-time only: needs network, run once, and the RESULT is committed
# (assets/vendor/). The committed files, not this script, are the source of
# truth for the package build, which never touches the network.
#
# What it does:
#   1. Download the npm tarballs of vis-network and iframe-worker.
#   2. Verify each against the npm registry's sha512 "integrity" value below.
#   3. Extract
#        package/standalone/umd/vis-network.min.cjs -> assets/vendor/vis-network.min.js
#        package/shim/index.js                      -> assets/vendor/iframe-worker-shim.js
#      (vis-network is renamed to .js: Firefox on file:// picks the MIME type
#      from the extension and refuses to run a .cjs as a script.)
#   4. Copy each package's license text to assets/vendor/LICENSE-<name>.
#   5. Rewrite assets/vendor/ORIGIN.md from the values below plus the sha256 of
#      every extracted file.
#
# To refresh: change the version, URL and integrity below (from
# https://registry.npmjs.org/<name>/<version>, field dist.integrity), run this
# script, check the diff, run scripts/check-wiki.sh.
set -euo pipefail

VIS_VERSION="10.1.2"
VIS_URL="https://registry.npmjs.org/vis-network/-/vis-network-${VIS_VERSION}.tgz"
VIS_INTEGRITY="sha512-1Kj7GD7XNjygliqRWXv/VPT1X/2eKz2e09PvwDtETHwuvKJ0emid7/PmWoFqCMypun8rLbjgmalSfPkiVZ8ZMg=="
VIS_LICENSE="(Apache-2.0 OR MIT)"
VIS_SRC="package/standalone/umd/vis-network.min.cjs"
VIS_DST="vis-network.min.js"

SHIM_VERSION="1.0.4"
SHIM_URL="https://registry.npmjs.org/iframe-worker/-/iframe-worker-${SHIM_VERSION}.tgz"
SHIM_INTEGRITY="sha512-roeaaI+Lg1LJNfgpCjoRe/+WzEjy9+Z08LoEvu85MCPbBjwm+qXz8Ag5U05lHa6V1CysZyGzE0SOkAtSUA5q7Q=="
SHIM_LICENSE="MIT"
SHIM_SRC="package/shim/index.js"
SHIM_DST="iframe-worker-shim.js"

HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
DEST="$PKG/assets/vendor"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# integrity <file> <sha512-base64>: npm's Subresource-Integrity style check.
integrity() {
    python3 - "$1" "$2" <<'PY'
import base64, hashlib, sys
path, want = sys.argv[1], sys.argv[2]
with open(path, "rb") as fh:
    got = "sha512-" + base64.b64encode(hashlib.sha512(fh.read()).digest()).decode()
if got != want:
    sys.exit(f"integrity mismatch for {path}:\n  got  {got}\n  want {want}")
print(f"{path.rsplit('/', 1)[-1]}: integrity OK")
PY
}

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    else shasum -a 256 "$1" | awk '{print $1}'; fi
}

# fetch <name> <url> <integrity>: download and verify into $WORK/<name>/
fetch() {
    local name="$1" url="$2" want="$3"
    echo "== fetching $name"
    curl -fsSL --retry 3 -o "$WORK/$name.tgz" "$url"
    integrity "$WORK/$name.tgz" "$want"
    mkdir -p "$WORK/$name"
    tar -xzf "$WORK/$name.tgz" -C "$WORK/$name"
}

# license_file <dir>: print the path of the package's license text.
license_file() {
    local f
    for f in "$1"/package/LICENSE "$1"/package/LICENSE.md "$1"/package/LICENSE.txt \
             "$1"/package/LICENCE "$1"/package/license; do
        [ -f "$f" ] && { echo "$f"; return 0; }
    done
    return 1
}

fetch vis-network "$VIS_URL" "$VIS_INTEGRITY"
fetch iframe-worker "$SHIM_URL" "$SHIM_INTEGRITY"

echo "== staging into $DEST"
mkdir -p "$DEST"
cp "$WORK/vis-network/$VIS_SRC" "$DEST/$VIS_DST"
cp "$WORK/iframe-worker/$SHIM_SRC" "$DEST/$SHIM_DST"

# vis-network is dual-licensed and ships one text per licence.
: > "$DEST/LICENSE-vis-network"
found=0
for f in "$WORK"/vis-network/package/LICENSE*; do
    [ -f "$f" ] || continue
    found=1
    { echo "==> $(basename "$f") (from vis-network ${VIS_VERSION}) <=="; cat "$f"; echo; } \
        >> "$DEST/LICENSE-vis-network"
done
[ "$found" = 1 ] || { echo "no LICENSE* in the vis-network tarball" >&2; exit 1; }
lic="$(license_file "$WORK/iframe-worker")" || { echo "no LICENSE in the iframe-worker tarball" >&2; exit 1; }
cp "$lic" "$DEST/LICENSE-iframe-worker"

VIS_SHA="$(sha256 "$DEST/$VIS_DST")"
SHIM_SHA="$(sha256 "$DEST/$SHIM_DST")"

echo "== writing ORIGIN.md"
cat > "$DEST/ORIGIN.md" <<EOF
# Vendored JavaScript origin

Written by \`scripts/import-vendor-js.sh\`; do not edit by hand. The committed
files in this directory are the source of truth for the package build, which
never touches the network. To refresh them, change the values at the top of the
script and run it again.

| | vis-network | iframe-worker |
|---|---|---|
| Version | \`${VIS_VERSION}\` | \`${SHIM_VERSION}\` |
| Tarball | \`${VIS_URL}\` | \`${SHIM_URL}\` |
| npm integrity | \`${VIS_INTEGRITY}\` | \`${SHIM_INTEGRITY}\` |
| Extracted from | \`${VIS_SRC}\` | \`${SHIM_SRC}\` |
| Shipped as | \`${VIS_DST}\` | \`${SHIM_DST}\` |
| sha256 of shipped file | \`${VIS_SHA}\` | \`${SHIM_SHA}\` |
| Licence | ${VIS_LICENSE}; texts in \`LICENSE-vis-network\` | ${SHIM_LICENSE}; text in \`LICENSE-iframe-worker\` |

## Why each file is here

- **vis-network** draws the interactive graphs (\`assets/js/snapshot-graphs.js\`
  mounts it on every \`<div class="snapshot-graph">\`). The standalone UMD build
  bundles its own dependencies, so it is the only file needed. It is renamed from
  \`.cjs\` to \`.js\` because Firefox on \`file://\` decides the MIME type from the
  extension.
- **iframe-worker** is the shim Material's \`offline\` plugin loads so that search
  works on \`file://\`, where Web Workers are not allowed. The plugin references
  \`https://unpkg.com/iframe-worker/shim\`; the build hook rewrites that to this
  local copy on every page.
EOF

echo "== done"
ls -l "$DEST"
