---
title: LibreOffice
summary: Create and edit text and graphics in letters, reports, documents and Web pages
folder: reporting
launchers: [libreoffice-writer.desktop]
ships_as: upstream-gui
package: libreoffice
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Write the rules of engagement and the test plan, and keep the asset owner's lists in Calc, before anything is connected.
  lessons-learned: Write the report in Writer, build timelines and asset tables in Calc, and export the PDF for handover.
csf: [govern, identify]
attack_ics: []
attack_role: none
upstream: https://help.libreoffice.org/
---

<!-- snapshot:facts -->

## What it is

LibreOffice is the free office suite: Writer (word processor), Calc
(spreadsheet), Impress (presentations), Draw, Base and Math. It saves in
OpenDocument formats and reads and writes Microsoft Office files (`.docx`,
`.xlsx`, `.pptx`), exports PDF, and converts documents from the command line
without opening a window. The **07 - Reporting & Documentation** folder holds
LibreOffice Writer; the other applications are under Usual Applications >
Office, where Writer is listed too.

## Why it is on SnapshOT

The report is the deliverable of an engagement, and it has to be written on the
laptop that holds the evidence, with no cloud service involved. Writer takes the
report and its appendices; Calc opens the CSV that other tools produce (a
[tshark](../traffic/tshark.md) field export, a
[Sleuth Kit](../forensics/sleuthkit.md) timeline, a
[field kit](../forensics/fieldkit.md) `processes.csv`) and turns them into
sorted, filtered tables; the command-line converter turns the
[pandoc](pandoc.md) output into PDF.

## On the wire

!!! note "Passive: it never transmits"

    LibreOffice needs no network and does not touch the plant.

    - **Documents from outside are untrusted.** Asset lists, drawings and
      reports received from the client or a vendor can carry macros and links to
      external content. Open them read-only (`--view`), never enable their
      macros, and keep the laptop off the client network while you work on them.
    - **The report is sensitive.** It describes the client's control system and
      its weaknesses: keep it in the case folder on the encrypted disk, and hand
      it over the way the rules of engagement say.
    - **Strip what should not leave.** Before handover, remove comments, tracked
      changes and personal information from the document properties.

## PICERL mapping

### Preparation

During [preparation](../../lifecycle/phases/preparation.md), Writer holds the
signed rules of engagement, the authorisation and the test plan, and Calc the
asset owner's lists: hosts, controllers, the engineer responsible for each, the
safe states and the agreed windows. They are the reference every later phase
checks against; see [rules of
engagement](../../lifecycle/rules-of-engagement.md).

### Lessons Learned

For [lessons learned](../../lifecycle/phases/lessons-learned.md), Writer holds
the report: the incident in terms of the process, the timeline, the findings
mapped to ATT&CK for ICS, and the control gaps. Calc builds the timeline and the
asset tables from the case's CSV files. The PDF export is the version handed
over; the [reporting handover](../../lifecycle/playbooks/reporting-handover.md)
playbook walks through it.

## MITRE ATT&CK for ICS mapping

LibreOffice has no ATT&CK for ICS mapping: it writes documents and neither
detects nor investigates adversary activity. It is where the mapping is written
down: each finding in the report names its tactic and technique, as listed on
the [ATT&CK for ICS](../../lifecycle/attack-ics/index.md) pages, so the client's
teams share one vocabulary for the gaps.

## Quick start

```sh
# What the menu launcher runs: a new Writer document
libreoffice --writer
# A new Calc spreadsheet, for asset lists and timelines
libreoffice --calc
# Open a CSV timeline in Calc (the import dialog asks for the separator)
libreoffice --calc ~/cases/site-a/analysis/tsk/hmi01-timeline.csv
# Open a document from outside read-only
libreoffice --view asset-list.xlsx
# Convert the report to PDF without opening a window
libreoffice --headless --convert-to pdf --outdir ~/cases/site-a/report \
    ~/cases/site-a/report/report.odt
# The same for a DOCX written by pandoc
libreoffice --headless --convert-to pdf --outdir ~/cases/site-a/report \
    ~/cases/site-a/report/report.docx
```

Close LibreOffice's windows before a `--convert-to` run: a conversion started
while LibreOffice is open is handed to the running instance and may produce
nothing.

## Output and evidence

Keep the report and its sources in the case folder, and hash the version that is
handed over:

```sh
CASE=~/cases/site-a
mkdir -p "$CASE/report"
libreoffice --headless --convert-to pdf --outdir "$CASE/report" "$CASE/report/report.odt"
sha256sum "$CASE/report/report.odt" "$CASE/report/report.pdf" >> "$CASE/SHA256SUMS"
```

The hash in the handover note proves later which version the client received.
For a long-lived archive, *File > Export as PDF* offers PDF/A. See [evidence
handling](../../lifecycle/evidence-handling.md).

## Related tools

- [pandoc](pandoc.md): write the report in Markdown and convert it to DOCX or
  ODT with your template.
- [CherryTree](cherrytree.md): the engagement notes the report is written from.
- [Flameshot](flameshot.md): annotated screenshots for the report's figures.
- [tshark](../traffic/tshark.md) and [The Sleuth Kit](../forensics/sleuthkit.md):
  CSV exports that Calc turns into tables and timelines.

## Upstream documentation

- [LibreOffice Help](https://help.libreoffice.org/): every application, menu and
  dialog.
- [LibreOffice documentation](https://documentation.libreoffice.org/): the
  Writer and Calc guides.
