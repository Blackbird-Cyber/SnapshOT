---
title: Lifecycle
summary: The SANS PICERL incident-response lifecycle, read for OT field work, cross-walked to NIST CSF 2.0 and mapped to MITRE ATT&CK for ICS.
---

SnapshOT organises an engagement around the six phases of **PICERL**:
Preparation, Identification, Containment, Eradication, Recovery and Lessons
Learned. It is the incident-response model SANS teaches, and its ICS courses
adapt it to industrial control systems. Each phase page says what the phase
means on a plant floor, what must be decided and by whom, which adversary
tactics it is about and which SnapshOT tools serve it.

## The six phases

<!-- snapshot:phases -->

## Why PICERL fits OT field work

An IT response can isolate a host the moment it looks compromised. On a plant
floor the same action can stop a process, trip a safety system or damage
equipment, and the person who decides is the process owner, not the responder.
PICERL puts that decision in the right place:

- **Preparation** carries most of the weight. The safe states, the actions that
  are pre-authorised, the engineer who must be present for any write and the
  known-good baseline are all agreed before an incident, so that later phases can
  act quickly without improvising on live equipment.
- **Identification** is passive first. Captures, protocol decoding and operator
  reports scope the incident before anything is sent to a controller, and
  triage asks what the incident means for the physical process.
- **Containment, eradication and recovery** are negotiated with physics. Each
  action is one the plan allows, taken with the process owner, verified from
  both sides of the boundary and recorded as evidence.
- **Lessons learned** feeds the next preparation: the report explains the
  incident in terms of the process and names the controls that would have
  changed the outcome.

## Frameworks behind it

- **NIST CSF 2.0** groups cybersecurity outcomes into six functions: Govern,
  Identify, Protect, Detect, Respond and Recover. NIST SP 800-61r3 recasts
  incident response around those functions, and each phase page shows the
  functions it serves.
- **NIST SP 800-82r3**, the guide to operational technology security, sets out
  what OT incident response must account for: safety, process continuity and
  the asset owner's authority at every step.
- **MITRE ATT&CK for ICS** names what the adversary is doing. Each phase lists
  the tactics it is about, and each tool page says which tactics the tool
  detects, investigates or resembles. See [ATT&CK for ICS](attack-ics/index.md).

## Phases and tools

The graph links every phase to the tools whose pages describe a use in it.
Tools are coloured by their menu folder. Click a node to open its page.

<div class="snapshot-graph" data-graph="lifecycle" data-height="600">
<p class="snapshot-graph__fallback">This graph needs JavaScript; the same links are in the matrix.</p>
</div>

The [matrix](matrix.md) shows the same data as tables: every tool against the six
phases and against the twelve tactics.
