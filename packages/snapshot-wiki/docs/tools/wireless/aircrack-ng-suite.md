---
title: aircrack-ng suite
summary: 802.11 capture and discovery, and WEP/WPA key cracking
folder: wireless
launchers: [snapshot-airodump-ng.desktop, snapshot-aircrack-ng.desktop]
ships_as: apt
package: aircrack-ng
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  preparation: Survey the Wi-Fi around a site and record the expected access points and clients as a baseline.
  identification: Find rogue or unexpected access points and wireless clients near OT equipment, and read a client's security posture.
csf: [identify, detect]
attack_ics: [initial-access, discovery, collection]
attack_role: resembles
attack_techniques: [T0860, T0887]
protocols: [wifi]
upstream: https://www.aircrack-ng.org/documentation.html
---

<!-- snapshot:facts -->

## What it is

The aircrack-ng suite is a set of tools for IEEE 802.11 (Wi-Fi) work. The ones a
responder uses on an OT engagement are `airmon-ng`, which puts a capable wireless
adapter into monitor mode, and `airodump-ng`, which then surveys the air: it
lists the access points and client stations it hears, with their BSSID, channel,
signal, encryption and the networks clients are probing for, and can save that to
pcap and CSV. `aircrack-ng` itself analyses a saved capture to test WEP and WPA
handshake strength offline. The suite also contains injection tools
(`aireplay-ng` and others) that transmit; those are not part of the SnapshOT
survey workflow.

## Why it is on SnapshOT

Wireless is a way into an OT environment that a wired survey never sees: rogue
access points, wireless HMIs and sensors, maintenance laptops bridging to the
plant network, a client probing for a network an attacker can stand up. A passive
802.11 survey with airodump-ng maps that attack surface and finds what should not
be there, and a baseline taken when things are known good is what makes a later
rogue obvious.

## On the wire

!!! danger "Writes: the suite includes tools that transmit"

    The survey tools (airmon-ng, airodump-ng) only listen, but the suite also
    contains injection tools (aireplay-ng and others) that transmit frames, and
    airmon-ng changes the adapter's state.

    - On SnapshOT, keep to the **receive-only survey**: `airmon-ng` to enter
      monitor mode and `airodump-ng` to listen. Leave out airodump-ng's `-x`
      (active scanning simulation), which sends probe requests. Do not use the
      transmitting tools (`aireplay-ng`, `airbase-ng` and the others) near a
      production OT environment: knocking a wireless instrument, telemetry link
      or HMI tablet off the air can interrupt a process.
    - **Transmitting is a legal question before it is a technical one.** Radio
      law varies by country and band, and injection or deauthentication without
      the network owner's authorization is unlawful in most jurisdictions.
      Transmit only where it is lawful for the band and named in the written
      authorization, and treat it as a write: the engineer for the affected
      wireless equipment present, inside the agreed window, and recorded (see
      the [rules of engagement](../../lifecycle/rules-of-engagement.md)).
    - A receive-only survey is invisible to the site's wireless monitoring; any
      transmission is what a wireless IDS alarms on, so tell the site's
      monitoring before any transmit, and stop at once if a wireless device
      drops off or operators report a lost link.
    - Monitor mode and capture need `sudo`, and need a wireless adapter and
      driver that support monitor mode; many built-in laptop adapters do not.
      `sudo airmon-ng check` lists processes, such as NetworkManager, that can
      interfere; stopping them also drops the laptop's other connections.
    - `aircrack-ng` run against a capture only reads a file and needs no `sudo`.

## PICERL mapping

### Preparation

In [preparation](../../lifecycle/phases/preparation.md), survey the Wi-Fi around
the site and record the access points and clients that are expected: their
BSSIDs, channels and encryption, checked against the site's own radio
inventory. This baseline is what a later survey is compared against.

### Identification

During [identification](../../lifecycle/phases/identification.md), and in the
[wireless survey](../../lifecycle/playbooks/wireless-survey.md) playbook, survey
the air near the OT equipment and compare it with the baseline: an access
point that should not be there, a client bridging to the control network, an open
or weakly encrypted network on a device that should be isolated. airodump-ng's
list names what is transmitting and how it is secured; follow a finding up with
the site's wireless owner.

## MITRE ATT&CK for ICS mapping

The suite *resembles* three tactics, because it is the same toolkit an adversary
brings to a plant's Wi-Fi.

- [Discovery](../../lifecycle/attack-ics/discovery.md): an airodump-ng survey is
  Wireless Sniffing (T0887) used to find targets. The list of access points,
  clients, channels and the networks clients probe for is what an adversary
  builds before choosing a way in.
- [Collection](../../lifecycle/attack-ics/collection.md): the same technique,
  Wireless Sniffing (T0887), also gathers data. Frames written to pcap hold
  whatever crosses an open or weakly protected network, and a captured WPA
  handshake is what `aircrack-ng` attacks offline.
- [Initial Access](../../lifecycle/attack-ics/initial-access.md): the
  transmitting tools in the suite are the kind used for Wireless Compromise
  (T0860), gaining access to a wireless network. That is why they stay out of
  the SnapshOT workflow unless the authorization names them.

Because a receive-only survey leaves no trace on the air, an adversary's sniffing
cannot be detected; what the survey gives the responder is the exposure it
measured. As evidence, the CSV and pcap document the wireless attack surface,
authorised and rogue, at a point in time: which networks and clients an
adversary in range could have seen, and how each was protected.

## Quick start

The capture commands need `sudo` and a monitor-mode-capable adapter, shown here
as `wlan0`; the two help commands and `aircrack-ng` on a file do not.

```sh
# What the airodump-ng launcher runs
airodump-ng --help
# What the aircrack-ng launcher runs
aircrack-ng --help
# Put the adapter into monitor mode (creates e.g. wlan0mon)
sudo airmon-ng start wlan0
# Passive survey: list APs and clients, write pcap/CSV to the case folder
sudo airodump-ng --manufacturer --write ~/cases/site-a/wifi/survey wlan0mon
# Survey one channel only, showing WPS information
sudo airodump-ng --channel 6 --wps wlan0mon
# Stop monitor mode when finished
sudo airmon-ng stop wlan0mon
# Offline: test a captured WPA handshake against a wordlist (reads a file)
aircrack-ng -w wordlist.txt ~/cases/site-a/wifi/survey-01.cap
```

`airodump-ng` hops the 2.4 GHz channels by default; `--band a` or `-C` with a
frequency list reaches 5 GHz. Pick a single channel with `--channel` once you
know where a device of interest lives.

## Output and evidence

airodump-ng's `--write` prefix produces pcap, CSV and netxml files. Keep them in
the case folder and hash them:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/wifi"
sudo airodump-ng --write "$CASE/wifi/survey" --output-format pcap,csv,netxml wlan0mon
sha256sum "$CASE"/wifi/* >> "$CASE/SHA256SUMS"
```

The CSV lists every access point and client seen; it is the record of the
wireless attack surface for the report.

## Related tools

- [Gqrx](gqrx.md) and [rtl-sdr](rtl-sdr.md): look at the wider radio spectrum,
  beyond Wi-Fi, for other wireless links around a site.
- [HackRF](hackrf.md): sweep the 2.4 and 5 GHz bands for non-Wi-Fi
  transmitters an 802.11 adapter cannot decode.
- [Wireshark](../traffic/wireshark.md): open the 802.11 pcap airodump-ng wrote to
  decode the management and data frames.

## Upstream documentation

- [aircrack-ng documentation](https://www.aircrack-ng.org/documentation.html):
  every tool in the suite, monitor mode and the survey options.
