---
title: ICS Python shell
summary: Python 3.11 shell with the ICS libraries (pymodbus, pycomm3, asyncua, bacpypes3, BAC0, python-snap7)
folder: protocols
launchers: [snapshot-ics-python.desktop]
ships_as: vendor
package: ics-python
arch: [amd64, arm64]
status: shipped
wire: active
phases:
  identification: Script a one-off read of a device in its own protocol when the command-line tools do not fit, with the engineer present.
  eradication: Read logic values, parameters and device identity back and compare them with the known-good list before a controller returns to automatic.
  recovery: Confirm restored devices answer with the expected values before the process owner returns them to normal operation.
csf: [detect, respond, recover]
attack_ics: [collection]
attack_role: resembles
attack_techniques: [T0801, T0861]
protocols: [modbus, s7comm, ethernet-ip, opc-ua, bacnet]
upstream: https://docs.python.org/3.11/
---

<!-- snapshot:facts -->

## What it is

The ICS Python shell is an interactive Python interpreter with the SnapshOT
industrial libraries already installed and ready to import: pymodbus (Modbus),
pycomm3 (EtherNet/IP and CIP), asyncua (OPC UA), bacpypes3 and BAC0 (BACnet) and
python-snap7 (Siemens S7comm). It lives in its own vendor-layer environment on a
pinned Python 3.11 runtime, separate from the system Python, so these versions
never affect anything else on the image. The menu launcher opens the shell, and
every library page in this folder gives short scripts to run inside it.

## Why it is on SnapshOT

Some protocol questions do not fit a one-line command: reading a structured data
block, walking an OPC UA address space, decoding a vendor-specific object. The
shell is where a responder writes a few lines of Python against one of the
libraries to ask exactly that question, then pastes the script and its output
into the case notes. It is the common environment behind the dedicated library
pages ([pymodbus](pymodbus.md), [pycomm3](pycomm3.md), [asyncua](asyncua.md),
[bacpypes3](bacpypes3.md), [bac0](bac0.md), [python-snap7](python-snap7.md)),
which cover each protocol in depth. The vendor layer is explained on the
[vendor layer](../../platform/vendor-layer.md) platform page.

## On the wire

!!! warning "Active: it sends whatever your script sends"

    The shell itself is passive, but the libraries in it talk to real devices.
    What reaches the wire is exactly what your code does, so the OT cautions of
    the individual protocols apply in full.

    - A read is still a request a fragile controller must answer. Work one
      device at a time, keep requests small and slow, and have the engineer for
      that device present.
    - Writing to a controller changes what it does. Treat any write script as
      the [writes](../../lifecycle/wire-classes.md) wire class: the engineer
      present, the exact address and value agreed, announced to the site.
    - None of these protocols authenticate the responder, so the site's
      monitoring cannot tell your script from an adversary's. Announce the work.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), the shell
answers a question the command-line tools cannot phrase: read a specific
structure, browse an address space, or decode an object a capture showed. Keep
it to reads, one device at a time, with the engineer present.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), a short script reads
logic values, parameters and device identity back from a cleaned controller and
compares them with the engineer's known-good list, in one pass across whichever
protocol the device speaks. Have the script print every mismatch rather than
stop at the first, so the engineer sees the whole difference at once. A
difference is either the adversary's change still in place or a gap in the
baseline, and both are resolved before the controller goes back to automatic.

### Recovery

During [recovery](../../lifecycle/phases/recovery.md), the shell confirms
restored devices answer with the expected values before they return to
automatic control. The eradication script can usually be run again unchanged,
which makes the two checks directly comparable. Save each run's script and
output with the case, with the UTC time, as the record that the values were
right when the process owner took the system back.

## MITRE ATT&CK for ICS mapping

The shell *resembles* Collection, because a script that reads process values
looks on the wire like Monitor Process State (T0801), and one that enumerates
tags, points or nodes looks like Point & Tag Identification (T0861). Its traffic
is indistinguishable from an adversary using the same libraries, which is why
the work is announced to the site's monitoring. When a script writes, it also
resembles the tactics on the library pages for that protocol.

## Quick start

```sh
# What the menu launcher runs: a one-line import check, then an interactive shell
/opt/snapshot/ics-python/bin/ics-python -c 'import pymodbus, asyncua; print("ICS libs ready")'
# Open the shell and import the library you need
/opt/snapshot/ics-python/bin/ics-python
# Run a saved script with the vendored interpreter
/opt/snapshot/ics-python/bin/ics-python ~/cases/site-a/modbus/read-plc01.py
# Run a library's own module (here, the BACpypes3 console's options)
/opt/snapshot/ics-python/bin/ics-python -m bacpypes3 --help
```

`/opt/snapshot/ics-python/bin/ics-python` is the only Python that has these
libraries; the system `python3` does not. Its wrappers are also linked into
`/opt/snapshot/bin`, which is on `PATH`, so `ics-python` and the OPC UA
command-line tools (`uadiscover`, `uaread` and the rest) also work by bare name
in a terminal.

## Output and evidence

Save each script in the case folder of the protocol it speaks (`modbus/`,
`s7/`, `enip/`, `opcua/`, `bacnet/`) and keep its output beside it:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/modbus"
/opt/snapshot/ics-python/bin/ics-python "$CASE/modbus/read-plc01.py" | tee "$CASE/modbus/plc01.txt"
sha256sum "$CASE"/modbus/read-plc01.py "$CASE"/modbus/plc01.txt >> "$CASE/SHA256SUMS"
```

The script is the record of exactly what was sent; keep it with the output.

## Related tools

- [pymodbus](pymodbus.md), [pycomm3](pycomm3.md), [asyncua](asyncua.md),
  [bacpypes3](bacpypes3.md), [bac0](bac0.md) and [python-snap7](python-snap7.md):
  the libraries in this shell, one protocol each.
- [OPC UA command-line tools](opcua-cli-tools.md): the asyncua console scripts
  that share this environment, for one-line OPC UA checks.
- [mbpoll](mbpoll.md): a single Modbus read or write without writing Python.
- [tshark](../traffic/tshark.md): capture while a script runs, so the packets
  show exactly what was asked and answered.

## Upstream documentation

- [Python 3.11 documentation](https://docs.python.org/3.11/): the language and
  standard library.
- Each library's own manual is linked from its page in this folder.
