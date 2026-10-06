---
title: mbpoll
summary: Modbus TCP/RTU master poller
folder: protocols
launchers: [snapshot-mbpoll.desktop]
ships_as: apt
package: mbpoll
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  identification: Read the registers a capture showed being polled or written, from a known unit id, with the engineer present.
  eradication: Read set points and parameters back and compare them with the known-good list before the controller returns to automatic.
  recovery: Confirm restored values read back as expected; write a correction only when the engineer asks for it.
csf: [detect, respond, recover]
attack_ics: [collection, impair-process-control]
attack_role: resembles
attack_techniques: [T0801, T1692.001, T0836]
protocols: [modbus, serial]
upstream: https://github.com/epsilonrt/mbpoll
---

<!-- snapshot:facts -->

## What it is

mbpoll is a command-line Modbus master. It reads coils, discrete inputs, input
registers and holding registers from a Modbus device over TCP or over a serial
line (RTU), once or at a fixed poll rate, and prints the values as integers,
hexadecimal, 32-bit integers, floats or text. Given values after the target, it
writes them to coils or holding registers instead. It is built on libmodbus and
its options follow the style of the proconX modpoll tool.

## Why it is on SnapshOT

Modbus is the most common protocol on the plant floor and the easiest to read
by hand. mbpoll lets a responder check exactly what a capture showed: the value
of the register an unknown host was polling, or whether a set point has the value
the operators expect. It needs no Python environment, works on both TCP and
RS-485 or RS-232 adapters, and its one-line commands are easy to record in the
case notes.

## On the wire

!!! danger "Writes: it can change what a controller does"

    Reading sends Modbus requests to the device; writing changes coils and
    holding registers, which drive real equipment.

    - **Never write without the engineer responsible for the device present and
      agreeing to the exact register and value.** A wrong register or unit id
      can start a motor or change a set point.
    - Use `-1` (poll once). Without it mbpoll polls every second until you stop it.
    - Read small ranges (`-c` of a few registers) from one unit id at a time;
      some devices and serial gateways cope badly with large or fast requests.
    - Check the addressing before writing: mbpoll counts references from 1 by
      default, and `-0` switches to the 0-based addresses of the Modbus PDU.
      Documentation that says "40001" means holding register reference 1.
    - Modbus has no authentication: the device cannot tell your writes from an
      adversary's, and neither can the site's monitoring. Announce the work.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), a capture
may show a host polling or writing registers it has no business touching. With
the engineer present, read those same registers once to see what they hold and
whether the values make sense for the process. Reads only, at this point.

### Eradication

Before a cleaned controller goes back to automatic control, read back its set
points and parameters and compare them with the engineer's known-good list.
Any difference is either the adversary's change still in place or a gap in the
baseline; both must be resolved before moving on.

### Recovery

After restoration, read the key registers again to confirm the process runs with
the expected values. If the engineer decides a value must be corrected from the
laptop, write it once with `-1`, read it back and record both commands.

## MITRE ATT&CK for ICS mapping

mbpoll *resembles* two tactics, because Modbus cannot tell a responder from an
adversary. Its reads look like Collection, specifically Monitor Process State
(T0801): an unexpected host polling registers. Its writes look like
Impair Process Control, through Unauthorized Message: Command Message
(T1692.001) and Modify Parameter (T0836). Announce mbpoll use to the site's
monitoring team, and when you find such traffic in a capture, mbpoll is how you
check, with approval, what the adversary read or changed.

## Quick start

```sh
# What the menu launcher runs
mbpoll -h
# Read 10 holding registers (references 1 to 10) once, from unit id 1
mbpoll -1 -a 1 -r 1 -c 10 192.0.2.10
# Read 4 input registers
mbpoll -1 -a 1 -t 3 -r 1 -c 4 192.0.2.10
# Read 8 coils
mbpoll -1 -a 1 -t 0 -r 1 -c 8 192.0.2.10
# Read two 32-bit floats from holding registers 101 to 104
mbpoll -1 -a 1 -t 4:float -r 101 -c 2 192.0.2.10
# The same kind of read over RS-485 or RS-232 (Modbus RTU), 9600 baud, no parity
mbpoll -1 -m rtu -a 1 -b 9600 -P none -r 1 -c 4 /dev/ttyUSB0
# WRITE 1234 to holding register 100: only with the engineer present
mbpoll -1 -a 1 -r 100 192.0.2.10 1234
```

`192.0.2.10` is a documentation address and `/dev/ttyUSB0` the usual name of a
USB serial adapter. The SnapshOT user is in group `dialout`, so serial ports
need no `sudo`. Add `-p` for a non-standard TCP port and `-o` to lengthen the
1-second timeout on slow links.

## Output and evidence

mbpoll prints to the terminal. Record what you read, and what you wrote, with
the command line and the UTC time:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/modbus"
{ date -u; echo '$ mbpoll -1 -a 1 -r 1 -c 10 192.0.2.10';
  mbpoll -1 -a 1 -r 1 -c 10 192.0.2.10; } \
  2>&1 | tee -a "$CASE/modbus/plc01-reads.txt"
sha256sum "$CASE/modbus/plc01-reads.txt" >> "$CASE/SHA256SUMS"
```

Run a [tshark](../traffic/tshark.md) capture at the same time when the session
matters: the packets are the evidence of exactly what was sent.

## Related tools

- [tshark](../traffic/tshark.md): find the Modbus traffic worth checking, and
  capture your own requests while you do it.
- [nmap](../recon/nmap.md): `modbus-discover` finds the unit id and device
  identity before you read registers.
- [pymodbus](pymodbus.md) and the [ICS Python shell](ics-python-shell.md):
  scripted Modbus reads when a one-line command is not enough.
- [plcscan](plcscan.md): find Modbus devices and unit ids on a segment.

## Upstream documentation

- [mbpoll on GitHub](https://github.com/epsilonrt/mbpoll): source, options and
  examples.
- [Modbus specifications](https://modbus.org/specs.php): function codes and data
  model.
