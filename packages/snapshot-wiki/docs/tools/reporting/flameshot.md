---
title: Flameshot
summary: Powerful yet simple to use screenshot software
folder: reporting
launchers: [org.flameshot.Flameshot.desktop]
ships_as: upstream-gui
package: flameshot
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  identification: Capture what you see as you see it (an HMI web page, an alarm list, a decoded packet) into the case folder.
  lessons-learned: Crop, annotate and redact screenshots into the report's figures.
csf: [detect, identify]
attack_ics: []
attack_role: none
upstream: https://flameshot.org/
---

<!-- snapshot:facts -->

## What it is

Flameshot is a screenshot tool for the desktop. You drag to select an area of
the screen, then annotate it in place with arrows, boxes, lines, numbered
markers and text, pixelate parts of it, and save it, copy it or pin it to the
screen. From the command line it takes the whole desktop, one screen or a chosen
region, with an optional delay, and saves straight to a file or folder. The menu
launcher starts it in the background with a tray icon; its *Take screenshot*
action opens the selection after half a second.

## Why it is on SnapshOT

Some evidence exists only on a screen: a device's web interface in Firefox, an
HMI page reached in an approved remote session, the packet in
[Wireshark](../traffic/wireshark.md) that proves a write, a terminal at the
moment a command answered. A screenshot taken then, saved into the case folder
with its time, keeps it. Annotation and pixelation on the spot save a trip
through an image editor when the same picture becomes a figure in the report.

## On the wire

!!! note "Passive: it never transmits"

    Flameshot captures the laptop's own screen and touches nothing else.

    - **Never use Upload.** The upload button and `-u` send the screenshot to an
      online image host. Evidence and client screens never leave the laptop.
    - **Screens show the client's process.** Tag names, set points, IP addresses
      and user names appear in screenshots: keep them in the case folder, and
      pixelate what the report's readers should not see.
    - **Capture on the laptop, not on the asset.** Do not install or run a
      screenshot tool on an HMI or engineering workstation; when a screen there
      must be recorded, photograph it with the operator's permission or capture
      the approved remote session from the laptop.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), capture the
evidence you see as you see it: the decoded write in Wireshark, the device's
status page, the alarm the operator showed you on the laptop's screen. Save to
the case folder, then paste the picture into the host's node in
[CherryTree](cherrytree.md) with a line on what it shows.

### Lessons Learned

For [lessons learned](../../lifecycle/phases/lessons-learned.md), crop, annotate
and pixelate the screenshots that become figures in the report. Keep the original
capture untouched next to the edited figure, so the evidence and the
illustration are never confused.

## MITRE ATT&CK for ICS mapping

Flameshot has no ATT&CK for ICS mapping: it records the laptop's own screen and
neither detects nor investigates adversary activity. Its screenshots only
illustrate findings that other tools map. For example, a picture of a decoded
Modbus write in [Wireshark](../traffic/wireshark.md) can be the figure for a
finding that [tshark](../traffic/tshark.md) and Wireshark place under Impair
Process Control; the mapping belongs to the capture, not to the screenshot.

## Quick start

```sh
# What the menu launcher runs: Flameshot in the background, with a tray icon
flameshot
# Select an area, annotate it, then save or copy it from the toolbar
flameshot gui
# Select an area and save it into the case folder
flameshot gui -p ~/cases/site-a/notes/screens
# The whole desktop after 3 seconds, saved into the case folder
flameshot full -d 3000 -p ~/cases/site-a/notes/screens
# Only the screen under the mouse pointer
flameshot screen -p ~/cases/site-a/notes/screens
# Select an area and put it on the clipboard, to paste into notes
flameshot gui -c
```

`-p` takes an existing folder or a new file name; `-d` is in milliseconds.

## Output and evidence

Save captures into one folder per case, keep originals and edited figures apart,
and hash the originals:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/notes/screens" "$CASE/report/figures"
flameshot full -p "$CASE/notes/screens"
sha256sum "$CASE"/notes/screens/*.png >> "$CASE/SHA256SUMS"
```

Note in the case notes what each screenshot shows, on which host or interface
and when, so it can be cited later. See [evidence
handling](../../lifecycle/evidence-handling.md).

## Related tools

- [CherryTree](cherrytree.md): the notes the screenshots are pasted into.
- [LibreOffice](libreoffice.md) and [pandoc](pandoc.md): the report the figures
  go into.
- [Wireshark](../traffic/wireshark.md) and [tshark](../traffic/tshark.md): the
  capture behind a screenshot of a packet, as evidence that can be re-examined.

## Upstream documentation

- [Flameshot](https://flameshot.org/): the project's home page, documentation
  and keyboard shortcuts.
