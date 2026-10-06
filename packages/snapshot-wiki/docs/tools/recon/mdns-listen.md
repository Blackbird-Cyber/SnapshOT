---
title: mDNS listen (passive)
summary: Capture the mDNS/DNS-SD announcements other hosts send (udp 5353) with tshark; avahi-daemon stays masked
folder: recon
launchers: [snapshot-mdns-listen.desktop]
ships_as: snapshot
package: snapshot-menu
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Record which hosts and services announce themselves over mDNS on a segment while the process runs normally.
  identification: List the hosts and services announcing themselves on a segment without sending a packet, and spot a new or unexpected one.
  lessons-learned: Name the devices that advertise themselves on control segments, from the saved capture, as a finding and a recommendation.
csf: [identify, detect]
attack_ics: [discovery]
attack_role: detects
attack_techniques: [T0846.003]
protocols: [mdns]
---

<!-- snapshot:facts -->

## What it is

mDNS listen is a small SnapshOT helper, `/usr/share/snapshot-menu/mdns-listen`
from the `snapshot-menu` package, behind the **mDNS listen (passive)** entry in
01 Recon & Discovery. It runs [tshark](../traffic/tshark.md) with the capture
filter `udp port 5353` on one network interface and prints, packet by packet,
the multicast DNS (mDNS) and DNS-SD traffic other hosts send to 224.0.0.251 and
ff02::fb: the names and services they announce, their answers and their
queries. With no argument it listens on the one interface that is up (loopback
aside), or lists the interfaces that are up and asks which to use;
`mdns-listen eth1` names one. Ctrl+C stops it.

## Why it is on SnapshOT

Building automation controllers, IP cameras, printers, engineering laptops and
IoT gear on a mixed OT network often announce themselves over mDNS, and the
records they send carry host names, service types, ports and TXT strings that
may name a model or firmware. That is a useful supplement to ARP and port
discovery, and a device advertising a web or remote-access service nobody
expected is a finding in itself. SnapshOT keeps avahi-daemon masked, so
[avahi-browse](avahi-browse.md) cannot work as shipped; the listener takes its
place in the menu and hears the same announcements without the laptop asking
or announcing anything. It hears only what hosts send on their own: their
announcements when they join the network or change, their answers to other
hosts' queries, and those queries. A device that only answers, on a segment
where nobody asks, stays silent, so leave the listener running for a while; if a
fuller list is needed, an approved active browse with avahi-browse or nmap's
DNS-SD scripts asks directly.

## On the wire

!!! note "Passive: it never transmits"

    The helper only captures: tshark sends nothing, and avahi-daemon stays
    masked, so the laptop neither queries nor announces itself. The site's
    monitoring sees nothing from it.

    - It needs an interface that is up, and the quiet
      [network defaults](../../platform/network-defaults.md) leave interfaces
      down until the operator brings one up. When none is up, the helper stops
      and suggests `nmcli device connect <iface>` or `sudo ip link set <iface> up`.
      For listening, prefer the second: it brings the link up without an
      address, whereas `nmcli device connect` activates a connection profile,
      which by default asks DHCP for an address and so transmits.
    - tshark opens the interface in promiscuous mode (its default), which is what
      lets it hear multicast for a group the laptop has not joined. The `any`
      pseudo-interface cannot go promiscuous, which is why the helper wants a
      real interface.
    - mDNS does not cross routers: the listener hears only the segment (or VLAN)
      it is attached to. Attach where the site agreed, a TAP, a SPAN port or an
      access port the network owner assigned, as for any capture.
    - Capture needs no `sudo`: the user is in group `wireshark`
      ([administration and capture](../../platform/admin-and-capture.md)).

## PICERL mapping

### Preparation

In [preparation](../../lifecycle/phases/preparation.md), listen on each segment
while the process runs normally and keep the capture. The hosts and services
that announce themselves when all is well are the baseline that a later listen
is compared against, and the list is a cross-check of the asset inventory.

### Identification

During [identification](../../lifecycle/phases/identification.md), and as part
of the [passive baseline](../../lifecycle/playbooks/passive-baseline.md), listen
on the affected segment and compare with the baseline: a new name, a new service
type (a web or remote-access service on a controller segment), or a host
announcing itself that the inventory does not list. A transient laptop that
announces itself is often the first sign of an unauthorised device on a control
network.

### Lessons Learned

In [lessons learned](../../lifecycle/phases/lessons-learned.md), name the devices
that advertise themselves on control segments, from the saved capture. They are
worth a recommendation of their own, since a control zone rarely needs mDNS and
everything they announce is readable by any host on the segment. Cite the
capture so the list can be checked against the evidence.

## MITRE ATT&CK for ICS mapping

mDNS listen *detects* part of the
[Discovery](../../lifecycle/attack-ics/discovery.md) tactic. A host that browses
DNS-SD sends multicast queries to 224.0.0.251 or ff02::fb, which every host on
the link receives, the listener included: that is what Remote System Discovery:
Multicast Discovery (T0846.003) looks like. A burst of
`_services._dns-sd._udp.local` queries from a host that does not normally
browse, or from an address nobody recognises, is worth following up. The
listener itself sends nothing and resembles nothing. What it records is also what
any host on the segment learns by listening (Network Sniffing, T0842), so the
list of announcing devices measures that exposure as well as describing the
segment.

## Quick start

```sh
# What the menu launcher runs: listen on the one interface that is up, or list
# the interfaces that are up and ask which; Ctrl+C stops it
/usr/share/snapshot-menu/mdns-listen
# If no interface is up: bring the capture interface up, with no address
sudo ip link set eth1 up
# Name the interface instead of being asked
/usr/share/snapshot-menu/mdns-listen eth1
# The same capture, written to the case folder instead of printed
tshark -n -i eth1 -f 'udp port 5353' -w ~/cases/site-a/pcap/eth1-mdns.pcapng
# From the saved file: who announced which service, its host, port and TXT
tshark -n -r ~/cases/site-a/pcap/eth1-mdns.pcapng \
    -Y 'mdns && dns.flags.response == 1' -T fields \
    -e ip.src -e dns.ptr.domain_name -e dns.srv.target -e dns.srv.port -e dns.txt
```

Replace `eth1` with the capture interface. The helper prints the tshark command
it runs, then one line per packet: the source address, the multicast group and
either a *Standard query* or a *Standard query response* with the record types
and names, such as `PTR printer-01._ipp._tcp.local`. The helper itself takes
only the interface name; to keep the capture, run tshark with `-w` as above (the
helper's own hint). Announcements from IPv6-only hosts carry `ipv6.src` instead
of `ip.src`. The [mDNS primer](../protocol-primers/mdns.md) explains the records
and gives display filters for Wireshark.

## Output and evidence

The helper only prints. For evidence, capture to the case folder with tshark,
stop with Ctrl+C, hash the file, and keep the services list drawn from it:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/pcap" "$CASE/recon"
PCAP="$CASE/pcap/eth1-mdns-$(date -u +%Y%m%dT%H%M%SZ).pcapng"
tshark -n -i eth1 -f 'udp port 5353' -w "$PCAP"
tshark -n -r "$PCAP" -Y 'mdns && dns.flags.response == 1' -T fields \
    -e ip.src -e dns.ptr.domain_name -e dns.srv.target -e dns.srv.port -e dns.txt \
    > "$CASE/recon/mdns-eth1.tsv"
sha256sum "$PCAP" "$CASE/recon/mdns-eth1.tsv" >> "$CASE/SHA256SUMS"
```

The capture is the evidence; the TSV is derived from it and can be rebuilt from
it at any time.

## Related tools

- [avahi-browse](avahi-browse.md): the active route, asking every host for its
  services, once its masked daemon has been unmasked with approval.
- [tshark](../traffic/tshark.md) and [Wireshark](../traffic/wireshark.md): the
  capture behind the helper, and the place to read a saved mDNS capture.
- [p0f](p0f.md) and [netdiscover](netdiscover.md): other passive views of the
  hosts on the same segment.
- [nmap](nmap.md): the `dns-service-discovery` script asks one host on UDP 5353
  for its DNS-SD services, for an approved active check.

## Upstream documentation

mDNS listen is SnapshOT's own helper; its comments and the snapshot-menu
changelog describe it. For the parts it is built from:

- [tshark manual](https://www.wireshark.org/docs/man-pages/tshark.html): capture
  and read options, `-T fields` and `-e`.
- [RFC 6762, Multicast DNS](https://www.rfc-editor.org/rfc/rfc6762) and
  [RFC 6763, DNS-Based Service Discovery](https://www.rfc-editor.org/rfc/rfc6763):
  what hosts announce and how.
