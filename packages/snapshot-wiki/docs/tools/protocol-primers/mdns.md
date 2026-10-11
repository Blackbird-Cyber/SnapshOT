---
title: mDNS and DNS-SD
summary: Zero-configuration service discovery; multicast DNS queries and service records on UDP 5353, loud on a quiet OT network.
---

## What it is and where it sits

Multicast DNS (mDNS) resolves names and, with DNS-based Service Discovery
(DNS-SD), advertises and finds services without a DNS server. Hosts send queries
to a multicast group and answer for their own names and services, so printers,
cameras, media devices and engineering laptops announce themselves automatically.
mDNS is not an industrial protocol, but it is common on the IT-leaning edges of
an OT network and on transient devices brought onto it. On a control network that
is supposed to be quiet, mDNS traffic is conspicuous: it marks hosts that
announce themselves, which is exactly what a field kit wants to notice. SnapshOT
itself keeps mDNS off so the laptop stays silent (see
[network defaults](../../platform/network-defaults.md)).

## Ports

UDP 5353, sent to the multicast groups 224.0.0.251 (IPv4) and ff02::fb (IPv6).
Service types are queried as names under `_services._dns-sd._udp.local`.

## What it can do, and what that means

- **Service discovery** enumerates the services a host offers (their types,
  ports and TXT metadata) and resolves `.local` names, all passively observable.
- mDNS has **no writes and no control**: it changes no device state. Its value to
  a responder is entirely in what hosts reveal about themselves, and its risk is
  that an adversary learns the same thing, and that a noisy host breaks the quiet
  a control network relies on.

Because mDNS is observe-only, the house doctrine applies plainly: listen to it in
a capture and do not add to it. A SnapshOT laptop that announced itself over
mDNS would itself be the anomaly.

## What to watch for in a capture

- Hosts advertising services (`_services._dns-sd._udp.local`,
  `_http._tcp.local`, `_workstation._tcp.local`) on a segment meant to be quiet.
- `.local` name lookups that reveal host and vendor names.
- A new transient device announcing itself, which can mark an unauthorized
  laptop on the control network.

## Wireshark display filters

```text
# All mDNS
mdns
# Service-discovery queries and the names asked for
mdns && dns.qry.name
# Responses only
mdns && dns.flags.response == 1
# Service (SRV) targets and pointer (PTR) names that enumerate services
dns.srv.target || dns.ptr.domain_name
```

## SnapshOT tools that speak or decode it

- [mDNS listen (passive)](../recon/mdns-listen.md): the 01 Recon & Discovery
  entry; a tshark capture of UDP 5353 that prints what hosts announce and sends
  nothing.
- [avahi-browse](../recon/avahi-browse.md): list the mDNS and DNS-SD services on
  a segment from the terminal. It sends queries, and only works once the
  avahi daemon, masked on SnapshOT, is started by hand.
- [nmap](../recon/nmap.md) (`dns-service-discovery`,
  `broadcast-dns-service-discovery`): query and enumerate DNS-SD services.
- [tshark](../traffic/tshark.md) and [Wireshark](../traffic/wireshark.md):
  capture and decode mDNS passively, the preferred way on a control network.

## ATT&CK for ICS techniques that ride on it

- [Discovery](../../lifecycle/attack-ics/discovery.md): Remote System Discovery:
  Multicast Discovery (T0846.003), and Network Sniffing (T0842), passively
  collecting the service and name records hosts announce.

## Upstream specification

- [RFC 6762, Multicast DNS](https://www.rfc-editor.org/rfc/rfc6762): the mDNS
  protocol.
- [RFC 6763, DNS-Based Service Discovery](https://www.rfc-editor.org/rfc/rfc6763):
  the service-discovery records.
