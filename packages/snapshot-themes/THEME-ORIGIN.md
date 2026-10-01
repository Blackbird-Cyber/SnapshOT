# Vendored theme origin

`rootfs/usr/share/themes/SnapshOT-Dark/` is derived from Kali's `Kali-Red-Dark`
GTK/xfwm4 theme, re-imported by `scripts/import-theme.sh`.

| | |
|---|---|
| Upstream package | `kali-themes-common` |
| Version | `2026.3.0` |
| File | `kali-themes-common_2026.3.0_all.deb` |
| URL | `http://http.kali.org/kali/pool/main/k/kali-themes/kali-themes-common_2026.3.0_all.deb` |
| sha256 | `037c921083e01837c94e17d970e629dfea7c13bc29f97bfba020e4213fc00f6d` |
| Source theme | `usr/share/themes/Kali-Red-Dark/{gtk-3.0,gtk-4.0,xfwm4}` |

The Kali pool keeps only the current version, so this exact `.deb` may become
unavailable. The committed files under `rootfs/usr/share/themes/SnapshOT-Dark/`
are the source of truth; the script exists to reproduce or refresh them.

## Licence

`kali-themes-common` is **GPL-3.0+**, copyright Offensive Security; the GTK theme
was created by Daniel Ruiz de Alegría (Flat Remix) for Offensive Security. See
`debian/copyright`.

## Changes applied during import

1. Only `gtk-3.0`, `gtk-4.0` and `xfwm4` are taken; renamed to `SnapshOT-Dark`.
2. The four trademarked `gtk-{3,4}.0/assets/kali-headerbar-logo*.png` assets are
   deleted, and the logo image layers are removed from the headerbar CSS rules
   (the gradient/colour backgrounds are kept).
3. The red accent `#ec0101` is recoloured to the SnapshOT brand red `#f1000e`.
   The darker shades (`#b90101`, `#540000`) are left unchanged.
4. A SnapshOT `index.theme` (and an `ORIGIN` attribution note) is written.

After import, `grep -ri kali` over the theme directory matches only the `ORIGIN`
attribution note. The Kali *trademark* (graphical Kali branding) is not shipped.
