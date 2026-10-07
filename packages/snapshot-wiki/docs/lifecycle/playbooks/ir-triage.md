---
title: Incident response triage
summary: Collect read-only host evidence with the field kit while a capture runs, verify and import it, and turn the findings into a pre-authorized containment action.
phases: [identification, containment]
tactics: [execution, persistence, lateral-movement, command-and-control]
---

When an incident is suspected on the engineering workstations, HMIs and
historians that supervise a process, triage gathers evidence from those hosts and
from the wire together, then uses it to decide containment. The host side is the
[field kit](../../tools/forensics/fieldkit.md): read-only collectors on a USB
stick that touch nothing but the results folder. The network side is a passive
capture at the affected conduit. This playbook runs across
[identification](../phases/identification.md) and into
[containment](../phases/containment.md); the containment action itself is only one
the plan already authorized.

## Before you start

- Written permission for each host to be triaged, and the operations contact
  present or informed. The field kit's own
  [OT safety rules](../../tools/forensics/fieldkit.md) apply: quick profile first,
  watch the banner, and the host's antivirus or EDR may alert on the collectors.
- A capture point agreed at the affected conduit.
- The printed chain-of-custody form ready, and a [case folder](../evidence-handling.md).

## Procedure

1. **Capture at the conduit.** Start or continue a
   [tshark](../../tools/traffic/tshark.md) capture where the affected zone meets
   the rest of the network.
   - *Record:* interface, UTC start, file name.
   - *Looks for:* [Command and Control](../attack-ics/command-and-control.md) and
     [Lateral Movement](../attack-ics/lateral-movement.md): beacons, cross-zone
     sessions and program transfers (Program Download, T0843; Lateral Tool
     Transfer, T0867).

2. **Prepare the stick.** On the laptop, prepare the field kit USB with the
   prepare step (this formats the stick, a [writes](../wire-classes.md) action on
   the media, not on any target).
   - *Record:* the kit version and the stick serial on the custody form.

3. **Collect from each host, read-only.** Run the collector on each in-scope host,
   quick profile first; it writes only to the stick and never to the target. Watch
   the banner and wait for the prompt so you can abort on a fragile host.
   - *Record:* host, role, profile, collector and the UTC start and end, on the
     custody form.
   - *Looks for:* [Execution](../attack-ics/execution.md) and
     [Persistence](../attack-ics/persistence.md): unexpected processes, scripts,
     services and autostart entries (Scripting, T0853; Command-Line Interface,
     T0807; Project File Infection, T0873).
   - *Go/no-go:* if antivirus quarantines a file or the host behaves oddly, stop,
     note it, and do not disable the antivirus.

4. **Import and verify.** Back on the laptop, import the stick read-only with the
   field kit import step. It checks each collection's hashes, copies it into
   `~/cases/<case>/fieldkit/`, makes it read-only and writes a block to the
   chain-of-custody log.
   - *Record:* the import result per collection (verified, no-manifest, or TAMPER).
   - *Go/no-go:* a TAMPER result means that collection is not trusted and not
     imported; investigate before relying on it.

5. **Triage against the baseline.** Compare the collected processes, network
   sockets, services and autostart entries with the
   [passive baseline](passive-baseline.md) and the capture; a host reaching across
   zones in the capture and a matching process on that host is a strong finding.
   - *Record:* each finding with its host-side and network-side evidence.

6. **Contain, with the process owner.** With findings in hand and the process
   owner's agreement, take the containment action the plan allows (isolate the
   conduit, block the session) and verify it from fresh captures on both sides of
   the boundary.
   - *Record:* the action, who authorized it, and the before-and-after captures.
   - *Looks for:* [Command and Control](../attack-ics/command-and-control.md):
     confirm the channel stays cut.
   - *Go/no-go:* confirm safety, alarm and protection functions still respond
     before and after isolating anything.

## Done when

- Each in-scope host is triaged read-only and imported with verified hashes, and
  the chain-of-custody log and printed form are complete.
- Findings are corroborated across host and network evidence.
- Any containment action was pre-authorized, taken with the process owner and
  verified from both sides.

## Related pages

- [Field kit](../../tools/forensics/fieldkit.md): the collectors, profiles and import,
  and the [hand-off](../../tools/forensics/fieldkit.md#hand-off-to-an-analysis-workstation) of the case to an
  analysis workstation when it needs deeper disk analysis.
- [Containment](../phases/containment.md): the pre-authorized actions and their limits.
- [Evidence handling](../evidence-handling.md): the case folder and chain of custody.
