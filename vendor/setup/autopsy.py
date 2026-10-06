#!/usr/bin/env python3
"""SnapshOT post-install setup for Autopsy (lock stanza `autopsy`, key setup:).

Run by vendor-install.py as root, offline, after the zip is unpacked to
$SNAPSHOT_APP and before the wrappers, chmod go-w, MANIFEST and the mtime
clamp. Does unix_setup.sh's job for a read-only tree: points autopsy.conf at
the vendored JRE, puts the libtsk_jni.so built by vendor/recipes/sleuthkit-jni.sh
into the TSK jar, keeps Solr's pid file and logs out of the install tree,
restores the exec bits the zip does not store, and prunes the Windows/macOS-only
payload except Tesseract-OCR/tessdata, which Autopsy's core installer copies
on first start. See docs/vendoring.md.
"""
import fnmatch
import os
import re
import shutil
import sys
import time
import zipfile

APP = os.environ["SNAPSHOT_APP"]
TOOL = os.environ["SNAPSHOT_TOOL"]
RUNTIME = os.environ["SNAPSHOT_RUNTIME"]
JNI = os.environ["SNAPSHOT_BUILD_SLEUTHKIT_JNI"]
EPOCH = int(os.environ.get("SOURCE_DATE_EPOCH") or 0)

TSK_JAR = "autopsy/modules/ext/sleuthkit-4.15.0.jar"
JNI_ENTRY = "NATIVELIBS/amd64/linux/libtsk_jni.so"   # os.arch on x86-64 Linux JVMs

# Windows-only trees: used only under PlatformUtil.isWindowsOS() (or Linux uses
# the system tool: photorec from testdisk, GStreamer). None is named in a module
# manifest Class-Path; javafx-*-mac/-win and httpclient-win ARE, so they stay.
PRUNE_DIRS = [
    "autopsy/gstreamer", "autopsy/photorec_exec",
    "autopsy/plaso", "autopsy/Volatility", "autopsy/7-Zip",
    "autopsy/ewfexport_exec", "autopsy/tsk_logical_imager",
    "autopsy/ESEDatabaseView", "autopsy/thumbcache_parser",
    "autopsy/iLeapp", "autopsy/aLeapp",
]
# Tesseract-OCR: the engine (tesseract.exe, its DLLs, doc/) goes, tessdata/
# stays. Autopsy 4.23.1's core Installer.restored() calls
# ensureOcrLanguagePacksFolderExists() on every OS: on the first start of a user
# dir it locates Tesseract-OCR/tessdata in the install and copies it to the
# user's OCR language pack folder. Without it the copy throws
# NullPointerException: srcDir, which aborts the rest of core start-up (JavaFX,
# 7-Zip, the module installers, the Welcome window). The language packs are
# plain data (about 14 MiB); OCR stays unsupported on Linux, with no engine.
TESSERACT = "autopsy/Tesseract-OCR"
TESSERACT_KEEP = "tessdata"
# rr and rr-full stay: on Linux ExtractRegistry runs `perl rr/rip.pl`.
PRUNE_GLOBS = [
    "bin/*.exe", "platform/lib/*.exe", "platform/lib/*.dll",
    "autopsy/modules/lib/amd64/*.dll", "autopsy/modules/lib/amd64/*.dylib",
    "autopsy/modules/lib/x86_64/*.dll", "autopsy/modules/lib/x86_64/*.dylib",
    "autopsy/rr/*.exe", "autopsy/rr/*.dll",
    "autopsy/rr-full/*.exe", "autopsy/rr-full/*.dll",
    "autopsy/yara/*.exe", "autopsy/pasco2/*.dll",
]
MARKMCKINNON_KEEP = {"mm_artifact_parser_x64_linux", "LICENSE-2.0.txt"}
# The zip stores no unix modes, so unzip leaves everything 0644.
EXECUTABLES = ["bin/autopsy", "platform/lib/nbexec",
               "autopsy/markmckinnon/mm_artifact_parser_x64_linux"]
REQUIRED = EXECUTABLES + [
    "etc/autopsy.conf", TSK_JAR, "autopsy/solr/bin/autopsy-solr",
    "autopsy/solr/bin/autopsy-solr.in.sh", "autopsy/rr/rip.pl",
    "autopsy/rr-full/rip.pl", "autopsy/modules/lib/amd64/libheifconvert.so",
    TESSERACT + "/" + TESSERACT_KEEP + "/eng.traineddata",
]
SOLR_BLOCK = '''
# --- SnapshOT (vendor/setup/autopsy.py) -------------------------------------
# /opt/snapshot is read-only. Autopsy exports SOLR_HOME=<userdir>/solr, so keep
# Solr's pid file and logs there instead of in solr/bin and solr/server/logs.
if [ -n "$SOLR_HOME" ]; then
  SOLR_PID_DIR="${SOLR_PID_DIR:-$SOLR_HOME}"
  SOLR_LOGS_DIR="${SOLR_LOGS_DIR:-$SOLR_HOME/../var/log/solr}"
fi
'''


def log(msg):
    print("autopsy-setup: %s" % msg)


def die(msg):
    print("autopsy-setup: ERROR: %s" % msg, file=sys.stderr)
    sys.exit(1)


def p(rel):
    return os.path.join(APP, rel)


def tree_size(path):
    if os.path.isfile(path):
        return os.path.getsize(path)
    return sum(os.path.getsize(os.path.join(dp, f))
               for dp, _, fns in os.walk(path) for f in fns)


def prune():
    freed = 0
    for d in PRUNE_DIRS:
        if not os.path.isdir(p(d)):
            log("note: %s not in this release" % d)
            continue
        freed += tree_size(p(d))
        shutil.rmtree(p(d))
    if not os.path.isdir(p(os.path.join(TESSERACT, TESSERACT_KEEP))):
        die("%s/%s not in this release" % (TESSERACT, TESSERACT_KEEP))
    for fn in sorted(os.listdir(p(TESSERACT))):
        if fn == TESSERACT_KEEP:
            continue
        f = p(os.path.join(TESSERACT, fn))
        freed += tree_size(f)
        if os.path.isdir(f) and not os.path.islink(f):
            shutil.rmtree(f)
        else:
            os.remove(f)
    log("kept %s/%s (%.1f MiB of OCR language data)" % (
        TESSERACT, TESSERACT_KEEP,
        tree_size(p(os.path.join(TESSERACT, TESSERACT_KEEP))) / 2**20))
    for dp, _, fns in os.walk(APP):
        for fn in fns:
            rel = os.path.relpath(os.path.join(dp, fn), APP)
            if any(fnmatch.fnmatchcase(rel, g) for g in PRUNE_GLOBS) or (
                    rel.startswith("autopsy/markmckinnon/")
                    and fn not in MARKMCKINNON_KEEP):
                freed += os.path.getsize(p(rel))
                os.remove(p(rel))
    log("pruned %.1f MiB of Windows/macOS-only files" % (freed / 2**20))


def patch_tsk_jar():
    """Rewrite the TSK jar without its win/mac DLLs and with our libtsk_jni.so
    as NATIVELIBS/amd64/linux/libtsk_jni.so (TSK loads it only from there).
    Deterministic: entries keep their order and dates; ours gets the epoch."""
    jar = p(TSK_JAR)
    so = open(os.path.join(JNI, "libtsk_jni.so"), "rb").read()
    stamp = time.gmtime(max(EPOCH, 315532800))[:6]   # zip dates start in 1980
    tmp = jar + ".snapshot"
    added = False
    with zipfile.ZipFile(jar) as zin, zipfile.ZipFile(tmp, "w") as zout:
        for info in zin.infolist():
            n = info.filename
            if re.match(r"NATIVELIBS/[^/]+/(win|mac)/.+", n) or n == JNI_ENTRY:
                continue
            zi = zipfile.ZipInfo(n, date_time=info.date_time)
            zi.compress_type = info.compress_type
            zi.external_attr = info.external_attr
            zi.create_system = info.create_system
            zout.writestr(zi, zin.read(info))
            if n == os.path.dirname(JNI_ENTRY) + "/":
                zi = zipfile.ZipInfo(JNI_ENTRY, date_time=stamp)
                zi.compress_type = zipfile.ZIP_DEFLATED
                zi.create_system = 3
                zi.external_attr = 0o100644 << 16
                zout.writestr(zi, so)
                added = True
    if not added:
        die("%s has no %s/ entry" % (TSK_JAR, os.path.dirname(JNI_ENTRY)))
    os.chmod(tmp, 0o644)
    os.replace(tmp, jar)
    log("put libtsk_jni.so into %s" % TSK_JAR)


def patch_conf():
    conf = p("etc/autopsy.conf")
    out, done = [], False
    for line in open(conf).read().splitlines():
        if re.match(r"\s*#?\s*jdkhome=", line):   # as unix_setup.sh
            continue
        if line.startswith('default_options="') and not done:
            # --nosplash: first-run dialogs open behind the splash (upstream
            # Running_Linux_OSX.md). Jython's package cache goes per-user.
            line = line.replace(
                'default_options="', 'default_options="--nosplash '
                '-J-Dpython.cachedir=${DEFAULT_CACHEDIR_ROOT}/dev/jython ', 1)
            done = True
        out.append(line)
    if not done:
        die("no default_options in etc/autopsy.conf")
    out += ["",
            "# SnapshOT: the pinned Temurin JRE from the vendor layer "
            "(docs/vendoring.md).",
            'jdkhome="%s"' % RUNTIME]
    open(conf, "w").write("\n".join(out) + "\n")


def main():
    prune()
    patch_tsk_jar()
    patch_conf()
    with open(p("autopsy/solr/bin/autopsy-solr.in.sh"), "a") as f:
        f.write(SOLR_BLOCK)
    for rel in EXECUTABLES:
        os.chmod(p(rel), 0o755)
    solr_bin = p("autopsy/solr/bin")
    for fn in os.listdir(solr_bin):
        f = os.path.join(solr_bin, fn)
        if os.path.isfile(f) and not fn.endswith(".cmd"):
            os.chmod(f, 0o755)
    shutil.copytree(os.path.join(JNI, "sleuthkit-licenses"),
                    os.path.join(TOOL, "licenses", "sleuthkit"))
    missing = [r for r in REQUIRED if not os.path.exists(p(r))]
    if missing:
        die("missing after setup: " + ", ".join(missing))


if __name__ == "__main__":
    main()
