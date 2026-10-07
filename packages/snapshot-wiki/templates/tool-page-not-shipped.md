---
# For a vendor-layer tool whose vendor/sources.lock stanza is `enabled: false`:
# its launcher exists in packages/snapshot-menu but TryExec hides it, or, for a
# tool whose launcher was dropped from the menu, there is none: launchers: [].
# Copy to docs/tools/<folder>/<slug>.md. Same keys as templates/tool-page.md;
# the PICERL notes say where the tool WOULD be used. Remove these comments.
title: TOOL
summary: ONE LINE
folder: FOLDER
launchers: [snapshot-TOOL.desktop]
ships_as: vendor                  # only vendor tools can be not-shipped
package: STANZA                   # the vendor/sources.lock stanza name
arch: [amd64, arm64]
status: not-shipped
wire: passive
phases:
  identification: ONE LINE
csf: [detect]
attack_ics: [discovery]
attack_role: detects
upstream: https://example.invalid/docs
---

<!-- snapshot:facts -->

## What it is

Two to four sentences on what the tool would add.

## Why it is not shipped

Why the lock stanza is disabled, in the words of `vendor/sources.lock` and
`docs/vendoring.md`, with a link to the vendor layer platform page.

## What to use instead

The shipped tools that cover the same job, linked.

## Upstream documentation

- [Upstream manual](https://example.invalid/docs): what it covers.
