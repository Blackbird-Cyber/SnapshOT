---
title: HackRF
summary: Show HackRF device info
folder: wireless
launchers: [snapshot-hackrf.desktop]
ships_as: apt
package: hackrf
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  preparation: Confirm a HackRF works and record a baseline wideband sweep of the bands around a site.
  identification: Sweep from 1 MHz to 6 GHz for transmitters and wireless links near OT equipment that a narrower receiver would miss.
csf: [identify, detect]
attack_ics: [discovery, collection]
attack_role: resembles
attack_techniques: [T0887]
protocols: [rf]
upstream: https://hackrf.readthedocs.io/
---

<!-- snapshot:facts -->

## What it is

HackRF One is a wideband software-defined radio that tunes from 1 MHz to 6 GHz.
The command-line tools are `hackrf_info` (identify the attached board),
`hackrf_sweep` (sweep a wide frequency range and log power per bin), and
`hackrf_transfer` (receive raw I/Q to a file, or transmit a file). Its range is
much wider than an RTL-SDR dongle, which lets it reach the higher bands used by
some industrial wireless and backhaul links. Unlike the RTL dongles, HackRF can
transmit, so it is a half-duplex transceiver, not a receive-only device.

## Why it is on SnapshOT

HackRF extends the radio survey to the bands an RTL-SDR cannot reach, up to
6 GHz, so a responder can map transmitters and wireless links across the whole
range an OT site might use in one tool. Its fast wideband sweep is well suited to
asking "what is transmitting anywhere around this plant", and its wide receive
range makes it the SDR to reach for when a signal of interest is above the RTL
dongle's ceiling. [Gqrx](gqrx.md) and [GNU Radio](gnuradio.md) drive it too, to
look at and decode a signal its sweep found.

## On the wire

!!! danger "Writes: it can transmit"

    HackRF is a transceiver. Receiving is passive; transmitting puts energy on
    the air.

    - On SnapshOT, keep to the **receive and sweep** tools: `hackrf_info`,
      `hackrf_sweep`, and `hackrf_transfer -r` (receive). Do not transmit
      (`hackrf_transfer -t`) near a production OT environment: radiating in a band
      a wireless control or telemetry link uses can interfere with a live
      process.
    - **Transmitting is a legal question before it is a technical one.** Radio
      law varies by country and band, and some bands must never be touched.
      Transmit only where it is lawful for the band and named in the written
      authorization, and treat it as a write: the engineer for any wireless
      equipment that could be affected present, inside the agreed window, the
      site's monitoring told first, and the action recorded (see the
      [rules of engagement](../../lifecycle/rules-of-engagement.md)). Never
      transmit where it could reach operating equipment.
    - Receiving is invisible to the site's monitoring; a transmission is not.
      Stop at once if a wireless device drops off or operators report a lost
      link.
    - The board is reached over USB through the `plugdev` group (a udev rule sets
      the device group to `plugdev`), and the SnapshOT user is in `plugdev`, so no
      `sudo` is needed.
    - As with any SDR sweep, a hit shows energy in a band, not content; follow it
      up, do not treat it as an identification.

## PICERL mapping

### Preparation

In [preparation](../../lifecycle/phases/preparation.md), confirm the board with
`hackrf_info` and record a baseline wideband sweep of the bands the site's radio
inventory lists, from a fixed, noted position, so the normal radio environment
across the full range is known before the engagement. Keep the receive gains you
used with the baseline; a later sweep is only comparable at the same settings.

### Identification

Sweep for transmitters and wireless links near the OT equipment during
[identification](../../lifecycle/phases/identification.md) and the
[wireless survey](../../lifecycle/playbooks/wireless-survey.md) playbook,
including the higher bands an RTL-SDR cannot see, and compare with the baseline.
A new carrier close to a controller, or a link in an unexpected band, is what to
follow up with the site's radio owner: record a short I/Q sample of it, and look
at it in [Gqrx](gqrx.md). A transmitter nobody can account for is a finding to
report, not a reason to transmit.

## MITRE ATT&CK for ICS mapping

HackRF *resembles* two tactics. Kept to receiving, as it is on an engagement,
its sweeps and recordings are Wireless Sniffing (T0887), which MITRE lists under
both [Discovery](../../lifecycle/attack-ics/discovery.md) and
[Collection](../../lifecycle/attack-ics/collection.md):

- **Discovery.** A wideband sweep is how an adversary finds the radio links an
  installation relies on, across the whole range up to 6 GHz, before choosing
  which to target.
- **Collection.** An I/Q recording of an unencrypted link captures the process
  data it carries, to be decoded later.

Receiving cannot be seen by the site's monitoring, whoever does it; announce the
survey anyway so it is on record. What HackRF gives the responder is the
exposure: its CSV sweeps and recordings document which links an adversary in
range could have found and captured. Its ability to transmit is why it is in the
writes class and why that side is reserved for lawful, authorised work.

## Quick start

All examples receive only.

```sh
# What the menu launcher runs (identify the attached board)
hackrf_info
# Wide sweep from 400 to 470 MHz, one pass, to a file
hackrf_sweep -f 400:470 -1 -r ~/cases/site-a/rf/uhf-sweep.csv
# The 2.4 GHz band, sweeping continuously to a file (Ctrl+C to stop)
hackrf_sweep -f 2400:2500 -r ~/cases/site-a/rf/ism24.csv
# Receive raw I/Q around a carrier for later analysis
hackrf_transfer -r ~/cases/site-a/rf/868M.iq -f 868000000 -s 8000000 -n 40000000
```

`hackrf_sweep`'s CSV has a date, time, frequency range, bin width and the power
of each bin; load it into a spreadsheet or plot it to see where the energy is.
`-l` (LNA) and `-g` (VGA) set the receive gains.

## Output and evidence

HackRF writes CSV sweeps and raw I/Q files. Keep them in the case folder and hash
them:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/rf"
hackrf_sweep -f 400:470 -1 -r "$CASE/rf/uhf-sweep.csv"
sha256sum "$CASE"/rf/* >> "$CASE/SHA256SUMS"
```

Raw I/Q at a wide sample rate is large; capture only the spans you need and note
the centre frequency and sample rate.

## Related tools

- [rtl-sdr](rtl-sdr.md): a cheaper receive-only dongle for the bands within its
  range; reach for HackRF when a signal is higher or wider.
- [gqrx](gqrx.md): a live waterfall for the HackRF, to find and tune a signal by
  eye.
- [GNU Radio Companion](gnuradio.md): decode a signal from the I/Q that
  `hackrf_transfer -r` recorded.
- [gr-osmosdr](gr-osmosdr.md) and [SoapySDR](soapysdr.md): how GNU Radio reaches
  the HackRF.

## Upstream documentation

- [HackRF documentation](https://hackrf.readthedocs.io/): the tools, the sweep
  format and the hardware.
