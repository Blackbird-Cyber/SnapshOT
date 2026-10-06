---
title: OPC UA Client (GUI)
summary: Graphical OPC UA client
folder: protocols
launchers: [snapshot-opcua-client.desktop]
ships_as: vendor
package: opcua-client
arch: [amd64]
status: shipped
wire: writes
phases:
  identification: Connect to an OPC UA server, browse its address space and read node values, with the engineer present.
  eradication: Read node values and attributes back and compare them with the known-good list before the system returns to service.
  recovery: Confirm restored nodes read back the expected values before the process owner returns the system to normal.
csf: [detect, respond, recover]
attack_ics: [collection, impair-process-control]
attack_role: resembles
attack_techniques: [T0801, T0861, T0836]
protocols: [opc-ua]
upstream: https://github.com/FreeOpcUa/opcua-client-gui
---

<!-- snapshot:facts -->

## What it is

The OPC UA Client is a graphical client for OPC UA servers. It connects to a
server, shows its address space as a tree, and displays a selected node's
attributes and references. From the tree you can read and write node values,
subscribe to data changes and watch them update live, and call server methods.
It is the desktop counterpart to the [OPC UA command-line
tools](opcua-cli-tools.md), useful when browsing a large address space by hand
is easier than scripting it.

## Why it is on SnapshOT

A large OPC UA server can have thousands of nodes, and a tree you can click
through is often the fastest way to find the one a capture referenced and see
what it holds. The GUI makes that exploration quick and makes a live subscription
easy to watch. It ships on amd64 only: it is built on PyQt5, which publishes
x86-64 Linux wheels but no aarch64 wheels, and the vendor layer installs wheels
only (see the [vendor layer](../../platform/vendor-layer.md) and
[architectures](../../platform/architectures.md) pages). On arm64, use the
[command-line tools](opcua-cli-tools.md) or [asyncua](asyncua.md) instead.

## On the wire

!!! danger "Writes: it can change what a server exposes"

    Browsing and reading send OPC UA requests; writing a node value or calling
    a method from the tree changes what the server presents and a controller
    may act on.

    - **Never write a node or call a method without the engineer responsible
      present and agreeing to the exact node, method and value.** A value typed
      into a tree is as real as one written from a script.
    - Expand one branch at a time on a large server rather than the whole tree;
      a full expansion is many browse requests.
    - A live subscription keeps a session open until you disconnect; note how
      long you watched.
    - OPC UA work is announced to the site's monitoring: the server, and the
      monitoring, cannot tell your session from an adversary's.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), connect to an
OPC UA server seen on the wire, browse to the node a capture referenced and, with
the engineer present, read it to confirm what it holds. The attributes pane shows
the node's data type, access level and timestamps, which help judge whether a
value a capture showed being written is one the server should accept. Reads only
at this point.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), read node values and
attributes back and compare them with the engineer's known-good list before the
system returns to service. A short subscription on the nodes that matter shows
whether anything still changes them when no operator is acting. For a long list
of nodes, a script with [asyncua](asyncua.md) is easier to repeat.

### Recovery

During [recovery](../../lifecycle/phases/recovery.md), read the key nodes again
to confirm they hold the expected values before the process owner returns the
system to normal operation. Screenshot the attributes of each node you checked,
with the clock visible, so the report shows what the server exposed when it went
back into service.

## MITRE ATT&CK for ICS mapping

The OPC UA Client *resembles* Collection and Impair Process Control. Reading node
values looks like Monitor Process State (T0801), and browsing the tree to find
them like Point & Tag Identification (T0861). Writing a node value looks like
Modify Parameter (T0836). Its traffic is the same as an adversary using any OPC
UA client, so the work is announced to the site's monitoring.

## Quick start

```sh
# What the menu launcher runs (amd64 only)
/opt/snapshot/opcua-client/bin/opcua-client
# Before connecting, list the server's endpoints and security policies
/opt/snapshot/ics-python/bin/uadiscover -u opc.tcp://192.0.2.50:4840
# The same browse without the GUI, on either architecture: Objects, one level
/opt/snapshot/ics-python/bin/uals -u opc.tcp://192.0.2.50:4840 -n i=85 -d 1 -l
```

In the window, enter the server address (for example
`opc.tcp://192.0.2.50:4840`) and connect, then expand the address space tree,
select a node to see its attributes, and use the right-click menu to subscribe
or, with the engineer present, to write a value. `192.0.2.50` is a documentation
address on the OPC UA default port 4840.

## Output and evidence

The GUI does not keep a transcript, so record findings by hand and capture the
session on the wire:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/pcap" "$CASE/notes/screens"
# Capture the OPC UA traffic while you work in the client; Ctrl+C to stop
PCAP="$CASE/pcap/eth1-$(date -u +%Y%m%dT%H%M%SZ).pcapng"
tshark -n -i eth1 -f 'tcp port 4840' -w "$PCAP"
sha256sum "$PCAP" >> "$CASE/SHA256SUMS"
```

Keep the node ids, values and UTC times you read in the running log
(`notes/log.txt`). A [Flameshot](../reporting/flameshot.md) screenshot of a
node's attributes, saved in `notes/screens/`, is good evidence of what the
server exposed at that time.

## Related tools

- [OPC UA command-line tools](opcua-cli-tools.md): the same reads and writes in
  the terminal, on both architectures.
- [asyncua](asyncua.md): the OPC UA library for scripted checks.
- [tshark](../traffic/tshark.md): capture and decode the OPC UA session.

## Upstream documentation

- [opcua-client-gui on GitHub](https://github.com/FreeOpcUa/opcua-client-gui):
  the client and its features.
- [OPC Foundation, OPC UA](https://opcfoundation.org/about/opc-technologies/opc-ua/):
  the specification.
