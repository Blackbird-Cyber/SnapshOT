---
title: Rules of engagement
summary: What must be agreed in writing before anything is connected on a plant floor, and the standing rules that keep active work from hurting the process.
---

Rules of engagement are agreed in [preparation](phases/preparation.md), before
the laptop touches the network, and they bind the whole engagement. On a plant
floor the cost of a mistake is not a crashed server but a tripped process, a
blinded operator or a safety function that did not fire. The rules below are the
house standard; a specific engagement can only make them stricter, never looser.
SnapshOT works [passive first](wire-classes.md): everything here is about the
moment the team wants to send a packet, open a port or touch a device.

## Authorization in writing, and its scope

No active work happens without written authorization from the asset owner. A
verbal go-ahead on site is not enough: the person who can accept the risk to the
process signs, and the signed scope travels with the case. The authorization
names, at least:

- **The targets.** The exact hosts, controllers and network segments that are in
  scope, by address and by role, and an explicit list of what is **out** of
  scope (safety instrumented systems, protection relays and anything the owner
  will not risk).
- **The actions.** Which [wire classes](wire-classes.md) are permitted on which
  targets: passive capture only, active reads, or writes. A target can be in
  scope for listening and out of scope for scanning.
- **The protocols and tools.** Which industrial protocols may be spoken, and
  whether active ICS queries (an [nmap](../tools/recon/nmap.md) ICS script, a
  [Modbus](../tools/protocols/mbpoll.md) read) are allowed at all.
- **The window.** The dates and times active work may run, and who to reach when
  it does.
- **The approver and the escalation path.** Who signed, who the on-site
  operations contact is, and who decides when the plan meets reality.

If the work would reach a system the authorization does not cover, it stops
until the scope is extended in writing. The team never "follows the adversary"
into systems it was not authorized to touch.

## The process owner has the final say

On an engagement the process owner, not the responder, decides what may be
touched. This is the single rule the others hang from. The team advises, the
process owner decides, and if the two disagree the process owner wins. The same
authority covers calling a halt: the operations contact or the process owner can
stop the work at any time, for any reason, and the team hands control back
without argument. This mirrors how the [phases](index.md) place
every containment, eradication and recovery decision with the people who run the
plant.

## Engagement windows

Active work runs inside an agreed window and not outside it. A window is chosen
with operations: a maintenance slot, a shift with the right engineers present, or
a period when the process can tolerate a controller pausing. Passive capture can
run continuously (it changes nothing), but a scan, a protocol read or any write
waits for the window, happens while the right people are watching, and ends when
the window ends. Record the window and the UTC start and stop of each active
action in the case notes (see [evidence handling](evidence-handling.md)).

## An engineer is present for anything that writes

Any action in the **writes** [wire class](wire-classes.md) (a
[Modbus](../tools/protocols/mbpoll.md) write, a firmware operation with
[flashrom](../tools/firmware/flashrom.md) or [OpenOCD](../tools/firmware/openocd.md),
a wipe with [nwipe](../tools/reporting/nwipe.md)) is done with the engineer
responsible for that device present and agreeing to the exact target and value
before it is sent. A wrong register, unit id or address can start a motor, change
a set point or brick a controller, and the device cannot tell the responder's
write from an adversary's. The engineer confirms the target, the operator sends
it once, both read it back, and both commands go in the notes.

## Fragile devices: one host at a time, slowly

PLCs, RTUs and protection relays often have small network stacks that were never
built to survive a scan. Active work on them follows three rules:

- **One host at a time.** Never sweep a control subnet. Pick the single host the
  evidence points to, act on it, confirm it is healthy, then move on.
- **Only the ports and registers you need.** Name them explicitly; do not let a
  tool explore. Read small ranges from one unit id at a time.
- **Slowly.** Cap the packet rate (for example [nmap](../tools/recon/nmap.md)'s
  `--max-rate`), prefer a plain connect scan over version and OS detection, and
  poll once rather than continuously.

A device that stops answering, faults or changes mode after a query is a stop
condition, not a reason to retry.

## Physical access: serial, JTAG and SPI

Bench and console work carries risks a network tool does not. Treat a cable like
a write:

- **Serial.** Opening a serial port can toggle the DTR and RTS lines and reset
  or interrupt the attached equipment. Confirm the port, the voltage levels and
  the pinout before connecting, and never attach to a console on a running,
  in-service controller without the engineer's agreement. List the adapters
  first without opening them (`ls -l /dev/serial/by-id/`); a
  [terminal tool](../tools/firmware/minicom.md) then opens one deliberately.
- **JTAG and SWD.** Debug access can halt the CPU, read or overwrite memory and
  leave the target in a stopped state. Use it on bench hardware, a spare or a
  unit the engineer has removed from service, not on a controller that is running
  a process.
- **SPI flash.** Clipping onto a live flash chip (a SOIC clip, an in-circuit
  programmer) can brown out or confuse the running device, and a mistaken write
  destroys its firmware. Prefer powering the board from the programmer or pulling
  the chip; image and verify before any write; keep a known-good dump first.

Physical work belongs in a maintenance window on hardware the engineer has
released, and every acquisition is hashed and logged like any other evidence.

## Radio: receive only

Wireless work on SnapshOT is **receive only**. The 05 Wireless & SDR folder
holds receivers: [airodump-ng](../tools/wireless/airodump-ng.md) surveys Wi-Fi
from a card in monitor mode, and the RTL-SDR dongles that
[rtl-sdr](../tools/wireless/rtl-sdr.md) and [Gqrx](../tools/wireless/gqrx.md)
drive have no transmitter. A survey listens and records; it changes nothing (see
the [wireless survey](playbooks/wireless-survey.md) playbook), and it answers
the question the radio tools are there for: is something transmitting here that
is not in the asset inventory?

- SnapshOT carries no transmit-capable SDR tooling: the `hackrf`, `gnuradio`
  and `soapysdr-tools` packages are not on the image (Gqrx brings only the GNU
  Radio libraries it receives through), and the menu offers no injection or
  key-cracking tool. The `aircrack-ng` package that provides airodump-ng also
  installs `aireplay-ng`, `airbase-ng` and the key cracker; they stay out of
  the workflow.
- Transmitting (Wi-Fi deauthentication or injection, or any other radio
  transmission) is out of scope unless the authorization names it and it is
  **lawful** for the band. Radio law varies by country and band, and some bands
  must never be touched.
- Jamming, deauthentication and injection can knock wireless instruments,
  telemetry or safety links off the air. If a transmission is ever approved,
  treat it as a write to the process and apply the engineer-present and window
  rules.
- Listening is passive, but recording the content of other parties'
  communications is regulated in some jurisdictions: record networks,
  frequencies, timing and power, and content only when the authorization covers
  it.

## Tell the site's monitoring before active work

SnapshOT's active tools look exactly like an attacker. A scan, an ICS query or a
protocol read is indistinguishable, on the wire and to a SOC, from the
[Discovery](attack-ics/discovery.md) and
[Impair Process Control](attack-ics/impair-process-control.md) tactics the team
is there to find. Before any active action, tell whoever watches the site's
monitoring: what you will run, against which targets, in which window. This keeps
the team from triggering the site's own incident response, and it keeps the
record clean, so that unannounced activity in the same capture can be
attributed to someone else. Passive capture that the team announced is also
worth noting, so a SPAN change is not mistaken for an intrusion.

## Stop conditions and handing control back

The team stops active work, and hands control back to the process owner, when:

- a device stops responding, faults, resets or changes operating mode after any
  query or write;
- operators report unexpected process behaviour, alarms or a safety action while
  the work is under way;
- the evidence suggests a safety instrumented system or protection function is
  involved;
- the work would reach systems, zones or actions the authorization does not
  cover; or
- the process owner, the operations contact or the engineer calls a halt.

Stopping means: cease the action, leave devices in a known state, tell the
operations contact and the process owner at once, record the UTC time and what
was happening, and preserve the evidence of what led up to it. Work resumes only
when the process owner agrees and, if the scope has changed, the authorization
has been extended. Handing control back is never a failure; it is the rule
working as intended.

## Related pages

- [Wire classes](wire-classes.md): passive, active and writes, and the passive-first doctrine.
- [Evidence handling](evidence-handling.md): the case folder, hashing and chain of custody.
- [Preparation](phases/preparation.md): where the rules of engagement are agreed.
- [Playbooks](playbooks/passive-baseline.md): the procedures that put these rules into practice.
