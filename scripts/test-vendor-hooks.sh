#!/usr/bin/env bash
# Prove the vendor layer installs and works, end to end, without building a full
# ISO. Stages the layer for one arch with scripts/vendor.py, then runs
# scripts/vendor-install.py (runtimes/tools/finish) inside a debian:trixie
# container of that arch and asserts the installed /opt/snapshot works.
#
#   scripts/test-vendor-hooks.sh [arch]     # arch: arm64 (default) | amd64
#
# arm64 is native on Apple Silicon; amd64 runs under emulation (slower). Run
# `scripts/vendor.py fetch --arch all` first so the layer is present. See
# docs/vendoring.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
ARCH="${1:-arm64}"
case "$ARCH" in amd64|arm64) ;; *) echo "arch must be amd64 or arm64" >&2; exit 2;; esac
IMAGE="${SNAPSHOT_TRIXIE_IMAGE:-debian:trixie}"
. config/snapshot.env
EPOCH="${SNAPSHOT_SOURCE_DATE_EPOCH}"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/snapshot-vendortest.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
echo "== staging vendor layer for $ARCH =="
python3 scripts/vendor.py stage --arch "$ARCH" --dest "$STAGE/vendor"
[ -f "$STAGE/vendor/vendor-install.py" ] || { echo "nothing staged for $ARCH; run scripts/vendor.py fetch" >&2; exit 1; }

echo "== installing + testing inside $IMAGE (linux/$ARCH) =="
docker run --rm -i --platform "linux/$ARCH" \
    -e SOURCE_DATE_EPOCH="$EPOCH" -e TEST_ARCH="$ARCH" \
    -v "$STAGE/vendor":/usr/local/share/snapshot/vendor:ro \
    "$IMAGE" bash -s <<'CONTAINER'
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    python3 nmap unzip ca-certificates findutils >/dev/null
# The amd64 OPC UA GUI client is PyQt5; the real SnapshOT image has the desktop,
# so give the bare test container the Qt runtime libs the offscreen platform
# needs (libGL/EGL, glib, fontconfig, dbus, xkbcommon). Autopsy's libtsk_jni.so
# needs the image libraries from snapshot-reporting.list.chroot and its Solr
# script needs ps and lsof; the JDK is only for javac on the JNI probe (P).
if [ "${TEST_ARCH}" = amd64 ]; then
    apt-get install -y -qq --no-install-recommends \
        libgl1 libegl1 libopengl0 libglib2.0-0 libfontconfig1 libfreetype6 \
        libdbus-1-3 libxkbcommon0 \
        libewf2 libafflib0t64 libvhdi1 libvmdk1 libsqlite3-0 zlib1g procps lsof \
        openjdk-21-jdk-headless >/dev/null
fi

fail=0
pass() { echo "  PASS: $1"; }
bad()  { echo "  FAIL: $1"; fail=1; }
have() { [ -e "$1" ] && pass "$1 exists" || bad "$1 missing"; }

echo "== run installer (runtimes, tools, finish) =="
python3 /usr/local/share/snapshot/vendor/vendor-install.py runtimes tools finish \
    || { echo "installer FAILED"; exit 1; }

OPT=/opt/snapshot
RT=$OPT/runtimes/cpython-3.11.16

echo "== assertions =="

# A. runtime interpreter
if "$RT/bin/python3" -c 'import sys;print(sys.version)' 2>/dev/null | grep -q '3\.11\.16'; then
    pass "runtime python is 3.11.16"
else bad "runtime python is not 3.11.16"; fi

# B. ICS libraries import (cpppo dropped: not imported)
if "$OPT/bin/ics-python" -c 'import pymodbus, pycomm3, bacpypes3, BAC0, asyncua, snap7; print("ok")' 2>/tmp/imp | grep -q ok; then
    pass "ics-python imports pymodbus/pycomm3/bacpypes3/BAC0/asyncua/snap7"
else bad "ics-python import failed"; sed 's/^/    /' /tmp/imp; fi

# C. pymodbus.console present (amendment 1: pymodbus-repl)
have "$OPT/ics-python/venv/bin/pymodbus.console"
have "$OPT/ics-python/bin/pymodbus-console"

# D. uadiscover --help
if "$OPT/bin/uadiscover" --help >/dev/null 2>&1; then pass "uadiscover --help exits 0"
else bad "uadiscover --help nonzero"; fi

# E. plcscan -h
if "$OPT/bin/plcscan" -h >/dev/null 2>&1; then pass "plcscan -h exits 0"
else bad "plcscan -h nonzero"; fi

# F. plcscan finds a live pymodbus server on 127.0.0.1:5020
cat > /tmp/mbserver.py <<'PY'
# Minimal Modbus/TCP server on the ics-python venv (pymodbus 3.11 API).
import asyncio
from pymodbus.datastore import (ModbusDeviceContext, ModbusServerContext,
                                ModbusSequentialDataBlock)
from pymodbus.server import StartAsyncTcpServer
try:
    from pymodbus.pdu.device import ModbusDeviceIdentification
    ident = ModbusDeviceIdentification()
    ident.VendorName = "SnapshOT"; ident.ProductCode = "TST"
    ident.ProductName = "vendor-test"; ident.MajorMinorRevision = "1.0"
except Exception:
    ident = None
block = ModbusSequentialDataBlock(0, [0] * 100)
ctx = ModbusServerContext(
    devices=ModbusDeviceContext(di=block, co=block, hr=block, ir=block),
    single=True)
asyncio.run(StartAsyncTcpServer(context=ctx, identity=ident,
                                address=("127.0.0.1", 5020)))
PY
"$OPT/ics-python/venv/bin/python" /tmp/mbserver.py & SRV=$!
for i in $(seq 1 30); do
    python3 -c 'import socket;socket.create_connection(("127.0.0.1",5020),1)' 2>/dev/null && break
    sleep 0.5
done
OUT="$("$OPT/bin/plcscan" --ports 5020 --modbus-uid 1 --modbus-timeout 3 127.0.0.1 2>&1 || true)"
kill "$SRV" 2>/dev/null || true
if printf '%s' "$OUT" | grep -q 'Modbus/TCP'; then
    pass "plcscan detected the pymodbus server on :5020"
else
    bad "plcscan did not detect the pymodbus server"; printf '%s\n' "$OUT" | sed 's/^/    /'
fi

# G. Redpoint NSE scripts symlinked + usable
n="$(ls /usr/share/nmap/scripts | grep -ciE 's7|enip|bacnet|modicon' || true)"
if [ "${n:-0}" -ge 4 ]; then pass "nmap has $n ICS NSE scripts (s7/enip/bacnet/modicon)"
else bad "expected >=4 ICS NSE scripts, found ${n:-0}"; fi
if nmap --script-help s7-enumerate >/dev/null 2>&1; then pass "nmap --script-help s7-enumerate works"
else bad "nmap --script-help s7-enumerate failed"; fi

# H. script.db deterministic order (amendment 3)
if LC_ALL=C sort -c /usr/share/nmap/scripts/script.db 2>/dev/null; then
    pass "script.db is LC_ALL=C sorted"
else bad "script.db not sorted"; fi

# I. every MANIFEST + index entry present
for t in runtimes/cpython-3.11.16 ics-python plcscan redpoint-nse; do
    have "$OPT/$t/MANIFEST"
done
[ "$TEST_ARCH" = amd64 ] && have "$OPT/opcua-client/MANIFEST"
for m in cpython-3.11.16 ics-python plcscan redpoint-nse; do
    have "/usr/share/snapshot/vendor/$m.manifest"
done

# J. every .pyc under /opt/snapshot is hash-based (amendment 2)
python3 - <<'PY'
import glob, struct, sys
files = glob.glob('/opt/snapshot/**/*.pyc', recursive=True)
bad = []
for f in files:
    with open(f, 'rb') as fh:
        fh.read(4)
        flags = struct.unpack('<I', fh.read(4))[0]
    if not (flags & 1):
        bad.append(f)
print("  checked %d pyc files" % len(files))
if not files:
    print("  FAIL: no pyc files found"); sys.exit(1)
if bad:
    print("  FAIL: %d timestamp-based pyc" % len(bad))
    for b in bad[:8]:
        print("    " + b)
    sys.exit(1)
print("  PASS: every pyc under /opt/snapshot is hash-based")
PY
[ $? -eq 0 ] || fail=1

# K. nothing world-writable
ww="$(find "$OPT" -not -type l -perm -0002 2>/dev/null)"
if [ -z "$ww" ]; then pass "no world-writable files under /opt/snapshot"
else bad "world-writable files under /opt/snapshot"; printf '%s\n' "$ww" | sed 's/^/    /'; fi

# L. PATH policy: /opt/snapshot/bin appended; OS python3 still wins
export PATH="$PATH:/opt/snapshot/bin"
if [ "$(command -v python3)" = /usr/bin/python3 ]; then pass "python3 still resolves to /usr/bin"
else bad "python3 resolves to $(command -v python3)"; fi
if [ "$(command -v ics-python)" = /opt/snapshot/bin/ics-python ]; then pass "ics-python resolves via /opt/snapshot/bin"
else bad "ics-python not on PATH"; fi

# M. mtime clamp
newer="$(find "$OPT" -not -type l -newermt "@$SOURCE_DATE_EPOCH" 2>/dev/null)"
if [ -z "$newer" ]; then pass "no file under /opt/snapshot is newer than SOURCE_DATE_EPOCH"
else bad "files newer than SOURCE_DATE_EPOCH"; printf '%s\n' "$newer" | head | sed 's/^/    /'; fi

# N. no legacy global venv / profile.d
[ ! -e /opt/snapshot/venv ] && pass "no /opt/snapshot/venv leftover" || bad "/opt/snapshot/venv exists"
[ ! -e /etc/profile.d/snapshot-venv.sh ] && pass "no /etc/profile.d/snapshot-venv.sh" || bad "snapshot-venv.sh exists"

# O. amd64-only OPC UA GUI client. The tool is a pure PyQt5 GUI (QApplication +
# exec_(), no --help), so prove the venv works by importing its main module and
# bringing up a QApplication under the offscreen platform.
if [ "$TEST_ARCH" = amd64 ]; then
    have "$OPT/opcua-client/bin/opcua-client"
    if QT_QPA_PLATFORM=offscreen "$OPT/opcua-client/venv/bin/python" -c \
        'import uaclient.mainwindow; from PyQt5.QtWidgets import QApplication; QApplication([]); print("qt-ok")' \
        2>/tmp/qt | grep -q qt-ok; then
        pass "opcua-client venv: PyQt5 + uaclient import + QApplication(offscreen) OK"
    else bad "opcua-client Qt offscreen smoke test failed"; sed 's/^/    /' /tmp/qt; fi
fi

# P. amd64-only Autopsy (vendor/setup/autopsy.py): the vendored JRE, wrapper and
# autopsy.conf, exec bits, the prune, libtsk_jni.so in the TSK jar and loading
# as a normal user, embedded Solr from the read-only tree, and no writes under
# /opt/snapshot while those parts run. On arm64 none of it may be installed.
if [ "$TEST_ARCH" = amd64 ]; then
    A=$OPT/autopsy; APP=$A/app; JRE=$OPT/runtimes/temurin-jre-21.0.12.1
    JAR=$APP/autopsy/modules/ext/sleuthkit-4.15.0.jar; S=$APP/autopsy/solr
    for f in "$A/MANIFEST" "$JRE/MANIFEST" /usr/share/snapshot/vendor/autopsy.manifest \
             /usr/share/snapshot/vendor/temurin-jre-21.0.12.1.manifest "$A/LICENSE" \
             "$A/licenses/sleuthkit/README.md" "$OPT/bin/autopsy" "$A/bin/autopsy"; do have "$f"; done
    v="$("$JRE/bin/java" -version 2>&1)"
    case "$v" in *'"21.0.12.1"'*) pass "JRE 21.0.12.1 runs";;
        *) bad "vendored JRE does not run"; printf '%s\n' "$v" | sed 's/^/    /';; esac
    grep -qx "RUNTIME=$JRE" "$A/bin/autopsy" && grep -qx 'exec "$TOOL/app/bin/autopsy" "$@"' "$A/bin/autopsy" \
        && pass "autopsy wrapper -> app/bin/autopsy on the JRE" || bad "autopsy wrapper wrong"
    c=$APP/etc/autopsy.conf
    [ "$(grep -cE '^[[:space:]]*#?[[:space:]]*jdkhome=' "$c")" = 1 ] && grep -qx "jdkhome=\"$JRE\"" "$c" \
        && pass "autopsy.conf jdkhome=$JRE" || bad "autopsy.conf jdkhome wrong"
    grep -q '^default_options="--nosplash ' "$c" && pass "default_options has --nosplash" || bad "no --nosplash"
    for f in bin/autopsy platform/lib/nbexec autopsy/solr/bin/autopsy-solr autopsy/markmckinnon/mm_artifact_parser_x64_linux; do
        [ -x "$APP/$f" ] && pass "$f executable" || bad "$f not executable"; done
    for d in gstreamer photorec_exec Tesseract-OCR plaso Volatility 7-Zip iLeapp aLeapp ewfexport_exec; do
        [ ! -e "$APP/autopsy/$d" ] && pass "pruned autopsy/$d" || bad "autopsy/$d still present"; done
    left="$(find "$APP" -type f \( -iname '*.exe' -o -iname '*.dylib' -o \( -iname '*.dll' ! -path '*/platform/modules/lib/*' \) \))"
    [ -z "$left" ] && pass "no Windows/macOS binaries left" || { bad "Windows/macOS binaries left"; printf '%s\n' "$left" | head | sed 's/^/    /'; }
    for f in autopsy/rr/rip.pl autopsy/rr-full/rip.pl autopsy/modules/lib/amd64/libheifconvert.so; do have "$APP/$f"; done
    python3 - "$JAR" <<'PY' && pass "jar has NATIVELIBS/amd64/linux/libtsk_jni.so, no win DLLs" || bad "TSK jar not patched"
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1]); n = z.namelist()
assert "NATIVELIBS/amd64/linux/libtsk_jni.so" in n and not [x for x in n if x.endswith(".dll")]
open("/tmp/libtsk_jni.so", "wb").write(z.read("NATIVELIBS/amd64/linux/libtsk_jni.so"))
PY
    d="$(ldd /tmp/libtsk_jni.so 2>&1)"
    case "$d" in *"not found"*|*libtsk.so*|*"not a dynamic"*) bad "libtsk_jni.so deps wrong"; printf '%s\n' "$d" | sed 's/^/    /';;
        *) pass "libtsk_jni.so resolves (libtsk static)";; esac
    touch /tmp/p-marker; useradd -m tester 2>/dev/null || true
    mkdir -p /tmp/probe; printf 'import org.sleuthkit.datamodel.SleuthkitJNI;\npublic class TskJniSmoke { public static void main(String[] a) { System.out.println("tsk-jni-version=" + SleuthkitJNI.getVersion()); } }\n' > /tmp/probe/TskJniSmoke.java
    javac --release 21 -cp "$JAR" -d /tmp/probe /tmp/probe/TskJniSmoke.java && chmod -R a+rX /tmp/probe
    out="$(runuser -u tester -- "$JRE/bin/java" -cp "$JAR:/tmp/probe" TskJniSmoke 2>&1)"
    case "$out" in *tsk-jni-version=4.15.0*) pass "SleuthkitJNI loads as a normal user (4.15.0)";;
        *) bad "JNI load failed"; printf '%s\n' "$out" | sed 's/^/    /';; esac
    out="$(runuser -u tester -- bash -c '
        U=$HOME/.autopsy/dev; mkdir -p "$U/solr" "$U/var/log"
        cp "$1/server/solr/solr.xml" "$1/server/solr/zoo.cfg" "$U/solr/"; cp -r "$1/server/solr/configsets" "$U/solr/"
        cd "$1" && SOLR_HOME="$U/solr" SOLR_JAVA_HOME="$2" SOLR_JAVA_MEM=-Xmx512m STOP_KEY=t timeout 600 "$1/bin/autopsy-solr" start -p 23232 >/tmp/solr.log 2>&1 || { echo START-FAILED; tail -5 /tmp/solr.log; }
        python3 -c "import urllib.request as u; print(\"solr-http\", u.urlopen(\"http://127.0.0.1:23232/solr/admin/info/system?wt=json\", timeout=30).status)"
        ls "$U/solr/solr-23232.pid" "$U/var/log/solr/solr.log"
        SOLR_HOME="$U/solr" SOLR_JAVA_HOME="$2" "$1/bin/autopsy-solr" stop -k t -p 23232 >/dev/null 2>&1' _ "$S" "$JRE" 2>&1)"
    case "$out" in
        *START-FAILED*|*"No such file"*) bad "Solr did not start cleanly"; printf '%s\n' "$out" | sed 's/^/    /';;
        *"solr-http 200"*) pass "Solr 8 starts from the read-only tree (pid + logs under ~/.autopsy/dev)";;
        *) bad "Solr did not start"; printf '%s\n' "$out" | sed 's/^/    /';;
    esac
    w="$(find "$OPT" -newer /tmp/p-marker 2>/dev/null)"
    [ -z "$w" ] && pass "running Autopsy parts wrote nothing under /opt/snapshot" || { bad "writes under /opt/snapshot"; printf '%s\n' "$w" | head | sed 's/^/    /'; }
else
    for f in "$OPT/autopsy" "$OPT/bin/autopsy" "$OPT/runtimes/temurin-jre-21.0.12.1" \
             /usr/share/snapshot/vendor/autopsy.manifest; do
        [ ! -e "$f" ] && pass "no $f on $TEST_ARCH" || bad "$f installed on $TEST_ARCH"; done
fi

echo
if [ "$fail" -eq 0 ]; then echo "== test-vendor-hooks ($TEST_ARCH): ALL PASS =="; else echo "== test-vendor-hooks ($TEST_ARCH): FAIL =="; fi
exit "$fail"
CONTAINER
