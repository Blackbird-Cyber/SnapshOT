# SnapshOT desktop

The live and installed systems boot into Xfce 4.20 with a dark, Kali-style
desktop: the **SnapshOT-Dark** GTK/xfwm4 theme, **Papirus-Dark** icons, one top
panel with a **Whisker** menu, and the SnapshOT tools grouped into eight numbered
engagement-phase folders. Two packages own all of this:

- `packages/snapshot-themes` — the theme, icons, fonts and every system-wide Xfce
  default (`/etc/xdg`), the Qt defaults and the LightDM greeter.
- `packages/snapshot-menu` — the tool launchers, the eight folders and the root
  Xfce menu. All launchers live here, including those for tools other SnapshOT
  packages ship (the field kit's in `snapshot-fieldkit`, the wiki's in
  `snapshot-wiki`).

`packages/snapshot-wiki` adds the default-browser settings (`helpers.rc`,
`mimeapps.list`) alongside the wiki itself; see [wiki.md](wiki.md).

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
| `menus/applications-merged/snapshot.menu` | the eight SnapshOT folders |
| `xfce4/helpers.rc` | Preferred Applications: the web browser `exo-open --launch WebBrowser` starts (snapshot-wiki) |
| `mimeapps.list` | HTML and http(s) links open in `firefox-esr.desktop` (snapshot-wiki) |

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

`snapshot-wiki` (preinst/postinst/postrm):

- `/etc/xdg/xfce4/helpers.rc`, owned by xfce4-helpers (Preferred Applications)

This one is done differently. `helpers.rc` is a conffile of xfce4-helpers, and
shipping a second conffile at the diverted path makes dpkg stop with a
"deleted since installation?" prompt whenever xfce4-helpers is already
configured (for example when a field update adds `snapshot-wiki` to an
installed system). So `snapshot-wiki` ships its copy as
`/usr/share/snapshot-wiki/xfce4-helpers.rc`, preinst diverts the original to
`helpers.rc.distrib`, postinst makes `/etc/xdg/xfce4/helpers.rc` a symlink to
the copy, and postrm removes the symlink before removing the divert.
(`snapshot-menu` and `snapshot-themes` ship at the diverted path; that works for
the image build, which installs everything in one transaction, but they would
hit the same prompt if first installed over an already configured owner.)

The copy keeps xfce4-helpers' keys (so Ctrl+Alt+T's TerminalEmulator is
unchanged) with `WebBrowser=debian-sensible-browser`. The `firefox` helper in
`/usr/share/xfce4/helpers/firefox.desktop` cannot be used: its
`X-XFCE-Binaries` are `firefox;firefox-gtk2;firefox-gtk;mozilla-firefox;org.mozilla.firefox;`,
without `firefox-esr`. `debian-sensible-browser` runs `sensible-browser`, which
runs `x-www-browser`, the alternative `firefox-esr` registers. `sensible-browser`
comes from `sensible-utils`, which is Priority important and so already in the
debootstrap base (the arm64 ISO's `live/filesystem.packages` lists it);
`snapshot-wiki` depends on it as well, so the chain does not rest on that.
`scripts/check-firefox-quiet.sh` checks this chain.

The other `/etc/xdg` files above (xfwm4.xml, xfce4-desktop.xml,
xfce4-screensaver.xml, terminalrc, the Qt confs, mimeapps.list) are not owned by
any package we install, so they ship directly with no divert.

## The menu

The diverted root `xfce-applications.menu` owns the single `<Layout>`: the eight
`SnapshOT-*` folders at the top, then **Usual Applications** (the stock Xfce
categories, nested) and **Settings**. The eight folder `<Menu>` blocks are merged
in from `applications-merged/snapshot.menu`; Xfce (garcon) finds that directory by
stripping the `xfce-` menu prefix.

Each folder collects its `X-SnapshOT-*` launchers plus the matching upstream GUI
tool (e.g. Wireshark in *Traffic Analysis*, gqrx in *Wireless & SDR*). Those
upstream tools are `<Exclude>`d from the relevant **Usual Applications** sub-menu
so they are not listed twice. (LibreOffice Writer is intentionally left in both
*Office* and *Reporting*.)

The folders are 01 Recon & Discovery, 02 Traffic Analysis, 03 Protocol Tools,
04 Firmware & Hardware, 05 Wireless & SDR, 06 Forensics & Response, 07 Reporting
& Documentation and 08 Reference. 06 Forensics & Response holds the field kit
launchers (Prepare Field Kit USB, Import Field Kit results, Field Kit folder,
Field Kit guide; see [`docs/fieldkit.md`](fieldkit.md)) and Autopsy and The
Sleuth Kit, which moved there from Reporting in snapshot-menu 0.2.3.
05 Wireless & SDR is strictly receive-only (snapshot-menu 0.2.4): airodump-ng
for the passive 802.11 survey, a dongle check (rtl_eeprom, since snapshot-menu
0.2.6; rtl_test -t only benchmarked E4000 tuners) and rtl_power for RTL-SDR
dongles, and gqrx. The HackRF, GNU Radio Companion and SoapySDR entries were
dropped with their packages, and the aircrack-ng key-cracking entry went with
them (the package stays because airodump-ng lives in it); the image never
transmits on radio.
01 Recon & Discovery's *mDNS listen (passive)* runs the package's `mdns-listen`
helper, a tshark capture on udp 5353 on the one interface that is up (or one the
operator picks), because avahi-daemon is masked and avahi-browse cannot work.

08 Reference holds the offline reference folder, the build manifest and the
**SnapshOT Wiki** (`snapshot-wiki.desktop`, snapshot-menu 0.2.7), which runs
`exo-open --launch WebBrowser file:///usr/share/snapshot/wiki/index.html`. The
Whisker favourites list it after the two terminals (snapshot-themes 0.2.1).
Firefox ESR itself is a general browser, not a SnapshOT tool, so it stays in
Usual Applications (Internet).

### Adding a launcher

1. Add a `.desktop` file under
   `packages/snapshot-menu/rootfs/usr/share/applications/`. CLI tools use
   `Terminal=true` and `Exec=/usr/share/snapshot-menu/exec-in-shell "<cmd>"`
   (which keeps the output on screen; Ctrl-C stops the tool and still leaves the
   operator in the shell). A vendor-layer tool is always reached by
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
  hints are expected), including snapshot-wiki's files,
- fails if a launcher retired in snapshot-menu 0.2.4 is back (HackRF, SoapySDR,
  aircrack-ng, avahi-browse) or the menu still pulls in GNU Radio Companion, and
  checks that the `exec-in-shell` and `mdns-listen` helpers are executable and parse,
- runs `xmllint --noout` on every `.xml`/`.menu`,
- parses the staged menu with `python3-xdg` and asserts the eight folders are
  populated (the wiki launcher in 08 - Reference), that Usual Applications does
  not re-list the pulled-in tools, and that it does list Firefox ESR (stubbed
  as `firefox-esr.desktop` with `Network;WebBrowser;`).

It exits non-zero on any error.

`scripts/check-wiki.sh` checks the other direction: that every tool launcher is
documented by exactly one wiki page, in the right folder, and that the wiki
launcher validates and opens the wiki ([wiki.md](wiki.md)).
