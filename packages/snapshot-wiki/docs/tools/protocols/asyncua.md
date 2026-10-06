---
title: asyncua
summary: OPC UA client and server library for Python
folder: protocols
launchers: []
ships_as: vendor
package: ics-python
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  identification: Browse an OPC UA server's address space and read node values from the ICS shell, with the engineer present.
  eradication: Read node values and server identity back and compare them with the known-good list before the system returns to service.
  recovery: Confirm restored nodes read back the expected values before the process owner returns the system to normal.
csf: [detect, respond, recover]
attack_ics: [collection, impair-process-control]
attack_role: resembles
attack_techniques: [T0801, T0861, T0836]
protocols: [opc-ua]
upstream: https://opcua-asyncio.readthedocs.io/
---

<!-- snapshot:facts -->

## What it is

asyncua is a pure-Python OPC UA stack with both a client and a server. As a
client it connects to an OPC UA server, browses its address space, reads and
writes node values and attributes, subscribes to data changes and calls server
methods. The command-line tools on the [OPC UA command-line
tools](opcua-cli-tools.md) page are thin wrappers around this same library;
asyncua is what you use from the [ICS Python shell](ics-python-shell.md) when a
check needs more than one of those commands can express.

## Why it is on SnapshOT

OPC UA is the modern supervisory protocol between SCADA, historians and
controllers, and its data is a tree of nodes rather than a flat register map.
asyncua lets a responder walk that tree, read the nodes a capture referenced and
confirm server identity, in a scriptable way that records exactly what was asked.
Its small server is also useful as a safe target for practising the client
tools off the plant.

## On the wire

!!! danger "Writes: it can change what a server exposes"

    Browsing and reading send OPC UA requests; writing a node value or calling a
    server method changes what the server, and the process behind it, does.

    - **Never write a node or call a method without the engineer responsible
      present and agreeing to the exact node, method and value.** A method can
      do anything the server allows.
    - Browse a subtree at a time rather than the whole address space of a large
      server; a deep recursive browse is a lot of requests. A subscription keeps
      a session open until you close it.
    - OPC UA can require certificates and encryption. On the plant floor many
      servers allow anonymous, unencrypted sessions; note which, because that is
      itself a finding.
    - Run the library's server only on the laptop or a lab host, never where it
      could be mistaken for a plant server, and bind it to the loopback address:
      the example server (`uaserver`) listens on every interface by default.
      Announce any active OPC UA work.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), connect to an
OPC UA server seen on the wire, browse the branch a capture referenced and, with
the engineer present, read the nodes in question to confirm what they hold.
Reads only at this point.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), read node values and the
server's identity back and compare them with the engineer's known-good list
before the system returns to service. A script can walk the same branch every
time and print each node id with its value, which turns the comparison into a
simple diff against the list. Also check the endpoints and security policies
the server offers, since an adversary may have weakened them.

### Recovery

During [recovery](../../lifecycle/phases/recovery.md), read the key nodes again
to confirm they hold the expected values before the process owner returns the
system to normal operation. Rerun the eradication script unchanged so the two
outputs compare directly, and keep both with the case as the record of what
the server exposed when it went back into service.

## MITRE ATT&CK for ICS mapping

asyncua *resembles* Collection and Impair Process Control. Reading node values
looks like Monitor Process State (T0801), and browsing the address space to find
them looks like Point & Tag Identification (T0861). Writing a node value looks
like Modify Parameter (T0836). The traffic is the same as an adversary using the
same library, so OPC UA work is announced to the site's monitoring.

## Quick start

```sh
# Browse the Objects node of a server and print its children
/opt/snapshot/ics-python/bin/ics-python -c '
import asyncio
from asyncua import Client
async def main():
    async with Client("opc.tcp://192.0.2.50:4840") as c:
        for n in await c.nodes.objects.get_children():
            print(n.nodeid.to_string(), (await n.read_browse_name()).to_string())
asyncio.run(main())'
# Read one node value by its node id
/opt/snapshot/ics-python/bin/ics-python -c '
import asyncio
from asyncua import Client
async def main():
    async with Client("opc.tcp://192.0.2.50:4840") as c:
        print(await c.get_node("ns=2;i=3").read_value())
asyncio.run(main())'
# Read the server's clock (i=2258) with the synchronous client, no async code
/opt/snapshot/ics-python/bin/ics-python -c '
from asyncua.sync import Client
with Client("opc.tcp://192.0.2.50:4840") as c:
    print(c.get_node("i=2258").read_value())'
# WRITE a double to a node and read it back: only with the engineer present
/opt/snapshot/ics-python/bin/ics-python -c '
from asyncua import ua
from asyncua.sync import Client
with Client("opc.tcp://192.0.2.50:4840") as c:
    n = c.get_node("ns=2;i=2"); n.write_value(ua.Variant(8.5, ua.VariantType.Double))
    print(n.read_value())'
```

`opc.tcp://192.0.2.50:4840` is a documentation address on the OPC UA default
port 4840. Node ids are numeric in namespace 0 (`i=2258`, the server's
CurrentTime) or namespaced (`ns=2;i=3`); browse first to find the ones you need.

## Output and evidence

Save the script and its output together:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/opcua"
/opt/snapshot/ics-python/bin/ics-python "$CASE/opcua/read-server1.py" \
  | tee "$CASE/opcua/server1.txt"
sha256sum "$CASE"/opcua/read-server1.py "$CASE"/opcua/server1.txt >> "$CASE/SHA256SUMS"
```

Capture with [tshark](../traffic/tshark.md) at the same time; the OPC UA
service names show which requests you sent.

## Related tools

- [OPC UA command-line tools](opcua-cli-tools.md): `uadiscover`, `uals`,
  `uaread` and the rest, built on this library, for one-line checks.
- [opcua-client](opcua-client.md): the graphical client (amd64 only).
- [tshark](../traffic/tshark.md): decode OPC UA in a capture.

## Upstream documentation

- [opcua-asyncio documentation](https://opcua-asyncio.readthedocs.io/): the
  client and server API.
- [OPC Foundation, OPC UA](https://opcfoundation.org/about/opc-technologies/opc-ua/):
  the specification and information model.
