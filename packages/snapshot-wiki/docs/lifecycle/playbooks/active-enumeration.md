---
title: Active enumeration
summary: Confirm, one host at a time and with approval, what the passive baseline suggested, sending the fewest packets that answer the question.
phases: [identification]
tactics: [discovery]
---

Active enumeration comes after the [passive baseline](passive-baseline.md), never
before it, and only inside [identification](../phases/identification.md) with
written approval. Its job is to confirm what listening already suggested: to turn
"a host on this address speaks Modbus" into "this is a named vendor's PLC, model
and firmware, with these ports open". Every step in it transmits, so every step
*resembles* an adversary's [Discovery](../attack-ics/discovery.md) and is
announced, rate-limited and taken one host at a time.

## Before you start

- A passive baseline that points at specific hosts worth confirming.
- Written authorization for each target host and the active actions allowed on it,
  inside an agreed window (see [rules of engagement](../rules-of-engagement.md)).
- The site's monitoring team told what you will run and when.
- For any ICS script or protocol query, the engineer for that device available.

## Procedure

1. **Pick one host.** Choose the single host the capture points at; do not sweep a
   control subnet.
   - *Go/no-go:* no target from the baseline means no scan. Go back and capture.

2. **Announce it.** Tell the site's monitoring the host, the action and the
   window, so your traffic is not mistaken for an intrusion.
   - *Record:* who was told, when, and the agreed window.

3. **Start a capture first.** Start a [tshark](../../tools/traffic/tshark.md)
   capture on the segment before the first packet is sent and keep it running
   through the active work, so the evidence shows exactly what was sent and how
   the device answered.
   - *Record:* the capture file, kept next to the scan output.

4. **Confirm presence at layer 2.** Use [arp-scan](../../tools/recon/arp-scan.md)
   or [netdiscover](../../tools/recon/netdiscover.md) on the local segment to
   confirm the host and read its MAC and vendor with a single ARP exchange and no
   connection to its services; add
   [fping](../../tools/recon/fping.md) only if you need liveness.
   - *Record:* the MAC, vendor and whether the host answered.
   - *Looks for:* [Discovery](../attack-ics/discovery.md), Remote System Discovery
     (T0846).

5. **Scan only the ports you need.** Run [nmap](../../tools/recon/nmap.md) as a
   plain connect scan (`-sT -n -Pn`), naming the few ports the traffic implies and
   capping the rate with `--max-rate`. Leave version, OS and aggressive scans off
   unless the owner agrees.
   - *Record:* the exact command and the result, saved with `-oA`.
   - *Looks for:* [Discovery](../attack-ics/discovery.md), Port Scan (T0846.001).
   - *Go/no-go:* if the host faults, resets or stops answering, stop and hand
     control back.

6. **Read the device's identity.** With the engineer present, ask the device what
   it is in its own protocol: an nmap ICS script (`modbus-discover`, `s7-info`,
   `enip-info`, `bacnet-info`) or [plcscan](../../tools/protocols/plcscan.md).
   - *Record:* vendor, model, firmware and unit ids.
   - *Looks for:* [Discovery](../attack-ics/discovery.md), Remote System
     Information Discovery (T0888).

7. **Hash the output.** Append the scan files and the capture to the case
   `SHA256SUMS`.

## Done when

- Each in-scope host is confirmed and identified, with the commands recorded.
- No device was disturbed, and the site's monitoring can attribute the traffic to
  the team.
- The output is saved and hashed in the case folder.

## Related pages

- [Passive baseline](passive-baseline.md): the step that must come first.
- [Protocol interrogation](protocol-interrogation.md): read a confirmed device's registers and tags.
- [Rules of engagement](../rules-of-engagement.md): approval, windows and stop conditions.
