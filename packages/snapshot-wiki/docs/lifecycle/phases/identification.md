---
title: Identification
summary: Detect and scope the incident from passive evidence first, confirm assets and sessions, and triage by cyber-physical impact.
---

## Definition and OT reading

Identification is where a suspicion becomes a declared, scoped incident. In IT
it often starts with an alert and moves quickly to probing the affected hosts.
On a plant floor the order is reversed: **listen first, ask later**. The first
evidence comes from a capture on a SPAN port or TAP, from the industrial
protocols decoded in it, and from what the operators and the safety system have
seen. Active queries come second, one host at a time, with approval, because a
fragile controller can fall over under a scan. Triage is measured in process
terms: what could this mean for safety, for product and for equipment, not only
for the hosts.

Where to listen follows the Purdue model: mirror ports or TAPs at levels 2 and 3
see the supervisory and engineering traffic, a serial adapter reaches a
controller's console at level 1, and a receive-only survey covers the wireless
links. Click a SnapshOT node to open the tool used there.

<div class="snapshot-graph" data-graph="purdue" data-height="620">
<p class="snapshot-graph__fallback">This diagram needs JavaScript: SPAN or TAP capture at Purdue levels 2 and 3, serial at level 1, and a wireless survey.</p>
</div>

## Entry and exit criteria

**Enter when**

- an alarm, an operator report, a monitoring alert or a third-party
  notification suggests unauthorized activity in the control system, or
- an assessment finds evidence of compromise.

**Leave when**

- the incident is declared, or ruled out with the evidence recorded;
- the affected zones, hosts and controllers are known, with the evidence for
  each;
- the likely impact on the process is assessed with the process owner; and
- the containment options are agreed with the people who own the process.

## Decisions and authorizations

- **Declaring the incident** is the incident commander's call, with the process
  owner informed.
- **Where to capture**: the network owner configures SPAN ports or places TAPs;
  the team does not reconfigure switches itself.
- **Any active query** (a scan, an ICS script, a Modbus read) needs the asset
  owner's approval for that host, in an agreed window, with the site's
  monitoring told in advance.
- **Any write** to a controller is out of scope in this phase unless the process
  owner directs it for safety, with the engineer for that device present.

## ATT&CK for ICS tactics in play

These are the adversary tactics whose traces identification looks for. Each
links to the tactic page and the tools that detect it.

<!-- snapshot:phase-tactics -->

## Tools in this phase

Generated from every tool page that describes a use in identification. Start
with the passive tools; use the active ones to confirm, not to explore.

<!-- snapshot:phase-tools -->

## Playbooks for this phase

<!-- snapshot:phase-playbooks -->

## Crosswalk

<!-- snapshot:phase-crosswalk -->

## Pitfalls and stop conditions

**Pitfalls**

- Scanning before capturing: the scan pollutes the very evidence you need and can
  upset fragile devices.
- Trusting a single source: a capture shows what crossed one point in the
  network, not everything that happened.
- Forgetting your own traffic: a scan you did not announce looks exactly like
  the adversary's discovery to the site's monitoring.
- Losing time order: record UTC times for every capture and command.

**Stop and hand control back to the process owner when**

- a device stops responding, faults or changes mode after any query;
- operators report unexpected process behavior during the work;
- the evidence points to a safety system being affected; or
- the scope reaches systems the authorization does not cover.
