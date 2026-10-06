---
title: OPC UA
summary: The modern, structured supervisory protocol; a browsable address space read, written and subscribed over opc.tcp 4840.
---

## What it is and where it sits

OPC UA (Unified Architecture) is the modern successor to classic OPC: a
platform-independent protocol whose data is a browsable address space of nodes,
each with attributes, references and a type. Clients discover servers, open a
secured session, browse the tree, read and write node values, subscribe to data
changes and call methods. It carries security that most older OT protocols lack:
sessions can be signed and encrypted and users authenticated, though many
plant deployments still allow anonymous, unencrypted sessions. OPC UA sits mostly
at levels 2 and 3, between SCADA, historians, MES and the controllers or gateways
that expose process data.

## Ports

TCP 4840 for the native `opc.tcp` binary transport (the default). Some servers
also offer HTTPS transports on other ports; `opc.tcp` on 4840 is what a field kit
meets most often.

## What it can do, and what that means

- **Discovery** (FindServers, GetEndpoints) lists a server's endpoints and the
  security policies and modes it offers. The policies on offer are themselves a
  finding: an endpoint that allows None/None is unauthenticated.
- **Reads** and **subscriptions** fetch current node values and stream changes.
- **Writes** change a node value a controller or system acts on.
- **Method calls** invoke server-defined operations, which can have any effect
  the server allows.

A write or a method call is the [writes](../../lifecycle/wire-classes.md) class:
the engineer present, the exact node or method and value agreed, announced to
the site.

## What to watch for in a capture

- Write requests to nodes from a client that should only read or subscribe.
- Sessions that open with security mode None where the site expects
  SignAndEncrypt.
- FindServers or GetEndpoints from an unexpected host, which look like
  enumeration.
- Method calls that are not part of normal operation.

## Wireshark display filters

```text
# All OPC UA
opcua
# The Hello that opens a connection
opcua.transport.type == "HEL"
# Read (631) and Write (673) service requests
opcua.servicenodeid.numeric == 631 || opcua.servicenodeid.numeric == 673
# Browse (527) requests
opcua.servicenodeid.numeric == 527
# Discovery: FindServers (422) and GetEndpoints (428)
opcua.servicenodeid.numeric in {422,428}
# Method calls: Call (712)
opcua.servicenodeid.numeric == 712
```

## SnapshOT tools that speak or decode it

- [OPC UA command-line tools](../protocols/opcua-cli-tools.md): `uadiscover`,
  `uals`, `uaread`, `uawrite` and the rest.
- [asyncua](../protocols/asyncua.md): the OPC UA library for scripted checks.
- [opcua-client](../protocols/opcua-client.md): the graphical client (amd64
  only).
- [tshark](../traffic/tshark.md) and [Wireshark](../traffic/wireshark.md):
  capture and decode OPC UA. Service calls in a SignAndEncrypt session are
  encrypted and do not decode; sessions in None or Sign mode do.

## ATT&CK for ICS techniques that ride on it

- [Discovery](../../lifecycle/attack-ics/discovery.md): Remote System
  Information Discovery (T0888).
- [Collection](../../lifecycle/attack-ics/collection.md): Monitor Process State
  (T0801), Point & Tag Identification (T0861).
- [Impair Process Control](../../lifecycle/attack-ics/impair-process-control.md):
  Modify Parameter (T0836).

## Upstream specification

- [OPC Foundation, OPC UA](https://opcfoundation.org/about/opc-technologies/opc-ua/):
  the specification parts, the address space and the security model.
