---
title: Scapy
summary: Interactive packet crafting
folder: traffic
launchers: [snapshot-scapy.desktop]
ships_as: apt
package: python3-scapy
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  identification: Dissect a capture packet by packet in Python, reaching fields and industrial layers that are awkward to express as a display filter.
  lessons-learned: Script the extraction, counting and summarizing of the exact frames behind a finding for the report.
csf: [identify, detect]
attack_ics: [discovery, collection, impair-process-control]
attack_role: resembles
attack_techniques: [T0846, T0842, T0801, T1692]
protocols: [modbus, ethernet-ip, profinet, iec-104]
upstream: https://scapy.readthedocs.io/
---

<!-- snapshot:facts -->

## What it is

Scapy is a Python library and interactive shell for reading, dissecting and
building network packets. It parses a pcap into Python objects whose every field
you can read, filter and summarize, and it builds arbitrary packets layer by
layer. Beyond the core protocols it carries contributed layers for industrial
and link protocols, including Modbus (`scapy.contrib.modbus`), EtherNet/IP
(`enipTCP`), PROFINET (`pnio`, `pnio_dcp`), IEC 60870-5-104
(`scapy.contrib.scada.iec104`), OPC DA and EtherCAT. On SnapshOT it is installed
as the system `python3-scapy` and launched into its interactive shell.

## Why it is on SnapshOT

When a display filter cannot express what you need, Scapy can: carve a specific
field out of every frame, correlate two layers, decode a protocol variant by
hand, or build a single, exact test frame for a lab. For a responder it is the
scripting layer over a capture, the place to answer a precise question about
thousands of packets in a few lines of Python. It uses the same contributed
ICS dissectors whether you are reading a file or constructing a frame.

## On the wire

!!! danger "Writes: it can craft and send arbitrary packets"

    Scapy can build any packet, including control-protocol commands, and send it.
    Reading a capture is safe; sending is not.

    - On SnapshOT, use Scapy to **read and dissect captures** (`rdpcap`) and to
      **build frames into a file** (`wrpcap`). Do the reading and crafting as your
      user; it needs no privileges.
    - Do not send crafted packets onto a control network. Sending (`send`,
      `sendp`, `sr`) needs `sudo` and puts packets on the wire that a device
      cannot tell from a real command. If a crafted frame must be tested, send it
      only on an isolated lab segment, with the engineer for the device present,
      exactly as for any write.
    - A crafted ICS request is an unauthorized command on a live network. Treat
      building one with the same care as using a write-capable protocol tool.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), load the case
capture in Scapy and pull out what a filter cannot: the distribution of Modbus
unit ids a host polled, the exact service in every CIP request, the ASDU type of
each IEC 104 control. Reading and dissecting only; no packets are sent. A
question that takes a page of display-filter work in tshark is often a ten-line
loop here, and the loop can be kept as part of the evidence trail.

### Lessons Learned

Script the extraction and counting of the frames behind each finding so the
report's numbers are reproducible, and save the short Scapy script with the case
so the analysis can be re-run. A reader who doubts a count can run the same
script over the same hashed capture and get the same answer, which is a stronger
statement than a screenshot of a filter.

## MITRE ATT&CK for ICS mapping

Scapy *resembles* whatever it is made to send: crafted traffic reproduces the
techniques it encodes, which is why sending belongs in a lab. Three tactics
follow from what it can do:

- **Discovery**: crafted probes and sweeps are Remote System Discovery (T0846),
  and its `sniff()` function, run on a live interface, is Network Sniffing
  (T0842).
- **Collection**: a crafted read request to a controller, a Modbus read of
  holding registers for example, is what an adversary polling the process
  looks like (Monitor Process State, T0801).
- **Impair Process Control**: a crafted write or command frame sent to a
  controller is Unauthorized Message (T1692), indistinguishable from the real
  thing.

On SnapshOT the safe, default use, dissecting a capture that is already on disk,
produces no traffic at all and resembles none of these. The same dissection
helps the team recognize these techniques when they appear in the evidence.

## Quick start

```sh
# What the menu launcher runs (the interactive shell; exit with Ctrl+D)
scapy
# A folder in the case for analysis scripts and their output
mkdir -p ~/cases/site-a/analysis/scapy
# Run the script below, saved there as modbus-writes.py, as your user
python3 ~/cases/site-a/analysis/scapy/modbus-writes.py
```

`modbus-writes.py` reads the case capture, lists every Modbus write-single-register
request and saves those frames to a new file. The same lines work typed into the
`scapy` shell.

```python
import os
from collections import Counter
from scapy.all import rdpcap, wrpcap, load_contrib, IP
# Load the Modbus layer from Scapy's contributed protocols
load_contrib("modbus")
from scapy.contrib.modbus import ModbusPDU06WriteSingleRegisterRequest as W

case = os.path.expanduser("~/cases/site-a")
pkts = rdpcap(case + "/pcap/eth1.pcapng")
# Every Modbus write-single-register request, with address and value
for p in pkts:
    if p.haslayer(W):
        print(p[IP].src, p[IP].dst, hex(p[W].registerAddr), p[W].registerValue)
# Count packets per source address
print(Counter(p[IP].src for p in pkts if p.haslayer(IP)).most_common(10))
# Save the write requests to a new capture (writes a FILE, not the wire)
wrpcap(case + "/analysis/scapy/modbus-writes.pcap", [p for p in pkts if p.haslayer(W)])
```

`load_contrib("enipTCP")`, `load_contrib("pnio_dcp")` and
`load_contrib("scada.iec104")` bring in the EtherNet/IP, PROFINET DCP and
IEC 104 layers the same way.

## Output and evidence

Scapy reads the capture without changing it. Create the case's `analysis/scapy/`
folder before the session, keep any capture you write and any script you run
there, and hash them:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/analysis/scapy"
sha256sum "$CASE"/analysis/scapy/* >> "$CASE/SHA256SUMS"
```

## Related tools

- [tshark](tshark.md) and [Wireshark](wireshark.md): the standard dissectors,
  for most capture analysis; reach for Scapy when a filter is not enough.
- [mbpoll](../protocols/mbpoll.md), [pymodbus](../protocols/pymodbus.md) and
  the [ICS Python shell](../protocols/ics-python-shell.md): purpose-built,
  engineer-supervised ways to read a device, rather than crafting frames by
  hand.
- [tcpreplay](tcpreplay.md): the other Traffic Analysis tool that transmits,
  for replaying a whole capture in the lab.

## Upstream documentation

- [Scapy documentation](https://scapy.readthedocs.io/): the API, `rdpcap` and
  `wrpcap`, and building and dissecting packets.
