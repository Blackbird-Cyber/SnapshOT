---
title: Using this wiki
summary: Opening the wiki offline, searching it, reading the badges and the facts box, using the graphs, and finding your way around the two sections.
---

This wiki ships on the image and documents every tool against the OT
incident-response lifecycle. It is meant to be used with the laptop open at a
plant, with no network. This page shows how to get around it.

## Opening it

Open it from **08 - Reference > SnapshOT Wiki**, which launches Firefox ESR on
`file:///usr/share/snapshot/wiki/index.html`. It is also the browser's home page
and a Whisker favourite. Everything works from `file://` with no network: search,
tags and the interactive graphs all run offline. The [browser](browser.md) is
locked down so it never calls out while you read.

## Searching

Press <kbd>/</kbd> or <kbd>S</kbd> and type. The search index is built into the
site, so results appear offline as you type. Search covers every page: tools,
lifecycle phases, playbooks, protocol primers and this platform guide. Results
quote each page's own text; the badges and the facts box are left out of the
index, so a search for a word like "passive" finds the pages that discuss it
rather than every page that carries the badge.

## The two sections, and this guide

- **[Lifecycle](../lifecycle/index.md)** follows an engagement through the six
  SANS PICERL phases (Preparation, Identification, Containment, Eradication,
  Recovery, Lessons Learned), read for a plant floor, with the MITRE ATT&CK for
  ICS tactics each phase is about and the tools that serve it.
- **[Tools](../tools/index.md)** documents every tool in the menu: what it is,
  how it behaves on the wire, how it is used in each phase, and which tactics it
  detects, investigates or resembles. Tools are grouped into the same eight menu
  folders as the desktop.
- The **platform guide** (this Home tab) covers the image itself: the
  [live session and install](live-and-install.md), the
  [desktop, menu and shortcuts](desktop.md),
  [administration and capture](admin-and-capture.md), the
  [quiet network defaults](network-defaults.md), the
  [vendor layer](vendor-layer.md) and more.

Under Tools, the **Protocols** section has a primer per industrial protocol
(ports, reads against writes, what to watch for, which tools speak it), and
under Lifecycle the **[matrix](../lifecycle/matrix.md)** puts every tool
against the six phases and the twelve ATT&CK for ICS tactics on one page.

## Reading the badges and the facts box

Every tool page carries a wire badge under its title, because the first question
on a plant floor is what a tool puts on the network:

- <span class="snapshot-wire snapshot-wire--passive">Passive</span> never
  transmits: it listens, reads files or works offline.
- <span class="snapshot-wire snapshot-wire--active">Active</span> sends queries
  or probes but only reads; it can still upset a fragile device.
- <span class="snapshot-wire snapshot-wire--writes">Writes</span> can change a
  device, its configuration or a disk; an engineer must be present and the work
  approved.

Passive-first is the house doctrine: prefer the passive tool, and treat anything
active or writing as a decision to announce and approve. The
[wire classes](../lifecycle/wire-classes.md) page explains the three classes in
full; the badge links to it.

Two more badges can follow it. **Not shipped** marks a tool whose vendor-layer
entry is defined but disabled, so this image does not carry it (see the
[vendor layer](vendor-layer.md)); **amd64 only** marks a tool that runs on one
architecture and is hidden on the other (see [architectures](architectures.md)).
The generated tables on the phase and tactic pages carry the same marks.

Under the badges, every tool page opens with a **facts box**: the menu folder
and launchers, how the tool ships, its architectures, a pointer to the
[build manifest](build-manifest.md) for its version, the wire class, the PICERL
phases it serves, its NIST CSF 2.0 functions, the ATT&CK for ICS tactics with
the tool's role (it *detects* the tactic, *investigates* it after the fact, or
*resembles* it, in which case the SOC is told before it is used), the technique
ids, the protocols and the upstream manual. The prose below never repeats
these facts. Phase pages show their place in the lifecycle (Phase 2 of 6) and
their CSF functions; tactic pages show the MITRE tactic id.

## Tags

Every tool page is tagged from its front-matter by phase, ATT&CK for ICS tactic,
menu folder, wire class and protocol. The [tags index](../tags.md) lists them, so
you can find, for example, every passive tool, every tool that speaks Modbus, or
every tool used in containment. The tags are not shown on the page itself: the
facts box at the top of each tool page carries the same information.

## The graphs

Four interactive graphs draw the relationships the tables list:

- the **lifecycle** graph, on the home page and the
  [Lifecycle](../lifecycle/index.md) page: the six phases and the tools that
  serve each, coloured by menu folder;
- the **ATT&CK** graph, on the [ATT&CK for ICS](../lifecycle/attack-ics/index.md)
  page: the tactics and the tools, coloured by their role;
- the **crosswalk** graph, on the [crosswalk](../lifecycle/crosswalk.md) page:
  PICERL against the CSF 2.0 functions and the tactics;
- the **Purdue** graph, on the [Identification](../lifecycle/phases/identification.md)
  phase page: the Purdue levels and zones, and where SnapshOT attaches.

To use one:

- **Pan** by dragging the background.
- **Zoom** with the **+** and **-** buttons at the top right of the graph. The
  mouse wheel scrolls the page, not the graph, so a graph never traps the
  scroll.
- **Full screen**: the third button opens the graph over the whole screen,
  where the mouse wheel zooms too. Press <kbd>Esc</kbd> or the same button to
  leave.
- **Hover** over a node to highlight its links; **click** a node to open its
  page.

The graphs need JavaScript, which the browser policy allows for the wiki; where
a graph cannot draw, a sentence says so, and the same links are in the tables
on each page and in the generated [matrix](../lifecycle/matrix.md).

## Related pages

- [Browser](browser.md): the locked-down Firefox the wiki opens in.
- [Lifecycle](../lifecycle/index.md) and [Tools](../tools/index.md): the two
  sections.
- [Wire classes](../lifecycle/wire-classes.md): passive, active and writes.
