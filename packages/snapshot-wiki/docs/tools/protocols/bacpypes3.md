---
title: BACpypes3
summary: BACnet client and server library for Python
folder: protocols
launchers: []
ships_as: vendor
package: ics-python
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  identification: Send a Who-Is and read device and object properties from the ICS shell, with the engineer present.
  eradication: Read object present-values and settings back and compare them with the known-good list before the system returns to service.
  recovery: Confirm restored objects read back the expected values before the process owner returns the system to normal.
csf: [detect, respond, recover]
attack_ics: [discovery, collection, impair-process-control]
attack_role: resembles
attack_techniques: [T0846, T0846.002, T0888, T0801, T0836]
protocols: [bacnet]
upstream: https://github.com/JoelBender/BACpypes3
---

<!-- snapshot:facts -->

## What it is

BACpypes3 is a Python implementation of BACnet, the building-automation
protocol. It can act as a BACnet device and send the protocol's requests:
Who-Is and Who-Has to find devices, read-property and read-property-multiple to
read object values, and write-property to change them. It runs as an interactive
console (`ics-python -m bacpypes3`) or as a library in the [ICS Python
shell](ics-python-shell.md). [BAC0](bac0.md) is a friendlier layer built on top
of it; BACpypes3 is the lower-level tool when you need exact control of a
request.

## Why it is on SnapshOT

BACnet runs the HVAC, lighting, access and energy systems that increasingly
share a network with industrial control, and an incident often crosses into
them. BACpypes3 lets a responder enumerate BACnet devices and read the objects a
capture showed, speaking the protocol directly so the request is exactly what
you intend. It is the foundation under [BAC0](bac0.md); both ship in the same
vendored Python.

## On the wire

!!! danger "Writes: write-property changes building systems"

    Who-Is and read-property only ask; write-property changes an object a
    controller acts on, which can move a damper, a valve or a set point.

    - **Never write a property without the engineer responsible present and
      agreeing to the exact object, property and value.**
    - Who-Is with no range is a broadcast to every device on the segment; bound
      it with instance limits (`whois * 1000 1099`), or address a single device
      (`whois 192.0.2.40`), on a busy network.
    - BACnet/IP uses UDP broadcast heavily; the laptop must have an address on
      the segment to receive replies, and the console runs as a BACnet device
      of its own (`--instance`) that answers other devices' Who-Is. The laptop
      is visible; note that in the case, and pick an instance number the site
      does not use.
    - On a commandable object a write lands in the priority array: without a
      priority it goes in at 16, the lowest. A write at a higher priority (a
      lower number) overrides the building system's own commands until it is
      relinquished, so agree the priority with the engineer.
    - BACnet has no authentication: devices, and the site's monitoring, cannot
      tell your requests from an adversary's. Announce the work.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), a Who-Is finds
the BACnet devices on a segment, and read-property reads the objects a capture
referenced, with the engineer present. Reads only at this point.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), read object
present-values and settings back and compare them with the engineer's known-good
list before the system returns to service. Read the priority array of
commandable objects as well as the present-value: a value held at a high
priority by an unknown writer is exactly what an adversary would leave behind.
Alarm limits and schedules deserve the same check, since changing them can
silence a response.

### Recovery

During [recovery](../../lifecycle/phases/recovery.md), read the key objects again
to confirm they hold the expected values before the process owner returns the
system to normal operation. Use the same console commands as in eradication so
the two transcripts compare line for line, and keep them with the case.

## MITRE ATT&CK for ICS mapping

BACpypes3 *resembles* three tactics. Who-Is and Who-Has look like Discovery:
Remote System Discovery (T0846), in the form of Remote System Discovery:
Broadcast Discovery (T0846.002), and reading a device object's vendor and
firmware looks like Remote System Information Discovery (T0888). Reading object
values looks like Collection: Monitor Process State (T0801). write-property
looks like Impair Process Control: Modify Parameter (T0836). The traffic is the
same as an adversary using the same library, so BACnet work is announced to the
site.

## Quick start

```sh
# The console's options (local address, device instance, BBMD and foreign device)
/opt/snapshot/ics-python/bin/ics-python -m bacpypes3 --help
# Open the BACpypes3 console as a device on the segment
/opt/snapshot/ics-python/bin/ics-python -m bacpypes3 --address 192.0.2.100/24 --instance 999
```

Inside the console, each command is one line (the `#` lines explain them; do
not type them):

```text
# Ask one device for its I-Am
whois 192.0.2.40
# Who-Is to the whole segment, limited to device instances 1000 to 1099
whois * 1000 1099
# Read a device's object name
read 192.0.2.40 device,1001 object-name
# Read several properties at once
rpm 192.0.2.40 device,1001 object-name vendor-name firmware-revision
# WRITE a property: only with the engineer present
write 192.0.2.40 analog-value,1 present-value 21.0
```

`192.0.2.100/24` is the laptop's documentation address on the segment and
`192.0.2.40` a documentation device address. BACnet/IP uses UDP 47808. Type
`help` in the console for the other commands (`whohas`, `iam`, and the BBMD
table reads and writes).

## Output and evidence

Capture the console session to the case folder:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/bacnet"
LOG="$CASE/bacnet/session-$(date -u +%Y%m%dT%H%M%SZ).log"
BAC='/opt/snapshot/ics-python/bin/ics-python -m bacpypes3 --address 192.0.2.100/24 --instance 999'
script -q -c "$BAC" "$LOG"
sha256sum "$LOG" >> "$CASE/SHA256SUMS"
```

Capture with [tshark](../traffic/tshark.md) at the same time; the BACnet service
names show which requests you sent.

## Related tools

- [BAC0](bac0.md): a higher-level BACnet layer built on BACpypes3.
- [ICS Python shell](ics-python-shell.md): the environment BACpypes3 runs in.
- [nmap](../recon/nmap.md): `bacnet-info` reads one device's identity without
  starting a BACnet device on the laptop.
- [tshark](../traffic/tshark.md): decode BACnet in a capture.

## Upstream documentation

- [BACpypes3 on GitHub](https://github.com/JoelBender/BACpypes3): the library,
  console and examples.
- [BACnet (ASHRAE)](http://www.bacnet.org/): the standard and object model.
