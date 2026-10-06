---
title: pandoc
summary: Universal document converter
folder: reporting
launchers: [snapshot-pandoc.desktop]
ships_as: apt
package: pandoc
arch: [amd64, arm64]
status: shipped
wire: passive
phases:
  preparation: Render the rules of engagement and the test plan from Markdown into the client's DOCX template.
  lessons-learned: Turn Markdown findings and notes into the report as DOCX, ODT or a self-contained HTML file.
csf: [govern, identify]
attack_ics: []
attack_role: none
upstream: https://pandoc.org/MANUAL.html
---

<!-- snapshot:facts -->

## What it is

pandoc converts documents between markup formats. Its most useful direction on
an engagement is from Markdown, a plain-text format you can write in any editor,
to Word (`.docx`), OpenDocument (`.odt`), HTML and many others, with headings,
tables, lists, code blocks and images carried across. A reference document sets
the styles of the DOCX or ODT it writes, so the output matches a company
template, and a YAML block at the top of the Markdown sets the title, author and
date. It also reads DOCX, HTML and CSV, which turns a client's document or a
tool's CSV into Markdown.

## Why it is on SnapshOT

Findings are easiest to write as text: in a terminal, next to the evidence,
under version control, with commands and outputs pasted in. pandoc turns that
text into the document the client expects, in their template, as often as the
draft changes, without retyping. The image has no LaTeX, so pandoc does not make
PDF itself: [LibreOffice](libreoffice.md) converts its DOCX or ODT to PDF.

## On the wire

!!! note "Passive: it never transmits"

    pandoc reads and writes local files and does not touch the network or the
    plant.

    - **Keep images local.** Given an image as a remote URL, pandoc fetches it
      to build a DOCX, ODT or self-contained HTML file. Keep every picture the
      report uses in the case folder and refer to it by a relative path, so
      there is nothing to fetch.
    - **The output is client-sensitive.** Write it to the case folder on the
      encrypted disk and hand it over as the rules of engagement say.
    - **Templates from outside are documents from outside.** A reference DOCX
      supplied by someone else is only used for its styles, but open it in
      LibreOffice read-only first if you did not make it.

## PICERL mapping

### Preparation

During [preparation](../../lifecycle/phases/preparation.md), keep the rules of
engagement, contact list and test plan as Markdown and render them into the
client's template for signature. When the scope changes, edit the text and
render again; the change history stays readable.

### Lessons Learned

For [lessons learned](../../lifecycle/phases/lessons-learned.md), write the
findings in Markdown (one file per section, or one file for the whole report)
with tables for the timeline and the ATT&CK for ICS mapping, and render the DOCX
or ODT for review. The [reporting
handover](../../lifecycle/playbooks/reporting-handover.md) playbook takes it from
there to the PDF that is handed over.

## MITRE ATT&CK for ICS mapping

pandoc has no ATT&CK for ICS mapping: it converts documents and neither detects
nor investigates adversary activity. A Markdown table of findings with their
tactic and technique, as named on the [ATT&CK for
ICS](../../lifecycle/attack-ics/index.md) pages, renders as a normal table in the
report.

## Quick start

```sh
# What the menu launcher runs
pandoc --version
# Markdown to DOCX, with a table of contents
pandoc findings.md -o report.docx --toc
# Copy pandoc's default reference DOCX, to edit its styles into a template
pandoc -o reference.docx --print-default-data-file reference.docx
# Markdown to DOCX using that template's styles
pandoc findings.md -o report.docx --reference-doc=reference.docx --toc
# Markdown to ODT, for LibreOffice
pandoc findings.md -o report.odt --toc
# One HTML file with the images inside it
pandoc findings.md -s --embed-resources -o report.html
# A tool's CSV as a Markdown table, to paste into the findings
pandoc -f csv -t markdown timeline.csv
# A client's DOCX as Markdown, to quote from it
pandoc client-scope.docx -t markdown -o client-scope.md
```

The YAML block at the top of `findings.md` sets the document's metadata:

```markdown
---
title: Site A incident report
author: Blackbird Cyber
date: 2026-10-06
---
```

## Output and evidence

Keep the Markdown sources and the rendered files in the case folder, convert the
final version to PDF and hash what is handed over:

```sh
CASE=~/cases/site-a
cd "$CASE/report"
pandoc findings.md -o report.docx --reference-doc=reference.docx --toc
libreoffice --headless --convert-to pdf report.docx
sha256sum findings.md report.docx report.pdf >> "$CASE/SHA256SUMS"
```

Image paths in the Markdown are relative to the directory pandoc runs in, so run
it from the report folder. See [evidence
handling](../../lifecycle/evidence-handling.md).

## Related tools

- [LibreOffice](libreoffice.md): edit the DOCX or ODT, and convert it to PDF.
- [CherryTree](cherrytree.md): its text export is a starting point for the
  Markdown.
- [Flameshot](flameshot.md): the figures the Markdown refers to.

## Upstream documentation

- [Pandoc User's Guide](https://pandoc.org/MANUAL.html): every option, the
  Markdown dialect, templates and reference documents.
