---
title: QEMU
summary: Machine emulator for running firmware and vendor VMs offline
folder: firmware
launchers: []
ships_as: apt
package: [qemu-system-x86, qemu-system-arm, qemu-utils]
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  identification: Run a suspect firmware image or a vendor VM in an offline sandbox to observe what it does, with no connection to the plant.
  eradication: Boot a cleaned or rebuilt image in the sandbox to confirm it runs before it is written back to a device.
csf: [identify, respond]
attack_ics: []
attack_role: none
upstream: https://www.qemu.org/documentation/
---

<!-- snapshot:facts -->

## What it is

QEMU is a machine emulator and virtualizer. It runs a whole operating system or a
firmware image for one architecture on a host of another: an ARM controller's
firmware on the amd64 build of SnapshOT, or an x86 vendor VM on the arm64 build.
SnapshOT installs
three parts of it: `qemu-system-x86` for x86 and x86-64 guests
(`qemu-system-x86_64`), `qemu-system-arm` for ARM and AArch64 guests
(`qemu-system-arm`, `qemu-system-aarch64`), and `qemu-utils` for `qemu-img`,
which creates, converts, inspects and takes snapshots of disk images. KVM gives
near-native speed only when the guest has the host's architecture (an x86-64
guest on the amd64 build, an AArch64 guest on the arm64 build) and `/dev/kvm`
exists, which needs bare-metal hardware or a hypervisor with nested
virtualization turned on. Every other combination runs under QEMU's own CPU
emulator (TCG), which is much slower but works across architectures.

## Why it is on SnapshOT

Some evidence is safest to run, not just read. A firmware image extracted with
[binwalk](binwalk.md), or a vendor's engineering-workstation VM handed over for
an incident, can be booted inside QEMU in a sandbox with no network, so you see
what it does without touching the plant or trusting it on a real host. `qemu-img`
also converts and inspects the disk-image formats these come in (`qcow2`, `vmdk`,
`vhdx`, raw) and makes a copy-on-write overlay so the original image is never
modified. It has no menu launcher; it is run from a terminal.

The image has no graphical QEMU display: the GTK and SDL front ends are in
`qemu-system-gui`, a recommended package, and SnapshOT installs no recommends.
Guests run with their serial console in the terminal (`-nographic`), a text-mode
screen in the terminal (`-display curses`), or a VNC server on the loopback
address (`-vnc 127.0.0.1:0`) for a viewer the image does not ship. That suits
firmware and Linux guests; a vendor VM that needs a desktop is better examined
as a disk image, with `qemu-img` and the [Sleuth Kit](../forensics/sleuthkit.md).

## On the wire

!!! note "Passive: it never transmits to the plant"

    QEMU runs offline on the laptop. The caution is about containing what you
    run, not about traffic on the OT network.

    - Run suspect images with **no network**: pass `-nic none` so the guest has
      no interface at all. A firmware image or a vendor VM under analysis may try
      to call out or spread; never give it a path to the engagement network.
    - Work on a copy, or a copy-on-write overlay, so the evidence image is never
      written. Keep the original dump hashed and untouched.
    - Treat anything the guest produces as untrusted: do not move files from the
      guest onto the host or a device without checking them.
    - KVM acceleration needs `/dev/kvm`; the SnapshOT user is in group `kvm`, so
      a same-architecture guest can use `-accel kvm` without `sudo` where the
      device exists. A cross-architecture guest runs emulated and needs no
      special access.
    - Nothing reaches the plant while the guest has no network, so the site's
      monitoring sees nothing; if you deliberately give a guest QEMU's user-mode
      network, keep the laptop itself off the engagement network.

## PICERL mapping

### Identification

During [identification](../../lifecycle/phases/identification.md), QEMU boots a
firmware image or a vendor VM in an isolated sandbox so its behaviour can be
observed safely: what it starts, what it would reach for on a network (watched
with a host capture, not a real link), what it writes. This turns a static image
found during triage into something you can watch run, without risking the
process.

### Eradication

In [eradication](../../lifecycle/phases/eradication.md), a cleaned or rebuilt
image can be booted in QEMU to confirm it starts and behaves before it is written
back to a device with [flashrom](flashrom.md) or [OpenOCD](openocd.md), so a bad
image is caught on the bench rather than on the controller.

## MITRE ATT&CK for ICS mapping

QEMU has no direct relationship to an ATT&CK for ICS tactic. It is an offline
sandbox: it runs firmware and VMs for analysis and confirmation, and any
adversary behaviour it helps reveal is attributed from what is seen inside the
sandbox, not from QEMU itself. Keep the sandbox disconnected from the plant so
nothing it runs can reach a real device.

## Quick start

QEMU has no menu launcher; run it in a terminal.

```sh
# Inspect a disk image handed over as evidence
qemu-img info vendor-ws.qcow2
# Convert a vendor VMDK to raw to carve or mount it read-only
qemu-img convert -f vmdk -O raw vendor-ws.vmdk vendor-ws.raw
# Make a copy-on-write overlay so the evidence image is never written
qemu-img create -f qcow2 -b vendor-ws.qcow2 -F qcow2 work-overlay.qcow2
# Boot the overlay with no network, its text screen in the terminal (emulated)
qemu-system-x86_64 -m 2048 -drive file=work-overlay.qcow2,format=qcow2 \
    -nic none -display curses
# amd64 build with /dev/kvm only: the same guest at near-native speed
qemu-system-x86_64 -accel kvm -m 2048 -drive file=work-overlay.qcow2,format=qcow2 \
    -nic none -display curses
# Run an ARM firmware/kernel image emulated, no network, serial to the terminal
qemu-system-arm -M virt -m 256 -kernel firmware.bin -nic none -nographic
# List the boards qemu-system-arm emulates, to match the target's SoC
qemu-system-arm -M help
```

Pick the machine that matches the target; a generic `virt` board only runs code
built for it. On the arm64 build the KVM case is an AArch64 guest under
`qemu-system-aarch64 -M virt -cpu host -accel kvm`. `-nographic` puts the guest's
serial console on the terminal (`Ctrl-A X` quits QEMU). Use `-snapshot` to
discard all guest writes at exit when you do not even want an overlay file.

## Output and evidence

Keep the original image untouched; run from an overlay and record what you did:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/firmware/sandbox" "$CASE/notes"
cd "$CASE/firmware/sandbox"
# The original stays in ../ untouched; confirm it still matches its recorded hash
( cd "$CASE" && sha256sum -c --ignore-missing SHA256SUMS )
# Every guest write lands in the overlay, never in the dump
qemu-img create -f qcow2 -b ../rtu7-spi-20261006T142530Z.bin -F raw work.qcow2
# Record the exact qemu-system command, with the UTC time, in the case notes
{ date -u; echo '$ qemu-system-arm -M virt ... -nic none -nographic'; } \
    >> "$CASE/notes/log.txt"
```

Put what you observed (console output, files the guest wrote, what it tried to
reach) in the notes next to the command. The default on this page is
`-nic none`; give a guest QEMU's user-mode network only as a deliberate step, so
that what it tries to send can be watched on the laptop.

## Related tools

- [binwalk](binwalk.md): extract the firmware image or file system before running
  it.
- [flashrom](flashrom.md) and [OpenOCD](openocd.md): read the image from the
  device and write a confirmed image back.
- [The Sleuth Kit](../forensics/sleuthkit.md): examine a disk image `qemu-img`
  converted to raw, read-only.

## Upstream documentation

- [QEMU documentation](https://www.qemu.org/documentation/): the system emulator,
  the `qemu-img` tool and the machine and device options.
