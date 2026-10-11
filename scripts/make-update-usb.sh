#!/usr/bin/env bash
# Build a signed, offline apt repository on a USB stick for in-field package
# adds, limited to the release's Debian snapshot pin and the packages you name.
# Laptops trust it only through the public half of the key that signed it. Run
# it on a networked Debian host, as the user who holds that key, with aptly,
# gnupg and debian-archive-keyring installed.
#
#   scripts/make-update-usb.sh <stick-mount> [package ...]
#
#   <stick-mount>  the mounted stick (any directory serves for a test). The
#                  repository goes to <stick-mount>/snapshot-cache, which must
#                  not exist yet or must be empty.
#   package ...    aptly package queries, usually plain package names. Only
#                  these are downloaded and published, without their
#                  dependencies, so name every package the laptop lacks. With
#                  none, the stick carries all of trixie main for each
#                  architecture. To test the script, name two or three small
#                  packages.
#
# Environment:
#   SNAPSHOT_GPG_KEY        the key that signs the repository: a key ID,
#                           fingerprint or user ID in your GnuPG keyring
#                           (GNUPGHOME applies). Unset: gpg's default key. The
#                           script never creates a key.
#   SNAPSHOT_UPDATE_ARCHES  architectures, comma separated (default amd64,arm64).
#   SNAPSHOT_UPDATE_POOL    a directory that keeps the downloaded packages
#                           between runs, so a re-run or an interrupted large run
#                           downloads only what is missing. Unset: they stay in
#                           the work directory and go with it.
#   TMPDIR                  where the work directory is made (default /var/tmp).
#                           It holds aptly's config and database and, unless
#                           SNAPSHOT_UPDATE_POOL is set, every downloaded
#                           package; it is removed when the script exits.
#
# aptly 1.6 (trixie) publishes to a local directory only through a filesystem
# endpoint in its config file, so the script writes a config of its own in the
# work directory: rootDir there, and an endpoint "stick" whose rootDir is
# <stick-mount>/snapshot-cache, with linkMethod copy because a FAT or exFAT stick
# takes neither hard links nor symlinks. ~/.aptly.conf and ~/.aptly are not used.
set -euo pipefail

die() { echo "make-update-usb: $*" >&2; exit 1; }
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    '') die "no stick given. Usage: make-update-usb.sh <stick-mount> [package ...] (--help for more)" ;;
esac
[ -d "$1" ] || die "$1 is not a directory: mount the stick and pass its mount point"
DEST="$(cd "$1" && pwd -P)"
shift
[ -w "$DEST" ] || die "$DEST is not writable"
OUT="$DEST/snapshot-cache"
if [ -e "$OUT" ] && [ -n "$(ls -A "$OUT")" ]; then
    die "$OUT already exists and is not empty: remove it, or use another stick"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=SCRIPTDIR/../config/snapshot.env disable=SC1091
. "$ROOT/config/snapshot.env"

command -v aptly >/dev/null 2>&1 || die "aptly is not installed: sudo apt-get install aptly"
command -v gpg >/dev/null 2>&1 || die "gpg is not installed: sudo apt-get install gnupg"
command -v gpgv >/dev/null 2>&1 || die "gpgv is not installed: sudo apt-get install gpgv"
DEBIAN_KEYRING=/usr/share/keyrings/debian-archive-keyring.gpg
[ -r "$DEBIAN_KEYRING" ] || die "$DEBIAN_KEYRING is missing: sudo apt-get install debian-archive-keyring"

KEY="${SNAPSHOT_GPG_KEY:-}"
if [ -n "$KEY" ]; then
    secret="$(gpg --batch --with-colons --list-secret-keys -- "$KEY" 2>/dev/null || true)"
    grep -q '^sec:' <<<"$secret" \
        || die "no secret key matches SNAPSHOT_GPG_KEY=$KEY in your GnuPG keyring (gpg --list-secret-keys)"
else
    secret="$(gpg --batch --with-colons --list-secret-keys 2>/dev/null || true)"
    grep -q '^sec:' <<<"$secret" \
        || die "no secret key to sign with in your GnuPG keyring: import or create one, or set SNAPSHOT_GPG_KEY (docs/updates.md)"
fi
SIGN=()
[ -z "$KEY" ] || SIGN=(-gpg-key="$KEY")

# Both image architectures by default, so one stick serves amd64 and arm64
# laptops (apt on the laptop fetches only its own architecture's index).
ARCHES="${SNAPSHOT_UPDATE_ARCHES:-amd64,arm64}"
[[ "$ARCHES" =~ ^[a-z0-9]+(,[a-z0-9]+)*$ ]] \
    || die "SNAPSHOT_UPDATE_ARCHES=$ARCHES is not a comma-separated list such as amd64,arm64"

WORK="$(mktemp -d "${TMPDIR:-/var/tmp}/snapshot-update-usb.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT TERM HUP
POOL="${SNAPSHOT_UPDATE_POOL:-$WORK/pool}"
mkdir -p "$POOL"
POOL="$(cd "$POOL" && pwd -P)"

json_str() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '"%s"' "$s"; }
CONF="$WORK/aptly.conf"
cat >"$CONF" <<EOF
{
  "rootDir": $(json_str "$WORK/root"),
  "skipLegacyPool": true,
  "gpgProvider": "gpg",
  "packagePoolStorage": {"type": "local", "path": $(json_str "$POOL")},
  "FileSystemPublishEndpoints": {
    "stick": {"rootDir": $(json_str "$OUT"), "linkMethod": "copy", "verifyMethod": "md5"}
  }
}
EOF
aptly_() { aptly -config="$CONF" "$@"; }

# The filter applies at download time: only the named packages are fetched.
NAME="debian-${SNAPSHOT_DEBIAN_PIN}"
FILTER=()
if [ "$#" -gt 0 ]; then
    query="$(printf '%s | ' "$@")"
    FILTER=(-filter="${query% | }")
fi
aptly_ mirror create -architectures="$ARCHES" -keyring="$DEBIAN_KEYRING" ${FILTER[@]+"${FILTER[@]}"} \
    "$NAME" "$SNAPSHOT_MIRROR_DEBIAN" "$SNAPSHOT_DIST" main
aptly_ mirror update -max-tries=3 -keyring="$DEBIAN_KEYRING" "$NAME"

missing=()
for q in "$@"; do
    aptly_ mirror search "$NAME" "$q" >/dev/null 2>&1 || missing+=("$q")
done
[ "${#missing[@]}" -eq 0 ] \
    || die "not in ${SNAPSHOT_DIST} main at the pin ${SNAPSHOT_DEBIAN_PIN} for ${ARCHES}: ${missing[*]}"

# No Contents indexes: apt does not read them, and building them for a full
# mirror means opening every package.
aptly_ snapshot create "$NAME" from mirror "$NAME"
aptly_ publish snapshot -distribution="$SNAPSHOT_DIST" -skip-contents ${SIGN[@]+"${SIGN[@]}"} \
    "$NAME" filesystem:stick:

# Check the signature the way a laptop will: against the signer's public key alone.
DIST="$OUT/dists/$SNAPSHOT_DIST"
status="$(gpg --batch --status-fd 1 --verify "$DIST/InRelease" 2>/dev/null)" \
    || die "the published $DIST/InRelease does not verify"
FPR="$(awk '$2 == "VALIDSIG" { print $NF; exit }' <<<"$status")"
[ -n "$FPR" ] || die "could not read the signing key from $DIST/InRelease"
gpg --batch --export "$FPR" >"$WORK/signer.gpg"
gpgv --keyring "$WORK/signer.gpg" "$DIST/InRelease" >/dev/null 2>&1 \
    || die "$DIST/InRelease does not verify against key $FPR alone"
gpgv --keyring "$WORK/signer.gpg" "$DIST/Release.gpg" "$DIST/Release" >/dev/null 2>&1 \
    || die "$DIST/Release.gpg does not verify against key $FPR alone"

COUNT="$(aptly_ snapshot show "$NAME" | awk -F': ' '/^Number of packages/ { print $2 }')"
SIZE="$(du -sh "$OUT" | cut -f1)"
cat <<EOF

SnapshOT update repository written to $OUT
  ${SNAPSHOT_DIST} main at the snapshot pin ${SNAPSHOT_DEBIAN_PIN}, ${ARCHES}: ${COUNT} packages, ${SIZE}
  signed by key ${FPR}

Give each laptop the public key once, by a channel other than this stick:
  gpg --export ${FPR} > snapshot-update.gpg      (here)
  sudo install -D -m 0644 snapshot-update.gpg /etc/apt/keyrings/snapshot-update.gpg      (on the laptop)

On the laptop, with the stick mounted (the desktop mounts it at /media/<user>/<label>):
  echo 'deb [signed-by=/etc/apt/keyrings/snapshot-update.gpg] file:/media/<user>/<label>/snapshot-cache ${SNAPSHOT_DIST} main' \\
    | sudo tee /etc/apt/sources.list.d/snapshot-update.list
  sudo apt-get update
  sudo apt-get install <package> ...
  sudo rm /etc/apt/sources.list.d/snapshot-update.list      (when done)
EOF
