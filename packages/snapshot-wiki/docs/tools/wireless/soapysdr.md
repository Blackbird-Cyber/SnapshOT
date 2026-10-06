---
title: SoapySDR
summary: Enumerate SDR devices
folder: wireless
launchers: [snapshot-soapysdr.desktop]
ships_as: apt
package: soapysdr-tools
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Confirm the SDR software stack is present and probe an attached device's capabilities before a survey.
csf: [identify]
attack_ics: []
attack_role: none
protocols: [rf]
upstream: https://github.com/pothosware/SoapySDR/wiki
---

<!-- snapshot:facts -->

## What it is

SoapySDR is a vendor-neutral abstraction layer for software-defined radios: one
API that other programs use to reach many kinds of SDR without knowing the
hardware details. The `soapysdr-tools` package provides `SoapySDRUtil`, a
command-line tool to list the SoapySDR modules installed, enumerate attached
devices and print a device's capabilities (sample rates, gains, antennas). It is
plumbing, not a receiver: it lets software find and describe an SDR, and leaves
receiving and transmitting to that software.

## Why it is on SnapshOT

SoapySDR is on the image because several SDR programs can use it: GNU Radio has
its own Soapy source and sink blocks, and gr-osmosdr can reach hardware through
it. `SoapySDRUtil` is a quick way to see what SDR support is installed, and on a
system with device modules it reads what a device can do (sample rates, gains,
antennas, sensors) before a survey. On this image its main job is the first of
those: it shows, in one command, that SoapySDR is present without device
modules, which tells you to drive the dongles through their native tools and
gr-osmosdr instead.

!!! note "Device modules on this image"

    SoapySDR finds hardware only through a per-device SoapySDR module (for
    example a SoapyRTLSDR or SoapyHackRF module). SnapshOT does not install those
    modules, so `SoapySDRUtil --find` reports no devices and `--probe` has nothing
    to probe; the tool still reports the library version and the sample-format
    converters it carries. On this image the SDRs are driven through their native
    tools ([rtl-sdr](rtl-sdr.md), [HackRF](hackrf.md)) and through
    [gr-osmosdr](gr-osmosdr.md) in GNU Radio, not through SoapySDR, so treat
    `SoapySDRUtil` as a status and reference tool rather than the way you reach a
    dongle.

## On the wire

!!! note "Passive: it enumerates, it does not transmit"

    `SoapySDRUtil` lists modules and devices and prints capabilities. It does not
    receive or transmit on its own.

    - Running it is safe and local; it touches the radio only to read a device's
      capabilities when a module is present, which on this image there is not.
      Nothing reaches the plant and the site's monitoring sees nothing.
    - Its rate test (`--rate` with `--direction=TX`) would stream samples to a
      transmit-capable device if a module for one were installed. With no
      modules on this image it cannot; if modules are ever added, that test is a
      transmission and falls under the radio rules in the
      [rules of engagement](../../lifecycle/rules-of-engagement.md).
    - Reaching an SDR over USB uses the `plugdev` group, which the SnapshOT user
      is in, so no `sudo` is needed.

## PICERL mapping

### Preparation

In [preparation](../../lifecycle/phases/preparation.md), before a
[wireless survey](../../lifecycle/playbooks/wireless-survey.md), run
`SoapySDRUtil` to see what the SDR software stack reports: the library version,
the module search path, the converters, and (where a module is installed) the
attached devices and their capabilities. On SnapshOT this confirms the stack is
present and that no device modules are, so a program configured for a Soapy
device will not find one. The devices themselves are then checked with their
native tools (`rtl_test`, `hackrf_info`) and driven through
[rtl-sdr](rtl-sdr.md), [HackRF](hackrf.md), [Gqrx](gqrx.md) or
[gr-osmosdr](gr-osmosdr.md) for the survey itself. Keep the `--info` output with
the case if the report needs to state which SDR software the survey used.

## MITRE ATT&CK for ICS mapping

SoapySDR is a device-abstraction and enumeration layer and does not map to an
ATT&CK for ICS technique. Listing modules and probing a device neither receives
the site's radio traffic nor transmits, so it is not Wireless Sniffing or
anything else an adversary does on a plant; the radio tactics belong to the
receivers that use it, such as [rtl-sdr](rtl-sdr.md) and [Gqrx](gqrx.md). It
produces no traffic, so its role is recorded as none.

## Quick start

```sh
# What the menu launcher runs (enumerate SDR devices)
SoapySDRUtil --find
# Library version, module search path and sample-format converters
SoapySDRUtil --info
# Probe an attached device's capabilities (needs a matching SoapySDR module)
SoapySDRUtil --probe
```

On this image `--find` reports no devices because no per-device SoapySDR module
is installed; `--info` still shows the library version and converters.

## Output and evidence

`SoapySDRUtil` prints to the terminal. If you record its output as part of
documenting the kit, keep it in the case folder:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/rf"
SoapySDRUtil --info > "$CASE/rf/soapysdr-info.txt"
sha256sum "$CASE/rf/soapysdr-info.txt" >> "$CASE/SHA256SUMS"
```

## Related tools

- [rtl-sdr](rtl-sdr.md) and [HackRF](hackrf.md): the native tools that actually
  drive the SDRs on this image.
- [gr-osmosdr](gr-osmosdr.md): the device layer GNU Radio and Gqrx use here
  instead of SoapySDR.
- [Gqrx](gqrx.md): the graphical receiver for the same hardware.

## Upstream documentation

- [SoapySDR wiki](https://github.com/pothosware/SoapySDR/wiki): the API, modules
  and `SoapySDRUtil`.
