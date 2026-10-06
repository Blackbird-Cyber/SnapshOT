---
title: avahi-browse (mDNS)
summary: Browse mDNS/DNS-SD services on the network
folder: recon
launchers: [snapshot-avahi-browse.desktop]
ships_as: apt
package: avahi-utils
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  identification: Enumerate the mDNS/DNS-SD services advertised on a segment, where a resident avahi daemon is acceptable, with approval.
  lessons-learned: Record the advertised services found, as part of describing what was on the network.
csf: [identify, detect]
attack_ics: [discovery]
attack_role: resembles
attack_techniques: [T0846, T0846.003]
protocols: [mdns]
upstream: https://avahi.org/
---

<!-- snapshot:facts -->

## What it is

avahi-browse lists the services that hosts advertise on the local network with
mDNS and DNS-SD (the protocol behind "Bonjour"): printers, web interfaces, file
shares, SSH and the many device types that announce themselves on UDP 5353. It
does not query the network itself; it asks the local **avahi-daemon**, which does
the multicast querying and caching, and prints what the daemon has learned. With
`--resolve` it also prints each service's host, port and TXT records.

## Why it is on SnapshOT

Building automation controllers, IP cameras, printers and IoT gear on a mixed OT
network often advertise themselves over mDNS, and avahi-browse is the quickest way
to list what is announcing itself. It names services and the hosts behind them,
and the resolved TXT records often carry a model or firmware string, which is a
useful supplement to ARP and port discovery on a segment that carries mDNS. A
device that advertises a web or remote-access service nobody expected is also a
finding in itself. On SnapshOT it is the active route; the same advertisements
can usually be read passively from a capture, which is why the daemon it needs
stays masked until someone decides otherwise.

## On the wire

!!! warning "Active: it relies on the avahi daemon sending mDNS queries"

    avahi-browse shows nothing on its own: the **avahi-daemon** it talks to is
    what sends the multicast queries and, by default, advertises the laptop's own
    presence on UDP 5353.

    - **On SnapshOT the avahi daemon is masked by default**, both its service
      and its socket (part of the quiet-on-the-wire
      [network defaults](../../platform/network-defaults.md)), so avahi-browse
      reports "Failed to create client object: Daemon not running" and the menu
      launcher, which runs `avahi-browse --help`, only prints usage. As shipped,
      the tool sends and shows nothing.
    - To actually browse you must unmask and start the daemon (the service
      requires its socket, so unmask both), which makes the laptop query and,
      unless configured otherwise, announce its own name and addresses on the
      segment. That breaks the quiet-on-the-wire posture, so do it only with
      approval, tell the site's monitoring, and mask both units again when
      finished (the commands are in the quick start).
    - **Prefer a passive alternative.** To see the mDNS already on a segment
      without transmitting, capture it with [tshark](../traffic/tshark.md):
      `tshark -n -i eth1 -f 'udp port 5353'`. For a single active query without a
      resident daemon, nmap's `dns-service-discovery` and
      `broadcast-dns-service-discovery` scripts send their DNS-SD queries and
      stop.
    - Stop and re-mask the daemon if a device on the segment reacts badly or the
      operators report anything unusual.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), where a
resident avahi daemon is acceptable and approved, avahi-browse enumerates the
services advertised on the segment and the hosts behind them. On SnapshOT the
passive route is the default: capture mDNS on UDP 5353 with tshark and read the
advertisements from the file, so the laptop stays silent.

### Lessons Learned

Record the advertised services found, by either route, as part of describing what
was on the network and which devices announced themselves. Devices that
advertise their names and services to anyone listening on a control segment are
worth a recommendation of their own, since a control zone rarely needs mDNS.
Cite the capture or the saved `-p` output so the list can be checked against the
evidence.

## MITRE ATT&CK for ICS mapping

avahi-browse, through a running avahi daemon, *resembles* the Discovery tactic:
multicast DNS-SD queries on UDP 5353 that ask every host on the segment what it
offers are what Remote System Discovery (T0846) and Remote System Discovery:
Multicast Discovery (T0846.003) look like. Because the daemon also announces the
laptop, bringing it up is noisy; announce it to the site's monitoring so the
queries are not mistaken for an intruder's, and so unannounced DNS-SD browsing
seen later in a capture still stands out. The passive capture route sends
nothing and resembles nothing. Either way, the list of advertised services
records what any host on the segment could learn about the devices there.

## Quick start

```sh
# What the menu launcher runs (prints the usage summary)
avahi-browse --help
# PASSIVE and preferred: watch mDNS on the wire without a daemon
tshark -n -i eth1 -f 'udp port 5353'
# Active, only with approval: unmask the daemon and its socket, then start it
sudo systemctl unmask avahi-daemon.service avahi-daemon.socket
sudo systemctl start avahi-daemon.service
# Browse all advertised service types, resolve them, then stop
avahi-browse -a -r -t
# Parse-friendly output without the service-type database lookup
avahi-browse -a -r -t -p -k
# When done, stop and mask both units so the laptop is quiet again
sudo systemctl stop avahi-daemon.service avahi-daemon.socket
sudo systemctl mask avahi-daemon.service avahi-daemon.socket
```

Replace `eth1` with the capture interface. `-a` browses all service types, `-r`
resolves them, `-t` terminates once the list looks complete. The
[mDNS primer](../protocol-primers/mdns.md) explains what the records mean.

## Output and evidence

When you take the passive route, the capture is the evidence. Capture into the
case folder (a capture filter, because tshark does not accept a display filter
while saving a live capture), stop with Ctrl+C, then hash:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/pcap"
tshark -n -i eth1 -f 'udp port 5353' -w "$CASE/pcap/eth1-mdns-$(date -u +%Y%m%dT%H%M%SZ).pcapng"
sha256sum "$CASE"/pcap/eth1-mdns-*.pcapng >> "$CASE/SHA256SUMS"
```

When an approved active browse ran, record its parse-friendly output (`-p`, one
semicolon-separated line per service) with the UTC time:

```sh
mkdir -p "$CASE/recon"
{ date -u; echo '$ avahi-browse -a -r -t -p -k'; avahi-browse -a -r -t -p -k; } \
    2>&1 | tee -a "$CASE/recon/mdns-services.txt"
sha256sum "$CASE/recon/mdns-services.txt" >> "$CASE/SHA256SUMS"
```

## Related tools

- [tshark](../traffic/tshark.md): the passive way to see mDNS on a segment, with
  no daemon and no traffic of your own.
- [nmap](nmap.md): `dns-service-discovery` sends a single DNS-SD query without a
  resident daemon, for an approved active check.
- [netdiscover](netdiscover.md): layer-2 discovery of the same hosts, passively.

## Upstream documentation

- [Avahi](https://avahi.org/): the mDNS/DNS-SD stack and its tools.
- `man avahi-browse`: the options on the image.
