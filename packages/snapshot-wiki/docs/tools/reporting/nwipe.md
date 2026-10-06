---
title: nwipe
summary: Securely wipe disks
folder: reporting
launchers: [snapshot-nwipe.desktop]
ships_as: apt
package: nwipe
arch: [amd64, arm64]
status: shipped
wire: writes
phases:
  preparation: Wipe the laptop's disk from the live session before re-imaging it for the next client, and wipe evidence sticks and drives before reuse.
  lessons-learned: Once the case is handed over and its retention agreed, wipe the media that held the client's data and keep each wipe report.
csf: [protect]
attack_ics: []
attack_role: none
upstream: https://github.com/martijnvanbrummelen/nwipe
---

<!-- snapshot:facts -->

## What it is

nwipe overwrites whole disks so their previous contents cannot be read back. It
is the wiping program of DBAN, rebuilt to run on any Linux system: a text-mode
screen lists the disks it finds, you select one or more, choose a method
(zeros, a pseudo-random stream, or multi-pass schemes such as DoD 5220.22-M or
Gutmann), and it writes, verifies and blanks them, several disks in parallel.
For each disk it logs the method, passes and result and writes a PDF report with
the disk's model and serial number.

## Why it is on SnapshOT

SnapshOT's rule is one client per image: between clients the laptop is wiped
and re-imaged rather than updated in place, which also clears the previous
client's data. nwipe is the wipe in that cycle, run from the live session on the
laptop's internal disk before the install, and the same tool clears evidence
sticks, external drives and a used [field kit](../forensics/fieldkit.md) stick
before they are reused. Preparing a field kit stick only repartitions and
formats it; the old contents stay readable until the stick is wiped.

## On the wire

!!! danger "Writes: it destroys everything on the disks you select"

    nwipe never touches the network, but there is no undo: a wiped disk is
    gone. Three safeguards, every time:

    - **Identify the right disk.** Unplug every disk you are not wiping. Match
      the size, model and serial in `lsblk` against the label on the device in
      your hand. Unmount it first.
    - **Never the boot medium.** In the live session, the stick SnapshOT booted
      from is the device behind `/run/live/medium`. When wiping the internal
      disk, hide all USB disks with `--nousb`, or name the boot stick in
      `--exclude`.
    - **Confirm twice.** Check the disk in `lsblk`, then check the same model and
      serial in nwipe's own list before you start. If they differ, stop.

    Never use `--autonuke` without device names: it starts wiping every disk it
    finds at once. Never wipe a client's disk, or any medium holding evidence,
    without the written instruction of its owner and the case's retention
    agreed. On SSDs and NVMe disks an overwrite cannot reach blocks the drive
    has remapped internally; there, the LUKS2 encryption of the installed system
    is what keeps the previous client's data unreadable.

## PICERL mapping

### Preparation

During [preparation](../../lifecycle/phases/preparation.md) for the next client,
boot the SnapshOT live USB, wipe the laptop's internal disk with nwipe (USB disks
hidden), and install from the same stick. Wipe evidence sticks, external drives
and the field kit stick before they are prepared again, and keep the PDF report
of each wipe. See [live session and
install](../../platform/live-and-install.md).

### Lessons Learned

For [lessons learned](../../lifecycle/phases/lessons-learned.md), once the report
is handed over, the evidence is archived or returned and the client has agreed
the retention period, wipe the media that held the client's data. The PDF
reports go into the case record as proof of disposal; the [reporting
handover](../../lifecycle/playbooks/reporting-handover.md) playbook ends here.

## MITRE ATT&CK for ICS mapping

nwipe has no ATT&CK for ICS mapping: SnapshOT uses it on the team's own media,
where it neither detects nor investigates adversary activity. As context only:
the same overwrite pointed at a client's asset is what the Data Destruction
technique describes, which is why nwipe never touches client equipment without
the owner's written instruction. Evidence of an adversary's wipe is the job of
[TestDisk and PhotoRec](../forensics/testdisk-photorec.md), which map to it.

## Quick start

```sh
# What the menu launcher runs
nwipe --help
# Identify the disk: name, size, bus, model, serial and mount points
lsblk -o NAME,SIZE,TRAN,MODEL,SERIAL,MOUNTPOINTS
# In the live session: the device SnapshOT booted from (never wipe it)
findmnt -n -o SOURCE /run/live/medium
# Wipe the internal disk from the live session, with every USB disk hidden
sudo nwipe --nousb --method=zero --verify=last
# Wipe an external stick, with the boot stick /dev/sdb kept out of the list
sudo nwipe --exclude=/dev/sdb --method=prng --verify=last
# The same, with the log and PDF report kept on the laptop's disk
sudo nwipe --exclude=/dev/sdb -l "$HOME/wipe/nwipe.log" -P "$HOME/wipe" \
    --method=zero --verify=last
```

nwipe needs root; in the live session `sudo` asks no password, on an installed
system it asks yours. Each command opens nwipe's screen: select the disk there,
check its model and serial, and start the wipe with the keys listed at the bottom
of the screen. The default method is a three-pass DoD scheme followed by a
blanking pass; one verified pass of zeros or of the random stream is enough for
media leaving an engagement.

## Output and evidence

nwipe logs to the terminal unless `-l` names a file, and writes a PDF report per
disk to the current directory unless `-P` names another. Never write them to
the disk being wiped:

```sh
mkdir -p "$HOME/wipe"
sudo nwipe --exclude=/dev/sdb -l "$HOME/wipe/nwipe.log" -P "$HOME/wipe" \
    --method=zero --verify=last
sha256sum "$HOME"/wipe/*.pdf "$HOME/wipe/nwipe.log" >> "$HOME/wipe/SHA256SUMS"
```

When the laptop's own disk is wiped from the live session, the reports must go
to another medium, such as a separate USB stick. File them with the case they
close. See [evidence handling](../../lifecycle/evidence-handling.md).

## Related tools

- [SnapshOT field kit](../forensics/fieldkit.md): wipe the stick before preparing
  it for the next client.
- [TestDisk and PhotoRec](../forensics/testdisk-photorec.md): why a format is
  not enough; they recover what a format leaves behind.
- [KeePassXC](keepassxc.md): the credentials database retired with the case.

## Upstream documentation

- [nwipe on GitHub](https://github.com/martijnvanbrummelen/nwipe): methods,
  options, the PDF report and known limitations.
