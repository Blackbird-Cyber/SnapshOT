---
title: picocom (serial)
summary: Minimal serial terminal
folder: firmware
launchers: [snapshot-picocom.desktop]
ships_as: apt
package: picocom
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  identification: Reach a controller's or device's serial console to read its identity, firmware version, logs and running state.
  eradication: Interact with the console, with the engineer, to inspect start-up and configuration and confirm what was changed against known-good.
csf: [identify, detect, respond]
attack_ics: [execution]
attack_role: resembles
attack_techniques: [T0807]
protocols: [serial]
upstream: https://github.com/npat-efault/picocom
---

<!-- snapshot:facts -->

## What it is

picocom is a minimal serial terminal. It opens a serial port at a chosen baud
rate and line setting and connects it to your terminal, with a small set of
escape commands (prefixed by Ctrl-A) for things like toggling the DTR line,
sending files through external helpers, and logging. It does little beyond being
a clean, dependable pipe to a serial device, which is why it is a favourite for
console work on embedded hardware.

## Why it is on SnapshOT

When you want the simplest possible connection to a device's serial console,
with no menus and no modem behaviour, picocom is it. It is the quick way to read
a bootloader, a firmware banner or a login prompt on a header, and its control
over the DTR and RTS lines is useful when a device resets or enters a bootloader
on those signals. It does the same job as [minicom](minicom.md) and
[tio](tio.md) with less around it.

## On the wire

!!! warning "Active: opening the port sends signals to the device"

    A serial console is a live connection to equipment. Opening the port and
    typing both reach the device.

    - On most systems opening the port raises the DTR and RTS lines, and by
      default picocom lowers them again on exit, signalling a modem hangup; on
      many devices either change asserts a reset or interrupts the running
      program. `--noreset` (or quitting with `Ctrl-A Ctrl-Q`) leaves the lines
      as they are on exit; `--lower-dtr` and `--lower-rts` drop them just after
      the port opens. None of these stops the lines moving as the port opens,
      so **never attach to the console of a running, in-service controller
      without the engineer's agreement**; see the
      [rules of engagement](../../lifecycle/rules-of-engagement.md).
    - Confirm the voltage level first: an RS-232 (±12 V) adapter on a TTL (3.3 V
      or 5 V) header damages the device. Confirm the pinout and baud rate, with
      [sigrok-cli](sigrok-cli.md) if need be.
    - Reading the console is reading; issuing commands that change configuration,
      firmware or mode is a write, done only with the engineer in eradication or
      recovery, against a known-good reference.
    - Console work puts nothing on the plant network, so the site's monitoring
      will not see it; tell the operations contact before you connect instead.
      Stop if the device resets, changes mode or the operators report anything.
    - The SnapshOT user is in group `dialout`, so serial ports need no `sudo`.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), picocom
reaches a device's console to read its boot log, firmware version and running
state. Log the session so the banner and any error are kept as evidence, and
stop if interacting with the console affects the process.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), with the engineer, the
console inspects a released device's start-up items and configuration for
comparison with the known-good reference. Any command that changes the device is
directed by the engineer and recorded.

## MITRE ATT&CK for ICS mapping

picocom *resembles* [Execution](../../lifecycle/attack-ics/execution.md):
interacting with a device over its console is a Command-Line Interface (T0807),
the same channel an adversary with console access would use. Announce console
work to the site, and keep the logged session as the record of what was typed and
what the device replied.

## Quick start

```sh
# What the menu launcher runs (picocom's own help)
picocom --help
# Open /dev/ttyUSB0 at 115200 8N1 (the defaults are 8N1)
picocom -b 115200 /dev/ttyUSB0
# Leave the port and its control lines as they are on exit, and log the session
picocom -b 115200 --noreset \
    --logfile console-$(date -u +%Y%m%dT%H%M%SZ).log /dev/ttyUSB0
```

The escape key is `Ctrl-A`: `Ctrl-A Ctrl-X` exits (resetting the port unless
`--noreset`), `Ctrl-A Ctrl-Q` quits without resetting, and `Ctrl-A Ctrl-C`
toggles local echo. `/dev/ttyUSB0` is the usual USB serial adapter; a USB CDC
device is `/dev/ttyACM0`.

## Output and evidence

Log the session to the case folder and hash it:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/serial"
picocom -b 115200 --noreset \
    --logfile "$CASE/serial/rtu7-console-$(date -u +%Y%m%dT%H%M%SZ).log" /dev/ttyUSB0
sha256sum "$CASE"/serial/rtu7-console-*.log >> "$CASE/SHA256SUMS"
```

## Related tools

- [minicom](minicom.md): a menu-driven serial terminal for the same consoles.
- [tio](tio.md): timestamps and auto-logs each session and reconnects when a USB
  adapter drops.
- [screen](screen.md): opens a serial line and keeps the session alive detached.
- [sigrok-cli](sigrok-cli.md): find an unmarked header's baud rate and pinout
  before you connect.

## Upstream documentation

- [picocom on GitHub](https://github.com/npat-efault/picocom): the source,
  options and escape commands.
