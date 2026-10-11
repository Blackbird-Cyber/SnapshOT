---
title: termshark
summary: Terminal UI for tshark
folder: traffic
launchers: [snapshot-termshark.desktop]
ships_as: apt
package: termshark
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  identification: Browse a capture from a SPAN or TAP in a terminal, with Wireshark's dissectors and display filters, over SSH or on a console with no desktop.
  containment: Read fresh captures either side of an isolated conduit to confirm the adversary's sessions have stopped.
  lessons-learned: Reassemble the conversations behind each finding for the report without opening a GUI.
csf: [detect, respond]
attack_ics: [discovery, collection, command-and-control, impair-process-control]
attack_role: detects
attack_techniques: [T0846, T0801, T0869, T1692]
protocols: [modbus, s7comm, ethernet-ip, opc-ua, bacnet, dnp3, iec-104, profinet]
upstream: https://termshark.io/
---

<!-- snapshot:facts -->

## What it is

termshark is a terminal user interface for [tshark](tshark.md). It gives the
three-pane Wireshark layout, the packet list, the field tree and the hex view,
inside a terminal, driving tshark underneath so every dissector and display
filter works exactly as it does in Wireshark. It reads a saved capture or
captures live from an interface, supports display-filter completion as you type,
and can reassemble TCP and UDP streams and list conversations. With `--pass-thru`
it simply runs tshark instead.

## Why it is on SnapshOT

On a field engagement the analysis machine is often a console or an SSH session
with no desktop: a jump host beside a SPAN port, a cramped panel in a plant room,
a laptop with the GUI closed to stay quiet. termshark gives the responder
Wireshark's view of a capture there, with vim-style navigation, so a capture can
be triaged on the spot without copying it to another machine. It captures without
`sudo` because the SnapshOT user is in group `wireshark`.

## On the wire

!!! note "Passive: it never transmits"

    termshark listens through tshark and dumpcap; it sends nothing. The same
    cautions as tshark apply.

    - Prefer a TAP or an agreed SPAN port. The capture interface needs no IP.
    - Pass a display filter, not a capture filter, when you want to narrow what
      you read from a file, so nothing is discarded from the evidence.
    - When capturing live, termshark saves packets under
      `~/.cache/termshark/pcaps/` unless you give `-w`; point `-w` at the case
      folder so the evidence is where you expect it.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), open the
agreed capture in termshark and work through it: filter for the industrial
protocol of interest, select a suspicious packet, and use the Analysis menu to
reassemble its stream or list conversations. It is the same investigation as
Wireshark, on a machine with no display.

### Containment

After a conduit is isolated, read a short capture from each side in termshark to
confirm the adversary's sessions have stopped while the process traffic that must
continue still flows. Over SSH to a capture host at the boundary, that check
needs no desktop and no copy of the file. Keep the captures as evidence of the
containment action.

### Lessons Learned

Reassemble the conversation behind each finding and copy the relevant bytes with
copy mode for the report, all from the terminal. Note the packet numbers and the
display filter that isolate each finding, so a reader can reproduce it from the
case capture in termshark, tshark or Wireshark.

## MITRE ATT&CK for ICS mapping

termshark *detects*: through tshark's dissectors it shows the network evidence
of four tactics, packet by packet, on a machine with no desktop.

- **Discovery**: scans and sweeps show as one source touching many hosts or
  ports (Remote System Discovery, T0846).
- **Collection**: repeated reads of a controller's registers or tags from a host
  that has no reason to poll it (Monitor Process State, T0801).
- **Command and Control**: sessions that cross the zone boundary on ordinary
  application protocols (Standard Application Layer Protocol, T0869).
- **Impair Process Control**: Modbus, S7 or DNP3 writes the operators did not
  make (Unauthorized Message, T1692).

It analyzes a capture; it produces no traffic of its own. Each finding carries a
packet number in the capture file, which is the evidence to cite.

## Quick start

```sh
# What the menu launcher runs
termshark --help
# Open a saved capture in the terminal UI
termshark -r ~/cases/site-a/pcap/eth1.pcapng
# Open it already filtered to Modbus writes (-Y: a display filter)
termshark -r ~/cases/site-a/pcap/eth1.pcapng -Y 'modbus.func_code in {5,6,15,16,22,23}'
# Capture live from the TAP interface into the case folder, named by UTC time
termshark -i eth1 -w ~/cases/site-a/pcap/eth1-$(date -u +%Y%m%dT%H%M%SZ).pcapng
# Run tshark instead of the UI, for a quick statistic in the terminal
termshark --pass-thru=true -r ~/cases/site-a/pcap/eth1.pcapng -q -z io,phs
```

Inside the UI: `/` focuses the display filter, `tab` moves between the three
views, `enter` expands a field, and the Analysis menu reassembles a stream or
lists conversations. Press `?` for the key map and `q` to quit.

## Output and evidence

termshark does not alter the capture it reads. Keep captures in the case folder
and hash them as for tshark:

```sh
CASE=~/cases/site-a
sha256sum "$CASE"/pcap/*.pcapng >> "$CASE/SHA256SUMS"
```

When you capture live without `-w`, copy the file termshark leaves in
`~/.cache/termshark/pcaps/` into the case folder before you rely on it.

## Related tools

- [tshark](tshark.md): the engine underneath, for scripting and ring buffers.
- [Wireshark](wireshark.md): the full GUI when a desktop is available.
- [tcpdump](tcpdump.md): the smallest tool to grab the packets termshark then
  reads.

## Upstream documentation

- [termshark site](https://termshark.io/): overview and installation.
- [termshark user guide](https://github.com/gcla/termshark/blob/master/docs/UserGuide.md):
  keys, stream reassembly, conversations and the command line.
