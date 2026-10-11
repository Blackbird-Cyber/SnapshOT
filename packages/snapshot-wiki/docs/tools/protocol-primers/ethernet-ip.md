---
title: EtherNet/IP and CIP
summary: Rockwell's industrial Ethernet; CIP objects and named tags read, written and discovered over TCP and UDP 44818.
---

## What it is and where it sits

EtherNet/IP carries the Common Industrial Protocol (CIP) over Ethernet. CIP is an
object model: a device is a set of objects (identity, assembly, connection
manager and vendor-specific ones), each with attributes and services. Explicit
messaging reads and writes those attributes and, on Logix controllers, named
tags; implicit (I/O) messaging streams cyclic process data over UDP. EtherNet/IP
is the common language of Rockwell Allen-Bradley plants and many third-party
devices, sitting between controllers at levels 1 and 2 and supervisory systems
at levels 2 and 3 on the Purdue model.

## Ports

TCP 44818 and UDP 44818 (explicit messaging and List Identity), UDP 2222
(implicit I/O). List Identity can be sent as a UDP broadcast to enumerate a
subnet.

## What it can do, and what that means

- **Discovery** (List Identity, List Services) returns a device's vendor,
  product, revision, serial and state, and can be broadcast to a whole subnet.
- **Reads** fetch object attributes and, on Logix controllers, named tag values
  and the tag list.
- **Writes** change tag values and object attributes a controller acts on.
- **Program and configuration changes** are carried as vendor-specific CIP
  services; a connection to the right object can alter controller behavior.

A write or configuration change is the [writes](../../lifecycle/wire-classes.md)
class: the engineer present, the exact tag or attribute and value agreed,
announced to the site. Most EtherNet/IP devices in service do not authenticate
the caller; CIP Security, which adds TLS and authentication, is still rare on
the plant floor.

## What to watch for in a capture

- Write Tag services (CIP service 0x4d) from a host that should only read.
- List Identity broadcasts sweeping the subnet, which look like enumeration.
- Forward Open connections to a controller from an unexpected host.
- A burst that reads the whole tag list, which an adversary does to learn the
  controller.

## Wireshark display filters

```text
# All EtherNet/IP and all CIP
enip || cip
# List Identity (ENIP command 0x63)
enip.command == 0x63
# CIP Read Tag (0x4c) and Write Tag (0x4d) services
cip.sc == 0x4c || cip.sc == 0x4d
# A specific tag by symbolic name
cip.symbol == "Speed"
# Forward Open (0x54) and Large Forward Open (0x5b): new CIP connections
cip.sc == 0x54 || cip.sc == 0x5b
# The List Identity response fields (vendor, serial, revision, product name)
enip.lir.vendor || enip.lir.serial
```

## SnapshOT tools that speak or decode it

- [pycomm3](../protocols/pycomm3.md): discover devices, read identity, read and
  write tags, list the tag database.
- [nmap](../recon/nmap.md) (`enip-info`, and [Redpoint
  NSE](../recon/redpoint-nse.md) `enip-enumerate` when the vendor layer is
  present): identify EtherNet/IP devices.
- [tshark](../traffic/tshark.md) and [Wireshark](../traffic/wireshark.md):
  capture and decode EtherNet/IP and CIP.

## ATT&CK for ICS techniques that ride on it

- [Discovery](../../lifecycle/attack-ics/discovery.md): Remote System
  Information Discovery (T0888), Remote System Discovery: Broadcast Discovery
  (T0846.002).
- [Collection](../../lifecycle/attack-ics/collection.md): Monitor Process State
  (T0801), Point & Tag Identification (T0861).
- [Impair Process Control](../../lifecycle/attack-ics/impair-process-control.md):
  Modify Parameter (T0836).
- [Lateral Movement](../../lifecycle/attack-ics/lateral-movement.md): Program
  Download (T0843) through vendor CIP services.

## Upstream specification

- [ODVA, EtherNet/IP](https://www.odva.org/technology-standards/key-technologies/ethernet-ip/):
  the EtherNet/IP adaptation of CIP and the CIP object model.
