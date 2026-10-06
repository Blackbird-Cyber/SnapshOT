---
title: s7scan
summary: Enumerate Siemens S7 PLCs
folder: protocols
launchers: [snapshot-s7scan.desktop]
ships_as: vendor
package: s7scan
arch: [amd64, arm64]
status: not-shipped
wire: active
phases:
  identification: Would enumerate Siemens S7 PLCs over S7comm and ISO-TSAP to confirm devices seen in passive capture.
csf: [detect]
attack_ics: [discovery]
attack_role: resembles
upstream: https://github.com/desvert/s7scan
---

<!-- snapshot:facts -->

## What it is

s7scan is a scanner focused on Siemens S7 controllers. It enumerates S7 PLCs and
reads back their identity and module details over S7comm, both over TCP/IP
(ISO-TSAP on port 102) and directly over Ethernet with LLC, which can reach
devices a TCP scanner cannot; the raw Ethernet path is why it needs scapy. The
desvert fork ports the original Python 2 tool to Python 3. Over TCP it overlaps
with [plcscan](plcscan.md)'s S7 half.

## Why it is not shipped

The launcher is present but hidden, because the s7scan stanza in
`vendor/sources.lock` is `enabled: false`. The maintained Python 3 fork (desvert)
depends on scapy pinned in its own virtual environment, which has not yet been
vendored under the layer's wheels-only, hash-pinned contract. It is recorded as a
disabled placeholder so its shape is captured; see "Out of scope and why" in the
[vendor layer](../../platform/vendor-layer.md) platform page.

## What to use instead

- [plcscan](plcscan.md): identifies Siemens S7 PLCs over S7comm (and Modbus
  devices) and is shipped.
- [nmap](../recon/nmap.md): the `s7-info` NSE script reads an S7 CPU's module,
  serial and firmware, and the [Redpoint NSE](../recon/redpoint-nse.md)
  `s7-enumerate` script is added when the vendor layer is present.
- [python-snap7](python-snap7.md): reads an S7 CPU's identity, state and data
  blocks in depth once it is found.

## Upstream documentation

- [s7scan on GitHub](https://github.com/desvert/s7scan): the Python 3 fork and
  its options.
