---
title: tshark
summary: CLI network protocol analyzer
folder: traffic
launchers: [snapshot-tshark.desktop]
ships_as: apt
package: tshark
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Record a baseline capture of each conduit while the process runs normally.
  identification: Capture from a SPAN port or TAP and decode the industrial protocols to scope what is happening.
  containment: Confirm from fresh captures that the adversary's sessions stop once a conduit is isolated.
  recovery: Watch restored systems' traffic for recurrence and compare it with the baseline.
  lessons-learned: Pull conversations, timelines and statistics from the case captures for the report.
csf: [identify, detect, respond, recover]
attack_ics: [discovery, collection, command-and-control, lateral-movement, impair-process-control]
attack_role: detects
attack_techniques: [T0846, T0801, T0845, T0843, T0869, T0885, T1692, T0836]
protocols: [modbus, s7comm, ethernet-ip, opc-ua, bacnet, dnp3, iec-104, iec-61850, profinet]
upstream: https://www.wireshark.org/docs/man-pages/tshark.html
---

<!-- snapshot:facts -->

## What it is

tshark is the command-line form of Wireshark. It captures packets from an
interface into a pcapng file, or reads an existing capture, and decodes every
packet with the same dissectors as Wireshark, including Modbus, S7comm,
EtherNet/IP and CIP, OPC UA, BACnet, DNP3, IEC 60870-5-104, IEC 61850 MMS and
GOOSE, and PROFINET. Display filters select packets by any decoded field, and
the statistics options summarise a capture by protocol, conversation or endpoint.
Output can be the familiar one-line summary, full packet detail, or chosen fields
as CSV.

## Why it is on SnapshOT

Passive capture is the first thing an OT responder does, and tshark does it
without a desktop: in a terminal, over SSH, or left running on a SPAN port with a
ring buffer while you work elsewhere. It answers the early questions of an
incident from evidence instead of from probing: which devices talk, which
protocols they use, who writes to the controllers and who downloads programs.
The SnapshOT user is in group `wireshark`, so tshark captures without `sudo`.

## On the wire

!!! note "Passive: it never transmits"

    tshark only listens. It does not need an IP address on the capture
    interface, only that the interface is up.

    - Prefer a hardware TAP, which cannot send, or a SPAN (mirror) port
      configured by the site's network owner. Do not plug into a live control
      network segment just to listen without agreement: the laptop itself may
      announce itself on the link.
    - Name resolution is a side effect worth avoiding: use `-n` so tshark makes
      no DNS lookups for the addresses it sees.
    - A SPAN port can drop packets under load; note the switch and port in the
      case notes so the gaps can be explained later.

## PICERL mapping

### Preparation

Capture each conduit for a period that covers the normal process cycle (polls,
shift changes, historian uploads) and store it as the baseline. Later captures
are compared with it to tell normal engineering traffic from new behaviour.

### Identification

This is tshark's main phase. During
[identification](../../lifecycle/phases/identification.md), capture from the
agreed SPAN or TAP, then work offline on the file: the protocol hierarchy shows
what is on the network, the conversation table shows who talks to whom, and
display filters for Modbus writes or S7 program transfers find the sessions that
change a controller. Every finding comes with packet numbers you can cite.

### Containment

After a conduit is isolated, a short capture on each side shows whether the
adversary's sessions have stopped and whether the process traffic that must
continue still flows. Keep these captures as evidence of the containment action.

### Recovery

When systems return, a rolling capture watches for the indicators found earlier
and confirms that the restored controllers are polled by the expected hosts
only.

### Lessons Learned

The case captures feed the report: conversation tables, first and last seen
times and the exact packets behind each finding. CSV output from `-T fields`
drops straight into a spreadsheet or a timeline.

## MITRE ATT&CK for ICS mapping

tshark *detects*: it records the network evidence of several tactics.

- **Discovery**: scans and sweeps show as one source touching many hosts or
  ports (Remote System Discovery, T0846).
- **Collection**: repeated reads from an unexpected host (Monitor Process State,
  T0801) and S7 upload functions (Program Upload, T0845).
- **Lateral Movement**: S7 download functions or other program transfers from
  an unusual source (Program Download, T0843).
- **Command and Control**: sessions that leave the zone on ordinary ports
  (Standard Application Layer Protocol, T0869; Commonly Used Port, T0885).
- **Impair Process Control**: Modbus or S7 writes the operators did not make
  (Unauthorized Message, T1692; Modify Parameter, T0836).

## Quick start

```sh
# List the capture interfaces (what the launcher runs)
tshark -D
# Capture everything on eth1 to a file; Ctrl+C to stop
tshark -n -i eth1 -w span.pcapng
# Ring buffer: a new file every hour, keep the last 24
tshark -n -i eth1 -b duration:3600 -b files:24 -w span.pcapng
# Protocol hierarchy: what is on this network
tshark -n -r span.pcapng -q -z io,phs
# TCP conversations: who talks to whom, and how much
tshark -n -r span.pcapng -q -z conv,tcp
# Modbus write requests and their replies
tshark -n -r span.pcapng -Y 'modbus.func_code in {5,6,15,16,22,23}'
# S7 program download and upload, PI service and PLC stop
tshark -n -r span.pcapng -Y 's7comm.param.func in {0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x28,0x29}'
# Every Modbus/TCP packet as CSV: time, source, destination, unit id, function
tshark -n -r span.pcapng -Y mbtcp -T fields -e frame.time_utc -e ip.src -e ip.dst \
    -e mbtcp.unit_id -e modbus.func_code -E header=y -E separator=,
```

Replace `eth1` with the capture interface `tshark -D` lists. The Modbus codes
are the write functions (5, 6, 15, 16, 22 and 23); the S7 codes are request
download, download block, download ended, start upload, upload, end upload,
PI service and PLC stop.

## Output and evidence

Capture straight into the case folder, name files by interface and UTC time,
and hash them when the capture ends:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/pcap"
tshark -n -i eth1 -a duration:3600 -w "$CASE/pcap/eth1-$(date -u +%Y%m%dT%H%M%SZ).pcapng"
sha256sum "$CASE"/pcap/*.pcapng >> "$CASE/SHA256SUMS"
# Start, end, packet count and interface of each file
capinfos "$CASE"/pcap/*.pcapng
```

Work on copies, never on the original capture; tshark's reads (`-r`) do not
modify the file.

## Related tools

- [nmap](../recon/nmap.md): capture with tshark while an approved scan runs, so
  the evidence shows exactly what was sent.
- [mbpoll](../protocols/mbpoll.md): reproduce a Modbus read seen in a capture,
  with the engineer's approval.
- Wireshark, termshark and tcpdump (02 Traffic Analysis): the same captures in a
  GUI, in a terminal UI, and with the smallest capture tool.

## Upstream documentation

- [tshark manual page](https://www.wireshark.org/docs/man-pages/tshark.html):
  every option, statistics and output format.
- [Display filter reference](https://www.wireshark.org/docs/dfref/): every field
  name tshark and Wireshark can filter on.
