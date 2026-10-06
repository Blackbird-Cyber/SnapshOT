---
title: nmap
summary: Network and port scanner
folder: recon
launchers: [snapshot-nmap.desktop, snapshot-nmap-ics.desktop]
ships_as: apt
package: nmap
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  preparation: Baseline the hosts and open ports of a segment from a known-good position, inside an agreed window.
  identification: Confirm hosts and services seen in passive capture, one host at a time; ICS scripts only with explicit approval.
  containment: Verify from both sides of a boundary that an isolated segment no longer answers.
  recovery: Check that restored hosts expose only the services recorded in the baseline.
csf: [identify, detect, respond, recover]
attack_ics: [discovery]
attack_role: resembles
attack_techniques: [T0846, T0846.001, T0888]
protocols: [modbus, s7comm, ethernet-ip, bacnet, omron-fins, niagara-fox, pcworx, iec-104, iec-61850, profinet, hart-ip]
upstream: https://nmap.org/book/
---

<!-- snapshot:facts -->

## What it is

Nmap is the standard network mapper. It finds which hosts on a network answer,
which TCP and UDP ports they have open, what service and version listen on each
port and, with root, what operating system the host runs. Its scripting engine
(NSE) runs Lua scripts against the hosts it finds, and Debian's package includes
scripts that speak industrial protocols, such as `modbus-discover`, `s7-info`,
`enip-info` and `bacnet-info`. Results can be written in normal, XML and
grepable formats at the same time.

## Why it is on SnapshOT

Passive capture tells you which devices talk; nmap confirms what they are. On
an OT engagement it is used sparingly: to check a handful of ports on a host
already seen on the wire, to ask a PLC for its identity in its own protocol, and
to prove after containment that a segment no longer answers. The **nmap ICS
scripts** launcher lists the industrial scripts available on this image, and
when the vendor layer is present the Redpoint NSE scripts are added to the same
script directory (see [Redpoint NSE](redpoint-nse.md)).

## On the wire

!!! warning "Active: it sends packets to every target"

    Everything nmap does except listing targets (`-sL`) transmits. Some PLCs,
    RTUs and protection relays have small network stacks that can stop
    responding, or fault, under a fast scan or unusual probes.

    - Scan only with written approval, inside the agreed window, and tell the
      site's monitoring team first: your scan is indistinguishable from an
      adversary's discovery.
    - One host at a time, only the ports you need, slowly: name the ports with
      `-p`, cap the rate with `--max-rate`, and skip ping sweeps with `-Pn` when
      the host is already known.
    - Prefer a TCP connect scan (`-sT`) of a few ports on controllers. Leave
      version detection (`-sV`), OS detection (`-O`) and `-A` for IT hosts unless
      the asset owner agrees: they send many probes a controller never expects.
    - `modbus-discover` is in NSE's *intrusive* category: it queries Modbus unit
      ids. Run it, and any ICS script, with the engineer for that device present.

## PICERL mapping

### Preparation

Before the engagement window, nmap records what a segment looks like when it is
known to be healthy: which hosts answer and which ports they expose. Run it from
an agreed position, with the asset owner's list in hand, and keep the XML output
with the case. This baseline is what later scans are compared against.

### Identification

During [identification](../../lifecycle/phases/identification.md), nmap
confirms what passive capture suggested. Pick one host seen on the wire, check
only the ports its traffic implies, and use an ICS script to read its identity
(vendor, model, firmware) instead of guessing from banners. Stop if the host's
behaviour changes or the operators report anything unusual.

### Containment

After a conduit is isolated, a connect scan from each side of the boundary shows
whether the isolation holds: the ports that should be unreachable must not
answer. Record the command and the result as evidence of the containment action.

### Recovery

When hosts are restored, a scan of their expected ports confirms they expose the
same services as in the baseline and nothing new, before the process owner
returns them to normal operation.

## MITRE ATT&CK for ICS mapping

nmap *resembles* the Discovery tactic: its traffic is what Remote System
Discovery (T0846), Remote System Discovery: Port Scan (T0846.001) and Remote
System Information Discovery (T0888) look like. That is why the site's monitoring must be told
before you run it, and why a scan you did not announce, seen in a capture, is a
strong sign of an intruder. As evidence, nmap's output documents which services
an adversary could have found on a host at that point in time.

## Quick start

```sh
# What the nmap launcher runs
nmap -h
# What the ICS scripts launcher shows, narrowed to four protocols (patterns are
# case-sensitive: bacnet* is nmap's bacnet-info, BACnet* the Redpoint script)
nmap --script-help 'modbus*,s7*,enip*,bacnet*,BACnet*'
# Three ICS ports on one known host, at most 10 packets a second
nmap -sT -n -Pn -p 102,502,44818 --max-rate 10 192.0.2.10
# Modbus unit id and device identification
nmap -sT -n -Pn -p 502 --script modbus-discover 192.0.2.10
# Siemens S7 module, serial number and firmware
nmap -sT -n -Pn -p 102 --script s7-info 192.0.2.20
# EtherNet/IP identity object
nmap -sT -n -Pn -p 44818 --script enip-info 192.0.2.30
# BACnet device properties (a UDP scan needs root)
sudo nmap -sU -n -Pn -p 47808 --script bacnet-info 192.0.2.40
# Host discovery only, no port scan (ARP on the local segment); approved sweeps only
sudo nmap -sn -n 192.0.2.0/24
```

`192.0.2.0/24` is a documentation range: replace it with the approved targets.
Without `sudo`, nmap falls back to connect scans and cannot run UDP or OS
detection.

## Output and evidence

Write every scan to the case folder in all three formats with `-oA`, then hash
the files:

```sh
# One folder per engagement
CASE=~/cases/site-a
mkdir -p "$CASE/nmap"
nmap -sT -n -Pn -p 502 --script modbus-discover -oA "$CASE/nmap/plc01-modbus" 192.0.2.10
sha256sum "$CASE"/nmap/plc01-modbus.* >> "$CASE/SHA256SUMS"
```

The `.xml` file is the one to keep for comparisons and reports; `.nmap` is the
human-readable copy and `.gnmap` suits `grep`.

## Related tools

- [tshark](../traffic/tshark.md): capture while you scan, so the evidence shows
  exactly what was sent and how the device answered.
- [mbpoll](../protocols/mbpoll.md): read Modbus registers once nmap has found a
  Modbus device and its unit id.
- [arp-scan](arp-scan.md) and [netdiscover](netdiscover.md): ARP-only
  discovery on the local segment.
- [Redpoint NSE](redpoint-nse.md): Digital Bond's ICS identification scripts,
  run with nmap's `--script`.
- [plcscan](../protocols/plcscan.md): S7comm and Modbus identification without
  the rest of nmap.

## Upstream documentation

- [Nmap Reference Guide](https://nmap.org/book/man.html): every option.
- [NSE documentation](https://nmap.org/nsedoc/): every script and its arguments.
