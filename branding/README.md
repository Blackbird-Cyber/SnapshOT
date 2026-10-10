# SnapshOT branding

SnapshOT is a product of Blackbird Cyber. This directory is the source of truth
for brand assets; the copies inside `packages/*/rootfs` are derived from here.

## Name
- Written form: **SnapshOT** (capital OT, as in operational technology). Use it in
  docs, installer strings, the GRUB title, the ISO label.
- Machine form: `snapshot` (package names, hostname, username, paths, env prefix).
- Never `snapshOT` in text. The logo is its own thing and is used as drawn.

## Palette
| Role | Hex |
|---|---|
| Signal red | `#F1000E` |
| Ink (backgrounds) | `#0A0B0C` |
| Black | `#000000` |
| Light (text on ink) | `#F4F5F6` |

Red on ink is for headings, highlights, and the selected item. Body text on ink
is Light. Type is Space Grotesk 500 (SIL Open Font License); it is not shipped in
the image, so text is always rendered from PNG exports, never from the SVGs.

## Assets (`exports/`)
- `snapshot-lockup-*`: horizontal lockup, wordmark + mark, 2400px PNG + SVG.
  `red-transparent` is light wordmark + red OT + red mark on alpha (the one to
  use on ink). `on-black` / `on-white` carry a solid background.
- `snapshot-mark-*`: the mark alone (viewfinder corners around a captured
  frame with a 45° stencil cut), 1024px PNG + SVG.
- `snapshot-icon-*`: the mark on a padded 1:1 tile (app icon, GRUB, avatar).
- `favicon/`: red-on-black tile at 16–512px.
- SVGs are the designer's exports with the embedded C2PA manifest stripped.
  Lockup SVGs still contain live `<text>`; outline before using them anywhere
  the font is not installed.

## Splash (`splash/`)
`snapshot-splash-2000x1125.png` is the approved title card (lockup, red rule,
"[ MADE BY ] BLACKBIRD"). The Blackbird mark exists only inside this raster;
there is no vector for it yet. `snapshot-splash-1920x1080.png` is the same
image resampled to 16:9 HD.

## Where each asset is used
| Slot | File in the tree | Source |
|---|---|---|
| Plymouth boot splash | `packages/snapshot-boot/rootfs/usr/share/plymouth/themes/snapshot/lockup.png` | `exports/snapshot-lockup-red-transparent.png` |
| GRUB theme background (installed) | `packages/snapshot-boot/rootfs/boot/grub/themes/snapshot/background.png` | `splash/snapshot-splash-1920x1080.png` |
| Live ISO boot menu background | `config/bootloaders/grub-pc/splash.png` | `splash/snapshot-splash-1920x1080.png` |
| Wallpaper + LightDM | `packages/snapshot-themes/rootfs/usr/share/backgrounds/snapshot/snapshot-default.png` | `splash/snapshot-splash-1920x1080.png` |
| xfdesktop default backdrop (diverted) | `packages/snapshot-themes/rootfs/usr/share/backgrounds/xfce/xfce-x.svg` | same PNG, base64-embedded in an SVG wrapper |
| App icon (hicolor) | `packages/snapshot-themes/rootfs/usr/share/icons/hicolor/*/apps/snapshot.*` | `exports/favicon/`, `exports/snapshot-icon-red-on-black.svg` |
| Whisker menu button (panel) | `packages/snapshot-themes/rootfs/usr/share/icons/hicolor/scalable/apps/snapshot-panel-menu.svg` | `exports/snapshot-mark-red-transparent.svg` |
| Greeter user avatar (`default-user-image = #snapshot`) | the hicolor `snapshot` app icon above (referenced by name) | `exports/favicon/`, `exports/snapshot-icon-red-on-black.svg` |
| Calamares logo / icon / slideshow | `packages/calamares-settings-snapshot/rootfs/etc/calamares/branding/snapshot/{logo.svg,icon.svg,welcome.png}` | mark-red-transparent, icon-red-on-black, lockup-red-transparent |
| Calamares welcome banner | `packages/calamares-settings-snapshot/rootfs/etc/calamares/branding/snapshot/banner.png` | welcome.png scaled to 520 px wide (`sips -Z 520`) |

Committed assets are fixed files so the build stays reproducible. If an asset
changes, update it here first, then copy it to the slots above.
