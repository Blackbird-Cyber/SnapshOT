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

Tool pages give technique ids only where the evidence a tool sees is certain to
belong to that technique. The ids follow ATT&CK v19, which moved several
techniques into the T16xx range (for example T1692 Unauthorized Message and T1693
Modify Firmware); older ids for those are not used.

## The twelve tactics

<!-- snapshot:tactics -->

## What a field kit can see

A laptop on a SPAN port or TAP sees the conversations that cross that point in
the network; the field kit's collectors see the state of the Windows and Linux
hosts they run on; the forensic tools see the disks and images brought to them.
Grouped by what the adversary is trying to do, that gives:

| Tactic class | Tactics | What SnapshOT can see | Where the evidence comes from |
|---|---|---|---|
| Getting in and staying in | [Initial Access](initial-access.md), [Execution](execution.md), [Persistence](persistence.md), [Privilege Escalation](privilege-escalation.md) | Remote sessions and file transfers crossing a boundary; on hosts, the processes, services, scheduled tasks, autostart entries, accounts and installed software; changes on disk | Captures at the boundary; the [field kit](../../tools/forensics/fieldkit.md) collectors; [The Sleuth Kit](../../tools/forensics/sleuthkit.md) |
| Learning the environment | [Discovery](discovery.md), [Collection](collection.md) | Scans, broadcast and multicast discovery, unexpected polling, bulk reads of registers and tags, project uploads: loud on a quiet OT network | Passive capture and protocol decoding with [tshark](../../tools/traffic/tshark.md) and [Wireshark](../../tools/traffic/wireshark.md) |
| Moving and keeping control | [Lateral Movement](lateral-movement.md), [Command and Control](command-and-control.md) | Sessions between zones the architecture does not expect, remote service logins, program downloads from unusual hosts, regular beacons, tunnels on allowed ports | Long captures at the conduits between zones; IDS rules in [Suricata](../../tools/traffic/suricata.md) |
| Hiding | [Evasion](evasion.md) | Gaps and imitations: logs that stop, devices whose mode changed, traffic shaped like an engineering session. Visible only against a baseline | Comparison with the preparation baseline; host logs (the field kit's full profile copies the Windows event logs and Linux logs) |
| Acting on the process | [Inhibit Response Function](inhibit-response-function.md), [Impair Process Control](impair-process-control.md), [Impact](impact.md) | Unauthorized writes, mode changes, program and firmware transfers on the wire; values, logic and firmware that differ from the baseline | Protocol decoding; approved read-only polls with the protocol tools; [binwalk](../../tools/firmware/binwalk.md) on firmware images; the process owner's and the safety system's own records |

Each tactic page repeats the view for that tactic and lists the tools that map to
it.

## What it cannot see

- **Anything that does not cross the listening point.** A capture shows one point
  in the network: not other zones, not traffic that stays inside a switch, not a
  serial link the laptop is not attached to, not a radio link outside a
  receive-only survey.
- **The inside of a controller.** Logic, memory and firmware are seen only through
  the engineer's own software, an approved read, or an acquired image.
- **Host memory.** The field kit collectors record processes and network state;
  they do not image memory.
- **Encrypted content.** A TLS, SSH or VPN session shows who talked to whom and
  when, not what was said.
- **The past.** A capture starts when it starts. Earlier activity appears only in
  the site's own monitoring, logs and historian.
- **Activity away from the site.** Reconnaissance, weaponization and the
  development and testing of a Stage 2 attack happen elsewhere (see the ICS Cyber
  Kill Chain on the [crosswalk](../crosswalk.md)).
- **The physical effect.** Whether a valve moved, a drive tripped or a safety
  function would have acted is for the operators, the process owner and the
  safety system's records to establish.

These limits are why the evidence of an incident is assembled from the laptop,
the field kit, the engineers' tools and the asset owner's records together.

## From a detection to a phase

A detection tells the team what the adversary is doing; the tactic, and where it
sits in the two stages of the ICS Cyber Kill Chain, tells the team which phase to
be in and how fast to move.

| What the evidence shows | Kill chain stage | First move | Phase |
|---|---|---|---|
| Discovery or Collection from an unexpected host | Stage 1 | Rule out the team's own and the site's sanctioned tools; scope passively; tell the incident commander | [Identification](../phases/identification.md) |
| Command and Control or Lateral Movement across a conduit | Stage 1, foothold established | Scope the channel and the hosts; prepare the pre-authorized containment options with the process owner | Identification, then [Containment](../phases/containment.md) |
| Initial Access, Execution, Persistence or Privilege Escalation on a host | Stage 1 | Preserve the host evidence; record the foothold for removal | Identification, then [Eradication](../phases/eradication.md) |
| Evasion: missing logs, changed modes, imitation traffic | Either | Assume more is hidden; widen the scope | Identification |
| Inhibit Response Function, Impair Process Control or Impact | Stage 2 | Tell the process owner at once; the site's safety procedures come first; contain from the pre-authorized list | Containment |
| Any of these after containment, eradication or recovery | Either | The last phase did not finish | Back to identification |

Two more rules:

- **During preparation**, a detection ends the baseline: the site is not in a
  known-good state, and the engagement becomes an incident.
- **Every detection is a timeline entry** for
  [lessons learned](../phases/lessons-learned.md), with its tactic, the technique
  where the evidence supports it, and its evidence.

Tools with the role **resembles** produce exactly the traffic in the first row.
Announce them to the site before they run and log their UTC times, so the team's
own work is never mistaken for an adversary's or hides one.

## Tactics and tools

Tactics in red; tools colored by their role. Click a node to open its page.

<div class="snapshot-graph" data-graph="attack" data-height="700">
<p class="snapshot-graph__fallback">This graph needs JavaScript; the same links are in the matrix.</p>
</div>

The [matrix](../matrix.md) lists every tool against every tactic.

Tactic ids, names and descriptions are from MITRE ATT&CK for ICS (v19). © 2026 The
MITRE Corporation. This work is reproduced and distributed with the permission of
The MITRE Corporation. ATT&CK is a registered trademark of The MITRE Corporation.
