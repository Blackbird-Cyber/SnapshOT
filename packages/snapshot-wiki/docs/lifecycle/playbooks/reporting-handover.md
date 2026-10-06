---
title: Reporting and handover
summary: Verify the evidence, build a UTC timeline, map each finding to ATT&CK for ICS, write the report in process terms, and hand over with the media wiped and logged.
phases: [lessons-learned]
---

The engagement ends in [lessons learned](../phases/lessons-learned.md): a report
that explains the incident to the people who run the plant, in terms of the
process, the safety margins used and the controls that would have changed the
outcome. This playbook turns a case folder into that report and closes the chain
of custody. It feeds straight back into the next
[preparation](../phases/preparation.md).

## Before you start

- A complete [case folder](../evidence-handling.md): captures, scans, reads,
  firmware, host triage, notes, the running `SHA256SUMS` and the
  chain-of-custody log.
- The process owner and the audience for the report agreed.

## Procedure

1. **Verify the evidence.** Re-check the case against its hashes
   (`sha256sum -c SHA256SUMS`) and confirm the chain-of-custody log and form are
   complete.
   - *Go/no-go:* evidence that does not verify, or whose custody is unclear, does
     not go in the report until it is explained.

2. **Build the timeline.** In UTC, assemble events from the captures
   ([tshark](../../tools/traffic/tshark.md) conversation and first-and-last-seen
   data, exported as CSV), the scan and read logs, the field kit stamps and the
   operator reports.
   - *Record:* one ordered UTC timeline, noting any `stamp=local` collection.

3. **Map findings to ATT&CK for ICS.** For each finding, name the tactic, the
   technique id and the evidence behind it, using the
   [ATT&CK for ICS](../attack-ics/index.md) pages and the
   [matrix](../matrix.md). Mapping the incident this way gives the gaps a shared
   vocabulary.
   - *Record:* a finding-to-technique table with evidence references.

4. **Write the report in process terms.** Draft in [CherryTree](../../tools/reporting/cherrytree.md)
   notes and produce the document with [pandoc](../../tools/reporting/pandoc.md)
   or [LibreOffice](../../tools/reporting/libreoffice.md). Explain the incident by
   its effect on safety, production and equipment, and name the control gaps
   against the SANS Five ICS Critical Controls, as the
   [crosswalk](../crosswalk.md) lays them out.
   - *Record:* the report draft in the case's `report/` folder.

5. **Illustrate and protect secrets.** Capture screens with
   [Flameshot](../../tools/reporting/flameshot.md) for the report, and keep any
   credentials gathered during the engagement in
   [KeePassXC](../../tools/reporting/keepassxc.md), never in the report body.

6. **Hand over and close out.** Deliver the report to the process owner. Return or
   securely wipe the media with [nwipe](../../tools/reporting/nwipe.md) so one
   client's data never reaches another, and log the transfer and the wipe in the
   chain-of-custody log.
   - *Record:* delivery, media disposition and the wipe, all dated and signed.

7. **Feed the next preparation.** Record the control gaps and detections that
   worked so the next [preparation](../phases/preparation.md) starts from what
   happened here.

## Done when

- Every finding is evidenced, verified and mapped to a tactic and technique.
- The report is delivered to the process owner in terms they can act on.
- The media is wiped or returned and the chain-of-custody log is closed.
- The lessons are written down for the next engagement.

## Related pages

- [Evidence handling](../evidence-handling.md): the case folder, hashing and custody this closes out.
- [Lessons learned](../phases/lessons-learned.md): the phase this playbook serves.
- [Crosswalk](../crosswalk.md): PICERL against CSF 2.0, SP 800-82r3 and the SANS controls.
