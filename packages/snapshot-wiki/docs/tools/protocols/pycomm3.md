---
title: pycomm3
summary: EtherNet/IP and CIP client library for Allen-Bradley PLCs
folder: protocols
launchers: []
ships_as: vendor
package: ics-python
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  identification: Read the identity and a few tags of an EtherNet/IP device seen on the wire, from the ICS shell, with the engineer present.
  eradication: Read tag values and controller information back and compare them with the known-good list before the controller returns to automatic.
  recovery: Confirm restored tags read back as expected before the process owner returns the line to automatic control.
csf: [detect, respond, recover]
attack_ics: [discovery, collection, impair-process-control]
attack_role: resembles
attack_techniques: [T0846, T0846.002, T0888, T0801, T0861, T0836]
protocols: [ethernet-ip]
upstream: https://docs.pycomm3.dev/
---

<!-- snapshot:facts -->

## What it is

pycomm3 is a Python library that speaks EtherNet/IP and the Common Industrial
Protocol (CIP) to Allen-Bradley programmable controllers: ControlLogix and
CompactLogix (its `LogixDriver`), the older SLC and PLC-5 family (`SLCDriver`)
and any CIP device (`CIPDriver`). It reads and writes named tags, lists the tag
database, reports the controller's identity, model and revision, and can send
raw CIP messages. SnapshOT carries it because the vendor layer's EtherNet/IP
coverage rests on it: scripts run in the [ICS Python shell](ics-python-shell.md).

## Why it is on SnapshOT

EtherNet/IP and CIP are the common language of Rockwell plants, and unlike
Modbus a CIP device is addressed by tag name rather than register number.
pycomm3 lets a responder ask such a device for its identity, list its tags and
read named values, which is the quickest way to confirm what a capture showed
without guessing offsets. It is the shipped answer for EtherNet/IP: cpppo, the
other common option, was dropped because it cannot be installed under the
vendor layer's wheels-only rule (see the [vendor
layer](../../platform/vendor-layer.md)).

## On the wire

!!! danger "Writes: it can change what a controller does"

    Reading tags and identity sends CIP requests; writing a tag changes a value
    the controller acts on.

    - **Never write a tag without the engineer responsible for the controller
      present and agreeing to the exact tag and value.**
    - A broadcast discovery (`CIPDriver.discover()`) sends to the whole subnet;
      prefer naming a single host (`CIPDriver.list_identity()`).
    - Opening a `LogixDriver` uploads the controller's tag definitions, which
      is a burst of traffic, and reads and writes need those definitions. Pass
      `init_program_tags=False` to skip program-scoped tags you do not need,
      or `init_tags=False` when you only want the controller's identity
      (`plc.info`) and no tag reads.
    - Give the full CIP path including the backplane slot (for example
      `192.0.2.30/1`) so the request reaches the processor, not a bridge.
    - EtherNet/IP has no authentication on most plant floors (CIP Security is
      rarely deployed): the controller, and the site's monitoring, cannot tell
      your requests from an adversary's. Announce the work.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), read the
identity (vendor, product, revision) of an EtherNet/IP device seen on the wire
and, with the engineer present, a few named tags, to confirm what it is and what
a capture showed. Reads only at this point.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), read tag values and the
controller's information back and compare them with the engineer's known-good
list before the controller returns to automatic. A short script can check a
whole set of tags at once.

### Recovery

During [recovery](../../lifecycle/phases/recovery.md), read the key tags again
to confirm the controller holds the expected values before the process owner
returns the line to automatic control. Run the same script as in eradication so
the two results compare line for line, and check `plc.info` too: a revision or
program name that differs from the record means the controller is not running
what the engineer restored. Keep each run's output with the case.

## MITRE ATT&CK for ICS mapping

pycomm3 *resembles* three tactics. A broadcast discovery looks like Discovery:
Remote System Discovery (T0846), in the form of Remote System Discovery:
Broadcast Discovery (T0846.002), and reading a device's identity looks like
Remote System Information Discovery (T0888). Reading tag values looks like
Collection: Monitor Process State (T0801), and listing the tag database like
Point & Tag Identification (T0861). Writing a tag looks like
Impair Process Control: Modify Parameter (T0836). The traffic is the same as an
adversary using the same library, so announce it to the site.

## Quick start

```sh
# Discover EtherNet/IP devices on the local subnet (sends a broadcast)
/opt/snapshot/ics-python/bin/ics-python -c '
from pycomm3 import CIPDriver
for d in CIPDriver.discover(): print(d["ip_address"], d["product_name"], d["revision"])'
# Read one device's identity object without listing its tags
/opt/snapshot/ics-python/bin/ics-python -c '
from pycomm3 import CIPDriver
print(CIPDriver.list_identity("192.0.2.30"))'
# Open a Logix controller (slot 1) without its tag list; print model, revision, name
/opt/snapshot/ics-python/bin/ics-python -c '
from pycomm3 import LogixDriver
with LogixDriver("192.0.2.30/1", init_tags=False) as plc:
    print(plc.info)'
# Read two controller-scoped tags (uploads controller tag definitions, not program ones)
/opt/snapshot/ics-python/bin/ics-python -c '
from pycomm3 import LogixDriver
with LogixDriver("192.0.2.30/1", init_program_tags=False) as plc:
    print(plc.read("Tank_Level", "Pump1_Speed"))'
# List the controller tag database (one burst of traffic)
/opt/snapshot/ics-python/bin/ics-python -c '
from pycomm3 import LogixDriver
with LogixDriver("192.0.2.30/1") as plc:
    print(list(plc.tags)[:20])'
```

`192.0.2.30` is a documentation address; `/1` is the backplane slot of the
processor (leave it off for a CompactLogix or a processor in slot 0). A tag
name that does not exist comes back as a `Tag` with an error, not as an
exception. EtherNet/IP uses TCP and UDP 44818.

## Output and evidence

Save the script and its output together under the case folder:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/enip"
/opt/snapshot/ics-python/bin/ics-python "$CASE/enip/read-plc01.py" | tee "$CASE/enip/plc01.txt"
sha256sum "$CASE"/enip/read-plc01.py "$CASE"/enip/plc01.txt >> "$CASE/SHA256SUMS"
```

Capture with [tshark](../traffic/tshark.md) at the same time; the CIP packets
show exactly which services and tags were requested.

## Related tools

- [ICS Python shell](ics-python-shell.md): the environment pycomm3 runs in.
- [plcscan](plcscan.md) and [nmap](../recon/nmap.md): find and identify devices
  (`enip-info`) before you read tags.
- [tshark](../traffic/tshark.md): decode EtherNet/IP and CIP in a capture.

## Upstream documentation

- [pycomm3 documentation](https://docs.pycomm3.dev/): the drivers, tag reads and
  writes, and CIP messaging.
- [ODVA, EtherNet/IP](https://www.odva.org/technology-standards/key-technologies/ethernet-ip/):
  the protocol and CIP object model.
