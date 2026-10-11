---
title: tcpdump
summary: Command-line packet capture
folder: traffic
launchers: [snapshot-tcpdump.desktop]
ships_as: apt
package: tcpdump
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Record a baseline capture of each conduit to a rotating set of files while the process runs normally.
  identification: Grab packets from a SPAN or TAP with a tight capture filter, to a file the other tools then decode.
  containment: Capture briefly either side of an isolated conduit to prove the sessions stopped.
  recovery: Leave a rotating capture running to catch recurrence of an indicator found earlier.
csf: [identify, detect, respond, recover]
attack_ics: [discovery, command-and-control]
attack_role: detects
attack_techniques: [T0846, T0885]
protocols: [modbus, s7comm, ethernet-ip, bacnet, dnp3]
upstream: https://www.tcpdump.org/manpages/tcpdump.1.html
---

<!-- snapshot:facts -->

## What it is

tcpdump is the small, standard command-line packet capture tool, built on
libpcap. It captures from an interface, applies a BPF capture filter to keep only
the packets you want, and either prints a one-line summary of each packet or
writes the raw packets to a pcap file. It decodes the common headers (Ethernet,
IP, TCP, UDP) but does not carry the industrial-protocol dissectors that
[Wireshark](wireshark.md) and [tshark](tshark.md) have; its job is to get the
packets onto disk cleanly, for those tools to decode.

## Why it is on SnapshOT

tcpdump is the capture tool to use when the one that captures must be as small
and dependable as possible: a long unattended baseline, a quick grab on a jump
host, a capture filtered down to one conversation. It is present on almost every
system, so the commands transfer to a target host you are given access to, and
its BPF filters cut a capture to exactly the hosts and ports agreed in the rules
of engagement.

## On the wire

!!! note "Passive: it never transmits"

    tcpdump only listens. The capture interface needs no IP address.

    - Prefer a TAP or an agreed SPAN port. Use `-n` so tcpdump makes no DNS
      lookups for the addresses it sees.
    - A capture filter keeps the capture to what you are authorized to record:
      `tcp port 502`, `host 192.0.2.10`. Narrow is both quieter and smaller.
    - On this image tcpdump needs `sudo`: unlike Wireshark and tshark, it is not
      reached through the `wireshark` group's `dumpcap`. Run it with `sudo`, and
      use `-Z` to hand the saved files back to your user (see below).
    - A SPAN port can drop packets under load; note the switch and port so gaps
      can be explained.

## PICERL mapping

### Preparation

Before the engagement, record a baseline of each conduit to a rotating set of
files (`-G`, `-C`, `-W`) so a long capture does not fill the disk. The baseline
is what later captures are compared against during
[identification](../../lifecycle/phases/identification.md).

### Identification

Grab packets from the agreed SPAN or TAP with a capture filter that keeps only
the hosts and ports in scope, write them to a pcap, then decode the file with
tshark or Wireshark. tcpdump is the recorder; the decoding happens offline on the
file.

### Containment

After a conduit is isolated, a short capture either side of the boundary shows
whether the sessions that should have stopped are gone and whether the process
traffic that must continue still flows.

### Recovery

Leave a rotating capture running on a restored segment to catch any recurrence of
an indicator found earlier, and hand the files to the analysis tools each time a
file rotates closed.

## MITRE ATT&CK for ICS mapping

tcpdump *detects* by recording the raw evidence, and even without industrial
protocol dissectors its one-line summaries show two tactics directly:

- **Discovery**: one source touching many hosts or ports in a short time, the
  pattern of a sweep or a scan (Remote System Discovery, T0846).
- **Command and Control**: sessions that cross a zone boundary on ordinary
  ports to hosts that have no business there (Commonly Used Port, T0885).

Everything else, the function codes that make a write or a program download,
is in the same file and is named when tshark or Wireshark decodes it.

## Quick start

```sh
# What the menu launcher runs (list the capture interfaces)
tcpdump -D
# Capture Modbus traffic on eth1 to a file, dropping root to your own user
sudo tcpdump -n -i eth1 -Z "$USER" -w ~/cases/site-a/pcap/eth1-modbus.pcap tcp port 502
# One conversation, printed as a summary to the screen instead of a file
sudo tcpdump -n -i eth1 host 192.0.2.10 and tcp port 502
# Hourly files named by UTC start time; stop after 24 files
sudo TZ=UTC tcpdump -n -i eth1 -Z "$USER" -G 3600 -W 24 \
    -w ~/cases/site-a/pcap/eth1-%Y%m%dT%H%M%SZ.pcap
# Ring buffer: 100 MB files, reuse the oldest after 10
sudo tcpdump -n -i eth1 -Z "$USER" -C 100 -W 10 -w ~/cases/site-a/pcap/eth1.pcap tcp port 502
```

Replace `eth1` with the capture interface `tcpdump -D` lists, and create the
case folder first (`mkdir -p ~/cases/site-a/pcap`). After opening the
interface, Debian's tcpdump drops root to its own `tcpdump` user, which cannot
write into your home folder; `-Z "$USER"` makes it drop to you instead, so the
files are yours and readable without `sudo`. With `-G`, the `%Y%m%dT%H%M%S` in
the file name is filled in with `strftime` in local time, hence `TZ=UTC` and
the literal `Z`. With `-G`, `-W` stops the capture after that many files; with
`-C`, it numbers the files `eth1.pcap0` to `eth1.pcap9` and overwrites the
oldest.

## Output and evidence

Write captures into the case folder and hash them when each file closes:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/pcap"
sudo TZ=UTC tcpdump -n -i eth1 -Z "$USER" -G 3600 -W 24 \
    -w "$CASE/pcap/eth1-%Y%m%dT%H%M%SZ.pcap" tcp port 502
sha256sum "$CASE"/pcap/*.pcap >> "$CASE/SHA256SUMS"
# Start, end and packet count of each file
capinfos "$CASE"/pcap/*.pcap
```

## Related tools

- [tshark](tshark.md) and [Wireshark](wireshark.md): decode the industrial
  protocols in the files tcpdump wrote.
- [termshark](termshark.md): browse those files in a terminal UI.
- [tcpflow](tcpflow.md): reconstruct the TCP flows from a capture into per-flow
  files.

## Upstream documentation

- [tcpdump manual page](https://www.tcpdump.org/manpages/tcpdump.1.html): every
  option and the file-rotation flags.
- [pcap-filter manual page](https://www.tcpdump.org/manpages/pcap-filter.7.html):
  the capture-filter (BPF) syntax.
