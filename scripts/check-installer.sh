#!/usr/bin/env bash
# Static checks for the SnapshOT installer: calamares-settings-snapshot, the
# package changelogs and the sudo hook. Runs in a debian:trixie container so
# the validators, dpkg and sudo match the target.
#
#   scripts/check-installer.sh
#
# Needs Docker and network access (snapshot.debian.org and the Calamares
# sources on GitHub). It exits non-zero on any error:
#   1. Downloads calamares from the snapshot pin in config/snapshot.env (the
#      version the image installs) and reads its version.
#   2. Validates every rootfs/etc/calamares/modules/*.conf against the
#      module's schema. Python modules ship theirs in the .deb; C++ modules
#      (users, welcome, partition, finished, machineid, ...) have theirs in
#      the Calamares source at the matching tag. A module with no schema in
#      either place is an error.
#   3. dpkg-parsechangelog on every packages/*/debian/changelog.
#   4. desktop-file-validate on the package's .desktop files, and checks that
#      the install-icon script is executable and parses as sh.
#   5. Runs config/hooks/normal/0500-snapshot-sudo.hook.chroot, which writes
#      the sudoers drop-in and checks it with visudo -cf.
#   6. Parses settings.conf and asserts that the exec sequence runs packages
#      before initramfscfg, so the installed initramfs has no live-boot hooks.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${SNAPSHOT_TRIXIE_IMAGE:-debian:trixie}"

docker run --rm -i -v "$ROOT":/snapshot:ro "$IMAGE" bash -s <<'CONTAINER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    ca-certificates curl dpkg-dev desktop-file-utils sudo \
    python3-jsonschema python3-yaml >/dev/null

PKG=/snapshot/packages/calamares-settings-snapshot/rootfs
fail=0

echo "== calamares from the snapshot pin =="
. /snapshot/config/snapshot.env
pin=/tmp/pin
mkdir -p "$pin/lists/partial" "$pin/parts" /tmp/deb
chown _apt /tmp/deb   # apt-get download drops privileges to _apt
cat > "$pin/sources.list" <<SRC
deb ${SNAPSHOT_MIRROR_DEBIAN} ${SNAPSHOT_DIST} main
deb ${SNAPSHOT_MIRROR_DEBIAN} ${SNAPSHOT_DIST}-updates main
deb ${SNAPSHOT_MIRROR_SECURITY} ${SNAPSHOT_DIST}-security main
SRC
# Separate apt state, so only the download resolves against the pin; the
# tools above come from the container's own (newer) trixie.
APT_PIN=(-o Dir::Etc::SourceList="$pin/sources.list" -o Dir::Etc::SourceParts="$pin/parts"
         -o Dir::State::Lists="$pin/lists" -o Acquire::Check-Valid-Until=false
         -o Acquire::Retries=5)
apt-get "${APT_PIN[@]}" update -qq
( cd /tmp/deb && apt-get "${APT_PIN[@]}" download calamares >/dev/null )
deb="$(ls /tmp/deb/calamares_*.deb)"
version="$(dpkg-deb -f "$deb" Version)"
upstream="${version#*:}"; upstream="${upstream%-*}"
echo "calamares $version ($(basename "$deb")), C++ schemas from tag v$upstream"
dpkg-deb -x "$deb" /tmp/calamares

echo "== module configs against their schemas =="
CALAMARES_TAG="v$upstream" PKG="$PKG" python3 - <<'PY' || fail=1
import glob, os, sys, time, urllib.error, urllib.request
import jsonschema, yaml

tag = os.environ["CALAMARES_TAG"]
confs = sorted(glob.glob(os.environ["PKG"] + "/etc/calamares/modules/*.conf"))
if not confs:
    print("FAIL no module configs found"); sys.exit(1)

def upstream_schema(module):
    url = ("https://raw.githubusercontent.com/calamares/calamares/"
           f"{tag}/src/modules/{module}/{module}.schema.yaml")
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return r.read().decode(), url
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None, url
            err = e
        except OSError as e:
            err = e
        time.sleep(2 * (attempt + 1))
    raise SystemExit(f"FAIL cannot fetch {url}: {err}")

rc = 0
for conf in confs:
    module = os.path.basename(conf)[:-len(".conf")]
    found = glob.glob(f"/tmp/calamares/usr/lib/*/calamares/modules/{module}/{module}.schema.yaml")
    if found:
        schema_text, where = open(found[0]).read(), "deb"
    else:
        schema_text, where = upstream_schema(module)
        if schema_text is None:
            print(f"FAIL {module}: no schema in the calamares .deb or at {where}")
            rc = 1
            continue
        where = tag
    try:
        docs = [d for d in yaml.safe_load_all(open(conf)) if d is not None]
    except yaml.YAMLError as e:
        print(f"FAIL {module}: YAML: {e}"); rc = 1; continue
    if len(docs) != 1 or not isinstance(docs[0], dict):
        print(f"FAIL {module}: expected one YAML mapping, found {len(docs)} document(s)")
        rc = 1
        continue
    validator = jsonschema.Draft7Validator(yaml.safe_load(schema_text))
    errors = sorted(validator.iter_errors(docs[0]), key=lambda e: list(e.path))
    if errors:
        print(f"FAIL {module} (schema: {where})")
        for e in errors:
            print("     ", "/".join(map(str, e.path)) or "<root>", "-", e.message)
        rc = 1
    else:
        print(f"ok   {module} (schema: {where})")
sys.exit(rc)
PY

echo "== changelogs =="
for cl in /snapshot/packages/*/debian/changelog; do
    pkg="${cl#/snapshot/packages/}"; pkg="${pkg%%/*}"
    if dpkg-parsechangelog -l "$cl" --all >/dev/null 2>/tmp/clerr && [ ! -s /tmp/clerr ]; then
        echo "ok   $pkg $(dpkg-parsechangelog -l "$cl" -S Version)"
    else
        echo "FAIL $pkg:"; cat /tmp/clerr; fail=1
    fi
done

echo "== desktop files and the install-icon script =="
while IFS= read -r f; do
    out="$(desktop-file-validate "$f" 2>&1 || true)"
    err="$(printf '%s\n' "$out" | grep -viE 'warning|hint' | grep -v '^$' || true)"
    if [ -n "$err" ]; then echo "FAIL ${f#/snapshot/}:"; printf '%s\n' "$err"; fail=1
    else echo "ok   ${f#/snapshot/}"; fi
done < <(find "$PKG" -name '*.desktop' | sort)
icon="$PKG/usr/bin/snapshot-install-icon"
# Compare the mode rather than test -x: root passes -x on Docker Desktop bind
# mounts. debian/rules copies rootfs/ with cp -a, so the committed mode ships.
if [ "$(stat -c %a "$icon" 2>/dev/null)" = 755 ] && sh -n "$icon"; then
    echo "ok   ${icon#/snapshot/} (mode 755, sh syntax)"
else echo "FAIL ${icon#/snapshot/}: missing, not mode 755 or not valid sh"; fail=1; fi

echo "== sudo hook =="
hook=/snapshot/config/hooks/normal/0500-snapshot-sudo.hook.chroot
if sh "$hook"; then
    mode="$(stat -c '%a %U:%G' /etc/sudoers.d/snapshot-operator)"
    if [ "$mode" = "440 root:root" ] && visudo -cq; then echo "ok   sudoers drop-in ($mode)"
    else echo "FAIL sudoers drop-in: mode $mode or visudo -c failed"; fail=1; fi
else
    echo "FAIL $hook"; fail=1
fi

echo "== settings.conf sequence =="
python3 - "$PKG/etc/calamares/settings.conf" <<'PY' || fail=1
import os, sys, yaml
path = sys.argv[1]
settings = yaml.safe_load(open(path))
execs = [m for step in settings["sequence"] for kind, mods in step.items() if kind == "exec" for m in mods]
print("exec:", " ".join(execs))
if "packages" not in execs or "initramfscfg" not in execs:
    print("FAIL exec sequence must contain packages and initramfscfg"); sys.exit(1)
if execs.index("packages") > execs.index("initramfscfg"):
    print("FAIL packages must run before initramfscfg"); sys.exit(1)
confdir = os.path.join(os.path.dirname(path), "modules")
shown = {m for step in settings["sequence"] for mods in step.values() for m in mods}
defaults = sorted(m for m in shown if not os.path.exists(os.path.join(confdir, m + ".conf")))
print("ok   packages runs before initramfscfg")
print("info modules on upstream defaults (no .conf):", " ".join(defaults))
PY

if [ "$fail" -ne 0 ]; then echo "== check-installer: FAIL =="; exit 1; fi
echo "== check-installer: OK =="
CONTAINER
