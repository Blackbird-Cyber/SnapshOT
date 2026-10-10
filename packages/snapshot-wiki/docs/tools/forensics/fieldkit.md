---
title: SnapshOT field kit
summary: Read-only triage collectors on a USB stick, prepared and imported on the laptop with integrity checks and a chain-of-custody log
folder: forensics
launchers: [snapshot-fieldkit-prep.desktop, snapshot-fieldkit-import.desktop, snapshot-fieldkit-folder.desktop, snapshot-fieldkit-guide.desktop]
ships_as: snapshot
package: snapshot-fieldkit
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  preparation: Prepare the stick, add any user-supplied Sysinternals tools and print the chain-of-custody form before going on site.
  identification: Run the quick read-only collector on each suspect HMI, engineering workstation or Linux host, with approval and the site informed.
  eradication: Collect again from a cleaned host and compare its autostart entries, services, tasks and accounts with the first collection.
  lessons-learned: Use the import manifests and the chain-of-custody log as the record of what was collected, when, by whom and on which stick.
csf: [identify, detect, respond]
attack_ics: [initial-access, execution, persistence, privilege-escalation, lateral-movement, command-and-control]
attack_role: investigates
attack_techniques: [T0847, T0886, T0807, T0873, T0859]
---

<!-- snapshot:facts -->

## What it is

The field kit is a USB stick of read-only triage collectors for the Windows and
Linux hosts met on an OT engagement. The laptop prepares the stick with
`snapshot-fieldkit-prep`, the operator runs a collector on each target host, and
`snapshot-fieldkit-import` brings the results back into the case folder with hash
checks and a chain-of-custody log. On Windows (XP to 11), `collect-triage.cmd`
starts `Collect-Triage.ps1` when PowerShell 2.0 or newer is present and otherwise
runs its own collection with built-in tools only; on Linux, `collect-triage.sh` is
plain POSIX `sh` and runs under BusyBox. They record processes, network
connections, services, scheduled tasks, autostart entries, users, installed
software, devices, serial ports, OPC servers and ICS project files.

The four launchers in **06 - Host Forensics** are *Prepare Field Kit USB*
and *Import Field Kit results* (both in a terminal), *Field Kit folder* (the kit
in the file manager, `/usr/share/snapshot/fieldkit`) and *Field Kit guide*
(`docs/fieldkit-guide.txt`: workflow, profiles, OT safety and chain of custody).

## Why it is on SnapshOT

HMIs, engineering workstations and historians often run old Windows, cannot take
an agent and may not be connected to anything a responder can reach. The field
kit gives the same inventory from every host, fast, with no network and nothing
installed: it runs from the stick, writes only to the stick and records its own
footprint. Back on the laptop the import checks every file against the hashes the
collector wrote, so the evidence in the case folder is provably what left the
host. It pairs with passive capture: [tshark](../traffic/tshark.md) shows a
session, the collector's connection table shows which process on the host owns
it.

SnapshOT ships only its own scripts. The Sysinternals and KAPE licences do not
allow redistribution, so the operator downloads them on a trusted machine and
drops them into `windows/user-supplied/` on the stick. The full profile runs
Sysinternals `autorunsc` and `sigcheck` when they are there; KAPE is only
listed, to be run by hand after the collector.

## On the wire

!!! danger "Writes: preparing the kit erases a USB stick"

    Nothing in the field kit uses the network: the collectors open no
    connection and the laptop side works only on the USB stick. What it writes
    is media, and what it runs is code on a production host.

    - **Prepare erases the stick.** `snapshot-fieldkit-prep` re-runs itself with
      `sudo`, lists only USB, removable or hot-plug disks and refuses the disk
      holding the SnapshOT boot medium, the disk holding the running system
      (through LUKS and LVM), a partition instead of a whole disk and any
      non-removable disk. You type the device name (`sdb`) and then `ERASE`.
      Check the model and serial it prints against the stick in your hand.
      `--yes --device` skips both prompts; keep it for scripts.
    - **Import is read-only.** `snapshot-fieldkit-import` runs as you, never as
      root, uses the stick where the desktop mounted it or mounts it read-only
      through udisks, and writes nothing to it. Only `--take-stick`, after you
      type `TAKE`, writes to it: it remounts the stick read-write if needed and
      removes the collections that run imported.
    - **On the target the collectors only read.** No network, no installs, no
      services started or stopped, no registry or configuration writes, no log
      clearing. Serial ports are listed from the registry, PnP and `/dev`, never
      opened: opening a port can toggle DTR/RTS and reset attached equipment.
    - **Known footprint**, logged in `run.log`: Windows Prefetch entries,
      process-creation audit events where enabled, wmic's first-run compile,
      file access times on Linux, and the Sysinternals `EulaAccepted` value when
      those tools run. Antivirus or EDR may alert on PowerShell or Sysinternals:
      tell the site before you start.
    - **On an HMI or engineering workstation**: written permission for that
      host, the operations contact present or informed, an agreed window, and
      the process state known. Use `quick` first; `full` is disk-heavy and takes
      10 to 60 minutes on Windows, so avoid it on busy HMIs and historians.
    - **Stop conditions**: abort at the banner (Ctrl+C) if anything is off; stop
      if the host slows, an operator reports an alarm, or antivirus quarantines a
      file from the stick (note it on the form, never disable the antivirus).
      Wait for `Done:` and eject the stick properly before pulling it.

## PICERL mapping

### Preparation

During [preparation](../../lifecycle/phases/preparation.md), prepare one stick
per engagement with *Prepare Field Kit USB*, copy any Sysinternals tools into
`windows/user-supplied/` and run `snapshot-fieldkit-prep --refresh` so the
manifest covers them too. Print `docs/chain-of-custody.txt` from the stick, write
the `VERSION` line and the stick's serial on it, and agree with the site which
hosts may be collected and when.

### Identification

During [identification](../../lifecycle/phases/identification.md), run the quick
profile on each host in scope, one at a time, with the operations contact
informed: it takes 2 to 5 minutes on Windows and 1 to 3 on Linux. Each run makes
one folder, `results/<HOST>_<UTC time>/`. Import as soon as you are back at the
laptop, so the evidence is verified and in the case folder before you start
reading it. The [IR triage](../../lifecycle/playbooks/ir-triage.md) playbook
chains this with capture and analysis.

### Eradication

When a host has been cleaned during
[eradication](../../lifecycle/phases/eradication.md), collect from it again with
the same profile and compare the new `autostart.txt`, `services.csv`,
`schtasks.csv`, `wmi-persistence.txt` and user lists (or `persistence.txt` and
`users.txt` on Linux) with the first collection. Every foothold found the first
time must be gone, and nothing new may have appeared.

### Lessons Learned

For [lessons learned](../../lifecycle/phases/lessons-learned.md), the
chain-of-custody log, the import manifests and the hand-written form are the
record of the collection: which host, which profile, who ran it, when it was
imported and whether it verified. They go into the report's evidence appendix as
they are; see [evidence handling](../../lifecycle/evidence-handling.md).

## MITRE ATT&CK for ICS mapping

The field kit *investigates*: it collects the host-side evidence of several
tactics, to be read after the fact.

- **Initial Access**: USB storage history and mounted devices (Replication
  Through Removable Media, T0847); RDP event logs in the full profile and logon
  sessions (Remote Services, T0886).
- **Execution**: every process with its command line, owner, start time and the
  SHA-256 of its binary (Command-Line Interface, T0807); on Linux, a running
  binary deleted from disk is flagged.
- **Persistence**: services, drivers, scheduled tasks, Run keys, WMI event
  subscriptions, systemd units and cron; ICS project files listed with their
  times, and hashed in the full profile (Project File Infection, T0873); local
  accounts and groups (Valid Accounts, T0859).
- **Privilege Escalation**: the members of every local group (Administrators
  included) on Windows, and `/etc/group` and the sudoers files on Linux, so an
  account that gained rights it should not have stands out against the site's
  account list.
- **Lateral Movement**: logon sessions, shares, `net use` and RDP logs (Remote
  Services, T0886; Valid Accounts, T0859).
- **Command and Control**: the connection table with the owning process of each
  socket, which ties a session seen in a capture to a program on the host.

The Windows collector itself runs PowerShell with `-ExecutionPolicy Bypass`,
which a monitoring team watches for as Execution. Tell them before you run it.

## Quick start

On the laptop:

```sh
# What Prepare Field Kit USB runs: pick the stick, type its name, then ERASE
snapshot-fieldkit-prep
# FAT32 instead of exFAT, for bare Windows XP hosts (4 GiB file limit)
snapshot-fieldkit-prep --fat32
# Update the kit on a prepared stick; results/ and user-supplied/ stay
snapshot-fieldkit-prep --refresh
# Import into ~/cases/site-a (Import Field Kit results asks for both names)
snapshot-fieldkit-import --case site-a --examiner "Jane Doe"
# Import, then remove what this run imported from the stick (type TAKE)
snapshot-fieldkit-import --case site-a --examiner "Jane Doe" --take-stick
```

`snapshot-fieldkit-prep --list` shows the disks it would offer, with size, bus,
model and serial, without root and without changing anything.

On a Windows target, from a command prompt (as Administrator for the full
picture; `E:` is wherever the stick appears):

```bat
:: Asks quick or full, shows the banner and waits for Enter
E:\windows\collect-triage.cmd
:: Built-in tools only, when PowerShell is blocked or watched
E:\windows\collect-triage.cmd cmd
```

On a Linux target (as root for the full picture; plain `sh` works with less
detail):

```sh
# Quick profile from the stick, mounted with the label SNAPKIT
sudo sh /media/<user>/SNAPKIT/linux/collect-triage.sh quick
```

`-y` skips the prompts on every collector, including the pause at the banner;
leave it out on a host you do not know.

## Output and evidence

Each collector writes only to `results/<HOST>_<yyyymmddTHHMMSSZ>/` on the stick:
`run.log` (a UTC `BEGIN`/`END` line with the return code per step), `errors.txt`,
`summary.txt` (host, OS, profile, times, user, admin or root, hasher),
`collection.txt` and `MANIFEST.sha256`, next to the collected files. The cmd
fallback without wmic uses the host's local time: the folder ends in `L` and
`summary.txt` says `stamp=local`. Windows XP has no SHA-256 tool, so there is no
manifest and integrity starts at the import.

The import builds the case folder:

```
~/cases/<case>/
  chain-of-custody.log            append-only, read-only between imports
  fieldkit/
    IMPORT-MANIFEST-<UTC>.sha256  every file of that run, read-only
    <HOST>_<STAMP>/               one collection, read-only
```

A collection that does not match its manifest prints a **TAMPER** banner, stays
on the stick, is not imported and makes the import exit 1; files not in the
manifest are imported and flagged `UNLISTED`. The log records the examiner, the
operator, the laptop, the stick's identity (device, label, UUID, vendor, model,
serial), each collection's result and the SHA-256 of the import manifest. To
check the copy again later:

```sh
# Re-verify everything imported in one run
cd ~/cases/site-a/fieldkit && sha256sum -c IMPORT-MANIFEST-*.sha256
```

Keep the printed form with the stick; [evidence
handling](../../lifecycle/evidence-handling.md) covers the rest of the case
folder.

### Hand-off to an analysis workstation

SnapshOT collects and hashes evidence, and examines disk images with
[The Sleuth Kit](sleuthkit.md). When a case needs more analysis than the
engagement laptop should do, it moves to a separate analysis workstation.

The transfer unit is the case folder, with its `SHA256SUMS` and
`chain-of-custody.log`. Lines that tool pages append to `SHA256SUMS` carry this
laptop's absolute paths, so check them before the case leaves, then write a
transfer manifest with paths relative to the case folder for the copy:

```sh
CASE=~/cases/site-a
# Every hash recorded during the engagement still matches
( cd "$CASE" && sha256sum -c SHA256SUMS )
# Hash every file in the case, paths relative to the case folder
T=TRANSFER-MANIFEST-$(date -u +%Y%m%dT%H%M%SZ).sha256
( cd "$CASE" && find . -type f ! -name "$T" -print0 | LC_ALL=C sort -z \
    | xargs -0 sha256sum -- > "$T" )
# The manifest's own hash goes on the custody form
sha256sum "$CASE/$T"
```

Copy the folder whole. On the workstation, run `sha256sum -c` on the transfer
manifest from inside the copied folder (on Windows, from Git Bash or WSL)
before any tool opens the evidence. Record the transfer, with the manifest's
hash, on the printed chain-of-custody form. The stick itself stays
collectors-only.

## Related tools

- [The Sleuth Kit](sleuthkit.md): when a host's disk is imaged instead, list and
  recover its files from the image.
- [tshark](../traffic/tshark.md): the network side of the same hosts, captured
  passively.
- [CherryTree](../reporting/cherrytree.md): notes per host, next to the
  chain-of-custody form.
- [nwipe](../reporting/nwipe.md): wipe the stick between clients before
  preparing it again.

## Upstream documentation

The field kit is SnapshOT's own; its documentation ships with it and on every
prepared stick:

- `/usr/share/snapshot/fieldkit/README.txt`: what the stick holds and the quick
  start for each collector.
- `/usr/share/snapshot/fieldkit/docs/fieldkit-guide.txt` (the *Field Kit guide*
  launcher): workflow, profiles, every file each collector writes, importing.
- `/usr/share/snapshot/fieldkit/docs/ot-safety.txt`: the checklist before
  running anything on a control system host.
- `/usr/share/snapshot/fieldkit/docs/chain-of-custody.txt`: the form to print,
  one per stick and engagement.
- `windows/user-supplied/README.txt` and `linux/user-supplied/README.txt`: which
  third-party tools the collectors use when present, and their footprint.
