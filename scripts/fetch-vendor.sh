#!/usr/bin/env bash
# The ONE online step (besides the snapshot apt fetches during lb build).
# Produces a hash-pinned Python wheelhouse and downloads the pinned source/binary
# artifacts, verifying sha256. Run on a networked machine, then the tree can be
# carried to an air-gapped build host.
#
#   scripts/fetch-vendor.sh                 # normal: compile lock, download, verify
#   scripts/fetch-vendor.sh --update-hashes # fill TODO sha256 in vendor/sources.lock
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
MODE="${1:-fetch}"

# --- Python wheelhouse ---
PY=vendor/python
if command -v pip-compile >/dev/null 2>&1; then
    echo "== pip-compile (hash-pinned lock)"
    pip-compile --quiet --generate-hashes \
        --output-file "$PY/requirements.txt" "$PY/requirements.in"
else
    echo "WARN: pip-tools not installed; skipping lock regeneration. Install with: pipx install pip-tools" >&2
fi
if ! grep -q 'PLACEHOLDER-UNPINNED' "$PY/requirements.txt"; then
    echo "== downloading wheelhouse"
    rm -rf "$PY/wheelhouse"; mkdir -p "$PY/wheelhouse"
    pip download --require-hashes --no-deps \
        -r "$PY/requirements.txt" -d "$PY/wheelhouse"
    echo "wheelhouse: $(ls "$PY/wheelhouse" | wc -l | tr -d ' ') files"
else
    echo "WARN: $PY/requirements.txt still a placeholder; run with pip-tools available." >&2
fi

# --- source/binary artifacts from vendor/sources.lock ---
LOCK=vendor/sources.lock
python3 - "$LOCK" "$MODE" <<'PY'
import sys, re, hashlib, os, urllib.request, subprocess, shutil
lock, mode = sys.argv[1], sys.argv[2]
text = open(lock).read()
stanzas = [s for s in re.split(r'\n(?=name:)', text) if s.strip().startswith('name:')]
def field(s, k):
    m = re.search(rf'^{k}:\s*(.+)$', s, re.M)
    return m.group(1).strip() if m else None
for s in stanzas:
    name, url, sha, kind = (field(s,'name'), field(s,'url'), field(s,'sha256'), field(s,'kind'))
    if not name or url in (None,'TODO'):
        print(f"  skip {name}: url TODO"); continue
    dest = f"vendor/src/{name}"
    tmp = f"vendor/src/.{name}.dl"
    os.makedirs("vendor/src", exist_ok=True)
    print(f"== {name}: {url}")
    urllib.request.urlretrieve(url, tmp)
    got = hashlib.sha256(open(tmp,'rb').read()).hexdigest()
    if mode == '--update-hashes':
        text = text.replace(f"name: {name}\n", f"name: {name}\n", 1)
        # replace the sha256 line within this stanza
        new_s = re.sub(r'^sha256:.*$', f'sha256: {got}', s, flags=re.M)
        text = text.replace(s, new_s, 1)
        print(f"   sha256 -> {got}")
    else:
        if sha in (None,'TODO'):
            print(f"   WARN: no pinned sha256 for {name}; run --update-hashes"); 
        elif got != sha:
            print(f"   ERROR: sha256 mismatch for {name}: got {got} want {sha}", file=sys.stderr); sys.exit(2)
    # extract
    shutil.rmtree(dest, ignore_errors=True); os.makedirs(dest, exist_ok=True)
    if kind in ('tarball','git-archive'):
        subprocess.run(["tar","-xf",tmp,"-C",dest,"--strip-components=1"], check=False)
    elif kind == 'zip':
        subprocess.run(["bsdtar","-xf",tmp,"-C",dest] if shutil.which("bsdtar") else ["unzip","-q",tmp,"-d",dest], check=False)
    elif kind == 'deb':
        shutil.move(tmp, f"{dest}/{name}.deb"); tmp=None
    if tmp and os.path.exists(tmp): os.remove(tmp)
if mode == '--update-hashes':
    open(lock,'w').write(text); print("updated", lock)
PY
echo "fetch-vendor: done."
