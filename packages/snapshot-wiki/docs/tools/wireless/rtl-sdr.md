---
title: rtl-sdr
summary: Find an RTL-SDR dongle and read its identity, and sweep the radio spectrum to CSV (receive only)
folder: wireless
launchers: [snapshot-rtl-sdr.desktop, snapshot-rtl-power.desktop]
ships_as: apt
package: rtl-sdr
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Check an RTL-SDR dongle works and record a baseline sweep of the RF bands around a site.
  identification: Sweep the spectrum for wireless links, telemetry and transmitters near OT equipment and compare with the baseline.
csf: [identify, detect]
attack_ics: [discovery, collection]
attack_role: resembles
attack_techniques: [T0887]
protocols: [rf]
upstream: https://osmocom.org/projects/rtl-sdr/wiki
---

<!-- snapshot:facts -->

## What it is

rtl-sdr is the command-line toolset for the low-cost RTL2832U software-defined
radio dongles. `rtl_eeprom` finds a dongle and reads its tuner and EEPROM
identity; `rtl_test` reports its gains and measures its clock error;
`rtl_power` sweeps a frequency range and logs the power in each bin to CSV,
which makes a spectrum survey; `rtl_sdr` records raw I/Q samples to a file;
`rtl_fm` demodulates narrowband signals. The dongles are
receive-only: they cannot transmit. Their usable range is roughly 24 MHz to
1.7 GHz depending on the tuner, and they see about 2 MHz of spectrum at a time,
which is why `rtl_power` steps across a wide band in hops.

## Why it is on SnapshOT

A great deal of OT telemetry and control travels by radio: wireless sensors,
licensed point-to-point links, remote SCADA over UHF, and the usual Wi-Fi and
Bluetooth. An RTL-SDR dongle is the cheapest way to see whether something is
transmitting in a band and roughly where, so a responder can map the radio attack
surface around a site and spot a transmitter that should not be there. Because the
dongle cannot transmit, it is the safe first look at the spectrum, and its
command-line tools write CSV and I/Q files that go straight into the case folder.
The menu has two entries for it in 05 Wireless & SDR, which is receive-only: the
**rtl-sdr (dongle check)**, which runs `rtl_eeprom`, and **rtl_power (RF
spectrum sweep)**. To look at and listen to a signal, use [Gqrx](gqrx.md); for
Wi-Fi, which is above the dongle's range, use [airodump-ng](airodump-ng.md).

## On the wire

!!! note "Passive: it can only receive"

    RTL-SDR dongles have no transmitter. Everything here listens, so nothing
    reaches the plant and the site's monitoring sees nothing.

    - Listening across the radio spectrum is passive, but what you may lawfully
      receive, record and disclose is still regulated in some jurisdictions
      (the content of private or licensed communications in particular). Keep
      the survey within the rules of engagement and record frequencies and
      power, not content, unless the authorization covers it.
    - The dongle is reached over USB through the `plugdev` group (the
      `librtlsdr0` udev rule sets the device group to `plugdev`), and the
      SnapshOT user is in `plugdev`, so no `sudo` is needed. If the kernel's
      DVB-T driver has claimed the dongle, the SDR tools say so; the image does
      not blacklist it, and `sudo rmmod dvb_usb_rtl28xxu` frees the dongle for
      the session.
    - A sweep only shows energy in a band, not content. Treat a hit as
      "something is transmitting here", to be followed up, not as an
      identification.

## PICERL mapping

### Preparation

In [preparation](../../lifecycle/phases/preparation.md), check each dongle with
the menu's dongle check (`rtl_eeprom`, which names the tuner and the serial
number) and measure its clock error with `rtl_test -p`, so later frequencies can
be corrected with `-p`. Then record a baseline sweep of the bands the site's
radio inventory lists (licensed telemetry, ISM, the plant's private radio) from
a fixed, noted position, so the normal radio environment is known before
anything goes wrong.

### Identification

During [identification](../../lifecycle/phases/identification.md), and in the
[wireless survey](../../lifecycle/playbooks/wireless-survey.md) playbook, sweep
the spectrum near the OT equipment and compare it with the baseline: a new
carrier in a band that should be quiet, a transmitter close to a controller,
continuous telemetry where there should be none. Narrow down with a finer sweep,
record a short I/Q sample of anything unexplained, and hand the finding to
whoever owns the site's radio. A transmitter nobody can account for is a finding
to report, not a reason to start transmitting at it.

## MITRE ATT&CK for ICS mapping

rtl-sdr *resembles* two tactics. Receiving and recording what transmits around a
site is Wireless Sniffing (T0887), which MITRE lists under both
[Discovery](../../lifecycle/attack-ics/discovery.md) and
[Collection](../../lifecycle/attack-ics/collection.md):

- **Discovery.** A sweep is how an adversary finds the radio links an
  installation relies on (their bands, timing and rough location) before
  choosing which to target.
- **Collection.** An I/Q recording of an unencrypted telemetry or control link
  captures the process data it carries, which an adversary can decode at
  leisure.

Because it only receives, neither an adversary's sniffing nor yours can be seen
by the site's monitoring; announce the survey anyway, so that it is on record.
What rtl-sdr gives the responder is the exposure: the CSV sweeps and recordings
document which links an adversary in range could have found and captured. An
unexplained transmitter near the process may also be a rogue device or bridge,
which the [wireless survey](../../lifecycle/playbooks/wireless-survey.md)
playbook follows up as possible Wireless Compromise (T0860).

## Quick start

```sh
# What the dongle check launcher runs: find the dongle, name its tuner and read
# its EEPROM identity (vendor and product ids, manufacturer, product, serial);
# with no options rtl_eeprom only reads
rtl_eeprom
# What the rtl_power launcher runs: the sweep options and the CSV columns
rtl_power -h
# Measure the dongle's clock error in ppm (Ctrl+C to stop)
rtl_test -p
# Sweep the 433 MHz ISM band in 1 kHz bins, single shot, to CSV
rtl_power -f 433M:435M:1k -1 ~/cases/site-a/rf/ism433.csv
# Broad UHF survey, 1 MHz bins, integrated over five minutes, single shot
rtl_power -f 400M:470M:1M -i 5m -1 ~/cases/site-a/rf/uhf-survey.csv
# Log the 433 MHz band every 10 seconds for an hour (-e), compressed
rtl_power -f 433M:435M:1k -e 1h | gzip > ~/cases/site-a/rf/ism433-1h.csv.gz
# Record 10 seconds of raw I/Q around 433.92 MHz at 2.048 MS/s
rtl_sdr -f 433920000 -s 2048000 -n 20480000 ~/cases/site-a/rf/433920k-2048k.iq
```

`rtl_power` is the survey tool. `-f lower:upper:bin` sets the range and the bin
size (a maximum: it picks a convenient smaller bin), `-i` the integration
interval (10 seconds by default), `-1` a single sweep and `-e` a total run time;
without `-1` or `-e` it logs until Ctrl+C. `-g` sets a fixed tuner gain instead
of the automatic one, which keeps sweeps taken at different times comparable,
`-p` applies the clock correction, and `-c 20%` to `-c 50%` crops the noisy
edges of each hop when the bins are 1 MHz or smaller.

Each line of an `rtl_power` CSV covers one hop of the sweep for one integration
interval: the date, the time, the low and high frequency of that hop, the bin
width, the sample count and then the power of each bin in dB. Plot it or load it
into a spreadsheet to see where the energy is. Add `-p <ppm>` from the clock
measurement to correct the frequencies. To look at a signal and listen to it,
open it in [Gqrx](gqrx.md).

## Output and evidence

rtl-sdr writes CSV sweeps and raw I/Q files. Keep them in the case folder and
hash them:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/rf"
rtl_power -f 400M:470M:1M -i 5m -1 "$CASE/rf/uhf-survey-$(date -u +%Y%m%dT%H%M%SZ).csv"
sha256sum "$CASE"/rf/uhf-survey-*.csv >> "$CASE/SHA256SUMS"
```

Raw I/Q files are large (2 bytes per sample, so about 4 MB a second at
2.048 MS/s); record only the spans you need and put the center frequency and
sample rate in the file name, as above, since a raw `.iq` file does not carry
them. Note the dongle, antenna and position in the case notes.

## Related tools

- [Gqrx](gqrx.md): a live waterfall for the same dongles, to find and tune a
  signal by eye before recording it.
- [airodump-ng](airodump-ng.md): the Wi-Fi side of the same survey.

## Upstream documentation

- [rtl-sdr wiki](https://osmocom.org/projects/rtl-sdr/wiki): the tools, supported
  dongles and the direct-sampling modes.
