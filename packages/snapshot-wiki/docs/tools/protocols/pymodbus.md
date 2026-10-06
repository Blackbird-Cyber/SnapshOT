---
title: pymodbus
summary: Interactive Modbus client console
folder: protocols
launchers: [snapshot-pymodbus-console.desktop]
ships_as: vendor
package: ics-python
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  identification: Script the Modbus reads a capture showed, from a known unit id, with the engineer present.
  eradication: Read set points and parameters back and compare them with the known-good list before the controller returns to automatic.
  recovery: Confirm restored values read back as expected; write a correction only when the engineer asks for it.
csf: [detect, respond, recover]
attack_ics: [discovery, collection, impair-process-control]
attack_role: resembles
attack_techniques: [T0888, T0801, T1692.001, T0836]
protocols: [modbus]
upstream: https://pymodbus.readthedocs.io/
---

<!-- snapshot:facts -->

!!! warning "Known issues on this build"

    - The pymodbus console launcher (`pymodbus-console`) fails to start on the
      pinned package set with an ImportError from pymodbus-repl. The pymodbus
      library itself works, in scripts and in the ICS Python shell.
    - The serial client (`ModbusSerialClient`, for Modbus RTU and ASCII) needs
      `pyserial`, which the vendor layer does not include, so it stops with an
      error. Modbus TCP works; for a serial line, use [mbpoll](mbpoll.md).

## What it is

pymodbus is a Modbus library for Python with a synchronous and an asynchronous
client. It reads and writes coils, discrete inputs, input registers and holding
registers over Modbus TCP or, given `pyserial`, over a serial line (RTU and
ASCII; not on this image, see the known issues), and it decodes register pairs
into 16, 32 and 64-bit integers, floats and strings. Where
[mbpoll](mbpoll.md) is a one-line command, pymodbus is used when a check needs a
loop, a decode or a condition: scripts run in the [ICS Python
shell](ics-python-shell.md). It also ships an interactive console, which the
menu launcher opens.

## Why it is on SnapshOT

Modbus is the most common protocol on the plant floor, and some Modbus questions
need more than one request: read a block, convert it to engineering units, poll
a handful of registers and compare them. pymodbus gives a responder a scriptable
client for exactly that over Modbus TCP, in the same vendored Python as the
other ICS libraries. For a single read, and for RS-485 or RS-232 adapters,
mbpoll is the tool; for anything with logic in it, pymodbus is.

## On the wire

!!! danger "Writes: it can change what a controller does"

    Reading sends Modbus requests to the device; writing changes coils and
    holding registers, which drive real equipment.

    - **Never write without the engineer responsible for the device present and
      agreeing to the exact register and value.** A wrong register or unit id
      can start a motor or move a set point.
    - Read small ranges from one unit id (`device_id`) at a time; some devices
      and serial gateways cope badly with large or fast requests. Set a short
      `retries` so a no-response does not hammer the device.
    - Modbus holding-register documentation counts from 1 (reference 40001 is
      register 0 on the wire); pymodbus addresses from 0. Check the offset
      before you write.
    - Modbus has no authentication: the device, and the site's monitoring,
      cannot tell your writes from an adversary's. Announce the work.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), a capture may
show a host reading or writing registers it should not touch. With the engineer
present, script the same reads to see what those registers hold and whether the
values make sense for the process. Reads only at this point.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), read a controller's set
points and parameters back and compare them, in the script, with the engineer's
known-good list before it goes back to automatic. A loop makes a whole block
easy to check at once.

### Recovery

During [recovery](../../lifecycle/phases/recovery.md), read the key registers
again to confirm the process runs with the expected values. If the engineer
decides a value must be corrected from the laptop, write it once, read it back
and record both.

## MITRE ATT&CK for ICS mapping

pymodbus *resembles* three tactics, because Modbus cannot tell a responder from
an adversary. Reading a device's identification objects (vendor, product,
revision) looks like Discovery: Remote System Information Discovery (T0888).
Reading registers looks like Collection: Monitor Process State (T0801). Its
writes look like Impair Process Control, through Unauthorized Message: Command
Message (T1692.001) and Modify Parameter (T0836). Announce the work, and when
you find such traffic in a capture, pymodbus is how you check, with approval,
what was read or changed.

## Quick start

```sh
# What the menu launcher runs (it fails on this build: see the known issues above)
/opt/snapshot/ics-python/bin/pymodbus-console --help
# Read 10 holding registers from unit id 1 (a short script in the ICS shell)
/opt/snapshot/ics-python/bin/ics-python -c '
from pymodbus.client import ModbusTcpClient
c = ModbusTcpClient("192.0.2.10", timeout=3, retries=1); c.connect()
print(c.read_holding_registers(0, count=10, device_id=1).registers); c.close()'
# Decode two registers as a 32-bit float
/opt/snapshot/ics-python/bin/ics-python -c '
from pymodbus.client import ModbusTcpClient
c = ModbusTcpClient("192.0.2.10"); c.connect()
rr = c.read_holding_registers(100, count=2, device_id=1)
print(c.convert_from_registers(rr.registers, c.DATATYPE.FLOAT32)); c.close()'
# Read the device identification objects (vendor, product, revision)
/opt/snapshot/ics-python/bin/ics-python -c '
from pymodbus.client import ModbusTcpClient
c = ModbusTcpClient("192.0.2.10"); c.connect()
print(c.read_device_information(device_id=1).information); c.close()'
# WRITE 1234 to holding register 99 (reference 100), read it back: engineer present
/opt/snapshot/ics-python/bin/ics-python -c '
from pymodbus.client import ModbusTcpClient
c = ModbusTcpClient("192.0.2.10", retries=1); c.connect()
print(c.write_register(99, 1234, device_id=1))
print(c.read_holding_registers(99, count=1, device_id=1).registers); c.close()'
```

`192.0.2.10` is a documentation address. Unit ids are passed as `device_id`,
counts as `count=`. For Modbus RTU on a serial line, use [mbpoll](mbpoll.md):
pymodbus's serial client needs `pyserial`, which the vendor layer does not
include, so `ModbusSerialClient` stops with an error on this image.

## Output and evidence

Save the script and its output together, since the script is the record of
exactly what was sent:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/modbus"
/opt/snapshot/ics-python/bin/ics-python "$CASE/modbus/read-plc01.py" | tee "$CASE/modbus/plc01.txt"
sha256sum "$CASE"/modbus/read-plc01.py "$CASE"/modbus/plc01.txt >> "$CASE/SHA256SUMS"
```

Run a [tshark](../traffic/tshark.md) capture at the same time when the session
matters: the packets are the evidence of what was sent and how the device
answered.

## Related tools

- [mbpoll](mbpoll.md): a one-line Modbus read or write when no script is needed.
- [ICS Python shell](ics-python-shell.md): the environment pymodbus runs in,
  with the other ICS libraries.
- [plcscan](plcscan.md) and [nmap](../recon/nmap.md) (`modbus-discover`): find
  Modbus devices and unit ids before you read registers.
- [tshark](../traffic/tshark.md): find the Modbus traffic worth checking, and
  capture your own requests while you make them.

## Upstream documentation

- [pymodbus documentation](https://pymodbus.readthedocs.io/): the client API,
  data types and the interactive console.
- [Modbus specifications](https://modbus.org/specs.php): function codes and the
  data model.
