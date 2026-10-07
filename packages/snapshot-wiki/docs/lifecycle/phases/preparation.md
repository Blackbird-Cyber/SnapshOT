---
title: Preparation
summary: Know the process, the assets and who may touch what; stage the kit and agree the rules of engagement before anything is connected.
---

## Definition and OT reading

Preparation is the work done before the laptop is connected: before an
incident, at the start of every engagement and again after every lessons-learned
review. In IT it is mostly tooling and runbooks. On a plant floor it is about
**authority**. The process owner, not the responder, decides what may be
touched, and preparation writes that down: the safe states of the process, the
actions that are pre-authorised, the engineer who must be present for any write,
the maintenance windows and the people to call. NIST SP 800-61r3 treats this as
continuous governance and risk management (Govern, Identify and Protect) rather
than a one-off step, and NIST SP 800-82r3 asks for an OT incident response plan
that operations, engineering, safety and the other stakeholders have reviewed and
approved, kept on paper or on an offline system that an attack cannot reach.

For a SnapshOT engagement, preparation has three products. Without them, every
later phase improvises on live equipment.

### Rules of engagement

The [rules of engagement](../rules-of-engagement.md) are the written agreement
between the team and the asset owner. Before anything is connected they name:

- the **scope**: zones, hosts and controllers by name and address, and what is
  out of scope;
- the [wire class](../wire-classes.md) allowed in each zone: passive capture
  where agreed, active queries one host at a time with approval, writes only with
  the device's engineer present;
- the **windows** for active work and for any change;
- the **people**: asset owner, process owner, the engineer for each controller,
  the network owner who sets up SPAN ports and TAPs, the site's monitoring or
  SOC, and the safety lead;
- the **stop conditions** and who may call a stop;
- how evidence is collected, held and handed over
  ([evidence handling](../evidence-handling.md));
- the **containment options** agreed in advance: which conduits may be isolated,
  which systems may be disconnected, and when the process goes to manual or
  local control.

The last item matters most. SP 800-82r3 describes OT response actions ranging
from doing nothing to a full shutdown, by way of disconnecting systems,
isolating networks that can run independently (enterprise from control, control
from safety) and moving to manual operation with extra staff to check values by
hand. Choosing among them during an incident, under stress, is how processes get
tripped; preparation chooses them in advance, with the process owner. Keep a
paper copy of the contact list and the stop conditions.

### The known-good baseline

Every later phase compares against a baseline: identification spots what is
new, eradication restores to it, recovery checks against it. Record it with the
date and the state of the process (running normally, not starting up or shutting
down):

- the **asset inventory**: hosts, controllers, modules and firmware versions,
  the engineering workstations, and the transient devices (vendor laptops, USB
  media) that visit the site;
- the **network baseline**: passive captures of each conduit showing who talks
  to whom, with which industrial protocols, function codes and polling rates.
  The [passive baseline playbook](../playbooks/passive-baseline.md) does this
  with [tshark](../../tools/traffic/tshark.md) and
  [Wireshark](../../tools/traffic/wireshark.md);
- the **remote access paths** and vendor connections, and the sessions that
  normally cross each conduit: the picture against which Initial Access and
  Lateral Movement stand out later;
- the **controller logic, configurations and firmware images**, backed up by the
  engineer with the vendor's engineering software, with a SHA-256 recorded for
  each copy when it was taken.

SP 800-82r3 asks for backups to be verified for integrity where possible, kept on
site and at a second location the same incident cannot reach, and their
restoration tested. A copy is **known-good** only when its hash was recorded while
the system was believed clean and the engineer agrees it is what should run.
Anything else is "last known", and the report should say so.

### Staging and verifying the kit

From the site's point of view the SnapshOT laptop is a transient cyber asset,
exactly what an intruder's laptop would be. Prepare it so that it can be trusted
and explained:

- **One client per image.** Re-image from a verified release between
  engagements ([field updates](../../platform/field-updates.md)); check the ISO
  against the release's `SHA256SUMS` before writing it.
- **Know what is on it.** `/etc/snapshot-release` and
  `/usr/share/snapshot/reference/BUILD-MANIFEST.txt` record the version, the
  Debian pin, the build commit and every package
  ([build manifest](../../platform/build-manifest.md)). Copy the manifest into
  the case folder so the report can name the exact tool versions.
- **Check the architecture and the vendor layer.** The OPC UA GUI client is
  amd64 only ([architectures](../../platform/architectures.md)). The
  ICS Python libraries and the other vendored tools are present only in an image
  built with the [vendor layer](../../platform/vendor-layer.md); the build
  manifest says `(no vendor layer in this image)` when it is absent.
- **Quiet on the wire.** Interfaces come up only when the operator brings them
  up, and the services that would announce the laptop are off
  ([network defaults](../../platform/network-defaults.md)). Give the site's
  monitoring the MAC addresses of the adapters you will use.
- **The clock.** `systemd-timesyncd` is masked, so the laptop never sets its
  clock from the network. Check it against a reference you trust and write down
  the offset: every timeline depends on it.
- **Capture rights.** The user is in group `wireshark`, so Wireshark, tshark and
  termshark capture without `sudo`; tcpdump needs it
  ([admin and capture](../../platform/admin-and-capture.md)).
- **The field kit.** Prepare the USB stick with
  [`snapshot-fieldkit-prep`](../../tools/forensics/fieldkit.md) before
  travelling. Tools the client allows that SnapshOT may not redistribute
  (Sysinternals) go in `windows/user-supplied/`; `snapshot-fieldkit-prep --refresh`
  then rewrites the stick's `MANIFEST.sha256` to cover them.
- **Credentials and the case.** Credentials the client provides go into
  [KeePassXC](../../tools/reporting/keepassxc.md), never into notes. Choose the
  case name now: captures, field kit imports and notes all go under
  `~/cases/<case>/`.
- **Physical access.** The TAP or SPAN port is arranged with the network owner;
  serial adapters, probes and programmers go only to devices whose engineer has
  agreed to them.

## Entry and exit criteria

**Enter when**

- an engagement or an incident-response retainer is agreed with the asset owner;
- the team is called to a suspected incident (preparation is then compressed to
  the minimum: written authorization, contacts, stop conditions, a verified kit);
  or
- a lessons-learned review hands over changes to the plan, the baseline or the
  kit.

**Leave when**

- the rules of engagement are signed by the asset owner and accepted by the
  process owner;
- every device in scope has a named engineer, and the wire class allowed for
  each zone is written down;
- the pre-authorised containment options and the safe states are recorded;
- a known-good baseline exists, or its absence is recorded with what that means
  for later phases;
- the kit is verified: image hash, build manifest, architecture, vendor layer,
  clock offset, field kit stick; and
- the site's monitoring knows the laptop's adapters, the windows and the tools
  whose traffic will resemble an adversary's.

## Decisions and authorizations

- **The engagement and its scope** are the asset owner's, in writing. Nothing
  outside the written scope is touched, whatever is found.
- **Safe states and pre-authorised containment actions** are the process
  owner's. These are the only actions containment may take without a fresh
  decision.
- **Any active query** is approved per host or per device class, by the asset
  owner, after the engineer for that device says it can take the load.
- **Any write** needs the engineer for that device present, in an agreed window.
  Preparation names that person; if nobody can be named, writes are out of scope.
- **Where to listen**: the network owner chooses and configures the SPAN ports
  and TAPs; the team does not reconfigure switches.
- **Notifying the site's monitoring**: agreed now, so that the team's own
  discovery and protocol traffic (tools with the role "resembles") is never
  mistaken for an intruder's.
- **Evidence and data handling**: who holds custody, where evidence goes at the
  end, how long it is kept, and that the laptop is wiped and re-imaged afterwards.
- **Radio**: wireless work is receive-only, which is all SnapshOT's radio tools
  do; any transmission is out of scope unless a licence and the owner's
  agreement cover it.

## ATT&CK for ICS tactics in play

Preparation does not chase an adversary; it records what normal looks like so
that the ways in and the paths between zones stand out later.

<!-- snapshot:phase-tactics -->

## Tools in this phase

Generated from every tool page that describes a use in preparation. Almost all
of it is passive: baseline captures, inventories, and preparing the kit itself.

<!-- snapshot:phase-tools -->

## Playbooks for this phase

<!-- snapshot:phase-playbooks -->

## Crosswalk

<!-- snapshot:phase-crosswalk -->

In the SP 800-61r3 profile, preparation leans on the Govern categories for roles,
responsibilities and authorities (GV.RR) and policy (GV.PO), on asset management
(ID.AM) and risk assessment (ID.RA), and on the Protect safeguards. The full
mapping, including the ICS Cyber Kill Chain, is on the
[crosswalk](../crosswalk.md).

### The SANS Five ICS Critical Controls as a checklist

The crosswalk row names the three controls preparation builds most directly. In
practice all five are the checklist to go through with the asset owner before an
incident: each one a site lacks turns up later as a phase that cannot be done
safely.

| Control | In place before an incident | Where SnapshOT helps |
|---|---|---|
| 1. ICS Incident Response | An ICS-specific response plan with roles, the process owner's authority, safe states and pre-authorised containment options, exercised in a tabletop with operations and engineering | The phase pages and playbooks of this wiki, the rules of engagement, the field kit and evidence handling |
| 2. Defensible Architecture | Zones and conduits documented and enforced, so a conduit can be isolated without stopping the process | Passive captures confirm that each conduit carries only what the architecture expects |
| 3. ICS Network Visibility and Monitoring | Agreed SPAN or TAP points, a baseline, and monitoring that decodes the industrial protocols | [tshark](../../tools/traffic/tshark.md), [Wireshark](../../tools/traffic/wireshark.md) and [Suricata](../../tools/traffic/suricata.md) for baseline captures and IDS checks |
| 4. Secure Remote Access | An inventory of remote access paths and vendor connections: who may use them, when and how | Captures at the boundary show which remote sessions really exist, to compare with the inventory |
| 5. Risk-Based Vulnerability Management | An asset and firmware inventory, with vulnerabilities ranked by their consequence for the process and their exposure, not by score alone | The baseline inventory, and [binwalk](../../tools/firmware/binwalk.md) to look inside firmware images the engineer provides |

## Pitfalls and stop conditions

**Pitfalls**

- A baseline taken during start-up, maintenance or an existing compromise, and
  then treated as normal. Label every baseline with its date and process state.
- Backups that were never hashed or test-restored: eradication will restore
  whatever they contain.
- Verbal authorization. When something goes wrong, the written scope is what
  protects the process, the client and the team.
- Containment options left "to be decided": they will be decided under stress.
- An unannounced laptop: the site's monitoring sees a transient device running
  discovery, which is exactly what an intruder looks like.
- Assuming a tool is on the image: check the architecture and the vendor layer
  before travelling, not on site.
- Carrying anything from the previous client: re-image, and prepare the field
  kit stick fresh.

**Do not connect anything, and go back to the asset owner, when**

- there is no written authorization, or the scope is unclear;
- a device you were asked to query or write has no named engineer;
- the process owner cannot state the safe state or how to stop the work;
- the image cannot be verified against its release; or
- passive access cannot be arranged with the network owner and the only option
  is to improvise on a live switch.
