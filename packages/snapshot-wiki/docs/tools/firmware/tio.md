---
title: tio (serial)
summary: Simple serial device I/O tool
folder: firmware
launchers: [snapshot-tio.desktop]
ships_as: apt
package: tio
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  identification: Reach a controller's or device's serial console to read its identity, firmware version, logs and running state, with timestamps.
  eradication: Interact with the console, with the engineer, to inspect start-up and configuration and confirm what was changed against known-good.
csf: [identify, detect, respond]
attack_ics: [execution]
attack_role: resembles
attack_techniques: [T0807]
protocols: [serial]
upstream: https://tio.github.io/
---

<!-- snapshot:facts -->

## What it is

tio is a small, modern serial terminal. It connects to a serial port (the
default is 115200 8N1) and gives a clean session with a short set of Ctrl-T
commands. It is built for console work: it can timestamp each line, log
automatically to a named file, and reconnect by itself when a USB serial adapter
disappears and comes back, which happens when a device reboots. Configuration
profiles let you save a device's settings under a name.

## Why it is on SnapshOT

tio is the convenient choice when a console session needs a timestamped,
auto-saved record, or when the device resets its USB adapter during boot and you
want the terminal to pick the connection back up. The per-line timestamps drop
straight into a timeline, and the automatic log means the session is captured
without a separate step. It does the same job as [minicom](minicom.md) and
[picocom](picocom.md), with logging and reconnection built in.

## On the wire

!!! warning "Active: opening the port sends signals to the device"

    A serial console is a live connection to equipment. Opening the port and
    typing both reach the device.

    - Opening a serial port asserts the DTR and RTS control lines, which on many
      devices resets or interrupts the running program. **Never attach to the
      console of a running, in-service controller without the engineer's
      agreement**; see the
      [rules of engagement](../../lifecycle/rules-of-engagement.md).
    - tio reconnects by default; on an in-service device a surprise reconnection
      means repeated line activity. Use `--no-reconnect` when you want a single,
      deliberate session.
    - Confirm the voltage level first: an RS-232 (±12 V) adapter on a TTL (3.3 V
      or 5 V) header damages the device. Confirm the pinout and baud rate, with
      [sigrok-cli](sigrok-cli.md) if need be.
    - Reading the console is reading; commands that change configuration,
      firmware or mode are a write, done only with the engineer in eradication or
      recovery, against a known-good reference.
    - Console work puts nothing on the plant network, so the site's monitoring
      will not see it; tell the operations contact before you connect instead.
      Stop if the device resets, changes mode or the operators report anything.
    - The SnapshOT user is in group `dialout`, so serial ports need no `sudo`.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), tio reaches a
device's console to read its boot log, firmware version and state, with each line
timestamped. The automatic log keeps the session as evidence; stop if
interacting with the console affects the process.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), with the engineer, the
console inspects a released device's start-up items and configuration for
comparison with the known-good reference. Any command that changes the device is
directed by the engineer and recorded.

## MITRE ATT&CK for ICS mapping

tio *resembles* [Execution](../../lifecycle/attack-ics/execution.md):
interacting with a device over its console is a Command-Line Interface (T0807),
the same channel an adversary with console access would use. Announce console
work to the site, and keep the timestamped log as the record of what was typed
and what the device replied.

## Quick start

```sh
# What the menu launcher runs (tio's own help)
tio --help
# List serial devices, profiles and topology ids
tio -l
# Connect to /dev/ttyUSB0 at 115200 8N1 (the defaults)
tio /dev/ttyUSB0
# One deliberate session, ISO 8601 timestamps in UTC, logged automatically
TZ=UTC tio -b 115200 --no-reconnect -t --timestamp-format iso8601 \
    -L --log-directory ~/cases/site-a/serial /dev/ttyUSB0
```

The command key is `Ctrl-T`: `Ctrl-T ?` lists commands, `Ctrl-T q` quits,
`Ctrl-T b` sends a serial break, `Ctrl-T L` shows the state of the control lines
and `Ctrl-T f` toggles logging. tio stamps lines in local time, so `TZ=UTC` keeps
the timestamps in UTC like the rest of the case. `/dev/ttyUSB0` is the usual USB
serial adapter; a USB CDC device is `/dev/ttyACM0`.

## Output and evidence

tio names an automatic log per connection under the chosen directory
(`tio_<device>_<date and time>.log`); hash the logs into the case:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/serial"
TZ=UTC tio -b 115200 --no-reconnect -t --timestamp-format iso8601 \
    -L --log-directory "$CASE/serial" /dev/ttyUSB0
sha256sum "$CASE"/serial/tio_*.log >> "$CASE/SHA256SUMS"
```

Use `--log-file` to set an exact name instead of the automatic one.

## Related tools

- [minicom](minicom.md): a menu-driven serial terminal for the same consoles.
- [picocom](picocom.md): a minimal serial terminal with explicit control-line
  handling.
- [screen](screen.md): opens a serial line and keeps the session alive detached.
- [sigrok-cli](sigrok-cli.md): find an unmarked header's baud rate and pinout
  before you connect.

## Upstream documentation

- [tio website](https://tio.github.io/): the manual, options and key commands.
