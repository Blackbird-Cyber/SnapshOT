#!/usr/bin/env python3
"""SnapshOT vendor tool — fetch and stage the per-tool runtimes/tools layer.

Every non-apt tool ships under /opt/snapshot/<tool>/ with its own pinned runtime
(see docs/vendoring.md). This script reads vendor/sources.lock (schema v2) and,
on a networked Mac/Linux host with Docker, downloads the pinned archives, builds
per-arch hash-pinned Python wheelhouses inside the target interpreter, verifies
everything, and stages a tree the chroot hooks install offline.

Pure stdlib + the Docker CLI. Subcommands:

  status                         show the lock and what is fetched
  update-hashes [--only NAME]    fill TODO sha256 in the lock (downloads once)
  fetch [--arch all|amd64|arm64] [--only NAME]
                                 download archives + build wheelhouses, verify
  wheels [--arch ...] [--only NAME]
                                 (re)build Python wheelhouses only
  verify                         recompute sha256 of everything under vendor/src
  stage --arch ARCH --dest DIR   copy the arch's layer for build.sh / the hooks

Exit non-zero on any mismatch, missing wheel, or TODO hash during fetch.
"""
import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCK = os.path.join(ROOT, "vendor", "sources.lock")
SRC = os.path.join(ROOT, "vendor", "src")
PYDIR = os.path.join(ROOT, "vendor", "python")
ARCHES = ("amd64", "arm64")
TRIXIE = os.environ.get("SNAPSHOT_TRIXIE_IMAGE", "debian:trixie")


# ---------------------------------------------------------------- lock parsing
class Stanza:
    __slots__ = ("raw", "fields")

    def __init__(self, raw):
        self.raw = raw
        self.fields = {}
        for line in raw.splitlines():
            if line.lstrip().startswith("#"):
                continue
            m = re.match(r"([A-Za-z0-9_.\-]+):\s*(.*)$", line)
            if m and m.group(1) not in self.fields:
                self.fields[m.group(1)] = m.group(2).strip()

    def get(self, key, default=None):
        return self.fields.get(key, default)

    @property
    def name(self):
        return self.fields.get("name")

    @property
    def type(self):
        return self.fields.get("type")

    @property
    def enabled(self):
        return self.fields.get("enabled", "true").lower() != "false"

    def arches(self):
        """Architectures this stanza targets."""
        if "arch" in self.fields:
            return [a.strip() for a in self.fields["arch"].split(",") if a.strip()]
        per = [k.split(".", 1)[1] for k in self.fields if k.startswith("url.")]
        return per or ["noarch"]

    def covers(self, arch):
        a = self.arches()
        return arch in a or "noarch" in a

    def artifacts(self):
        """List of (store_arch, url, sha_key, sha_val, basename) for this stanza.

        store_arch is the directory under vendor/src the download lands in:
        a concrete arch for per-arch urls, else 'noarch' (or the single arch)."""
        out = []
        per = {k.split(".", 1)[1]: v for k, v in self.fields.items()
               if k.startswith("url.")}
        if per:
            for a, url in sorted(per.items()):
                out.append((a, url, "sha256.%s" % a, self.fields.get("sha256.%s" % a),
                            os.path.basename(url)))
        elif self.fields.get("url"):
            url = self.fields["url"]
            a = self.arches()
            store = "noarch" if "noarch" in a else a[0]
            out.append((store, url, "sha256", self.fields.get("sha256"),
                        os.path.basename(url)))
        return out


def load_lock():
    text = open(LOCK).read()
    parts = re.split(r"(?m)^(?=name:)", text)
    header = parts[0]
    stanzas = [Stanza(p) for p in parts[1:]]
    return text, header, stanzas


def by_name(stanzas):
    return {s.name: s for s in stanzas}


# ---------------------------------------------------------------- helpers
def die(msg, code=1):
    print("vendor: %s" % msg, file=sys.stderr)
    sys.exit(code)


def run(cmd, **kw):
    kw.setdefault("check", True)
    return subprocess.run(cmd, **kw)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    tmp = dest + ".part"
    req = urllib.request.Request(url, headers={"User-Agent": "snapshot-vendor/2"})
    with urllib.request.urlopen(req) as r, open(tmp, "wb") as out:
        shutil.copyfileobj(r, out, length=1 << 20)
    os.replace(tmp, dest)
    return os.path.getsize(dest)


def human(n):
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return "%.1f %s" % (n, unit)
        n /= 1024.0


def arch_set(arg):
    if arg in (None, "all"):
        return list(ARCHES)
    if arg not in ARCHES:
        die("unknown --arch %r (use all|amd64|arm64)" % arg)
    return [arg]


def enabled_tools(stanzas):
    return [s for s in stanzas
            if s.enabled and s.type in ("python", "java", "data")]


def needed_runtimes(stanzas, build_arch, only=None):
    """Runtime names referenced by enabled tools that cover build_arch."""
    names = set()
    for s in enabled_tools(stanzas):
        if only and s.name != only:
            continue
        if not s.covers(build_arch):
            continue
        rt = s.get("runtime")
        if rt:
            names.add(rt)
    return names


def archive_path(store_arch, name, basename):
    return os.path.join(SRC, store_arch, name, basename)


# ---------------------------------------------------------------- fetch core
def verify_size(stanza, path):
    want = stanza.get("size")
    if want:
        got = os.path.getsize(path)
        if int(want) != got:
            die("%s: size mismatch (got %d, want %s)" % (stanza.name, got, want))


def fetch_artifact(stanza, store_arch, url, sha_key, sha_val, basename,
                   update_hashes=False, new_hashes=None):
    dest = archive_path(store_arch, stanza.name, basename)
    label = "%s[%s]" % (stanza.name, store_arch)
    if os.path.exists(dest):
        got = sha256_file(dest)
    else:
        print("  fetch %s: %s" % (label, url))
        download(url, dest)
        got = sha256_file(dest)
    verify_size(stanza, dest)
    if update_hashes:
        if sha_val in (None, "TODO"):
            new_hashes.append((stanza.name, sha_key, got))
            print("    sha256 %s -> %s" % (sha_key, got))
        elif got != sha_val:
            die("%s: sha256 mismatch on re-fetch (got %s want %s)"
                % (label, got, sha_val))
    else:
        if sha_val in (None, "TODO"):
            die("%s: sha256 is TODO; run `vendor.py update-hashes`" % label)
        if got != sha_val:
            die("%s: sha256 mismatch (got %s want %s)" % (label, got, sha_val))
    return dest, os.path.getsize(dest)


def write_hashes(text, new_hashes):
    """Rewrite TODO sha lines in the lock, stanza-scoped so duplicates are safe."""
    parts = re.split(r"(?m)^(?=name:)", text)
    for i in range(1, len(parts)):
        block = parts[i]
        m = re.search(r"(?m)^name:\s*(.+)$", block)
        if not m:
            continue
        nm = m.group(1).strip()
        for (sname, skey, sval) in new_hashes:
            if sname == nm:
                block = re.sub(r"(?m)^(%s:)\s*TODO\s*$" % re.escape(skey),
                               r"\1 %s" % sval, block)
        parts[i] = block
    return "".join(parts)


def cmd_update_hashes(args):
    text, _, stanzas = load_lock()
    new_hashes = []
    for s in stanzas:
        if args.only and s.name != args.only:
            continue
        for (store_arch, url, sha_key, sha_val, basename) in s.artifacts():
            if url in (None, "TODO"):
                continue
            if sha_val not in (None, "TODO"):
                continue
            fetch_artifact(s, store_arch, url, sha_key, sha_val, basename,
                           update_hashes=True, new_hashes=new_hashes)
    if not new_hashes:
        print("no TODO hashes to fill.")
        return
    text = write_hashes(text, new_hashes)
    open(LOCK, "w").write(text)
    print("updated %s (%d hashes)" % (LOCK, len(new_hashes)))


def cmd_fetch(args):
    build_arches = arch_set(args.arch)
    _, _, stanzas = load_lock()
    bn = by_name(stanzas)
    totals = {a: 0 for a in build_arches}

    # 1. runtimes referenced by enabled, covered tools
    for a in build_arches:
        for rt in sorted(needed_runtimes(stanzas, a, args.only)):
            rs = bn.get(rt)
            if not rs:
                die("runtime %r referenced but not defined" % rt)
            for (store, url, sk, sv, base) in rs.artifacts():
                if store != a:
                    continue
                _, size = fetch_artifact(rs, store, url, sk, sv, base)
                totals[a] += size

    # 2. tool archives
    for s in enabled_tools(stanzas):
        if args.only and s.name != args.only:
            continue
        for (store, url, sk, sv, base) in s.artifacts():
            if store == "noarch" or store in build_arches:
                _, size = fetch_artifact(s, store, url, sk, sv, base)
                for a in build_arches:
                    if store in ("noarch", a):
                        totals[a] += size

    # 3. wheels for python tools with a requirements.in
    cmd_wheels(args, loaded=(stanzas, bn))

    print("\n== fetch sizes ==")
    for a in build_arches:
        print("  %-6s archives: %s" % (a, human(totals[a])))
    print("fetch: OK")


# ---------------------------------------------------------------- wheels
WHEEL_SCRIPT = r"""
set -euo pipefail
RT=/tmp/py
rm -rf "$RT"; mkdir -p "$RT"
tar -xf "/work/{rt_archive}" -C "$RT" --strip-components={strip}
PY="$RT/bin/python3"
"$PY" -m ensurepip -q >/dev/null 2>&1 || true
"$PY" -m pip install -q --upgrade pip pip-tools >/dev/null
cd "/work/vendor/python/{tool}"
"$RT/bin/pip-compile" -q --generate-hashes --allow-unsafe \
    -o "requirements.{arch}.txt" requirements.in
rm -rf "wheelhouse/{arch}"; mkdir -p "wheelhouse/{arch}"
"$PY" -m pip download --require-hashes --no-deps --only-binary=:all: \
    -r "requirements.{arch}.txt" -d "wheelhouse/{arch}"
echo "wheels: {tool}[{arch}] -> $(ls wheelhouse/{arch} | wc -l | tr -d ' ') files"
"""


def cmd_wheels(args, loaded=None):
    build_arches = arch_set(args.arch)
    if loaded:
        stanzas, bn = loaded
    else:
        _, _, stanzas = load_lock()
        bn = by_name(stanzas)
    for s in enabled_tools(stanzas):
        if args.only and s.name != args.only:
            continue
        if s.type != "python" or not s.get("requirements"):
            continue
        rt = bn.get(s.get("runtime"))
        if not rt:
            die("%s: runtime %r not defined" % (s.name, s.get("runtime")))
        for a in build_arches:
            if not s.covers(a):
                continue
            rt_arts = [art for art in rt.artifacts() if art[0] == a]
            if not rt_arts:
                die("%s: runtime %s has no artifact for %s" % (s.name, rt.name, a))
            _, url, sk, sv, base = rt_arts[0]
            rt_path = archive_path(a, rt.name, base)
            if not os.path.exists(rt_path):
                # make sure the interpreter is present before building wheels
                fetch_artifact(rt, a, url, sk, sv, base)
            rel = os.path.relpath(rt_path, ROOT)
            script = WHEEL_SCRIPT.format(
                rt_archive=rel, strip=int(rt.get("strip", "0") or 0),
                tool=s.name, arch=a)
            print("== wheels %s[%s] (platform linux/%s)" % (s.name, a, a))
            run(["docker", "run", "--rm", "--platform", "linux/%s" % a,
                 "-v", "%s:/work" % ROOT, "-w", "/work",
                 TRIXIE, "bash", "-c", script])


# ---------------------------------------------------------------- verify
def cmd_verify(args):
    _, _, stanzas = load_lock()
    checked = 0
    for s in stanzas:
        for (store, url, sk, sv, base) in s.artifacts():
            path = archive_path(store, s.name, base)
            if not os.path.exists(path):
                continue
            got = sha256_file(path)
            if sv in (None, "TODO"):
                print("  %s[%s]: present, lock sha is TODO" % (s.name, store))
                continue
            if got != sv:
                die("%s[%s]: sha256 mismatch (got %s want %s)"
                    % (s.name, store, got, sv))
            checked += 1
    print("verify: OK (%d archives match the lock)" % checked)


# ---------------------------------------------------------------- status
def cmd_status(args):
    _, _, stanzas = load_lock()
    print("%-22s %-8s %-7s %-14s %-18s %s" %
          ("name", "type", "enabled", "arch", "runtime", "fetched"))
    for s in stanzas:
        fetched = []
        for a in ARCHES:
            arts = [art for art in s.artifacts() if art[0] in (a, "noarch")]
            wh = os.path.join(PYDIR, s.name or "", "wheelhouse", a)
            have_arch = any(os.path.exists(archive_path(art[0], s.name, art[4]))
                            for art in arts)
            have_wh = os.path.isdir(wh) and bool(os.listdir(wh))
            if have_arch or have_wh:
                fetched.append(a)
        print("%-22s %-8s %-7s %-14s %-18s %s" %
              (s.name, s.type or "-", "yes" if s.enabled else "no",
               ",".join(s.arches()), s.get("runtime", "-"),
               ",".join(fetched) or "-"))


# ---------------------------------------------------------------- stage
def tool_available(s, bn, arch):
    """Is everything this enabled, covered tool needs fetched for `arch`?"""
    rt = bn.get(s.get("runtime")) if s.get("runtime") else None
    if rt is not None:
        rt_arts = [art for art in rt.artifacts() if art[0] == arch]
        if not rt_arts or not os.path.exists(
                archive_path(arch, rt.name, rt_arts[0][4])):
            return False
    for (store, url, sk, sv, base) in s.artifacts():
        if store in ("noarch", arch) and not os.path.exists(
                archive_path(store, s.name, base)):
            return False
    if s.type == "python" and s.get("requirements"):
        wh = os.path.join(PYDIR, s.name, "wheelhouse", arch)
        req = os.path.join(PYDIR, s.name, "requirements.%s.txt" % arch)
        if not (os.path.isdir(wh) and os.listdir(wh) and os.path.exists(req)):
            return False
    return True


def cmd_stage(args):
    arch = args.arch
    if arch not in ARCHES:
        die("stage needs --arch amd64|arm64 (got %r)" % arch)
    dest = os.path.abspath(args.dest)
    _, _, stanzas = load_lock()
    bn = by_name(stanzas)
    required = os.environ.get("SNAPSHOT_VENDOR_REQUIRED") == "1"

    tools = [s for s in enabled_tools(stanzas) if s.covers(arch)]
    staged, missing = [], []
    for s in tools:
        (staged if tool_available(s, bn, arch) else missing).append(s)

    for s in missing:
        print("WARN: %s enabled for %s but not fetched; skipping" % (s.name, arch))

    if not staged:
        shutil.rmtree(dest, ignore_errors=True)
        print("WARN: no vendor artifacts fetched for %s; staging nothing "
              "(run scripts/vendor.py fetch)" % arch)
        if required and missing:
            die("SNAPSHOT_VENDOR_REQUIRED=1 and vendor layer is incomplete")
        return

    shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(dest, exist_ok=True)
    shutil.copy2(LOCK, os.path.join(dest, "sources.lock"))
    shutil.copy2(os.path.join(ROOT, "scripts", "vendor-install.py"),
                 os.path.join(dest, "vendor-install.py"))

    def copy_archive(store, name, base):
        srcp = archive_path(store, name, base)
        dstp = os.path.join(dest, "src", store, name, base)
        os.makedirs(os.path.dirname(dstp), exist_ok=True)
        shutil.copy2(srcp, dstp)

    runtimes = set()
    for s in staged:
        if s.get("runtime"):
            runtimes.add(s.get("runtime"))
        for (store, url, sk, sv, base) in s.artifacts():
            if store in ("noarch", arch):
                copy_archive(store, s.name, base)
        if s.type == "python" and s.get("requirements"):
            td = os.path.join(dest, "python", s.name)
            os.makedirs(os.path.join(td, "wheelhouse"), exist_ok=True)
            shutil.copy2(os.path.join(PYDIR, s.name, "requirements.%s.txt" % arch),
                         os.path.join(td, "requirements.%s.txt" % arch))
            shutil.copytree(os.path.join(PYDIR, s.name, "wheelhouse", arch),
                            os.path.join(td, "wheelhouse", arch))
            noarch_wh = os.path.join(PYDIR, s.name, "wheelhouse", "noarch")
            if os.path.isdir(noarch_wh):
                shutil.copytree(noarch_wh,
                                os.path.join(td, "wheelhouse", "noarch"))

    for rt in sorted(runtimes):
        rs = bn[rt]
        for (store, url, sk, sv, base) in rs.artifacts():
            if store == arch:
                copy_archive(store, rt, base)

    print("staged %d tool(s) + %d runtime(s) for %s into %s"
          % (len(staged), len(runtimes), arch, dest))
    if required and missing:
        die("SNAPSHOT_VENDOR_REQUIRED=1 and vendor layer is incomplete")


# ---------------------------------------------------------------- cli
def main(argv=None):
    p = argparse.ArgumentParser(prog="vendor.py", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("status").set_defaults(func=cmd_status)

    uh = sub.add_parser("update-hashes")
    uh.add_argument("--only")
    uh.set_defaults(func=cmd_update_hashes)

    f = sub.add_parser("fetch")
    f.add_argument("--arch", default="all")
    f.add_argument("--only")
    f.set_defaults(func=cmd_fetch)

    w = sub.add_parser("wheels")
    w.add_argument("--arch", default="all")
    w.add_argument("--only")
    w.set_defaults(func=lambda a: cmd_wheels(a))

    sub.add_parser("verify").set_defaults(func=cmd_verify)

    s = sub.add_parser("stage")
    s.add_argument("--arch", required=True)
    s.add_argument("--dest", required=True)
    s.set_defaults(func=cmd_stage)

    args = p.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
