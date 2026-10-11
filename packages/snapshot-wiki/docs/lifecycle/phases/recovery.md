---
title: Recovery
summary: Restore from verified images, validate the process communications with the process owner and watch for recurrence.
---

## Definition and OT reading

Recovery returns the affected systems and the process to normal operation. In
IT it ends when the services are back and the hosts are clean. On a plant floor
recovery is complete when **the process owner says the process is safe and
producing**, not when the hosts are clean. NIST SP 800-82r3 is explicit about the
order: recovery prioritizes human and environmental safety before the OT
operation is restarted, and restoration can follow the plant's own start-up
order, for example the systems that support critical utilities before those that
support manufacturing.

Recovery therefore runs **in stages**, each one checked before the next:

1. **Restore** from verified sources only: images, logic, configurations and
   firmware whose hashes match the known-good record. NIST SP 800-61r3 asks for
   the integrity of backups and other restoration assets to be verified before
   they are used.
2. **Prove the protective functions.** Alarms, interlocks, safety instrumented
   functions and protection relays are tested, by the people who own them, before
   the process returns to normal operation.
3. **Validate communications.** Fresh captures of each restored segment are
   compared with the baseline from [preparation](preparation.md): the same
   hosts, the same protocols and function codes, the same polling, and nothing
   new. [tshark](../../tools/traffic/tshark.md) and
   [Wireshark](../../tools/traffic/wireshark.md) show the conversations;
   [Suricata](../../tools/traffic/suricata.md) can watch for the indicators found
   during the incident.
4. **Verify the values.** With approval and the engineer present, read-only
   polls with the protocol tools (for example [mbpoll](../../tools/protocols/mbpoll.md))
   confirm that registers, set points and modes match what the engineer expects.
   Where the operators' view may have been manipulated, check values at the plant
   as well as on the HMI.
5. **Return to automatic** controller by controller, as the process owner
   directs, and keep watching.

Monitoring stays in place after the incident is closed. Recurrence is the
clearest sign that eradication missed something.

## Entry and exit criteria

**Enter when**

- eradication is verified: footholds removed, access paths closed, logic and
  firmware matching the baseline;
- the order of restoration is agreed with the process owner and operations; and
- the protective functions can be tested and the monitoring for recurrence is in
  place.

**Leave when**

- the process owner declares the process safe and in normal operation;
- alarms, safety and protection functions have been proven to work;
- the restored systems' communications match the baseline, or each difference is
  explained and accepted by the asset owner;
- temporary containment measures are removed, or made permanent by decision;
- monitoring for recurrence is agreed: how long, what it watches, and what sends
  the team back to identification; and
- the end of recovery is declared and the records of what was done are complete.

## Decisions and authorizations

- **The order of restoration** belongs to the process owner and operations,
  usually following the plant's start-up procedures.
- **Return to automatic control** for each controller is the process owner's
  decision, on the word of the engineer responsible after verification.
- **Removing containment measures** is decided by the process owner, the network
  owner and the incident commander together; the network owner makes the change.
- **Any read-only poll** to verify values is approved per device and run with the
  engineer present; any write is the engineer's, not the team's.
- **Declaring the end of recovery** is the process owner's and the incident
  commander's call, against criteria agreed beforehand.
- **Recovery communication** to staff, management and outside parties follows the
  site's plan.

## ATT&CK for ICS tactics in play

Recovery undoes the effects of the tactics that touch the process. It proves that
response functions work again, that process control is in the expected hands, and
it records what was lost for the report.

<!-- snapshot:phase-tactics -->

## Tools in this phase

Generated from every tool page that describes a use in recovery. Passive
comparison with the baseline comes first; active verification is the exception,
approved per device.

<!-- snapshot:phase-tools -->

## Playbooks for this phase

<!-- snapshot:phase-playbooks -->

## Crosswalk

<!-- snapshot:phase-crosswalk -->

In the SP 800-61r3 profile, recovery is incident recovery plan execution (RC.RP):
verifying restoration assets before use (RC.RP-03), restoring essential functions
in the right order with the system owners (RC.RP-04), verifying restored assets
and confirming normal operating status (RC.RP-05), and declaring the end of
recovery against criteria (RC.RP-06), together with recovery communication
(RC.CO). See the [crosswalk](../crosswalk.md).

## Pitfalls and stop conditions

**Pitfalls**

- Declaring recovery from IT signs (clean hosts, services up) without the process
  owner's confirmation.
- Restoring everything at once, so that a problem cannot be traced to one change.
- Returning to normal operation with a bypass, a forced value or a disabled alarm
  still in place from the manual period.
- Removing containment measures before monitoring has shown that the adversary
  is gone.
- Stopping monitoring the day the incident closes.
- Restoring from a copy whose hash was never recorded, or whose date falls inside
  the incident.

**Stop and hand control back to the process owner when**

- the traffic shows recurrence: a new beacon, an unexpected session or an
  unauthorized write (return to identification);
- restored values, modes or logic differ from what the engineer expects;
- a safety, alarm or protection function fails its test; or
- the process behaves unexpectedly on the return to automatic control.
