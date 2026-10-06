---
title: DNP3
summary: The SCADA protocol of electric and water utilities; polled and unsolicited data, and control, over TCP/UDP 20000 or serial.
---

## What it is and where it sits

DNP3 (Distributed Network Protocol 3) is the SCADA protocol of electric power,
water and wastewater utilities. A master polls outstations (RTUs and IEDs) for
points grouped into classes, outstations send unsolicited responses when values
change, and the master issues control commands (select-before-operate, direct
operate) to actuate outputs. It carries a time model and an internal-indications
word that reports outstation status. DNP3 sits between a control-centre master at
level 2 or 3 and field RTUs at levels 1 and 2, often over wide-area links, which
is why its security extensions (Secure Authentication) matter and its absence is
a common finding.

## Ports

TCP and UDP 20000; also serial. Secure Authentication, where deployed, rides on
the same link.

## What it can do, and what that means

- **Reads** (Read, class polls) return point values and outstation status. Low
  risk, but field RTUs can be fragile.
- **Writes and control** (Select, Operate, Direct Operate) actuate outputs:
  breakers, pumps, set points. A select-then-operate pair closes or opens real
  plant.
- **Device control** (Cold Restart, Warm Restart) restarts an outstation.
- **Unsolicited responses** stream change data; enabling or disabling them
  changes what the master sees.

A control or restart is the [writes](../../lifecycle/wire-classes.md) class: the
engineer present, the exact point and action agreed, announced to the site.
Operating an output has immediate physical effect.

## What to watch for in a capture

- Operate and Direct Operate functions from a host that is not the master.
- Cold or Warm Restart commands to an outstation.
- Disable Unsolicited requests, which stop an outstation reporting changes to
  the master on its own.
- A new master address polling outstations.
- Internal-indications bits flagging restarts, parameter errors or lost time.

## Wireshark display filters

Decoding DNP3 in a capture is the shipped path (see the note on tools below).

```text
# All DNP3
dnp3
# Control functions: Operate (4), Direct Operate (5), Direct Operate No Ack (6)
dnp3.al.func in {4,5,6}
# Select (3), the first half of select-before-operate
dnp3.al.func == 3
# Cold Restart (13) and Warm Restart (14)
dnp3.al.func in {13,14}
# Enable (20) and Disable (21) Unsolicited Messages
dnp3.al.func in {20,21}
# Traffic from or to one station address
dnp3.src == 100 || dnp3.dst == 100
```

## SnapshOT tools that speak or decode it

SnapshOT reads DNP3 passively and does not ship a DNP3 client. **pydnp3 is not
shipped**: it is published only as a source distribution with no wheel, so it
cannot be installed under the vendor layer's wheels-only, hash-pinned contract,
and building it would need a native build stage. The reason is recorded under
"Out of scope and why" on the [vendor layer](../../platform/vendor-layer.md)
page. **Decoding DNP3 in a capture is the shipped path:**

- [tshark](../traffic/tshark.md) and [Wireshark](../traffic/wireshark.md):
  capture and fully decode DNP3, including the application functions and
  internal indications.
- [nmap](../recon/nmap.md) ([Redpoint NSE](../recon/redpoint-nse.md)
  `dnp3-info`, when the vendor layer is present): identify DNP3 outstations.

## ATT&CK for ICS techniques that ride on it

- [Collection](../../lifecycle/attack-ics/collection.md): Monitor Process State
  (T0801).
- [Impair Process Control](../../lifecycle/attack-ics/impair-process-control.md):
  Unauthorized Message: Command Message (T1692.001), Modify Parameter (T0836).
- [Inhibit Response Function](../../lifecycle/attack-ics/inhibit-response-function.md):
  Device Restart/Shutdown (T0816), through Cold and Warm Restart.
- [Initial Access](../../lifecycle/attack-ics/initial-access.md): Rogue Master
  (T0848), a host acting as an unauthorised DNP3 master.

## Upstream specification

- [DNP Users Group](https://www.dnp.org/): the DNP3 specification and the Secure
  Authentication supplement.
