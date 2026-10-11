---
title: Containment
summary: Take the pre-authorized actions that stop the spread without endangering the process, and preserve evidence while doing it.
---

## Definition and OT reading

Containment stops an incident from spreading and limits the damage while the
team works out how to remove the adversary. In IT the reflex is to isolate the
host the moment it looks compromised. On a plant floor containment is a
**negotiation with physics**: pulling a cable can trip a process, isolating a
conduit can blind the operators or force manual operation, and a controller that
loses its supervisory link may fall back to a state nobody planned for. NIST SP
800-82r3 puts the range of OT responses from doing nothing to a full shutdown and
warns that mitigation may mean process shutdowns or communication disconnects
whose impact must be understood and communicated. It also asks for a focused risk
assessment before choosing, because the obvious response, physically isolating
the system under attack, may not be possible without affecting operations or
safety.

So containment on SnapshOT engagements follows three rules:

- **Only pre-authorized actions.** The options agreed in
  [preparation](preparation.md) (which conduits may be isolated, which systems may
  be disconnected, when the process goes to manual or local control) are the only
  ones taken without a fresh decision by the process owner.
- **Verify from both sides.** Every action is checked with fresh captures on both
  sides of the boundary: the adversary's sessions stop, the process traffic that
  must continue still flows, and the safety and alarm functions still respond.
- **Preserve as you go.** Capture before and after each action, and collect
  volatile host evidence with the [field kit](../../tools/forensics/fieldkit.md)
  before a host is disconnected when it is safe to do so.
  SP 800-82r3 names the trade-off: returning to normal quickly against
  investigating and preserving forensic data. The incident commander and the
  process owner make that call, not the person holding the cable.

SnapshOT's part in containment is mostly **verification and evidence**. The
network owner changes the firewall rules or pulls the cable, the operators move
to manual, and the laptop shows whether it worked.

## Entry and exit criteria

**Enter when**

- identification has declared the incident, with its scope and the evidence for
  each affected zone, host and controller; and
- the process owner has agreed which of the pre-authorized containment options
  to use; or
- people, the environment or equipment are in immediate danger, in which case the
  site's own safety and emergency procedures run first and the team supports them.

**Leave when**

- the adversary's channels are cut and stay cut, shown by fresh captures over an
  observation period agreed with the incident commander;
- the conduits the adversary used are isolated or filtered, and the segmentation
  is verified from both sides;
- safety, alarm and protection functions are confirmed to respond while systems
  are isolated or in manual;
- the process is in a stable state the process owner has accepted (automatic,
  manual or shut down by decision);
- the evidence from before and after each action is in the case folder with its
  hashes; and
- the eradication plan, with its windows and engineers, is agreed.

## Decisions and authorizations

- **Which containment action**: the process owner, with the incident commander,
  chooses from the pre-authorized list. Anything not on the list needs a new
  decision by the process owner, informed by a focused risk assessment.
- **Who acts**: the network owner changes firewall rules, switch ports and
  cabling; operators move to manual or local control; the team does not
  reconfigure the network or touch controllers itself.
- **Evidence before isolation**: the incident commander decides, with the
  process owner, whether there is time to capture or collect before an action.
  Safety always wins.
- **How long each measure stays**: SP 800-61r3 suggests weighing the duration of
  a containment measure (an emergency workaround removed within hours, a
  temporary one, or a permanent change). Every measure gets an owner and a review
  time.
- **Writes**: no write to a controller by the team, except where the process
  owner directs it for safety, with the engineer for that device present.
- **Communication**: who tells the operators, management and any outside party
  (regulator, sector CERT, vendor) follows the site's plan; the team reports to
  the incident commander.

## ATT&CK for ICS tactics in play

These are the tactics containment is meant to stop, and the ones it must not
make worse. Isolating a conduit should cut Command and Control and Lateral
Movement; it must not take away a safety or alarm function, which is what an
adversary pursuing Inhibit Response Function wants.

<!-- snapshot:phase-tactics -->

## Tools in this phase

Generated from every tool page that describes a use in containment. Passive
capture does most of the work: before and after each action, on both sides of the
boundary.

<!-- snapshot:phase-tools -->

## Playbooks for this phase

<!-- snapshot:phase-playbooks -->

## Crosswalk

<!-- snapshot:phase-crosswalk -->

In the SP 800-61r3 profile, containment is incident mitigation (RS.MI-01,
"Incidents are contained"), carried out under incident management (RS.MA) while
incident analysis (RS.AN) keeps collecting data with its integrity and provenance
preserved. In ICS Cyber Kill Chain terms, containment during Stage 1 denies the
adversary the access it needs to develop a Stage 2 attack; containment during
Stage 2 is about protecting the process first. See the
[crosswalk](../crosswalk.md).

## Pitfalls and stop conditions

**Pitfalls**

- Isolating a conduit that also carries safety, interlock or alarm traffic.
  Check what crosses it in the baseline before it is cut.
- Containing part of the scope and alerting the adversary, who then switches to a
  path nobody has found yet. Scope first where safety allows.
- Acting without capturing: the evidence of the channel disappears with it.
- Verifying from one side only: a firewall rule that blocks the capture point's
  view but not the traffic looks like success.
- Trusting the HMI after an incident that may have manipulated the view. Manual
  operation needs people to check values at the plant, which SP 800-82r3 asks to
  be resourced in advance.
- Temporary measures with no owner, which become permanent or are quietly
  removed.

**Stop and hand control back to the process owner when**

- a containment step causes an unexpected process response, alarm or trip;
- a safety, alarm or protection function does not respond as expected;
- an action not on the pre-authorized list seems necessary;
- the evidence shows a second path, or activity in the safety system; or
- anyone on site is at physical risk.
