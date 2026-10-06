---
title: Wireless survey
summary: Map the Wi-Fi and radio around a site by receiving only, flag transmitters the inventory does not explain, and transmit nothing unless it is lawful and separately approved.
phases: [identification]
tactics: [discovery, initial-access]
---

A wireless survey finds the radios around a site: access points, clients, serial
and telemetry links, and anything transmitting that the asset inventory does not
explain. It belongs in [identification](../phases/identification.md), and it is
**receive first**: listening changes nothing and answers most questions. Any
transmission (deauthentication, injection, an active probe) is a separate,
lawful-and-approved action under the [rules of engagement](../rules-of-engagement.md),
because radio law varies by band and a transmission can knock a wireless
instrument or safety link off the air.

## Before you start

- The radio inventory from [preparation](../phases/preparation.md): the APs,
  bands and wireless devices the site expects to be there.
- Agreement that the survey is receive-only. Transmission, if it is in scope at
  all, is named in the authorization with the bands that are lawful.
- Hardware ready: a Wi-Fi adapter that supports monitor mode, and an SDR for the
  wider spectrum.

## Procedure

1. **Set up to receive.** Put the Wi-Fi adapter in monitor mode and bring up the
   [SDR](../../tools/wireless/rtl-sdr.md). Receive only.
   - *Record:* the adapter, the SDR and the antennas used.

2. **Survey Wi-Fi.** Use `airodump-ng` from the
   [aircrack-ng suite](../../tools/wireless/aircrack-ng-suite.md) to list access
   points and clients, their channels and encryption; it only captures here, it
   does not inject.
   - *Record:* BSSIDs, SSIDs, channels, encryption and signal strength.
   - *Looks for:* [Discovery](../attack-ics/discovery.md), Wireless Sniffing
     (T0887): what an attacker could learn by listening.

3. **Sweep the spectrum.** With [Gqrx](../../tools/wireless/gqrx.md),
   [rtl-sdr](../../tools/wireless/rtl-sdr.md) and the
   [gr-osmosdr](../../tools/wireless/gr-osmosdr.md) and
   [SoapySDR](../../tools/wireless/soapysdr.md) backends, look for transmitters
   outside Wi-Fi: 900 MHz and sub-GHz telemetry, serial radios, remote I/O links.
   - *Record:* the frequencies, bandwidths and when each signal appears.
   - *Looks for:* [Discovery](../attack-ics/discovery.md) and, for an unexpected
     inbound radio path, [Initial Access](../attack-ics/initial-access.md),
     Wireless Compromise (T0860).

4. **Correlate against the inventory.** Match every transmitter to a known device.
   - *Go/no-go:* a transmitter near the process that the inventory does not
     explain is a finding to report, not a reason to transmit at it.

5. **Capture signals of interest.** Record the raw signal or Wi-Fi frames for
   anything notable, and hash the captures into the case `SHA256SUMS`.

6. **Do not transmit by default.** Deauthentication, injection or an active probe
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
- [Rules of engagement](../rules-of-engagement.md): the radio receive-first and transmit rules.
