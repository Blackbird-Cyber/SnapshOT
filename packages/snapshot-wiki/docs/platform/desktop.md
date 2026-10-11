---
title: The desktop, menu and shortcuts
summary: The Xfce desktop, the eight tool folders, the Whisker menu and its favorites, the keyboard shortcuts and the field kit.
---

SnapshOT boots to an Xfce desktop with a dark theme, one panel along the top of
the screen and a Whisker menu at its left end. Every tool with a launcher is in
that menu, in eight numbered folders; a few command-line tools (QEMU, sdcc,
screen, TestDisk/PhotoRec, avahi-browse, the Redpoint scripts, the Python
libraries) are run from a terminal or through another tool. This page is the
operator's tour; the repository's `docs/desktop.md` has the detail of how it is
put together.

## The menu

Open the Whisker menu with the SnapshOT button at the left of the top panel, or
with <kbd>Alt</kbd>+<kbd>F1</kbd> or <kbd>Ctrl</kbd>+<kbd>Esc</kbd>. Start
typing to search: launchers are found by name and description, so "wiki",
"modbus" or "serial" finds the right entry without opening a folder.

The tools are in eight folders, numbered in the order an engagement uses them.
Each folder has a page in this wiki listing its tools:

| Menu folder | What is in it | In this wiki |
|---|---|---|
| 01 Recon & Discovery | host and service discovery, nmap with its ICS scripts | [Recon & Discovery](../tools/recon/index.md) |
| 02 Traffic Analysis | capture and decoding: Wireshark, tshark, tcpdump, Suricata | [Traffic Analysis](../tools/traffic/index.md) |
| 03 Protocol Tools | Modbus, S7, EtherNet/IP, OPC UA and BACnet clients | [Protocol Tools](../tools/protocols/index.md) |
| 04 Firmware & Hardware | flash and JTAG readers, logic analyzers, serial consoles, QEMU (no launcher) | [Firmware & Hardware](../tools/firmware/index.md) |
| 05 Wireless & SDR | receive-only Wi-Fi survey and software-defined radio | [Wireless & SDR](../tools/wireless/index.md) |
| 06 Host Forensics | the field kit, The Sleuth Kit, TestDisk/PhotoRec (no launcher) | [Host Forensics](../tools/forensics/index.md) |
| 07 Reporting & Documentation | notes, screenshots, office suite, password store, disk wiping | [Reporting & Documentation](../tools/reporting/index.md) |
| 08 Reference | the offline reference folder, the build manifest and this wiki | [Reference](../tools/reference/index.md) |

Below the folders come **Usual Applications**, which holds the standard Xfce
categories (Firefox ESR is under Internet, the Mousepad text editor under
Accessories), and **Settings**.

A command-line tool's launcher opens a terminal, shows the command it ran (most
print their help), and leaves a shell open in that terminal so you can carry on
typing; the tool pages give the commands to run next. For a tool that keeps
running, such as the passive mDNS listener, Ctrl+C stops the tool and still
leaves the shell open. Launchers for tools this image does not carry are
hidden rather than broken, because each one's `TryExec` names a program that is
not installed: the vendor-layer tools when the image was built without the
[vendor layer](vendor-layer.md), the amd64-only tools on arm64
([architectures](architectures.md)), and the six launchers for tools that are
disabled placeholders in the vendor layer (Ghidra, Zeek, GRASSMARLIN, s7scan,
firmware-mod-kit and searchsploit).

## The panel and the favorites

The top panel carries, from the left: the Whisker menu, show desktop, a folder
menu, launchers for the terminal (its arrow also offers the Root Terminal), the
file manager, Mousepad, Flameshot and Wireshark, then the workspaces, the open
windows, the tray, sound, notifications, power, the clock and the log-out
menu.

The Whisker menu opens on its favorites: the terminal, the Root Terminal, the
**SnapshOT Wiki**, the file manager, Mousepad, Wireshark, nmap, CherryTree,
Flameshot and, in the live session, **Install SnapshOT**. Right-click any
launcher in the menu to add it to the favorites or remove it.

The Root Terminal asks for authorization and opens a root shell; prefer `sudo`
for single commands (see [administration and capture](admin-and-capture.md)).

## Keyboard shortcuts

| Keys | Does |
|---|---|
| <kbd>Alt</kbd>+<kbd>F1</kbd> or <kbd>Ctrl</kbd>+<kbd>Esc</kbd> | open the Whisker menu |
| <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>T</kbd> | open a terminal |
| <kbd>Super</kbd>+<kbd>E</kbd> | open the file manager |
| <kbd>Alt</kbd>+<kbd>F2</kbd> | run a command by name (the application finder) |
| <kbd>Print</kbd> | Flameshot: select an area, annotate, save ([Flameshot](../tools/reporting/flameshot.md)) |
| <kbd>Shift</kbd>+<kbd>Print</kbd> | Flameshot: the whole desktop, to the clipboard |
| <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>L</kbd> | lock the screen |
| <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>Delete</kbd> | log out, with the other session actions |
| <kbd>Ctrl</kbd>+<kbd>F1</kbd> to <kbd>Ctrl</kbd>+<kbd>F4</kbd> | go to workspace 1 to 4 |
| <kbd>Alt</kbd>+<kbd>Tab</kbd> | switch windows |

Lock the screen whenever you step away from the laptop on site; in the live
session the password that unlocks it is `live`.

## The field kit

06 Host Forensics also holds the **SnapshOT field kit**: a USB stick of
read-only triage collectors for the Windows and Linux hosts met on an
engagement. **Prepare Field Kit USB** erases a stick and writes the kit to it,
the collectors run on the target hosts and write only to the stick, and
**Import Field Kit results** brings the results into the case folder with hash
checks and a chain-of-custody log. **Field Kit folder** and **Field Kit guide**
open the kit and its printable guide. The [field kit](../tools/forensics/fieldkit.md)
tool page has the commands and the evidence trail.

## Related pages

- [Using this wiki](using-this-wiki.md): opening the wiki from 08 Reference or
  the favorites.
- [Administration and capture](admin-and-capture.md): the Root Terminal, `sudo`
  and the groups that let tools run without root.
- [Firefox ESR, locked down](browser.md): the browser the wiki and the device
  web interfaces open in.
