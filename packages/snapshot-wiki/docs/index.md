---
title: SnapshOT Wiki
summary: Every tool on this image, what it does on the wire, and where it fits in an OT incident response, offline.
hide:
  - toc
---

This wiki ships on the SnapshOT image and opens from the menu (**08 - Reference >
SnapshOT Wiki**) with no network. It has two halves. **Lifecycle** follows an
engagement through the six PICERL phases, read for a plant floor, with the MITRE
ATT&CK for ICS tactics each phase is about. **Tools** documents every tool in the
menu: what it is, how it behaves on the wire, how to use it in each phase and
which tactics it detects, investigates or resembles.

<!-- snapshot:cards -->

## The lifecycle at a glance

Each phase links to the tools that serve it. Drag to pan, scroll to zoom, hover
to highlight a node's links, click a node to open its page.

<div class="snapshot-graph" data-graph="lifecycle" data-height="660">
<p class="snapshot-graph__fallback">This graph needs JavaScript; the same links are in the tables on each phase page and in the matrix.</p>
</div>

<!-- snapshot:phases -->

## Reading the badges

Every tool page carries a wire badge under its title:
<span class="snapshot-wire snapshot-wire--passive">Passive</span> never
transmits, <span class="snapshot-wire snapshot-wire--active">Active</span> sends
queries but only reads, and <span class="snapshot-wire snapshot-wire--writes">Writes</span>
can change a device, its configuration or a disk. Search works offline: press
<kbd>/</kbd> or <kbd>S</kbd> and type. Pages are also listed by [tag](tags.md):
phase, tactic, menu folder, wire class and protocol.
