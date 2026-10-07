---
title: Eradication
summary: Remove the adversary's footholds from hosts, logic and firmware, comparing everything against a verified known-good state.
---

## Definition and OT reading

Eradication removes what the adversary left behind: accounts and changed
credentials, tools and scripts, start-up items and services, modified controller
logic and implanted firmware, and the access paths that let them in. In IT it is
often a matter of re-imaging hosts. On a plant floor eradication touches **the
things that run the process**: controller logic, firmware, HMIs and the
engineering workstations that hold the projects. Every change is made by or with
the engineer responsible for that device, in an agreed window, and checked
against a **verified known-good copy** rather than against whatever is running
now. If the running copy were trustworthy, there would be nothing to eradicate.

Three habits keep eradication safe:

- **Image before you clean.** Preserve the evidence of each foothold (a disk
  image, a field kit collection, a copy of the modified logic or firmware) before
  it is removed. The report and any legal follow-up depend on it.
- **Rebuild rather than repair** where you can: an engineering workstation or HMI
  restored from verified media is easier to trust than one cleaned by hand.
- **Restore only from verified sources.** SP 800-82r3 asks that software for OT
  maintenance come from the vendor with its authenticity verified, for example by
  comparing installer hashes; the same rule applies to firmware and to the logic
  backups recorded in [preparation](preparation.md).

SnapshOT's part is to find and prove: the [field kit](../../tools/forensics/fieldkit.md)
collects services, scheduled tasks, autostart entries and accounts from Windows
and Linux hosts so a second collection after clean-up can be compared with the
first; [The Sleuth Kit](../../tools/forensics/sleuthkit.md) examines disk images,
with deeper analysis on a separate workstation after the field kit
[hand-off](../../tools/forensics/fieldkit.md#hand-off-to-an-analysis-workstation);
[binwalk](../../tools/firmware/binwalk.md) looks inside firmware images; and the
hashes in the case folder show that what was restored is what was verified.
Reading or writing flash with [flashrom](../../tools/firmware/flashrom.md) or
[OpenOCD](../../tools/firmware/openocd.md) is hardware work on the device itself:
the engineer is present, the device is out of service, and the
[rules of engagement](../rules-of-engagement.md) cover the physical risks.

## Entry and exit criteria

**Enter when**

- containment holds and has been verified;
- the footholds are scoped well enough to list them: every host, account, logic
  change and firmware image implicated, with the evidence for each; and
- verified known-good copies exist, or there is an agreed way to obtain them
  (from the vendor, or by rebuilding).

**Leave when**

- every foothold on the list is removed, and each removal is verified by a fresh
  collection, capture or comparison;
- credentials the adversary obtained or changed are reset, and added accounts are
  removed;
- the access paths used are closed: remote access, conduit rules, removable media
  and transient devices;
- logic, configurations, set points and firmware match the known-good baseline,
  checked by the engineer;
- the evidence of every finding was preserved before removal; and
- the recovery plan and its order are agreed with the process owner.

## Decisions and authorizations

- **How each device is restored** is the decision of the engineer responsible
  for it, who makes or supervises the change. The team does not write to a
  controller on its own.
- **The window and the process state** during each change are the process
  owner's to approve.
- **Rebuild or clean** a host: the asset owner decides with the incident
  commander; rebuilding from verified media is the default.
- **What is kept**: the incident commander decides, with legal where relevant,
  which images and copies are retained as evidence before media are wiped.
- **The vendor's role**: firmware and software come from the vendor or from the
  verified baseline, never from a copy found on site.
- **Credential resets**: the asset owner decides who resets what and how new
  credentials reach their users; the team keeps any it receives in
  [KeePassXC](../../tools/reporting/keepassxc.md).

## ATT&CK for ICS tactics in play

These are the tactics whose traces eradication removes. Persistence is the main
target, but the means of execution and any escalated privileges must go too, and
anything that impaired process control must be shown to match the baseline.

<!-- snapshot:phase-tactics -->

## Tools in this phase

Generated from every tool page that describes a use in eradication. Most read and
compare; the few that write (to flash, to a disk) need the engineer present.

<!-- snapshot:phase-tools -->

## Playbooks for this phase

<!-- snapshot:phase-playbooks -->

## Crosswalk

<!-- snapshot:phase-crosswalk -->

In the SP 800-61r3 profile, eradication is incident mitigation (RS.MI-02,
"Incidents are eradicated"), and the analysis that establishes what happened and
its root cause (RS.AN-03) decides what has to go. Closing the vulnerabilities used
is where Risk-Based Vulnerability Management (SANS control 5) meets the incident.
See the [crosswalk](../crosswalk.md).

## Pitfalls and stop conditions

**Pitfalls**

- Comparing against the running system instead of the verified baseline.
- Restoring a backup taken after the compromise began: check its date against
  the timeline before trusting it.
- Removing the visible foothold and missing the second one. Eradicate once the
  scope is known, not as each finding appears.
- Wiping before imaging, which destroys the evidence.
- Forgetting the engineering workstation and its project files: the next program
  download will carry the adversary's logic back into the controller.
- Forgetting transient devices and removable media that visited the site.
- Flashing over an unstable connection, at the wrong voltage or without a tested
  recovery path, which can leave a device unrecoverable.

**Stop and hand control back to the process owner when**

- a device does not return to the expected state after a restore;
- a known-good copy is missing or its hash does not match the record;
- new footholds appear (return to identification and containment);
- the window ends: leave each device in a safe, agreed state rather than half
  changed; or
- the engineer responsible for the device is no longer present.
