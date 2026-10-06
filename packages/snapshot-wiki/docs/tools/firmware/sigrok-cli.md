---
title: sigrok-cli
summary: Logic analyzer CLI (sigrok)
folder: firmware
launchers: [snapshot-sigrok-cli.desktop]
ships_as: apt
package: sigrok-cli
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  identification: Capture a device's serial, SPI, I2C or JTAG lines on the bench and decode them to understand how it works and what it exposes.
  eradication: Watch a boot sequence read firmware from a SPI flash, or confirm a debug bus, while the device under analysis is on the bench.
csf: [identify, detect]
attack_ics: [persistence, inhibit-response-function, impair-process-control]
attack_role: investigates
attack_techniques: [T1693]
protocols: [serial, spi, i2c, jtag]
upstream: https://sigrok.org/wiki/Sigrok-cli
---

<!-- snapshot:facts -->

## What it is

sigrok-cli is the command-line front end for sigrok, an open logic-analyzer and
oscilloscope framework. With a supported logic analyzer (the generic `fx2lafw`
driver covers the common FX2-based clones), it samples a set of digital channels
at a chosen rate for a set time or number of samples, saves the capture as a
sigrok `.sr` file, and runs protocol decoders over it. Its decoders include
UART, SPI, SPI flash, I2C, 1-Wire, CAN, JTAG, SWD and Modbus RTU, and decoders
stack, so a UART capture can feed the Modbus decoder. Captures and decoded
annotations export as text, CSV or VCD.

## Why it is on SnapshOT

Below the network and the firmware image is the physical bus. On the bench, a
logic analyzer shows what a controller's UART console, its SPI flash, an I2C
EEPROM or a JTAG header is actually doing: the baud rate of an unmarked serial
header, the chip-select and clock of a flash read, the bytes on an I2C sensor
bus. That is how you find the pinout and parameters the other firmware tools
need, and how you confirm what a device exposes. sigrok-cli does it from a
terminal and writes a file you can keep; [PulseView](pulseview.md) is the same
capture in a GUI.

## On the wire

!!! note "Passive: it never transmits"

    A logic analyzer listens to voltage levels on wires; it does not drive the
    bus. The risk is physical, to the device and to the probe, not network
    traffic.

    - Match the analyzer's input voltage to the target. Many logic analyzers are
      5 V tolerant, but clipping a 5 V probe onto a 1.8 V or 3.3 V line, or
      getting a ground wrong, can disturb or damage the device under test.
    - This is bench work on hardware the engineer has released from service.
      Probing the buses of a running, in-service controller risks the process;
      see the [rules of engagement](../../lifecycle/rules-of-engagement.md).
    - The analyzers run as your own user through the udev rules the image ships
      (group `plugdev`); no `sudo` is needed.
    - A capture of a SPI or UART bus can contain firmware, keys and credentials
      in the clear. Treat the `.sr` file as evidence and hash it.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), when a device
has been released to the bench, sigrok-cli reads its buses to answer concrete
questions: what baud rate is the console header, which pins are a SPI flash,
what is on the I2C bus. Decoding a short capture turns an unknown header into a
known interface for [minicom](minicom.md), [flashrom](flashrom.md) or
[OpenOCD](openocd.md).

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), a logic capture of the
boot sequence can show the processor reading its firmware from a SPI flash,
which both confirms where the firmware lives and gives a second, independent view
of what was read. It supports, rather than replaces, a direct dump with
[flashrom](flashrom.md) or [OpenOCD](openocd.md).

## MITRE ATT&CK for ICS mapping

sigrok-cli *investigates* Modify Firmware (T1693) and the three tactics it
serves. A bus capture of a boot sequence shows the processor reading its
firmware from a SPI flash, so it tells you where the firmware lives and gives a
second, independent copy of what was read; that copy can be compared with the
known-good image when a modified image is suspected of providing
[Persistence](../../lifecycle/attack-ics/persistence.md). A capture also shows
whether the device boots and talks normally on its buses, which helps explain a
controller whose protection role has stopped
([Inhibit Response Function](../../lifecycle/attack-ics/inhibit-response-function.md))
or whose outputs behave differently
([Impair Process Control](../../lifecycle/attack-ics/impair-process-control.md))
after a suspected firmware change. sigrok-cli changes nothing on the device; it
reveals how the device works so the other firmware tools can be used safely.

## Quick start

```sh
# What the menu launcher runs
sigrok-cli --help
# List drivers, decoders and output formats the image has
sigrok-cli -L
# Find a connected logic analyzer
sigrok-cli --scan
# Capture 8 channels of an FX2-based analyzer at 4 MHz for 1 second to a file
sigrok-cli -d fx2lafw -c samplerate=4m -C D0,D1,D2,D3,D4,D5,D6,D7 \
    --time 1000 -o bus.sr
# Decode a UART console on channel 0 at 115200 baud from the capture
sigrok-cli -i bus.sr -P uart:rx=D0:baudrate=115200 -A uart=rx-data
# Decode a SPI flash: clk, miso, mosi, cs on four channels
sigrok-cli -i bus.sr -P spi:clk=D0:miso=D1:mosi=D2:cs=D3,spiflash
# Decode Modbus RTU stacked on a UART line
sigrok-cli -i bus.sr -P uart:rx=D0:baudrate=9600,modbus -A modbus
# Export the raw samples as CSV for a spreadsheet or timeline
sigrok-cli -i bus.sr -O csv -o bus.csv
```

Channel names (`D0`, `D1`...) depend on the analyzer; with it attached,
`sigrok-cli --show -d fx2lafw` lists them. `-C` takes the names as a comma
list: a range such as `D0-D7` is rejected ("Invalid channel"), because ranges
only work with numeric channel names. `sigrok-cli -P uart --show` (or any
other decoder id) lists a decoder's channels, options and annotation classes.
Decoders take their channel assignments and options as `key=value` after the
decoder id, and a comma stacks one decoder on another.

## Output and evidence

Save the capture into the case folder and hash it; it is the raw evidence the
decoded output comes from:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/firmware/logic"
S=$(date -u +%Y%m%dT%H%M%SZ)
L="$CASE/firmware/logic"
sigrok-cli -d fx2lafw -c samplerate=4m -C D0,D1,D2,D3,D4,D5,D6,D7 \
    --time 1000 -o "$L/rtu7-bus-$S.sr"
# Decode the console from the saved capture and keep the text beside it
sigrok-cli -i "$L/rtu7-bus-$S.sr" -P uart:rx=D0:baudrate=115200 \
    -A uart=rx-data | tee "$L/rtu7-uart-$S.txt"
sha256sum "$L/rtu7-bus-$S.sr" "$L/rtu7-uart-$S.txt" >> "$CASE/SHA256SUMS"
```

## Related tools

- [PulseView](pulseview.md): the same captures and decoders in a GUI, with the
  waveform on screen.
- [minicom](minicom.md), [picocom](picocom.md) and [tio](tio.md): open the serial
  console once the logic capture has found its baud rate and pinout.
- [flashrom](flashrom.md) and [OpenOCD](openocd.md): read the firmware once the
  SPI or JTAG pinout is confirmed.

## Upstream documentation

- [sigrok-cli manual](https://sigrok.org/wiki/Sigrok-cli): options, capture and
  decoding.
- [libsigrok protocol decoders](https://sigrok.org/wiki/Protocol_decoders): every
  decoder and its channels and options.
