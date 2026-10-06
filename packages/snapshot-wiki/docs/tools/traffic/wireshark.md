---
title: Wireshark
summary: Network traffic analyzer
folder: traffic
launchers: [org.wireshark.Wireshark.desktop]
ships_as: upstream-gui
package: wireshark
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Record and review a baseline capture of each conduit while the process runs normally.
  identification: Open a capture from a SPAN port or TAP and decode the industrial protocols to scope what is happening.
  containment: Confirm from fresh captures that the adversary's sessions stop once a conduit is isolated.
  recovery: Watch restored systems' traffic for recurrence and compare it with the baseline.
  lessons-learned: Pull conversations, flows and statistics from the case captures for the report.
csf: [identify, detect, respond, recover]
attack_ics: [discovery, collection, command-and-control, lateral-movement, impair-process-control]
attack_role: detects
attack_techniques: [T0846, T0801, T0845, T0843, T0869, T0885, T1692, T0836]
protocols: [modbus, s7comm, ethernet-ip, opc-ua, bacnet, dnp3, iec-104, iec-61850, profinet]
upstream: https://www.wireshark.org/docs/wsug_html_chunked/
---

<!-- snapshot:facts -->

## What it is

Wireshark is the graphical network protocol analyzer. It captures packets from
an interface, or opens a saved capture, and shows every packet in three linked
views: the packet list, the decoded field tree and the raw bytes. The same
dissectors as [tshark](tshark.md) decode the industrial protocols, including
Modbus/TCP, S7comm, EtherNet/IP and CIP, OPC UA, BACnet, DNP3, IEC 60870-5-104,
IEC 61850 MMS and GOOSE, and PROFINET. Display filters select packets by any
field, "Follow stream" reassembles a conversation, and the Statistics menu
summarises a capture by protocol, conversation or endpoint.

## Why it is on SnapshOT

Wireshark is the tool an OT responder reaches for to understand a capture in
depth. Where tshark is for capturing and scripting, Wireshark is for working
through a file by eye: colouring rules highlight the protocols of interest, the
protocol hierarchy shows what the network carries, and the field tree makes the
exact function code or register behind a finding visible without memorising the
specification. The SnapshOT user is in group `wireshark`, so Wireshark captures
without `sudo`.

## On the wire

!!! note "Passive: it never transmits"

    Wireshark only listens. The capture interface needs no IP address, only to
    be up.

    - Prefer a hardware TAP, which cannot send, or a SPAN (mirror) port that the
      site's network owner configures. Do not plug the laptop into a live
      control segment just to listen: the interface, and the desktop behind it,
      can still announce themselves on the link.
    - Keep network name resolution off (View > Name Resolution, or Edit >
      Preferences > Name Resolution). It is off by default, and with it off
      Wireshark makes no DNS queries for the addresses it sees; MAC vendor and
      port names come from local files and send nothing.
    - A SPAN port can drop packets under load. Note the switch and port in the
      case notes so gaps can be explained later.

## PICERL mapping

### Preparation

Open the baseline captures recorded for each conduit and learn what normal looks
like: which hosts poll which controllers, at what rate, and with which function
codes. A labelled baseline is what makes an anomaly obvious during
[identification](../../lifecycle/phases/identification.md).

### Identification

This is Wireshark's main phase. Work on the capture file offline: the protocol
hierarchy (Statistics > Protocol Hierarchy) shows what is present, the
conversation table (Statistics > Conversations) shows who talks to whom, and a
display filter such as `modbus.func_code in {5,6,15,16,22,23}` finds the writes
that change a controller. Every finding carries a packet number to cite.

### Containment

After a conduit is isolated, a short capture on each side shows whether the
adversary's sessions have stopped and whether the process traffic that must
continue still flows. Keep these captures as evidence of the containment action.

### Recovery

When systems return, watch their traffic and confirm the restored controllers
are polled only by the expected hosts, at the expected rate, before the process
owner returns them to automatic control.

### Lessons Learned

The case captures feed the report: conversation tables, first and last seen
times and the exact packets behind each finding. Export packet dissections (File
> Export Packet Dissections) as CSV or text for the appendix.

## MITRE ATT&CK for ICS mapping

Wireshark *detects*: it records the network evidence of several tactics.

- **Discovery**: scans and sweeps show as one source touching many hosts or
  ports (Remote System Discovery, T0846).
- **Collection**: repeated reads from an unexpected host (Monitor Process State,
  T0801) and S7 or MMS upload functions (Program Upload, T0845).
- **Lateral Movement**: program transfers from an unusual source (Program
  Download, T0843).
- **Command and Control**: sessions that leave the zone on ordinary ports
  (Standard Application Layer Protocol, T0869; Commonly Used Port, T0885).
- **Impair Process Control**: Modbus, S7 or DNP3 writes the operators did not
  make (Unauthorized Message, T1692; Modify Parameter, T0836).

## Quick start

Wireshark is a GUI; the menu launcher opens the window. These commands open it
the useful ways:

```sh
# What the menu launcher runs (opens the capture-interface window)
wireshark
# Open a saved capture straight into the GUI
wireshark -r ~/cases/site-a/pcap/eth1.pcapng
# Open it already filtered to Modbus writes
wireshark -r ~/cases/site-a/pcap/eth1.pcapng -Y 'modbus.func_code in {5,6,15,16,22,23}'
# Start capturing on the TAP or SPAN interface at once
wireshark -i eth1 -k
```

A first session, from capture to a saved extract:

1. **Capture, or open a file.** Open Wireshark from 02 Traffic Analysis and
   choose **Capture > Options**. On the **Input** tab, select the TAP or SPAN
   interface (no `sudo`: the user is in group `wireshark`). On the **Output**
   tab, give a file name in the case folder, such as
   `~/cases/site-a/pcap/eth1-20261006T0900Z.pcapng`; for a long capture, tick
   **Create a new file automatically** after an interval and **Use a ring
   buffer with** a number of files. Click **Start**, and **Capture > Stop**
   when you have enough. A capture taken earlier opens with **File > Open**.
2. **Put the clock on UTC.** **View > Time Display Format > UTC Date and Time
   of Day**, so packet times match the case notes.
3. **Read the three panes.** The packet list at the top has one line per
   packet. The packet details below it show the selected packet as a tree of
   decoded fields: expand Modbus/TCP to see the unit id, the function code and
   the register. The packet bytes at the bottom highlight whatever field is
   selected.
4. **See what is on the network.** **Statistics > Protocol Hierarchy** lists
   the protocols and their share of the traffic, **Statistics > Conversations**
   who talks to whom (IPv4 and TCP tabs), and **Statistics > Endpoints** every
   address. **Statistics > Capture File Properties** gives the first and last
   packet times and the counts for the notes.
5. **Filter.** Type a display filter (examples below) in the bar above the
   packet list and press Enter; the bar turns green when the filter is valid.
   To filter on a value you can see, right-click the field in the packet
   details and choose **Apply as Filter**.
6. **Follow a conversation.** Select one packet of it and choose **Analyze >
   Follow > TCP Stream** (also on the right-click menu). Wireshark sets a
   filter for that stream and shows its content; **Back** closes the window
   and restores the previous filter.
7. **Check the warnings.** **Analyze > Expert Information** groups malformed
   packets, retransmissions and protocol warnings by severity.
8. **Save what supports a finding.** With the filter applied, **File > Export
   Specified Packets** writes only the displayed packets to a new file in the
   case folder. Never overwrite the original capture, and note the filter and
   the packet numbers in the case notes.

Display filters that work on the shipped dissectors:

```text
modbus.func_code in {5,6,15,16,22,23}
s7comm.param.func in {0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x28,0x29}
enip.command == 0x63
cip.sc in {0x05,0x06,0x07}
dnp3.al.func in {4,5,6,13,14}
bacapp.confirmed_service in {15,16}
iec60870_asdu.typeid in {45,46,47,48,49,50,51}
opcua.servicenodeid.numeric in {673,712}
```

The Modbus filter is the write function codes (5, 6, 15, 16, 22, 23); the S7
filter is the download, upload, PI-service and PLC-stop functions; the
EtherNet/IP filter is List Identity, the discovery request; the CIP filter is
the Reset, Start and Stop services; the DNP3 filter is Operate, Direct Operate
(with and without acknowledgement) and the cold and warm restarts; the BACnet
filter is WriteProperty and WritePropertyMultiple; the IEC 60870-5-104 filter is
the C_* control ASDU types; the OPC UA filter is the Write and Call service node
ids. Replace `eth1` with the capture interface.

## Output and evidence

Save captures into the case folder, name them by interface and UTC time, and
hash them:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/pcap"
# Capture from the GUI into $CASE/pcap, then hash the files
sha256sum "$CASE"/pcap/*.pcapng >> "$CASE/SHA256SUMS"
# Start, end, packet count and interface of each file
capinfos "$CASE"/pcap/*.pcapng
```

Work on copies, never on the original capture. Wireshark does not modify a file
it only reads.

## Related tools

- [tshark](tshark.md): the same dissectors on the command line, for capture,
  ring buffers and scripted field extraction.
- [termshark](termshark.md) and [tcpdump](tcpdump.md): the same captures in a
  terminal UI, and with the smallest capture tool.
- [Suricata](suricata.md): run detection rules and the protocol parsers over the
  same capture offline, then open the flagged packets here.
- [nmap](../recon/nmap.md): capture with Wireshark while an approved scan runs,
  so the evidence shows exactly what was sent.
- [mbpoll](../protocols/mbpoll.md): reproduce, with approval, a Modbus exchange
  seen in a capture.

## Upstream documentation

- [Wireshark User's Guide](https://www.wireshark.org/docs/wsug_html_chunked/):
  capture, display filters, statistics and stream reassembly.
- [Display filter reference](https://www.wireshark.org/docs/dfref/): every field
  name the dissectors expose.
