---
title: BAC0
summary: High-level BACnet scripting on top of BACpypes3
folder: protocols
launchers: []
ships_as: vendor
package: ics-python
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  identification: Discover BACnet devices and read object present-values from the ICS shell, with the engineer present.
  eradication: Read object values and settings back and compare them with the known-good list before the system returns to service.
  recovery: Confirm restored objects read back the expected values before the process owner returns the system to normal.
csf: [detect, respond, recover]
attack_ics: [discovery, collection, impair-process-control]
attack_role: resembles
attack_techniques: [T0846, T0846.002, T0888, T0801, T0836]
protocols: [bacnet]
upstream: https://bac0.readthedocs.io/
---

<!-- snapshot:facts -->

## What it is

BAC0 is a higher-level BACnet library built on [BACpypes3](bacpypes3.md). It
hides the protocol detail behind short calls: start a BACnet application, run a
Who-Is to discover devices, read an object's present-value with one string, read
several properties at once and write a property. It is meant for interactive and
scripted use from the [ICS Python shell](ics-python-shell.md), and reads a device
address, object and property in a compact `"address object instance property"`
form.

## Why it is on SnapshOT

When the question is simply "what BACnet devices are here and what are these
objects reading", BAC0 asks it in fewer lines than BACpypes3, which makes it the
quicker tool for a responder working interactively. It shares the same BACnet
stack, so the two agree on the wire; use BAC0 for speed and BACpypes3 when you
need to shape a request exactly.

## On the wire

!!! danger "Writes: write changes building systems"

    Discovery and read only ask; `write` changes an object a controller acts on.

    - **Never write without the engineer responsible present and agreeing to the
      exact object, property and value.**
    - `who_is()` with no arguments broadcasts to the whole segment; bound it
      with `low_limit` and `high_limit`, or pass a single device's address, on
      a busy network. Pass `ping=False` so BAC0 does not poll registered
      devices on its own.
    - BAC0 takes an address on the segment to send and receive BACnet/IP and
      runs as a BACnet device of its own, so the laptop is visible on the
      network; record that.
    - `write()` takes one string,
      `"<address> <object> <instance> <property> <value> - <priority>"`,
      starts the write in the background and returns at once, so read the
      value back to see what happened. The BAC0 on this image parses whole
      numbers only: `21.5` is sent as `21` and the priority after it is
      dropped. Write decimal values with [BACpypes3](bacpypes3.md) instead.
    - BACnet has no authentication: devices, and the site's monitoring, cannot
      tell your requests from an adversary's. Announce the work.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), a Who-Is
discovers BACnet devices and a read confirms the present-value of the objects a
capture referenced, with the engineer present. Reads only at this point.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), read object values and
settings back and compare them with the engineer's known-good list before the
system returns to service. `readMultiple` reads several properties of an object
in one request, which keeps a check of many set points short and easy to repeat.
Include the priority array of commandable objects, where a value held by an
unknown writer shows up, and the alarm limits, which an adversary may have
widened.

### Recovery

During [recovery](../../lifecycle/phases/recovery.md), read the key objects again
to confirm they hold the expected values before the process owner returns the
system to normal operation. Rerun the eradication script unchanged so the two
outputs compare directly, and keep both with the case.

## MITRE ATT&CK for ICS mapping

BAC0 *resembles* three tactics, the same as BACpypes3 beneath it. Who-Is looks
like Discovery: Remote System Discovery (T0846), in the form of Remote System
Discovery: Broadcast Discovery (T0846.002), and reading a device object's vendor
and firmware looks like Remote System Information Discovery (T0888). Reading
objects looks like Collection: Monitor Process State (T0801). `write` looks like
Impair Process Control: Modify Parameter (T0836). The traffic is the same as an
adversary using the same library, so BACnet work is announced to the site.

## Quick start

```sh
# Ask one device for its I-Am, then read its name, vendor and firmware
/opt/snapshot/ics-python/bin/ics-python -c '
import asyncio, BAC0
async def main():
    async with BAC0.start(ip="192.0.2.100/24", ping=False) as bacnet:
        print(await bacnet.who_is("192.0.2.40"))
        print(await bacnet.readMultiple(
            "192.0.2.40 device 1001 objectName vendorName firmwareRevision"))
asyncio.run(main())'
# Who-Is to the whole segment, limited to device instances 1000 to 1099
/opt/snapshot/ics-python/bin/ics-python -c '
import asyncio, BAC0
async def main():
    async with BAC0.start(ip="192.0.2.100/24", ping=False) as bacnet:
        print(await bacnet.who_is(low_limit=1000, high_limit=1099))
asyncio.run(main())'
# Read one object's present-value
/opt/snapshot/ics-python/bin/ics-python -c '
import asyncio, BAC0
async def main():
    async with BAC0.start(ip="192.0.2.100/24", ping=False) as bacnet:
        print(await bacnet.read("192.0.2.40 analogValue 1 presentValue"))
asyncio.run(main())'
```

`192.0.2.100/24` is the laptop's documentation address on the segment and
`192.0.2.40` a documentation device address. BACnet/IP uses UDP 47808. Object
types and properties are written in BACnet's camel case (`analogValue`,
`presentValue`) or with dashes (`analog-value`, `present-value`).

## Output and evidence

Save the script and its output together:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/bacnet"
/opt/snapshot/ics-python/bin/ics-python "$CASE/bacnet/discover.py" | tee "$CASE/bacnet/discover.txt"
sha256sum "$CASE"/bacnet/discover.py "$CASE"/bacnet/discover.txt >> "$CASE/SHA256SUMS"
```

Capture with [tshark](../traffic/tshark.md) at the same time; the BACnet service
names show which requests you sent.

## Related tools

- [BACpypes3](bacpypes3.md): the BACnet stack under BAC0, for exact control.
- [ICS Python shell](ics-python-shell.md): the environment BAC0 runs in.
- [tshark](../traffic/tshark.md): decode BACnet in a capture.

## Upstream documentation

- [BAC0 documentation](https://bac0.readthedocs.io/): the API and examples.
- [BACnet (ASHRAE)](http://www.bacnet.org/): the standard and object model.
