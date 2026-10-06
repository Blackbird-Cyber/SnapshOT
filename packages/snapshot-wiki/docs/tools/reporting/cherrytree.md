---
title: CherryTree
summary: Hierarchical Note Taking
folder: reporting
launchers: [cherrytree.desktop]
ships_as: upstream-gui
package: cherrytree
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Set up the engagement notebook, one node per zone, host and phase, with the contacts, windows and safe states agreed.
  identification: Record every command, observation and time as you work, next to the host it concerns.
  lessons-learned: Export the notes to HTML or text as the working record behind the report.
csf: [govern, identify, respond]
attack_ics: []
attack_role: none
upstream: https://www.giuspen.net/cherrytree/
---

<!-- snapshot:facts -->

## What it is

CherryTree is a note-taking application that keeps a whole notebook in one file,
as a tree of nodes. Each node is a page of rich text or of syntax-highlighted
code, and can hold images, tables, code boxes, attached files and links to other
nodes. A notebook is stored as SQLite (`.ctb`) or XML (`.ctd`), or as the
password-protected variants of each (`.ctx` and `.ctz`). It searches across all
nodes and exports a notebook, or one branch of it, to HTML, plain text or PDF.

## Why it is on SnapshOT

An engagement produces a stream of small facts: which port a switch's SPAN used,
when a capture started, what the engineer said about a controller, which command
read which register. A tree with one node per host or per phase keeps each fact
next to what it concerns, and a single file per engagement is easy to protect,
hash and hand over. It is the notebook that the report, the timeline and the
evidence log are later written from.

## On the wire

!!! note "Passive: it never transmits"

    CherryTree works on a local file and needs no network.

    - **Protect the notebook.** Notes hold IP plans, device models and
      weaknesses of the client's control system: use a password-protected
      notebook (`.ctx` or `.ctz`) in the case folder on the encrypted disk.
    - **No credentials in notes.** Passwords and keys go into
      [KeePassXC](keepassxc.md), never into a node, a screenshot or the report.
    - **Commands in notes are records, not scripts.** Copy a command from the
      notes into a terminal only after checking it against the current target
      and window, never by habit: the rules of the [wire
      class](../../lifecycle/wire-classes.md) apply again each time.

## PICERL mapping

### Preparation

During [preparation](../../lifecycle/phases/preparation.md), build the notebook
before going on site: a node for the rules of engagement and contacts, one per
zone and host from the asset owner's list, and one per phase. Each host node
records the engineer responsible, the safe state and what may be touched.

### Identification

During [identification](../../lifecycle/phases/identification.md), write as you
work: the UTC time, the command, what it showed and the file it saved to. A note
written at the moment is evidence; one reconstructed the next day is not. Paste
screenshots from [Flameshot](flameshot.md) into the node of the host they show.

### Lessons Learned

For [lessons learned](../../lifecycle/phases/lessons-learned.md), the notebook is
the working record: export it to HTML or text for the case archive, and write
the report's timeline and findings from it. The [reporting
handover](../../lifecycle/playbooks/reporting-handover.md) playbook covers what
goes to the client and what stays in the case.

## MITRE ATT&CK for ICS mapping

CherryTree has no ATT&CK for ICS mapping: it holds the team's notes and neither
detects nor investigates adversary activity itself. Its part is bookkeeping: a
node per tactic seen, with the evidence and the tool that found it, makes the
report's [ATT&CK for ICS](../../lifecycle/attack-ics/index.md) mapping
straightforward to write.

## Quick start

CherryTree is a GUI; the menu launcher opens a new window.

```sh
# What the menu launcher runs
cherrytree --new_window
# Open the engagement notebook (it asks for the notebook's password)
cherrytree ~/cases/site-a/notes/site-a.ctx
# Export the whole notebook as a single HTML page, replacing an earlier export
cherrytree ~/cases/site-a/notes/site-a.ctx -x ~/cases/site-a/report/notes -s -w
# Export every node to its own text file
cherrytree ~/cases/site-a/notes/site-a.ctx -t ~/cases/site-a/report/notes -w
# Export the whole notebook as one PDF
cherrytree ~/cases/site-a/notes/site-a.ctx -p ~/cases/site-a/report/notes -w
```

The HTML and text exports write a folder named after the notebook
(`site-a.ctx_HTML`, `site-a.ctx_TXT`) inside the directory given; the PDF export
writes `site-a.ctx.pdf` there. The command-line exports need the desktop
session, like the application itself. `-P` would take the notebook's password
on the command line, where it lands in the shell history, so leave it out and
type the password when asked.

Setting up the engagement notebook, the first time:

1. **Start it.** Open CherryTree from 07 Reporting & Documentation.
2. **Save it protected, at once.** **File > Save As**, and in **Choose Storage
   Type** pick **Single SQLite File, 7-zip Encrypted and Password Protected**.
   Set the password (store it in [KeePassXC](keepassxc.md)) and save as
   `~/cases/site-a/notes/site-a.ctx`.
3. **Build the tree.** **Tree > Add Node** adds a node beside the selected one
   and **Tree > Add Subnode** a child of it: for example one node per phase,
   with a subnode per host or controller. A node's properties (name, rich text
   or code) are edited from the same menu.
4. **Write as you go.** Type into the node on the right. The **Insert** menu
   adds an image (a [Flameshot](flameshot.md) capture from
   `notes/screens/`), a table, a code box for a command and its output, and a
   timestamp in the laptop's local time; write UTC times by hand where they
   matter, as in the rest of the case.
5. **Find things later.** The **Search** menu finds text in the selected node
   or across the whole notebook.
6. **Save often** (Ctrl+S). The notebook is one file, so it is easy to hash and
   archive with the case.
7. **Export for the report.** **Export > Export To PDF** or **Export To HTML**
   asks whether to export the selected node only, the selected node and its
   subnodes, or all the tree.

## Output and evidence

Keep the notebook in the case folder, and hash it and its export when the
engagement closes:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/notes" "$CASE/report"
cherrytree "$CASE/notes/site-a.ctx" -x "$CASE/report/notes" -s -w
sha256sum "$CASE/notes/site-a.ctx" >> "$CASE/SHA256SUMS"
find "$CASE/report/notes" -type f -exec sha256sum {} + >> "$CASE/SHA256SUMS"
```

See [evidence handling](../../lifecycle/evidence-handling.md) for the rest of
the case folder.

## Related tools

- [Flameshot](flameshot.md): screenshots to paste into the notes.
- [KeePassXC](keepassxc.md): where credentials go instead of the notes.
- [LibreOffice](libreoffice.md) and [pandoc](pandoc.md): the report written from
  the notes.
- [SnapshOT field kit](../forensics/fieldkit.md): its chain-of-custody form and
  log, referenced from each host's node.

## Upstream documentation

- [CherryTree](https://www.giuspen.net/cherrytree/): the project's home page,
  features and documentation links.
