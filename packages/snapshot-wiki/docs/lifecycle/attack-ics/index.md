---
title: ATT&CK for ICS
summary: The twelve MITRE ATT&CK for ICS tactics, the PICERL phases they matter in, and the SnapshOT tools that detect, investigate or resemble them.
---

MITRE ATT&CK for ICS describes what adversaries do inside industrial control
systems, as twelve tactics (the adversary's goal at a stage) and the techniques
that achieve them. SnapshOT uses it in two directions: each
[lifecycle phase](../index.md) lists the tactics it is about, and each tool page
says how the tool relates to a tactic:

- **Detects**: the tool produces evidence that the tactic is happening (a
  capture showing a scan or an unauthorized write).
- **Investigates**: the tool helps scope or explain it once suspected (disk and
  host forensics).
- **Resembles**: the tool's own activity looks like the tactic (an active scan
  looks like Discovery), so the site must be told before it runs.

## The twelve tactics

<!-- snapshot:tactics -->

## What a field kit can and cannot see

A laptop on a SPAN port sees the conversations that cross that point in the
network: scans, protocol reads and writes, program transfers and sessions
leaving a zone. It does not see what happens inside a controller, on a serial
link it is not attached to, or in a host's memory. Those need the field kit's
host collection, the engineer's own tools and the asset owner's records. The
tactic pages say, for each tactic, where the evidence usually is.

## Tactics and tools

Tactics in red; tools coloured by their role. Click a node to open its page.

<div class="snapshot-graph" data-graph="attack" data-height="600">
<p class="snapshot-graph__fallback">This graph needs JavaScript; the same links are in the matrix.</p>
</div>

Ids, names and descriptions are from MITRE ATT&CK for ICS (v19), © The MITRE
Corporation, reproduced with its permission. The [matrix](../matrix.md) lists
every tool against every tactic.
