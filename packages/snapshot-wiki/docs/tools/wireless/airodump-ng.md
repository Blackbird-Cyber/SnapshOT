---
title: airodump-ng
summary: 802.11 capture and discovery
folder: wireless
launchers: [snapshot-airodump-ng.desktop]
ships_as: apt
package: aircrack-ng
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Survey the Wi-Fi around a site and record the expected access points and clients as a baseline.
  identification: Find rogue or unexpected access points and wireless clients near OT equipment, and read how each network is secured.
csf: [identify, detect]
attack_ics: [discovery, collection]
attack_role: resembles
attack_techniques: [T0887]
protocols: [wifi]
upstream: https://www.aircrack-ng.org/documentation.html
---

<!-- snapshot:facts -->

## What it is

airodump-ng is the IEEE 802.11 (Wi-Fi) survey tool of the aircrack-ng suite.
With a wireless adapter in monitor mode, which `airmon-ng` from the same package
sets up, it listens across the Wi-Fi channels and lists the access points and
client stations it hears: their BSSID, channel, signal, encryption and cipher,
the network names, and the networks clients are probing for. It can save what it
hears to pcap, CSV and other formats. Debian ships it in the `aircrack-ng`
package, which also installs the suite's key cracker and its injection tools
(`aireplay-ng`, `airbase-ng` and others); SnapshOT gives none of those a menu
entry, and its receive-only survey does not use them.

## Why it is on SnapshOT

Wireless is a way into an OT environment that a wired survey never sees: rogue
access points, wireless HMIs and sensors, maintenance laptops bridging to the
plant network, a client probing for a network an attacker can stand up. A passive
802.11 survey with airodump-ng maps that attack surface and finds what should not
be there, and a baseline taken when things are known good is what makes a later
rogue obvious. It is the only 802.11 entry in 05 Wireless & SDR, which is
receive-only: [rtl-sdr](rtl-sdr.md) and [Gqrx](gqrx.md) cover the radio spectrum
outside Wi-Fi.

## On the wire

!!! note "Passive: it only listens"

    airodump-ng receives 802.11 frames and sends none, as long as `-x` (active
    scanning simulation, which sends probe requests) is left out. Nothing reaches
    the site's Wi-Fi, and its wireless monitoring sees nothing.

    - Monitor mode and capture need `sudo`, and need a wireless adapter and
      driver that support monitor mode; many built-in laptop adapters do not.
      `airmon-ng` changes the adapter's mode, the laptop's own state, not the
      network's.
    - SnapshOT ships NetworkManager's Wi-Fi switch off, and the switch is also
      an rfkill soft block: `sudo airmon-ng start` on a blocked adapter stops
      with "soft blocked, please run rfkill unblock" and offers to do it.
      Unblock only the survey adapter (`sudo rfkill` lists the IDs) and leave
      the switch off: NetworkManager does not use any Wi-Fi adapter while it is
      off, so the laptop sends no probe requests during the survey. Switching
      Wi-Fi on instead (`nmcli radio wifi on`) unblocks every radio, and
      NetworkManager starts scanning with each adapter it manages
      ([quiet network defaults](../../platform/network-defaults.md)).
    - `sudo airmon-ng check` lists NetworkManager and wpa_supplicant as
      processes that can interfere. With the Wi-Fi switch off they leave the
      adapters alone, so there is no need to stop them; `airmon-ng check kill`
      stops NetworkManager and kills wpa_supplicant, which also drops the
      laptop's wired connections.
    - The `aircrack-ng` package also installs tools that transmit
      (deauthentication, injection, fake access points). They have no launcher
      and are not part of the survey: knocking a wireless instrument, telemetry
      link or HMI tablet off the air can interrupt a process, and transmitting
      without the network owner's authorization is unlawful in most
      jurisdictions. The [rules of engagement](../../lifecycle/rules-of-engagement.md)
      keep radio work receive-only.
    - Listening is passive, but what you may record of other parties' traffic is
      regulated in some jurisdictions. Keep the survey to what the authorization
      covers: the networks, clients and how they are secured.

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

airodump-ng *resembles* two tactics, because a survey is what an adversary runs
against a plant's Wi-Fi before choosing a way in. Both are Wireless Sniffing
(T0887):

- [Discovery](../../lifecycle/attack-ics/discovery.md): the list of access
  points, clients, channels and the networks clients probe for is what an
  adversary builds to find targets.
- [Collection](../../lifecycle/attack-ics/collection.md): frames written to pcap
  hold whatever crosses an open or weakly protected network, and a captured WPA
  handshake is what an adversary would attack offline.

Because a receive-only survey leaves no trace on the air, an adversary's sniffing
cannot be detected; what the survey gives the responder is the exposure it
measured. As evidence, the CSV and pcap document the wireless attack surface,
authorized and rogue, at a point in time: which networks and clients an
adversary in range could have seen, and how each was protected. An access point
nobody can account for may be a way in, which the
[wireless survey](../../lifecycle/playbooks/wireless-survey.md) playbook follows
up as possible Wireless Compromise (T0860).

## Quick start

The capture commands need `sudo` and a monitor-mode-capable adapter, shown here
as `wlan0` with rfkill ID `1`; the help does not.

```sh
# What the menu launcher runs
airodump-ng --help
# The radios and their rfkill state: blocked while NetworkManager's Wi-Fi switch is off
sudo rfkill
# Unblock the survey adapter alone (its ID from the list); the switch stays off
sudo rfkill unblock 1
# List processes that can interfere with monitor mode
sudo airmon-ng check
# Put the adapter into monitor mode (creates e.g. wlan0mon)
sudo airmon-ng start wlan0
# Passive survey: list APs and clients, write pcap/CSV to the case folder
sudo airodump-ng --manufacturer --write ~/cases/site-a/wifi/survey wlan0mon
# Hop the 5 GHz channels instead of 2.4 GHz (if the adapter supports them)
sudo airodump-ng --band a wlan0mon
# Stay on one channel, showing the WPS information access points advertise
sudo airodump-ng --channel 6 --wps wlan0mon
# Stop monitor mode when finished, and block the adapter again
sudo airmon-ng stop wlan0mon
sudo rfkill block 1
```

`airodump-ng` hops the 2.4 GHz channels by default; `--band a` or `-C` with a
list of frequencies in MHz reaches 5 GHz. Pick a single channel with `--channel`
once you know where a device of interest lives, and leave `-x` out.

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

- [rtl-sdr](rtl-sdr.md) and [Gqrx](gqrx.md): sweep and look at the radio
  spectrum outside Wi-Fi for the other wireless links around a site.
- [Wireshark](../traffic/wireshark.md): open the 802.11 pcap airodump-ng wrote to
  decode the management and data frames.

## Upstream documentation

- [aircrack-ng documentation](https://www.aircrack-ng.org/documentation.html):
  airodump-ng, airmon-ng, monitor mode and the survey options.
- `man airodump-ng` and `man airmon-ng`: the options on the image.
