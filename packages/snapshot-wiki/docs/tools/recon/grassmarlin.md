---
title: GRASSMARLIN
summary: Passive ICS/SCADA network mapper
folder: recon
launchers: [snapshot-grassmarlin.desktop]
ships_as: vendor
package: grassmarlin
arch: [amd64, arm64]
status: not-shipped
wire: passive
phases:
  identification: Would build a passive map of the control network and its conversations from a capture or a SPAN port.
csf: [identify, detect]
attack_ics: [discovery]
attack_role: detects
upstream: https://github.com/nsacyber/GRASSMARLIN
---

<!-- snapshot:facts -->

## What it is

GRASSMARLIN is a passive network mapper for ICS and SCADA environments. Given a
live SPAN port or a saved capture, it builds a visual map of the hosts, the
conversations between them and the industrial protocols they use, and groups them
into logical networks, without sending a single packet. It was written to give a
responder a picture of an unfamiliar control network from passive evidence alone.

## Why it is not shipped

GRASSMARLIN is disabled in `vendor/sources.lock` (`enabled: false`) and is not
installed on this image. It is archived upstream, and, as `docs/vendoring.md`
("Out of scope and why") records, it is a Java 8 and JavaFX application with an
x86-only JNetPcap native library, which is unsupported on this image's runtimes
and architectures. Its launcher ships but stays hidden because its `TryExec`
target is absent. See the [vendor layer](../../platform/vendor-layer.md) page for
how disabled tools are handled.

## What to use instead

- [tshark](../traffic/tshark.md): the protocol hierarchy (`-z io,phs`) and the
  conversation table (`-z conv,tcp`) give the same "who talks to whom, in which
  protocol" from a capture, on the command line.
- [Wireshark](../traffic/wireshark.md) and [termshark](../traffic/termshark.md):
  the same captures in a GUI and a terminal UI, with the conversation and
  endpoint statistics a click away.
- [Suricata](../traffic/suricata.md): run offline over the same capture, its
  `eve.json` flow records list every conversation as structured data.
- [netdiscover](netdiscover.md) in passive mode and [p0f](p0f.md): passive
  host and OS discovery to complement the conversation view.

## Upstream documentation

- [GRASSMARLIN on GitHub](https://github.com/nsacyber/GRASSMARLIN): the archived
  project, its documentation and its known limitations.
