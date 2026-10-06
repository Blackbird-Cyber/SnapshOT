# SnapshOT Wiki

The SnapshOT Wiki is an offline documentation site that ships on the image:
every tool in the menu, documented against the OT incident-response lifecycle
(SANS PICERL, NIST CSF 2.0, MITRE ATT&CK for ICS). It is built with MkDocs
Material when the `snapshot-wiki` package is built, installed to
`/usr/share/snapshot/wiki`, and opened from **08 - Reference > SnapshOT Wiki**
in Firefox ESR, from `file://`, with no network. Search, tags and the
interactive graphs all work offline.

This guide is for authors and maintainers. Readers start at the wiki's own
home page.

## Package layout

```
packages/snapshot-wiki/
  debian/               control, rules (mkdocs build --strict), changelog, copyright,
                        preinst/postinst/postrm (the helpers.rc divert)
  mkdocs.yml            site settings; no nav: (the hook builds it)
  data/
    folders.yaml        the eight menu folders
    lifecycle.yaml      the six PICERL phases, CSF 2.0 functions, SANS controls,
                        wire classes, ATT&CK roles
    attack-ics.yaml     the 12 ATT&CK for ICS tactics and every technique id
    protocols.yaml      protocol slugs for tool pages and primers
  docs/                 the Markdown pages (below)
  docs/graphs/*.yaml    hand-written graph data
  hooks/snapshot_wiki.py  build-time logic (python3 + yaml only)
  overrides/            Material template overrides (the footer)
  assets/css/snapshot.css       the dark SnapshOT theme
  assets/js/snapshot-graphs.js  mounts vis-network on graph placeholders
  assets/vendor/        vis-network and the iframe-worker shim (ORIGIN.md, licences)
  assets/img/           the SnapshOT mark and favicon (from branding/exports)
  templates/            page skeletons to copy (not built)
  scripts/import-vendor-js.sh   refreshes assets/vendor (network, run by hand)
  rootfs/               files installed as is: the Firefox policy and prefs,
                        mimeapps.list, the replacement helpers.rc
```

## Site structure

Three tabs. Pages marked *generated* are produced by the hook from front-matter
and data files; never create them by hand (the build fails if you do).

| Tab | Path under `docs/` | Content |
|---|---|---|
| Home | `index.md` | the home page: cards, the lifecycle graph, the phase table |
| | `platform/*.md` | Platform guide: `live-and-install`, `admin-and-capture`, `network-defaults`, `vendor-layer`, `reference-data`, `build-manifest`, `architectures`, `field-updates`, `browser`, `using-this-wiki` (in that order) |
| Lifecycle | `lifecycle/index.md` | the PICERL model and why it fits OT field work |
| | `lifecycle/rules-of-engagement.md`, `wire-classes.md`, `evidence-handling.md` | Rules of engagement section |
| | `lifecycle/phases/<id>.md` | one page per phase id in `data/lifecycle.yaml` |
| | `lifecycle/playbooks/*.md` | engagement playbooks: `passive-baseline`, `active-enumeration`, `protocol-interrogation`, `firmware-acquisition`, `wireless-survey`, `ir-triage`, `reporting-handover` first, others after |
| | `lifecycle/attack-ics/index.md` | ATT&CK for ICS introduction |
| | `lifecycle/attack-ics/<tactic>.md` | *generated*: one page per tactic |
| | `lifecycle/crosswalk.md` | PICERL against the frameworks |
| | `lifecycle/matrix.md` | *generated*: tools against phases and tactics |
| Tools | `tools/index.md` | *generated*: every tool |
| | `tools/<folder>/index.md` | *generated*: one page per menu folder |
| | `tools/<folder>/<slug>.md` | one page per tool |
| | `tools/protocol-primers/index.md` | *generated*: protocols, ports, the tools that speak them |
| | `tools/protocol-primers/<protocol>.md` | protocol primers; the file name is a slug from `data/protocols.yaml` |
| (none) | `tags.md` | the tag index, linked from pages |

The navigation is generated from this table and `data/folders.yaml`. A new page
appears once its file exists; pages in a known directory but not in the
preferred order are added after it, by title. Nobody edits `nav:`.

The tool folder slugs are `recon`, `traffic`, `protocols`, `firmware`,
`wireless`, `forensics`, `reporting` and `reference`. Protocol primers are in
`tools/protocol-primers/`, not `tools/protocols/`, which is the 03 Protocol
Tools folder.

## Rules for every page

- Front-matter `title` and `summary` (one line). The hook renders the H1, the
  summary as the lede and the badges; **never write an H1** (`# ...`).
- Link other pages with relative Markdown links to their `.md` files. Links are
  checked at build time; a link to a page that does not exist fails the build.
- External links are fine (the reader chooses to follow them); nothing may be
  *loaded* from the network (no remote images, scripts, fonts or iframes).
- House style: **SnapshOT** in prose and `snapshot` in paths and commands; no
  em-dashes; no package versions (they change with the pin; the build manifest
  has them); documentation addresses (`192.0.2.0/24`) for example targets;
  only flags you have checked against the trixie package (`--help`, `man`).

## Tool pages

Copy `templates/tool-page.md` (or `templates/tool-page-not-shipped.md` for a
vendor tool whose lock stanza is disabled) to `docs/tools/<folder>/<slug>.md`.
`nmap`, `tshark` and `mbpoll` are the worked examples.

### Front-matter

| Key | Required | Values |
|---|---|---|
| `title` | yes | the tool as the operator types or sees it |
| `summary` | yes | one line; the launcher's `Comment=` where one exists |
| `folder` | yes | a folder slug; must match the directory |
| `launchers` | yes | `.desktop` ids: SnapshOT launchers in `packages/snapshot-menu`, or upstream ids pulled into a folder by `snapshot.menu` (e.g. `org.wireshark.Wireshark.desktop`); `[]` if none |
| `ships_as` | yes | `apt`, `vendor`, `upstream-gui` or `snapshot` (our own package) |
| `package` | yes | the apt package, the `vendor/sources.lock` stanza name, or our package; a list of names (`[qemu-system-x86, qemu-system-arm, qemu-utils]`) for a tool split over several packages, rendered comma-separated in the facts box (a vendor tool has exactly one stanza) |
| `arch` | yes | `[amd64, arm64]`, or one of them |
| `status` | yes | `shipped`, or `not-shipped` (vendor tools whose stanza is `enabled: false`) |
| `wire` | yes | `passive` (never transmits), `active` (sends, reads only), `writes` (changes device state or media) |
| `phases` | yes | phase id -> one line on how the tool is used in that phase; at least one |
| `csf` | yes | CSF 2.0 function ids: `govern`, `identify`, `protect`, `detect`, `respond`, `recover` |
| `attack_ics` | yes | tactic slugs from `data/attack-ics.yaml`; `[]` with `attack_role: none` |
| `attack_role` | yes | `detects`, `investigates`, `resembles` or `none` |
| `attack_techniques` | no | technique ids from `data/attack-ics.yaml`, only where certain |
| `protocols` | no | slugs from `data/protocols.yaml` |
| `upstream` | no | the upstream manual's URL |

Phase ids: `preparation`, `identification`, `containment`, `eradication`,
`recovery`, `lessons-learned`. Tactic slugs: `initial-access`, `execution`,
`persistence`, `privilege-escalation`, `evasion`, `discovery`,
`lateral-movement`, `collection`, `command-and-control`,
`inhibit-response-function`, `impair-process-control`, `impact`. ATT&CK v19
moved several techniques into the T16xx range (for example T1692 Unauthorized
Message, T1693 Modify Firmware, T1694 Insecure Credentials); use the ids in the
data file, not older ones from memory.

### Body

Put `<!-- snapshot:facts -->` on a line of its own straight after the
front-matter; the hook replaces it with the facts box (folder, launchers, how
it ships, architectures, version pointer, wire class, phases, CSF, tactics,
techniques, protocols, upstream). Never repeat that metadata in prose.

The `##` sections must be exactly, in this order: What it is; Why it is on
SnapshOT; On the wire; PICERL mapping; MITRE ATT&CK for ICS mapping; Quick
start; Output and evidence; Related tools; Upstream documentation. Under
PICERL mapping, one `###` per phase in `phases:`, named as the phase
(Preparation, Identification, Containment, Eradication, Recovery, Lessons
Learned). A not-shipped page has: What it is; Why it is not shipped; What to use
instead; Upstream documentation.

In Quick start, put each command's explanation on a comment line above it;
code blocks are narrow. The launcher's own command comes first, vendor tools are
`/opt/snapshot/<tool>/bin/<cmd>`, and `sudo` appears only where the image needs
it (capture with Wireshark, tshark and termshark needs none: the user is in
group `wireshark`; serial ports need none: group `dialout`).

### Adding a tool

1. Copy the template to `docs/tools/<folder>/<slug>.md` and fill it in.
2. List every SnapshOT launcher for the tool in `launchers:`. Each
   `snapshot-*.desktop` in `packages/snapshot-menu` (other than the root
   terminal, reference folder, build manifest and wiki launchers) must be listed
   by exactly one tool page.
3. Run `scripts/check-wiki.sh --partial` while other pages are still being
   written, `scripts/check-wiki.sh` when everything is in place.

Tags (phase, ATT&CK tactic, folder, wire class, protocol) are set from the
front-matter; the tags index lists them. They are not shown on the page itself,
where the facts box carries the same information.

## Phase pages

Copy `templates/phase-page.md` to `docs/lifecycle/phases/<id>.md`. The H1 and
the "Phase N of 6" and CSF badges come from `data/lifecycle.yaml`. Sections, in
order: Definition and OT reading; Entry and exit criteria; Decisions and
authorizations; ATT&CK for ICS tactics in play; Tools in this phase; Playbooks
for this phase; Crosswalk; Pitfalls and stop conditions. The markers render the
generated parts:

| Marker | Renders | From |
|---|---|---|
| `<!-- snapshot:phase-tactics -->` (required) | the tactics in play, with ids and why they matter here | `tactics:` of the phase in `data/lifecycle.yaml` |
| `<!-- snapshot:phase-tools -->` (required) | every tool page whose `phases:` lists the phase, with its one-line note | tool front-matter |
| `<!-- snapshot:phase-playbooks -->` (required) | playbooks whose `phases:` lists the phase | playbook front-matter |
| `<!-- snapshot:phase-crosswalk -->` | CSF 2.0, SP 800-61r3, SP 800-82r3 and SANS controls for the phase | `csf:` and `anchors:` in `data/lifecycle.yaml` |

`identification.md` is the worked example.

## Playbooks

`docs/lifecycle/playbooks/<name>.md` with front-matter `title`, `summary`,
`phases` (one or two phase ids) and optionally `tactics` (tactic slugs). No H1.
The phase badges are rendered under the title and the playbook is listed on its
phases' pages.

## Other pages and their markers

Every other page (platform guide, rules of engagement, primers, the lifecycle
and ATT&CK introductions) needs only `title` and `summary`, and may use:

| Marker | Renders |
|---|---|
| `<!-- snapshot:cards -->` | the home page card grid; a card links only once its page exists |
| `<!-- snapshot:phases -->` | the six phases with summary and CSF functions |
| `<!-- snapshot:tactics -->` | the twelve tactics with MITRE's descriptions, their phases and tool counts |

These markers link only to pages that exist, so a page can mention sections
another author has not written yet.

## Data files

- `data/folders.yaml`: slug, number, name, `.directory` file, X-SnapshOT
  category, graph colour and one-line summary of each menu folder.
  `check-wiki.sh` compares it with `packages/snapshot-menu`.
- `data/lifecycle.yaml`: the phases (id, number, name, summary, OT reading, CSF
  functions, tactics in play with a note each, crosswalk anchors), the CSF 2.0
  functions, the SANS Five ICS Critical Controls, the wire classes and the
  ATT&CK roles.
- `data/attack-ics.yaml`: the 12 tactics (slug, TA id, name, MITRE's
  description, what a field kit can see) and every ICS technique and
  sub-technique id with its name, copied from attack.mitre.org (v19). Tool
  pages may only use ids listed there. MITRE's copyright notice is in the file
  and on the tactic pages.
- `data/protocols.yaml`: protocol slug, name, family and usual ports. Add a
  protocol here only when a tool page needs it.

## Graphs

A graph is placed in a page with a placeholder and a one-sentence fallback for
browsers without JavaScript:

```html
<div class="snapshot-graph" data-graph="purdue" data-height="620">
<p class="snapshot-graph__fallback">One sentence saying what the graph shows.</p>
</div>
```

`lifecycle` (phases and tools, tools coloured by menu folder) and `attack`
(tactics and tools, coloured by ATT&CK role) are generated from the tool pages.
Any other name is `docs/graphs/<name>.yaml`:

```yaml
title: Purdue levels, zones and where SnapshOT attaches
layout: hierarchical        # or force (the default)
direction: UD               # hierarchical only: UD, DU, LR or RL
groups:                     # styling and legend; every node's group must be here
  control: {color: purple, shape: box, label: "Control zone (levels 1 and 2)"}
  snapshot: {color: red, shape: dot, label: "Where SnapshOT attaches"}
nodes:
  - {id: l1, level: 5, group: control, label: "Level 1\nBasic control", title: "Tooltip text."}
  - {id: serial, level: 5, group: snapshot, label: "Serial", url: tools/protocols/mbpoll.md}
edges:
  - {from: serial, to: l1, color: red}
  - {from: l2, to: l1, dashes: true, label: "conduit"}
```

Colours are palette names (`red`, `light`, `muted`, `surface`, `teal`,
`green`, `amber`, `blue`, `purple`, `cobalt`, `coral`, `sand`) or `#RRGGBB`.
Shapes: `dot`, `box`, `ellipse`, `circle`, `diamond`, `square`, `triangle`,
`hexagon`, `database`, `text`. A hierarchical graph needs a `level` on every
node. `url` is a page under `docs/` (it must exist); clicking the node opens it.
Edge keys: `label`, `title`, `dashes`, `arrows` (`true`, `to`, `from`), `color`.

The hook writes each graph to `assets/graphs/<name>.js` as
`window.SNAPSHOT_GRAPHS["<name>"] = {...}` (a script rather than JSON, because
`fetch()` does not work on `file://`) and adds vis-network, the data and
`assets/js/snapshot-graphs.js` to the pages that use it. Readers pan by
dragging and zoom with the + and - buttons at the top right of the graph (the
wheel scrolls the page unless the graph is full screen), hover to highlight a
node's links and click to open a node's page. The third button opens the graph
full screen: native where the browser allows it, a fixed overlay otherwise,
and Escape leaves either.

## What the build hook does

`hooks/snapshot_wiki.py` (its docstring has the detail):

1. loads the data files and the package version from `debian/changelog`;
2. validates front-matter and section headings of tool, phase and playbook
   pages, and the title and summary of every page, reporting each problem as a
   warning so `mkdocs build --strict` fails;
3. generates the navigation;
4. generates the tool, folder, protocol, tactic and matrix pages;
5. renders titles, ledes, badges, facts boxes (kept out of the search index, so
   results quote each page's own prose), the marker sections and the Material
   tags; the generated phase and tactic tables mark tools that are not shipped
   or run on one architecture only, and the matrix turns its column headings so
   six phases and twelve tactics fit the page;
6. writes the graph data and adds the graph scripts to the pages that need them;
7. points Material's offline search shim at the vendored copy instead of
   `https://unpkg.com/iframe-worker/shim`, and removes the sitemap and source
   maps.

The footer shows the package version, never a build time, and two builds are
byte-identical.

## Building and previewing

The package build runs `mkdocs build --strict -d build/site` (`debian/rules`);
the builder image has the Build-Depends. To build or preview the site alone:

```sh
docker run --rm -v "$PWD/packages/snapshot-wiki":/w -w /w debian:trixie bash -c \
  'apt-get update -qq && apt-get install -y -qq --no-install-recommends mkdocs-material python3-pymdownx python3-yaml >/dev/null &&
   mkdocs build --strict -d build/site'
```

Then open `packages/snapshot-wiki/build/site/index.html` in a browser
(`build/` is ignored by git).

## Checks

| Script | Time | What it checks |
|---|---|---|
| `scripts/check-wiki.sh` | about 20 s | strict build, two identical builds, nothing remote in the site, offline search index, graph data for every graph, launcher coverage (each tool launcher listed by exactly one tool page, in its own folder), `status` against `vendor/sources.lock`, `data/folders.yaml` against the menu's `.directory` files, a page for every phase, `policies.json`, the wiki launcher, no em-dashes |
| `scripts/check-wiki.sh --partial` | about 20 s | the same, but links to pages not written yet, undocumented launchers and missing phase pages are warnings, for use while content is being written |
| `scripts/check-firefox-quiet.sh` | about 2 min | with the firefox-esr of the image's Debian snapshot pin: every policy in `policies.json` known to that Firefox's own schema, the `about:policies` screenshot (`build/firefox-quiet/about-policies.png`), the default-browser chain, and zero packets in 45 seconds of Firefox on the wiki |
| `scripts/check-desktop.sh` | about 10 s | includes the wiki launcher in 08 - Reference and Firefox in Usual Applications |

All run in `debian:trixie` containers and exit non-zero on failure.

## Firefox ESR

`firefox-esr` is in `config/package-lists/snapshot-reference.list.chroot`: it
shows the wiki and is the browser for PLC, HMI and switch web interfaces on an
engagement. `snapshot-wiki` makes it quiet:

- `/etc/firefox/policies/policies.json` is the enterprise policy. Debian's
  firefox-esr reads this path (checked with `about:policies`;
  `/etc/firefox-esr/policies/` is not read). It turns off telemetry, studies,
  application and extension updates,
  Firefox accounts, DNS over HTTPS, captive-portal and connectivity checks,
  prefetching and speculative connections, Safe Browsing, search suggestions,
  sponsored and new-tab content, the password manager (KeePassXC is the store)
  and push, and sets the wiki as the home page. JavaScript and `file://` stay
  on: the wiki needs both.
- `/etc/firefox-esr/snapshot-quiet.js` sets the preferences the policy engine
  refuses ("not allowed for stability reasons": `toolkit.telemetry.*`,
  Normandy, the health report). Debian's firefox-esr reads every `*.js` in
  `/etc/firefox-esr/`; its own `firefox-esr.js` is left alone.
- **Remote Settings** (and the Nimbus rollouts it delivers) has no policy in
  the pinned Firefox ESR 140: `DisableRemoteSettingsAndAcceptSecurityConsequences`
  and `DisableRemoteImprovements` arrive in a later ESR, and 140 lists them as
  unknown policies in `about:policies`. `snapshot-quiet.js` therefore resolves
  its three hosts (`firefox.settings.services.mozilla.com`,
  `firefox-settings-attachments.cdn.mozilla.net`,
  `content-signature-2.cdn.mozilla.net`) to loopback with
  `network.dns.localDomains`, so no query or connection leaves the machine.
  When the pin moves to an ESR that knows those policies, add them back to
  `policies.json`; `check-firefox-quiet.sh` fails on any policy the pinned
  Firefox does not know.
- **Consequence of disabling Remote Settings:** Firefox does not receive
  certificate revocation and intermediate updates, add-on blocklists or
  updated search and security lists. That is the price of a browser that never
  calls home; the image is re-imaged rather than updated in place.
- `DisablePocket` is not set: Firefox 140 deprecates it.

The default browser: the launcher runs `exo-open --launch WebBrowser`, which
reads `/etc/xdg/xfce4/helpers.rc`. `snapshot-wiki` diverts xfce4-helpers' copy
and links that path to `/usr/share/snapshot-wiki/xfce4-helpers.rc`: the same
keys, with `WebBrowser=debian-sensible-browser`. xfce4-helpers' `firefox` helper
cannot be used because its binaries list does not include `firefox-esr`;
`sensible-browser` (from `sensible-utils`: Priority important, so it is in the
debootstrap base, and a dependency of `snapshot-wiki` as well) runs
`x-www-browser`, which firefox-esr provides.
`/etc/xdg/mimeapps.list` sends HTML and http(s) links to `firefox-esr.desktop`.
See [desktop.md](desktop.md) for the divert.

## Vendored JavaScript

`assets/vendor/` holds vis-network (the graphs) and the iframe-worker shim
(offline search on `file://`), with their licences and `ORIGIN.md`. To refresh:
edit the version, URL and npm `dist.integrity` at the top of
`packages/snapshot-wiki/scripts/import-vendor-js.sh`, run it (network needed),
review the diff, run `scripts/check-wiki.sh` and commit. The package build never
touches the network.
