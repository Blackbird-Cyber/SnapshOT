---
title: Zeek
summary: Network security monitor
folder: traffic
launchers: [snapshot-zeek.desktop]
ships_as: vendor
package: zeek
arch: [amd64, arm64]
status: not-shipped
wire: passive
phases:
  identification: Would turn a capture into structured connection and protocol logs, including Modbus and DNP3 transactions, for scoping.
  lessons-learned: Would provide a scriptable record of the incident's traffic for the timeline and detections.
csf: [detect, respond]
attack_ics: [discovery, command-and-control, lateral-movement, impair-process-control]
attack_role: detects
attack_techniques: [T0846, T0869, T1692]
protocols: [modbus, dnp3]
upstream: https://docs.zeek.org/
---

<!-- snapshot:facts -->

## What it is

Zeek is a network security monitor that turns traffic into structured logs: one
record per connection plus per-protocol logs for the application protocols it
understands. Its own Modbus and DNP3 analyzers log industrial transactions as
records that are far easier to search and correlate than raw packets, and the
CISA ICSNPP parsers extend them and add further industrial protocols, such as
BACnet, EtherNet/IP and S7comm. Its scripting language lets you express
detections over that log stream.

## Why it is not shipped

Zeek is defined in `vendor/sources.lock` as a disabled placeholder
(`enabled: false`), and so is the `icsnpp` stanza for the CISA ICSNPP parsers.
As `docs/vendoring.md` records under "Out of scope and why", Zeek is packaged
upstream as an OBS `.deb` that installs into `/opt/zeek` and pulls in apt
dependencies, the
documented exception to the vendor layer's rule that a vendored tool is
self-contained, and ICSNPP needs a working Zeek. The lock notes say neither is
vendored yet: the shape is recorded so they can be enabled later, but no
artifact is pinned, so the stanzas are validated and never fetched. The Zeek
launcher ships but stays hidden because its `TryExec` target is absent. See the
[vendor layer](../../platform/vendor-layer.md) page for how disabled tools are
handled.

## What to use instead

- [Suricata](suricata.md): the shipped network-monitoring engine. Run offline
  over a capture, it produces structured `eve.json` events and, with the Modbus
  and DNP3 parsers enabled, flags industrial-protocol anomalies, covering much of
  the same ground.
- [tshark](tshark.md): `-T fields` or `-T ek` turns a capture into per-packet
  records, including the ICS fields, for the same kind of scripted analysis.
- [Wireshark](wireshark.md) and [termshark](termshark.md): interactive decoding
  of the same captures.
- [tcpflow](tcpflow.md): the content of the clear-text TCP sessions in a
  capture, one file per flow direction, with a DFXML report of the flows.

## Upstream documentation

- [Zeek documentation](https://docs.zeek.org/): logs, the scripting language and
  the cluster model.
