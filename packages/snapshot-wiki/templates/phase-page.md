---
# Copy to docs/lifecycle/phases/<id>.md, where <id> is one of the phase ids in
# data/lifecycle.yaml: preparation | identification | containment | eradication
# | recovery | lessons-learned. The H1, the "Phase N of 6" badge and the CSF
# badges come from data/lifecycle.yaml; do not write an H1. The four
# <!-- snapshot:phase-* --> markers are replaced at build time; keep them on a
# line of their own under their headings. Remove these comments.
title: PHASE NAME
summary: ONE LINE (the same idea as `summary` in data/lifecycle.yaml)
---

## Definition and OT reading

What the phase is in PICERL and why it differs on a plant floor: safety,
process continuity and the process owner's authority.

## Entry and exit criteria

**Enter when** ... **Leave when** ... (bullets).

## Decisions and authorizations

Who decides what in this phase, and what must be agreed in writing before the
team acts (bullets).

## ATT&CK for ICS tactics in play

One or two sentences of context; the table is generated from
data/lifecycle.yaml (`tactics:` of this phase).

<!-- snapshot:phase-tactics -->

## Tools in this phase

One or two sentences; the table is generated from every tool page whose
`phases:` lists this phase.

<!-- snapshot:phase-tools -->

## Playbooks for this phase

<!-- snapshot:phase-playbooks -->

## Crosswalk

<!-- snapshot:phase-crosswalk -->

Optional prose after the generated table.

## Pitfalls and stop conditions

The mistakes that hurt a process in this phase, and the conditions under which
the team stops and hands control back to the process owner (bullets).
