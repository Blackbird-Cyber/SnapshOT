# SnapshOT desktop

The live and installed systems boot into Xfce 4.20 with a dark, Kali-style
desktop: the **SnapshOT-Dark** GTK/xfwm4 theme, **Papirus-Dark** icons, one top
panel with a **Whisker** menu, and the SnapshOT tools grouped into seven numbered
engagement-phase folders. Two packages own all of this:

- `packages/snapshot-themes` — the theme, icons, fonts and every system-wide Xfce
  default (`/etc/xdg`), the Qt defaults and the LightDM greeter.
- `packages/snapshot-menu` — the tool launchers, the seven folders and the root
  Xfce menu.

## Where the defaults live

Xfce reads system defaults from `/etc/xdg` on first login, so shipping files
there sets the desktop up for every new user with no per-user seeding:

| File (under `/etc/xdg`) | Sets |
|---|---|
| `xfce4/panel/default.xml` | the single top panel and its plugins |
| `xfce4/xfconf/.../xsettings.xml` | theme, icons, fonts, hinting |
| `xfce4/xfconf/.../xfwm4.xml` | window-manager theme, titlebar, workspaces |
| `xfce4/xfconf/.../xfce4-desktop.xml` | desktop icons (not the wallpaper) |
| `xfce4/xfconf/.../xfce4-power-manager.xml` | power/lid/battery behaviour |
| `xfce4/xfconf/.../xfce4-screensaver.xml` | idle blank and lock |
| `xfce4/xfconf/.../xfce4-keyboard-shortcuts.xml` | shortcuts (stock + SnapshOT) |
| `xfce4/whiskermenu/defaults.rc` | the Whisker menu button and favourites |
| `xfce4/terminal/terminalrc` | xfce4-terminal colours |
| `qt5ct/qt5ct.conf`, `qt6ct/qt6ct.conf` | dark Qt (Fusion + SnapshOT-Dark palette) |
| `menus/xfce-applications.menu` | the root menu layout (snapshot-menu) |
| `menus/applications-merged/snapshot.menu` | the seven SnapshOT folders |

The wallpaper is **not** set in `xfce4-desktop.xml`: xfdesktop keys backdrops by
monitor name, so a fixed stanza would miss differently-named monitors. Instead
xfdesktop's compiled-in fallback backdrop `/usr/share/backgrounds/xfce/xfce-x.svg`
is diverted to the SnapshOT wallpaper (see below).

## Diverts and why

Several of these files are owned by other packages. Because the image installs no
recommends and is never apt-upgraded (it is re-imaged), SnapshOT uses
`dpkg-divert` to replace them the way Kali's `kali-themes` does — the owning
package's copy is renamed to `<file>.distrib` and the SnapshOT copy wins, in
either install order.

`snapshot-themes` (preinst/postrm, `FILES_TO_DIVERT`):

- `/usr/share/backgrounds/xfce/xfce-x.svg` — xfdesktop (wallpaper fallback)
- `/etc/xdg/xfce4/panel/default.xml` — xfce4-panel
- `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml` — xfce4-settings
- `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml` — libxfce4ui-common
- `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml` — xfce4-power-manager
- `/etc/xdg/xfce4/whiskermenu/defaults.rc` — xfce4-whiskermenu-plugin

`snapshot-menu` (preinst/postrm):

- `/etc/xdg/menus/xfce-applications.menu` — libgarcon-common

The other `/etc/xdg` files above (xfwm4.xml, xfce4-desktop.xml,
xfce4-screensaver.xml, terminalrc, the Qt confs) are not owned by any package we
install, so they ship directly with no divert.

## The menu

The diverted root `xfce-applications.menu` owns the single `<Layout>`: the seven
`SnapshOT-*` folders at the top, then **Usual Applications** (the stock Xfce
categories, nested) and **Settings**. The seven folder `<Menu>` blocks are merged
in from `applications-merged/snapshot.menu`; Xfce (garcon) finds that directory by
stripping the `xfce-` menu prefix.

Each folder collects its `X-SnapshOT-*` launchers plus the matching upstream GUI
tool (e.g. Wireshark in *Traffic Analysis*, gqrx/GRC in *Wireless & SDR*). Those
upstream tools are `<Exclude>`d from the relevant **Usual Applications** sub-menu
so they are not listed twice. (LibreOffice Writer is intentionally left in both
*Office* and *Reporting*.)

### Adding a launcher

1. Add a `.desktop` file under
   `packages/snapshot-menu/rootfs/usr/share/applications/`. CLI tools use
   `Terminal=true` and `Exec=/usr/share/snapshot-menu/exec-in-shell "<cmd>"`
   (which keeps the output on screen). A vendor-layer tool is always reached by
   its absolute per-tool wrapper path `/opt/snapshot/<tool>/bin/<cmd>` in both
   `Exec` and `TryExec`, never `/opt/snapshot/venv/...` or a bare path — the
   wrapper sets the tool's runtime up and the `TryExec` hides the entry when the
   vendor layer is absent. `check-desktop.sh` enforces this. See
   [`docs/vendoring.md`](vendoring.md).
2. Put the folder's category in `Categories=` (e.g. `X-SnapshOT-Recon;`).
3. If it is an upstream GUI tool pulled into a folder, add a `<Filename>` to that
   folder's `<Or>` in `applications-merged/snapshot.menu` and an `<Exclude>` in the
   matching Usual Applications sub-menu of `xfce-applications.menu`.
4. Run `scripts/check-desktop.sh`.

## Changing the theme

The GTK/xfwm4 theme lives at
`packages/snapshot-themes/rootfs/usr/share/themes/SnapshOT-Dark/` and is vendored
from Kali's `Kali-Red-Dark` by `packages/snapshot-themes/scripts/import-theme.sh`
(records version/URL/sha256 in `THEME-ORIGIN.md`). To refresh or re-derive it,
run that script; it strips the trademarked logo assets and recolours the accent to
`#f1000e`. To point the desktop at a different theme, change `Net/ThemeName` in
`xsettings.xml`, `theme` in `xfwm4.xml` and `theme-name` in the greeter config.

## Validating

`scripts/check-desktop.sh` runs in a `debian:trixie` container and:

- runs `desktop-file-validate` on every `.desktop` (the `X-SnapshOT-*` category
  hints are expected),
- runs `xmllint --noout` on every `.xml`/`.menu`,
- parses the staged menu with `python3-xdg` and asserts the seven folders are
  populated and that Usual Applications does not re-list the pulled-in tools.

It exits non-zero on any error.
