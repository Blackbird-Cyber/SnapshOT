---
title: flashrom
summary: Read/write SPI flash chips
folder: firmware
launchers: [snapshot-flashrom.desktop]
ships_as: apt
package: flashrom
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  eradication: Read a controller's or device's SPI flash to a file for comparison, and, only when the engineer directs it, write a verified known-good image back.
  recovery: Read the flash back after a reflash and confirm its hash matches the known-good image before the device returns to service.
csf: [respond, recover]
attack_ics: [persistence, inhibit-response-function, impair-process-control]
attack_role: resembles
attack_techniques: [T1693, T1693.001, T1693.002]
protocols: [spi]
upstream: https://www.flashrom.org/
---

<!-- snapshot:facts -->

## What it is

flashrom reads, writes, erases and verifies the contents of flash chips,
usually the SPI NOR chip that holds a device's firmware or BIOS. It talks to the
chip through an external SPI programmer: a CH341A dongle, an FT2232-based
adapter, a Bus Pirate, a serprog device or others, connected with a SOIC clip or
soldered leads. Given a programmer and, if auto-detection needs help, a chip
name, it dumps the whole flash to a file, writes a file back (erasing first), or
checks the chip against a file. It also reads and sets the chip's write-protect
ranges.

## Why it is on SnapshOT

When a controller, RTU, gateway or network device may have modified firmware,
reading its flash directly is how you get an image that does not depend on the
possibly-compromised device to report itself honestly. That dump is then
compared with the vendor's known-good image in [binwalk](binwalk.md). flashrom
is also how a verified image is written back during eradication, under the
engineer's direction. It is bench work on an external programmer, not something
done over the network.

## On the wire

!!! danger "Writes: it can erase or overwrite a device's firmware"

    flashrom clips onto a physical chip. A wrong chip, voltage or command can
    brick the device or damage the board.

    - **Bench work only, on hardware the engineer has released from service.**
      Never clip onto a flash chip in a running, in-service controller: an
      in-circuit read can brown out or confuse the live device, and a write
      destroys its firmware. See the physical-access rules in the
      [rules of engagement](../../lifecycle/rules-of-engagement.md).
    - Match the programmer's I/O voltage to the chip (many SPI parts are 3.3 V
      and 1.8 V parts are common on newer devices); the wrong level can damage
      the chip or the board. Prefer powering the board from the programmer, or
      pull the chip, rather than clipping onto a powered board.
    - **Read first, and read twice.** Take two independent dumps and confirm they
      match before you rely on either; a flaky clip gives a different image each
      time.
    - **Hash the dump and keep it as evidence** before anything is written.
    - Write only in eradication or recovery, with the engineer present, with a
      verified known-good image, and verify by reading back afterwards.
    - Stop and recheck the clip and wiring if repeated probes name different
      chips or two reads differ. Never reach for `-f` (force) to get past an
      error on evidence hardware.
    - Nothing here touches the plant network, so the site's monitoring sees
      nothing: the record of the work is your notes, the dumps and their hashes.
    - The supported SPI programmers run as your own user through the udev rules
      the image ships (group `plugdev`); the `internal` programmer, which writes
      the host's own BIOS, needs `sudo` and is not what you want on an
      engagement. With Secure Boot on, the kernel's lockdown blocks the raw
      memory and I/O port access it needs, so it does not work at all; external
      programmers are unaffected. Clip onto the target's chip with an external
      programmer.

## PICERL mapping

### Eradication

During [eradication](../../lifecycle/phases/eradication.md), and in the
[firmware acquisition](../../lifecycle/playbooks/firmware-acquisition.md)
playbook, flashrom dumps the device's flash so it can be compared with the
known-good image. If the comparison finds an implant and the engineer decides to
reflash, flashrom writes the verified known-good image back. The pre-reflash
dump is kept as evidence of what was on the device.

### Recovery

In [recovery](../../lifecycle/phases/recovery.md), after any write, flashrom
reads the flash again and the read-back is hashed and checked against the
known-good image. Only a byte-for-byte match confirms the reflash before the
engineer returns the device to service.

## MITRE ATT&CK for ICS mapping

flashrom *resembles* the firmware techniques it is used to investigate and
reverse. Writing an image to a chip is exactly Modify Firmware (T1693), in its
Modify Firmware: System Firmware (T1693.001) and Modify Firmware: Module
Firmware (T1693.002) forms; the difference between eradication and an attack is
the authorization, the engineer and the verified image, not the action on the
chip. Modify Firmware serves three tactics, and a flashrom write looks like each:
[Persistence](../../lifecycle/attack-ics/persistence.md), because an implant in
flash survives reboots and re-imaging of the host software;
[Inhibit Response Function](../../lifecycle/attack-ics/inhibit-response-function.md),
because firmware that no longer boots or answers takes a protection or safety
function out of service; and
[Impair Process Control](../../lifecycle/attack-ics/impair-process-control.md),
because altered firmware can change what the device does with its inputs and
outputs. Record every read and write; the pre-reflash dump is the evidence of
the firmware an adversary left in place.

## Quick start

```sh
# What the menu launcher runs
flashrom --help
# List supported programmers, chips and boards
flashrom -L
# Probe only: what chip is on a CH341A programmer, no read or write
flashrom -p ch341a_spi
# Read the whole chip to a file (first of two independent dumps)
flashrom -p ch341a_spi -r rtu7-dump1.bin
# Name the chip explicitly when auto-detection is ambiguous
flashrom -p ch341a_spi -c W25Q64JV-.M -r rtu7-dump1.bin
# An FT2232-based adapter instead, interface B
flashrom -p ft2232_spi:type=4232H,port=B -r rtu7-dump1.bin
# Verify the chip against the known-good image (reads only)
flashrom -p ch341a_spi -v known-good.bin
# WRITE a verified image back: eradication only, engineer present
flashrom -p ch341a_spi -w known-good.bin
```

`ch341a_spi` fixes the SPI clock at 2 MHz and needs no parameters; other
programmers take a `spispeed=` and their own options (see `flashrom -L` and the
manual). A bare probe (no `-r`, `-w`, `-v` or `-E`) only identifies the chip.

## Output and evidence

Dump to the case folder, take a second dump to prove the read is stable, and
hash both before anything is written:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/firmware"
S=$(date -u +%Y%m%dT%H%M%SZ)
flashrom -p ch341a_spi -r "$CASE/firmware/rtu7-spi-$S.bin"
flashrom -p ch341a_spi -r "$CASE/firmware/rtu7-spi-$S-b.bin"
# The two reads must match before the dump is trusted
cmp "$CASE/firmware/rtu7-spi-$S.bin" "$CASE/firmware/rtu7-spi-$S-b.bin"
sha256sum "$CASE"/firmware/rtu7-spi-$S*.bin >> "$CASE/SHA256SUMS"
```

Keep the first dump untouched as the pre-reflash reference and do the analysis on
a copy in [binwalk](binwalk.md).

## Related tools

- [binwalk](binwalk.md): identify and extract the contents of a dump and compare
  it with the known-good image.
- [OpenOCD](openocd.md): read firmware through a JTAG/SWD debug port when the
  flash is internal to the microcontroller.
- [sigrok-cli](sigrok-cli.md) and [PulseView](pulseview.md): confirm a chip's
  pinout and the SPI wiring on a logic analyzer before clipping on.
- [firmware-mod-kit](firmware-mod-kit.md): defined in the vendor layer but not
  shipped on this image.

## Upstream documentation

- [flashrom website](https://www.flashrom.org/): the manual, the supported
  hardware list and the programmer documentation.
