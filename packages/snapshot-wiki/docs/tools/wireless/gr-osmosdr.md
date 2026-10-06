---
title: gr-osmosdr
summary: Osmocom SDR source and sink blocks for GNU Radio
folder: wireless
launchers: []
ships_as: apt
package: gr-osmosdr
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  preparation: Confirm an SDR is reachable from GNU Radio and view the live spectrum with osmocom_fft before building a receive chain.
  identification: Provide the source block that feeds a receive flow graph analysing a signal near OT equipment.
csf: [identify, detect]
attack_ics: [discovery, collection]
attack_role: resembles
attack_techniques: [T0887]
protocols: [rf]
upstream: https://osmocom.org/projects/gr-osmosdr/wiki
---

<!-- snapshot:facts -->

## What it is

gr-osmosdr is the Osmocom block set that connects GNU Radio to a wide range of
SDR hardware through one common source and sink block, covering the RTL-SDR
dongles, HackRF, and others. It is mostly used from inside
[GNU Radio](gnuradio.md), where its Osmocom Source block is how a flow graph
receives from the hardware, but it also ships two standalone programs:
`osmocom_fft`, a live spectrum (and, with `-W`, waterfall) display that can also
record I/Q to a file, and `osmocom_siggen_nogui`, a signal generator that drives
a transmit-capable SDR. It has no menu launcher; it is a library and two
helpers, reached from the terminal or from GRC.

## Why it is on SnapshOT

gr-osmosdr is the glue that lets one flow graph, or one spectrum viewer, work
with whichever SDR a responder has to hand, without rewriting it per device. On
SnapshOT it is what [GNU Radio Companion](gnuradio.md) and [Gqrx](gqrx.md) use to
reach the RTL-SDR dongles and the HackRF, and `osmocom_fft` is a quick way to
look at a band with any of them without building a flow graph. When
`osmocom_fft` opens on a device, the whole chain a flow graph will use
(hardware, driver, blocks) is known to work.

## On the wire

!!! danger "Writes: its sink block and signal generator can transmit"

    The Osmocom block set includes a sink (transmit) block, and
    `osmocom_siggen_nogui` transmits through a transmit-capable SDR such as a
    HackRF. On SnapshOT the package is used for receiving: `osmocom_fft` and
    source blocks in receive flow graphs.

    - Do not run the signal generator, or a flow graph that uses the Osmocom
      **sink** block, near a production OT environment.
    - **Transmitting is a legal question before it is a technical one.** Radio
      law varies by country and band. Transmit only where it is lawful for the
      band and named in the written authorization, and treat it as a write: the
      engineer for any wireless equipment that could be affected present,
      inside the agreed window, the site's monitoring told first, and the action
      recorded (see the [rules of engagement](../../lifecycle/rules-of-engagement.md)).
    - Receiving is invisible to the site's monitoring; a transmission is not.
      Stop at once if a wireless device drops off or operators report a lost
      link.
    - The SDR is reached over USB through the `plugdev` group, which the SnapshOT
      user is in, so no `sudo` is needed.
    - `osmocom_fft` shows energy and modulation, not content; use it to find and
      characterise a signal, and [GNU Radio](gnuradio.md) to decode one.

## PICERL mapping

### Preparation

In [preparation](../../lifecycle/phases/preparation.md), confirm each SDR is
reachable from GNU Radio before you rely on it: `osmocom_fft` opening on the
attached device, with a clean spectrum, proves the whole chain (hardware, driver,
blocks) works. Note the device argument that selects each one (`rtl=0`,
`hackrf=0`), so the flow graphs prepared for the engagement name the right
receiver.

### Identification

During [identification](../../lifecycle/phases/identification.md), the Osmocom
Source block is what feeds a receive flow graph built to analyse a signal found
in a [wireless survey](../../lifecycle/playbooks/wireless-survey.md), and
`osmocom_fft` is a fast way to look at the band the signal is in before building
that graph. Its `-r` option records the I/Q while you watch, so the samples the
flow graph is later built against are the ones you saw.

## MITRE ATT&CK for ICS mapping

gr-osmosdr, used to receive, *resembles* two tactics. `osmocom_fft` and the
source blocks receive and record what transmits around the OT environment, which
is Wireless Sniffing (T0887), listed by MITRE under both
[Discovery](../../lifecycle/attack-ics/discovery.md) (finding which radio links
a site relies on, and their bands and timing) and
[Collection](../../lifecycle/attack-ics/collection.md) (capturing the data an
unencrypted link carries, for decoding in a flow graph). Receiving produces no
traffic, so the site's monitoring cannot see it from anyone; announce it anyway.
For the responder, the value is the exposure it documents. The transmit side is
why the package is in the writes class, and it is reserved for lawful,
authorised work.

## Quick start

```sh
# Live spectrum from the first attached SDR (receive only)
osmocom_fft
# A named device, sample rate and centre frequency, with a waterfall
osmocom_fft -a rtl=0 -s 2048000 -f 433920000 -W
# The same on a HackRF, with a frequency correction in ppm
osmocom_fft -a hackrf=0 -s 8000000 -f 868000000 -c 2 -W
# Help for the signal generator: read it, do not run it on a site
osmocom_siggen_nogui --help
```

`osmocom_fft` takes the same device arguments (`rtl=0`, `hackrf=0`) that the
Osmocom Source block uses in GRC. Inside GNU Radio Companion, drop an Osmocom
Source block into a receive flow graph and set its device argument to match.

## Output and evidence

`osmocom_fft -r` records the I/Q it is showing to a file, and its name can carry
the sample rate (`%S`), centre frequency (`%F`) and a timestamp (`%T`), which a
raw recording needs to be read again. Record into the case folder and hash it:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/rf"
osmocom_fft -a rtl=0 -s 2048000 -f 433920000 -W \
    -r "$CASE/rf/osmo-f%F-s%S-t%T.cfile"
sha256sum "$CASE"/rf/osmo-*.cfile >> "$CASE/SHA256SUMS"
```

Recordings from the SDRs' own tools ([rtl-sdr](rtl-sdr.md), [HackRF](hackrf.md))
or a [GNU Radio](gnuradio.md) File Sink go in the same folder.

## Related tools

- [GNU Radio Companion](gnuradio.md): the editor whose flow graphs use the
  Osmocom Source block gr-osmosdr provides.
- [Gqrx](gqrx.md): a ready-made receiver that reaches the hardware the same way.
- [SoapySDR](soapysdr.md): the other device-abstraction layer on the image.

## Upstream documentation

- [gr-osmosdr wiki](https://osmocom.org/projects/gr-osmosdr/wiki): the blocks,
  device arguments and supported hardware.
