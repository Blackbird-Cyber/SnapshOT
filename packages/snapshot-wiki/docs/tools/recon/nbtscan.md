---
title: nbtscan
summary: NetBIOS name scanner
folder: recon
launchers: [snapshot-nbtscan.desktop]
ships_as: apt
package: nbtscan
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  preparation: Record the NetBIOS names, workgroups and MAC addresses of Windows hosts on a segment, as part of the baseline.
  identification: Identify the Windows hosts in a range by name, workgroup and logged-on user, with approval.
  recovery: Confirm restored Windows hosts report the expected names before they return to service.
csf: [identify, detect, recover]
attack_ics: [discovery]
attack_role: resembles
attack_techniques: [T0846, T0888]
protocols: [netbios]
upstream: https://github.com/resurrecting-open-source-projects/nbtscan
---

<!-- snapshot:facts -->

## What it is

nbtscan queries the NetBIOS name service (UDP 137) across a range and reports
what each Windows host returns: its NetBIOS name, the workgroup or domain it
belongs to, the logged-on user where that is exposed, and the adapter's MAC
address. It is the network form of the old `nbtstat -A`, run across many hosts at
once. One query to each host produces a compact, script-friendly table.

## Why it is on SnapshOT

Engineering workstations, HMIs and historians on an OT network are usually
Windows, and NetBIOS name service answers tell a responder who they are, which
domain or workgroup they sit in, and sometimes who is logged on, without touching
the host itself. That maps the Windows side of a control network quickly and
gives names to the addresses seen in passive capture. nbtscan sends from an
unprivileged source port by default, so it needs no `sudo`.

## On the wire

!!! warning "Active: it sends NetBIOS name queries"

    nbtscan transmits a UDP 137 query to each target. It is a small amount of
    traffic, but it is traffic a quiet OT segment rarely carries.

    - Run it only with approval and tell the site's monitoring; a NetBIOS sweep
      is distinctive and will be seen.
    - Slow it with `-b` (bandwidth) on a sensitive link so the queries do not
      arrive in a burst.
    - NetBIOS name service is unauthenticated, so the replies cannot be trusted
      as proof of identity, only as a lead.
    - The default run needs no `sudo`; only `-r` (source port 137, which some old
      Windows hosts require) needs root.

## PICERL mapping

### Preparation

From an agreed position, record the NetBIOS names, workgroups and MAC addresses
of the Windows hosts on each segment as part of the baseline. Later sweeps are
compared against this list to spot a renamed or new host.

### Identification

During [identification](../../lifecycle/phases/identification.md), an approved
sweep puts names, workgroups and sometimes logged-on users to the Windows
addresses seen on the wire. A host whose name or domain does not match the asset
owner's records, or a logged-on user who should not be there, is a lead to
follow with host collection, not with another network probe.

### Recovery

When Windows hosts are restored, a sweep confirms they report the expected
NetBIOS names and domains before the process owner returns them to service.

## MITRE ATT&CK for ICS mapping

nbtscan *resembles* the Discovery tactic: its NetBIOS queries are what Remote
System Discovery (T0846) and Remote System Information Discovery (T0888) look
like, a host asking Windows machines who they are and who is logged on. Announce
a run to the site's monitoring; an unannounced NetBIOS sweep in a capture is a
sign of an intruder enumerating the Windows estate.

## Quick start

```sh
# What the menu launcher runs (prints the usage summary)
nbtscan
# Scan a /24 for NetBIOS names
nbtscan 192.0.2.0/24
# Verbose: list every name each host returns, with human-readable services
nbtscan -v -h 192.0.2.0/24
# Script-friendly output, colon-separated, throttled bandwidth
nbtscan -s : -b 32000 192.0.2.0/24
# Read the targets from a file
nbtscan -f targets.txt
```

`192.0.2.0/24` is a documentation range: replace it with the approved targets.
`-s <sep>` gives one parseable line per name; `-h` (with `-v`) prints
human-readable service names.

## Output and evidence

nbtscan prints to the terminal. Save a sweep with its command line and the UTC
time:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/recon"
{ date -u; echo '$ nbtscan -v 192.0.2.0/24'; nbtscan -v 192.0.2.0/24; } \
    2>&1 | tee -a "$CASE/recon/netbios.txt"
sha256sum "$CASE/recon/netbios.txt" >> "$CASE/SHA256SUMS"
```

## Related tools

- [nmap](nmap.md): the `nbstat` NSE script reads the same NetBIOS data as part of
  a wider, approved host check.
- [tshark](../traffic/tshark.md): capture NetBIOS name traffic passively, or
  record your own queries while an approved sweep runs.
- [netdiscover](netdiscover.md) and [arp-scan](arp-scan.md): find the hosts at
  layer 2 first, then name the Windows ones with nbtscan.

## Upstream documentation

- [nbtscan on GitHub](https://github.com/resurrecting-open-source-projects/nbtscan):
  options and output format.
- `man nbtscan`: the full option list on the image.
