---
title: arp-scan
summary: ARP host discovery on the local link
folder: recon
launchers: [snapshot-arp-scan.desktop]
ships_as: apt
package: arp-scan
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  preparation: Enumerate the hosts and MAC addresses on a segment from a known-good position, as part of the baseline.
  identification: Confirm which hosts are live on the local segment, with approval and controlled timing.
  recovery: Verify restored hosts answer on the segment with the MAC addresses recorded in the baseline.
csf: [identify, detect, recover]
attack_ics: [discovery]
attack_role: resembles
attack_techniques: [T0846, T0846.002]
protocols: [arp]
upstream: https://github.com/royhills/arp-scan
---

<!-- snapshot:facts -->

## What it is

arp-scan sends ARP requests to a set of addresses on the local link and reports
which ones answer, with their IP address, MAC address and the vendor the MAC
maps to from its built-in registry files. It works only on the local segment,
because ARP is not routed, and it gives fine control over timing, retries and the
contents of the ARP packet, including 802.1Q VLAN tagging. It can read targets
from the command line, a file, or the interface configuration (`--localnet`).

## Why it is on SnapshOT

ARP is the most reliable way to find hosts on a flat control segment: a device
answers an ARP request even when it ignores ping and runs no IP services. arp-scan
gives the responder precise control over how fast those requests go out, which
matters on a fragile network: `--interval` and `--bandwidth` cap the rate, and
`--retry` handles a lossy link. The MAC vendor lookup is a quick first hint at a
device's maker before any protocol-level query.

## On the wire

!!! warning "Active: it sends ARP requests"

    arp-scan always transmits: it has no passive mode. Every target gets at
    least one ARP request.

    - Run it only with approval, and keep the rate low. `--bandwidth` (bits per
      second) or `--interval` (time between packets) throttle the sweep; use
      one or the other, not both. The default of 256000 bits per second is
      already modest, but a quiet OT segment is not used to broadcast bursts.
    - Name the approved range. `--localnet` sweeps every address of the
      interface's own subnet, which on a flat control network is every device.
    - It is link-local: arp-scan reaches only the segment the interface is on,
      so the result is scoped to one broadcast domain.
    - For a continuous, zero-transmit view of the same hosts, listen to ARP with
      [netdiscover](netdiscover.md) in passive mode or
      [tshark](../traffic/tshark.md) instead.
    - arp-scan needs raw-socket access; on this image it runs under `sudo`.

## PICERL mapping

### Preparation

From an agreed position, enumerate the hosts and their MAC addresses on each
segment and keep the output as part of the baseline. Record the interface and
the time; later sweeps are compared against this list.

### Identification

During [identification](../../lifecycle/phases/identification.md), an approved,
rate-limited sweep confirms which hosts are live on the local segment and gives a
first vendor hint from each MAC. Use it to decide which hosts, already seen in
passive capture, deserve a protocol-level look; do not treat the sweep itself as
a licence to probe services.

### Recovery

When hosts are restored, a sweep confirms they answer on the segment with the
same MAC addresses as the baseline and that no unexpected host has appeared,
before the process owner returns the segment to normal operation.

## MITRE ATT&CK for ICS mapping

arp-scan *resembles* the Discovery tactic: one host sending ARP requests to
every address in a range is what Remote System Discovery (T0846) and Remote
System Discovery: Broadcast Discovery (T0846.002) look like on the segment.
Tell the site's monitoring before a run, so the sweep is not taken for an
intruder's and so an unannounced ARP sweep in a capture still stands out as a
sign of someone mapping the local network. The saved output records which hosts
answered on the segment at that time, which is also what an adversary there
could have learned.

## Quick start

```sh
# What the menu launcher runs
arp-scan --help
# Sweep the local segment from the interface's own address and netmask
sudo arp-scan --interface=eth1 --localnet
# Sweep one range at a capped rate, minimal output
sudo arp-scan --interface=eth1 --bandwidth=64000 --quiet 192.0.2.0/24
# Show round-trip time and ignore duplicate replies
sudo arp-scan --interface=eth1 --rtt --ignoredups 192.0.2.0/24
# Tag the requests with a VLAN id when the port is a trunk
sudo arp-scan --interface=eth1 --vlan=100 192.0.2.0/24
```

Replace `eth1` with the capture interface and `192.0.2.0/24` with the approved
range. `--localnet` takes its targets from the interface's own address and
netmask and cannot be combined with a target list or `--file`; prefer a named
range on a control segment.

## Output and evidence

arp-scan prints to the terminal, and `--plain` drops the header and footer for a
clean record. Save the run with its command and the UTC time:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/recon"
{ date -u; echo '$ sudo arp-scan --interface=eth1 --bandwidth=64000 --plain 192.0.2.0/24'; \
  sudo arp-scan --interface=eth1 --bandwidth=64000 --plain 192.0.2.0/24; } \
    2>&1 | tee -a "$CASE/recon/arp-scan.txt"
sha256sum "$CASE/recon/arp-scan.txt" >> "$CASE/SHA256SUMS"
```

`--pcapsavefile` also writes the replies arp-scan received to a pcap if you need
the packets as evidence; a [tshark](../traffic/tshark.md) capture running
alongside records the requests as well.

## Related tools

- [netdiscover](netdiscover.md): the same ARP discovery with a passive,
  listen-only mode for live segments.
- [fping](fping.md): an ICMP sweep, for ranges beyond the local segment.
- [tshark](../traffic/tshark.md): watch the ARP passively, or capture your own
  requests while an approved sweep runs.
- [nmap](nmap.md): confirm the services on a host arp-scan found, with approval.

## Upstream documentation

- [arp-scan on GitHub](https://github.com/royhills/arp-scan): options, output
  format and the MAC vendor files.
- `man arp-scan`: the full option list on the image.
