#!/usr/bin/env bash
# Checks for the SnapshOT Wiki (packages/snapshot-wiki). Runs in a debian:trixie
# container so mkdocs, Material and the validators match the package build.
#
#   scripts/check-wiki.sh             # every problem is an error (use before merging)
#   scripts/check-wiki.sh --partial   # while pages are still being written
#
# Errors (exit non-zero):
#   - mkdocs build --strict fails: front-matter or template problems the hook
#     reports, broken links or anchors, a page outside the navigation;
#   - two builds differ;
#   - the site references anything remote: src="http, <link href="http,
#     url(http, @import, Material's unpkg shim, or a .mermaid element (Material
#     would load Mermaid from unpkg);
#   - search/search_index.js is missing, or a data-graph has no assets/graphs/*.js;
#   - a snapshot-*.desktop launcher in packages/snapshot-menu (other than the
#     root terminal, reference folder, build manifest and wiki entries) that no
#     tool page lists in `launchers:`, or that more than one lists;
#   - a `launchers:` id that is not a snapshot-menu launcher or a <Filename> in
#     the SnapshOT menu, or that is not in the tool's own menu folder;
#   - `status` disagreeing with vendor/sources.lock `enabled:` (vendor tools),
#     or a vendor `package` that is not a lock stanza;
#   - data/folders.yaml out of step with the snapshot-*.directory files;
#   - a phase in data/lifecycle.yaml without docs/lifecycle/phases/<id>.md;
#   - invalid policies.json, a wiki launcher that fails desktop-file-validate or
#     does not open /usr/share/snapshot/wiki/index.html;
#   - an em-dash in the wiki's text.
# With --partial, three of these become warnings: links to pages not written
# yet, launchers no tool page documents yet, and phases without a page.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${SNAPSHOT_TRIXIE_IMAGE:-debian:trixie}"
PLATFORM="${SNAPSHOT_CHECK_PLATFORM:-linux/arm64}"

PARTIAL=0
for arg in "$@"; do
    case "$arg" in
        --partial) PARTIAL=1 ;;
        -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

docker run --rm -i --platform "$PLATFORM" -e PARTIAL="$PARTIAL" \
    -v "$ROOT":/snapshot:ro "$IMAGE" bash -s <<'CONTAINER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    mkdocs-material python3-pymdownx python3-yaml desktop-file-utils >/dev/null

# Build from a copy: the bind mount is read-only and build/ may hold old output.
cp -a /snapshot/packages/snapshot-wiki /tmp/wiki
rm -rf /tmp/wiki/build
cd /tmp/wiki

build() {  # build <site dir> <log>
    if [ "$PARTIAL" = 1 ]; then
        mkdocs build --no-strict -d "$1" >"$2" 2>&1
    else
        mkdocs build --strict -d "$1" >"$2" 2>&1
    fi
}

echo "== mkdocs build ($([ "$PARTIAL" = 1 ] && echo partial || echo strict)) =="
status=0
build /tmp/site /tmp/build1.log || status=$?
grep -E 'WARNING|ERROR|Aborted' /tmp/build1.log || true
echo "== second build (reproducibility) =="
build /tmp/site2 /tmp/build2.log || true

rc=0
python3 - "$status" <<'PY' || rc=$?
import json, os, re, subprocess, sys, xml.etree.ElementTree as ET
import yaml
from mkdocs.utils.meta import get_data

PARTIAL = os.environ.get("PARTIAL") == "1"
REPO, WIKI, SITE = "/snapshot", "/tmp/wiki", "/tmp/site"
MENU = f"{REPO}/packages/snapshot-menu/rootfs"
errors, warnings = [], []

def error(msg): errors.append(msg)
def soft(msg): (warnings if PARTIAL else errors).append(msg)

# -- the build -----------------------------------------------------------------
build_status = int(sys.argv[1])
log = open("/tmp/build1.log", encoding="utf-8").read().splitlines()
missing_link = re.compile(r"contains a link .*, but the target .* is not found among documentation files")
for line in log:
    if not line.startswith(("WARNING", "ERROR")):
        continue
    text = re.sub(r"^(WARNING|ERROR)\s+-\s+", "", line)
    if PARTIAL and line.startswith("WARNING") and missing_link.search(text):
        soft("link to a page not written yet: " + text)
    else:
        error("build: " + text)
if not PARTIAL and build_status != 0:
    error("mkdocs build --strict failed (warnings above)")
if not os.path.isdir(SITE):
    print("ERROR no site was built"); sys.exit(1)

diff = subprocess.run(["diff", "-r", SITE, "/tmp/site2"], capture_output=True, text=True)
if diff.returncode != 0:
    error("two builds differ:\n" + diff.stdout[:2000])

# -- the built site --------------------------------------------------------------
remote = [
    (re.compile(r'src="https?://'), 'src="http'),
    (re.compile(r'<link[^>]*href="https?://'), '<link href="http'),
    (re.compile(r'url\(\s*["\']?https?://'), "url(http"),
    (re.compile(r"@import"), "@import"),
    (re.compile(r"unpkg\.com/iframe-worker"), "Material's unpkg shim"),
    (re.compile(r'class="[^"]*\bmermaid\b'), "a .mermaid element (loads Mermaid from unpkg)"),
]
graphs_used = {}
for dirpath, _, files in os.walk(SITE):
    for name in files:
        path = os.path.join(dirpath, name)
        rel = os.path.relpath(path, SITE)
        if not name.endswith((".html", ".css")):
            continue
        content = open(path, encoding="utf-8", errors="replace").read()
        for pattern, label in remote:
            if pattern.search(content):
                error(f"{rel}: references something remote ({label})")
        if name.endswith(".html"):
            for g in re.findall(r'data-graph="([^"]+)"', content):
                graphs_used.setdefault(g, []).append(rel)
if not os.path.isfile(f"{SITE}/search/search_index.js"):
    error("search/search_index.js is missing (offline search)")
for g, pages in sorted(graphs_used.items()):
    if not os.path.isfile(f"{SITE}/assets/graphs/{g}.js"):
        error(f'data-graph="{g}" ({", ".join(pages)}) has no assets/graphs/{g}.js')

# -- data files and the menu package -------------------------------------------------
folders = yaml.safe_load(open(f"{WIKI}/data/folders.yaml"))["folders"]
by_dir = {f["directory"]: f for f in folders}
lifecycle = yaml.safe_load(open(f"{WIKI}/data/lifecycle.yaml"))

def desktop_entry(path):
    entry, section = {}, None
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line.startswith("["):
            section = line
        elif section == "[Desktop Entry]" and "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            entry[key.strip()] = value.strip()
    return entry

dirs = {}
for name in sorted(os.listdir(f"{MENU}/usr/share/desktop-directories")):
    if name.startswith("snapshot-") and name.endswith(".directory") \
            and name != "snapshot-usual-applications.directory":
        dirs[name] = desktop_entry(f"{MENU}/usr/share/desktop-directories/{name}")
for name, entry in dirs.items():
    f = by_dir.get(name)
    if not f:
        error(f"data/folders.yaml has no folder for {name}")
    elif entry.get("Name") != f"{f['number']} - {f['name']}":
        error(f"{name}: Name={entry.get('Name')!r} but data/folders.yaml gives "
              f"{f['number'] + ' - ' + f['name']!r}")
for f in folders:
    if f["directory"] not in dirs:
        error(f"data/folders.yaml folder {f['slug']}: {f['directory']} does not exist in snapshot-menu")

# Which launcher ids each folder's <Menu> pulls in: its category plus <Filename>s.
menu_xml = ET.parse(f"{MENU}/etc/xdg/menus/applications-merged/snapshot.menu").getroot()
folder_files, folder_cats = {}, {}
for m in menu_xml.findall("Menu"):
    directory = m.findtext("Directory")
    f = by_dir.get(directory)
    if not f:
        continue
    folder_files[f["slug"]] = {e.text for e in m.iter("Filename")}
    folder_cats[f["slug"]] = {e.text for e in m.iter("Category")}
    if f["category"] not in folder_cats[f["slug"]]:
        error(f"snapshot.menu: folder {directory} does not include category {f['category']}")

launchers = {}
for name in sorted(os.listdir(f"{MENU}/usr/share/applications")):
    if name.endswith(".desktop"):
        launchers[name] = desktop_entry(f"{MENU}/usr/share/applications/{name}")
NOT_TOOLS = {"snapshot-root-terminal.desktop", "snapshot-reference-folder.desktop",
             "snapshot-build-manifest.desktop", "snapshot-wiki.desktop"}

# -- vendor/sources.lock ------------------------------------------------------------
stanzas = {}
for block in re.split(r"\n\s*\n", open(f"{REPO}/vendor/sources.lock", encoding="utf-8").read()):
    fields = {}
    for line in block.splitlines():
        if line.startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        fields[key.strip()] = value.strip()
    if "name" in fields:
        stanzas[fields["name"]] = fields

# -- tool pages --------------------------------------------------------------------
listed = {}
slugs = {f["slug"] for f in folders}
for f in folders:
    d = f"{WIKI}/docs/tools/{f['slug']}"
    if not os.path.isdir(d):
        continue
    for name in sorted(os.listdir(d)):
        if not name.endswith(".md") or name == "index.md":
            continue
        src = f"tools/{f['slug']}/{name}"
        _, meta = get_data(open(f"{d}/{name}", encoding="utf-8").read())
        meta = meta or {}
        folder = meta.get("folder")
        for lid in meta.get("launchers") or []:
            listed.setdefault(lid, []).append(src)
            if lid.startswith("snapshot-"):
                if lid not in launchers:
                    error(f"{src}: launcher {lid} does not exist in packages/snapshot-menu")
                elif folder in slugs:
                    cats = set(filter(None, launchers[lid].get("Categories", "").split(";")))
                    if not cats & folder_cats.get(folder, set()):
                        error(f"{src}: launcher {lid} is not in the {folder} folder "
                              f"(Categories={launchers[lid].get('Categories')})")
            else:
                if not any(lid in files for files in folder_files.values()):
                    error(f"{src}: launcher {lid} is neither a snapshot-menu launcher nor a "
                          f"<Filename> in snapshot.menu")
                elif folder in slugs and lid not in folder_files.get(folder, set()):
                    error(f"{src}: launcher {lid} is pulled into another folder, not {folder}")
        if meta.get("ships_as") == "vendor":
            stanza = stanzas.get(meta.get("package"))
            if not stanza:
                error(f"{src}: package {meta.get('package')!r} is not a vendor/sources.lock stanza")
            else:
                enabled = stanza.get("enabled", "true") != "false"
                if enabled != (meta.get("status") == "shipped"):
                    error(f"{src}: status {meta.get('status')} but vendor/sources.lock "
                          f"{meta.get('package')} has enabled: {stanza.get('enabled', 'true')}")
        elif meta.get("status") == "not-shipped":
            error(f"{src}: only vendor tools can be not-shipped")

for lid in sorted(launchers):
    if not lid.startswith("snapshot-") or lid in NOT_TOOLS:
        continue
    pages = listed.get(lid, [])
    if not pages:
        soft(f"launcher {lid} is not listed by any tool page")
    elif len(pages) > 1:
        error(f"launcher {lid} is listed by more than one tool page: {', '.join(pages)}")

# -- phases -------------------------------------------------------------------------
phase_ids = [p["id"] for p in lifecycle["phases"]]
pdir = f"{WIKI}/docs/lifecycle/phases"
for pid in phase_ids:
    if not os.path.isfile(f"{pdir}/{pid}.md"):
        soft(f"phase {pid} has no page docs/lifecycle/phases/{pid}.md")
if os.path.isdir(pdir):
    for name in sorted(os.listdir(pdir)):
        if name.endswith(".md") and name[:-3] not in phase_ids:
            error(f"docs/lifecycle/phases/{name} is not a phase in data/lifecycle.yaml")

# -- Firefox policy and the launcher ---------------------------------------------------
policy = f"{WIKI}/rootfs/etc/firefox/policies/policies.json"
try:
    data = json.load(open(policy, encoding="utf-8"))
    home = data["policies"]["Homepage"]["URL"]
    if home != "file:///usr/share/snapshot/wiki/index.html":
        error(f"policies.json Homepage is {home}, not the wiki")
except Exception as exc:
    error(f"policies.json is not valid: {exc}")
wiki_launcher = f"{MENU}/usr/share/applications/snapshot-wiki.desktop"
if not os.path.isfile(wiki_launcher):
    error("packages/snapshot-menu has no snapshot-wiki.desktop")
else:
    out = subprocess.run(["desktop-file-validate", wiki_launcher], capture_output=True, text=True)
    bad = [l for l in (out.stdout + out.stderr).splitlines()
           if l.strip() and not re.search(r"warning|hint", l, re.I)]
    if bad:
        error("snapshot-wiki.desktop: " + "; ".join(bad))
    if "file:///usr/share/snapshot/wiki/index.html" not in launchers.get("snapshot-wiki.desktop", {}).get("Exec", ""):
        error("snapshot-wiki.desktop does not open file:///usr/share/snapshot/wiki/index.html")
if not os.path.isfile(f"{SITE}/index.html"):
    error("the site has no index.html")

# -- house style -------------------------------------------------------------------
for top in ("docs", "data", "templates"):
    for dirpath, _, files in os.walk(f"{WIKI}/{top}"):
        for name in files:
            path = os.path.join(dirpath, name)
            for n, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
                if "—" in line:
                    error(f"{os.path.relpath(path, WIKI)}:{n}: em-dash; use a colon, comma or brackets")

# -- report --------------------------------------------------------------------------
for w in warnings:
    print("WARN  " + w)
for e in errors:
    print("ERROR " + e)
print(f"site: {sum(len(f) for _, _, f in os.walk(SITE))} files; graphs: "
      f"{', '.join(sorted(graphs_used)) or 'none'}; {len(warnings)} warnings, {len(errors)} errors")
sys.exit(1 if errors else 0)
PY
if [ "$rc" -ne 0 ]; then echo "== check-wiki: FAIL =="; exit 1; fi
echo "== check-wiki: OK$([ "$PARTIAL" = 1 ] && echo ' (partial)') =="
CONTAINER
