#!/usr/bin/env bash
# Static checks for the SnapshOT desktop packages (snapshot-themes, snapshot-menu,
# and the desktop files snapshot-wiki ships).
# Runs in a debian:trixie container so the validators and pyxdg match the target.
#
#   scripts/check-desktop.sh
#
# It does three things and exits non-zero on any error:
#   1. desktop-file-validate every *.desktop (X-SnapshOT-* category hints/warnings
#      are expected; errors are not).
#   2. xmllint --noout every *.xml / *.menu (well-formedness).
#   3. Parse the staged menu tree with python3-xdg and assert the eight SnapshOT
#      folders hold the expected entries and that "Usual Applications" does NOT
#      also list the upstream tools pulled into those folders.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${SNAPSHOT_TRIXIE_IMAGE:-debian:trixie}"

docker run --rm -i -v "$ROOT":/snapshot:ro "$IMAGE" bash -s <<'CONTAINER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    desktop-file-utils libxml2-utils python3-xdg libgarcon-common >/dev/null

THEMES=/snapshot/packages/snapshot-themes/rootfs
MENU=/snapshot/packages/snapshot-menu/rootfs
WIKI=/snapshot/packages/snapshot-wiki/rootfs
fail=0

echo "== desktop-file-validate =="
while IFS= read -r f; do
    out="$(desktop-file-validate "$f" 2>&1 || true)"
    err="$(printf "%s\n" "$out" | grep -viE "warning|hint" | grep -v "^$" || true)"
    if [ -n "$err" ]; then echo "ERROR $f:"; printf "%s\n" "$err"; fail=1; fi
done < <(find "$THEMES" "$MENU" "$WIKI" -name "*.desktop" | sort)

echo "== vendor path policy =="
# Every /opt/snapshot reference in a launcher must be the per-tool wrapper form
# /opt/snapshot/<tool>/bin/<cmd> (e.g. /opt/snapshot/zeek/bin/zeek); the old
# /opt/snapshot/venv/... paths and bare tool paths are gone. Fail if any remain.
viol="$(
    grep -rhoE '/opt/snapshot/[A-Za-z0-9._/-]+' "$MENU/usr/share/applications" 2>/dev/null \
        | grep -vE '^/opt/snapshot/[a-z0-9-]+/bin/[A-Za-z0-9._-]+$' || true
    grep -rhoE '/opt/snapshot/venv[A-Za-z0-9._/-]*' "$MENU/usr/share/applications" 2>/dev/null || true
)"
if [ -n "$viol" ]; then
    echo "ERROR: launcher path is not /opt/snapshot/<tool>/bin/<cmd>:"
    printf "%s\n" "$viol" | sort -u | sed 's/^/  /'
    fail=1
else
    echo "all /opt/snapshot launcher paths use <tool>/bin/<cmd>"
fi

echo "== xmllint =="
while IFS= read -r f; do
    if ! xmllint --noout --nonet "$f" 2>/tmp/xmlerr; then
        echo "ERROR $f:"; cat /tmp/xmlerr; fail=1
    fi
done < <(find "$THEMES" "$MENU" "$WIKI" \( -name "*.xml" -o -name "*.menu" \) | sort)

echo "== staging menu tree =="
STAGE=/tmp/stage
mkdir -p "$STAGE/config" "$STAGE/data/applications" "$STAGE/data/desktop-directories"
cp -a "$MENU/etc/xdg/." "$STAGE/config/"
cp -a "$MENU/usr/share/applications/." "$STAGE/data/applications/" 2>/dev/null || true
cp -a "$MENU/usr/share/desktop-directories/." "$STAGE/data/desktop-directories/" 2>/dev/null || true
cp -a /usr/share/desktop-directories/. "$STAGE/data/desktop-directories/" 2>/dev/null || true
# pyxdg derives the merge-dir from the menu file's basename, so it would look for
# xfce-applications-merged/. The real Xfce (garcon) strips the XDG_MENU_PREFIX and
# merges applications-merged/. Parse a prefix-less copy to replicate that: basename
# "applications" -> applications-merged/ (where snapshot.menu already lives).
cp "$STAGE/config/menus/xfce-applications.menu" "$STAGE/config/menus/applications.menu"

# Stub the upstream GUI tools (real packages are not installed here) with their
# real Categories so the menu include/exclude logic can be exercised.
stub() { printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nIcon=%s\nCategories=%s\n' \
    "$2" "${2%% *}" "$2" "$3" > "$STAGE/data/applications/$1"; }
stub org.wireshark.Wireshark.desktop Wireshark "Network;Monitor;Qt;"
stub dk.gqrx.gqrx.desktop gqrx "AudioVideo;Audio;Qt;HamRadio;"
stub gnuradio-grc.desktop "GNU Radio Companion" "Development;HamRadio;Science;"
stub org.sigrok.PulseView.desktop PulseView "Development;Electronics;"
stub cherrytree.desktop CherryTree "GNOME;GTK;Utility;"
stub org.flameshot.Flameshot.desktop Flameshot "Graphics;"
stub org.keepassxc.KeePassXC.desktop KeePassXC "Utility;Security;Qt;"
stub libreoffice-writer.desktop "LibreOffice Writer" "Office;WordProcessor;"
stub firefox-esr.desktop "Firefox ESR" "Network;WebBrowser;"
stub qt5ct.desktop "Qt5 Settings" "Settings;DesktopSettings;Qt;"
stub qt6ct.desktop "Qt6 Settings" "Settings;DesktopSettings;Qt;"

echo "== menu parse =="
XDG_MENU_PREFIX="" \
XDG_CONFIG_DIRS="$STAGE/config:/etc/xdg" \
XDG_DATA_DIRS="$STAGE/data:/usr/share" \
python3 - "$STAGE/config/menus/applications.menu" <<"PY" || fail=1
import sys
import xdg.Menu
from xdg.Menu import Menu, MenuEntry

menu = xdg.Menu.parse(sys.argv[1])

def ids_recursive(m):
    out = []
    for e in m.getEntries(show_hidden=True):
        if isinstance(e, MenuEntry):
            out.append(e.DesktopFileID)
        elif isinstance(e, Menu):
            out += ids_recursive(e)
    return out

def submenus(m):
    return {e.getName(): e for e in m.getEntries(show_hidden=True) if isinstance(e, Menu)}

def walk(m, depth=0):
    for e in m.getEntries(show_hidden=True):
        if isinstance(e, Menu):
            print("  " * depth + "[" + e.getName() + "]")
            walk(e, depth + 1)
        elif isinstance(e, MenuEntry):
            print("  " * depth + "- " + e.DesktopEntry.getName() + "  (" + e.DesktopFileID + ")")

print("---- menu tree ----")
walk(menu)
print("-------------------")

top = submenus(menu)
problems = []

expected = {
    "01 - Recon & Discovery":         ["snapshot-nmap.desktop"],
    "02 - Traffic Analysis":          ["snapshot-tshark.desktop", "org.wireshark.Wireshark.desktop"],
    "03 - Protocol Tools":            ["snapshot-mbpoll.desktop"],
    "04 - Firmware & Hardware":       ["snapshot-binwalk.desktop", "org.sigrok.PulseView.desktop"],
    "05 - Wireless & SDR":            ["snapshot-aircrack-ng.desktop", "dk.gqrx.gqrx.desktop", "gnuradio-grc.desktop"],
    "06 - Forensics & Response":      ["snapshot-autopsy.desktop", "snapshot-sleuthkit.desktop",
                                       "snapshot-fieldkit-prep.desktop", "snapshot-fieldkit-import.desktop",
                                       "snapshot-fieldkit-folder.desktop", "snapshot-fieldkit-guide.desktop"],
    "07 - Reporting & Documentation": ["snapshot-pandoc.desktop", "cherrytree.desktop",
                                       "org.flameshot.Flameshot.desktop", "org.keepassxc.KeePassXC.desktop",
                                       "libreoffice-writer.desktop"],
    "08 - Reference":                 ["snapshot-build-manifest.desktop", "snapshot-wiki.desktop"],
}
for name, want in expected.items():
    if name not in top:
        problems.append("missing SnapshOT folder: " + name)
        continue
    have = set(ids_recursive(top[name]))
    for w in want:
        if w not in have:
            problems.append(name + ": expected entry " + w + " not present")

# Moved out of Reporting into Forensics & Response (snapshot-menu 0.2.3).
for name, gone in {"07 - Reporting & Documentation": ["snapshot-autopsy.desktop",
                                                       "snapshot-sleuthkit.desktop"]}.items():
    if name in top:
        for g in sorted(set(ids_recursive(top[name])) & set(gone)):
            problems.append(name + ": " + g + " should be in 06 - Forensics & Response only")

ua = top.get("Usual Applications")
if ua is None:
    problems.append("missing Usual Applications menu")
else:
    leaked = set(ids_recursive(ua)) & {
        "org.wireshark.Wireshark.desktop", "dk.gqrx.gqrx.desktop",
        "org.sigrok.PulseView.desktop", "gnuradio-grc.desktop",
        "cherrytree.desktop", "org.flameshot.Flameshot.desktop",
        "org.keepassxc.KeePassXC.desktop",
    }
    if leaked:
        problems.append("Usual Applications still lists: " + ", ".join(sorted(leaked)))
    # Firefox ESR is a general browser, not a SnapshOT tool: it stays in
    # Usual Applications (Network); the wiki launcher is the Reference entry.
    if "firefox-esr.desktop" not in set(ids_recursive(ua)):
        problems.append("Usual Applications does not list firefox-esr.desktop")

if problems:
    print("MENU CHECK FAILED:")
    for p in problems:
        print("  - " + p)
    sys.exit(1)
print("menu check OK: eight folders populated, Usual Applications clean")
PY

if [ "$fail" -ne 0 ]; then echo "== check-desktop: FAIL =="; exit 1; fi
echo "== check-desktop: OK =="
CONTAINER
