---
title: tcpreplay
summary: Replay captured traffic
folder: traffic
launchers: [snapshot-tcpreplay.desktop]
ships_as: apt
package: tcpreplay
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  preparation: In a lab, replay representative captures to validate that the monitoring and IDS rules you will rely on actually fire.
  lessons-learned: In a lab, replay the incident's captured traffic to build and test detections before the next engagement.
csf: [protect, detect]
attack_ics: [command-and-control, impair-process-control]
attack_role: resembles
attack_techniques: [T1692, T1692.001, T0869]
protocols: [modbus, dnp3, ethernet-ip]
upstream: https://tcpreplay.appneta.com/
---

<!-- snapshot:facts -->

## What it is

tcpreplay is a suite that sends the packets from a pcap file back out onto a
network interface, at the capture's original timing or at a rate you set. The
suite includes `tcprewrite` (change addresses, ports and checksums in a capture
before replay), `tcpprep` (classify a capture into client and server sides) and
`tcpliveplay` (replay a TCP session against a live host with new, valid
sequence numbers). It is a traffic generator: it takes recorded packets and puts
them on the wire again.

## Why it is on SnapshOT

One of the two Traffic Analysis tools that transmit (with
[Scapy](scapy.md)), tcpreplay is here for the lab, not the plant. Replaying a captured incident, or a representative sample
of OT traffic, against a test segment is how a responder checks that the passive
monitoring, the IDS rules and the [Suricata](suricata.md) signatures they will
depend on actually fire on the traffic they are meant to catch. It turns a
capture into a repeatable test.

## On the wire

!!! danger "Writes: it injects packets onto the network"

    tcpreplay re-sends real recorded traffic, including recorded control-protocol
    commands. On a control network those replayed packets are indistinguishable
    from a live attack and can be acted on by a device.

    - **Never replay onto a production control network, or any network that
      reaches one.** Use an isolated lab segment or a bench with only the
      equipment under test attached. A replayed Modbus write, DNP3 operate or
      CIP command can move real equipment.
    - Confirm the target interface is the lab interface every time
      (`tcpreplay --listnics`). A replay sent out of the wrong port is on the
      wrong network.
    - Rewrite addresses and MACs with `tcprewrite` so the replay matches the lab,
      and recalculate checksums (`--fixcsum`); replaying a capture unchanged puts
      the original production addresses on the lab wire.
    - Sending needs `sudo`; `tcprewrite` and `tcpprep`, which only edit files, do
      not. Do the editing as your user and keep `sudo` for the moment of replay.
    - Tell whoever runs the lab's monitoring: a replay is meant to look like the
      attack, so it will trip every detection that works.

## PICERL mapping

### Preparation

Before an engagement, replay representative OT captures against a lab segment to
confirm the detections you plan to rely on during
[identification](../../lifecycle/phases/identification.md) actually fire: that
the Suricata event rules alert, that the capture point sees the conduit, that the
baseline tooling behaves. This validates the kit, away from any live process.

### Lessons Learned

After an incident, replay its captured traffic in the lab to build and test the
signatures and rules that would have caught it sooner. The capture becomes a
regression test for the next engagement's monitoring.

## MITRE ATT&CK for ICS mapping

tcpreplay *resembles* the techniques carried in the traffic it replays; it adds
none of its own. Two tactics matter for the captures an OT team replays:

- **Impair Process Control**: a capture that holds controller commands,
  replayed, reproduces Unauthorized Message (T1692) and Unauthorized Message:
  Command Message (T1692.001). A replayed Modbus write or DNP3 operate is a real
  command to whatever device receives it.
- **Command and Control**: an incident capture that holds the adversary's
  channel, replayed, reproduces that channel on the wire, for example over
  Standard Application Layer Protocol (T0869), which is how a lab tests the
  detections meant to catch it.

That is exactly why it is a lab tool: on a live network its output would be a
real unauthorized command, not a test. Used in the lab, it drives the detections
that catch those techniques for real, and the lab capture of the replay shows
which ones fired.

## Quick start

All examples assume an isolated lab interface, shown here as `lab0`. Confirm it
first.

```sh
# What the menu launcher shows
tcpreplay -h
# List interfaces so you replay onto the lab port, never a live one
tcpreplay --listnics
# Rewrite the capture's addresses and MACs to the lab, as your user (edits a file)
tcprewrite --infile=incident.pcap --outfile=lab.pcap \
    --pnat=192.0.2.0/24:198.51.100.0/24 \
    --enet-smac=02:00:00:00:00:bb --enet-dmac=02:00:00:00:00:aa --fixcsum
# Replay onto the lab segment at 10 packets a second (needs sudo)
sudo tcpreplay -i lab0 --pps=10 lab.pcap
# Replay at the capture's original timing instead
sudo tcpreplay -i lab0 lab.pcap
```

`--pnat` maps the capture's networks onto the lab's; `--fixcsum` recomputes the
checksums the rewrite invalidates. Keep the rate low (`--pps`) so the device
under test is not flooded.

## Output and evidence

tcpreplay prints how many packets it sent. Record the lab test in the case notes
with the exact files and command:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/lab"
# Keep the rewritten capture beside the lab notes
cp lab.pcap "$CASE/lab/"
{ date -u; echo '# lab replay of incident capture, isolated segment lab0';
  echo '$ sudo tcpreplay -i lab0 --pps=10 lab.pcap'; } >> "$CASE/lab/replay-notes.txt"
sha256sum "$CASE/lab/lab.pcap" >> "$CASE/SHA256SUMS"
```

The evidence of what a replay produced is a capture taken on the lab segment with
[tcpdump](tcpdump.md) or [tshark](tshark.md) while it runs.

## Related tools

- [Suricata](suricata.md): the detections a lab replay is usually run to
  validate.
- [tcpdump](tcpdump.md) and [tshark](tshark.md): capture the replayed traffic on
  the lab segment to prove what was sent.
- [Wireshark](wireshark.md): inspect the capture you are about to replay, and the
  one the replay produces.

## Upstream documentation

- [tcpreplay documentation](https://tcpreplay.appneta.com/): the suite, the
  rewrite options and the replay modes.
