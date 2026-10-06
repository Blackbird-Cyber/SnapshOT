---
title: Suricata
summary: IDS/IPS and network monitoring
folder: traffic
launchers: [snapshot-suricata.desktop]
ships_as: apt
package: suricata
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  identification: Run offline over a capture to flag protocol anomalies and, with a rule set, known-bad traffic, with a structured eve.json to triage.
  containment: Re-run over fresh captures to confirm the alerting traffic has stopped once a conduit is isolated.
  lessons-learned: Build and keep the rules that would have caught the incident, and record the alerts behind the timeline.
csf: [detect, respond]
attack_ics: [discovery, command-and-control, lateral-movement, impair-process-control]
attack_role: detects
attack_techniques: [T0846, T0886, T0869, T0885, T1692]
protocols: [modbus, dnp3, ethernet-ip, http, dns, smb, rdp, ssh]
upstream: https://docs.suricata.io/
---

<!-- snapshot:facts -->

## What it is

Suricata is a network intrusion-detection engine. It inspects traffic, live or
from a capture, against a set of rules and a set of protocol parsers, and writes
alerts and protocol records to `fast.log` and to a structured `eve.json` event
log. It understands the common IT protocols (HTTP, TLS, DNS, SMB and others) and
ships parsers for the industrial protocols Modbus, DNP3 and EtherNet/IP. On
SnapshOT its main use is offline: run it over a case pcap with `-r` and triage
the `eve.json` it produces.

## Why it is on SnapshOT

Reading a large capture by hand finds what you look for; Suricata flags what you
did not. Run over the case captures it raises protocol anomalies (malformed
Modbus, unsolicited responses, DNP3 CRC errors) and, when you give it a rule set,
matches of known-bad traffic, and it records every HTTP request, TLS handshake
and DNS query as a JSON event you can filter and count. It turns a pcap into a
structured, searchable event stream.

## On the wire

!!! note "Passive: it never transmits"

    Suricata in the way SnapshOT uses it reads a file and emits logs; it sends
    nothing.

    - Prefer offline analysis: `suricata -r capture.pcap -l outdir`. Reading a
      file needs no privileges. Live capture (`-i`, `--af-packet`) needs `sudo`
      and should be done on a TAP or SPAN port, never inline on a control
      network (the inline and IPS modes can drop packets and are not for a plant
      floor).
    - The industrial parsers are shipped but off by default. Enable them for a
      run with `--set app-layer.protocols.modbus.enabled=yes` (and the same for
      `dnp3` and `enip`), or in a copy of `suricata.yaml`. The Modbus and DNP3
      event rules only load when their parser is enabled.
    - Run as your user, Suricata warns that it cannot create its command socket
      under `/var/run`; that is harmless for offline analysis.

!!! note "Rule set on this image"

    SnapshOT ships Suricata and its Debian configuration, including the built-in
    protocol-anomaly and decoder event rules under `/etc/suricata/rules/`
    (`modbus-events.rules`, `dnp3-events.rules`, `dns-events.rules` and the
    rest). It does **not** ship a signature rule set (Emerging Threats, Talos or
    an ICS rule pack), and it does not ship `suricata-update`, which would fetch
    one over the network. The default `rule-files:` in `suricata.yaml` is
    `suricata.rules` under `/var/lib/suricata/rules`, a file only
    `suricata-update` creates, so out of the box a run warns that no rule files
    match, loads no rules, and only the app-layer parsers and their logs do any
    work. Point `-S` at the shipped event rules, or at rules you bring, to get
    alerts; those you bring should be carried in with the rest of the
    engagement material.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), run Suricata
over the agreed capture with the industrial parsers enabled and the shipped event
rules loaded. Triage the `eve.json`: the `alert` records point at anomalies and
rule matches, and the `flow`, `http`, `dns` and protocol records give a
structured index of what the capture contains.

### Containment

After a conduit is isolated, re-run Suricata over a fresh capture from each side
to confirm the traffic that was alerting has stopped, while the process traffic
that must continue still appears in the event log.

### Lessons Learned

Keep, and test, the rules that would have caught the incident: run them over
the case captures with `-S`, or replay the traffic in a lab with
[tcpreplay](tcpreplay.md), and confirm they fire. The `eve.json` alerts and
flow records are the structured evidence behind the timeline in the report;
each timestamp carries its UTC offset, so it lines up with the capture it came
from.

## MITRE ATT&CK for ICS mapping

Suricata *detects*: its alerts and protocol records are evidence of four
tactics.

- **Discovery**: scan signatures, and flow records that show one source
  touching many hosts or ports (Remote System Discovery, T0846).
- **Lateral Movement**: its SMB, RDP and SSH parsers log every remote session
  between hosts, so a session from the IT side to an engineering station or
  from one control host to the next stands out in `eve.json` (Remote Services,
  T0886).
- **Command and Control**: flow, HTTP, TLS and DNS records of sessions that
  leave the zone on ordinary protocols and ports (Standard Application Layer
  Protocol, T0869; Commonly Used Port, T0885).
- **Impair Process Control**: with the Modbus, DNP3 and EtherNet/IP parsers
  enabled, rules on function codes and services flag write and operate
  requests from hosts that should not send them (Unauthorized Message, T1692),
  and the event rules flag malformed control messages.

What it catches depends on the parsers you enable and the rules you load; with
no signature rule set, the protocol records are the main evidence.

## Quick start

```sh
# What the menu launcher shows
suricata --build-info
# Check that the configuration and the rules load (-l: a folder you can write to)
mkdir -p ~/cases/site-a/analysis/suricata
suricata -T -c /etc/suricata/suricata.yaml -l ~/cases/site-a/analysis/suricata \
    -S /etc/suricata/rules/modbus-events.rules \
    --set app-layer.protocols.modbus.enabled=yes
# Run offline over a capture, Modbus parser on, shipped Modbus events loaded
suricata -r ~/cases/site-a/pcap/eth1.pcapng -l ~/cases/site-a/analysis/suricata \
    -S /etc/suricata/rules/modbus-events.rules \
    --set app-layer.protocols.modbus.enabled=yes
# Same, enabling DNP3 and EtherNet/IP as well, with your own rules
suricata -r ~/cases/site-a/pcap/eth1.pcapng -l ~/cases/site-a/analysis/suricata \
    -S ~/cases/site-a/analysis/suricata/engagement.rules \
    --set app-layer.protocols.modbus.enabled=yes \
    --set app-layer.protocols.dnp3.enabled=yes \
    --set app-layer.protocols.enip.enabled=yes
# Pull the alerts out of the JSON event log
jq -c 'select(.event_type=="alert")
    | {ts:.timestamp, sig:.alert.signature, src:.src_ip, dst:.dest_ip}' \
    ~/cases/site-a/analysis/suricata/eve.json
```

`-l` is the output directory for `fast.log`, `eve.json`, `stats.log` and
`suricata.log`; without it Suricata tries `/var/log/suricata`, which your user
cannot write. `-S` loads that rule file exclusively, in place of the
configuration's `rule-files:`, and `-s` loads one in addition to them; on this
image the configured rules do not exist, so either works. The shipped event
rules are in `/etc/suricata/rules/`. `jq` is on the image for reading
`eve.json`.

## Output and evidence

Suricata writes its logs into the `-l` directory. Keep that directory in the case
folder and hash it:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/analysis/suricata"
suricata -r "$CASE/pcap/eth1.pcapng" -l "$CASE/analysis/suricata" \
    -S /etc/suricata/rules/modbus-events.rules \
    --set app-layer.protocols.modbus.enabled=yes
sha256sum "$CASE"/analysis/suricata/eve.json "$CASE"/analysis/suricata/fast.log \
    >> "$CASE/SHA256SUMS"
```

Run over a copy of the capture; Suricata reads the pcap and never changes it.

## Related tools

- [tshark](tshark.md) and [Wireshark](wireshark.md): decode by hand the packets
  behind an alert.
- [tcpdump](tcpdump.md): capture the pcap Suricata then reads.
- [tcpreplay](tcpreplay.md): in a lab, replay traffic to confirm your rules fire.

## Upstream documentation

- [Suricata documentation](https://docs.suricata.io/): running modes, the
  `eve.json` schema and the rule language.
