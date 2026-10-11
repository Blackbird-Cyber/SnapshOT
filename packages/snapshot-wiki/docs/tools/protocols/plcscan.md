---
title: plcscan
summary: Scan for PLCs (S7comm/Modbus)
folder: protocols
launchers: [snapshot-plcscan.desktop]
ships_as: vendor
package: plcscan
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  preparation: Record which hosts answer S7comm and Modbus on an agreed segment, as a baseline, inside the window.
  identification: Confirm a device seen in passive capture is a PLC and read its identity, one host at a time, with approval.
  containment: Verify from both sides of a boundary that an isolated segment no longer answers S7comm or Modbus.
csf: [identify, detect, respond]
attack_ics: [discovery]
attack_role: resembles
attack_techniques: [T0846, T0846.001, T0888]
protocols: [modbus, s7comm]
upstream: https://github.com/eloraux/plcscan
---

<!-- snapshot:facts -->

## What it is

plcscan is a small scanner that identifies PLCs by speaking two industrial
protocols to them. On TCP 102 it tries a few ISO-TSAP pairs until a Siemens CPU
accepts the connection, then reads its module, hardware and firmware
identification, name and serial number from the CPU's system status lists over
S7comm. On TCP 502 it sends Modbus Read Device Identification (function 43/14)
to a few unit ids and prints the vendor, product and revision each one returns.
For each host it prints whether it answered as an S7 or a Modbus device and the
identity fields it got back. SnapshOT carries a Python 3 port (the eloraux
fork) of PLCScan, which Dmitry Efanov wrote at Positive Research.

## Why it is on SnapshOT

Between a passive capture that shows a host talking and a full protocol read,
plcscan answers the middle question: is this a PLC, and which kind? It asks in
the device's own protocol rather than guessing from an open port, so the answer
includes the vendor and model. On an OT engagement it is used sparingly, like
[nmap](../recon/nmap.md): a few known hosts, with approval, to confirm what the
wire already suggested.

## On the wire

!!! warning "Active: it sends S7comm and Modbus requests"

    plcscan connects and sends real protocol requests to every target, which a
    fragile controller must answer.

    - Scan only with written approval, inside the agreed window, and tell the
      site's monitoring first: this traffic looks exactly like an adversary
      enumerating controllers.
    - Name the hosts and ports, one device at a time. A range on the command
      line (`192.0.2.0/24`) expands to every address in it and connects to each,
      which is a sweep, not a check.
    - Avoid `--brute-uid` on a live Modbus gateway: it walks all 256 unit ids,
      which some gateways handle badly. Name the unit ids with `--modbus-uid`.
    - A connection and an identity request are light, but an S7 or Modbus stack
      that is already stressed can still fault. Stop if the device or the
      operators report anything unusual.
    - Neither protocol authenticates the caller, so the device and the site's
      monitoring cannot tell your scan from an intruder's. Announce it.

## PICERL mapping

### Preparation

In [preparation](../../lifecycle/phases/preparation.md), plcscan records which
hosts on an agreed segment answer as S7 or Modbus devices, and their identities,
as a baseline to compare later scans against. Run it from an agreed position
with the asset owner's list in hand (`--hosts-list` reads that list from a
file), and keep the output with the case.

### Identification

During [identification](../../lifecycle/phases/identification.md), plcscan
confirms that a host seen talking in a capture is a PLC and reads its identity,
one host at a time, with approval, instead of guessing from a port number. Stop
if the host's behavior changes.

### Containment

After a conduit is isolated during
[containment](../../lifecycle/phases/containment.md), plcscan from each side of
the boundary shows whether the isolation holds: the controllers that should be
unreachable must not answer S7comm or Modbus. Record the command and the result
as evidence.

## MITRE ATT&CK for ICS mapping

plcscan *resembles* the Discovery tactic. Connecting to controller ports across a
range looks like Remote System Discovery (T0846), in the form of Remote System
Discovery: Port Scan (T0846.001), and asking each device for its module,
firmware or unit identity looks like Remote System Information Discovery
(T0888). That is why the site's monitoring must be
told before you run it, and why such traffic found in a capture, unannounced, is
a strong sign of an intruder enumerating the control network.

## Quick start

```sh
# What the menu launcher runs
/opt/snapshot/plcscan/bin/plcscan -h
# Identify one known host on the default ports 102 and 502
/opt/snapshot/plcscan/bin/plcscan --timeout 2 192.0.2.20
# Modbus only, a single unit id, a 3-second Modbus reply timeout
/opt/snapshot/plcscan/bin/plcscan --ports 502 --modbus-uid 1 --modbus-timeout 3 192.0.2.10
# S7comm only
/opt/snapshot/plcscan/bin/plcscan --ports 102 --timeout 2 192.0.2.20
# The approved hosts from a file, one host or host:port per line
/opt/snapshot/plcscan/bin/plcscan --hosts-list ~/cases/site-a/recon/plc-targets.txt
```

`192.0.2.10` and `192.0.2.20` are documentation addresses. The default ports are
102 (S7comm) and 502 (Modbus); a port given as `host:port` overrides `--ports`,
and plcscan tries Modbus, then S7comm, on any port other than 102 and 502. The
default Modbus unit ids queried are 0 and 255. `--timeout` is the TCP connect
timeout (1 second by default) and `--modbus-timeout` the wait for each Modbus
reply (8 seconds by default).

## Output and evidence

plcscan prints to the terminal. Save the output with the command line and the
UTC time:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/recon"
{ date -u; echo '$ plcscan --timeout 2 192.0.2.20';
  /opt/snapshot/plcscan/bin/plcscan --timeout 2 192.0.2.20; } \
  2>&1 | tee -a "$CASE/recon/plcscan.txt"
sha256sum "$CASE/recon/plcscan.txt" >> "$CASE/SHA256SUMS"
```

Run a [tshark](../traffic/tshark.md) capture at the same time so the evidence
shows exactly what was sent and how each device answered.

## Related tools

- [nmap](../recon/nmap.md): `modbus-discover`, `s7-info` and `enip-info` do the
  same identity reads with more protocols and finer control.
- [mbpoll](mbpoll.md) and [python-snap7](python-snap7.md): read a device in
  depth once plcscan has identified it.
- [tshark](../traffic/tshark.md): capture while plcscan runs.

## Upstream documentation

- [plcscan on GitHub](https://github.com/eloraux/plcscan): the Python 3 port
  SnapshOT ships, its options and output.
