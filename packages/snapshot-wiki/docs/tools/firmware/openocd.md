---
title: OpenOCD
summary: On-chip debugger (JTAG/SWD)
folder: firmware
launchers: [snapshot-openocd.desktop]
ships_as: apt
package: openocd
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  eradication: Read a microcontroller's internal flash and memory over JTAG or SWD for comparison, and write a verified image back only when the engineer directs it.
  recovery: Read the flash back after a reflash and confirm its hash matches the known-good image before the device returns to service.
csf: [respond, recover]
attack_ics: [persistence, inhibit-response-function, impair-process-control]
attack_role: resembles
attack_techniques: [T1693, T1693.001, T1693.002]
protocols: [jtag]
upstream: https://openocd.org/doc/html/index.html
---

<!-- snapshot:facts -->

## What it is

OpenOCD (Open On-Chip Debugger) talks to the debug port of a microcontroller or
SoC over JTAG or SWD, through an adapter such as an ST-Link, a J-Link, a
CMSIS-DAP probe or an FTDI-based interface. It can halt and reset the CPU, read
and write memory and registers, and read, erase, verify and program the chip's
internal and attached flash. It is driven by a configuration file for the
adapter and one for the target, and it exposes a GDB server (port 3333 by
default), a Telnet command console (4444) and a Tcl interface (6666). Debian
ships a large library of interface and target configurations under
`/usr/share/openocd/scripts`.

## Why it is on SnapshOT

Many controllers, protection relays and smart sensors keep their firmware in the
microcontroller's own flash, reachable only through a debug header, not an
external SPI chip. OpenOCD is how that firmware is read for comparison with the
vendor's image, and how a verified image is written back during eradication. Like
[flashrom](flashrom.md), it is bench work on released hardware with a physical
connection, under the engineer's direction.

## On the wire

!!! danger "Writes: debug access can halt the CPU and overwrite firmware"

    A debug probe has full control of the target: it can stop the processor,
    read or change memory, and erase or reprogram flash.

    - **Bench work only, on hardware the engineer has released from service.**
      Halting or resetting a running controller through its debug port stops the
      process it controls. Never attach to a device that is in service. See the
      [rules of engagement](../../lifecycle/rules-of-engagement.md).
    - Confirm the adapter, the target voltage and the pinout before connecting;
      the wrong voltage on a debug header can damage the device.
    - Some devices have their debug port locked or set read-out protection;
      forcing it can mass-erase the chip. Expect this and do not fight a locked
      target on live evidence.
    - **Read first.** Dump the flash read-only, take a second read to confirm it
      is stable, and hash the dump as evidence before anything is written.
    - Write only in eradication or recovery, with the engineer present, with a
      verified known-good image, and verify by reading back.
    - OpenOCD opens local TCP ports (3333, 4444, 6666) for GDB, Telnet and Tcl
      while it runs; they are for the operator on the laptop, not for the
      network. Nothing goes onto the plant network, so the site's monitoring
      sees nothing; the notes, dumps and hashes are the record.
    - Stop if the target resets unexpectedly, reports a different ID from the
      one expected, or two reads differ; recheck the wiring before trying again.

## PICERL mapping

### Eradication

During [eradication](../../lifecycle/phases/eradication.md), and in the
[firmware acquisition](../../lifecycle/playbooks/firmware-acquisition.md)
playbook, OpenOCD reads the microcontroller's flash so it can be compared with
the known-good image in [binwalk](binwalk.md). If an implant is found and the
engineer decides to reflash, OpenOCD writes the verified image. The pre-reflash
dump is kept as evidence.

### Recovery

In [recovery](../../lifecycle/phases/recovery.md), after a reflash, OpenOCD reads
the flash back and the read-back is hashed and checked against the known-good
image. Only a byte-for-byte match confirms the write before the engineer returns
the device to service.

## MITRE ATT&CK for ICS mapping

OpenOCD *resembles* the firmware techniques it investigates: programming a chip's
flash over a debug port is Modify Firmware (T1693), in its Modify Firmware:
System Firmware (T1693.001) and Modify Firmware: Module Firmware (T1693.002)
forms. Modify Firmware serves three tactics, and an OpenOCD write looks like
each: [Persistence](../../lifecycle/attack-ics/persistence.md) (an implant in
the microcontroller's flash outlives a restart),
[Inhibit Response Function](../../lifecycle/attack-ics/inhibit-response-function.md)
(a halted or bricked controller cannot perform its protection role) and
[Impair Process Control](../../lifecycle/attack-ics/impair-process-control.md)
(changed firmware changes how the device drives the process). Debug access goes
further than a network write, because halting the CPU stops the process
outright. What separates a reflash in eradication from an attack is the
authorization, the engineer and the verified image. The pre-reflash dump is the
evidence of the firmware the adversary left on the device.

## Quick start

```sh
# What the menu launcher runs
openocd --help
# Start a session: pick the adapter and the target config, then halt
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg -c 'init' -c 'reset halt'
# Dump the whole internal flash bank 0 to a file, then exit
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg \
    -c 'init' -c 'reset halt' -c 'flash read_bank 0 rtu7-dump1.bin' -c 'shutdown'
# Verify the chip against a known-good image (reads only)
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg \
    -c 'init' -c 'reset halt' -c 'verify_image known-good.bin' -c 'shutdown'
# WRITE a verified image and verify it: eradication only, engineer present
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg \
    -c 'program known-good.bin verify reset exit'
# List the interface and target configs the image ships
ls /usr/share/openocd/scripts/interface /usr/share/openocd/scripts/target
```

Replace `interface/stlink.cfg` and `target/stm32f4x.cfg` with the adapter and the
target you have; the `scripts/` tree lists both. The supported adapters run as
your own user through the udev rules the image ships (group `plugdev`).

## Output and evidence

Dump to the case folder, confirm the read is stable and hash it before any write:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/firmware"
S=$(date -u +%Y%m%dT%H%M%SZ)
F="$CASE/firmware/rtu7-jtag-$S"
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg \
    -c 'init' -c 'reset halt' -c "flash read_bank 0 $F.bin" -c 'shutdown'
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg \
    -c 'init' -c 'reset halt' -c "flash read_bank 0 $F-b.bin" -c 'shutdown'
# The two reads must match before the dump is trusted
cmp "$F.bin" "$F-b.bin"
sha256sum "$F.bin" "$F-b.bin" >> "$CASE/SHA256SUMS"
```

Keep the first dump untouched as the pre-reflash reference and analyse a copy.

## Related tools

- [flashrom](flashrom.md): read and write firmware on an external SPI flash chip
  rather than through a debug port.
- [binwalk](binwalk.md): identify and extract the contents of a dump and compare
  it with the known-good image.
- [sigrok-cli](sigrok-cli.md) and [PulseView](pulseview.md): confirm a JTAG or
  SWD pinout on a logic analyzer before connecting.
- [Ghidra](ghidra.md): defined in the vendor layer but not shipped on this image.

## Upstream documentation

- [OpenOCD User's Guide](https://openocd.org/doc/html/index.html): adapters,
  targets, the flash commands and the GDB, Telnet and Tcl servers.
