---
title: Lessons Learned
summary: Build the timeline, write the report, name the control gaps and hand over, so the next preparation starts from what happened.
---

## Definition and OT reading

Lessons learned turns an incident, or an assessment, into changes that make the
next one less likely or less harmful. NIST SP 800-61r3 no longer treats it as a
meeting after recovery: lessons go into the Improvement category of Identify
(ID.IM) whenever they are found, and from there into every function, including
the response plans themselves (ID.IM-04). NIST SP 800-82r3 asks for someone to be
designated to document response actions as they happen, so that they can be
reviewed later, and accepts logs, video and interviews where recording on the spot
would slow a safety-critical response.

On a plant floor the audience decides the shape of the work. **The report goes to
people who run a plant**: it explains the incident in terms of the process, the
safety margins that were used up and the controls that would have changed the
outcome. Mapping the incident to MITRE ATT&CK for ICS gives those gaps a shared
vocabulary with the security team, the vendors and other sites. Four products
come out of this phase.

### The timeline

One table, in UTC, from the first trace of the adversary to the end of recovery.
Its sources are the case folder and the site's own records:

- capture files, with their start and end times ([tshark](../../tools/traffic/tshark.md)
  conversations and statistics, [tcpflow](../../tools/traffic/tcpflow.md) for the
  content of sessions);
- field kit collections, whose folder names and `summary.txt` carry a UTC stamp
  (a cmd fallback without wmic records `stamp=local`, which needs converting), and
  the `chain-of-custody.log` of each import;
- disk timelines from [The Sleuth Kit](../../tools/forensics/sleuthkit.md)
  (`fls -m` and `mactime`);
- the historian, alarm and event journals, operator logs and the engineering
  workstation's project history, from the asset owner;
- the team's own log of every command, scan and action, with its UTC time.

Record the clock offset of every source, starting with the laptop's own (checked
in [preparation](preparation.md)). Controllers and HMIs often keep local time with
no synchronization. Mark the team's own actions in the timeline, so that a scan
SnapshOT ran is never read later as the adversary's Discovery.

### Mapping the incident to ATT&CK for ICS

For each adversary event in the timeline, record the tactic, the technique where
the evidence supports it, the evidence and its hash, when it first became visible
and when it was detected. Use the ids in this wiki's
[ATT&CK for ICS](../attack-ics/index.md) pages, which follow ATT&CK v19 (several
techniques moved to the T16xx range, for example T1693 Modify Firmware). Two
illustrative rows:

| UTC | Tactic | Technique | Evidence | Visible from | Detected |
|---|---|---|---|---|---|
| (time) | [Discovery](../attack-ics/discovery.md) | T0846 Remote System Discovery | capture file and SHA-256 | first scan packet | operator report, two days later |
| (time) | [Lateral Movement](../attack-ics/lateral-movement.md) | T0843 Program Download | capture file and SHA-256 | the download session | identification capture |

A tactic without a technique is fine; a technique without evidence is not. The
gap between "visible from" and "detected" is the most useful number in the report:
it shows which monitoring would have shortened the incident. The
[matrix](../matrix.md) shows which SnapshOT tools detect or investigate each
tactic, and the [crosswalk](../crosswalk.md) places each event in the two stages
of the ICS Cyber Kill Chain.

### The report to plant people

Write for the process owner, the site manager and the engineers first, and the
security team second:

- **what happened to the process**: safety, production, equipment and
  environment, and which safety margins were used up;
- **the timeline** and the ATT&CK for ICS mapping, in plain words beside the ids;
- **what was done in each phase**, by whom and on whose authority, including the
  team's own activity on the network;
- **the evidence**: what was collected, its hashes and its chain of custody;
- **the control gaps**, grouped by the SANS Five ICS Critical Controls, each
  with the change that would have helped, an owner and a date.

[LibreOffice](../../tools/reporting/libreoffice.md),
[CherryTree](../../tools/reporting/cherrytree.md),
[Flameshot](../../tools/reporting/flameshot.md) and
[pandoc](../../tools/reporting/pandoc.md) produce the report on the laptop, with
no network. The [reporting and hand-over playbook](../playbooks/reporting-handover.md)
walks through it.

### The hand-over

- **Evidence and custody** go to the client as agreed in the
  [rules of engagement](../rules-of-engagement.md): the case folder, its hashes
  and the chain-of-custody log ([evidence handling](../evidence-handling.md)).
- **Credentials** the team received are returned or destroyed, and the client
  resets any that were used.
- **The next preparation** receives the updated baseline, the new or changed
  containment options, the changed response plan and the list of controls to
  build.
- **The laptop** is wiped and re-imaged before the next client
  ([nwipe](../../tools/reporting/nwipe.md) for media,
  [field updates](../../platform/field-updates.md) for the re-image), and the
  field kit stick is prepared fresh.

## Entry and exit criteria

**Enter when**

- recovery is declared complete; or
- an assessment's fieldwork ends; or
- a lesson is clear during an earlier phase. Record it then: SP 800-61r3 asks for
  lessons to be shared as soon as they are identified, not held until recovery
  ends.

**Leave when**

- the timeline and the ATT&CK for ICS mapping are complete, with the evidence for
  each entry;
- the report has been delivered and walked through with the process owner and the
  engineers;
- every control gap has an owner and a date;
- evidence and custody are handed over as agreed; and
- the laptop and the field kit stick are wiped, and the next preparation has its
  inputs.

## Decisions and authorizations

- **Who receives the report**, at what classification and in what form, is the
  asset owner's decision.
- **What evidence is kept**, by whom and for how long, follows the rules of
  engagement; any change is agreed in writing.
- **Disclosure** to vendors, regulators or a sector CERT is the asset owner's
  decision under the site's plan; the team advises.
- **Which recommendations are accepted**, and their owners and dates, are decided
  by the asset owner with the process owner.
- **Closing the engagement**: the incident commander and the asset owner sign off
  the hand-over.

## ATT&CK for ICS tactics in play

All twelve. Lessons learned maps the whole incident to the matrix, so that each
tactic the adversary used is recorded with how it was seen, or why it was not.

<!-- snapshot:phase-tactics -->

## Tools in this phase

Generated from every tool page that describes a use in lessons learned: analysis
of the case evidence, the report, and wiping the kit for the next client.

<!-- snapshot:phase-tools -->

## Playbooks for this phase

<!-- snapshot:phase-playbooks -->

## Crosswalk

<!-- snapshot:phase-crosswalk -->

SP 800-61r3 places lessons learned in Improvement (ID.IM): improvements from
evaluations, from tests and exercises, and from the execution of operational
processes, with the response plans maintained and improved (ID.IM-04). SnapshOT
also maps this phase to Govern, because the report and its control gaps go to the
people who set the site's policy and oversee its risk. SP 800-82r3 has the same
loop for OT in its Response Improvements (RS.IM) and Recovery Improvements (RC.IM)
sections, written against the CSF 1.1 categories. See the
[crosswalk](../crosswalk.md).

## Pitfalls and stop conditions

**Pitfalls**

- Writing for the SOC instead of the plant: technique ids without the process
  impact beside them.
- Mapping techniques the evidence does not support, to make the matrix look
  complete.
- Leaving the team's own activity out of the timeline, or the clock offsets out
  of the evidence.
- Blame. Operators and engineers who expect blame stop reporting the oddities that
  start the next identification.
- Recommendations without owners and dates.
- Client data left on the laptop or the field kit stick after the hand-over.

**Stop and go back to the process owner when**

- the analysis shows activity after recovery was declared (return to
  identification);
- the evidence suggests a safety, alarm or protection function was affected and
  was not tested in recovery;
- custody of the evidence cannot be established for the hand-over; or
- findings concern systems or third parties outside the authorization; the asset
  owner decides what happens next.
