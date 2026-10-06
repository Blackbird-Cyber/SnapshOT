---
title: GNU Radio Companion
summary: Graphical tool for creating signal flow graphs and generating flow-graph source code with the GNU Radio framework
folder: wireless
launchers: [gnuradio-grc.desktop]
ships_as: upstream-gui
package: gnuradio
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  identification: Build a receive flow graph to demodulate and decode a signal found in a survey, turning raw RF into something readable.
  lessons-learned: Keep the flow graph that decoded a signal with the case, so the analysis is reproducible.
csf: [identify, detect]
attack_ics: []
attack_role: none
protocols: [rf]
upstream: https://wiki.gnuradio.org/
---

<!-- snapshot:facts -->

## What it is

GNU Radio is a framework for building software radios out of signal-processing
blocks, and GNU Radio Companion (GRC) is its graphical editor: you wire blocks
(a source, filters, a demodulator, a sink) into a flow graph and GRC generates
and runs the Python program for it. With an SDR source block it processes live
RF from a dongle or HackRF; with a file source it processes recorded I/Q. It is
the tool for turning a raw signal into something decoded, when a ready-made
receiver does not exist for it.

## Why it is on SnapshOT

A spectrum survey finds that something is transmitting; GNU Radio is how you work
out what. For an unusual industrial wireless link, custom telemetry or a protocol
with no off-the-shelf decoder, a responder can build a receive chain in GRC to
demodulate and inspect it. It is the general-purpose signal-processing layer
behind the single-purpose SDR tools, used when they are not enough.

## On the wire

!!! danger "Writes: a flow graph can drive a transmit-capable SDR"

    GNU Radio itself is software, but a flow graph with a sink block and a
    transmit-capable SDR (such as a HackRF) radiates.

    - On SnapshOT, build **receive** flow graphs: a source block and processing,
      ending in a display or a file sink. Do not build or run transmit flow
      graphs near a production OT environment.
    - **Transmitting is a legal question before it is a technical one.** Radio
      law varies by country and band. Transmit only where it is lawful for the
      band and named in the written authorization, and treat it as a write: the
      engineer for any wireless equipment that could be affected present,
      inside the agreed window, the site's monitoring told first, and the action
      recorded (see the [rules of engagement](../../lifecycle/rules-of-engagement.md)).
      Stop at once if a wireless device drops off or operators report a lost
      link.
    - Prefer a file source (recorded I/Q from [rtl-sdr](rtl-sdr.md) or
      [HackRF](hackrf.md)) for analysis: it is repeatable, touches no radio at
      all, and nothing it does is visible to the site's monitoring.
    - An SDR source block reaches the hardware through
      [gr-osmosdr](gr-osmosdr.md)'s Osmocom Source. GNU Radio's own Soapy blocks
      are installed too, but find no device on this image (see
      [SoapySDR](soapysdr.md)). The device permissions are the SDR's (the
      `plugdev` group), so no `sudo` is needed.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), build a
receive flow graph to demodulate a signal a
[wireless survey](../../lifecycle/playbooks/wireless-survey.md) found: a source
(file or SDR),
the filters and demodulator for its modulation, and a sink that shows or records
the result. This turns raw RF into a bitstream or audio you can interpret.

### Lessons Learned

In [lessons learned](../../lifecycle/phases/lessons-learned.md), save the flow
graph that decoded a signal with the case, alongside the recorded I/Q it was
built against, so the decoding can be reproduced and explained in the report.
Because a file-source graph needs no radio, anyone can rerun it later on the
same samples and get the same result, which is what makes it evidence rather
than an observation.

## MITRE ATT&CK for ICS mapping

GNU Radio is a general signal-processing framework and does not map to a specific
ATT&CK for ICS technique on its own; the radio tactics belong to the SDR hardware
and the survey tools. Used as intended on SnapshOT, to decode a recorded or
received signal, it produces no traffic and is an analysis step, so its role is
recorded as none.

## Quick start

GNU Radio Companion is a GUI; the menu launcher opens the flow-graph editor.

```sh
# What the menu launcher runs (opens the flow-graph editor)
gnuradio-companion
# Compile a saved flow graph to a Python program without the GUI
grcc ~/cases/site-a/rf/decode.grc -o ~/cases/site-a/rf
# Show the build configuration (enabled components, install prefix)
gnuradio-config-info --print-all
```

A first flow graph, looking at a recording rather than the air: a `.cfile` of
complex samples recorded with `osmocom_fft -r` ([gr-osmosdr](gr-osmosdr.md)) or
by Gqrx's I/Q tool, whose file name carries the sample rate and centre
frequency.

1. **Start a flow graph.** Open GNU Radio Companion from 05 Wireless & SDR. A
   new flow graph already holds an **Options** block and a `samp_rate`
   **Variable** block. Double-click Options (any block opens its
   **Properties** this way) and set its Id, for example `look_433`: it names
   the generated program.
2. **Set the sample rate.** Double-click `samp_rate` and set it to the
   recording's sample rate, for example `2048000`.
3. **Add the blocks.** Press Ctrl+F (**Find Blocks**), type part of a block's
   name and drag it onto the canvas. Add a **File Source** (File: the
   recording; Output Type: complex; Repeat: No), a **Throttle** (Sample Rate:
   `samp_rate`; it stops a file from being read flat out), a **QT GUI
   Frequency Sink** and a **QT GUI Waterfall Sink** (Center Frequency (Hz): the
   recording's centre frequency; Bandwidth (Hz): `samp_rate`).
4. **Connect them.** Click an output port, then an input port: File Source to
   Throttle, then Throttle to each sink. A block drawn in red still has an
   error; its Properties say what.
5. **Save, generate and run.** **File > Save As** into `~/cases/site-a/rf/`.
   **Run > Generate** (F5) writes the Python program next to the `.grc` file,
   **Run > Execute** (F6) runs it and opens the spectrum and waterfall windows,
   and **Run > Kill** (F7) stops it.
6. **Go further.** To hear or decode an FM signal, put a **Low Pass Filter**
   and a **Quadrature Demod** between the Throttle and a sink; to keep the
   processed samples, end the chain in a **File Sink** in the case folder.

To receive live instead, replace the File Source and the Throttle with an
**osmocom Source** (Device Arguments: `rtl=0` or `hackrf=0`, plus its sample
rate and frequency). Never add an osmocom Sink: a sink transmits.

## Output and evidence

GRC saves flow graphs as `.grc` files and generates `.py` programs; a File Sink
writes the processed samples. Keep all of these in the case folder and hash them:

```sh
CASE=~/cases/site-a
sha256sum "$CASE"/rf/decode.grc "$CASE"/rf/*.iq >> "$CASE/SHA256SUMS"
```

## Related tools

- [Gqrx](gqrx.md): a ready-made receiver to find and tune a signal before you
  build a flow graph for it.
- [rtl-sdr](rtl-sdr.md) and [HackRF](hackrf.md): record the I/Q a file-source
  flow graph then processes.
- [gr-osmosdr](gr-osmosdr.md) and [SoapySDR](soapysdr.md): the blocks and library
  a flow graph uses to reach the SDR hardware.

## Upstream documentation

- [GNU Radio wiki](https://wiki.gnuradio.org/): the blocks, GRC and tutorials.
