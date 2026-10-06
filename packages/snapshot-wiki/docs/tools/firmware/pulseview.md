---
title: PulseView
summary: Control your logic analyzer, oscilloscope, or MSO
folder: firmware
launchers: [org.sigrok.PulseView.desktop]
ships_as: upstream-gui
package: pulseview
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  identification: Capture a device's serial, SPI, I2C or JTAG lines on the bench and read the waveforms and decoded protocols on screen.
  eradication: Watch a boot sequence or a bus on the bench to confirm how a released device reads its firmware and what it exposes.
csf: [identify, detect]
attack_ics: [persistence, inhibit-response-function, impair-process-control]
attack_role: investigates
attack_techniques: [T1693]
protocols: [serial, spi, i2c, jtag]
upstream: https://sigrok.org/wiki/PulseView
---

<!-- snapshot:facts -->

## What it is

PulseView is the graphical front end for the sigrok logic-analyzer and
oscilloscope framework. It drives the same supported hardware as
[sigrok-cli](sigrok-cli.md) and runs the same protocol decoders, but shows the
captured channels as waveforms you can zoom, scroll and measure, with the decoded
protocol annotations drawn over the signal. It opens and saves sigrok `.sr`
captures, so a capture taken with sigrok-cli can be read in PulseView and the
other way round.

## Why it is on SnapshOT

Reading a bus is often easier by eye. When you are finding the baud rate of an
unmarked serial header, lining up the chip-select and clock of a SPI flash, or
checking an I2C bus, seeing the waveform and the decoded bytes together is faster
than re-running a command. PulseView is the interactive companion to sigrok-cli
for bench work on firmware and hardware; the two share captures and decoders.

## On the wire

!!! note "Passive: it never transmits"

    PulseView listens to voltage levels on wires through the logic analyzer; it
    does not drive the bus. The risk is physical, to the device and the probe.

    - Match the analyzer's input voltage to the target; a 5 V probe on a 1.8 V or
      3.3 V line, or a wrong ground, can disturb or damage the device under test.
    - This is bench work on hardware the engineer has released from service, not
      the buses of a running controller; see the
      [rules of engagement](../../lifecycle/rules-of-engagement.md).
    - The analyzers run as your own user through the udev rules the image ships
      (group `plugdev`); no `sudo` is needed.
    - A capture of a SPI or UART bus can hold firmware, keys and credentials in
      the clear. Save it into the case folder and hash it.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), PulseView
reads a released device's buses to find the console baud rate, the SPI flash
pins or the contents of an I2C bus, turning an unknown header into a known
interface for [minicom](minicom.md), [flashrom](flashrom.md) or
[OpenOCD](openocd.md). The waveform makes a wrong guess obvious at once.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), a capture of the boot
sequence can show the processor reading firmware from a SPI flash, confirming
where the firmware lives and giving a second view of what was read, alongside a
direct dump with [flashrom](flashrom.md) or [OpenOCD](openocd.md).

## MITRE ATT&CK for ICS mapping

PulseView *investigates* Modify Firmware (T1693), exactly as
[sigrok-cli](sigrok-cli.md) does. A bus capture of a boot sequence shows the
processor reading its firmware from a SPI flash: where the firmware lives, and a
second, independent copy of what was read to compare with the known-good image
when a modified image is suspected of providing
[Persistence](../../lifecycle/attack-ics/persistence.md). The waveforms also show
whether a device boots and drives its buses normally, which helps explain a
controller that stopped performing its protection role
([Inhibit Response Function](../../lifecycle/attack-ics/inhibit-response-function.md))
or whose outputs changed
([Impair Process Control](../../lifecycle/attack-ics/impair-process-control.md))
after a suspected firmware change. It changes nothing on the device; it reveals
how the device works.

## Quick start

PulseView is a GUI; the menu launcher opens the window. The usual flow:

```sh
# What the menu launcher runs
pulseview
# Open a capture saved by sigrok-cli straight away
pulseview -i bus.sr
# Use the named driver only, without scanning for every supported device
pulseview -D -d fx2lafw
```

In the window, pick the device, set the channels and sample rate, run a capture,
then add a decoder (for example UART or SPI) from the toolbar and set its
channels and options. Add the SPI flash or Modbus decoder on top to see the
higher-level protocol.

## Output and evidence

Save the capture as a `.sr` file into the case folder from PulseView's Save
dialog, then hash it like any other evidence:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/firmware/logic"
# After saving rtu7-bus-<UTC>.sr from PulseView into the folder above
sha256sum "$CASE"/firmware/logic/*.sr >> "$CASE/SHA256SUMS"
```

Export decoded annotations from PulseView, or re-run the decode with
[sigrok-cli](sigrok-cli.md) on the same `.sr` file for a text record.

## Related tools

- [sigrok-cli](sigrok-cli.md): the command-line form, sharing captures and
  decoders; use it to script a decode or record its text output.
- [minicom](minicom.md), [picocom](picocom.md) and [tio](tio.md): open the serial
  console once PulseView has found its baud rate.
- [flashrom](flashrom.md) and [OpenOCD](openocd.md): read the firmware once the
  SPI or JTAG pinout is confirmed.

## Upstream documentation

- [PulseView manual](https://sigrok.org/wiki/PulseView): the GUI, capture and
  decoding.
- [libsigrok protocol decoders](https://sigrok.org/wiki/Protocol_decoders): every
  decoder and its channels and options.
