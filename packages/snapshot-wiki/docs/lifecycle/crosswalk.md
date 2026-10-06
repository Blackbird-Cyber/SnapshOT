---
title: Crosswalk
summary: How the PICERL phases line up with NIST CSF 2.0 and SP 800-61r3, NIST SP 800-82r3, the SANS Five ICS Critical Controls, the ICS Cyber Kill Chain and the ATT&CK for ICS tactics.
---

SnapshOT organises an engagement around the six PICERL phases. The other
frameworks are not competing lifecycles: each answers a different question about
the same work, and the wiki uses each one for something specific.

| Framework | The question it answers | Where SnapshOT uses it |
|---|---|---|
| SANS PICERL | What do we do next? | The phase pages, the PICERL mapping on every tool page, the playbooks |
| NIST CSF 2.0 and SP 800-61r3 | Which cybersecurity outcome does this serve? | The CSF functions on phase and tool pages; the language of the client's governance |
| NIST SP 800-82r3 | What does OT add to incident response? | The OT reading of each phase: safety, continuity, the process owner's authority |
| SANS Five ICS Critical Controls | What should a site have in place? | The preparation checklist and the control gaps in the report |
| ICS Cyber Kill Chain | How far has the adversary got? | Triage in identification, urgency in containment, the account in the report |
| MITRE ATT&CK for ICS | What exactly is the adversary doing? | The tactics in play on each phase page, each tool's role, the incident mapping |

The graph puts the phases in the middle, the CSF 2.0 functions they serve on the
left and the ATT&CK for ICS tactics in play on the right. Lessons learned maps the
whole incident to all twelve tactics (dashed). Hover a node to highlight its
links; click a phase or a tactic to open its page.

<div class="snapshot-graph" data-graph="crosswalk" data-height="640">
<p class="snapshot-graph__fallback">This graph needs JavaScript; the tables on this page show the same mapping.</p>
</div>

## The phases at a glance

| Phase | NIST CSF 2.0 | SANS controls | ATT&CK for ICS tactics in play |
|---|---|---|---|
| 1. [Preparation](phases/preparation.md) | Govern, Identify, Protect | 1, 2, 3 | Initial Access, Lateral Movement |
| 2. [Identification](phases/identification.md) | Detect | 3 | Discovery, Collection, Command and Control, Lateral Movement, Evasion |
| 3. [Containment](phases/containment.md) | Respond | 1, 2, 4 | Command and Control, Lateral Movement, Inhibit Response Function, Impair Process Control |
| 4. [Eradication](phases/eradication.md) | Respond | 1, 5 | Persistence, Execution, Privilege Escalation, Impair Process Control |
| 5. [Recovery](phases/recovery.md) | Recover | 1, 3 | Impact, Inhibit Response Function, Impair Process Control |
| 6. [Lessons Learned](phases/lessons-learned.md) | Govern, Identify | all five | all twelve |

Each phase page renders its own row of this crosswalk from the same data, with
the SP 800-61r3 and SP 800-82r3 anchors.

## SANS PICERL

**What it is.** The six-step incident handling process SANS teaches:
Preparation, Identification, Containment, Eradication, Recovery and Lessons
Learned, written up for SANS in Patrick Kral's
[Incident Handler's Handbook](https://www.sans.org/white-papers/33901/) and
adapted to industrial control systems in its ICS courses. It is more finely
divided than the four phases of the earlier NIST SP 800-61r2 (preparation;
detection and analysis; containment, eradication and recovery; post-incident
activity), and that suits OT: containment, eradication and recovery each change
something on the plant floor, and each needs its own decision by the process
owner.

**How SnapshOT uses it.** PICERL is the spine of the wiki. The six phase ids are
fixed in the lifecycle data; every tool page says how the tool is used in each
phase it serves, every playbook belongs to one or two phases, and the
[matrix](matrix.md) shows the tools against the phases.

## NIST CSF 2.0 and SP 800-61r3

**What they are.** The [NIST Cybersecurity Framework 2.0](https://www.nist.gov/cyberframework)
(NIST CSWP 29, February 2024) groups cybersecurity outcomes into six functions:
Govern, Identify, Protect, Detect, Respond and Recover. Govern is new in 2.0.
[NIST SP 800-61r3](https://csrc.nist.gov/pubs/sp/800/61/r3/final), *Incident
Response Recommendations and Considerations for Cybersecurity Risk Management: A
CSF 2.0 Community Profile* (April 2025), recasts incident response around those
functions and replaces the circular life cycle of SP 800-61r2. In its model,
Govern, Identify and Protect are preparation: broader risk management that also
supports incident response. Detect, Respond and Recover are the response itself.
The Improvement category of Identify (ID.IM) takes in lessons learned from every
function, at any time, rather than only after recovery.

**How SnapshOT uses them.** Each phase page shows the CSF functions it serves and
each tool page lists its own (`csf:`), so a finding can be reported in the terms
the client's governance already uses. The categories below come from the SP
800-61r3 profile; they are the vocabulary for the report.

| Phase | CSF 2.0 functions | SP 800-61r2 phase it corresponds to | CSF 2.0 categories that carry it |
|---|---|---|---|
| Preparation | Govern, Identify, Protect | Preparation | GV.RR Roles, Responsibilities, and Authorities; GV.PO Policy; ID.AM Asset Management; ID.RA Risk Assessment; PR.PS Platform Security; PR.IR Technology Infrastructure Resilience |
| Identification | Detect | Detection and Analysis | DE.CM Continuous Monitoring; DE.AE Adverse Event Analysis, through estimating impact and scope (DE.AE-04) to declaring the incident (DE.AE-08) |
| Containment | Respond | Containment, Eradication and Recovery | RS.MA Incident Management; RS.AN Incident Analysis; RS.CO Incident Response Reporting and Communication; RS.MI Incident Mitigation (RS.MI-01, incidents are contained) |
| Eradication | Respond | Containment, Eradication and Recovery | RS.MI Incident Mitigation (RS.MI-02, incidents are eradicated); RS.AN-03, establishing what happened and the root cause |
| Recovery | Recover | Containment, Eradication and Recovery | RC.RP Incident Recovery Plan Execution (RC.RP-03 verifies restoration assets before use, RC.RP-06 declares the end of recovery); RC.CO Incident Recovery Communication |
| Lessons Learned | Govern, Identify | Post-Incident Activity | ID.IM Improvement (ID.IM-01 to ID.IM-04, including improving the response plans); Govern because the report and its control gaps go to the people who set policy and oversee risk |

SP 800-61r3 also maps the earlier detection, containment, eradication and recovery
phases to the Improvement category: lessons are recorded during every phase, not
saved for the last one.

## NIST SP 800-82r3

**What it is.** [NIST SP 800-82r3](https://csrc.nist.gov/pubs/sp/800/82/r3/final),
*Guide to Operational Technology (OT) Security* (September 2023), is NIST's
guidance on securing OT while respecting its performance, reliability and safety
requirements. Its incident-response guidance is spread across the programme
sections (3.3.8, an incident response capability; 3.3.9, a recovery and
restoration capability) and the sections that apply the Cybersecurity Framework to
OT (section 6). Section 6 was written against CSF 1.1, before CSF 2.0, so its
category ids (RS.RP, RS.IM, RC.IM, PR.IP) differ from those in SP 800-61r3.

**How SnapshOT uses it.** It supplies the OT reading of every phase: safety
first, process continuity, and the asset and process owners' authority over what
is touched.

| Phase | What SP 800-82r3 asks for | Sections |
|---|---|---|
| Preparation | An incident response plan with roles, workflow, incident classification, contacts and communication; reviewed and approved by operations, engineering, IT, vendors, management, organized labor, legal and safety; kept on paper or an offline system; backups verified, kept on site and off site, restoration tested; recovery time and point objectives | 3.3.8, 3.3.9, 6.2.4.3, 6.2.4.5 |
| Identification | Anomaly detection, continuous monitoring and tested detection processes; analysis that weighs OT's dependencies on other systems and classifies incidents, including accidental actions by authorized staff as well as targeted and untargeted attacks | 6.3, 6.4.3 |
| Containment | Response actions from doing nothing to a full shutdown: disconnecting systems, isolating networks that can run independently (enterprise from control, control from safety), manual operation with extra staff to validate data; a focused risk assessment before isolating; impacts of shutdowns and disconnects understood and communicated | 6.2.4.5, 6.4.4 |
| Eradication | Mitigation that resolves the incident; software for OT maintenance obtained from the vendor with its authenticity verified, for example by comparing installer hashes | 6.4.4, 6.2.5 |
| Recovery | Human and environmental safety before the process restarts; restoring state, data, configuration and programs from backups; an order of recovery that can follow the start-up procedures; bench tests where live tests are unsafe, and at least verified backups; recovery communication | 3.3.9, 6.2.4.5, 6.5 |
| Lessons Learned | Capturing how the response and recovery plans were executed (logs, video or interviews where recording would slow a safety-critical response); someone designated to document response actions; improved response and recovery plans | 6.4.1, 6.4.5, 6.5.1, 6.5.2 |

## SANS Five ICS Critical Controls

**What they are.** [The Five ICS Cybersecurity Critical Controls](https://www.sans.org/white-papers/five-ics-cybersecurity-critical-controls/)
(Robert M. Lee and Tim Conway, SANS, November 2022) are the five controls the
authors consider most relevant to an ICS and OT security strategy, written to flex
to each organization's risk model.

**How SnapshOT uses them.** As the [preparation](phases/preparation.md) checklist,
as the anchors in each phase's crosswalk row, and as the headings under which the
report groups the control gaps.

| Control | Phases it anchors | What it means for a field team |
|---|---|---|
| 1. ICS Incident Response | Preparation, Containment, Eradication, Recovery, Lessons Learned | An ICS-specific plan, with the process owner's authority, safe states and pre-authorised containment, exercised before it is needed |
| 2. Defensible Architecture | Preparation, Containment, Lessons Learned | Zones and conduits that can be isolated without stopping the process, and captures that prove the segmentation holds |
| 3. ICS Network Visibility and Monitoring | Preparation, Identification, Recovery, Lessons Learned | SPAN or TAP points, a baseline, and monitoring that decodes the industrial protocols |
| 4. Secure Remote Access | Containment, Lessons Learned | Remote access paths known, controlled and cut cleanly when needed |
| 5. Risk-Based Vulnerability Management | Eradication, Lessons Learned | The weaknesses the adversary used are closed, ranked by consequence to the process |

## ICS Cyber Kill Chain

**What it is.** [The Industrial Control System Cyber Kill Chain](https://www.sans.org/white-papers/36297/)
(Michael J. Assante and Robert M. Lee, SANS Institute, October 2015) adapts the
Lockheed Martin Cyber Kill Chain to ICS. It argues that an attack with a
significant and predictable effect on a process needs two stages. **Stage 1, Cyber
Intrusion Preparation and Execution**, is close to what IT calls a breach, and is
where much of the intrusion activity and espionage takes place. **Stage 2, ICS Attack Development and
Execution**, uses what Stage 1 learned to build, test and deliver a capability
against that specific system. Two stages give defenders more chances to detect the
adversary. The paper also warns that Stage 1 activity can have unintended effects:
actively discovering hosts on an ICS network may disrupt communications or cause
communication cards to fail. SnapshOT's own active tools carry the same risk, which
is why the [rules of engagement](rules-of-engagement.md) limit them.

**How SnapshOT uses it.** In identification, place each piece of evidence in a
stage. Stage 1 evidence is serious but usually leaves time to scope. Stage 2
evidence (program downloads, changed parameters or firmware, suppressed alarms)
puts safety and the process owner first and shortens the road to containment. In
lessons learned, the report says how far the adversary got. The tactic column is
SnapshOT's reading; the paper predates ATT&CK for ICS.

| Stage | Phase (as the paper names it) | Steps | ATT&CK for ICS tactics where it shows | Where a field team meets it |
|---|---|---|---|---|
| 1 | Planning | Reconnaissance | None: it happens away from the site | Preparation: know what is exposed |
| 1 | Preparation | Weaponization, Targeting | None: away from the site | Preparation |
| 1 | Cyber Intrusion | Delivery, Exploit, Install/Modify | Initial Access, Execution, Persistence | Identification, Eradication |
| 1 | Management and Enablement | Command and Control | Command and Control | Identification, Containment |
| 1 | Sustainment, Entrenchment, Development, and Execution | Act | Discovery, Collection, Lateral Movement, Privilege Escalation, Evasion | Identification, Containment, Eradication |
| 2 | Attack Development and Tuning | Develop | None: built away from the site, from stolen data | Lessons Learned: what Collection took |
| 2 | Validation | Test | None: tested on similar systems elsewhere | Not visible from the site |
| 2 | ICS Attack | Deliver, Install/Modify, Execute ICS Attack | Lateral Movement, Execution, Inhibit Response Function, Impair Process Control, Impact | Containment, Eradication, Recovery |

## MITRE ATT&CK for ICS

**What it is.** [MITRE ATT&CK for ICS](https://attack.mitre.org/matrices/ics/) is a
knowledge base of how adversaries behave inside industrial control systems, built
from observed incidents: twelve tactics (the adversary's goal at a stage) and the
techniques that achieve them. The wiki follows ATT&CK v19.

**How SnapshOT uses it.** Each phase lists the tactics it is about; each tool page
says whether the tool detects, investigates or resembles its tactics, with
technique ids only where certain; lessons learned maps the incident to the matrix.
The [ATT&CK for ICS](attack-ics/index.md) section explains what a field kit can and
cannot see for each tactic, and the [matrix](matrix.md) lists the tools against
the tactics.

| Tactic | ID | Phases where it is in play | ICS Cyber Kill Chain (SnapshOT's reading) |
|---|---|---|---|
| [Initial Access](attack-ics/initial-access.md) | TA0108 | Preparation, Lessons Learned | Stage 1, Cyber Intrusion |
| [Execution](attack-ics/execution.md) | TA0104 | Eradication, Lessons Learned | Stage 1, Cyber Intrusion and Act; Stage 2, ICS Attack |
| [Persistence](attack-ics/persistence.md) | TA0110 | Eradication, Lessons Learned | Stage 1, Install/Modify and Act |
| [Privilege Escalation](attack-ics/privilege-escalation.md) | TA0111 | Eradication, Lessons Learned | Stage 1, Act |
| [Evasion](attack-ics/evasion.md) | TA0103 | Identification, Lessons Learned | Stage 1, Act; Stage 2, ICS Attack |
| [Discovery](attack-ics/discovery.md) | TA0102 | Identification, Lessons Learned | Stage 1, Act |
| [Lateral Movement](attack-ics/lateral-movement.md) | TA0109 | Preparation, Identification, Containment, Lessons Learned | Stage 1, Act; Stage 2, Deliver |
| [Collection](attack-ics/collection.md) | TA0100 | Identification, Lessons Learned | Stage 1, Act, feeding Stage 2 development |
| [Command and Control](attack-ics/command-and-control.md) | TA0101 | Identification, Containment, Lessons Learned | Stage 1, Management and Enablement |
| [Inhibit Response Function](attack-ics/inhibit-response-function.md) | TA0107 | Containment, Recovery, Lessons Learned | Stage 2, ICS Attack |
| [Impair Process Control](attack-ics/impair-process-control.md) | TA0106 | Containment, Eradication, Recovery, Lessons Learned | Stage 2, ICS Attack |
| [Impact](attack-ics/impact.md) | TA0105 | Recovery, Lessons Learned | Stage 2, ICS Attack, or an unintended effect of Stage 1 |

Tactic ids and names are from MITRE ATT&CK for ICS (v19). © 2026 The MITRE
Corporation. This work is reproduced and distributed with the permission of The
MITRE Corporation. ATT&CK is a registered trademark of The MITRE Corporation.

## Sources

- Patrick Kral, [Incident Handler's Handbook](https://www.sans.org/white-papers/33901/), SANS Institute.
- NIST, [Cybersecurity Framework 2.0](https://www.nist.gov/cyberframework), NIST CSWP 29, February 2024 ([doi:10.6028/NIST.CSWP.29](https://doi.org/10.6028/NIST.CSWP.29)).
- NIST, [SP 800-61r3](https://csrc.nist.gov/pubs/sp/800/61/r3/final), April 2025 ([doi:10.6028/NIST.SP.800-61r3](https://doi.org/10.6028/NIST.SP.800-61r3)).
- NIST, [SP 800-82r3](https://csrc.nist.gov/pubs/sp/800/82/r3/final), September 2023.
- Robert M. Lee and Tim Conway, [The Five ICS Cybersecurity Critical Controls](https://www.sans.org/white-papers/five-ics-cybersecurity-critical-controls/), SANS, November 2022.
- Michael J. Assante and Robert M. Lee, [The Industrial Control System Cyber Kill Chain](https://www.sans.org/white-papers/36297/), SANS Institute, October 2015.
- MITRE, [ATT&CK for ICS matrix](https://attack.mitre.org/matrices/ics/).

These links are for reading when a network is available; nothing on this page
loads from them.
