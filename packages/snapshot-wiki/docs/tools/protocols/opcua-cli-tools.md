---
title: OPC UA command-line tools
summary: Discover OPC UA servers on the network
folder: protocols
launchers: [snapshot-uadiscover.desktop]
ships_as: vendor
package: ics-python
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  identification: Discover OPC UA servers, browse an address space and read node values, one server at a time, with the engineer present.
  eradication: Read node values and history back and compare them with the known-good list before the system returns to service.
  recovery: Confirm restored nodes read back the expected values before the process owner returns the system to normal.
csf: [detect, respond, recover]
attack_ics: [discovery, collection, impair-process-control]
attack_role: resembles
attack_techniques: [T0888, T0801, T0861, T0836]
protocols: [opc-ua]
upstream: https://opcua-asyncio.readthedocs.io/
---

<!-- snapshot:facts -->

## What it is

The OPC UA command-line tools are a set of small programs for working with an
OPC UA server from the terminal, without writing any Python. SnapshOT ships
`uadiscover` (find servers and list their endpoints), `uals` (browse the address
space), `uaread` and `uawrite` (read and write a node), `uasubscribe` (watch a
node for data changes), `uahistoryread` (read a node's history), `uacall` (call
a server method), `uaclient` (open a Python shell connected to a server) and
`uaserver` (run a small example server). They are the console scripts of the
[asyncua](asyncua.md) library, installed in `/opt/snapshot/ics-python/bin` and
linked into `/opt/snapshot/bin`, which is on `PATH`, so they also work by bare
name.

## Why it is on SnapshOT

OPC UA is where a responder often has to answer a question quickly: is there a
server here, what does it expose, what is this node worth? These commands do each
of those in one line, which is easy to run and easy to record; when a check needs
real logic, the same library is available as [asyncua](asyncua.md) in the
[ICS Python shell](ics-python-shell.md). `uadiscover` in particular is the first step against an
OPC UA endpoint seen in a capture.

## On the wire

!!! danger "Writes: uawrite and uacall can change the process"

    Most of these commands only read, but `uawrite` changes a node value,
    `uacall` runs a server method, and `uaserver` stands up a server of its own.

    - **Never run `uawrite` or `uacall` without the engineer responsible
      present and agreeing to the exact node, method and value.** A method can
      do anything the server allows.
    - Browse with a bounded `--depth`; a deep browse of a large server is many
      requests. Work one server at a time.
    - `uasubscribe` keeps a session open and streams changes until you stop it;
      note how long you watched.
    - `uaserver` listens on every interface, on port 4840, unless told
      otherwise. Run it only on the laptop or a lab host, bound to the loopback
      address with `-u`, never where it could be taken for a plant server.
    - Announce any active OPC UA work to the site: an anonymous session looks
      the same whether it is yours or an adversary's.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), `uadiscover`
confirms an OPC UA endpoint and lists its security policies, `uals` browses to
the node a capture referenced, and `uaread` reads it, with the engineer present.
An endpoint that offers security policy None with anonymous login is a finding
in its own right; record it. Reads only at this point.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), `uaread` and
`uahistoryread` read current and past node values back for comparison with the
engineer's known-good list before the system returns to service. The history
can show when a value changed, which helps place the adversary's change on the
incident timeline, if the server keeps history for that node. Run `uadiscover`
again too, to check the endpoints and policies were not weakened.

### Recovery

During [recovery](../../lifecycle/phases/recovery.md), `uaread` confirms the key
nodes hold the expected values before the process owner returns the system to
normal operation. Run the same commands as in eradication so the outputs
compare line for line, and keep them with the case.

## MITRE ATT&CK for ICS mapping

This tool set *resembles* three tactics. `uadiscover` looks like Discovery:
Remote System Information Discovery (T0888), because it asks a server what it is
and what endpoints it offers. `uals` and `uaread` look like Collection: Point &
Tag Identification (T0861) and Monitor Process State (T0801). `uawrite` looks
like Impair Process Control: Modify Parameter (T0836). Their traffic is the same
as an adversary using the same scripts, so OPC UA work is announced to the
site's monitoring.

## Quick start

```sh
# What the menu launcher runs: uadiscover help
/opt/snapshot/ics-python/bin/uadiscover -h
# Discover a server and list its endpoints and security policies
/opt/snapshot/ics-python/bin/uadiscover -u opc.tcp://192.0.2.50:4840
# Browse from the Objects node, one level deep, long format
/opt/snapshot/ics-python/bin/uals -u opc.tcp://192.0.2.50:4840 -n i=85 -d 1 -l
# Read one node value by its node id
/opt/snapshot/ics-python/bin/uaread -u opc.tcp://192.0.2.50:4840 -n 'ns=2;i=3'
# Watch a node for data changes (Ctrl+C to stop)
/opt/snapshot/ics-python/bin/uasubscribe -u opc.tcp://192.0.2.50:4840 -n 'ns=2;i=3'
# Read a node's recorded history
/opt/snapshot/ics-python/bin/uahistoryread -u opc.tcp://192.0.2.50:4840 -n 'ns=2;i=3' -l 50
# WRITE a double to a node: only with the engineer present
/opt/snapshot/ics-python/bin/uawrite -u opc.tcp://192.0.2.50:4840 -n 'ns=2;i=2' -t double 8.5
# A practice server with sample nodes, on the loopback address only
/opt/snapshot/ics-python/bin/uaserver -u opc.tcp://127.0.0.1:4840 -p
```

`opc.tcp://192.0.2.50:4840` is a documentation address on the OPC UA default
port 4840. Node ids are either numeric (`i=85`) or namespaced (`ns=2;i=3`).
The commands that open a session (`uals`, `uaread`, `uawrite`, `uasubscribe`,
`uahistoryread`, `uacall`, `uaclient`) take `--security`, `--user` and
`--password` for a server that does not allow anonymous, unencrypted sessions.

## Output and evidence

Record what each command read, with the command line and the UTC time:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/opcua"
{ date -u; echo '$ uadiscover -u opc.tcp://192.0.2.50:4840';
  /opt/snapshot/ics-python/bin/uadiscover -u opc.tcp://192.0.2.50:4840; } \
  2>&1 | tee -a "$CASE/opcua/server1.txt"
sha256sum "$CASE"/opcua/*.txt >> "$CASE/SHA256SUMS"
```

Capture with [tshark](../traffic/tshark.md) when the session matters.

## Related tools

- [asyncua](asyncua.md): the library these commands wrap, for scripted checks.
- [opcua-client](opcua-client.md): the graphical client (amd64 only).
- [tshark](../traffic/tshark.md): decode OPC UA in a capture.

## Upstream documentation

- [opcua-asyncio documentation](https://opcua-asyncio.readthedocs.io/): the
  library and its console tools.
- [OPC Foundation, OPC UA](https://opcfoundation.org/about/opc-technologies/opc-ua/):
  the specification.
