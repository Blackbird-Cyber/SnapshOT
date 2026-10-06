---
title: Gqrx
summary: Software defined radio receiver implemented using GNU Radio and the Qt GUI toolkit
folder: wireless
launchers: [dk.gqrx.gqrx.desktop]
ships_as: upstream-gui
package: gqrx-sdr
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  identification: Watch a live waterfall to find, tune and listen to a signal near OT equipment, and record its I/Q for later analysis.
  lessons-learned: Play back the recorded I/Q of a signal of interest to show the finding in the debrief, and update the radio baseline.
csf: [identify, detect]
attack_ics: [discovery, collection]
attack_role: resembles
attack_techniques: [T0887]
protocols: [rf]
upstream: https://gqrx.dk/
---

<!-- snapshot:facts -->

## What it is

Gqrx is a graphical SDR receiver built on GNU Radio. It shows a live spectrum and
waterfall for the band you tune to, lets you click a signal to centre and
demodulate it (AM, FM, SSB and more), plays the audio, and records either the
demodulated audio or the raw I/Q to a file; its I/Q tool also plays a recording
back through the same display. It is receive-only. It drives the RTL-SDR
dongles, the HackRF and other SDRs through [gr-osmosdr](gr-osmosdr.md), and it
keeps its settings (device, frequency, demodulator) in a configuration file
under `~/.config/gqrx/`.

## Why it is on SnapshOT

A command-line sweep tells you energy is present in a band; Gqrx lets you look at
it. For a responder, the waterfall is the fastest way to find a transmitter,
judge its bandwidth and modulation by eye, and confirm whether it is voice,
telemetry or a data link, before deciding whether it matters. It turns the raw RF
near a site into something a person can see and hear, and record as evidence.
It sits between the command-line sweeps of [rtl-sdr](rtl-sdr.md) and
[HackRF](hackrf.md), which say where to look, and
[GNU Radio](gnuradio.md), which decodes what Gqrx found.

## On the wire

!!! note "Passive: it only receives"

    Gqrx is a receiver; it never transmits, even when the attached SDR is a
    HackRF. Nothing reaches the plant and the site's monitoring sees nothing.

    - Listening is passive, but what you may lawfully receive, record and
      disclose is regulated in some jurisdictions (the content of private or
      licensed communications in particular); stay within the rules of
      engagement, and record voice or data content only when the authorization
      covers it.
    - The SDR is reached over USB through the `plugdev` group, which the SnapshOT
      user is in, so no `sudo` is needed. Gqrx asks which device to use on
      startup; pick the attached dongle or HackRF.
    - The waterfall shows energy and modulation, not meaning. Use it to find and
      characterise a signal; decoding a data protocol is a job for
      [GNU Radio](gnuradio.md) or a dedicated decoder.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), and in the
[wireless survey](../../lifecycle/playbooks/wireless-survey.md) playbook, tune
Gqrx to a band that a sweep flagged, find the signal on the waterfall, and
demodulate it to judge what it is: a continuous telemetry carrier, a bursty data
link, a voice channel. Watch when it transmits as well as where: a burst every
few seconds is typical of polled telemetry, a carrier that appears only at night
is worth asking about. Record its I/Q if it needs closer analysis, and note its
frequency, bandwidth and timing for the site's radio owner.

### Lessons Learned

In [lessons learned](../../lifecycle/phases/lessons-learned.md), play the
recorded I/Q back through Gqrx's I/Q tool to show the debrief exactly what was
found, with the same waterfall the team saw on site. Fold the explained
transmitters into the site's radio inventory, so that the next survey's baseline
includes them and only the unexplained ones stand out.

## MITRE ATT&CK for ICS mapping

Gqrx *resembles* two tactics. Tuning, demodulating and recording a signal is
Wireless Sniffing (T0887), which MITRE lists under both
[Discovery](../../lifecycle/attack-ics/discovery.md) and
[Collection](../../lifecycle/attack-ics/collection.md):

- **Discovery.** The waterfall shows an adversary which links a site uses, how
  wide they are, how they are modulated and when they talk.
- **Collection.** A demodulated or recorded unencrypted link yields the
  telemetry, commands or voice traffic it carries.

Because it only receives, neither an adversary's listening nor yours shows up in
the site's monitoring; announce the work anyway so it is on record. For the
responder, the recordings are evidence of exposure: what an adversary in range
could have learned and captured from the site's radio links.

## Quick start

```sh
# What the menu launcher runs (opens the receiver window)
gqrx
# List the saved configurations in ~/.config/gqrx
gqrx --list
# Start with one of them by name, for example a per-site receiver setup
gqrx --conf site-a.conf
# Open the device settings of the configuration before starting
gqrx --edit
```

In the window: pick the SDR device on first run, set the centre frequency and
sample rate, start the receiver, then click a signal on the waterfall to tune it.
The recording controls save demodulated audio (WAV) or raw I/Q; the DSP settings
choose the demodulator and bandwidth.

## Output and evidence

Gqrx saves audio and I/Q recordings to the paths you set in its recording
controls. Put them in the case folder and hash them:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/rf"
# After recording into $CASE/rf from the GUI, keep the receiver settings too
cp ~/.config/gqrx/default.conf "$CASE/rf/gqrx-$(date -u +%Y%m%dT%H%M%SZ).conf"
sha256sum "$CASE"/rf/gqrx_* "$CASE"/rf/gqrx-*.conf >> "$CASE/SHA256SUMS"
```

Gqrx names its recordings `gqrx_<UTC date>_<UTC time>_<frequency>...`, and an
I/Q file name also carries the sample rate, which a raw file needs to be read
again; choosing the SigMF format instead writes that metadata to a
`.sigmf-meta` file beside the samples. Note the demodulator, antenna and
position in the case notes; the copied configuration records the rest.

## Related tools

- [rtl-sdr](rtl-sdr.md) and [HackRF](hackrf.md): the dongles and wideband SDR
  Gqrx receives through, and their command-line sweeps that point you at a band.
- [GNU Radio Companion](gnuradio.md): build a decoder for a signal Gqrx found.
- [gr-osmosdr](gr-osmosdr.md) and [SoapySDR](soapysdr.md): the device layers Gqrx
  uses to reach the hardware.

## Upstream documentation

- [Gqrx site](https://gqrx.dk/): the receiver, supported hardware and recording.
