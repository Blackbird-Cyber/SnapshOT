---
title: Wireless survey
summary: Map the Wi-Fi and radio around a site by receiving only, flag transmitters the inventory does not explain, and transmit nothing unless it is lawful and separately approved.
phases: [identification]
tactics: [discovery, initial-access]
---

A wireless survey finds the radios around a site: access points, clients, serial
and telemetry links, and anything transmitting that the asset inventory does not
explain. It belongs in [identification](../phases/identification.md), and it is
**receive only**: listening changes nothing and answers the question, and
SnapshOT's radio tools only receive. Any transmission (deauthentication,
injection, an active probe) is out of scope unless the authorization names it,
under the [rules of engagement](../rules-of-engagement.md), because radio law
varies by band and a transmission can knock a wireless instrument or safety link
off the air.

## Before you start

- The radio inventory from [preparation](../phases/preparation.md): the APs,
  bands and wireless devices the site expects to be there.
- Agreement that the survey is receive-only. Transmission, if it is in scope at
  all, is named in the authorization with the bands that are lawful.
- Hardware ready: a Wi-Fi adapter that supports monitor mode, and an RTL-SDR
  dongle with an antenna for the bands the inventory lists (roughly 24 MHz to
  1.7 GHz, depending on the tuner).

## Procedure

1. **Set up to receive.** Leave NetworkManager's Wi-Fi switch off, so the laptop
   itself sends no probe requests; unblock only the survey adapter
   (`sudo rfkill unblock <ID>`) and put it in monitor mode with `airmon-ng`
   ([airodump-ng](../../tools/wireless/airodump-ng.md) has the steps). Check the
   dongle with the [rtl-sdr](../../tools/wireless/rtl-sdr.md) dongle check
   (`rtl_eeprom`). Receive only.
   - *Record:* the adapter, the dongle (its serial from the dongle check) and the
     antennas used.

2. **Survey Wi-Fi.** Use [airodump-ng](../../tools/wireless/airodump-ng.md) to
   list access points and clients, their channels and encryption; it only
   listens (leave out `-x`, which sends probe requests).
   - *Record:* BSSIDs, SSIDs, channels, encryption and signal strength.
   - *Looks for:* [Discovery](../attack-ics/discovery.md), Wireless Sniffing
     (T0887): what an attacker could learn by listening.

3. **Sweep the spectrum.** Sweep the bands outside Wi-Fi to CSV with `rtl_power`
   from [rtl-sdr](../../tools/wireless/rtl-sdr.md), then tune to what the sweep
   shows in [Gqrx](../../tools/wireless/gqrx.md): 900 MHz and sub-GHz telemetry,
   serial radios, remote I/O links.
   - *Record:* the frequencies, bandwidths and when each signal appears.
   - *Looks for:* [Discovery](../attack-ics/discovery.md) and, for an unexpected
     inbound radio path, [Initial Access](../attack-ics/initial-access.md),
     Wireless Compromise (T0860).

4. **Correlate against the inventory.** Match every transmitter to a known device.
   - *Go/no-go:* a transmitter near the process that the inventory does not
     explain is a finding to report, not a reason to transmit at it.

5. **Capture signals of interest.** Record the raw signal or Wi-Fi frames for
   anything notable, and hash the captures into the case `SHA256SUMS`.

6. **Do not transmit.** The survey needs no transmission, and SnapshOT's menu
   offers no transmitting tool. Deauthentication, injection or an active probe
   happens only if the authorization names it and the band is lawful, and then it
   is treated as a [write](../wire-classes.md): engineer present, window, and the
   site told.

## Done when

- The site's Wi-Fi and radio surface is documented and matched against the
  inventory, with unknown transmitters flagged.
- Captures of interest are saved and hashed.
- Nothing was transmitted, unless a separate, lawful, approved action required it
  and it was recorded.

## Related pages

- [Passive baseline](passive-baseline.md): the wired equivalent, on the network.
- [Rules of engagement](../rules-of-engagement.md): the receive-only radio rules.
