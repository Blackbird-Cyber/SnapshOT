---
title: Using this wiki
summary: Opening the wiki offline, searching it, reading the wire badges, and finding your way around the two sections.
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
lifecycle phases, playbooks and this platform guide.

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
  [live session and install](live-and-install.md),
  [administration and capture](admin-and-capture.md), the
  [quiet network defaults](network-defaults.md), the
  [vendor layer](vendor-layer.md) and more.

## Reading the wire badges

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
full.

## Tags

Every tool page is tagged from its front-matter by phase, ATT&CK for ICS tactic,
menu folder, wire class and protocol. The [tags index](../tags.md) lists them, so
you can find, for example, every passive tool, every tool that speaks Modbus, or
every tool used in containment. The tags are not shown on the page itself: the
facts box at the top of each tool page carries the same information.

## The graphs

Several pages carry an interactive graph: the lifecycle graph links phases to
tools, and the ATT&CK graph links tactics to tools coloured by their role. Drag
to pan and zoom with the + and - buttons at the top right of the graph; the mouse
wheel scrolls the page, not the graph. The third button opens the graph full
screen, where the wheel zooms too; Escape or the same button leaves. Hover over
a node to highlight its links, and click a node to open its page. The graphs need JavaScript (which the wiki is allowed to run);
where a graph cannot draw, the same links are in the tables on each page and in
the generated matrix.

## Related pages

- [Browser](browser.md): the locked-down Firefox the wiki opens in.
- [Lifecycle](../lifecycle/index.md) and [Tools](../tools/index.md): the two
  sections.
- [Wire classes](../lifecycle/wire-classes.md): passive, active and writes.
