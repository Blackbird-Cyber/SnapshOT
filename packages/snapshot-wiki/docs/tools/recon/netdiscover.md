---
title: netdiscover
summary: Active/passive ARP network discovery
folder: recon
launchers: [snapshot-netdiscover.desktop]
ships_as: apt
package: netdiscover
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  preparation: Record the hosts that answer on a segment, and their MAC addresses, as part of a known-good baseline.
  identification: Find the live hosts on a local segment, passively if the link must stay quiet, actively only with approval.
  recovery: Confirm that restored hosts appear on the segment with the same addresses as the baseline.
csf: [identify, detect, recover]
attack_ics: [discovery]
attack_role: resembles
attack_techniques: [T0846, T0846.002]
protocols: [arp]
upstream: https://github.com/netdiscover-scanner/netdiscover
---

<!-- snapshot:facts -->

## What it is

netdiscover is an ARP reconnaissance tool. In its active mode it sends ARP
requests across a range and lists the hosts that answer, with their IP address,
MAC address and the vendor the MAC maps to. In its passive mode (`-p`) it sends
nothing at all: it only listens to the ARP traffic already on the link and
builds the same list from what it hears. It works at layer 2, so it finds hosts
on the local segment whether or not they run IP services, and it does not depend
on DHCP.

## Why it is on SnapshOT

On a flat control-network segment, ARP is the quietest way to learn which hosts
are present. The passive mode fits the SnapshOT doctrine exactly: left on a SPAN
port or a quiet tap, it maps the segment from the ARP that devices send anyway,
with no packet of its own. The active mode is there for when a short, approved
sweep is acceptable and a faster answer is needed. The MAC vendor lookup is a
useful first hint at what a device is before any protocol query.

## On the wire

!!! warning "Active: it sends ARP requests (passive mode sends nothing)"

    In the default active mode netdiscover broadcasts ARP requests across the
    range. In passive mode (`-p`) it transmits nothing and only sniffs.

    - Prefer passive mode (`-p`) on a live control segment: it is
      indistinguishable from an ordinary listener and cannot upset a device.
    - Use active mode only with approval, and slow it down: `-s` sets a sleep in
      milliseconds between requests. A fast ARP sweep still adds broadcast
      traffic a quiet OT segment is not used to.
    - ARP is link-local: netdiscover sees only the segment the capture interface
      is on, so the result is scoped to one broadcast domain.
    - Without `-r`, `-l` or `-p`, netdiscover scans a list of common private
      ranges on its own. Always give the approved range, or `-p`.
    - Both modes open the interface at the packet level (raw sockets and pcap),
      so netdiscover runs under `sudo` on this image, passive mode included.
    - Stop if a device on the segment drops off or the operators report
      anything unusual during an active sweep.

## PICERL mapping

### Preparation

From an agreed position, record the hosts that answer on each segment and their
MAC addresses as part of the baseline. Passive mode gathers the same list over a
longer window without adding traffic. Keep the output with the case.

### Identification

During [identification](../../lifecycle/phases/identification.md), passive mode
is the first pass: it lists the live hosts on the segment from the ARP already
flowing. When an approved active sweep is acceptable, it fills in hosts that have
been quiet. Pair the MAC vendor hints with the passive capture to decide which
hosts deserve a closer, protocol-level look.

### Recovery

When hosts are restored, a short run confirms they are back on the segment with
the same IP and MAC addresses recorded in the baseline, and that nothing
unexpected has appeared, before the process owner returns the segment to normal.

## MITRE ATT&CK for ICS mapping

netdiscover's active mode *resembles* the Discovery tactic: a burst of ARP
requests from one host across a range is what Remote System Discovery (T0846)
and Remote System Discovery: Broadcast Discovery (T0846.002) look like on the
segment. Announce an active run to the site's monitoring, so that it is not
mistaken for an intruder and so that an unannounced ARP sweep, seen later in a
capture, still stands out as one. Passive mode produces no traffic of its own
and resembles nothing. As evidence, the host list records which devices an
adversary on that segment could have found at that time.

## Quick start

```sh
# What the menu launcher runs
netdiscover -h
# Passive: listen only, never transmit (preferred on a live segment)
sudo netdiscover -p -i eth1
# Active sweep of one /24, 100 ms between requests, parse-friendly then stop
sudo netdiscover -i eth1 -r 192.0.2.0/24 -s 100 -P
# Active sweep from a list of ranges in a file
sudo netdiscover -i eth1 -l ranges.txt -s 100
```

Replace `eth1` with the capture interface and `192.0.2.0/24` with the approved
range. `-P` prints a parse-friendly table and stops after the active scan; `-L`
is the same but keeps listening.

## Output and evidence

netdiscover prints to the terminal. With `-P`, an approved active sweep prints
a parse-friendly table and exits, so it can be recorded with its command line
and the UTC time:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/recon"
{ date -u; echo '$ sudo netdiscover -i eth1 -r 192.0.2.0/24 -s 100 -P'; \
  sudo netdiscover -i eth1 -r 192.0.2.0/24 -s 100 -P; } \
    2>&1 | tee -a "$CASE/recon/arp-hosts.txt"
sha256sum "$CASE/recon/arp-hosts.txt" >> "$CASE/SHA256SUMS"
```

Passive mode runs until you stop it, so for a passive record capture the ARP
itself with [tshark](../traffic/tshark.md) into `$CASE/pcap/` (capture filter
`arp`) and keep the pcap as the evidence; netdiscover's screen is the view.

## Related tools

- [arp-scan](arp-scan.md): a one-shot active ARP sweep with finer timing control
  and 802.1Q options.
- [tshark](../traffic/tshark.md): capture the ARP passively, or record your own
  requests while an approved active sweep runs.
- [nmap](nmap.md): confirm services on a host netdiscover found, one host at a
  time and with approval.

## Upstream documentation

- [netdiscover on GitHub](https://github.com/netdiscover-scanner/netdiscover):
  options and usage.
- `man netdiscover`: the full option list on the image.
