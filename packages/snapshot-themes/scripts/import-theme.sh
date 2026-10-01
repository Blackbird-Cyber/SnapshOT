#!/usr/bin/env bash
# Re-import the vendored GTK/xfwm4 theme from Kali's kali-themes-common.
#
# Developer-time only: needs network, run once, and the RESULT is committed
# (rootfs/usr/share/themes/SnapshOT-Dark/). The Kali pool keeps only the current
# version, so the committed files -- not this script -- are the source of truth.
#
# What it does:
#   1. Download kali-themes-common_<VER>_all.deb and verify its sha256.
#   2. Extract usr/share/themes/Kali-Red-Dark/{gtk-3.0,gtk-4.0,xfwm4}.
#   3. Strip the four trademarked kali-headerbar-logo*.png assets and remove the
#      logo image layers from the headerbar CSS rules (gradient/colour kept).
#   4. Recolour the red accent #ec0101 -> #f1000e (brand signal red). The darker
#      shades (#b90101, #540000) are left alone.
#   5. Write our own index.theme and drop the result into the package rootfs.
#
# Metadata (URL, version, sha256) is recorded in ../THEME-ORIGIN.md; keep the
# values below in sync with it.
set -euo pipefail

KALI_VER="2026.3.0"
DEB="kali-themes-common_${KALI_VER}_all.deb"
URL="http://http.kali.org/kali/pool/main/k/kali-themes/${DEB}"
SHA256="037c921083e01837c94e17d970e629dfea7c13bc29f97bfba020e4213fc00f6d"

SRC_THEME="Kali-Red-Dark"
DST_THEME="SnapshOT-Dark"
ACCENT_FROM="#ec0101"
ACCENT_TO="#f1000e"

HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
DEST="$PKG/rootfs/usr/share/themes/$DST_THEME"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== fetching $DEB"
if [ -f "$HERE/$DEB" ]; then
    cp "$HERE/$DEB" "$WORK/$DEB"
else
    curl -fL --retry 3 -o "$WORK/$DEB" "$URL"
fi

echo "== verifying sha256"
if command -v sha256sum >/dev/null 2>&1; then
    echo "$SHA256  $WORK/$DEB" | sha256sum -c -
else
    got="$(shasum -a 256 "$WORK/$DEB" | awk '{print $1}')"
    [ "$got" = "$SHA256" ] || { echo "sha256 mismatch: $got != $SHA256" >&2; exit 1; }
    echo "$DEB: OK"
fi

echo "== extracting $SRC_THEME"
mkdir -p "$WORK/x"
if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb -x "$WORK/$DEB" "$WORK/x"
else
    # macOS / no dpkg: a .deb is an ar(1) archive of data.tar.{xz,zst}.
    ( cd "$WORK" && ar x "$DEB" )
    data="$(ls "$WORK"/data.tar.* | head -n1)"
    tar -xf "$data" -C "$WORK/x"
fi

SRC="$WORK/x/usr/share/themes/$SRC_THEME"
[ -d "$SRC" ] || { echo "missing $SRC in deb" >&2; exit 1; }

echo "== staging $DST_THEME"
rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$SRC/gtk-3.0" "$SRC/gtk-4.0" "$SRC/xfwm4" "$DEST/"

echo "== stripping trademarked headerbar logo assets"
rm -f "$DEST"/gtk-3.0/assets/kali-headerbar-logo*.png \
      "$DEST"/gtk-4.0/assets/kali-headerbar-logo*.png

for css in "$DEST/gtk-3.0/gtk.css" "$DEST/gtk-4.0/gtk.css"; do
    echo "== rewriting $(basename "$(dirname "$css")")/gtk.css"
    perl -0777 -i -pe '
      # 1. drop the logo image layer (and its trailing comma) from background:
      s/ -gtk-scaled\(url\("assets\/kali-headerbar-logo[^"]*"\), url\("assets\/kali-headerbar-logo[^"]*"\)\),//g;
      # 2. drop the backdrop background-image logo declaration plus its now
      #    pointless background-repeat/background-position lines
      s/^[ \t]*background-image: -gtk-scaled\(url\("assets\/kali-headerbar-logo[^"]*"\), url\("assets\/kali-headerbar-logo[^"]*"\)\);\n[ \t]*background-repeat: no-repeat;\n[ \t]*background-position: left;\n//mg;
      # 3. default-decoration rule: drop the leftover position/repeat for the
      #    (now removed) logo, keeping the existing background-color and brace
      s/^([ \t]*background-color: #181a20;)\n[ \t]*background-position: -35px;\n[ \t]*background-repeat: no-repeat; \}/$1 }/mg;
    ' "$css"
    # 4. recolour the red accent; leave the darker shades alone
    perl -i -pe "s/\Q$ACCENT_FROM\E/$ACCENT_TO/gi" "$css"
done

echo "== writing index.theme"
cat > "$DEST/index.theme" <<EOF
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=$DST_THEME
Comment=The SnapshOT dark theme
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=$DST_THEME
MetacityTheme=$DST_THEME
IconTheme=Papirus-Dark
CursorTheme=Adwaita
ButtonLayout=:minimize,maximize,close
EOF

# Origin/attribution note kept inside the theme (the only place "kali" is allowed
# to remain, as the upstream credit).
cat > "$DEST/ORIGIN" <<EOF
SnapshOT-Dark is derived from Kali-Red-Dark (kali-themes-common $KALI_VER),
GPL-3.0+, copyright Offensive Security; GTK theme by Daniel Ruiz de Alegria
(Flat Remix). Trademarked Kali headerbar logo assets have been removed and the
red accent recoloured to the SnapshOT brand (#f1000e). See ../../THEME-ORIGIN.md.
EOF

echo "== done: $DEST"
echo "   remaining 'kali' references (expect only ORIGIN):"
grep -ril kali "$DEST" || echo "   (none)"
