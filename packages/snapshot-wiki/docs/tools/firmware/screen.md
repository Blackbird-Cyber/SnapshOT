---
title: screen
summary: Terminal multiplexer, used here as a serial console
folder: firmware
launchers: []
ships_as: apt
package: screen
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  identification: Attach a serial console and leave it capturing a device's boot log and output while you work elsewhere.
  eradication: Hold a console session on a released device, with the engineer, to inspect start-up and configuration against known-good.
csf: [identify, detect, respond]
attack_ics: [execution]
attack_role: resembles
attack_techniques: [T0807]
protocols: [serial]
upstream: https://www.gnu.org/software/screen/manual/screen.html
---

<!-- snapshot:facts -->

## What it is

GNU screen is a terminal multiplexer, but it also opens a serial line directly:
give it a tty device and a line setting and it becomes a serial terminal whose
session you can detach and reattach, so a console stays connected while you close
the laptop lid or switch tasks. It can log the window to a file and send a break.
On this image it has no menu launcher; it is run from a terminal, mainly for its
serial-console and detach features.

## Why it is on SnapshOT

The thing screen does that the dedicated serial terminals do not is survive
detachment: a session left running captures a device's full boot log or a slow
process over minutes or hours while you do other work, and reattaches later with
the scrollback intact. When you want a long, unattended, logged console on a
released device, screen is the tool; [minicom](minicom.md),
[picocom](picocom.md) and [tio](tio.md) are better for an interactive session at
the bench.

## On the wire

!!! warning "Active: opening the port sends signals to the device"

    Connecting screen to a serial line is a live connection to equipment, and it
    takes an exclusive hold on the port.

    - Opening a serial port asserts the DTR and RTS control lines, which on many
      devices resets or interrupts the running program. **Never attach to the
      console of a running, in-service controller without the engineer's
      agreement**; see the
      [rules of engagement](../../lifecycle/rules-of-engagement.md).
    - Confirm the voltage level first: an RS-232 (±12 V) adapter on a TTL (3.3 V
      or 5 V) header damages the device. Confirm the pinout and baud rate, with
      [sigrok-cli](sigrok-cli.md) if need be.
    - A detached session still holds the port open and still logs; detach is for
      your convenience, not a reason to leave a console on a live device
      unattended.
    - Reading the console is reading; commands that change configuration,
      firmware or mode are a write, done only with the engineer in eradication or
      recovery, against a known-good reference.
    - Console work puts nothing on the plant network, so the site's monitoring
      will not see it; tell the operations contact before you connect instead.
      Stop if the device resets, changes mode or the operators report anything.
    - The SnapshOT user is in group `dialout`, so serial ports need no `sudo`.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), screen
attaches to a device's console and captures its boot log and output to a file,
left running while you work on the capture or other hosts. The scrollback and the
log are the evidence; stop if interacting with the console affects the process.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), with the engineer, a
held console session inspects a released device's start-up items and
configuration for comparison with the known-good reference, with the session
logged. Any command that changes the device is directed by the engineer and
recorded.

## MITRE ATT&CK for ICS mapping

screen *resembles* [Execution](../../lifecycle/attack-ics/execution.md):
interacting with a device over its console is a Command-Line Interface (T0807),
the same channel an adversary with console access would use. Announce console
work to the site, and keep the window log as the record of the session.

## Quick start

screen has no menu launcher; run it in a terminal.

```sh
# Open /dev/ttyUSB0 at 115200 as a serial console, logging to a file
screen -L -Logfile rtu7-console.log /dev/ttyUSB0 115200
# Add line settings in stty notation: 8 data bits, no parity, one stop bit
screen /dev/ttyUSB0 115200,cs8,-parenb,-cstopb
# Reattach to a session you detached earlier
screen -r
```

Inside screen the command key is `Ctrl-A`: `Ctrl-A d` detaches (leaving the
session running), `Ctrl-A k` kills the window and closes the port, `Ctrl-A H`
toggles logging and `Ctrl-A b` sends a serial break. The other line settings in
the same list are `cs7`, `parenb` with `parodd` for parity, `cstopb` for two stop
bits, and `ixon`/`ixoff` for software flow control, each negated with `-`. `/dev/ttyUSB0` is the usual
USB serial adapter; a USB CDC device is `/dev/ttyACM0`.

## Output and evidence

Log the window to the case folder and hash it when the session ends:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/serial"
screen -L -Logfile "$CASE/serial/rtu7-console-$(date -u +%Y%m%dT%H%M%SZ).log" \
    /dev/ttyUSB0 115200
sha256sum "$CASE"/serial/rtu7-console-*.log >> "$CASE/SHA256SUMS"
```

## Related tools

- [minicom](minicom.md), [picocom](picocom.md) and [tio](tio.md): dedicated
  serial terminals for an interactive session at the bench.
- [sigrok-cli](sigrok-cli.md): find an unmarked header's baud rate and pinout
  before you connect.

## Upstream documentation

- [GNU screen manual](https://www.gnu.org/software/screen/manual/screen.html):
  the full command reference, including the serial-window line settings.
