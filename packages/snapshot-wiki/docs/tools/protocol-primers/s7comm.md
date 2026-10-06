---
title: S7comm
summary: Siemens' protocol for S7 PLCs; reads and writes data, and downloads logic, over ISO-TSAP on TCP 102.
---

## What it is and where it sits

S7comm is the protocol Siemens S7 controllers speak: it reads and writes memory
areas (data blocks, inputs, outputs, merkers, timers, counters), reports the CPU
state and identity, and carries program upload and download. It runs inside
ISO-TSAP over TCP (an ISO 8073 COTP connection on top of TPKT), so a session is
established with source and destination TSAPs that encode the rack and slot of
the CPU. On the Purdue model S7comm sits between engineering stations and HMIs at
levels 2 and 3 and the S7 controllers at levels 1 and 2. Newer S7-1200 and
S7-1500 CPUs use **S7comm-Plus**, a related but distinct protocol with integrity
protection. The Wireshark on SnapshOT decodes S7comm but has no S7comm-Plus
dissector: those sessions show as COTP data on port 102 that is not S7comm.

## Ports

TCP 102 (ISO-TSAP). The TSAP values in the connection request select the CPU's
rack and slot.

## What it can do, and what that means

- **Reads** return data-block contents, I/O, the CPU run or stop state, the
  module and firmware identity and system status lists. Low risk, but still
  requests a CPU must service.
- **Writes** change data-block values and I/O the CPU acts on: a set point, a
  parameter, a mode word.
- **Control functions** stop and start the CPU and change its operating mode; a
  stop halts the controlled process.
- **Program download and upload** move the CPU's logic blocks. A download can
  replace what the controller runs, which is the highest-impact action on the
  protocol.

Any write, control or download is the [writes](../../lifecycle/wire-classes.md)
class: the engineer present, the exact action agreed, announced to the site.
Stopping or reprogramming a running CPU can stop or endanger the process.

## What to watch for in a capture

- Write Var to a CPU from a host that should only read.
- Program download or online edit functions, which replace or alter logic.
- PLC stop or change-of-operating-mode requests.
- A new engineering session (COTP connection request on port 102) from an
  unexpected host, especially outside a maintenance window.

## Wireshark display filters

```text
# All S7comm
s7comm
# Write Var (function 0x05)
s7comm.param.func == 0x05
# Program download and upload (request download, download block/ended, start/end upload)
s7comm.param.func in {0x1a,0x1b,0x1c,0x1d,0x1e,0x1f}
# PLC stop (0x29) and PI service / program invocation (0x28)
s7comm.param.func in {0x28,0x29}
# CPU-function userdata, e.g. Read SZL (identity and status)
s7comm.header.rosctr == 7 && s7comm.param.userdata.funcgroup == 4
# Setup communication, the first S7comm exchange of a new session
s7comm.param.func == 0xf0
# The COTP layer that carries every S7 session on port 102
cotp
# Port 102 traffic that is neither S7comm nor IEC 61850 MMS (setup, S7comm-Plus)
cotp && tcp.port == 102 && !s7comm && !mms
```

## SnapshOT tools that speak or decode it

- [python-snap7](../protocols/python-snap7.md): read identity, state and data
  blocks, and (with care) write them.
- [plcscan](../protocols/plcscan.md) and [nmap](../recon/nmap.md) (`s7-info`,
  and [Redpoint NSE](../recon/redpoint-nse.md) `s7-enumerate` when the vendor
  layer is present): identify S7 PLCs.
- [tshark](../traffic/tshark.md) and [Wireshark](../traffic/wireshark.md):
  capture and decode S7comm; S7comm-Plus sessions are captured but not decoded.

## ATT&CK for ICS techniques that ride on it

- [Discovery](../../lifecycle/attack-ics/discovery.md): Remote System
  Information Discovery (T0888), by reading the module identification SZLs.
- [Collection](../../lifecycle/attack-ics/collection.md): Monitor Process State
  (T0801), Program Upload (T0845), and Detect Operating Mode (T0868), reading
  the CPU state to choose a moment to act.
- [Execution](../../lifecycle/attack-ics/execution.md): Change Operating Mode
  (T0858), Modify Controller Tasking (T0821).
- [Lateral Movement](../../lifecycle/attack-ics/lateral-movement.md): Program
  Download (T0843), including Program Download: Download All (T0843.001).
- [Persistence](../../lifecycle/attack-ics/persistence.md): Modify Program
  (T0889), logic changed by a download and left in place.
- [Impair Process Control](../../lifecycle/attack-ics/impair-process-control.md):
  Modify Parameter (T0836).
- [Inhibit Response Function](../../lifecycle/attack-ics/inhibit-response-function.md):
  Device Restart/Shutdown (T0816).

## Upstream specification

S7comm is proprietary to Siemens and has no public specification. The closest
authoritative reference is the protocol as decoded by the Wireshark dissector:

- [S7comm (Wireshark wiki)](https://wiki.wireshark.org/S7comm): the message
  structure, function codes and SZL identifiers.
