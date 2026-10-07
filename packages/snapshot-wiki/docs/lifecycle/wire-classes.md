---
title: Wire classes
summary: Passive, active and writes, the passive-first doctrine behind them, and how to read the wire badge on every tool page.
---

Every SnapshOT tool carries a **wire class** that says what it does on the wire:
whether it only listens, whether it sends packets but only reads, or whether it
can change a device, its configuration, firmware or media. The class is the first
thing to check before pointing a tool at anything on a plant floor, and it is
shown as a coloured badge at the top of each tool page. The three classes and the
doctrine that orders them are below.

## Passive first

On a control network the safest action is to listen. A capture on a SPAN port or
a TAP, an SDR in receive, or a disk image examined offline changes nothing and
cannot upset a fragile device. So the house rule is **passive first**: answer as
much as possible from passive evidence before sending a single packet, use active
tools only to confirm what listening already suggested, and treat writes as a
last resort taken with the engineer present. The order matters for evidence too:
a scan run before a capture pollutes the very traffic the team needs to read, and
it looks, to the site's monitoring, exactly like an intruder's
[Discovery](attack-ics/discovery.md). [Identification](phases/identification.md)
is built on this order, and the [passive baseline](playbooks/passive-baseline.md)
playbook is where it starts.

## Passive: it never transmits

!!! note "Passive"

    Listens, reads files or works offline. Never puts a packet on the wire.

A passive tool can be left running on a mirror port, pointed at a capture file, or
run against a disk image with no risk to the process. It needs no window and no
per-host approval, only agreement on where it is connected. Passive work spans
several menu folders:

- **Traffic Analysis (02):** [tshark](../tools/traffic/tshark.md),
  [Wireshark](../tools/traffic/wireshark.md),
  [termshark](../tools/traffic/termshark.md),
  [tcpdump](../tools/traffic/tcpdump.md),
  [tcpflow](../tools/traffic/tcpflow.md) and
  [Suricata](../tools/traffic/suricata.md) capture, decode and analyse without
  transmitting.
- **Recon & Discovery (01):** [p0f](../tools/recon/p0f.md) fingerprints hosts
  from traffic it only observes, and
  [mDNS listen](../tools/recon/mdns-listen.md) prints the mDNS announcements
  hosts send.
- **Firmware & Hardware (04):** [binwalk](../tools/firmware/binwalk.md) analyses
  a firmware image on disk; [sigrok-cli](../tools/firmware/sigrok-cli.md) and
  [PulseView](../tools/firmware/pulseview.md) record signals from a bench probe;
  [sdcc](../tools/firmware/sdcc.md) and [QEMU](../tools/firmware/qemu.md) work
  offline on the laptop.
- **Wireless & SDR (05):** the whole folder is receive-only:
  [airodump-ng](../tools/wireless/airodump-ng.md) surveys Wi-Fi from a card in
  monitor mode, and [rtl-sdr](../tools/wireless/rtl-sdr.md) and
  [Gqrx](../tools/wireless/gqrx.md) receive radio with dongles that have no
  transmitter.
- **Forensics & Response (06):** the [Sleuth Kit](../tools/forensics/sleuthkit.md)
  reads evidence without changing it; so does the field kit's import step,
  though the kit as a whole is a writes tool (below) because preparing the stick
  formats it.
- **Reporting & Documentation (07) and Reference (08):**
  [LibreOffice](../tools/reporting/libreoffice.md),
  [CherryTree](../tools/reporting/cherrytree.md),
  [Flameshot](../tools/reporting/flameshot.md),
  [pandoc](../tools/reporting/pandoc.md),
  [KeePassXC](../tools/reporting/keepassxc.md), the
  [build manifest](../tools/reference/build-manifest.md) and the
  [offline reference data](../tools/reference/reference-data.md) work on local
  files only.

A hardware TAP is the purest passive attachment because it physically cannot
send. A SPAN port is passive from the laptop's side, but remember the laptop is
on a link: avoid giving the capture interface an address, and do not plug into a
live control segment without agreement.

## Active: it sends, but only reads

!!! warning "Active"

    Sends queries or probes and reads the answers, but does not change the
    device. It can still upset a fragile stack.

An active tool asks a question: a port scan, an ARP sweep, a Modbus identity read,
a few keystrokes on a serial console. It does not change what the device does, but
sending is sending, and a controller with a small stack can fault under a scan it
never expected. Active work needs written approval for the target, an agreed
window, the site's monitoring told in advance, and the fragile-device rules
(one host at a time, only the ports you need, slowly) from the
[rules of engagement](rules-of-engagement.md). Active tools include:

- **Recon & Discovery (01):** [nmap](../tools/recon/nmap.md) and the
  [Redpoint NSE](../tools/recon/redpoint-nse.md) scripts,
  [arp-scan](../tools/recon/arp-scan.md),
  [netdiscover](../tools/recon/netdiscover.md) (which also has a passive mode),
  [fping](../tools/recon/fping.md), [nbtscan](../tools/recon/nbtscan.md) and
  [avahi-browse](../tools/recon/avahi-browse.md) (once its masked daemon is
  started by hand).
- **Protocol Tools (03):** [plcscan](../tools/protocols/plcscan.md) and the
  [ICS Python shell](../tools/protocols/ics-python-shell.md) when used for reads.
- **Firmware & Hardware (04):** the serial console tools
  [minicom](../tools/firmware/minicom.md),
  [picocom](../tools/firmware/picocom.md), [tio](../tools/firmware/tio.md) and
  [screen](../tools/firmware/screen.md). They only read and type, but opening a
  serial port can toggle control lines and reset attached equipment, so treat the
  physical connection with the care the rules of engagement set out.

Active tools *resemble* the adversary's [Discovery](attack-ics/discovery.md), which
is why announcing them is not optional.

## Writes: it can change the device or the media

!!! danger "Writes"

    Can change device state, configuration, firmware or media. An engineer must
    be present and the action must be approved.

A write changes something that matters: a coil or holding register that drives
equipment, a controller's firmware, a radio transmission on a live band, or the
contents of a disk. The device cannot tell the responder's write from an
adversary's, so every write follows the engineer-present rule, happens in a
window, and is read back and recorded. Writes appear across folders:

- **Protocol Tools (03):** [mbpoll](../tools/protocols/mbpoll.md),
  [pymodbus](../tools/protocols/pymodbus.md),
  [python-snap7](../tools/protocols/python-snap7.md),
  [pycomm3](../tools/protocols/pycomm3.md),
  [asyncua](../tools/protocols/asyncua.md), the
  [OPC UA command-line tools](../tools/protocols/opcua-cli-tools.md),
  [opcua-client](../tools/protocols/opcua-client.md),
  [BACpypes3](../tools/protocols/bacpypes3.md) and
  [BAC0](../tools/protocols/bac0.md) can write registers, tags, nodes,
  properties, parameters and programs to a controller.
- **Firmware & Hardware (04):** [flashrom](../tools/firmware/flashrom.md) and
  [OpenOCD](../tools/firmware/openocd.md) can overwrite firmware and memory.
- **Wireless & SDR (05)** has no writes tool. The `aircrack-ng` package that
  provides [airodump-ng](../tools/wireless/airodump-ng.md) also installs tools
  that inject and deauthenticate; they have no menu entry, and using one would be
  a radio write under the [rules of engagement](rules-of-engagement.md).
- **Traffic Analysis (02):** [Scapy](../tools/traffic/scapy.md) crafts and sends
  packets and [tcpreplay](../tools/traffic/tcpreplay.md) puts a capture back on a
  wire, so both are writes tools even though they live among the capture tools.
- **Reporting & Documentation (07):** [nwipe](../tools/reporting/nwipe.md)
  destroys data on media, used to re-image a stick between clients.
- **Forensics & Response (06):** the [field kit](../tools/forensics/fieldkit.md)
  prepare step formats the USB stick (its collectors on the target are
  read-only; preparing the stick is the write), and
  [TestDisk](../tools/forensics/testdisk-photorec.md) can rewrite a partition
  table or boot sector, so it runs only on image copies (PhotoRec, in the same
  package, is read-only).

The writes a tool can perform are what [Impair Process Control](attack-ics/impair-process-control.md)
looks like on the wire. The team only crosses into this class deliberately,
with the people who own the device.

## Reading the badge

Each tool page shows its wire class as a badge in the facts box: **green** for
passive, **amber** for active, **red** for writes. The same colours mark the
wire badges in the tool tables, on the phase pages and in the
[matrix](matrix.md). When you are deciding how to answer a question,
start at the greenest tool that can answer it and move up a class only when it
cannot. Most of an OT engagement is green and amber; the red tools are used
rarely, late, and with the engineer standing next to you.

## Related pages

- [Rules of engagement](rules-of-engagement.md): the standing rules each class must follow.
- [Evidence handling](evidence-handling.md): recording what every active and writes action did.
- [Identification](phases/identification.md): passive first in practice.
