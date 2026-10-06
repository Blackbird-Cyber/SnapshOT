---
title: Passive baseline
summary: Record what a segment looks like when it is healthy, from a capture that transmits nothing, so later evidence has something to stand against.
phases: [preparation, identification]
tactics: [discovery, collection, command-and-control, lateral-movement]
---

A passive baseline is the first thing to do on any segment, in
[preparation](../phases/preparation.md) before an incident and again at the start
of [identification](../phases/identification.md) when one is suspected. It
captures normal traffic from a mirror port or TAP and distils it into an
inventory of who talks, how and to whom. Nothing is transmitted, so it needs no
window and no per-host approval, only agreement on where the laptop is attached.
Work the whole procedure [passive first](../wire-classes.md); the active
[enumeration](active-enumeration.md) playbook comes after, not before.

## Before you start

- Agreement with the network owner on the capture point. The owner configures the
  SPAN or places the TAP; the team does not reconfigure switches.
- The asset owner's expected list of devices and protocols, if one exists, to
  compare against.
- A [case folder](../evidence-handling.md) ready (`~/cases/<case>/pcap/`).

## Procedure

1. **Attach at the right point.** Prefer a hardware TAP (it cannot transmit) or a
   SPAN port the network owner configures, at Purdue level 2 or 3 for supervisory
   and engineering traffic.
   - *Record:* the switch, port and capture point; whether it is a TAP or SPAN.
   - *Go/no-go:* if the capture shows no traffic or only the laptop's own, the
     mirror is wrong; fix it before going on.

2. **Start the capture.** Run [tshark](../../tools/traffic/tshark.md) with name
   resolution off and a ring buffer so it can run for hours unattended;
   [Wireshark](../../tools/traffic/wireshark.md) or
   [tcpdump](../../tools/traffic/tcpdump.md) do the same job.
   - *Record:* the interface, the UTC start time and the file names.

3. **Cover a full process cycle.** Let it run long enough to see the normal
   rhythm: polling cycles, a shift change, a historian upload, a batch.
   - *Record:* the duration and anything operations mention happening during it.

4. **Distil the inventory.** Offline, build the protocol hierarchy
   (`-z io,phs`) and the conversation table (`-z conv,tcp`) in tshark to see what
   is on the network and who talks to whom.
   - *Record:* the device list, the protocols each speaks, and the normal
     conversations between zones. This is the baseline that later makes
     [Discovery](../attack-ics/discovery.md), [Collection](../attack-ics/collection.md),
     [Command and Control](../attack-ics/command-and-control.md) and
     [Lateral Movement](../attack-ics/lateral-movement.md) stand out.

5. **Fingerprint hosts passively.** Run [p0f](../../tools/recon/p0f.md) over the
   same capture to guess operating systems and stacks without sending anything.
   - *Record:* the passive fingerprints next to each host.

6. **Hash and keep it.** Hash the captures into the case `SHA256SUMS` and store
   them as the baseline.
   - *Record:* the SHA-256 lines; mark these files as the reference baseline.

## Done when

- A hashed capture covers at least one full process cycle from an agreed point.
- You have an inventory of devices, protocols and normal cross-zone conversations.
- Nothing was transmitted, and the baseline is stored for later comparison.

## Related pages

- [Active enumeration](active-enumeration.md): confirm, with approval, what the baseline suggested.
- [Wire classes](../wire-classes.md) and [evidence handling](../evidence-handling.md).
