#!/usr/bin/env bash
# Prove Firefox ESR stays quiet on the wire with snapshot-wiki's policy, in a
# debian:trixie container (slow: about two minutes; not part of the build).
#
#   scripts/check-firefox-quiet.sh
#
# It installs firefox-esr, builds the wiki into /usr/share/snapshot/wiki and
# copies snapshot-wiki's /etc files into place, then:
#   1. screenshots about:policies to build/firefox-quiet/about-policies.png
#      (for review) and fails if Firefox logs any policy error;
#   2. checks the default-browser chain the wiki launcher uses: helpers.rc's
#      WebBrowser helper -> its binary -> x-www-browser -> firefox-esr;
#   3. runs Firefox headless on the wiki for 45 seconds under
#      tcpdump -i any 'not host 127.0.0.1 and not host ::1' and fails on any
#      packet. The container has a working network, so an attempted
#      connection or DNS lookup would be captured.
# Exits non-zero on any failure.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${SNAPSHOT_TRIXIE_IMAGE:-debian:trixie}"
PLATFORM="${SNAPSHOT_CHECK_PLATFORM:-linux/arm64}"
SECONDS_ON_WIRE="${SNAPSHOT_QUIET_SECONDS:-45}"
OUT="$ROOT/build/firefox-quiet"
mkdir -p "$OUT"

docker run --rm -i --platform "$PLATFORM" --cap-add NET_RAW --cap-add NET_ADMIN \
    -e SECONDS_ON_WIRE="$SECONDS_ON_WIRE" \
    -v "$ROOT":/snapshot:ro -v "$OUT":/out "$IMAGE" bash -s <<'CONTAINER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    firefox-esr xfce4-helpers sensible-utils tcpdump \
    mkdocs-material python3-pymdownx python3-yaml fonts-cantarell fonts-firacode >/dev/null
fail=0

echo "== installing the wiki and snapshot-wiki's /etc files =="
cp -a /snapshot/packages/snapshot-wiki /tmp/wiki && rm -rf /tmp/wiki/build
( cd /tmp/wiki && mkdocs build --strict -q -d /usr/share/snapshot/wiki )
# The divert is the package's job; here the copy simply replaces the file.
cp -a /tmp/wiki/rootfs/. /
ls /etc/firefox/policies/policies.json /etc/firefox-esr/snapshot-quiet.js \
   /etc/xdg/xfce4/helpers.rc /etc/xdg/mimeapps.list

export HOME=/tmp/home
mkdir -p "$HOME"
newprofile() { rm -rf /tmp/prof && mkdir -p /tmp/prof; }

echo "== about:policies =="
newprofile
# Route the policy engine's log to stdout so errors can be checked.
cat > /tmp/prof/user.js <<'EOF'
user_pref("devtools.console.stdout.chrome", true);
user_pref("browser.policies.loglevel", "warn");
EOF
timeout 90 firefox-esr --headless --no-remote --profile /tmp/prof --window-size 1280,2400 \
    --screenshot /out/about-policies.png about:policies >/tmp/policies.log 2>&1 || true
if [ -s /out/about-policies.png ]; then
    echo "screenshot: build/firefox-quiet/about-policies.png"
else
    echo "ERROR: no about:policies screenshot"; fail=1
fi
if grep -A1 -E 'Policies:' /tmp/policies.log | grep -v -E '^--$|Policies:' | grep .; then
    echo "ERROR: Firefox reported the policy errors above"; fail=1
else
    echo "no policy errors"
fi

echo "== default browser chain =="
helper="$(sed -n 's/^WebBrowser=//p' /etc/xdg/xfce4/helpers.rc)"
desktop="/usr/share/xfce4/helpers/$helper.desktop"
if [ ! -f "$desktop" ]; then
    echo "ERROR: helpers.rc WebBrowser=$helper but $desktop does not exist"; fail=1
else
    found=""
    for bin in $(sed -n 's/^X-XFCE-Binaries=//p' "$desktop" | tr ';' ' '); do
        command -v "$bin" >/dev/null 2>&1 && { found="$bin"; break; }
    done
    browser="$(readlink -f "$(command -v x-www-browser)")"
    echo "WebBrowser=$helper -> ${found:-no binary found} -> x-www-browser -> $browser"
    [ -n "$found" ] || { echo "ERROR: none of the helper's binaries is installed"; fail=1; }
    case "$browser" in */firefox-esr) ;; *) echo "ERROR: x-www-browser is not firefox-esr"; fail=1 ;; esac
fi
grep -q '^text/html=firefox-esr.desktop' /etc/xdg/mimeapps.list || { echo "ERROR: mimeapps.list"; fail=1; }

echo "== ${SECONDS_ON_WIRE}s of Firefox on the wiki under tcpdump =="
echo "nameserver(s): $(awk '/^nameserver/{print $2}' /etc/resolv.conf | tr '\n' ' ')"
ip -brief address 2>/dev/null || true
newprofile
tcpdump -i any -n -p -U -w /tmp/quiet.pcap 'not host 127.0.0.1 and not host ::1' 2>/tmp/tcpdump.log &
dump=$!
sleep 3
timeout "$SECONDS_ON_WIRE" firefox-esr --headless --no-remote --profile /tmp/prof \
    file:///usr/share/snapshot/wiki/index.html >/tmp/firefox.log 2>&1 || true
sleep 2
kill -INT "$dump"; wait "$dump" || true
cp /tmp/quiet.pcap /out/quiet.pcap
tcpdump -n -r /tmp/quiet.pcap > /tmp/quiet.txt 2>/dev/null || true
packets="$(wc -l < /tmp/quiet.txt)"
if [ "$packets" -eq 0 ]; then
    echo "0 packets left the machine (capture: build/firefox-quiet/quiet.pcap)"
else
    echo "ERROR: $packets packets captured (build/firefox-quiet/quiet.pcap); DNS names asked for:"
    grep -oE '(A|AAAA)\? [^ ]+' /tmp/quiet.txt | sort | uniq -c || true
    sed -n '1,20p' /tmp/quiet.txt
    fail=1
fi

if [ "$fail" -ne 0 ]; then echo "== check-firefox-quiet: FAIL =="; exit 1; fi
echo "== check-firefox-quiet: OK =="
CONTAINER
