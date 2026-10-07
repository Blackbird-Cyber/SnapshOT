#!/usr/bin/env bash
# SnapshOT source build: libtsk_jni.so for Autopsy from The Sleuth Kit 4.15.0
# (lock stanza sleuthkit-jni). Run by scripts/vendor.py in a throwaway
# debian:trixie container of the target arch, repo at /work. Env: BUILD_SRC
# BUILD_STRIP BUILD_OUT SNAPSHOT_DEBIAN_PIN SNAPSHOT_DIST SOURCE_DATE_EPOCH
# HOST_UID HOST_GID. libtsk 4.15 is linked in statically, so it never loads
# Debian's libtsk19t64 (4.12.1); the other libraries are shared, from the pin.
# Not run since 2026-10-07: sleuthkit-jni is disabled with autopsy, its only
# user (docs/vendoring.md, "Out of scope and why"); kept as the recorded shape.
set -euo pipefail
. "$(dirname "$0")/lib/pinned-apt.sh"
pinned_install build-essential pkg-config openjdk-21-jdk-headless \
    libewf-dev libafflib-dev libvhdi-dev libvmdk-dev libbfio-dev libsqlite3-dev zlib1g-dev
B=/tmp/b   # fixed path: output is bit-for-bit reproducible per pin
rm -rf "$B"; mkdir -p "$B"; cd "$B"
tar -xzf "$BUILD_SRC" --strip-components="${BUILD_STRIP:-1}"
# ANT_FOUND: configure enables the JNI only if it finds ant; we never run the
#   ant jar build (ivy fetches deps online), so a stub is enough.
# --without-libvslvm: 4.15.0 tarball lacks tsk/pool/tsk_lvm.hpp.
# --with-pic: libtsk.a is linked into a shared object below.
ANT_FOUND=/bin/true ./configure --enable-java --with-pic --disable-cppunit \
    --without-libvslvm >"$B/configure.log" 2>&1 || { tail -40 "$B/configure.log"; exit 1; }
grep -qE 'Java/JNI support: +yes' "$B/configure.log" || { echo "JNI not enabled" >&2; exit 1; }
make -s -C tsk -j"$(nproc)"
make -s -C bindings/java/jni -j"$(nproc)"
# libtool's libtsk_jni.so would need libtsk.so.23; relink against libtsk.a.
J=bindings/java/jni
LIBS_LINE="$(sed -n 's/^LIBS = //p' "$J/Makefile")"
PTHREAD="$(sed -n 's/^PTHREAD_CFLAGS = //p' "$J/Makefile")"
so="$BUILD_OUT/libtsk_jni.so"
g++ -shared -fPIC $PTHREAD -o "$so" "$J/.libs/dataModel_SleuthkitJNI.o" "$J/.libs/auto_db_java.o" \
    tsk/.libs/libtsk.a $LIBS_LINE -lstdc++ \
    -Wl,-soname,libtsk_jni.so -Wl,-z,defs -Wl,--as-needed -Wl,--build-id=none
strip --strip-unneeded "$so"
# Gates (no `cmd | grep -q` under pipefail: SIGPIPE makes it lie)
needed="$(readelf -d "$so")"; printf '%s\n' "$needed" | grep NEEDED
case "$needed" in *libtsk.so*) echo "libtsk linked dynamically" >&2; exit 1;; esac
deps="$(ldd "$so")"; case "$deps" in *"not found"*) printf '%s\n' "$deps" >&2; exit 1;; esac
n="$(nm -D --defined-only "$so" | grep -c ' T Java_org_sleuthkit_datamodel_' || true)"
[ "$n" -ge 50 ] || { echo "only $n JNI symbols" >&2; exit 1; }
mkdir -p "$BUILD_OUT/sleuthkit-licenses"
cp licenses/README.md licenses/IBM-LICENSE licenses/cpl1.0.txt licenses/Apache-LICENSE-2.0.txt "$BUILD_OUT/sleuthkit-licenses/"
chown -R "${HOST_UID:-0}:${HOST_GID:-0}" "$BUILD_OUT"
