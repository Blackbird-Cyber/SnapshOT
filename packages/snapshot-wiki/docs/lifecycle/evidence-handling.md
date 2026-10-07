---
title: Evidence handling
summary: One case folder per engagement, UTC timestamps, SHA-256 hashes in a running SHA256SUMS file, a chain-of-custody log, and media wiped between clients.
---

Everything the team collects on an engagement is evidence: captures, scans,
register reads, firmware dumps, host triage and notes. Handled well it supports a
finding, a report and, if it comes to it, a legal process; handled carelessly it
proves nothing and may be challenged. SnapshOT keeps this simple and consistent
so that the habit survives a long day on a plant floor: one folder per
engagement, UTC times, a hash for every file, and a log of who did what. The
[field kit](../tools/forensics/fieldkit.md) already works this way, and the rest
of the engagement follows the same shape.

## The case folder

All output for one engagement lives under `~/cases/<case>/`, where `<case>` is a
short, stable name agreed at the start (a client code and date, for example
`acme-2026-10`; the tool pages use `site-a`). Inside it, a subfolder per kind of
evidence keeps things findable:

```
~/cases/acme-2026-10/
  pcap/                 captures, by interface and UTC time
  recon/                discovery output: ARP, ping and NetBIOS
                        sweeps, mDNS service lists, p0f, plcscan
  nmap/                 scan output (-oA: .nmap, .xml, .gnmap)
  modbus/ s7/ enip/     protocol reads and writes, one folder per
  opcua/ bacnet/        protocol, each script beside its output
  serial/               serial console logs
  firmware/             flash dumps, logic captures and their analysis
  rf/                   SDR sweeps and recordings
  wifi/                 802.11 survey captures
  images/               disk images, hashed on arrival
  analysis/             results derived from the evidence: suricata/,
                        flows/, scapy/, tsk/, carved/
  fieldkit/             host triage imported from the field kit stick
  lab/                  notes from lab replays, never the plant
  reference/            the build manifest and /etc/snapshot-release
  notes/                the running log and screenshots (notes/screens/)
  report/               the report draft, its figures, the hand-over copy
  acme-2026-10.kdbx     KeePassXC database of the credentials the client
                        issued; returned or destroyed at hand-over
  SHA256SUMS            one line per file: its SHA-256 and path
  chain-of-custody.log  append-only record of custody and handling
```

Create only the subfolders the work needs; the constants are the single case
root, the `SHA256SUMS` file at its top, and the chain-of-custody log. Original
evidence (captures, dumps, images, imports) and what is derived from it
(`analysis/`, `report/`) stay apart, so a reader always knows which is which.
Each tool page's *Output and evidence* section writes into this layout.

## Naming captures and dumps

A file name should say what it is, where it came from and when, without opening
it. Use UTC and the compact ISO form from `date -u`:

```sh
# The UTC stamp used throughout: 20261006T142530Z
date -u +%Y%m%dT%H%M%SZ
```

- **Captures:** interface and UTC start, for example
  `pcap/eth1-20261006T142530Z.pcapng`. A rolling capture keeps the tool's own
  numbering.
- **Scans and reads:** target and subject, for example
  `nmap/plc01-modbus.xml` or `modbus/plc01-reads.txt`.
- **Firmware dumps:** the device and the chip, for example
  `firmware/rtu7-spi-20261006T142530Z.bin`, with a second dump kept as a
  known-good reference before any write.
- **Host triage:** the field kit names collections `<HOST>_<UTC>` itself; keep
  that name.

Times are UTC everywhere so that evidence from the laptop, the field kit, a
controller's clock and the site's monitoring can be put on one timeline.

## Hashing: sha256sum and a running SHA256SUMS

Hash every piece of evidence as soon as it stops changing, and append the hash to
the case's `SHA256SUMS`. The hash is what lets anyone later prove the file has not
been altered.

```sh
CASE=~/cases/acme-2026-10
# Hash a finished capture and append the line to the running file
sha256sum "$CASE"/pcap/eth1-20261006T142530Z.pcapng >> "$CASE/SHA256SUMS"
# Later, verify nothing in the case has changed
( cd "$CASE" && sha256sum -c SHA256SUMS )
```

Hash the original, then work on copies; a read never changes the file, but
working on a copy removes all doubt. The field kit goes further and writes its own
per-import manifest (`fieldkit/IMPORT-MANIFEST-<UTC>.sha256`) and makes imported
collections read-only; leave those in place and let the case `SHA256SUMS` point at
them.

## UTC, always

Record UTC for every capture and every command, not local time. Plant clocks,
controllers and laptops drift and sit in different zones, and an incident timeline
that mixes them is worthless. The field kit's collectors stamp in UTC where they
can and flag a collection `stamp=local` when a bare Windows host left them no
choice; note that flag in the timeline. When you write a command into the notes,
put the UTC time next to it:

```sh
{ date -u; echo '$ nmap -sT -n -Pn -p 502 192.0.2.10'; } >> "$CASE/notes/log.txt"
```

## Chain of custody

The chain of custody is the unbroken record of who held and handled the evidence,
from collection to report. SnapshOT keeps it two ways, and they agree:

- **The field kit's log.** Each import appends a block to
  `~/cases/<case>/chain-of-custody.log`: the UTC time, the examiner, the operator
  and laptop, the source stick's identity, how it was mounted, each collection and
  its result, the import manifest's SHA-256, and what was taken from the stick.
  The log is append-only (read-only between imports), and it records no email
  address. Mirror this for evidence you collect by hand: append a dated,
  signed-off line when a file is created, copied, or handed to someone else.
- **The printed form.** The field kit ships a one-page chain-of-custody form to
  print per stick and engagement: case, client, stick serial and kit version,
  each collection, and every transfer of the stick with who released and received
  it. Keep it with the physical media.

Between them, a reader can trace any file back to the host it came from, the
operator who collected it, and every hand it passed through, with hashes proving
it did not change on the way.

When a case needs deeper analysis than
[The Sleuth Kit](../tools/forensics/sleuthkit.md) on the engagement laptop
gives, the whole case folder moves to a separate analysis workstation. That transfer is a hand in the chain
like any other: check `SHA256SUMS` before the case leaves, write a transfer
manifest with paths relative to the case folder (the lines in `SHA256SUMS`
carry this laptop's absolute paths), verify the copy against it on the
workstation, and record the transfer on the form. The field kit page's
[hand-off](../tools/forensics/fieldkit.md#hand-off-to-an-analysis-workstation) section has the commands.

## What the kit itself proves

Evidence is only as trustworthy as the tool that produced it, so the image records
exactly what it is. Two files tie an engagement's output to a known, reproducible
build:

- **`/etc/snapshot-release`** holds the release identity: the SnapshOT version,
  the architecture and the git commit the image was built from.
- **The build manifest**, `/usr/share/snapshot/reference/BUILD-MANIFEST.txt`,
  records the version, architecture and git commit, the Debian snapshot the build
  was pinned to, the `SOURCE_DATE_EPOCH`, the kernel, every installed package with
  its version, and the vendored tools under `/opt/snapshot`. Open it from the menu
  (*08 - Reference > Build manifest*) or read its
  [tool page](../tools/reference/build-manifest.md).

Because SnapshOT pins its packages to a single Debian snapshot, two builds of the
same release produce the same image, so the manifest names the precise version of
every tool that touched the evidence. Copy the manifest (or at least its first few
lines and the entries for the tools used) into the case's `reference/` folder, so the report can
state which build collected the evidence without depending on the laptop still
existing. The [reference data](../tools/reference/reference-data.md) that ships
with the image is likewise fixed to the build.

## Wiping media between clients

The field kit stick and any removable media carry one client's data and must never
reach another. Between engagements, wipe them with
[nwipe](../tools/reporting/nwipe.md) (a **writes** tool: it destroys data) and
record that the wipe happened in the outgoing case's custody log. A fresh stick is
then prepared for the next client with the field kit's prepare step, which erases
and reformats it again. The same rule covers the laptop: finish, hash and back up
a case before starting the next, and keep cases in separate folders so nothing
bleeds from one client to another.

## Related pages

- [Rules of engagement](rules-of-engagement.md): authorization, windows and stop conditions.
- [Wire classes](wire-classes.md): why passive evidence comes first.
- [Reporting and handover](playbooks/reporting-handover.md): turning the case folder into the report.
- [Field kit](../tools/forensics/fieldkit.md): the host-triage collectors and their chain-of-custody log.
