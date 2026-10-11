---
title: minicom (serial)
summary: Serial console terminal
folder: firmware
launchers: [snapshot-minicom.desktop]
ships_as: apt
package: minicom
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
upstream: https://salsa.debian.org/minicom-team/minicom
---

<!-- snapshot:facts -->

## What it is

minicom is a full-screen serial terminal. It opens a serial port at a chosen
baud rate and line setting and gives you an interactive session with whatever is
on the other end: a controller's maintenance console, a bootloader prompt, a
switch or gateway CLI. It has a menu (Ctrl-A Z) for changing settings, a capture
file for logging the session, and a dialing directory left over from its modem
origins. On this image it is used as a plain console, not a modem dialer.

## Why it is on SnapshOT

Many OT devices expose a serial console on a header or a DB9 before they expose
anything on the network, and it is often the only way to read a bootloader, a
firmware banner or an error during a device's start-up. minicom is the
established, menu-driven choice when you want a settings menu and a built-in
capture file; [picocom](picocom.md) and [tio](tio.md) are lighter alternatives
for the same job.

## On the wire

!!! warning "Active: opening the port sends signals to the device"

    A serial console is a live connection to equipment. Opening the port and
    typing both reach the device.

    - Opening a serial port toggles the DTR and RTS control lines, which on many
      devices asserts a reset or interrupts the running program. **Never attach
      to the console of a running, in-service controller without the engineer's
      agreement**; see the
      [rules of engagement](../../lifecycle/rules-of-engagement.md).
    - Confirm the voltage level first. A console header may be RS-232 (±12 V) or
      TTL (3.3 V or 5 V); a TTL header driven by an RS-232 adapter is damaged.
      Use the right adapter, and confirm the pinout and baud rate, with
      [sigrok-cli](sigrok-cli.md) if need be.
    - Start minicom with `-o` (no initialization) so it does not send its
      compiled-in modem init string (`AT S7=45 ...`) to the device, which a
      non-modem console would see as stray input. Leave with `Ctrl-A Q`, not
      `Ctrl-A X`, which resets the "modem" on the way out.
    - Reading the console is reading; issuing commands that change configuration,
      firmware or mode is a write, done only with the engineer in eradication or
      recovery, against a known-good reference.
    - Console work puts nothing on the plant network, so the site's monitoring
      will not see it; tell the operations contact before you connect instead.
      Stop if the device resets, changes mode or the operators report anything.
    - The SnapshOT user is in group `dialout`, so serial ports need no `sudo`.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), the serial
console is where a device tells you what it is: the boot log, the firmware
version, the model and the running state. Capture the session to a file so the
banner and any error become evidence, and stop if interacting with the console
affects the process.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), with the engineer, the
console is used to inspect a released device's start-up items, configuration and
stored logic and compare them with the known-good reference. Any command that
changes the device is directed by the engineer and recorded.

## MITRE ATT&CK for ICS mapping

minicom *resembles* [Execution](../../lifecycle/attack-ics/execution.md):
interacting with a device over its console is a Command-Line Interface (T0807),
the same channel an adversary with physical or remote console access would use.
Because the device cannot tell your session from theirs, announce console work to
the site and keep the captured session as the record of exactly what was typed
and what the device replied.

## Quick start

```sh
# What the menu launcher runs (minicom's own help)
minicom -h
# Open /dev/ttyUSB0 at 115200 8N1 with no modem init, logging to a file
minicom -o -D /dev/ttyUSB0 -b 115200 -C console-$(date -u +%Y%m%dT%H%M%SZ).log
# Enter the settings menu to change port, baud and handshake
minicom -s
```

Inside minicom, `Ctrl-A Z` shows the command summary, `Ctrl-A C` clears the
screen, `Ctrl-A Q` quits without resetting (the exit to use on a device
console), and `Ctrl-A X` exits and resets the modem. `/dev/ttyUSB0` is the usual name of a USB serial adapter; a
built-in port is `/dev/ttyS0` and a USB CDC device `/dev/ttyACM0`.

## Output and evidence

Log the whole session with the capture file and hash it; the log is the record
of what the console showed and what you sent:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/serial"
minicom -o -D /dev/ttyUSB0 -b 115200 \
    -C "$CASE/serial/rtu7-console-$(date -u +%Y%m%dT%H%M%SZ).log"
sha256sum "$CASE"/serial/rtu7-console-*.log >> "$CASE/SHA256SUMS"
```

## Related tools

- [picocom](picocom.md) and [tio](tio.md): lighter serial terminals for the same
  consoles; tio timestamps and auto-logs each session.
- [screen](screen.md): also opens a serial line, and keeps the session alive
  detached.
- [sigrok-cli](sigrok-cli.md) and [PulseView](pulseview.md): find an unmarked
  header's baud rate and pinout before you connect.

## Upstream documentation

- [minicom on Debian Salsa](https://salsa.debian.org/minicom-team/minicom): the
  source and the manual pages.
