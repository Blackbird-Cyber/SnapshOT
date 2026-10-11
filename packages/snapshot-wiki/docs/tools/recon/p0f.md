---
title: p0f
summary: Passive OS fingerprinting
folder: recon
launchers: [snapshot-p0f.desktop]
ships_as: apt
package: p0f
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Fingerprint the hosts on a segment while the process runs normally, so a later unexpected stack stands out.
  identification: Identify the operating systems and stacks of the hosts seen on the wire, without sending a packet.
  lessons-learned: Use the saved fingerprints to describe what was on the network and to flag any host that did not belong.
csf: [identify, detect]
attack_ics: []
attack_role: none
protocols: [tcp-ip]
upstream: https://lcamtuf.coredump.cx/p0f3/
---

<!-- snapshot:facts -->

## What it is

p0f identifies the operating system and some configuration of a host purely by
watching the structure of the TCP/IP packets it sends. It never probes: it reads
packets from a live interface or from a saved capture and matches the SYN, SYN+ACK
and other fields against its fingerprint database. From a passive observation it
reports a likely OS and version, whether the host is behind NAT or a firewall,
and uptime hints. Because it sends nothing, the host being fingerprinted cannot
tell it is being watched.

## Why it is on SnapshOT

Passive-first is the house doctrine, and p0f is passive identification in its
purest form: it characterizes hosts from traffic they already send, with no
packet of its own. On an OT segment that should contain only known controllers
and workstations, a stack fingerprint that does not fit, a general-purpose laptop
OS where every other host is an embedded device, is a lead worth following. p0f
reads the same captures as the rest of the kit, so it adds host identity to the
conversation and protocol views without adding any risk to the network.

## On the wire

!!! note "Passive: it never transmits"

    p0f only listens. It needs no IP address on the capture interface, only that
    the interface is up, and it works equally well on a saved pcap.

    - Prefer a hardware TAP or a SPAN (mirror) port configured by the site's
      network owner; p0f adds nothing to the link, but the laptop's own
      interface should still reach the segment only through a listen-only path.
    - Live capture needs raw-socket access, so running p0f on an interface uses
      `sudo`; reading a pcap file (`-r`) does not.
    - p0f does not put the interface in promiscuous mode unless asked. On a SPAN
      port or TAP the frames it must see are addressed to other hosts, so add
      `-p`; promiscuous mode changes only what the laptop accepts, not what it
      sends.
    - A fingerprint is a hint, not proof: NAT, proxies and unusual stacks can
      mislead it, and many embedded controllers are not in its database (it
      reports `???`). Treat it as a lead to confirm, not a conclusion.

## PICERL mapping

### Preparation

While the process runs normally, record the OS fingerprints of the hosts on each
segment as part of the baseline. A host whose stack later changes, or a new stack
that was not in the baseline, is then easy to spot.

### Identification

During [identification](../../lifecycle/phases/identification.md), p0f puts an OS
and stack to the addresses seen in passive capture, without sending anything. A
fingerprint that does not match what the asset owner says should be on the
segment, a desktop OS among embedded controllers, points to a host worth a closer
look.

### Lessons Learned

The saved fingerprints help describe, in the report, what was on the network and
when, and they document any host that did not belong. Run p0f on the case
captures (`-r`) so the analysis is reproducible from the evidence.

## MITRE ATT&CK for ICS mapping

p0f has no direct relationship to an ATT&CK for ICS tactic. It neither emits
traffic that could resemble a technique nor decodes the industrial commands an
adversary would send; it passively characterizes the hosts on the wire. Its value
is in asset and host identification that supports the other tools, not in
detecting a specific adversary tactic.

## Quick start

```sh
# What the menu launcher runs (p0f has no -h option; it prints the usage summary)
p0f -h
# List the interfaces p0f can listen on
p0f -L
# Fingerprint hosts live on a SPAN or TAP interface (listen only, promiscuous)
sudo p0f -i eth1 -p
# Read from a saved capture instead of the wire (no sudo needed)
p0f -r ~/cases/site-a/pcap/eth1.pcapng
# Only the traffic of one host, with a tcpdump-style filter
p0f -r ~/cases/site-a/pcap/eth1.pcapng 'host 192.0.2.10'
```

Replace `eth1` with the capture interface. The filter syntax is tcpdump's
(`man pcap-filter`). `-o` writes the results to a log file; `-d` (daemon mode)
needs `-o` or `-s`.

## Output and evidence

p0f prints each fingerprint as it sees it, and `-o` writes the same to a log
file. Run it over the case capture, as your user, so the log is reproducible
from the evidence:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/recon"
p0f -r "$CASE/pcap/eth1.pcapng" -o "$CASE/recon/p0f-eth1.log"
sha256sum "$CASE/recon/p0f-eth1.log" >> "$CASE/SHA256SUMS"
```

Live runs on the wire are for a quick look; the same capture read again gives
the same fingerprints for the report.

## Related tools

- [tshark](../traffic/tshark.md): the capture p0f reads; tshark decodes the
  protocols while p0f fingerprints the hosts.
- [netdiscover](netdiscover.md): passive ARP discovery that lists the same hosts
  at layer 2, also without transmitting.
- [nmap](nmap.md): active OS detection when a passive fingerprint is not enough
  and an approved probe is acceptable.

## Upstream documentation

- [p0f homepage](https://lcamtuf.coredump.cx/p0f3/): the method, the signature
  format and the fingerprint database.
- `man p0f`: the options on the image.
