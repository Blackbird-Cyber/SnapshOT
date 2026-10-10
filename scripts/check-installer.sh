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
#      the sudoers drop-in and checks it with visudo -cf, and
#      0600-snapshot-wireshark.hook.chroot against wireshark-common from the
#      pin: group wireshark exists and dumpcap is root:wireshark with
#      capabilities (or setuid when the container cannot set them). Checks
#      that users.conf and the live-config defaults both add group wireshark.
#   6. Parses settings.conf and asserts that the exec sequence runs packages
#      before initramfscfg, so the installed initramfs has no live-boot hooks.
#   7. Checks the bootloader setup: bootloader.conf runs snapshot-boot's
#      grub-install wrapper with installEFIFallback off, and the wrapper (mode
#      755, valid sh), run against a stub grub-install, adds
#      --uefi-secure-boot --force-extra-removable for an EFI target, copies
#      EFI/<id>/grub.cfg to EFI/BOOT, names the fallback's boot entry after the
#      bootloader id in BOOTX64.CSV, and passes a BIOS call through unchanged.
#   8. Checks the reserved login names: users.conf carries the BEGIN and END
#      lines and a seed with names such as operator and wireshark, and
#      config/hooks/normal/0950-snapshot-installer-reserved-names.hook.chroot
#      (mode 755, valid sh), run on a copy after adding a system user and
#      group, lists exactly this container's user and group names plus
#      autologin and changes nothing else in users.conf.
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

echo "== wireshark hook =="
# From the container's trixie (installing from the pin would mix library
# versions); the postinst logic the hook drives is the same in every trixie
# point release. Compare the two versions printed below if this ever fails.
( cd /tmp/deb && apt-get "${APT_PIN[@]}" download wireshark-common >/dev/null )
# adduser: the postinst's addgroup (the image has it; this container does not).
apt-get install -y -qq --no-install-recommends adduser wireshark-common >/dev/null
echo "info wireshark-common $(dpkg-query -W -f='${Version}' wireshark-common)" \
     "(pin: $(dpkg-deb -f /tmp/deb/wireshark-common_*.deb Version))"
hook=/snapshot/config/hooks/normal/0600-snapshot-wireshark.hook.chroot
if [ "$(stat -c %a "$hook")" = 755 ] && sh "$hook"; then
    echo "ok   ${hook#/snapshot/}"
else
    echo "FAIL ${hook#/snapshot/}"; fail=1
fi
live=/snapshot/config/includes.chroot/etc/live/config.conf.d/snapshot.conf
if python3 - "$PKG/etc/calamares/modules/users.conf" <<'PY' && grep -Eq '^LIVE_USER_DEFAULT_GROUPS=".*\<wireshark\>' "$live"
import sys, yaml
groups = yaml.safe_load(open(sys.argv[1]))["defaultGroups"]
sys.exit("wireshark" not in [g["name"] if isinstance(g, dict) else g for g in groups])
PY
then echo "ok   installed and live users are in group wireshark"
else echo "FAIL group wireshark missing from users.conf or the live-config defaults"; fail=1; fi

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

echo "== bootloader: Secure Boot wrapper =="
wrapper_path=/usr/lib/snapshot-boot/grub-install
wrapper=/snapshot/packages/snapshot-boot/rootfs$wrapper_path
python3 - "$PKG/etc/calamares/modules/bootloader.conf" "$wrapper_path" <<'PY' || fail=1
import sys, yaml
conf = yaml.safe_load(open(sys.argv[1]))
if conf.get("grubInstall") != sys.argv[2]:
    print(f"FAIL bootloader.conf grubInstall is {conf.get('grubInstall')!r}, not {sys.argv[2]!r}"); sys.exit(1)
if conf.get("installEFIFallback") is not False:
    print("FAIL bootloader.conf installEFIFallback must be false (the fallback copies GRUB over the shim)"); sys.exit(1)
print(f"ok   bootloader.conf: grubInstall {sys.argv[2]}, installEFIFallback false")
PY
if [ "$(stat -c %a "$wrapper" 2>/dev/null)" = 755 ] && sh -n "$wrapper"; then
    echo "ok   ${wrapper#/snapshot/} (mode 755, sh syntax)"
else echo "FAIL ${wrapper#/snapshot/}: missing, not mode 755 or not valid sh"; fail=1; fi
# A stub grub-install records its arguments and lays out EFI/<id> and EFI/BOOT
# the way the real one does. The wrapper puts /usr/sbin first in PATH.
cat > /usr/sbin/grub-install <<'STUB'
#!/bin/sh
printf '%s\n' "$*" > /tmp/grub-install.args
efidir= id=
for a; do case "$a" in --efi-directory=*) efidir=${a#*=} ;; --bootloader-id=*) id=${a#*=} ;; esac; done
if [ -n "$efidir" ]; then
    mkdir -p "$efidir/EFI/$id" "$efidir/EFI/BOOT"
    echo "search.fs_uuid stub root" > "$efidir/EFI/$id/grub.cfg"
    printf 'shimx64.efi,debian,,This is the boot entry for debian\n' |
        iconv -f UTF-8 -t UTF-16LE > "$efidir/EFI/$id/BOOTX64.CSV"
fi
STUB
chmod 755 /usr/sbin/grub-install
esp=/tmp/esp; mkdir -p "$esp"
efi_call="--target=x86_64-efi --efi-directory=$esp --bootloader-id=SnapshOT --force"
# shellcheck disable=SC2086
if sh "$wrapper" $efi_call >/dev/null \
   && [ "$(cat /tmp/grub-install.args)" = "--uefi-secure-boot --force-extra-removable $efi_call" ] \
   && cmp -s "$esp/EFI/SnapshOT/grub.cfg" "$esp/EFI/BOOT/grub.cfg" \
   && [ "$(iconv -f UTF-16LE -t UTF-8 "$esp/EFI/SnapshOT/BOOTX64.CSV")" = "shimx64.efi,SnapshOT,,This is the boot entry for SnapshOT" ]; then
    echo "ok   EFI call: --uefi-secure-boot --force-extra-removable added, grub.cfg copied to EFI/BOOT, fallback CSV names SnapshOT"
else
    echo "FAIL EFI call: grub-install got '$(cat /tmp/grub-install.args 2>/dev/null)'"; fail=1
fi
bios_call="--target=i386-pc --recheck --force /dev/sda"
# shellcheck disable=SC2086
if sh "$wrapper" $bios_call >/dev/null && [ "$(cat /tmp/grub-install.args)" = "$bios_call" ]; then
    echo "ok   BIOS call passed through unchanged"
else
    echo "FAIL BIOS call: grub-install got '$(cat /tmp/grub-install.args 2>/dev/null)'"; fail=1
fi
rm -f /usr/sbin/grub-install

echo "== reserved login names =="
hook=/snapshot/config/hooks/normal/0950-snapshot-installer-reserved-names.hook.chroot
if [ "$(stat -c %a "$hook" 2>/dev/null)" = 755 ] && sh -n "$hook"; then
    echo "ok   ${hook#/snapshot/} (mode 755, sh syntax)"
else echo "FAIL ${hook#/snapshot/}: missing, not mode 755 or not valid sh"; fail=1; fi
# The seed in the package: the markers once each, and names an operator might pick.
python3 - "$PKG/etc/calamares/modules/users.conf" <<'PY' || fail=1
import sys, yaml
text = open(sys.argv[1]).read()
for marker in ("# BEGIN snapshot-reserved-login-names", "# END snapshot-reserved-login-names"):
    if text.count(marker) != 1:
        print(f"FAIL users.conf: {marker!r} must appear exactly once"); sys.exit(1)
names = yaml.safe_load(text)["user"]["forbidden_names"]
missing = sorted({"operator", "wireshark", "sudo", "lightdm", "autologin"} - set(names))
if missing:
    print("FAIL users.conf forbidden_names lacks", ", ".join(missing)); sys.exit(1)
print(f"ok   users.conf seed: {len(names)} forbidden login names, markers present")
PY
# Run the hook on a copy in this container, after adding a system user and group
# the way a package postinst would: the list must become exactly the container's
# user and group names plus autologin, and nothing else in users.conf may change.
mkdir -p /etc/calamares/modules
cp "$PKG/etc/calamares/modules/users.conf" /etc/calamares/modules/users.conf
groupadd -r snapshot-test-group
useradd -r -M -N -s /usr/sbin/nologin snapshot-test-svc
if sh "$hook" && python3 - "$PKG/etc/calamares/modules/users.conf" /etc/calamares/modules/users.conf <<'PY'
import sys, yaml
seed = yaml.safe_load(open(sys.argv[1]))
out = yaml.safe_load(open(sys.argv[2]))
names = out["user"]["forbidden_names"]
accounts = {l.split(":")[0] for f in ("/etc/passwd", "/etc/group") for l in open(f) if l.strip()}
want = sorted(accounts | {"autologin"})
if names != want:
    print("FAIL hook: forbidden_names differ from the account names; extra:",
          sorted(set(names) - set(want)), "missing:", sorted(set(want) - set(names))); sys.exit(1)
if not {"snapshot-test-svc", "snapshot-test-group"} <= set(names):
    print("FAIL hook: a system user or group added before the hook is not listed"); sys.exit(1)
del seed["user"]["forbidden_names"]; del out["user"]["forbidden_names"]
if seed != out:
    print("FAIL hook: changed users.conf outside the forbidden names"); sys.exit(1)
print(f"ok   hook: {len(names)} names, exactly this container's users and groups plus autologin;"
      " the rest of users.conf unchanged")
PY
then :; else echo "FAIL ${hook#/snapshot/} run"; fail=1; fi

if [ "$fail" -ne 0 ]; then echo "== check-installer: FAIL =="; exit 1; fi
echo "== check-installer: OK =="
CONTAINER
