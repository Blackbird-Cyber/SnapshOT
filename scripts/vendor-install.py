#!/usr/bin/env python3
"""SnapshOT in-chroot vendor installer. Run by the live-build hooks with the
image's own python3 (stdlib only, no network).

It reads the staged sources.lock and wheelhouses from this script's directory
(/usr/local/share/snapshot/vendor) and installs the vendor layer under
/opt/snapshot per docs/vendoring.md. Phases, given as argv:

  runtimes   extract each referenced runtime into /opt/snapshot/runtimes/<name>/
  tools      install each enabled tool into /opt/snapshot/<tool>/ with wrappers
  finish     clamp mtimes to SOURCE_DATE_EPOCH and remove the staging dir

Only enabled tools whose arch covers this image and whose files are staged are
installed; a partial vendor set still builds. A tool with `setup:` runs its
vendor/setup/<tool>.py after extraction, with the verified output of the source
builds it `uses:`. Nothing is modified after its mtime clamp, and no vendored
python/java/pip is reachable by its bare name.
"""
import datetime
import glob
import hashlib
import os
import re
import shutil
import stat
import subprocess
import sys

VENDOR = os.path.dirname(os.path.abspath(__file__))
OPT = "/opt/snapshot"
RUNTIMES = os.path.join(OPT, "runtimes")
BIN = os.path.join(OPT, "bin")
NMAP_SCRIPTS = "/usr/share/nmap/scripts"
MANIFEST_INDEX = "/usr/share/snapshot/vendor"


# ---------------------------------------------------------------- lock parsing
class Stanza:
    def __init__(self, raw):
        self.fields = {}
        for line in raw.splitlines():
            if line.lstrip().startswith("#"):
                continue
            m = re.match(r"([A-Za-z0-9_.\-]+):\s*(.*)$", line)
            if m and m.group(1) not in self.fields:
                self.fields[m.group(1)] = m.group(2).strip()

    def get(self, k, d=None):
        return self.fields.get(k, d)

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
        if "arch" in self.fields:
            return [a.strip() for a in self.fields["arch"].split(",") if a.strip()]
        per = [k.split(".", 1)[1] for k in self.fields if k.startswith("url.")]
        return per or ["noarch"]

    def covers(self, arch):
        a = self.arches()
        return arch in a or "noarch" in a

    def uses(self):
        return [u.strip() for u in self.fields.get("uses", "").split(",")
                if u.strip()]

    def artifact(self, arch):
        """(store_arch, basename, sha256) for this image arch, or None."""
        per = {k.split(".", 1)[1]: v for k, v in self.fields.items()
               if k.startswith("url.")}
        if per:
            if arch in per:
                return (arch, os.path.basename(per[arch]),
                        self.fields.get("sha256.%s" % arch))
            return None
        if self.fields.get("url"):
            a = self.arches()
            store = "noarch" if "noarch" in a else a[0]
            if store in ("noarch", arch):
                return (store, os.path.basename(self.fields["url"]),
                        self.fields.get("sha256"))
        return None


def load_lock():
    text = open(os.path.join(VENDOR, "sources.lock")).read()
    parts = re.split(r"(?m)^(?=name:)", text)
    stanzas = [Stanza(p) for p in parts[1:]]
    return {s.name: s for s in stanzas}, stanzas


# ---------------------------------------------------------------- helpers
def log(msg):
    # flushed so it stays in order with subprocess output (setup scripts)
    print("vendor-install: %s" % msg, flush=True)


def die(msg):
    print("vendor-install: ERROR: %s" % msg, file=sys.stderr)
    sys.exit(1)


def run(cmd, **kw):
    kw.setdefault("check", True)
    return subprocess.run(cmd, **kw)


def detect_arch():
    try:
        out = run(["dpkg", "--print-architecture"], capture_output=True,
                  text=True).stdout.strip()
        if out:
            return out
    except Exception:
        pass
    m = os.uname().machine
    return {"x86_64": "amd64", "aarch64": "arm64"}.get(m, m)


def epoch():
    e = os.environ.get("SOURCE_DATE_EPOCH")
    if not e and os.path.exists("/etc/snapshot-release"):
        for line in open("/etc/snapshot-release"):
            m = re.match(r'SNAPSHOT_SOURCE_DATE_EPOCH="?(\d+)"?', line.strip())
            if m:
                e = m.group(1)
    return int(e) if e else 0


def iso(e):
    return datetime.datetime.fromtimestamp(
        e, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def staged_archive(stanza, arch):
    art = stanza.artifact(arch)
    if not art:
        return None, None
    store, base, sha = art
    return os.path.join(VENDOR, "src", store, stanza.name, base), sha


def staged_build(name, arch):
    return os.path.join(VENDOR, "src", arch, name, "out")


def verify_build(bs, arch):
    """Check a staged source build against the lock; return its directory."""
    out = staged_build(bs.name, arch)
    text = open(os.path.join(out, "SHA256SUMS")).read()
    want = bs.get("build.sha256.%s" % arch)
    got = hashlib.sha256(text.encode()).hexdigest()
    if want in (None, "TODO") or got != want:
        die("%s: staged build SHA256SUMS %s != lock %s" % (bs.name, got, want))
    for line in text.splitlines():
        sha, rel = line.split("  ", 1)
        if sha256(os.path.join(out, rel)) != sha:
            die("%s: %s sha256 mismatch" % (bs.name, rel))
    return out


def extract(archive, destdir, kind, strip):
    os.makedirs(destdir, exist_ok=True)
    if kind == "zip":
        tmp = destdir + ".unz"
        shutil.rmtree(tmp, ignore_errors=True)
        os.makedirs(tmp)
        run(["unzip", "-q", archive, "-d", tmp])
        src = tmp
        for _ in range(strip):
            entries = [e for e in os.listdir(src)]
            if len(entries) == 1 and os.path.isdir(os.path.join(src, entries[0])):
                src = os.path.join(src, entries[0])
            else:
                break
        for e in os.listdir(src):
            shutil.move(os.path.join(src, e), os.path.join(destdir, e))
        shutil.rmtree(tmp, ignore_errors=True)
    else:  # tarball / git-archive
        run(["tar", "-xf", archive, "-C", destdir,
             "--strip-components=%d" % strip])


def write_manifest(name, fields):
    tooldir = fields.pop("_dir")
    order = ["name", "type", "version", "arch", "runtime", "url", "sha256",
             "uses", "setup", "license", "built", "commands"]
    lines = []
    for k in order:
        if fields.get(k) is not None:
            lines.append("%s=%s" % (k, fields[k]))
    text = "\n".join(lines) + "\n"
    os.makedirs(tooldir, exist_ok=True)
    open(os.path.join(tooldir, "MANIFEST"), "w").write(text)
    os.makedirs(MANIFEST_INDEX, exist_ok=True)
    open(os.path.join(MANIFEST_INDEX, "%s.manifest" % name), "w").write(text)


def chmod_tree_go_w(root):
    for dp, dns, fns in os.walk(root):
        for n in dns + fns:
            p = os.path.join(dp, n)
            try:
                mode = os.lstat(p).st_mode
                if stat.S_ISLNK(mode):
                    continue
                os.chmod(p, mode & ~0o022)
            except OSError:
                pass


# ---------------------------------------------------------------- which tools
def installable_tools(stanzas, arch):
    bn = {s.name: s for s in stanzas}
    out = []
    for s in stanzas:
        if not s.enabled or s.type not in ("python", "java", "data"):
            continue
        if not s.covers(arch):
            continue
        if s.get("kind") == "deb":
            die("%s: kind: deb is reserved (apt/.deb install not supported "
                "in the vendor layer)" % s.name)
        # archive present if the stanza has one
        if s.artifact(arch):
            apath, _ = staged_archive(s, arch)
            if not apath or not os.path.exists(apath):
                log("skip %s: archive not staged" % s.name)
                continue
        # wheelhouse present for python tools with a venv
        if s.type == "python" and s.get("requirements"):
            wh = os.path.join(VENDOR, "python", s.name, "wheelhouse", arch)
            req = os.path.join(VENDOR, "python", s.name,
                               "requirements.%s.txt" % arch)
            if not (os.path.isdir(wh) and os.listdir(wh) and os.path.exists(req)):
                log("skip %s: wheelhouse/%s not staged" % (s.name, arch))
                continue
        # runtime present
        rt = s.get("runtime")
        if rt:
            rs = bn.get(rt)
            rpath, _ = staged_archive(rs, arch) if rs else (None, None)
            if not rpath or not os.path.exists(rpath):
                log("skip %s: runtime %s not staged for %s" % (s.name, rt, arch))
                continue
        # source-build output and setup script present
        unbuilt = [u for u in s.uses() if not os.path.exists(
            os.path.join(staged_build(u, arch), "SHA256SUMS"))]
        if unbuilt:
            log("skip %s: build %s not staged for %s"
                % (s.name, ", ".join(unbuilt), arch))
            continue
        if s.get("setup") and not os.path.exists(
                os.path.join(VENDOR, "setup", os.path.basename(s.get("setup")))):
            log("skip %s: setup %s not staged" % (s.name, s.get("setup")))
            continue
        out.append(s)
    return out


# ---------------------------------------------------------------- phase: runtimes
def phase_runtimes(bn, stanzas, arch, ep):
    tools = installable_tools(stanzas, arch)
    needed = sorted({s.get("runtime") for s in tools if s.get("runtime")})
    if not needed:
        log("no runtimes needed for %s" % arch)
        return
    os.makedirs(RUNTIMES, exist_ok=True)
    for name in needed:
        rs = bn[name]
        apath, want = staged_archive(rs, arch)
        got = sha256(apath)
        if want and got != want:
            die("%s: staged runtime sha256 mismatch (got %s want %s)"
                % (name, got, want))
        dest = os.path.join(RUNTIMES, name)
        shutil.rmtree(dest, ignore_errors=True)
        extract(apath, dest, rs.get("kind", "tarball"),
                int(rs.get("strip", "0") or 0))
        # python runtimes ship timestamp pycs; rebuild them hash-based so the
        # mtime clamp cannot make them look stale.
        py = os.path.join(dest, "bin", "python3")
        if os.path.exists(py):
            for libdir in glob.glob(os.path.join(dest, "lib", "python3.*")):
                for pc in glob.glob(os.path.join(libdir, "**", "__pycache__"),
                                    recursive=True):
                    shutil.rmtree(pc, ignore_errors=True)
                run([py, "-m", "compileall", "-q", "-j0", "-f",
                     "--invalidation-mode", "unchecked-hash",
                     "-x", r"/(test|tests|idle_test)/", libdir])
        chmod_tree_go_w(dest)
        write_manifest(name, {
            "_dir": dest, "name": name, "type": "runtime",
            "version": rs.get("version"), "arch": arch,
            "url": (rs.artifact(arch) or (None, "-", None))[1],
            "sha256": want, "license": rs.get("license"), "built": iso(ep),
        })
        log("runtime %s -> %s" % (name, dest))


# ---------------------------------------------------------------- phase: tools
def wrapper_text(tool, runtime, kind_type, has_venv, has_lib, exec_spec):
    tdir = os.path.join(OPT, tool)
    rdir = os.path.join(RUNTIMES, runtime) if runtime else None
    L = ["#!/bin/sh",
         "# SnapshOT wrapper for %s (generated at image build; docs/vendoring.md)"
         % tool,
         "TOOL=%s" % tdir]
    if rdir:
        L.append("RUNTIME=%s" % rdir)
    if kind_type == "python":
        L.append("export PYTHONNOUSERSITE=1")
        L.append("export PYTHONDONTWRITEBYTECODE=1")
    if kind_type == "java":
        L.append('export JAVA_HOME="$RUNTIME"')
    if has_lib:
        L.append('export LD_LIBRARY_PATH="$TOOL/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"')
    # PATH prepend
    if kind_type == "python" and has_venv:
        L.append('export PATH="$TOOL/venv/bin:$RUNTIME/bin:$PATH"')
    elif rdir:
        L.append('export PATH="$RUNTIME/bin:$PATH"')
    # exec target
    parts = exec_spec.split()
    if parts[0] == "python":
        py = '"$TOOL/venv/bin/python"' if has_venv else '"$RUNTIME/bin/python3"'
        if len(parts) == 1:
            tgt = '%s "$@"' % py
        else:
            tgt = '%s "$TOOL/%s" "$@"' % (py, parts[1])
    else:
        tgt = '"$TOOL/%s" "$@"' % exec_spec
    L.append("exec %s" % tgt)
    return "\n".join(L) + "\n"


def parse_commands(spec):
    out = []
    for item in spec.split(","):
        item = item.strip()
        if not item:
            continue
        name, _, ex = item.partition("=")
        out.append((name.strip(), ex.strip()))
    return out


def phase_tools(bn, stanzas, arch, ep):
    tools = installable_tools(stanzas, arch)
    os.makedirs(BIN, exist_ok=True)
    for s in tools:
        name = s.name
        tdir = os.path.join(OPT, name)
        shutil.rmtree(tdir, ignore_errors=True)
        os.makedirs(tdir, exist_ok=True)
        install_mode = s.get("install", "copy")

        # 1. unpack archive, if any
        art = s.artifact(arch)
        if art:
            apath, want = staged_archive(s, arch)
            got = sha256(apath)
            if want and got != want:
                die("%s: staged archive sha256 mismatch (got %s want %s)"
                    % (name, got, want))
            if s.type == "data" and install_mode == "nmap-scripts":
                sub = "scripts"
            elif s.type == "data":
                sub = "data"
            else:
                sub = "app"
            extract(apath, os.path.join(tdir, sub), s.get("kind", "tarball"),
                    int(s.get("strip", "0") or 0))

        # 2. python venv from the staged wheelhouse
        has_venv = False
        if s.type == "python" and s.get("requirements"):
            rt = bn[s.get("runtime")]
            rtpy = os.path.join(RUNTIMES, rt.name, "bin", "python3")
            venv = os.path.join(tdir, "venv")
            run([rtpy, "-m", "venv", "--without-pip", venv])
            wh = os.path.join(VENDOR, "python", name, "wheelhouse", arch)
            req = os.path.join(VENDOR, "python", name,
                               "requirements.%s.txt" % arch)
            findlinks = ["--find-links", wh]
            noarch_wh = os.path.join(VENDOR, "python", name, "wheelhouse", "noarch")
            if os.path.isdir(noarch_wh):
                findlinks += ["--find-links", noarch_wh]
            run([rtpy, "-m", "pip", "--python", os.path.join(venv, "bin", "python"),
                 "install", "--no-index", "--no-cache-dir", "--no-compile",
                 "--no-deps", "--require-hashes", *findlinks, "-r", req])
            run([os.path.join(venv, "bin", "python"), "-m", "compileall",
                 "-q", "-j0", "-f", "--invalidation-mode", "unchecked-hash",
                 os.path.join(venv, "lib")])
            has_venv = True

        # 3. record a bundled LICENSE for provenance
        for cand in ("scripts/LICENSE", "scripts/LICENSE.txt", "scripts/LICENSE.md",
                     "app/LICENSE", "app/LICENSE.txt", "app/LICENSE.md",
                     "app/COPYING", "app/LICENSE-2.0.txt", "data/LICENSE"):
            lp = os.path.join(tdir, cand)
            if os.path.exists(lp):
                shutil.copy2(lp, os.path.join(tdir, "LICENSE"))
                break

        # 3b. per-tool setup (vendor/setup/<tool>.py), before wrappers and the
        # go-w/MANIFEST/mtime steps; gets the verified source-build outputs.
        if s.get("setup"):
            env = dict(os.environ, SNAPSHOT_TOOL=tdir,
                       SNAPSHOT_APP=os.path.join(tdir, "app"),
                       SNAPSHOT_ARCH=arch, SOURCE_DATE_EPOCH=str(ep))
            if s.get("runtime"):
                env["SNAPSHOT_RUNTIME"] = os.path.join(RUNTIMES, s.get("runtime"))
            for u in s.uses():
                env["SNAPSHOT_BUILD_" + re.sub(r"[^A-Z0-9]", "_", u.upper())] = \
                    verify_build(bn[u], arch)
            run([sys.executable, os.path.join(
                VENDOR, "setup", os.path.basename(s.get("setup")))], env=env)

        # 4. wrappers + /opt/snapshot/bin symlinks
        has_lib = os.path.isdir(os.path.join(tdir, "lib"))
        cmds = parse_commands(s.get("commands", ""))
        os.makedirs(os.path.join(tdir, "bin"), exist_ok=True)
        for (cname, ex) in cmds:
            if ex.split()[0] != "python":
                # catches exec bits a zip did not store, for any tool
                tgt = os.path.join(tdir, ex)
                if not (os.path.isfile(tgt) and os.access(tgt, os.X_OK)):
                    die("%s: command %s target %s missing or not executable"
                        % (name, cname, tgt))
            w = os.path.join(tdir, "bin", cname)
            open(w, "w").write(wrapper_text(
                name, s.get("runtime"), s.type, has_venv, has_lib, ex))
            os.chmod(w, 0o755)
            link = os.path.join(BIN, cname)
            if os.path.islink(link) or os.path.exists(link):
                os.remove(link)
            os.symlink(os.path.relpath(w, BIN), link)

        # 5. nmap-scripts: symlink *.nse, refresh + sort the db
        if install_mode == "nmap-scripts":
            os.makedirs(NMAP_SCRIPTS, exist_ok=True)
            for nse in sorted(glob.glob(os.path.join(tdir, "scripts", "*.nse"))):
                link = os.path.join(NMAP_SCRIPTS, os.path.basename(nse))
                if os.path.islink(link) or os.path.exists(link):
                    os.remove(link)
                os.symlink(nse, link)
            if shutil.which("nmap"):
                run(["nmap", "--script-updatedb"])
                db = os.path.join(NMAP_SCRIPTS, "script.db")
                if os.path.exists(db):
                    env = dict(os.environ, LC_ALL="C")
                    run(["sort", "-o", db, db], env=env)

        chmod_tree_go_w(tdir)
        write_manifest(name, {
            "_dir": tdir, "name": name, "type": s.type,
            "version": s.get("version"), "arch": arch,
            "runtime": s.get("runtime"),
            "url": (art[1] if art else "(pip wheelhouse)"),
            "sha256": (art[2] if art else "(requirements.%s.txt hash-pinned)" % arch),
            "uses": ",".join("%s@%s:%s" % (u, bn[u].get("version"),
                                           bn[u].get("build.sha256." + arch))
                             for u in s.uses()) or None,
            "setup": os.path.basename(s.get("setup")) if s.get("setup") else None,
            "license": s.get("license"),
            "built": iso(ep),
            "commands": ",".join(c for c, _ in cmds) or None,
        })
        log("tool %s -> %s (%d command(s))" % (name, tdir, len(cmds)))


# ---------------------------------------------------------------- phase: finish
def phase_finish(ep):
    if os.path.isdir(OPT):
        # clamp every path (including symlinks) to SOURCE_DATE_EPOCH
        run(["find", OPT, "-exec", "touch", "-h", "-d", "@%d" % ep, "{}", "+"])
    if os.path.isdir(MANIFEST_INDEX):
        run(["find", MANIFEST_INDEX, "-exec", "touch", "-h",
             "-d", "@%d" % ep, "{}", "+"])
    shutil.rmtree(VENDOR, ignore_errors=True)
    log("clamped mtimes to %s and removed staging dir" % iso(ep))


# ---------------------------------------------------------------- main
def main(argv):
    phases = argv or ["runtimes", "tools", "finish"]
    bn, stanzas = load_lock()
    arch = detect_arch()
    ep = epoch()
    log("arch=%s SOURCE_DATE_EPOCH=%d (%s)" % (arch, ep, iso(ep)))
    for ph in phases:
        if ph == "runtimes":
            phase_runtimes(bn, stanzas, arch, ep)
        elif ph == "tools":
            phase_tools(bn, stanzas, arch, ep)
        elif ph == "finish":
            phase_finish(ep)
        else:
            die("unknown phase %r" % ph)


if __name__ == "__main__":
    main(sys.argv[1:])
