---
title: Protocol interrogation
summary: Read a controller's registers, tags and parameters in its own protocol, with the engineer present, to confirm what a capture showed and to compare against known-good.
phases: [identification, eradication]
tactics: [collection, impair-process-control]
---

Protocol interrogation reads a device in its own language to answer a question the
capture raised: what value does that register hold, is this set point what the
operators expect, does the controller still run the known-good parameters? It is
used twice: in [identification](../phases/identification.md) to confirm what a
host was polling or writing, and in [eradication](../phases/eradication.md) to
compare live values against a verified baseline before a controller returns to
automatic. Reads are the default; a write happens only when the engineer directs
one. Because the protocols carry no authentication, the device cannot tell your
reads from an adversary's, so this is announced like any active work.

## Before you start

- The engineer responsible for the device present and agreeing to each read and
  any write (the [writes wire class](../wire-classes.md) rule).
- Written approval and an agreed window; the site's monitoring told.
- A capture or baseline showing the traffic to reproduce, and, for eradication,
  the engineer's known-good list of set points, parameters and programs.

## Procedure

1. **Locate the conversation.** In the [tshark](../../tools/traffic/tshark.md)
   capture, find the device, protocol, unit id and the registers or tags the
   suspect host touched (for Modbus, filter on the write function codes).
   - *Record:* the address, unit id, register range and what the capture showed
     being read or written.
   - *Looks for:* [Collection](../attack-ics/collection.md), Monitor Process State
     (T0801), what the adversary was learning.

2. **Read, once, with the engineer.** Read those exact references a single time
   with [mbpoll](../../tools/protocols/mbpoll.md) (`-1`),
   [pymodbus](../../tools/protocols/pymodbus.md) or, for S7 and OPC UA,
   [python-snap7](../../tools/protocols/python-snap7.md) and the
   [OPC UA CLI tools](../../tools/protocols/opcua-cli-tools.md). Reads only.
   - *Record:* the command and the values returned, with the UTC time.
   - *Go/no-go:* one unit id and a small range at a time; if the device degrades,
     stop.

3. **Compare with what is expected.** Check the values against what operators say
   they should be, or against the known-good list.
   - *Record:* each value and whether it matches.
   - *Looks for:* [Impair Process Control](../attack-ics/impair-process-control.md),
     Modify Parameter (T0836): a value that does not match may be the adversary's
     change still in place, or a gap in the baseline.

4. **In eradication, read back the baseline.** Before the cleaned controller
   returns to automatic, read its set points, parameters and program state and
   confirm they match the known-good copy, not whatever is currently running.
   - *Record:* the comparison, and resolve every difference with the engineer.

5. **Correct only on the engineer's instruction.** If a value must be set from the
   laptop, the engineer directs the exact register and value, you write it once
   (mbpoll `-1`), read it back, and record both commands. This is a
   [writes](../wire-classes.md) action.
   - *Looks for:* [Impair Process Control](../attack-ics/impair-process-control.md),
     Unauthorized Message, Command Message (T1692.001): the same write the SOC
     must be told about.

6. **Hash the notes.** Append the read and write logs to the case `SHA256SUMS`.

## Done when

- The registers, tags or parameters in question are read and compared against
  known-good, and every difference is explained or corrected.
- Any correction was directed by the engineer, written once, read back and
  recorded.
- The reads, writes and their values are saved and hashed.

## Related pages

- [Active enumeration](active-enumeration.md): identify the device before you read it.
- [Firmware acquisition](firmware-acquisition.md): when the suspect change is in firmware, not a register.
- [Evidence handling](../evidence-handling.md): recording reads, writes and times.
