---
title: tcpflow
summary: Reconstruct and record TCP flows
folder: traffic
launchers: [snapshot-tcpflow.desktop]
ships_as: apt
package: tcpflow
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  identification: Reconstruct the clear-text sessions in a capture, so a device web login, a Telnet or FTP transfer or an HTTP exchange can be read in full.
  lessons-learned: Carve the exact content exchanged in a session out of the case captures for the report.
csf: [detect, respond]
attack_ics: [collection, command-and-control, impact]
attack_role: investigates
attack_techniques: [T0845, T0811, T0869, T0882]
protocols: [http, ftp, telnet, modbus]
upstream: https://github.com/simsong/tcpflow
---

<!-- snapshot:facts -->

## What it is

tcpflow reads a capture (or listens on an interface) and reconstructs each TCP
connection into the stream of bytes that crossed it, writing one file per
direction of each flow, named for the two endpoints. Where a packet tool shows
one packet at a time, tcpflow shows the whole conversation as it was sent: a web
login and its response, a Telnet session, an FTP control session and its data
transfer, an HTTP download. It reconstructs TCP only; UDP protocols such as TFTP
are better followed in [tshark](tshark.md). It writes a DFXML report
(`report.xml`) of the flows it found, with their start and end times, and can
print flows to the screen in text or hex instead of to files.

## Why it is on SnapshOT

Industrial networks carry more than the control protocols: HMIs and engineering
stations reach PLCs, switches and gateways over HTTP, Telnet and FTP, and those
clear-text sessions often hold the credentials, firmware uploads and
configuration changes that matter to an incident (SSH and TLS sessions are
reconstructed too, but stay encrypted). tcpflow turns a capture of
those sessions back into readable content, so a responder can see what was
actually sent without clicking through packets. It complements the ICS dissectors
in [tshark](tshark.md) rather than replacing them: the binary control protocols
are better read there.

## On the wire

!!! note "Passive: it never transmits"

    tcpflow reads a capture or listens; it sends nothing. Working from a saved
    file is the norm on SnapshOT.

    - Run it against the case pcap (`-r`), not on a live control network. Reading
      a file needs no privileges; only live capture (`-i`) needs `sudo`.
    - Reconstructed flows can contain credentials and process data. Keep the
      output inside the case folder with the rest of the evidence and handle it
      as sensitive.
    - Give `-o` an output directory so tcpflow does not scatter flow files into
      the current directory.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), run tcpflow
over the agreed capture to reconstruct the clear-text sessions: a login to a
PLC's web interface, a Telnet session to a switch, an FTP transfer of a
configuration file. Reading the content in full often explains a finding that the
packet view only hints at.

### Lessons Learned

Carve the exact bytes exchanged in a relevant session out of the case captures,
so the report can show what was taken or changed. The flow file stays in the
case's `analysis/flows/` folder with its hash in `SHA256SUMS`, and its name and
the `report.xml` entry tie it to the endpoints and times in the original
capture, so a reader can trace every quoted byte back to the evidence.

## MITRE ATT&CK for ICS mapping

tcpflow *investigates*: it analyzes a capture after the fact and produces no
traffic of its own. Where a packet view shows that a session happened, tcpflow
shows what it carried, for three tactics:

- **Collection**: a controller's program or configuration pulled over FTP or
  HTTP comes back as the file itself (Program Upload, T0845), and so do
  documents copied from an engineering station or a historian's file share
  (Data from Information Repositories, T0811).
- **Command and Control**: the commands and responses of a channel run over an
  ordinary clear-text protocol, an HTTP exchange or a Telnet session, read in
  full (Standard Application Layer Protocol, T0869).
- **Impact**: when such files leave the site over a clear-text protocol, the
  reconstructed flows show exactly what was taken (Theft of Operational
  Information, T0882), which the report needs in order to state the loss.

## Quick start

```sh
# What the menu launcher runs
tcpflow -h
# The case's folder for reconstructed flows (tcpflow creates only the last level)
mkdir -p ~/cases/site-a/analysis/flows
# Reconstruct every flow in a capture into a case subfolder
tcpflow -r ~/cases/site-a/pcap/eth1.pcapng -o ~/cases/site-a/analysis/flows
# Only the flows to one device's web interface
tcpflow -r ~/cases/site-a/pcap/eth1.pcapng -o ~/cases/site-a/analysis/flows/web \
    'host 192.0.2.10 and port 80'
# Prepend an ISO 8601 UTC timestamp to each flow's file name
tcpflow -r ~/cases/site-a/pcap/eth1.pcapng -o ~/cases/site-a/analysis/flows -FT
# Print the Telnet flows to the screen, as hex, instead of writing files
tcpflow -r ~/cases/site-a/pcap/eth1.pcapng -o /tmp -c -D 'port 23'
# Print the HTTP flows as text, with non-printable bytes shown as dots
tcpflow -r ~/cases/site-a/pcap/eth1.pcapng -o /tmp -c -s 'port 80'
```

The expression at the end is a tcpdump-style filter. Console mode (`-c`) still
writes a `report.xml`, into the current directory unless `-o` says otherwise,
hence `-o /tmp`. tcpflow creates the `-o` folder but not its parents. `-FT` (ISO 8601) and `-Ft`
(Unix time) prefix the file names with the flow's UTC start time so flows sort
in order. Each file is named for its two endpoints, source first, with
zero-padded addresses and ports (`192.000.002.005.40001-192.000.002.010.00080`).

## Output and evidence

tcpflow writes the flow files and a `report.xml` into the output directory. Keep
that directory in the case folder and hash it:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/analysis"
tcpflow -r "$CASE/pcap/eth1.pcapng" -o "$CASE/analysis/flows" -FT
# Hash every reconstructed flow and the report
find "$CASE/analysis/flows" -type f -exec sha256sum {} + >> "$CASE/SHA256SUMS"
```

Work from a copy of the capture; tcpflow never modifies the pcap it reads.

## Related tools

- [tcpdump](tcpdump.md) and [tshark](tshark.md): capture the traffic, and decode
  the binary control protocols tcpflow does not.
- [Wireshark](wireshark.md): "Follow TCP Stream" does the same reconstruction
  one conversation at a time, in the GUI.

## Upstream documentation

- [tcpflow on GitHub](https://github.com/simsong/tcpflow): source, the DFXML
  report format and the filename templates.
