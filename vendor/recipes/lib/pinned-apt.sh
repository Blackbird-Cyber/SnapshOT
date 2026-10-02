# Sourced by vendor/recipes/*.sh inside a throwaway debian:trixie container.
# Points apt at the SnapshOT snapshot pin only and downgrades the base image to
# it, so anything built here links against exactly the libraries the image
# ships. Plain http on purpose: debian:trixie has no CA bundle, and apt checks
# the signed InRelease with debian-archive-keyring either way.
: "${SNAPSHOT_DEBIAN_PIN:?}"; DIST="${SNAPSHOT_DIST:-trixie}"
export DEBIAN_FRONTEND=noninteractive
rm -f /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list
cat > /etc/apt/sources.list <<EOF
deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/${SNAPSHOT_DEBIAN_PIN}/ ${DIST} main
deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/${SNAPSHOT_DEBIAN_PIN}/ ${DIST}-updates main
deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/${SNAPSHOT_DEBIAN_PIN}/ ${DIST}-security main
EOF
printf 'Package: *\nPin: origin "snapshot.debian.org"\nPin-Priority: 1001\n' > /etc/apt/preferences.d/snapshot-pin
apt-get -o Acquire::Retries=5 update -qq
apt-get -y -qq --allow-downgrades dist-upgrade >/dev/null
pinned_install() { apt-get -o Acquire::Retries=5 install -y -qq --no-install-recommends "$@" >/dev/null; }
