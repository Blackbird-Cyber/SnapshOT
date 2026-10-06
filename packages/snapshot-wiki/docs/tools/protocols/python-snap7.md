---
title: python-snap7
summary: Siemens S7comm client library for Python
folder: protocols
launchers: []
ships_as: vendor
package: ics-python
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  identification: Read a Siemens PLC's identity, CPU state and a data block from the ICS shell, with the engineer present.
  eradication: Read data blocks and block lists back and compare them with the known-good project before the controller returns to automatic.
  recovery: Confirm restored data blocks read back the expected values before the process owner returns the line to automatic control.
csf: [detect, respond, recover]
attack_ics: [discovery, collection, execution, impair-process-control]
attack_role: resembles
attack_techniques: [T0888, T0801, T0845, T0858, T0836]
protocols: [s7comm]
upstream: https://python-snap7.readthedocs.io/
---

<!-- snapshot:facts -->

## What it is

python-snap7 is a Python wrapper around the Snap7 library, which speaks S7comm
to Siemens S7-300, S7-400, S7-1200 and S7-1500 PLCs. As a client it connects to a
CPU, reads its identity and order code, reports the run or stop state, reads and
writes data blocks, inputs, outputs, merkers, timers and counters, lists the
blocks on the CPU and reads system status lists. Helper functions decode the raw
bytes into integers, reals and strings. It runs as a library in the [ICS Python
shell](ics-python-shell.md).

## Why it is on SnapshOT

Siemens S7 controllers are among the most common on the plant floor, and S7comm
addresses data by block and offset rather than by a flat register map.
python-snap7 lets a responder ask an S7 CPU for its identity and state and read
the data blocks a capture referenced, which is the quickest way to confirm what a
Siemens PLC is doing without the engineering software. The wheel on this image
bundles its own `libsnap7` shared library for both architectures, so no separate
system library is needed.

## On the wire

!!! danger "Writes: it can change a Siemens CPU"

    Reading identity and data blocks sends S7comm requests; writing a data
    block, and commands such as stop, change what the CPU does.

    - **Never write a block, or stop or start a CPU, without the engineer
      responsible present and agreeing to the exact block, offset and value.**
      Stopping a running S7 CPU stops the process it controls.
    - The rack and slot must match the CPU (often rack 0, slot 1 on an S7-300,
      slot 0 or 1 on newer families). A wrong slot simply fails; confirm with
      the engineer.
    - Read small areas from one CPU at a time. S7-1200 and S7-1500 refuse
      S7comm reads and writes unless PUT/GET access is enabled and the data
      block is not optimized; note what the CPU allows, as that is itself a
      finding.
    - S7comm has no authentication on most deployments: the CPU, and the site's
      monitoring, cannot tell your requests from an adversary's. Announce the
      work.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), read a
Siemens CPU's identity, order code and run or stop state, and with the engineer
present read the data block a capture referenced, to confirm what the PLC is and
what it holds. Reads only at this point.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), read data blocks and
the block list back and compare them with the engineer's known-good project
before the controller returns to automatic. A difference is either an
adversary's change or a gap in the baseline.

### Recovery

During [recovery](../../lifecycle/phases/recovery.md), read the key data blocks
again to confirm the CPU runs with the expected values before the process owner
returns the line to automatic control. Check the CPU state and the block list
as well: a CPU left in stop, or a block that was not in the engineer's project,
means the restoration is not finished. Rerun the eradication script so the two
outputs compare directly, and keep both with the case.

## MITRE ATT&CK for ICS mapping

python-snap7 *resembles* four tactics. Reading the CPU's identity and order code
looks like Discovery: Remote System Information Discovery (T0888). Reading a
data block looks like Collection: Monitor Process State (T0801), and uploading a
block like Program Upload (T0845). Stopping or starting the CPU looks like
Execution: Change Operating Mode (T0858). Writing a data block looks like
Impair Process Control: Modify Parameter (T0836). The traffic is the same as an
adversary using the same library, so S7 work is announced to the site, and an
unannounced CPU stop or block upload in a capture deserves an immediate
question.

## Quick start

```sh
# Read a CPU's state, identity and order code
/opt/snapshot/ics-python/bin/ics-python -c '
import snap7
c = snap7.client.Client(); c.connect("192.0.2.20", 0, 1)
print(c.get_cpu_state())
print(c.get_cpu_info().ModuleTypeName, c.get_order_code().OrderCode)
c.disconnect()'
# Read 6 bytes from data block 1: an INT at byte 0 and a REAL at byte 2
/opt/snapshot/ics-python/bin/ics-python -c '
import snap7
from snap7.util import get_int, get_real
c = snap7.client.Client(); c.connect("192.0.2.20", 0, 1)
data = c.db_read(1, 0, 6)
print(data.hex(), get_int(data, 0), get_real(data, 2))
c.disconnect()'
# List the blocks on the CPU
/opt/snapshot/ics-python/bin/ics-python -c '
import snap7
c = snap7.client.Client(); c.connect("192.0.2.20", 0, 1)
print(c.list_blocks()); c.disconnect()'
# WRITE the REAL 21.5 at byte 2 of data block 1 and read it back: engineer present
/opt/snapshot/ics-python/bin/ics-python -c '
import snap7
from snap7.util import get_real, set_real
c = snap7.client.Client(); c.connect("192.0.2.20", 0, 1)
data = bytearray(4); set_real(data, 0, 21.5); c.db_write(1, 2, data)
print(get_real(c.db_read(1, 2, 4), 0)); c.disconnect()'
```

`192.0.2.20` is a documentation address; `0, 1` are the rack and slot. S7comm
uses TCP 102. Offsets are in bytes from the start of the data block, as the
engineering project shows them for a non-optimized block.

## Output and evidence

Save the script and its output together:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/s7"
/opt/snapshot/ics-python/bin/ics-python "$CASE/s7/read-cpu.py" | tee "$CASE/s7/cpu.txt"
sha256sum "$CASE"/s7/read-cpu.py "$CASE"/s7/cpu.txt >> "$CASE/SHA256SUMS"
```

Capture with [tshark](../traffic/tshark.md) at the same time; the S7comm
functions show which requests you sent.

## Related tools

- [plcscan](plcscan.md) and [nmap](../recon/nmap.md): identify an S7 PLC
  (`s7-info`) before you read blocks.
- [ICS Python shell](ics-python-shell.md): the environment python-snap7 runs in.
- [tshark](../traffic/tshark.md): decode S7comm in a capture.

## Upstream documentation

- [python-snap7 documentation](https://python-snap7.readthedocs.io/): the client
  API and the util decoders.
- [S7comm (Wireshark wiki)](https://wiki.wireshark.org/S7comm): the protocol as
  the dissector decodes it.
