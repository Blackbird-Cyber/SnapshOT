"""SnapshOT Wiki build hook (MkDocs 1.6 ``hooks:``; needs only python3 and yaml).

Metadata lives in one place, the front-matter of each page and the files under
``data/``, and everything derived from it is produced here at build time:

1. Data and version (``on_config``). Load ``data/*.yaml`` and the package
   version from the first line of ``debian/changelog``; the footer shows that
   version and never a timestamp.
2. Validation (``on_config``). Parse the front-matter of every page under
   ``docs/`` and check tool, phase and playbook pages against the data files
   and the page templates. Each problem is logged as a warning, so
   ``mkdocs build --strict`` (what ``debian/rules`` runs) fails.
3. Navigation (``on_config``). Build ``nav`` from the site structure below and
   ``data/folders.yaml``. Nobody edits ``nav:`` by hand; a new page appears in
   the navigation once its file exists.
4. Generated pages (``on_files``). ``tools/index.md``, one
   ``tools/<folder>/index.md`` per menu folder, ``tools/protocol-primers/index.md``,
   ``lifecycle/matrix.md`` and ``lifecycle/attack-ics/<tactic>.md`` are created
   with ``File.generated()``. The package's ``assets/`` tree is added too.
5. Page decoration (``on_page_markdown``). Every page gets its H1, lede and
   badges from the front-matter (authors never write an H1). Tool pages get the
   facts box at ``<!-- snapshot:facts -->`` and their Material tags; phase pages
   get the generated sections at ``<!-- snapshot:phase-tactics -->``,
   ``-tools``, ``-playbooks`` and ``-crosswalk``.
6. Graphs (``on_post_page``, ``on_post_build``). A page containing
   ``<div class="snapshot-graph" data-graph="NAME">`` gets vis-network, the
   graph data and ``assets/js/snapshot-graphs.js``. The data is written to
   ``assets/graphs/NAME.js`` (``window.SNAPSHOT_GRAPHS["NAME"] = ...``; a script,
   not JSON, because ``fetch()`` fails on ``file://``) from
   ``docs/graphs/NAME.yaml``, or from the tool front-matter for the generated
   ``lifecycle`` and ``attack`` graphs.
7. Offline shim (``on_post_page``, ``on_post_template``). Material's offline
   plugin loads ``https://unpkg.com/iframe-worker/shim``; every page gets the
   vendored copy by a page-relative path instead. The sitemap (absolute URLs
   and dates, useless offline) and Material's source maps are removed.
"""

from __future__ import annotations

import html
import json
import logging
import os
import posixpath
import re
from dataclasses import dataclass

import yaml
from mkdocs.structure.files import File
from mkdocs.utils import get_relative_url
from mkdocs.utils.meta import get_data

log = logging.getLogger("mkdocs.hooks.snapshot_wiki")

# ---------------------------------------------------------------------------
# Site structure (paths are relative to docs/)
# ---------------------------------------------------------------------------

# Preferred order inside each section; other pages in the same directory are
# appended, sorted by title, so new pages need no change here.
PLATFORM_ORDER = ["live-and-install", "admin-and-capture", "network-defaults",
                  "vendor-layer", "reference-data", "build-manifest",
                  "architectures", "field-updates", "browser", "using-this-wiki"]
ROE_ORDER = ["rules-of-engagement", "wire-classes", "evidence-handling"]
PLAYBOOK_ORDER = ["passive-baseline", "active-enumeration", "protocol-interrogation",
                  "firmware-acquisition", "wireless-survey", "ir-triage",
                  "reporting-handover"]

PRIMERS_DIR = "tools/protocol-primers"
NOT_IN_NAV = {"tags.md"}
BUILD_MANIFEST_PAGE = "platform/build-manifest.md"
VENDOR_LAYER_PAGE = "platform/vendor-layer.md"
WIRE_CLASSES_PAGE = "lifecycle/wire-classes.md"
MANIFEST_FILE = "/usr/share/snapshot/reference/BUILD-MANIFEST.txt"

SHIM_URL = "https://unpkg.com/iframe-worker/shim"
SHIM_PATH = "assets/vendor/iframe-worker-shim.js"
VIS_PATH = "assets/vendor/vis-network.min.js"
GRAPHS_JS = "assets/js/snapshot-graphs.js"
GENERATED_GRAPHS = ("lifecycle", "attack")

# ---------------------------------------------------------------------------
# Page schemas and templates
# ---------------------------------------------------------------------------

# `package` is one name or, for a tool split over several Debian packages
# (QEMU), a list of names; validate_tool checks the elements.
TOOL_REQUIRED = {"title": str, "summary": str, "folder": str, "launchers": list,
                 "ships_as": str, "package": (str, list), "arch": list, "status": str,
                 "wire": str, "phases": dict, "csf": list, "attack_ics": list,
                 "attack_role": str}
TOOL_OPTIONAL = {"attack_techniques": list, "protocols": list, "upstream": str}
PLAYBOOK_REQUIRED = {"title": str, "summary": str, "phases": list}
PLAYBOOK_OPTIONAL = {"tactics": list}
SHIPS_AS = {"apt": "Debian package", "vendor": "Vendor layer",
            "upstream-gui": "Debian package (upstream menu entry)",
            "snapshot": "SnapshOT package"}
STATUS = {"shipped": "Shipped", "not-shipped": "Not shipped"}
ARCHES = ("amd64", "arm64")

TOOL_SECTIONS = {
    "shipped": ["What it is", "Why it is on SnapshOT", "On the wire", "PICERL mapping",
                "MITRE ATT&CK for ICS mapping", "Quick start", "Output and evidence",
                "Related tools", "Upstream documentation"],
    "not-shipped": ["What it is", "Why it is not shipped", "What to use instead",
                    "Upstream documentation"],
}
PHASE_SECTIONS = ["Definition and OT reading", "Entry and exit criteria",
                  "Decisions and authorizations", "ATT&CK for ICS tactics in play",
                  "Tools in this phase", "Playbooks for this phase", "Crosswalk",
                  "Pitfalls and stop conditions"]
PHASE_MARKERS = ["phase-tactics", "phase-tools", "phase-playbooks", "phase-crosswalk"]
REQUIRED_PHASE_MARKERS = ["phase-tactics", "phase-tools", "phase-playbooks"]
# Markers any other hand-written page may use. Their links only point at pages
# that exist, so a page can list sections other authors have not written yet.
PAGE_MARKERS = ["cards", "phases", "tactics"]
MARKER_RE = re.compile(r"<!--\s*snapshot:([a-z-]+)\s*-->")

# The home page card grid (<!-- snapshot:cards -->): icon, title, target, text.
HOME_CARDS = [
    ("material-sync", "Lifecycle", "lifecycle/index.md",
     "The six PICERL phases read for OT field work, with the tools and ATT&CK for ICS tactics of each."),
    ("material-tools", "Tools", "tools/index.md",
     "Every tool on the image: what it does, how it behaves on the wire and where it fits."),
    ("material-shield-alert-outline", "Rules of engagement", "lifecycle/rules-of-engagement.md",
     "Authorization, windows, the engineer-present rule for writes and the stop conditions."),
    ("material-format-list-numbered", "Playbooks", "lifecycle/playbooks/passive-baseline.md",
     "Step-by-step engagements that chain the tools, with go and no-go checks."),
    ("material-lan", "Protocols", f"{PRIMERS_DIR}/index.md",
     "Modbus, S7comm, EtherNet/IP, OPC UA, BACnet, DNP3: ports, reads versus writes, what to watch."),
    ("material-laptop", "Platform", "platform/live-and-install.md",
     "Live session and install, capture without root, quiet networking, the vendor layer."),
]

# Graph colours: names usable in docs/graphs/*.yaml, from the SnapshOT palette.
PALETTE = {"red": "#F1000E", "light": "#F4F5F6", "muted": "#8A8D91",
           "surface": "#23252e", "ink": "#0A0B0C", "teal": "#47D4B9",
           "green": "#5EBDAB", "amber": "#FEA44C", "blue": "#49AEE6",
           "purple": "#9755B3", "cobalt": "#277FFF", "coral": "#FF3B45",
           "sand": "#E6E6E6"}
ROLE_COLORS = {"detects": "#47D4B9", "investigates": "#49AEE6", "resembles": "#FEA44C"}
GRAPH_SHAPES = {"dot", "box", "ellipse", "circle", "diamond", "square", "triangle",
                "hexagon", "database", "text"}

FENCE_RE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*#*\s*$")
GRAPH_REF_RE = re.compile(r'data-graph="([^"]+)"')


# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------

@dataclass
class Page:
    """A hand-written page: its docs-relative path, front-matter and body."""
    src: str
    meta: dict
    body: str
    kind: str  # tool | primer | phase | playbook | page
    valid: bool = True  # False once validation reported a problem

    @property
    def stem(self) -> str:
        return posixpath.splitext(posixpath.basename(self.src))[0]

    @property
    def title(self) -> str:
        return str(self.meta.get("title", self.stem))


class Wiki:
    """Everything loaded in on_config and used by the later events."""

    def __init__(self, config):
        self.root = os.path.dirname(os.path.abspath(config.config_file_path))
        self.docs_dir = config.docs_dir
        self.version = read_version(os.path.join(self.root, "debian", "changelog"))
        data = os.path.join(self.root, "data")
        self.folders = load_yaml(os.path.join(data, "folders.yaml"))["folders"]
        lifecycle = load_yaml(os.path.join(data, "lifecycle.yaml"))
        attack = load_yaml(os.path.join(data, "attack-ics.yaml"))
        protocols = load_yaml(os.path.join(data, "protocols.yaml"))["protocols"]
        self.folder = {f["slug"]: f for f in self.folders}
        self.phases = lifecycle["phases"]
        self.phase = {p["id"]: p for p in self.phases}
        self.csf = {c["id"]: c for c in lifecycle["csf_functions"]}
        self.sans = {s["number"]: s for s in lifecycle["sans_controls"]}
        self.wire = {w["id"]: w for w in lifecycle["wire_classes"]}
        self.role = {r["id"]: r for r in lifecycle["attack_roles"]}
        self.tactics = attack["tactics"]
        self.tactic = {t["slug"]: t for t in self.tactics}
        self.techniques = attack["techniques"]
        self.attack_version = str(attack.get("attack_version", ""))
        self.protocols = protocols
        self.protocol = {p["slug"]: p for p in protocols}
        self.pages: dict[str, Page] = {}
        self.generated: dict[str, str] = {}   # src -> markdown, filled in on_config
        self.graph_refs: dict[str, set] = {}  # graph name -> pages using it

    # -- lookups ------------------------------------------------------------

    def exists(self, src: str) -> bool:
        return src in self.pages or src in self.generated

    def tools(self) -> list[Page]:
        """Valid tool pages in menu order: folder number, then title. Invalid
        ones are left out of every generated table (their problems are already
        reported), so a bad page cannot crash the build."""
        order = {f["slug"]: i for i, f in enumerate(self.folders)}
        tools = [p for p in self.pages.values() if p.kind == "tool" and p.valid]
        return sorted(tools, key=lambda p: (order.get(p.meta.get("folder"), 99),
                                            p.title.lower()))

    def of_kind(self, kind: str) -> list[Page]:
        return sorted((p for p in self.pages.values() if p.kind == kind),
                      key=lambda p: p.src)

    def folder_label(self, slug: str) -> str:
        f = self.folder[slug]
        return f"{f['number']} {f['name']}"

    def technique_name(self, tid: str) -> str:
        """Sub-techniques read "Parent: Child", e.g. Unauthorized Message: Command Message."""
        name = self.techniques[tid]
        if "." in tid:
            name = f"{self.techniques.get(tid.split('.')[0], '')}: {name}"
        return name


WIKI: Wiki | None = None


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def load_yaml(path: str):
    with open(path, encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def read_version(changelog: str) -> str:
    """Version from the first line of debian/changelog: 'pkg (VERSION) dist; ...'."""
    try:
        with open(changelog, encoding="utf-8") as fh:
            first = fh.readline()
    except OSError:
        log.warning("snapshot-wiki: cannot read %s for the footer version", changelog)
        return "unknown"
    m = re.match(r"^\S+\s+\(([^)]+)\)", first)
    if not m:
        log.warning("snapshot-wiki: no version on the first line of %s", changelog)
        return "unknown"
    return m.group(1)


PROBLEMS = 0


def problem(src: str, message: str) -> None:
    """Report a content problem; under --strict it fails the build."""
    global PROBLEMS
    PROBLEMS += 1
    log.warning("snapshot-wiki: %s: %s", src, message)


def rel(from_src: str, to_src: str) -> str:
    """Link from one docs page to another, relative, as Markdown wants it."""
    return posixpath.relpath(to_src, posixpath.dirname(from_src) or ".")


def html_path(src: str) -> str:
    """docs/ path -> site path (use_directory_urls is false)."""
    return posixpath.splitext(src)[0] + ".html"


def text(value) -> str:
    """Free text for a Markdown table cell: one line, pipes escaped."""
    return " ".join(str(value).split()).replace("|", "\\|")


def table(headers: list[str], rows: list[list[str]]) -> str:
    lines = ["| " + " | ".join(headers) + " |",
             "|" + "|".join("---" for _ in headers) + "|"]
    lines += ["| " + " | ".join(row) + " |" for row in rows]
    return "\n".join(lines)


def headings(markdown: str) -> list[tuple[int, str]]:
    """(level, text) of every ATX heading outside fenced code."""
    found, fence = [], None
    for line in markdown.splitlines():
        m = FENCE_RE.match(line)
        if fence:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence):
                fence = None
            continue
        if m:
            fence = m.group(1)
            continue
        h = HEADING_RE.match(line)
        if h:
            title = re.sub(r"\s*\{[^}]*\}\s*$", "", h.group(2)).strip()
            found.append((len(h.group(1)), title))
    return found


def classify(src: str, folders: dict) -> str:
    parts = src.split("/")
    if len(parts) == 3 and parts[0] == "tools" and parts[2] != "index.md":
        if parts[1] in folders:
            return "tool"
        if "/".join(parts[:2]) == PRIMERS_DIR:
            return "primer"
    if len(parts) == 3 and parts[:2] == ["lifecycle", "phases"]:
        return "phase"
    if len(parts) == 3 and parts[:2] == ["lifecycle", "playbooks"]:
        return "playbook"
    return "page"


# ---------------------------------------------------------------------------
# 2. Validation
# ---------------------------------------------------------------------------

def type_name(kind) -> str:
    kinds = kind if isinstance(kind, tuple) else (kind,)
    return " or a ".join(k.__name__ for k in kinds)


def check_keys(page: Page, required: dict, optional: dict) -> bool:
    ok = True
    for key, kind in required.items():
        if key not in page.meta:
            problem(page.src, f"front-matter is missing '{key}'")
            ok = False
        elif not isinstance(page.meta[key], kind):
            problem(page.src, f"'{key}' must be a {type_name(kind)}")
            ok = False
    for key, kind in optional.items():
        if key in page.meta and not isinstance(page.meta[key], kind):
            problem(page.src, f"'{key}' must be a {type_name(kind)}")
            ok = False
    for key in page.meta:
        if key not in required and key not in optional:
            problem(page.src, f"unknown front-matter key '{key}'")
    return ok


def check_sections(page: Page, wanted: list[str]) -> None:
    """The H2 headings must be exactly the template's, in its order; no H1."""
    hs = headings(page.body)
    if any(level == 1 for level, _ in hs):
        problem(page.src, "do not write an H1; the title comes from the front-matter")
    have = [t for level, t in hs if level == 2]
    if have != wanted:
        problem(page.src, "sections (## headings) must be, in order: "
                + "; ".join(wanted) + ". Found: " + ("; ".join(have) or "none"))


def check_markers(page: Page, allowed: list[str], required: list[str]) -> None:
    found = MARKER_RE.findall(page.body)
    for name in found:
        if name not in allowed:
            problem(page.src, f"marker <!-- snapshot:{name} --> does not belong on this page")
    for name in required:
        if found.count(name) != 1:
            problem(page.src, f"needs exactly one <!-- snapshot:{name} --> marker")


def validate_tool(w: Wiki, page: Page) -> None:
    if not check_keys(page, TOOL_REQUIRED, TOOL_OPTIONAL):
        return
    m = page.meta
    folder_dir = page.src.split("/")[1]
    if m["folder"] not in w.folder:
        problem(page.src, f"folder '{m['folder']}' is not in data/folders.yaml")
    elif m["folder"] != folder_dir:
        problem(page.src, f"folder '{m['folder']}' but the page is in tools/{folder_dir}/")
    for launcher in m["launchers"]:
        if not isinstance(launcher, str) or not launcher.endswith(".desktop"):
            problem(page.src, f"launcher '{launcher}' is not a .desktop id")
    if m["ships_as"] not in SHIPS_AS:
        problem(page.src, f"ships_as must be one of {', '.join(SHIPS_AS)}")
    packages = package_names(m)
    if not packages or any(not isinstance(p, str) or not p.strip() for p in packages):
        problem(page.src, "package must be a non-empty name or a list of non-empty names")
    elif m["ships_as"] == "vendor" and isinstance(m["package"], list):
        problem(page.src, "a vendor tool's package is its one vendor/sources.lock stanza")
    if not m["arch"] or any(a not in ARCHES for a in m["arch"]):
        problem(page.src, "arch must list amd64 and/or arm64")
    if m["status"] not in STATUS:
        problem(page.src, "status must be shipped or not-shipped")
    elif m["status"] == "not-shipped" and m["ships_as"] != "vendor":
        problem(page.src, "only vendor-layer tools can be not-shipped")
    if m["wire"] not in w.wire:
        problem(page.src, f"wire must be one of {', '.join(w.wire)}")
    if not m["phases"]:
        problem(page.src, "phases needs at least one PICERL phase")
    for phase, note in m["phases"].items():
        if phase not in w.phase:
            problem(page.src, f"unknown phase '{phase}' (data/lifecycle.yaml)")
        if not isinstance(note, str) or not note.strip():
            problem(page.src, f"phases.{phase} needs a one-line note")
    for fn in m["csf"]:
        if fn not in w.csf:
            problem(page.src, f"unknown CSF function '{fn}'")
    for tactic in m["attack_ics"]:
        if tactic not in w.tactic:
            problem(page.src, f"unknown ATT&CK for ICS tactic '{tactic}' (data/attack-ics.yaml)")
    if m["attack_role"] not in w.role:
        problem(page.src, f"attack_role must be one of {', '.join(w.role)}")
    elif (m["attack_role"] == "none") != (not m["attack_ics"]):
        problem(page.src, "attack_role none goes with an empty attack_ics, and only then")
    for tid in m.get("attack_techniques", []):
        if tid not in w.techniques:
            problem(page.src, f"technique '{tid}' is not in the dictionary in data/attack-ics.yaml")
    for proto in m.get("protocols", []):
        if proto not in w.protocol:
            problem(page.src, f"unknown protocol '{proto}' (data/protocols.yaml)")
    upstream = m.get("upstream")
    if upstream is not None and not re.match(r"^https?://", upstream):
        problem(page.src, "upstream must be an http(s) URL")
    if m["status"] in TOOL_SECTIONS:
        check_sections(page, TOOL_SECTIONS[m["status"]])
    check_markers(page, ["facts"], ["facts"])
    if m["status"] == "shipped":
        h3 = {t for level, t in headings(page.body) if level == 3}
        for phase in m["phases"]:
            if phase in w.phase and w.phase[phase]["name"] not in h3:
                problem(page.src, f"PICERL mapping needs a '### {w.phase[phase]['name']}' subsection")


def validate_phase(w: Wiki, page: Page) -> None:
    if page.stem not in w.phase:
        problem(page.src, f"'{page.stem}' is not a phase id in data/lifecycle.yaml")
    check_keys(page, {"title": str, "summary": str}, {})
    check_sections(page, PHASE_SECTIONS)
    check_markers(page, PHASE_MARKERS, REQUIRED_PHASE_MARKERS)


def validate_playbook(w: Wiki, page: Page) -> None:
    if not check_keys(page, PLAYBOOK_REQUIRED, PLAYBOOK_OPTIONAL):
        return
    if not 1 <= len(page.meta["phases"]) <= 2:
        problem(page.src, "a playbook belongs to one or two phases")
    for phase in page.meta["phases"]:
        if phase not in w.phase:
            problem(page.src, f"unknown phase '{phase}'")
    for tactic in page.meta.get("tactics", []):
        if tactic not in w.tactic:
            problem(page.src, f"unknown tactic '{tactic}'")
    check_markers(page, [], [])
    if any(level == 1 for level, _ in headings(page.body)):
        problem(page.src, "do not write an H1; the title comes from the front-matter")


def validate_page(w: Wiki, page: Page) -> None:
    for key in ("title", "summary"):
        if not isinstance(page.meta.get(key), str):
            problem(page.src, f"front-matter needs a '{key}'")
    if any(level == 1 for level, _ in headings(page.body)):
        problem(page.src, "do not write an H1; the title comes from the front-matter")
    check_markers(page, PAGE_MARKERS, [])
    if page.kind == "primer" and page.stem not in w.protocol:
        problem(page.src, f"primer '{page.stem}' is not a protocol slug in data/protocols.yaml")


def scan_docs(w: Wiki) -> None:
    """Read and validate every hand-written page under docs/."""
    for dirpath, dirnames, filenames in os.walk(w.docs_dir):
        dirnames[:] = sorted(d for d in dirnames if d != "graphs" and not d.startswith("."))
        for name in sorted(filenames):
            if not name.endswith(".md"):
                continue
            path = os.path.join(dirpath, name)
            src = os.path.relpath(path, w.docs_dir).replace(os.sep, "/")
            with open(path, encoding="utf-8-sig") as fh:
                body, meta = get_data(fh.read())
            page = Page(src, meta or {}, body, classify(src, w.folder))
            w.pages[src] = page
    for page in w.pages.values():
        before = PROBLEMS
        {"tool": validate_tool, "phase": validate_phase,
         "playbook": validate_playbook}.get(page.kind, validate_page)(w, page)
        page.valid = PROBLEMS == before


# ---------------------------------------------------------------------------
# 3. Navigation
# ---------------------------------------------------------------------------

def ordered(w: Wiki, directory: str, order: list[str], kind: str | None = None) -> list[str]:
    """Pages directly in `directory`: the preferred order, then the rest by title."""
    pages = [p for p in w.pages.values()
             if posixpath.dirname(p.src) == directory and p.stem != "index"
             and (kind is None or p.kind == kind)]
    rank = {stem: i for i, stem in enumerate(order)}
    pages.sort(key=lambda p: (rank.get(p.stem, len(order)), p.title.lower()))
    return [p.src for p in pages]


def section(label: str, items: list) -> list:
    return [{label: items}] if items else []


def build_nav(w: Wiki) -> list:
    placed: set[str] = set()

    def take(items: list) -> list:
        for item in items:
            if isinstance(item, str):
                placed.add(item)
            else:
                for children in item.values():
                    take(children)
        return items

    exists = [s for s in ("index.md",) if w.exists(s)]
    home = take(exists + section("Platform guide", ordered(w, "platform", PLATFORM_ORDER)))

    lifecycle = take(
        [s for s in ("lifecycle/index.md",) if w.exists(s)]
        + section("Rules of engagement",
                  [s for s in (f"lifecycle/{n}.md" for n in ROE_ORDER) if w.exists(s)])
        + section("Phases", [f"lifecycle/phases/{p['id']}.md" for p in w.phases
                             if w.exists(f"lifecycle/phases/{p['id']}.md")])
        + section("Playbooks", ordered(w, "lifecycle/playbooks", PLAYBOOK_ORDER))
        + section("ATT&CK for ICS",
                  [s for s in ["lifecycle/attack-ics/index.md"]
                   + [f"lifecycle/attack-ics/{t['slug']}.md" for t in w.tactics]
                   if w.exists(s)])
        + [s for s in ("lifecycle/crosswalk.md", "lifecycle/matrix.md") if w.exists(s)])

    tools = ["tools/index.md"]
    for f in w.folders:
        pages = [p.src for p in w.tools() if p.meta.get("folder") == f["slug"]
                 and p.src.startswith(f"tools/{f['slug']}/")]
        tools += [{w.folder_label(f["slug"]): [f"tools/{f['slug']}/index.md"] + pages}]
    tools += section("Protocols", [f"{PRIMERS_DIR}/index.md"]
                     + ordered(w, PRIMERS_DIR, [p["slug"] for p in w.protocols]))
    tools = take(tools)

    # Anything not placed yet joins the tab of its top-level directory, so a new
    # page is never silently missing from the navigation.
    tabs = {"platform": home, "lifecycle": lifecycle, "tools": tools}
    for src in sorted(w.pages, key=lambda s: w.pages[s].title.lower()):
        if src in placed or src in NOT_IN_NAV:
            continue
        tabs.get(src.split("/")[0], home).append(src)

    return [{"Home": home}, {"Lifecycle": lifecycle}, {"Tools": tools}]


# ---------------------------------------------------------------------------
# 4. Generated pages
# ---------------------------------------------------------------------------

def front(title: str, summary: str, hide: list[str] | None = None) -> str:
    meta = {"title": title, "summary": summary}
    if hide:
        meta["hide"] = hide
    return "---\n" + yaml.safe_dump(meta, sort_keys=False, allow_unicode=True) + "---\n\n"


def wire_badge(w: Wiki, wire: str, from_src: str | None = None) -> str:
    wc = w.wire.get(wire, {"name": wire, "summary": ""})
    if from_src and w.exists(WIRE_CLASSES_PAGE):
        return (f"[{wc['name']}]({rel(from_src, WIRE_CLASSES_PAGE)})"
                f'{{ .snapshot-wire .snapshot-wire--{wire} title="{html.escape(wc["summary"])}" }}')
    return (f'<span class="snapshot-wire snapshot-wire--{wire}" '
            f'title="{html.escape(wc["summary"])}">{html.escape(wc["name"])}</span>')


def tactic_badge(w: Wiki, slug: str, from_src: str, role: str | None = None) -> str:
    t = w.tactic[slug]
    classes = ".snapshot-tactic" + (f" .snapshot-tactic--{role}" if role else "")
    return f"[{t['name']}]({rel(from_src, f'lifecycle/attack-ics/{slug}.md')}){{ {classes} }}"


def phase_link(w: Wiki, phase: str, from_src: str, cls: str = "") -> str:
    name = w.phase[phase]["name"]
    target = f"lifecycle/phases/{phase}.md"
    attrs = f"{{ .{cls} }}" if cls else ""
    if w.exists(target):
        return f"[{name}]({rel(from_src, target)}){attrs}"
    return f'<span class="{cls}">{name}</span>' if cls else name


def package_names(m: dict) -> list:
    """`package` as a list: one name, or the names of a tool split over packages."""
    value = m.get("package")
    return list(value) if isinstance(value, list) else [value]


def tool_link(page: Page, from_src: str) -> str:
    return f"[{page.title}]({rel(from_src, page.src)})"


def tool_cell(page: Page, from_src: str) -> str:
    """A tool link for the generated phase and tactic tables, marked when the
    tool is not on this image or only on one architecture."""
    marks = []
    if page.meta.get("status") == "not-shipped":
        marks.append('<span class="snapshot-pill snapshot-pill--muted">Not shipped</span>')
    arch = page.meta.get("arch") or []
    if len(arch) == 1:
        marks.append(f'<span class="snapshot-pill">{html.escape(arch[0])} only</span>')
    return " ".join([tool_link(page, from_src)] + marks)


def page_link(w: Wiki, target: str, label: str, from_src: str) -> str:
    return f"[{label}]({rel(from_src, target)})" if w.exists(target) else label


def phases_of(w: Wiki, page: Page) -> list[str]:
    return [p["id"] for p in w.phases if p["id"] in page.meta.get("phases", {})]


def gen_tools_index(w: Wiki) -> str:
    src = "tools/index.md"
    out = [front("Tools", "Every tool on SnapshOT by menu folder, with how it behaves on the "
                 "wire, where it fits in the lifecycle and the ATT&CK for ICS tactics it touches.")]
    out.append("## By menu folder\n")
    rows = []
    for f in w.folders:
        count = sum(1 for p in w.tools() if p.meta.get("folder") == f["slug"])
        rows.append([f"[{w.folder_label(f['slug'])}]({rel(src, 'tools/' + f['slug'] + '/index.md')})",
                     str(count), text(f["summary"])])
    out.append(table(["Folder", "Tool pages", "What it is for"], rows))
    out.append("\n\n## Every tool\n")
    rows = []
    for p in w.tools():
        m = p.meta
        rows.append([tool_link(p, src), text(w.folder_label(m["folder"])),
                     wire_badge(w, m["wire"]),
                     ", ".join(w.phase[x]["name"] for x in phases_of(w, p)),
                     ", ".join(w.tactic[t]["name"] for t in m.get("attack_ics", []) if t in w.tactic),
                     STATUS.get(m.get("status"), "")])
    out.append(table(["Tool", "Folder", "On the wire", "PICERL phases", "ATT&CK for ICS", "Status"], rows)
               if rows else "No tool pages yet.")
    out.append("\n\nThe same data as a graph is on the [lifecycle page]"
               f"({rel(src, 'lifecycle/index.md')}); the full cross-reference is the "
               f"[matrix]({rel(src, 'lifecycle/matrix.md')}). Pages are also listed by "
               f"[tag]({rel(src, 'tags.md')}).\n" if w.exists("lifecycle/index.md") and w.exists("tags.md")
               else "\n")
    return "\n".join(out)


def gen_folder_index(w: Wiki, f: dict) -> str:
    src = f"tools/{f['slug']}/index.md"
    out = [front(w.folder_label(f["slug"]), f["summary"])]
    out.append(f"The launchers for these tools are in the applications menu under "
               f"**{f['number']} - {f['name']}**.\n")
    rows = []
    for p in w.tools():
        if p.meta.get("folder") != f["slug"]:
            continue
        m = p.meta
        rows.append([tool_link(p, src), text(m["summary"]), wire_badge(w, m["wire"]),
                     ", ".join(w.phase[x]["name"] for x in phases_of(w, p)),
                     STATUS.get(m.get("status"), "")])
    out.append(table(["Tool", "What it does", "On the wire", "PICERL phases", "Status"], rows)
               if rows else "No tool pages in this folder yet.")
    return "\n".join(out) + "\n"


def gen_protocols_index(w: Wiki) -> str:
    src = f"{PRIMERS_DIR}/index.md"
    out = [front("Protocols", "The protocols SnapshOT tools speak, where they are usually "
                 "found and which tools to use for each.")]
    families = [("ics", "Industrial protocols"), ("it", "IT protocols on OT networks"),
                ("link", "Link layer"), ("radio", "Radio"), ("hardware", "Hardware and bench")]
    users: dict[str, list[Page]] = {}
    for p in w.tools():
        for proto in p.meta.get("protocols", []):
            users.setdefault(proto, []).append(p)
    any_rows = False
    for family, label in families:
        rows = []
        for proto in w.protocols:
            if proto["family"] != family:
                continue
            primer = f"{PRIMERS_DIR}/{proto['slug']}.md"
            if proto["slug"] not in users and not w.exists(primer):
                continue
            name = page_link(w, primer, proto["name"], src)
            rows.append([name, text(proto["ports"]),
                         ", ".join(tool_link(p, src) for p in users.get(proto["slug"], []))])
        if rows:
            any_rows = True
            out.append(f"## {label}\n")
            out.append(table(["Protocol", "Usually found on", "SnapshOT tools"], rows) + "\n")
    if not any_rows:
        out.append("No tool page lists a protocol yet.\n")
    return "\n".join(out)


def gen_tactic_page(w: Wiki, t: dict) -> str:
    src = f"lifecycle/attack-ics/{t['slug']}.md"
    out = [front(t["name"], t["description"])]
    out.append(f"## What a field kit can see\n\n{' '.join(t['field_view'].split())}\n")
    out.append("## Phases where it is in play\n")
    rows = [[phase_link(w, p["id"], src), text(p["tactics"][t["slug"]])]
            for p in w.phases if t["slug"] in p.get("tactics", {})]
    out.append(table(["Phase", "Why it matters there"], rows) if rows
               else "No phase lists this tactic.")
    out.append("\n## Tools\n")
    rows = []
    for p in w.tools():
        m = p.meta
        if t["slug"] not in m.get("attack_ics", []):
            continue
        techniques = ", ".join(f"{tid} {w.technique_name(tid)}"
                               for tid in m.get("attack_techniques", []) if tid in w.techniques)
        rows.append([tool_cell(p, src), w.role[m["attack_role"]]["name"],
                     wire_badge(w, m["wire"]), text(techniques)])
    out.append(table(["Tool", "Role", "Wire", "Techniques on its page"], rows) if rows
               else "No tool page maps to this tactic yet.")
    out.append("\n\nRoles: " + "; ".join(f"**{r['name']}**: {r['summary']}"
                                         for r in w.role.values() if r["id"] != "none"))
    out.append(f"\n\n## Reference\n\n[{t['id']} {t['name']} on attack.mitre.org]"
               f"(https://attack.mitre.org/tactics/{t['id']}/). "
               f"Tactic ids, names and descriptions are from MITRE ATT&CK for ICS"
               f"{' v' + w.attack_version if w.attack_version else ''}, "
               "© The MITRE Corporation, reproduced with its permission.\n")
    return "\n".join(out)


def matrix_table(kind: str, headers: list[str], rows: list[list[str]]) -> str:
    """A matrix table in a wrapper the theme compacts (turned column headers)."""
    if not rows:
        return "No tool pages yet."
    return (f'<div class="snapshot-matrix snapshot-matrix--{kind}" markdown>\n\n'
            + table(headers, rows) + "\n\n</div>")


def gen_matrix(w: Wiki) -> str:
    src = "lifecycle/matrix.md"
    out = [front("Matrix", "Every tool against the six PICERL phases and the twelve ATT&CK "
                 "for ICS tactics, generated from the tool pages.", hide=["toc"])]
    tools = w.tools()
    out.append("## Phases and tools\n")
    out.append("A dot means the tool page describes how the tool is used in that phase.\n")
    headers = ["Tool", "Wire"] + [phase_link(w, p["id"], src) for p in w.phases]
    rows = [[tool_link(p, src), wire_badge(w, p.meta["wire"])]
            + ["●" if ph["id"] in p.meta["phases"] else "" for ph in w.phases] for p in tools]
    out.append(matrix_table("phases", headers, rows))
    out.append("\n\n## Tactics and tools\n")
    out.append("**D** detects, **I** investigates, **R** resembles (the tool's own "
               "activity looks like the tactic; tell the site before using it).\n")
    letter = {"detects": "D", "investigates": "I", "resembles": "R"}
    headers = ["Tool"] + [f"[{t['name']}]({rel(src, 'lifecycle/attack-ics/' + t['slug'] + '.md')})"
                          for t in w.tactics]
    rows = [[tool_link(p, src)] + [letter.get(p.meta["attack_role"], "")
                                   if t["slug"] in p.meta["attack_ics"] else ""
                                   for t in w.tactics] for p in tools]
    out.append(matrix_table("tactics", headers, rows))
    return "\n".join(out) + "\n"


def generate_pages(w: Wiki) -> None:
    """Fill w.generated (src -> markdown); hand-written files take precedence."""
    gen = {"tools/index.md": gen_tools_index(w),
           f"{PRIMERS_DIR}/index.md": gen_protocols_index(w),
           "lifecycle/matrix.md": gen_matrix(w)}
    for f in w.folders:
        gen[f"tools/{f['slug']}/index.md"] = gen_folder_index(w, f)
    for t in w.tactics:
        gen[f"lifecycle/attack-ics/{t['slug']}.md"] = gen_tactic_page(w, t)
    for src, content in gen.items():
        if src in w.pages:
            problem(src, "this page is generated; delete the hand-written file")
        else:
            w.generated[src] = content


# ---------------------------------------------------------------------------
# 5. Page decoration
# ---------------------------------------------------------------------------

def header(w: Wiki, src: str, meta: dict, kind: str) -> str:
    """H1, lede and badges for the top of a page."""
    title = meta.get("title") or posixpath.splitext(posixpath.basename(src))[0]
    out = [f"# {title}\n"]
    if meta.get("summary"):
        out.append(f"{' '.join(str(meta['summary']).split())}\n{{ .snapshot-lede }}\n")
    badges = []
    if kind == "tool" and meta.get("wire") in w.wire:
        badges.append(wire_badge(w, meta["wire"], src))
        if meta.get("status") == "not-shipped":
            badges.append('<span class="snapshot-pill snapshot-pill--muted">Not shipped</span>')
        arch = meta.get("arch", [])
        if len(arch) == 1:
            badges.append(f'<span class="snapshot-pill">{html.escape(arch[0])} only</span>')
    elif kind == "phase" and posixpath.splitext(posixpath.basename(src))[0] in w.phase:
        p = w.phase[posixpath.splitext(posixpath.basename(src))[0]]
        badges.append(f'<span class="snapshot-pill snapshot-pill--red">Phase {p["number"]} of {len(w.phases)}</span>')
        badges += [f'<span class="snapshot-pill">CSF {w.csf[c]["name"]}</span>' for c in p["csf"]]
    elif kind == "playbook":
        badges += [phase_link(w, ph, src, "snapshot-pill") for ph in meta.get("phases", [])
                   if ph in w.phase]
    elif kind == "generated" and src.startswith("lifecycle/attack-ics/"):
        t = w.tactic.get(posixpath.splitext(posixpath.basename(src))[0])
        if t:
            badges.append(f'<span class="snapshot-pill snapshot-pill--red">{t["id"]}</span>')
            badges.append('<span class="snapshot-pill">ATT&amp;CK for ICS tactic</span>')
    if badges:
        out.append('<div class="snapshot-badges" markdown>\n\n' + " ".join(badges) + "\n\n</div>\n")
    return "\n".join(out) + "\n"


def facts_box(w: Wiki, page_src: str, m: dict) -> str:
    rows = []
    f = m["folder"]
    rows.append(["Menu folder", f"[{w.folder_label(f)}]({rel(page_src, 'tools/' + f + '/index.md')})"])
    launchers = ", ".join(f"`{x}`" for x in m["launchers"]) or "none (run it from a terminal)"
    rows.append(["Launchers", launchers])
    kind = SHIPS_AS[m["ships_as"]]
    if m["ships_as"] == "vendor":
        where = page_link(w, VENDOR_LAYER_PAGE, kind, page_src)
        rows.append(["Ships as", f"{where}: `/opt/snapshot/{m['package']}/`"])
    else:
        names = package_names(m)
        noun = kind if len(names) == 1 else kind.replace("package", "packages", 1)
        rows.append(["Ships as", f"{noun} " + ", ".join(f"`{p}`" for p in names)])
    rows.append(["Architectures", ", ".join(m["arch"]) + (" only" if len(m["arch"]) == 1 else "")])
    if m["status"] == "not-shipped":
        rows.append(["Status", "Not shipped: defined in the vendor lock but disabled; "
                               "its launcher stays hidden"])
    version = (f"Pinned by the image; see the {page_link(w, BUILD_MANIFEST_PAGE, 'build manifest', page_src)}"
               if w.exists(BUILD_MANIFEST_PAGE) else f"Pinned by the image; see `{MANIFEST_FILE}`")
    rows.append(["Version", version])
    rows.append(["On the wire", wire_badge(w, m["wire"], page_src) + " " + text(w.wire[m["wire"]]["summary"])])
    rows.append(["PICERL phases", " ".join(phase_link(w, p, page_src, "snapshot-pill")
                                           for p in [x["id"] for x in w.phases] if p in m["phases"])])
    rows.append(["NIST CSF 2.0", ", ".join(w.csf[c]["name"] for c in m["csf"])])
    if m["attack_ics"]:
        role = m["attack_role"]
        rows.append(["ATT&CK for ICS", f"{w.role[role]['name']}: " + " ".join(
            tactic_badge(w, t, page_src, role) for t in m["attack_ics"])])
    techniques = m.get("attack_techniques", [])
    if techniques:
        rows.append(["Techniques", "; ".join(
            f"[{tid}](https://attack.mitre.org/techniques/{tid.replace('.', '/')}/) "
            f"{text(w.technique_name(tid))}" for tid in techniques)])
    protos = m.get("protocols", [])
    if protos:
        rows.append(["Protocols", ", ".join(
            page_link(w, f"{PRIMERS_DIR}/{p}.md", w.protocol[p]["name"], page_src) for p in protos)])
    if m.get("upstream"):
        label = re.sub(r"^https?://", "", m["upstream"]).rstrip("/")
        rows.append(["Upstream", f"[{label}]({m['upstream']})"])
    # Excluded from the search index: every tool page has the same labels, and
    # search results should quote the page's own prose.
    return ('<div class="snapshot-facts" markdown data-search-exclude>\n\n'
            + table(["Fact", "Value"], rows) + "\n\n</div>\n")


def phase_tactics(w: Wiki, src: str, phase: dict) -> str:
    rows = [[tactic_badge(w, slug, src), w.tactic[slug]["id"], text(note)]
            for slug, note in phase.get("tactics", {}).items() if slug in w.tactic]
    return table(["Tactic", "ID", "Why it matters in this phase"], rows) if rows else \
        "No tactics are listed for this phase."


def phase_tools(w: Wiki, src: str, phase: dict) -> str:
    rows = [[tool_cell(p, src), text(w.folder_label(p.meta["folder"])),
             wire_badge(w, p.meta["wire"]), text(p.meta["phases"][phase["id"]])]
            for p in w.tools() if phase["id"] in p.meta.get("phases", {})]
    return table(["Tool", "Folder", "On the wire", "How it is used here"], rows) if rows else \
        "No tool page lists this phase yet."


def phase_playbooks(w: Wiki, src: str, phase: dict) -> str:
    books = [p for p in w.pages.values() if p.kind == "playbook"
             and phase["id"] in (p.meta.get("phases") or [])]
    rank = {s: i for i, s in enumerate(PLAYBOOK_ORDER)}
    books.sort(key=lambda p: (rank.get(p.stem, 99), p.title.lower()))
    if not books:
        return "No playbook covers this phase yet."
    return "\n".join(f"- [{p.title}]({rel(src, p.src)}): {' '.join(str(p.meta.get('summary', '')).split())}"
                     for p in books)


def phase_crosswalk(w: Wiki, src: str, phase: dict) -> str:
    a = phase.get("anchors", {})
    sans = ", ".join(f"{n}. {w.sans[n]['name']}" for n in a.get("sans_controls", []) if n in w.sans)
    rows = [["NIST CSF 2.0", ", ".join(w.csf[c]["name"] for c in phase["csf"])],
            ["NIST SP 800-61r3", text(a.get("sp800_61r3", ""))],
            ["NIST SP 800-82r3", text(a.get("sp800_82r3", ""))],
            ["SANS Five ICS Critical Controls", text(sans)]]
    return table(["Framework", "In this phase"], rows)


def home_cards(w: Wiki, src: str) -> str:
    """Material card grid; a card links only when its page exists."""
    out = ['<div class="grid cards snapshot-cards" markdown>\n']
    for icon, title, target, blurb in HOME_CARDS:
        out.append(f"-   :{icon}:{{ .lg .middle }} **{title}**\n\n    ---\n\n    {blurb}\n")
        if w.exists(target):
            out.append(f"    [:material-arrow-right: {title}]({rel(src, target)})\n")
    out.append("</div>\n")
    return "\n".join(out)


def phases_table(w: Wiki, src: str) -> str:
    rows = [[str(p["number"]), phase_link(w, p["id"], src), text(p["summary"]),
             ", ".join(w.csf[c]["name"] for c in p["csf"])] for p in w.phases]
    return table(["", "Phase", "What it is for", "NIST CSF 2.0"], rows)


def tactics_table(w: Wiki, src: str) -> str:
    rows = []
    for t in w.tactics:
        phases = [p for p in w.phases if t["slug"] in p.get("tactics", {})]
        tools = [p for p in w.tools() if t["slug"] in p.meta.get("attack_ics", [])]
        rows.append([f"{tactic_badge(w, t['slug'], src)}<br>{t['id']}", text(t["description"]),
                     ", ".join(phase_link(w, p["id"], src) for p in phases), str(len(tools))])
    return table(["Tactic", "MITRE description", "PICERL phases", "Tool pages"], rows)


def replace_markers(w: Wiki, src: str, markdown: str, page: Page | None) -> str:
    def render(m: re.Match) -> str:
        name = m.group(1)
        if page is None:
            return m.group(0)
        if name == "facts" and page.kind == "tool":
            return facts_box(w, src, page.meta) if page.valid else \
                '!!! failure "Facts box not rendered: fix the front-matter problems the build reported."'
        if name in PAGE_MARKERS and page.kind in ("page", "primer"):
            return {"cards": home_cards, "phases": phases_table,
                    "tactics": tactics_table}[name](w, src)
        if name in PHASE_MARKERS and page.kind == "phase" and page.stem in w.phase:
            phase = w.phase[page.stem]
            fn = {"phase-tactics": phase_tactics, "phase-tools": phase_tools,
                  "phase-playbooks": phase_playbooks, "phase-crosswalk": phase_crosswalk}[name]
            return fn(w, src, phase)
        return m.group(0)  # reported by validation
    return MARKER_RE.sub(render, markdown)


def tool_tags(w: Wiki, m: dict) -> list[str]:
    tags = [f"Folder: {w.folder_label(m['folder'])}"] if m.get("folder") in w.folder else []
    if m.get("wire") in w.wire:
        tags.append(f"Wire: {w.wire[m['wire']]['name']}")
    tags += [f"Phase: {w.phase[p]['name']}" for p in m.get("phases", {}) if p in w.phase]
    tags += [f"ATT&CK: {w.tactic[t]['name']}" for t in m.get("attack_ics", []) if t in w.tactic]
    tags += [f"Protocol: {w.protocol[p]['name']}" for p in m.get("protocols", []) if p in w.protocol]
    return tags


# ---------------------------------------------------------------------------
# 6. Graphs
# ---------------------------------------------------------------------------

def color(value, where: str) -> str:
    if isinstance(value, str) and value in PALETTE:
        return PALETTE[value]
    if isinstance(value, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
        return value
    problem(where, f"colour '{value}' is neither a palette name ({', '.join(PALETTE)}) nor #RRGGBB")
    return PALETTE["muted"]


def node_url(w: Wiki, target: str, where: str) -> str | None:
    path, _, anchor = target.partition("#")
    if not w.exists(path):
        problem(where, f"node url '{target}' is not a page under docs/")
        return None
    return html_path(path) + (f"#{anchor}" if anchor else "")


def load_graph(w: Wiki, path: str, name: str) -> dict:
    """Validate docs/graphs/NAME.yaml and turn it into the JSON the mount script reads."""
    where = f"graphs/{name}.yaml"
    raw = load_yaml(path) or {}
    for key in raw:
        if key not in {"title", "layout", "direction", "groups", "nodes", "edges"}:
            problem(where, f"unknown key '{key}'")
    layout = raw.get("layout", "force")
    if layout not in ("force", "hierarchical"):
        problem(where, "layout must be force or hierarchical")
    groups = {}
    for gname, g in (raw.get("groups") or {}).items():
        groups[gname] = {"color": color(g.get("color", "muted"), where),
                         "shape": g.get("shape", "dot"), "label": g.get("label", "")}
        if groups[gname]["shape"] not in GRAPH_SHAPES:
            problem(where, f"group {gname}: unknown shape '{groups[gname]['shape']}'")
    nodes, ids = [], set()
    for n in raw.get("nodes") or []:
        if "id" not in n or "label" not in n:
            problem(where, f"node {n} needs an id and a label")
            continue
        if n["id"] in ids:
            problem(where, f"duplicate node id '{n['id']}'")
        ids.add(n["id"])
        node = {"id": str(n["id"]), "label": str(n["label"])}
        for key in n:
            if key not in {"id", "label", "group", "level", "url", "title", "shape"}:
                problem(where, f"node {n['id']}: unknown key '{key}'")
        if "group" in n:
            if n["group"] not in groups:
                problem(where, f"node {n['id']}: group '{n['group']}' is not defined under groups")
            node["group"] = n["group"]
        if "level" in n:
            node["level"] = int(n["level"])
        elif layout == "hierarchical":
            problem(where, f"node {n['id']}: a hierarchical graph needs a level on every node")
        if "title" in n:
            node["title"] = " ".join(str(n["title"]).split())
        if "shape" in n:
            node["shape"] = n["shape"]
        if "url" in n:
            url = node_url(w, n["url"], where)
            if url:
                node["url"] = url
        nodes.append(node)
    edges = []
    for e in raw.get("edges") or []:
        if e.get("from") not in ids or e.get("to") not in ids:
            problem(where, f"edge {e} refers to an unknown node")
            continue
        edge = {"from": str(e["from"]), "to": str(e["to"])}
        for key in e:
            if key not in {"from", "to", "label", "dashes", "arrows", "color", "title"}:
                problem(where, f"edge {e['from']}->{e['to']}: unknown key '{key}'")
        for key in ("label", "title"):
            if key in e:
                edge[key] = " ".join(str(e[key]).split())
        if e.get("dashes"):
            edge["dashes"] = True
        if e.get("arrows"):
            edge["arrows"] = "to" if e["arrows"] is True else str(e["arrows"])
        if "color" in e:
            edge["color"] = color(e["color"], where)
        edges.append(edge)
    return {"title": raw.get("title", name), "layout": layout,
            "direction": raw.get("direction", "UD"), "groups": groups,
            "nodes": nodes, "edges": edges}


def tool_node(w: Wiki, p: Page, group: str) -> dict:
    return {"id": f"tool:{p.src}", "label": p.title, "group": group,
            "url": html_path(p.src), "title": " ".join(str(p.meta.get("summary", "")).split())}


def graph_lifecycle(w: Wiki) -> dict:
    """Phases <-> tools, force layout, tools coloured by menu folder."""
    groups = {"phase": {"color": PALETTE["red"], "shape": "box", "label": "PICERL phase"}}
    nodes, edges = [], []
    for p in w.phases:
        node = {"id": f"phase:{p['id']}", "label": f"{p['number']}. {p['name']}",
                "group": "phase", "title": p["summary"]}
        if w.exists(f"lifecycle/phases/{p['id']}.md"):
            node["url"] = html_path(f"lifecycle/phases/{p['id']}.md")
        nodes.append(node)
    for i, p in enumerate(w.phases[:-1]):
        edges.append({"from": f"phase:{p['id']}", "to": f"phase:{w.phases[i + 1]['id']}",
                      "arrows": "to", "color": PALETTE["red"]})
    for t in w.tools():
        f = t.meta["folder"]
        groups.setdefault(f"folder:{f}", {"color": w.folder[f]["color"], "shape": "dot",
                                          "label": w.folder_label(f)})
        nodes.append(tool_node(w, t, f"folder:{f}"))
        edges += [{"from": f"tool:{t.src}", "to": f"phase:{ph}"} for ph in phases_of(w, t)]
    return {"title": "PICERL phases and the tools that serve them", "layout": "force",
            "direction": "UD", "groups": groups, "nodes": nodes, "edges": edges}


def graph_attack(w: Wiki) -> dict:
    """Tactics <-> tools, tools and edges coloured by attack_role."""
    groups = {"tactic": {"color": PALETTE["red"], "shape": "box", "label": "ATT&CK for ICS tactic"}}
    nodes = [{"id": f"tactic:{t['slug']}", "label": t["name"], "group": "tactic",
              "url": html_path(f"lifecycle/attack-ics/{t['slug']}.md"),
              "title": f"{t['id']}: {t['description']}"} for t in w.tactics]
    edges = []
    for p in w.tools():
        role = p.meta["attack_role"]
        if role == "none" or not p.meta["attack_ics"]:
            continue
        groups.setdefault(f"role:{role}", {"color": ROLE_COLORS[role], "shape": "dot",
                                           "label": f"Tool that {role} the tactic"
                                           if role != "resembles" else "Tool whose activity resembles the tactic"})
        nodes.append(tool_node(w, p, f"role:{role}"))
        edges += [{"from": f"tool:{p.src}", "to": f"tactic:{t}", "color": ROLE_COLORS[role]}
                  for t in p.meta["attack_ics"]]
    return {"title": "ATT&CK for ICS tactics and the tools that touch them", "layout": "force",
            "direction": "UD", "groups": groups, "nodes": nodes, "edges": edges}


def write_graphs(w: Wiki, site_dir: str) -> set[str]:
    graphs = {"lifecycle": graph_lifecycle(w), "attack": graph_attack(w)}
    gdir = os.path.join(w.docs_dir, "graphs")
    if os.path.isdir(gdir):
        for name in sorted(os.listdir(gdir)):
            stem, ext = os.path.splitext(name)
            if ext not in (".yaml", ".yml"):
                continue
            if stem in GENERATED_GRAPHS:
                problem(f"graphs/{name}", f"'{stem}' is generated; rename the file")
                continue
            if not re.fullmatch(r"[a-z0-9-]+", stem):
                problem(f"graphs/{name}", "graph names are lowercase letters, digits and dashes")
                continue
            graphs[stem] = load_graph(w, os.path.join(gdir, name), stem)
    out = os.path.join(site_dir, "assets", "graphs")
    os.makedirs(out, exist_ok=True)
    for name, data in sorted(graphs.items()):
        # Insertion order is deterministic (data files, menu order) and is the
        # legend order, so keys are not sorted.
        body = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
        with open(os.path.join(out, f"{name}.js"), "w", encoding="utf-8") as fh:
            fh.write("window.SNAPSHOT_GRAPHS=window.SNAPSHOT_GRAPHS||{};\n"
                     f"window.SNAPSHOT_GRAPHS[{json.dumps(name)}]={body};\n")
    return set(graphs)


def graph_scripts(page_url: str, names: list[str]) -> str:
    srcs = [VIS_PATH] + [f"assets/graphs/{n}.js" for n in names] + [GRAPHS_JS]
    return "".join(f'<script src="{get_relative_url(s, page_url)}"></script>\n' for s in srcs)


# ---------------------------------------------------------------------------
# MkDocs events
# ---------------------------------------------------------------------------

def on_config(config):
    global WIKI
    WIKI = w = Wiki(config)
    scan_docs(w)
    generate_pages(w)
    config.nav = build_nav(w)
    config.extra["snapshot_version"] = w.version
    return config


def on_files(files, config):
    w = WIKI
    assets = os.path.join(w.root, "assets")
    for dirpath, dirnames, filenames in os.walk(assets):
        dirnames.sort()
        for name in sorted(filenames):
            if name.endswith(".md") or name.startswith("."):
                continue  # ORIGIN.md documents the vendored files; it is not a page
            path = os.path.relpath(os.path.join(dirpath, name), w.root).replace(os.sep, "/")
            files.append(File(path, src_dir=w.root, dest_dir=config.site_dir,
                              use_directory_urls=config.use_directory_urls))
    for src, content in sorted(w.generated.items()):
        files.append(File.generated(config, src, content=content))
    return files


def on_page_markdown(markdown, page, config, files):
    w = WIKI
    src = page.file.src_uri
    handwritten = w.pages.get(src)
    kind = handwritten.kind if handwritten else "generated"
    if kind == "tool":
        page.meta["tags"] = tool_tags(w, page.meta)
        # Material reads a page's `status` as its own "page status" feature and
        # draws an icon in the navigation. Ours (shipped / not-shipped) is
        # rendered by the facts box; the validated copy stays in WIKI.pages.
        # MkDocs reads every page before rendering any, so this covers the
        # navigation of every page.
        page.meta.pop("status", None)
    hide = list(page.meta.get("hide") or [])
    if "tags" not in hide:
        page.meta["hide"] = hide + ["tags"]
    if page.meta.get("summary") and not page.meta.get("description"):
        page.meta["description"] = " ".join(str(page.meta["summary"]).split())
    return header(w, src, page.meta, kind) + replace_markers(w, src, markdown, handwritten)


def on_post_page(output, page, config):
    w = WIKI
    output = output.replace(SHIM_URL, get_relative_url(SHIM_PATH, page.url))
    names = sorted(set(GRAPH_REF_RE.findall(output)))
    if names:
        for name in names:
            w.graph_refs.setdefault(name, set()).add(page.file.src_uri)
        output = output.replace("</body>", graph_scripts(page.url, names) + "</body>", 1)
    return output


def on_post_template(output_content, template_name, config):
    # 404.html is rendered from the theme, not from a page; same shim rewrite.
    return output_content.replace(SHIM_URL, get_relative_url(SHIM_PATH, template_name))


def on_post_build(config):
    w = WIKI
    available = write_graphs(w, config.site_dir)
    for name, pages in sorted(w.graph_refs.items()):
        if name not in available:
            problem(", ".join(sorted(pages)), f"data-graph=\"{name}\" has no docs/graphs/{name}.yaml")
    for name in ("sitemap.xml", "sitemap.xml.gz"):
        path = os.path.join(config.site_dir, name)
        if os.path.exists(path):
            os.remove(path)
    # Material's source maps (about a quarter of the site) only serve developer
    # tools; the image does not need them.
    for dirpath, _, filenames in os.walk(config.site_dir):
        for name in filenames:
            if name.endswith(".map"):
                os.remove(os.path.join(dirpath, name))
