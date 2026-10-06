---
title: Redpoint NSE
summary: Digital Bond's ICS device-identification scripts for nmap
folder: recon
launchers: []
ships_as: vendor
package: redpoint-nse
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  preparation: Record each controller's identity (vendor, model, firmware) from a known-good position, inside an agreed window, as part of the baseline.
  identification: Confirm the make and firmware of a device already seen on the wire, one host at a time and only with approval.
  recovery: Check that a restored controller reports the same identity and firmware as the baseline before it returns to service.
csf: [identify, detect, recover]
attack_ics: [discovery]
attack_role: resembles
attack_techniques: [T0846, T0888]
protocols: [modbus, s7comm, ethernet-ip, bacnet, dnp3, omron-fins, niagara-fox, pcworx]
upstream: https://github.com/digitalbond/Redpoint
---

<!-- snapshot:facts -->

## What it is

Redpoint is a set of nmap scripting engine (NSE) scripts from Digital Bond that
identify and enumerate industrial devices in their own protocols. Where Debian's
nmap package already carries ICS scripts such as `modbus-discover` and `s7-info`,
Redpoint adds device-specific enumeration: it asks a controller, in its native
protocol, for its vendor, model, firmware, serial number and project details.
On SnapshOT the scripts are vendored and symlinked into nmap's script directory,
so they run exactly like any other NSE script. The pinned archive carries 13
scripts: `s7-enumerate` (Siemens S7), `enip-enumerate` (EtherNet/IP),
`cspv4-info` (Allen-Bradley CSPv4 on TCP 2222), `BACnet-discover-enumerate`,
`modicon-info` (Schneider Modicon), `dnp3-info`, `fox-info` (Niagara Fox),
`pcworx-info` (Phoenix Contact PC Worx), `proconos-info` (ProConOS),
`codesys-v2-discover` (CoDeSys V2), `omrontcp-info` and `omronudp-info` (Omron
FINS) and `atg-info` (automatic tank gauges on TCP 10001).

## Why it is on SnapshOT

Passive capture tells you a device is there; an identity query tells you what it
is. When a responder needs to know the exact make and firmware of a controller
to compare it with an advisory or a known-good baseline, Redpoint reads that
from the device in its own protocol instead of guessing from a banner. The
scripts cover vendors and protocols the stock nmap scripts do not, for example
Schneider Modicon (`modicon-info`), Phoenix Contact PC Worx (`pcworx-info`),
Niagara Fox (`fox-info`) and Omron FINS. They are run through nmap, so the same
rate limits, target control and output formats apply.

## On the wire

!!! warning "Active: it sends protocol queries to the target"

    Each Redpoint script opens a session to the device and sends real protocol
    requests. Digital Bond's own README warns that many ICS devices and
    applications are fragile and can crash or respond unexpectedly to
    unanticipated traffic, so use them with care.

    - Most Redpoint scripts are in NSE's **intrusive** category (the S7,
      EtherNet/IP, CSPv4, BACnet, Modicon, DNP3 and Fox scripts). Treat all of
      them as intrusive on a controller: run one only with written approval for
      that host, inside the agreed window, with the engineer responsible for the
      device present.
    - The Omron, PC Worx and ProConOS scripts are in the **version** category,
      so they also run whenever version detection (`-sV`, `-A`) reaches TCP or
      UDP 9600, TCP 1962 or TCP 20547. Another reason to leave `-sV` off
      controllers.
    - `atg-info` reads a tank gauge's inventory report by default; its
      `command` script argument sends any other gauge command instead,
      including ones that change the gauge's configuration. Never pass it.
    - Tell the site's monitoring team first: an identity query to a PLC is
      indistinguishable from an adversary enumerating the same device.
    - One host at a time, one script at a time, and only the script that matches
      the protocol you already saw on the wire. Do not sweep a segment with
      every ICS script at once, and stop if the device stops answering, faults
      or changes mode.
    - The scripts send legitimate protocol commands and do not attempt
      exploitation, but a legitimate command is still an unexpected command to a
      controller that only ever talks to its HMI.

## PICERL mapping

### Preparation

Before the engagement, and from an agreed position, record each controller's
reported identity and firmware as part of the baseline, next to the nmap port
scan and the passive capture. Keep the nmap output with the case; later queries
are compared against it.

### Identification

During [identification](../../lifecycle/phases/identification.md), once passive
capture has shown a device speaking a protocol Redpoint covers, run the matching
script against that one host to confirm its vendor, model and firmware. Read the
identity, then stop; this is confirmation, not exploration. If the device's
behaviour changes or the operators report anything unusual, stop and hand
control back to the process owner.

### Recovery

When a controller is restored, the same identity query confirms it reports the
expected vendor, model and firmware before the process owner returns it to
service. A changed firmware string is a finding, not a formality.

## MITRE ATT&CK for ICS mapping

Redpoint *resembles* the Discovery tactic. Its queries are what Remote System
Discovery (T0846) and Remote System Information Discovery (T0888) look like on
the wire: a host asking controllers, in their own protocols, who and what they
are. That is why the site's monitoring must be told before a script runs, and
why the same traffic seen in a capture, unannounced, is a strong sign of an
intruder enumerating the control network. The script output documents the device
identity an adversary could have read at that time.

## Quick start

Redpoint has no launcher of its own: the scripts are symlinked into nmap's
script directory, so they are reached through nmap. Pass `-p` for the
protocol's port and name the one script you need.

```sh
# Describe every Redpoint script (and the stock ICS scripts the patterns also match)
nmap --script-help \
    's7*,enip*,cspv4*,BACnet*,modicon*,dnp3*,fox*,pcworx*,proconos*,codesys*,omron*,atg*'
# Siemens S7 identity on one known host
nmap -sT -n -Pn -p 102 --script s7-enumerate --max-rate 10 192.0.2.20
# Schneider Modicon identity (Modbus function codes 43 and 90)
nmap -sT -n -Pn -p 502 --script modicon-info --max-rate 10 192.0.2.10
# EtherNet/IP list-identity on one host
nmap -sT -n -Pn -p 44818 --script enip-enumerate --max-rate 10 192.0.2.30
# BACnet device enumeration (UDP; a UDP scan needs root)
sudo nmap -sU -n -Pn -p 47808 --script BACnet-discover-enumerate 192.0.2.40
# DNP3 identity
nmap -sT -n -Pn -p 20000 --script dnp3-info --max-rate 10 192.0.2.50
# Niagara Fox device information
nmap -sT -n -Pn -p 1911 --script fox-info --max-rate 10 192.0.2.60
```

`192.0.2.0/24` is a documentation range: replace it with the approved target.
Script names are case-sensitive in `--script` and `--script-help`: `bacnet*`
matches only nmap's own `bacnet-info`, so the Redpoint BACnet script needs
`BACnet*` or its full name. Add `--script-args full=yes` to
`BACnet-discover-enumerate` only when the asset owner agrees, as it also reads
the broadcast distribution and foreign device tables.

## Output and evidence

Redpoint output is part of nmap's output, so capture it the same way: write every
run to the case folder in all three formats with `-oA`, then hash it.

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/nmap"
nmap -sT -n -Pn -p 102 --script s7-enumerate -oA "$CASE/nmap/plc02-s7" 192.0.2.20
sha256sum "$CASE"/nmap/plc02-s7.* >> "$CASE/SHA256SUMS"
```

Run a [tshark](../traffic/tshark.md) capture at the same time when the session
matters: the packets are the evidence of exactly what was asked and answered.

## Related tools

- [nmap](nmap.md): the engine that runs these scripts. The **nmap ICS scripts**
  launcher's patterns show the S7, EtherNet/IP, DNP3, Fox, PC Worx and Omron
  Redpoint scripts beside the stock ones; use the command above for the rest.
- [plcscan](../protocols/plcscan.md): S7comm and Modbus identification without
  nmap.
- [tshark](../traffic/tshark.md): see the device on the wire first, and capture
  the identity query while it runs.
- [mbpoll](../protocols/mbpoll.md): read Modbus registers once `modicon-info`
  has identified a Schneider controller.

## Upstream documentation

- [Redpoint on GitHub](https://github.com/digitalbond/Redpoint): the scripts,
  their arguments and the per-script notes.
- [NSE documentation](https://nmap.org/nsedoc/): how nmap runs scripts and names
  their arguments.
