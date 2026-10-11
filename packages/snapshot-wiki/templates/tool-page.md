---
# Copy to docs/tools/<folder>/<slug>.md. <slug> is the tool's usual name in
# lowercase with dashes (nmap, tshark, redpoint-nse); it becomes the URL.
# Every key below is required unless marked optional; the build fails on a
# missing or unknown key, an unknown phase/tactic/technique/protocol, or a
# section heading that differs from this template. Remove these comments.
title: TOOL                       # as the operator types or sees it: nmap, Wireshark, mbpoll
summary: ONE LINE                 # match the launcher's Comment= where one exists
folder: FOLDER                    # recon | traffic | protocols | firmware | wireless | forensics | reporting | reference
launchers: [snapshot-TOOL.desktop]  # SnapshOT ids, upstream ids (org.wireshark.Wireshark.desktop), or []
ships_as: apt                     # apt | vendor | upstream-gui | snapshot
package: PACKAGE                  # apt package, vendor/sources.lock stanza name, or our package name;
                                  # a list for a tool split over packages: [qemu-system-x86, qemu-utils]
arch: [amd64, arm64]              # or one of them
status: shipped                   # shipped | not-shipped (use templates/tool-page-not-shipped.md)
wire: passive                     # passive (never transmits) | active (sends, reads only) | writes (changes state or media)
phases:                           # PICERL phase id -> one line: how the tool is used in that phase
  identification: ONE LINE
csf: [detect]                     # govern | identify | protect | detect | respond | recover
attack_ics: [discovery]           # tactic slugs from data/attack-ics.yaml; [] with attack_role: none
attack_role: detects              # detects | investigates | resembles | none
attack_techniques: [T0842]        # optional; ids from data/attack-ics.yaml, only where certain
protocols: [modbus]               # optional; slugs from data/protocols.yaml
upstream: https://example.invalid/docs   # optional; the upstream manual
---

<!-- snapshot:facts -->

## What it is

Three to six sentences: what the tool does, in plain words, for someone who has
not used it. No version numbers; the facts box points to the build manifest.

## Why it is on SnapshOT

The OT job it does: which protocols, assets and engagement tasks, and why this
tool rather than another one on the image.

## On the wire

!!! warning "Active: it sends packets"

    Pick the admonition from the wire class: `!!! note "Passive: it never
    transmits"`, `!!! warning "Active: ..."` or `!!! danger "Writes: ..."`. Then
    the cautions that apply: fragile stacks and scan rate, one host at a time,
    an engineer present for any write, serial/JTAG/SPI physical risk, radio
    transmit legality. Say what the site's monitoring will see.

## PICERL mapping

One `###` subsection per entry in `phases:`, named exactly as the phase
(Preparation, Identification, Containment, Eradication, Recovery, Lessons
Learned), expanding the one-line note into how the tool is used in that phase.

### Identification

Two to five sentences, with a link to the phase page.

## MITRE ATT&CK for ICS mapping

Which tactics the tool detects, investigates or resembles, the technique ids and
names where you are certain, and what evidence it produces for the tactic.

## Quick start

The guide to using the tool (docs/wiki.md, "Body"). A command-line tool: three
to eight commands, each with a one-line explanation as a comment on the line
above it (code blocks are narrow; trailing comments get cut off). The
launcher's own command first; vendor tools as `/opt/snapshot/<tool>/bin/<cmd>`;
`sudo` only where the image needs it; documentation addresses (192.0.2.0/24)
for targets.

```sh
# What the menu launcher runs
tool --help
```

A GUI tool: any command lines that apply, then a numbered walkthrough of a
first useful session, one paragraph per step, with menu labels checked against
the trixie package or the upstream manual:

1. **Open and connect or load.** Where it is in the menu, and the first dialog.
2. **The key panes.** What each shows and where to look.
3. **Filter, decode or analyze.** The one or two actions that answer the
   question.
4. **Save or export.** Into `~/cases/<case>/`, never over the original.

A Python library: short working examples through
`/opt/snapshot/ics-python/bin/ics-python`, reads first, any write marked as
needing the engineer present.

## Output and evidence

Where output goes, how to save it under `~/cases/<case>/` and hash it with
`sha256sum`.

## Related tools

- Links to the other tool pages that pair with this one, with half a line each.

## Upstream documentation

- [Upstream manual](https://example.invalid/docs): what it covers.
