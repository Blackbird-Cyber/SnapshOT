---
title: Modbus
summary: The oldest and most common plant-floor protocol; simple, unauthenticated register access over TCP or serial.
---

## What it is and where it sits

Modbus is the simplest and most widespread industrial protocol. A master (a
SCADA server, an HMI or an engineering laptop) reads and writes numbered data
points on a slave device (a PLC, an RTU, a drive, a meter). The data model is
four flat tables: coils and discrete inputs (single bits) and holding and input
registers (16-bit words). There is no session, no authentication and no
built-in integrity: a request is a function code, an address and a count, and
the device answers. On the Purdue model Modbus sits at levels 1 and 2, between
controllers and their supervisory systems, and on serial links down to field
devices.

## Ports

TCP 502; RTU and ASCII over RS-232 and RS-485. Modbus/TCP wraps the same
requests in a short MBAP header carrying a transaction id and a unit id (the
slave address, which still matters behind a serial-to-TCP gateway).

## What it can do, and what that means

- **Reads** (function codes 1 to 4, and 43/14 Read Device Identification) ask a
  device for register and coil values and for its vendor and product strings.
  Reads are low risk, but still a request a fragile stack must answer.
- **Writes** (5, 6, 15, 16, 22, 23) change coils and holding registers, which
  drive real outputs: a set point, a mode bit, a valve. A single wrong write can
  move the process.
- Standard Modbus has **no program download**: its public function codes carry
  no logic or firmware. Vendors do tunnel their own engineering services
  through it, though: Schneider Electric's UMAS programs Modicon controllers
  over function code 90, so that code is engineering traffic, not polling.
- Otherwise the risk is in writes to live values, and in the fact that the
  device cannot tell an authorised master from an adversary.

Treat any write as the [writes](../../lifecycle/wire-classes.md) class: the
engineer present, the exact register and value agreed, announced to the site.

## What to watch for in a capture

- Writes (function codes 5, 6, 15, 16, 22, 23) from a host that should only
  read, or at a time no operator was working.
- A new master address polling or writing registers it has no reason to touch.
- Reads of Device Identification or sweeps across unit ids, which look like an
  adversary learning the devices.
- Modbus exceptions (illegal function, illegal data address), which can mark
  probing or a mismatch between master and device.
- Function code 90 from a host that is not the engineering workstation:
  someone may be reading or changing a Modicon controller's program.

## Wireshark display filters

```text
# All Modbus/TCP
mbtcp
# Write requests and replies (single/multiple coils and registers, mask, read/write)
modbus.func_code in {5,6,15,16,22,23}
# Read Device Identification (MEI type 14 under function 43)
modbus.func_code == 43 && modbus.mei == 14
# Traffic to or from one unit id
mbtcp.unit_id == 1
# Any Modbus exception response
modbus.exception_code
# Function code 90, used by Schneider Electric's UMAS engineering protocol
modbus.func_code == 90
```

## SnapshOT tools that speak or decode it

- [mbpoll](../protocols/mbpoll.md): one-line Modbus reads and writes, TCP or
  serial.
- [pymodbus](../protocols/pymodbus.md): scripted Modbus from the
  [ICS Python shell](../protocols/ics-python-shell.md).
- [plcscan](../protocols/plcscan.md) and [nmap](../recon/nmap.md)
  (`modbus-discover`): find Modbus devices and unit ids.
- [tshark](../traffic/tshark.md) and [Wireshark](../traffic/wireshark.md):
  capture and decode Modbus.

## ATT&CK for ICS techniques that ride on it

- [Discovery](../../lifecycle/attack-ics/discovery.md): Remote System
  Information Discovery (T0888), through Read Device Identification.
- [Collection](../../lifecycle/attack-ics/collection.md): Monitor Process State
  (T0801), Point & Tag Identification (T0861).
- [Impair Process Control](../../lifecycle/attack-ics/impair-process-control.md):
  Unauthorized Message: Command Message (T1692.001), Modify Parameter (T0836),
  Brute Force I/O (T0806).
- [Initial Access](../../lifecycle/attack-ics/initial-access.md): Rogue Master
  (T0848), a host acting as an unauthorised Modbus master.

## Upstream specification

- [Modbus specifications](https://modbus.org/specs.php): the application
  protocol, the TCP mapping and the serial line specification.
