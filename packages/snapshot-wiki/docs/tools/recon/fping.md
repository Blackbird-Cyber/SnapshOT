---
title: fping
summary: Fast multi-host ping sweep
folder: recon
launchers: [snapshot-fping.desktop]
ships_as: apt
package: fping
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  preparation: Record which addresses in a segment answer ICMP from a known-good position, as part of the baseline.
  identification: Find which hosts in a range are reachable, with approval and gentle timing.
  containment: Check from each side of an isolated boundary that the addresses that should be unreachable no longer answer.
  recovery: Confirm restored hosts answer again, and only the ones expected to.
csf: [identify, detect, respond, recover]
attack_ics: [discovery]
attack_role: resembles
attack_techniques: [T0846]
upstream: https://www.fping.org/
---

<!-- snapshot:facts -->

## What it is

fping sends ICMP echo requests to many hosts at once and reports which answer and
which do not. Unlike `ping`, it does not wait for one host before moving to the
next, so it sweeps a range quickly, and it can generate a target list from a CIDR
block or read one from a file. It reports simply whether each address is alive,
with optional round-trip and loss statistics.

## Why it is on SnapshOT

A ping sweep is the quickest way to learn which addresses in a range respond, and
fping does it in one pass. On an engagement it is used sparingly: to confirm the
reachable hosts in an approved range, and, after containment, to prove from both
sides of a boundary that the addresses that should be cut off no longer answer.
It needs no raw-socket setup from the operator because the package ships with the
`cap_net_raw` capability, so it runs without `sudo`.

## On the wire

!!! warning "Active: it sends ICMP echo requests"

    fping transmits to every target. It is light, but it is not silent, and some
    devices are counted as down simply because they do not answer ICMP.

    - Run it only with approval and keep the rate gentle: `-i` sets the interval
      between any two packets fping sends (10 ms by default, which is fast for
      a large range) and `-p` the interval between packets to the same target
      in count and loop modes. Raise `-i` on a fragile segment.
    - Each unanswered target is retried (`-r`, three retries by default), so a
      sweep of a mostly empty range sends more than one packet per address.
    - A host that does not answer is not proven absent: many controllers and
      firewalls drop ICMP. Confirm absence another way before relying on it.
    - ICMP from the laptop is easy for the site's monitoring to see; announce the
      sweep so it is not mistaken for an intruder's.
    - fping carries `cap_net_raw` on this image, so it needs no `sudo`.

## PICERL mapping

### Preparation

From an agreed position, record which addresses in a segment answer ICMP as part
of the baseline, noting that ICMP-silent hosts will not appear. Keep the list
with the case.

### Identification

During [identification](../../lifecycle/phases/identification.md), a gentle,
approved sweep shows which hosts in a range are reachable, a fast first cut
before any closer look. Treat a silent address as unknown, not absent.

### Containment

After a conduit is isolated, a sweep from each side of the boundary helps show
the isolation holds: the addresses that should now be unreachable must stop
answering, while the hosts that must keep talking still do. Record the command
and result as evidence of the containment action.

### Recovery

When hosts are restored, a sweep confirms the expected addresses answer again,
and that nothing unexpected has appeared, before the process owner returns the
segment to normal operation.

## MITRE ATT&CK for ICS mapping

fping *resembles* the Discovery tactic: one source sending ICMP echo requests to
every address in a range, in quick succession, is what Remote System Discovery
(T0846) looks like on the wire, and it is often the first step an intruder takes
after landing on a segment. Announce every sweep to the site's monitoring, with
the range and the window, so that it is not mistaken for that intruder and so
that an unannounced sweep in a capture still stands out as an early sign of one.
fping reads nothing from the hosts beyond whether they answer, so it stays in
Discovery and touches no other tactic. As evidence, the list of answering
addresses shows what an adversary on that segment could have reached at that
time, and, after containment, that the cut-off addresses no longer answer.

## Quick start

```sh
# What the menu launcher runs
fping -h
# Sweep a /24, show only the hosts that are alive
fping -a -g 192.0.2.0/24
# Gentle sweep: 50 ms between packets, one retry, show alive and unreachable
fping -a -u -i 50 -r 1 -g 192.0.2.0/24
# Sweep a list of addresses from a file
fping -a -f targets.txt
# One count-mode pass with per-host statistics
fping -c 1 -g 192.0.2.0/24
```

`192.0.2.0/24` is a documentation range: replace it with the approved targets.
`-a` lists the alive hosts, `-u` the unreachable, `-g` generates the list from a
range.

## Output and evidence

fping prints to the terminal. Save a sweep with its command line and the UTC
time:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/recon"
{ date -u; echo '$ fping -a -g 192.0.2.0/24'; fping -a -g 192.0.2.0/24; } \
    2>&1 | tee -a "$CASE/recon/ping-sweep.txt"
sha256sum "$CASE/recon/ping-sweep.txt" >> "$CASE/SHA256SUMS"
```

## Related tools

- [arp-scan](arp-scan.md) and [netdiscover](netdiscover.md): ARP discovery that
  finds hosts which ignore ICMP, on the local segment.
- [nmap](nmap.md): once a host answers, confirm its open ports and services,
  with approval and one host at a time.
- [tshark](../traffic/tshark.md): capture the sweep so the evidence shows exactly
  what was sent.

## Upstream documentation

- [fping homepage](https://www.fping.org/): usage, options and output formats.
- `man fping`: the full option list on the image.
