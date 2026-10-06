#!/usr/bin/env bash
# Checks for the SnapshOT field kit (packages/snapshot-fieldkit): the target
# collectors, the host-side prep/import tools and the package. Everything runs
# in containers, so the tools match the target.
#
#   scripts/check-fieldkit.sh
#
# Needs Docker (one privileged container, for a loop device) and network
# access (Debian mirrors, the PowerShell Gallery). It exits non-zero on any
# error:
#   1. static, in debian:trixie: shellcheck (-s sh for the Linux collector and
#      the wrappers, -s bash for the host tools), file modes, CRLF/LF line
#      ends and ASCII, guardrails (no destructive commands; every write goes
#      to the results folder) on collect-triage.cmd, Collect-Triage.ps1 and
#      collect-triage.sh, the kit layout, and dpkg-buildpackage of
#      snapshot-fieldkit with the modes in the .deb.
#   2. the Linux collector in busybox and debian:trixie, as root and as
#      nobody, quick and full: results folder, ps.tsv, sockets.tsv, run.log
#      BEGIN/END rc= lines, summary.txt keys, a MANIFEST.sha256 that verifies
#      and covers every file, and nothing written outside the results folder.
#      Plus the /proc/net decoder on a fixture, a deleted running binary and
#      a listening socket.
#   3. snapshot-fieldkit-prep on a loop device (privileged debian:trixie):
#      refuses a non-removable disk, the boot medium, the root disk and a
#      partition; prepares exFAT and FAT32; --refresh keeps results/, the
#      operator's user-supplied/ tools and files at the root, restores the kit.
#   4. snapshot-fieldkit-import as a normal user: copies, verifies, makes the
#      copy read-only, writes the import manifest and an append-only
#      chain-of-custody log; refuses root; a tampered collection is reported
#      as TAMPER, not imported, exit 1; --take-stick removes only what it
#      imported.
#   5. PowerShell, in mcr.microsoft.com/dotnet/sdk:8.0 (pwsh 7; the
#      powershell image is arm/v7 only): parse, scripts/fieldkit/ps2-lint.ps1
#      on the collector and on its own sample, PSScriptAnalyzer with the
#      PowerShell 3.0 profile (advisory, fails only on syntax), and unit tests
#      of the collector's helpers (dot-sourced with -LibOnly).
# PowerShell 2.0 itself and cmd.exe cannot run here: the Windows QA checklist
# in docs/fieldkit.md covers them, and is printed at the end.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${SNAPSHOT_TRIXIE_IMAGE:-debian:trixie}"
BUSYBOX="${SNAPSHOT_BUSYBOX_IMAGE:-busybox:latest}"
PWSH_IMAGE="${SNAPSHOT_PWSH_IMAGE:-mcr.microsoft.com/dotnet/sdk:8.0}"
KIT=packages/snapshot-fieldkit/rootfs/usr/share/snapshot/fieldkit
WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-fieldkit.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail=0
summary=()
record() {   # record <name> <rc>
    if [ "$2" -eq 0 ]; then summary+=("ok   $1"); else summary+=("FAIL $1"); fail=1; fi
}

# ---------------------------------------------------------------- 1. static
echo "== 1. static checks =="
rc=0
docker run --rm -i -v "$ROOT":/snapshot:ro "$IMAGE" bash -s <<'CONTAINER' || rc=$?
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends shellcheck debhelper dpkg-dev >/dev/null
P=/snapshot/packages/snapshot-fieldkit
K=$P/rootfs/usr/share/snapshot/fieldkit
H=$P/rootfs/usr/share/snapshot-fieldkit
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

echo "-- shellcheck"
if shellcheck -s sh -S warning "$K/linux/collect-triage.sh" "$P/rootfs/usr/bin/"*; then
    ok "shellcheck -s sh: collect-triage.sh, /usr/bin wrappers"
else bad "shellcheck -s sh"; fi
if shellcheck -s bash -S warning -x -P SCRIPTDIR "$H/snapshot-fieldkit-common.sh" \
        "$H/snapshot-fieldkit-prep" "$H/snapshot-fieldkit-import"; then
    ok "shellcheck -s bash: host tools"
else bad "shellcheck -s bash"; fi
echo "   (style notes, advisory:)"
shellcheck -s sh -S style "$K/linux/collect-triage.sh" | grep -E '^In |SC[0-9]+' | sed 's/^/     /' || true

echo "-- modes"
# Compare the mode rather than test -x: root passes -x on Docker Desktop bind
# mounts. debian/rules copies rootfs/ with cp -a, so the committed mode ships.
for f in "$P/rootfs/usr/bin/snapshot-fieldkit-prep" "$P/rootfs/usr/bin/snapshot-fieldkit-import" \
         "$H/snapshot-fieldkit-prep" "$H/snapshot-fieldkit-import" "$K/linux/collect-triage.sh"; do
    [ "$(stat -c %a "$f")" = 755 ] && ok "755 ${f#/snapshot/}" || bad "${f#/snapshot/} is not mode 755"
done
while IFS= read -r f; do
    [ "$(stat -c %a "$f")" = 644 ] || bad "${f#/snapshot/} is not mode 644"
done < <(find "$K" "$H/snapshot-fieldkit-common.sh" -type f ! -name collect-triage.sh)
ok "every other kit file is 644 (unless listed above)"

echo "-- line ends and ASCII"
while IFS= read -r f; do
    [ -s "$f" ] || continue
    perl -ne 'exit 1 unless /\r\n\z/' "$f" && ok "CRLF ${f#"$K"/}" || bad "${f#/snapshot/} must use CRLF line ends"
done < <(find "$K/windows" "$K/docs" "$K/README.txt" "$K/VERSION" -type f | sort)
for f in "$K/linux/collect-triage.sh" "$K/linux/user-supplied/README.txt" "$H"/* "$P/rootfs/usr/bin/"*; do
    if grep -q $'\r' "$f"; then bad "${f#/snapshot/} must use LF line ends"; fi
done
ok "Linux-side scripts use LF"
if find "$P" /snapshot/scripts/fieldkit -type f -print0 | xargs -0 perl -ne 'if (/[^\x00-\x7F]/) { print "$ARGV:$.\n"; $bad = 1 } close ARGV if eof; END { exit $bad }'; then
    ok "ASCII only"
else bad "non-ASCII bytes (PowerShell 2.0 reads BOM-less scripts in the ANSI code page)"; fi

echo "-- kit layout"
for f in VERSION README.txt windows/Collect-Triage.ps1 windows/collect-triage.cmd \
         windows/ics-extensions.txt windows/ics-vendors.txt windows/user-supplied/README.txt \
         windows/user-supplied/.keep linux/collect-triage.sh linux/user-supplied/README.txt \
         linux/user-supplied/.keep docs/fieldkit-guide.txt docs/ot-safety.txt \
         docs/chain-of-custody.txt results/.keep; do
    [ -e "$K/$f" ] || bad "kit file missing: $f"
done
[ "$(find "$K/results" -type f | wc -l)" = 1 ] || bad "results/ must ship with .keep only"
[ "$(grep -c '^\.' "$K/windows/ics-extensions.txt")" -ge 30 ] || bad "ics-extensions.txt looks empty"
[ "$(grep -c '^name|' "$K/windows/ics-vendors.txt")" -ge 30 ] || bad "ics-vendors.txt has too few names"
[ "$(grep -c '^dir|' "$K/windows/ics-vendors.txt")" -ge 5 ] || bad "ics-vendors.txt has too few dirs"
if grep -E '^(name|dir)\|' "$K/windows/ics-vendors.txt" | grep -q '[&|<>^"]' 2>/dev/null &&
   grep -E '^(name|dir)\|' "$K/windows/ics-vendors.txt" | cut -d'|' -f2- | grep -q '[&|<>^"]'; then
    bad "ics-vendors.txt values must not contain & | < > ^ \" (cmd.exe)"
fi
ok "kit layout"

echo "-- guardrails: collect-triage.cmd"
C=$K/windows/collect-triage.cmd
code() { tr -d '\r' < "$1" | grep -viE '^\s*(rem|::)( |$)'; }
grep -qF '"%PSEXE%" -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%~dp0Collect-Triage.ps1"' "$C" \
    && ok "launches PowerShell with -NoProfile -ExecutionPolicy Bypass" || bad "PowerShell launch line"
grep -qF 'for %%I in ("%~dp0..") do set "KIT=%%~fI"' "$C" && grep -qF 'set "OUT=%KIT%\results\%HOST%_%STAMP%"' "$C" \
    && ok "results under %~dp0..\\results" || bad "results path is not derived from %~dp0"
grep -qF 'ics-extensions.txt' "$C" && grep -qF 'ics-vendors.txt' "$C" && ok "reads ics-extensions.txt and ics-vendors.txt" || bad "ICS lists not read"
grep -qiF 'if /i "%~1"=="cmd"' "$C" && ok "has the cmd mode switch" || bad "no cmd mode switch"
grep -qF "wmic os get LocalDateTime" "$C" && grep -qF 'set "STAMPKIND=local"' "$C" && ok "UTC from wmic, stamp=local fallback" || bad "time stamp handling"
v=$(code "$C" | grep -niE '(^|[\s&(])(del|erase|rd|rmdir|format|attrib|icacls|cacls|takeown|bcdedit|vssadmin|shutdown|taskkill|diskpart|cipher|cleanmgr|defrag)(\s|$)|reg(\.exe)? +(add|delete|import|load|unload|restore|copy|save)|sc(\.exe)? +(config|stop|start|delete|create|failure|pause)|net +(stop|start)|/add\b|schtasks.*/(create|delete|change|run|end)|wevtutil +(cl|clear-log|sl|set-log|im)|\bmode +com|win32_product|win32_serialport|powershell.*-(enc|encodedcommand|command)\b|netsh [^&]*\b(set|add|delete|reset)\b' |
   grep -viE 'call BackupEventlog' || true)
v2=$(code "$C" | grep -niE 'wmic [^&]* call +[^:]' | grep -viE 'call BackupEventlog' || true)
[ -z "$v$v2" ] && ok "no destructive or state-changing commands" || { bad "forbidden commands in collect-triage.cmd:"; printf '%s\n%s\n' "$v" "$v2" | sed '/^$/d; s/^/     /'; }
# Every redirection writes to the results folder (or nul / a handle).
v=$(code "$C" | perl -ne 'while (/(?<![\^])(\d?>>?)\s*("[^"]*"|[^\s()&|]+)/g) { my $t = $2; next if $t =~ /^(nul|&\d)$/i; next if $t =~ /^"%(OUT|LOG|ERR)%/; print "$.: $t\n" }')
[ -z "$v" ] && ok "every redirection targets %OUT%, %LOG% or %ERR%" || { bad "redirection outside the results folder:"; echo "$v" | sed 's/^/     /'; }
v=$(code "$C" | grep -iE '(^|[\s&(])(mkdir|md|move|copy|xcopy|robocopy|ren|rename)\s' | grep -vE 'mkdir "%KIT%\\results"|mkdir "%OUT%"|mkdir "%OUT%\\eventlogs"|move /y "%OUT%\\MANIFEST.sha256.tmp" "%OUT%\\MANIFEST.sha256"' || true)
[ -z "$v" ] && ok "mkdir/move only inside the results folder" || { bad "file operations outside the results folder:"; echo "$v" | sed 's/^/     /'; }

echo "-- guardrails: Collect-Triage.ps1"
S=$K/windows/Collect-Triage.ps1
ps_code() { tr -d '\r' < "$1" | grep -vE '^\s*#'; }
v=$(ps_code "$S" | grep -niE '\b(Remove-Item|Remove-ItemProperty|Set-ItemProperty|New-ItemProperty|Set-Item|Clear-Item|Rename-Item|Move-Item|Copy-Item|New-Item|Out-File|Set-Content|Add-Content|Stop-Process|Stop-Service|Start-Service|Restart-Service|Suspend-Service|Set-Service|New-Service|Clear-EventLog|Limit-EventLog|Remove-EventLog|Write-EventLog|Restart-Computer|Stop-Computer|Invoke-WebRequest|Invoke-RestMethod|Invoke-Expression|Set-ExecutionPolicy|Register-ScheduledJob|Start-Process|Net\.WebClient|Win32_Product|Win32_SerialPort|DeleteSubKey|DeleteValue|SetValue|CreateSubKey|StopService|StartService|Terminate|EncodedCommand)\b|::Delete\(|\.Delete\(|OpenSubKey\([^)]*,\s*\$true' || true)
[ -z "$v" ] && ok "no destructive, network or state-changing calls" || { bad "forbidden calls in Collect-Triage.ps1:"; echo "$v" | sed 's/^/     /'; }
v=$(ps_code "$S" | grep -nE '\.Kill\(' | grep -vE '^\s*[0-9]+:\s*if \(-not \$p\.WaitForExit\(|try \{ \$p\.Kill\(\) \} catch \{ \}' || true)
[ -z "$v" ] && ok "Kill() only on its own timed-out cmd.exe" || { bad "unexpected Kill():"; echo "$v" | sed 's/^/     /'; }
# Write primitives only on paths from Get-OutPath or the results-folder variables.
v=$(ps_code "$S" | grep -nE 'Export-Csv|WriteAllText|AppendAllText|WriteAllBytes|::Move\(|CreateDirectory' |
    grep -vE 'Get-OutPath|\$script:(LogFile|ErrFile|OutDir)|\(\$p, |\(\$tmp, |\(\$dir\)' || true)
[ -z "$v" ] && ok "every write goes through Get-OutPath / the results folder" || { bad "writes not tied to the results folder:"; echo "$v" | sed 's/^/     /'; }
ps_code "$S" > /tmp/ps.txt
grep -qE '^\s+\$p = Get-OutPath \$Name$' /tmp/ps.txt && grep -qE '^\s+\$tmp = Get-OutPath ' /tmp/ps.txt && grep -qE '^\s+\$dir = Get-OutPath ' /tmp/ps.txt \
  && grep -qE "^\\\$script:OutDir = \[System\.IO\.Path\]::Combine\(\[System\.IO\.Path\]::Combine\(\\\$script:KitRoot, 'results'\)" /tmp/ps.txt \
  && grep -qE '^\$script:KitRoot = Split-Path -Parent \$script:WinDir$' /tmp/ps.txt \
  && ok "\$p/\$tmp/\$dir come from Get-OutPath; OutDir is <kit>\\results\\..." || bad "results folder derivation changed: review the write guard"

echo "-- guardrails: collect-triage.sh"
L=$K/linux/collect-triage.sh
sh_code() { grep -vE '^\s*#' "$1"; }
v=$(sh_code "$L" | grep -nE '(^|[;&|(]|\s)(kill|killall|pkill|mount|umount|modprobe|insmod|rmmod|dd|shutdown|reboot|halt|chmod|chown|chattr|setfacl|useradd|usermod|userdel|passwd|curl|wget|nc|ssh|scp|tee|iptables|nft|crontab|install)(\s|$)|sysctl +-w|systemctl +(start|stop|restart|reload|enable|disable|mask|unmask|kill|daemon-reload|set-)' || true)
[ -z "$v" ] && ok "no destructive, network or state-changing commands" || { bad "forbidden commands in collect-triage.sh:"; echo "$v" | sed 's/^/     /'; }
v=$(sh_code "$L" | grep -nE '(^|\s)rm\s' | grep -vF 'rm -f "$OUT/.step.err"' || true)
[ -z "$v" ] && ok "rm only on its own temp file in the results folder" || { bad "unexpected rm:"; echo "$v" | sed 's/^/     /'; }
# Redirections outside the awk programs must target $OUT, $LOG, /dev/null or a handle.
v=$(sh_code "$L" | perl -ne '
    $in = 1 if /\bawk\b.*'"'"'\s*$/ || /\bawk\b -[Fv].*'"'"'$/;
    if ($in) { $in = 0 if /^\s*[^'"'"']*'"'"'(\s|$)/ && !/\bawk\b/; next }
    next if /\bawk\b/;
    while (/(?<![<>=-])(\d?>>?)\s*("[^"]*"|[^\s;|&)]+)/g) {
        my $t = $2; next if $t =~ m{^(/dev/null|&\d|"\$(OUT|LOG)[/"]|"\$dest")};
        print "$.: $t\n" }')
[ -z "$v" ] && ok "every redirection targets \$OUT, \$LOG or /dev/null" || { bad "redirection outside the results folder:"; echo "$v" | sed 's/^/     /'; }
grep -qF 'dest="$OUT/logs$f"' "$L" && ok "\$dest is under \$OUT" || bad "\$dest is not derived from \$OUT"
grep -qF "KIT_DIR=\$(CDPATH='' cd -- \"\$(dirname -- \"\$0\")/..\" && pwd -P)" "$L" && grep -qF 'OUT="$KIT_DIR/results/${HOST}_${STAMP}"' "$L" \
    && ok "results under <script dir>/../results" || bad "results path is not derived from \$0"
grep -qE '^\s*(cat|show).*shadow' "$L" && bad "collect-triage.sh reads /etc/shadow contents" || ok "/etc/shadow: listing only"
sh_code "$L" | grep -qE '^\s*set\s+-[a-z]*e' && bad "collect-triage.sh must not use set -e" || ok "no set -e (fail-soft)"

echo "-- package build"
rm -rf /tmp/build && mkdir -p /tmp/build && cp -a "$P" /tmp/build/
if ( cd /tmp/build/snapshot-fieldkit && dpkg-buildpackage -b -us -uc -d >/tmp/build.log 2>&1 ); then
    deb=$(ls /tmp/build/snapshot-fieldkit_*_all.deb)
    ok "dpkg-buildpackage: ${deb##*/}"
    dpkg-deb -c "$deb" > /tmp/contents
    for f in usr/bin/snapshot-fieldkit-prep usr/bin/snapshot-fieldkit-import \
             usr/share/snapshot-fieldkit/snapshot-fieldkit-prep usr/share/snapshot-fieldkit/snapshot-fieldkit-import \
             usr/share/snapshot/fieldkit/linux/collect-triage.sh; do
        grep -qE "^-rwxr-xr-x root/root .* \./$f\$" /tmp/contents && ok "deb: $f 755" || bad "deb: $f not -rwxr-xr-x"
    done
    for f in usr/share/snapshot/fieldkit/windows/Collect-Triage.ps1 usr/share/snapshot/fieldkit/windows/collect-triage.cmd \
             usr/share/snapshot-fieldkit/snapshot-fieldkit-common.sh usr/share/snapshot/fieldkit/results/.keep; do
        grep -qE "^-rw-r--r-- root/root .* \./$f\$" /tmp/contents && ok "deb: $f 644" || bad "deb: $f not -rw-r--r--"
    done
    dpkg-deb -x "$deb" /tmp/x
    cmp -s "$K/windows/collect-triage.cmd" /tmp/x/usr/share/snapshot/fieldkit/windows/collect-triage.cmd \
        && ok "deb: collect-triage.cmd byte-identical (CRLF kept)" || bad "deb: collect-triage.cmd changed in the package"
    echo "     Depends: $(dpkg-deb -f "$deb" Depends)   Recommends: $(dpkg-deb -f "$deb" Recommends)"
else
    bad "dpkg-buildpackage failed:"; tail -30 /tmp/build.log | sed 's/^/     /'
fi
exit $fail
CONTAINER
record "1. static: shellcheck, modes, line ends, guardrails, package build" "$rc"

# ------------------------------------------------------- 2. Linux collector
echo "== 2. Linux collector =="
mkdir -p "$WORK/fixture"
# /proc/net fixtures: 0.0.0.0:502 LISTEN, 10.0.0.5:49711 -> 10.0.0.20:44818,
# [::1]:8080 LISTEN, udp 127.0.0.1:53.
cat > "$WORK/fixture/tcp" <<'EOF'
  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
   0: 00000000:01F6 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 12345 1 0000000000000000 100 0 0 10 0
   1: 0500000A:C22F 1400000A:AF12 01 00000000:00000000 02:000A7B5E 00000000  1000        0 23456 1 0000000000000000 20 4 30 10 -1
EOF
cat > "$WORK/fixture/tcp6" <<'EOF'
  sl  local_address                         remote_address                        st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
   0: 00000000000000000000000001000000:1F90 00000000000000000000000000000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 34567 1 0000000000000000 100 0 0 10 0
EOF
cat > "$WORK/fixture/udp" <<'EOF'
   sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode ref pointer drops
  100: 0100007F:0035 00000000:0000 07 00000000:00000000 00:00000000 00000000   101        0 45678 2 0000000000000000 0
EOF
printf '12345 1\n23456 2\n23456 7\n' > "$WORK/fixture/map"
printf 'tcp\t0.0.0.0:502\t0.0.0.0:0\tLISTEN\t0\t12345\t1\ntcp\t10.0.0.5:49711\t10.0.0.20:44818\tESTABLISHED\t1000\t23456\t2,7\ntcp6\t[0000:0000:0000:0000:0000:0000:0000:0001]:8080\t[0000:0000:0000:0000:0000:0000:0000:0000]:0\tLISTEN\t0\t34567\t-\nudp\t127.0.0.1:53\t0.0.0.0:0\tUNCONN\t101\t45678\t-\n' > "$WORK/fixture/expected"

rc=0
for img in "$BUSYBOX" "$IMAGE"; do
    tag=$(printf '%s' "$img" | tr -c 'a-z0-9' '_')
    if docker run --rm -v "$ROOT/$KIT":/kit:ro -v "$WORK/fixture":/fx:ro "$img" sh -c '
        SNAPSHOT_FIELDKIT_LIB=1; . /kit/linux/collect-triage.sh
        for p in tcp tcp6 udp; do decode_net $p /fx/$p /fx/map; done' > "$WORK/decode.$tag" 2>&1 &&
       diff -u "$WORK/fixture/expected" "$WORK/decode.$tag"; then
        echo "ok   $img: /proc/net decoder on the fixture"
    else echo "FAIL $img: /proc/net decoder"; cat "$WORK/decode.$tag"; rc=1; fi
    for user in 0 65534; do
        for prof in quick full; do
            run="$tag-$user-$prof"
            mkdir -p "$WORK/res/$run"; chmod 777 "$WORK/res/$run"
            # debian/root/quick first starts a binary and deletes it, and a
            # TCP listener. Then a marker: after it, nothing may change
            # outside /kit/results (the marker itself lives there).
            docker run --rm --user "$user" -v "$ROOT/$KIT":/kit:ro -v "$WORK/res/$run":/kit/results \
                -e RUN="$run" -e PROF="$prof" "$img" sh -c '
                case $RUN in debian_trixie-0-quick)
                    cp /bin/sleep /tmp/evil && /tmp/evil 600 &
                    sleep 1; rm -f /tmp/evil
                    perl -MIO::Socket::INET -e "my \$s = IO::Socket::INET->new(LocalPort => 5020, Listen => 1, ReuseAddr => 1) or die; sleep 600" &
                    sleep 1 ;;
                esac
                touch /kit/results/.marker; sleep 1
                sh /kit/linux/collect-triage.sh "$PROF" -y
                echo "--- written outside /kit/results:"
                find / -xdev \( -path /proc -o -path /sys -o -path /dev -o -path /kit \) -prune -o -newer /kit/results/.marker -print 2>/dev/null
                ' > "$WORK/res/$run.out" 2>&1 || true
        done
    done
done

docker run --rm -i -v "$WORK/res":/res:ro "$IMAGE" bash -s <<'CONTAINER' || rc=1
set -uo pipefail
fail=0
for out in /res/*.out; do
    run=${out##*/}; run=${run%.out}
    user=$(echo "$run" | awk -F- '{print $(NF-1)}'); prof=${run##*-}
    err=()
    dirs=(/res/"$run"/*_*)
    if [ "${#dirs[@]}" -ne 1 ] || [ ! -d "${dirs[0]}" ]; then
        echo "FAIL $run: expected one results folder, got: ${dirs[*]}"; sed 's/^/     /' "$out"; fail=1; continue
    fi
    c=${dirs[0]}; n=${c##*/}
    [[ $n =~ ^[A-Za-z0-9._-]+_[0-9]{8}T[0-9]{6}Z$ ]] || err+=("folder name $n")
    [ "$(head -n 1 "$c/ps.tsv" | cut -f1-3)" = $'pid\tppid\tuid' ] || err+=("ps.tsv header")
    [ "$(wc -l < "$c/ps.tsv")" -ge 2 ] || err+=("ps.tsv has no process rows")
    [ "$(head -n 1 "$c/sockets.tsv")" = $'proto\tlocal\tremote\tstate\tuid\tinode\tpids' ] || err+=("sockets.tsv header")
    grep -qE '^[0-9TZ:-]+ SnapshOT field kit .*: read-only collection to /kit/results/.*, profile '"$prof"'$' "$c/run.log" || err+=("banner not in run.log")
    grep -q 'Expected duration' "$c/run.log" || err+=("expected duration not in run.log")
    [ "$(grep -cE '^[0-9TZ:-]+ BEGIN ' "$c/run.log")" -ge 12 ] || err+=("run.log BEGIN lines")
    [ "$(grep -cE '^[0-9TZ:-]+ END +[^ ]+ rc=[0-9]+$' "$c/run.log")" = "$(grep -cE '^[0-9TZ:-]+ BEGIN ' "$c/run.log")" ] || err+=("run.log END rc= lines")
    for k in host os kernel profile start_utc end_utc stamp collector collector_version kit_version user uid is_root processes sockets hasher; do
        grep -qE "^$k=" "$c/summary.txt" || err+=("summary.txt: no $k=")
    done
    grep -qx "profile=$prof" "$c/summary.txt" || err+=("summary profile")
    if [ "$user" = 0 ]; then grep -qx is_root=1 "$c/summary.txt" || err+=("is_root"); else
        grep -qx is_root=0 "$c/summary.txt" || err+=("is_root")
        grep -q 'WARNING: not root' "$c/run.log" || err+=("no non-root warning in run.log"); fi
    for f in recent.tsv suid.txt logs-index.tsv journal.txt hashes.tsv; do
        if [ "$prof" = full ]; then [ -f "$c/$f" ] || err+=("full: $f missing")
        else [ ! -e "$c/$f" ] || err+=("quick: $f present"); fi
    done
    [ ! -e "$c/.step.err" ] || err+=(".step.err left behind")
    [ -f "$c/errors.txt" ] && [ -f "$c/collection.txt" ] || err+=("errors.txt / collection.txt")
    if [ -f "$c/MANIFEST.sha256" ]; then
        ( cd "$c" && sha256sum -c --quiet --strict MANIFEST.sha256 ) || err+=("MANIFEST.sha256 does not verify")
        listed=$(wc -l < "$c/MANIFEST.sha256")
        files=$(cd "$c" && find . -type f ! -name 'MANIFEST.sha256*' | wc -l)
        [ "$listed" = "$files" ] || err+=("MANIFEST lists $listed of $files files")
        ! grep -q 'MANIFEST' "$c/MANIFEST.sha256" || err+=("MANIFEST lists itself")
    else err+=("no MANIFEST.sha256"); fi
    outside=$(sed -n '/^--- written outside/,$p' "$out" | tail -n +2)
    [ -z "$outside" ] || err+=("wrote outside the results folder: $(echo $outside)")
    grep -q '^--- written outside' "$out" || err+=("collector run did not finish")
    if [ "$run" = debian_trixie-0-quick ]; then
        awk -F'\t' '$8 == "/tmp/evil (deleted)" && $9 == 1' "$c/ps.tsv" | grep -q . || err+=("deleted binary not flagged in ps.tsv")
        awk -F'\t' '$1 == "tcp" && $2 == "0.0.0.0:5020" && $4 == "LISTEN" && $7 ~ /^[0-9]/' "$c/sockets.tsv" | grep -q . || err+=("listener 0.0.0.0:5020 with PID not in sockets.tsv")
    fi
    if [ "${#err[@]}" -eq 0 ]; then echo "ok   $run ($(grep -c . "$c/MANIFEST.sha256") files, manifest verified)"
    else echo "FAIL $run:"; printf '     %s\n' "${err[@]}"; fail=1; fi
done
exit $fail
CONTAINER
record "2. Linux collector: busybox + trixie, root + nobody, quick + full" "$rc"

# ------------------------------------------------------------ 3. prep (loop)
echo "== 3. snapshot-fieldkit-prep on a loop device =="
rc=0
docker run --rm -i --privileged -v "$ROOT":/snapshot:ro "$IMAGE" bash -s <<'CONTAINER' || rc=$?
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends exfatprogs dosfstools fdisk jq rsync mount xorriso >/dev/null
cp -a /snapshot/packages/snapshot-fieldkit/rootfs/. /
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
truncate -s 256M /tmp/stick.img
DEV=$(losetup -f --show -P /tmp/stick.img) || { echo "FAIL losetup"; exit 1; }
trap 'umount /mnt/s 2>/dev/null; losetup -d "$DEV"' EXIT
echo "loop device: $DEV"
mkdir -p /mnt/s

# expect_refusal <message> <env...> -- <args...>
expect_refusal() {
    local msg=$1; shift
    local envs=()
    while [ "$1" != -- ]; do envs+=("$1"); shift; done; shift
    local out rc=0
    out=$(env "${envs[@]}" snapshot-fieldkit-prep "$@" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ] && grep -qF -- "$msg" <<<"$out"; then ok "refused ($msg)"
    else bad "expected refusal '$msg' (rc $rc): $out"; fi
}
expect_refusal "not a removable or USB disk" X=1 -- --device "$DEV" --yes
expect_refusal "holds the SnapshOT boot medium" SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 SNAPSHOT_FIELDKIT_TEST_BOOT_DEV="$DEV" -- --device "$DEV" --yes
expect_refusal "holds the running system's root" SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 SNAPSHOT_FIELDKIT_TEST_ROOT_DEV="$DEV" -- --device "$DEV" --yes
expect_refusal "--yes needs --device" SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 -- --yes
expect_refusal "is not a block device" SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 -- --device /dev/nonexistent --yes
expect_refusal "no terminal to confirm on" SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 -- --device "$DEV" </dev/null
# An unmounted SnapshOT live medium (booted with toram) is refused by its label.
mkdir -p /tmp/iso && echo x > /tmp/iso/x
xorriso -as mkisofs -quiet -V "SnapshOT trixie arm64" -o /tmp/live.iso /tmp/iso 2>/dev/null
ISO=$(losetup -f --show /tmp/live.iso) || bad "losetup live.iso"
expect_refusal "holds the SnapshOT boot medium" SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 -- --device "$ISO" --yes
SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 snapshot-fieldkit-prep --list | grep -qF "$ISO" && bad "--list shows the live medium" || ok "--list leaves the live medium out"
losetup -d "$ISO"
snapshot-fieldkit-prep --list | grep -qF "$DEV" && bad "--list shows a loop device" || ok "--list leaves the loop device out"
SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 snapshot-fieldkit-prep --list | grep -qF "$DEV" && ok "--list shows it with ALLOW_LOOP" || bad "--list with ALLOW_LOOP"
SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 SNAPSHOT_FIELDKIT_TEST_ROOT_DEV="$DEV" snapshot-fieldkit-prep --list | grep -qF "$DEV" \
    && bad "--list shows the root disk" || ok "--list leaves the root disk out"

check_stick() {   # check_stick <fstype> <label>
    local part=${DEV}p1 kitfiles listed
    [ "$(blkid -o value -s TYPE "$part")" = "$1" ] && ok "$1 filesystem" || bad "filesystem is $(blkid -o value -s TYPE "$part"), want $1"
    [ "$(blkid -o value -s LABEL "$part")" = "$2" ] && ok "label $2" || bad "label is $(blkid -o value -s LABEL "$part"), want $2"
    mount "$part" /mnt/s || { bad "mount $part"; return; }
    ( cd /mnt/s && sha256sum -c --quiet --strict MANIFEST.sha256 ) && ok "MANIFEST.sha256 verifies" || bad "MANIFEST.sha256 does not verify"
    kitfiles=$(cd /usr/share/snapshot/fieldkit && find . -path ./results -prune -o -type f -print | wc -l)
    listed=$(wc -l < /mnt/s/MANIFEST.sha256)
    [ "$listed" = "$kitfiles" ] && ok "manifest lists all $kitfiles kit files" || bad "manifest lists $listed, kit has $kitfiles"
    grep -q ' results/' /mnt/s/MANIFEST.sha256 && bad "manifest covers results/" || ok "manifest leaves results/ out"
    [ -d /mnt/s/results ] && ok "results/ present" || bad "results/ missing"
    for f in windows/Collect-Triage.ps1 windows/collect-triage.cmd linux/collect-triage.sh docs/ot-safety.txt; do
        cmp -s "/usr/share/snapshot/fieldkit/$f" "/mnt/s/$f" || bad "$f differs from the kit"
    done
    grep -qE $'^0\\.1\\.0 [^ ]+ [^ ]+\r$' /mnt/s/VERSION && ok "VERSION: $(tr -d '\r' < /mnt/s/VERSION)" || bad "VERSION line: $(cat -A /mnt/s/VERSION)"
}

echo "-- prepare exFAT"
if out=$(SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 snapshot-fieldkit-prep --device "$DEV" --yes 2>&1); then
    ok "prepare exFAT"; echo "$out" | sed 's/^/     /'
    check_stick exfat SNAPKIT
else bad "prepare exFAT failed: $out"; fi
umount /mnt/s 2>/dev/null
expect_refusal "not a partition" SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 -- --device "${DEV}p1" --yes

echo "-- refresh (stick not mounted)"
mount "${DEV}p1" /mnt/s
mkdir -p /mnt/s/results/HOSTA_20261006T120000Z
echo evidence > /mnt/s/results/HOSTA_20261006T120000Z/run.log
echo tool > /mnt/s/windows/user-supplied/autorunsc.exe
echo notes > /mnt/s/notes.txt
rm /mnt/s/docs/ot-safety.txt
echo stale > /mnt/s/windows/stale.txt
umount /mnt/s
if out=$(SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 snapshot-fieldkit-prep --refresh --device "$DEV" --yes 2>&1); then
    ok "refresh"
    mount "${DEV}p1" /mnt/s
    [ "$(cat /mnt/s/results/HOSTA_20261006T120000Z/run.log)" = evidence ] && ok "results/ kept" || bad "results/ lost"
    [ -f /mnt/s/windows/user-supplied/autorunsc.exe ] && ok "user-supplied tool kept" || bad "user-supplied tool removed"
    [ -f /mnt/s/notes.txt ] && ok "file at the stick root kept" || bad "file at the stick root removed"
    cmp -s /usr/share/snapshot/fieldkit/docs/ot-safety.txt /mnt/s/docs/ot-safety.txt && ok "deleted kit file restored" || bad "kit file not restored"
    [ ! -e /mnt/s/windows/stale.txt ] && ok "stale kit file removed" || bad "stale kit file kept"
    ( cd /mnt/s && sha256sum -c --quiet --strict MANIFEST.sha256 ) && ok "manifest verifies after refresh" || bad "manifest after refresh"
    grep -q ' windows/user-supplied/autorunsc.exe$' /mnt/s/MANIFEST.sha256 && ok "manifest covers user-supplied tools" || bad "manifest misses user-supplied tools"
    grep -q ' results/' /mnt/s/MANIFEST.sha256 && bad "manifest covers results/" || ok "manifest leaves results/ out"
else bad "refresh failed: $out"; fi

echo "-- refresh (stick already mounted read-write)"
rm /mnt/s/docs/fieldkit-guide.txt
if out=$(SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 snapshot-fieldkit-prep --refresh --device "$DEV" --yes 2>&1); then
    [ -f /mnt/s/docs/fieldkit-guide.txt ] && ok "refresh through the existing mount" || bad "refresh through the existing mount: file not restored"
else bad "refresh while mounted failed: $out"; fi
umount /mnt/s

echo "-- prepare FAT32 (erases the exFAT stick, including its results)"
if out=$(SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 snapshot-fieldkit-prep --device "$DEV" --fat32 --label fieldkit2 --yes 2>&1); then
    ok "prepare FAT32"
    check_stick vfat FIELDKIT2
    [ ! -e /mnt/s/results/HOSTA_20261006T120000Z ] && ok "old results erased by prepare" || bad "prepare kept old results"
    umount /mnt/s
else bad "prepare FAT32 failed: $out"; fi
exit $fail
CONTAINER
record "3. prep: loop device, refusals, exFAT, FAT32, refresh" "$rc"

# ---------------------------------------------------------------- 4. import
echo "== 4. snapshot-fieldkit-import =="
rc=0
docker run --rm -i -v "$ROOT":/snapshot:ro "$IMAGE" bash -s <<'CONTAINER' || rc=$?
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends jq >/dev/null
cp -a /snapshot/packages/snapshot-fieldkit/rootfs/. /
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
useradd -m tester
as_tester() { runuser -u tester -- "$@"; }

# A stick: the kit plus collections of every kind.
cp -r /usr/share/snapshot/fieldkit /stick
sh /stick/linux/collect-triage.sh quick -y >/dev/null 2>&1
LNX=$(basename /stick/results/*_*Z)
mkcoll() {   # mkcoll <name> <style: lf|crlf|none>
    local d=/stick/results/$1
    mkdir -p "$d/eventlogs"
    printf '\xef\xbb\xbfhost=%s\r\nstamp=%s\r\nhasher=%s\r\n' "${1%%_*}" "$3" "$4" > "$d/summary.txt"
    echo "run" > "$d/run.log"; : > "$d/errors.txt"; head -c 5000 /dev/urandom > "$d/eventlogs/Security.evtx"
    case $2 in
        lf) ( cd "$d" && find . -type f ! -name 'MANIFEST.sha256*' | sed 's|^\./||' | sort | xargs sha256sum ) > "$d/MANIFEST.sha256" ;;
        crlf) ( cd "$d" && find . -type f ! -name 'MANIFEST.sha256*' | sed 's|^\./||' | sort | xargs sha256sum ) |
              awk '{ printf "%s  %s\r\n", toupper($1), $2 }' > "$d/MANIFEST.sha256" ;;
    esac
}
mkcoll HOSTW_20261006T120000Z crlf utc ".NET SHA256CryptoServiceProvider"
mkcoll HOSTL_100620261200001L crlf local certutil
mkcoll HOSTX_20261006T130000Z none utc none
chown -R tester: /stick
export -n SNAPSHOT_CASES_DIR

echo "-- first import"
out=$(as_tester snapshot-fieldkit-import --path /stick --case CASE-1 --examiner "Test Examiner" --yes 2>&1); r=$?
echo "$out" | sed 's/^/     /'
C=/home/tester/cases/CASE-1; D=$C/fieldkit
[ "$r" = 0 ] && ok "rc 0" || bad "rc $r"
for n in "$LNX" HOSTW_20261006T120000Z HOSTL_100620261200001L HOSTX_20261006T130000Z; do
    diff -r "/stick/results/$n" "$D/$n" >/dev/null && ok "imported $n" || bad "$n not imported intact"
done
[ -z "$(find "$D" -mindepth 1 -perm /222)" ] && ok "imported copy is read-only" || bad "writable files in the case copy: $(find "$D" -mindepth 1 -perm /222 | head -3)"
im=$(ls "$D"/IMPORT-MANIFEST-*.sha256 2>/dev/null | head -n 1)
[ -n "$im" ] && ( cd "$D" && sha256sum -c --quiet --strict "${im##*/}" ) && ok "import manifest verifies" || bad "import manifest"
[ "$(wc -l < "$im")" = "$(find "$D" -mindepth 2 -type f | wc -l)" ] && ok "import manifest covers every imported file" || bad "import manifest coverage"
L=$C/chain-of-custody.log
[ -f "$L" ] && ! as_tester test -w "$L" && ok "chain-of-custody.log exists and is read-only" || bad "chain-of-custody.log missing or writable"
grep -qx 'examiner: Test Examiner' "$L" && ok "CoC: examiner" || bad "CoC: examiner"
grep -q '^operator: tester (uid ' "$L" && ok "CoC: operator" || bad "CoC: operator"
grep -q '@' "$L" && bad "CoC contains an @ (no email addresses)" || ok "CoC: no email address"
grep -q "^collection $LNX: verified files=" "$L" && ok "CoC: Linux collection verified" || bad "CoC: Linux collection"
grep -q '^collection HOSTW_20261006T120000Z: verified files=' "$L" && ok "CoC: CRLF/uppercase manifest verified" || bad "CoC: Windows-style collection"
grep -q '^collection HOSTL_100620261200001L: verified .*stamp=local' "$L" && ok "CoC: stamp=local noted" || bad "CoC: stamp=local"
grep -q '^collection HOSTX_20261006T130000Z: no-manifest .*hasher=none' "$L" && ok "CoC: no-manifest noted" || bad "CoC: no-manifest"
grep -q "^import manifest: fieldkit/${im##*/} sha256=$(sha256sum "$im" | cut -d' ' -f1)\$" "$L" && ok "CoC: import manifest hash" || bad "CoC: import manifest hash"
lines1=$(wc -l < "$L")

echo "-- second import: nothing new, log appended"
out=$(as_tester snapshot-fieldkit-import --path /stick --case CASE-1 --examiner "Test Examiner" --yes 2>&1); r=$?
[ "$r" = 0 ] && grep -q 'already imported' <<<"$out" && ok "re-import skips imported collections" || bad "re-import (rc $r): $out"
[ "$(wc -l < "$L")" -gt "$lines1" ] && [ "$(head -n "$lines1" "$L" | sha256sum)" = "$(sed -n "1,${lines1}p" "$L" | sha256sum)" ] && ! as_tester test -w "$L" \
    && ok "CoC appended and read-only again" || bad "CoC not appended"

echo "-- tamper and unlisted files"
mkcoll HOSTT_20261006T140000Z lf utc sha256sum
echo "changed" >> /stick/results/HOSTT_20261006T140000Z/run.log
mkcoll HOSTU_20261006T150000Z lf utc sha256sum
echo "added later" > /stick/results/HOSTU_20261006T150000Z/extra.txt
chown -R tester: /stick
out=$(as_tester snapshot-fieldkit-import --path /stick --case CASE-1 --examiner "Test Examiner" --yes 2>&1); r=$?
echo "$out" | sed 's/^/     /'
[ "$r" = 1 ] && ok "rc 1 on tamper" || bad "rc $r on tamper"
grep -q 'TAMPER: HOSTT_20261006T140000Z' <<<"$out" && ok "TAMPER reported" || bad "TAMPER not reported"
[ ! -e "$D/HOSTT_20261006T140000Z" ] && ok "tampered collection not imported" || bad "tampered collection imported"
grep -q '^collection HOSTT_20261006T140000Z: TAMPER, not imported' "$L" && ok "CoC: TAMPER" || bad "CoC: TAMPER"
grep -q '^result: FAILED' "$L" && ok "CoC: result FAILED" || bad "CoC: result"
grep -q '^collection HOSTU_20261006T150000Z: verified .*UNLISTED files .*extra.txt' "$L" && ok "CoC: unlisted file flagged" || bad "CoC: unlisted file"

echo "-- refusals"
out=$(snapshot-fieldkit-import --path /stick --case CASE-1 --examiner X --yes 2>&1) && bad "root accepted" || { grep -q 'not root' <<<"$out" && ok "refuses root" || bad "root refusal: $out"; }
out=$(as_tester snapshot-fieldkit-import --path /stick --case CASE-1 --yes </dev/null 2>&1) && bad "no examiner accepted" || ok "needs an examiner name"
out=$(as_tester snapshot-fieldkit-import --path /stick --case '../x' --examiner X --yes 2>&1) && bad "bad case name accepted" || ok "refuses a case name with /"

echo "-- --take-stick"
mkcoll HOSTK_20261006T160000Z lf utc sha256sum
chown -R tester: /stick
out=$(as_tester snapshot-fieldkit-import --path /stick --case CASE-1 --examiner "Test Examiner" --take-stick --yes 2>&1); r=$?
[ ! -e /stick/results/HOSTK_20261006T160000Z ] && [ -d "$D/HOSTK_20261006T160000Z" ] && ok "imported collection taken from the stick" || bad "take-stick: $out"
[ -d /stick/results/HOSTT_20261006T140000Z ] && ok "tampered collection left on the stick" || bad "tampered collection removed"
[ -d "/stick/results/$LNX" ] && ok "collections imported earlier left on the stick" || bad "earlier collections removed"
grep -q '^taken from source: HOSTK_20261006T160000Z$' "$L" && ok "CoC: taken from source" || bad "CoC: taken"
exit $fail
CONTAINER
record "4. import: verify, read-only copy, CoC, TAMPER, take-stick" "$rc"

# ------------------------------------------------------------- 5. PowerShell
echo "== 5. PowerShell (pwsh 7 in $PWSH_IMAGE) =="
rc=0
cat > "$WORK/pwsh-tests.ps1" <<'PS'
$ErrorActionPreference = 'Stop'
$kit = '/snapshot/packages/snapshot-fieldkit/rootfs/usr/share/snapshot/fieldkit'
$collector = "$kit/windows/Collect-Triage.ps1"
$lint = '/snapshot/scripts/fieldkit/ps2-lint.ps1'
$script:fails = 0
function Check([string]$Name, [bool]$Cond, [string]$Detail = '') {
    if ($Cond) { "ok   $Name" } else { "FAIL $Name $Detail"; $script:fails++ }
}

"-- parse"
$t = $null; $e = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($collector, [ref]$t, [ref]$e)
Check 'Collect-Triage.ps1 parses' ($e.Count -eq 0) (($e | ForEach-Object { "$($_.Extent.StartLineNumber): $($_.Message)" }) -join '; ')

"-- ps2-lint"
# In-process: the image's second pwsh on PATH is an x64 app host.
$out = & $lint -Path $collector 2>&1 | Out-String
$out.TrimEnd()
Check 'ps2-lint: collector is clean' ($LASTEXITCODE -eq 0 -and $out -match 'ps2-lint: OK')
$sample = '/snapshot/scripts/fieldkit/ps2-lint-sample.ps1'
$out = & $lint -Path $sample 2>&1 | Out-String
$flagged = @([regex]::Matches($out, 'ps2-lint-sample\.ps1:(\d+):') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique)
$lines = Get-Content $sample
$want = @(for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -and -not $lines[$i].TrimStart().StartsWith('#')) { $i + 1 } })
$missed = @($want | Where-Object { $flagged -notcontains $_ })
Check "ps2-lint self-test: all $($want.Count) sample lines flagged" ($missed.Count -eq 0 -and $LASTEXITCODE -ne 0) ("missed lines: " + ($missed -join ','))

"-- PSScriptAnalyzer (PowerShell 3.0 profile; advisory except syntax)"
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -ErrorAction Stop
Import-Module PSScriptAnalyzer
"     PSScriptAnalyzer $((Get-Module PSScriptAnalyzer).Version)"
$r = @(Invoke-ScriptAnalyzer -Path $collector -Settings '/snapshot/scripts/fieldkit/settings.psd1')
foreach ($x in $r) { "     advisory: $($x.RuleName) line $($x.Line): $($x.Message)" }
$syntax = @($r | Where-Object { $_.RuleName -eq 'PSUseCompatibleSyntax' })
Check "PSScriptAnalyzer: no PS 3.0 syntax findings ($($r.Count) advisory)" ($syntax.Count -eq 0)

"-- helper unit tests (dot-sourced with -LibOnly)"
. $collector -LibOnly
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('fk' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tmp)
[IO.File]::WriteAllBytes("$tmp/empty", [byte[]]@())
[IO.File]::WriteAllText("$tmp/abc", 'abc')
$rand = New-Object byte[] 3145728; (New-Object Random 7).NextBytes($rand); [IO.File]::WriteAllBytes("$tmp/rand", $rand)
foreach ($f in 'empty', 'abc', 'rand') {
    $want = ((& sha256sum "$tmp/$f") -split ' ')[0]
    Check "Get-Sha256 $f matches sha256sum" ((Get-Sha256 "$tmp/$f") -eq $want)
}
Check "hasher: $script:HasherName" ($script:HasherName -ne 'none')
Check 'Get-Sha256 of a missing file is empty' ((Get-Sha256 "$tmp/missing") -eq '')

$rows = @(ConvertFrom-Netstat -Lines (Get-Content '/snapshot/scripts/fieldkit/netstat-sample.txt') -ProcNames @{ '884' = 'svchost.exe'; '2240' = 'plc.exe' })
Check 'ConvertFrom-Netstat: 6 rows' ($rows.Count -eq 6) "got $($rows.Count)"
Check 'ConvertFrom-Netstat: TCP 502 listening, plc.exe' ($rows[1].Local -eq '0.0.0.0:502' -and $rows[1].PID -eq '2240' -and $rows[1].Process -eq 'plc.exe' -and $rows[1].Listening)
Check 'ConvertFrom-Netstat: established is not listening' ($rows[2].State -eq 'ESTABLISHED' -and -not $rows[2].Listening -and $rows[2].Remote -eq '10.0.0.20:44818')
Check 'ConvertFrom-Netstat: UDP rows, no state, PID' ($rows[4].Proto -eq 'UDP' -and $rows[4].State -eq '' -and $rows[4].PID -eq '1504' -and $rows[5].Local -eq '[fe80::1%11]:1900')
Check 'ConvertFrom-Netstat: 5 listening' (@($rows | Where-Object { $_.Listening }).Count -eq 5)

Check 'Get-UtcStamp format' ((Get-UtcStamp) -match '^\d{8}T\d{6}Z$')
Check 'Get-UtcNow format' ((Get-UtcNow) -match '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$')
Check 'Get-SafeHost' ((Get-SafeHost 'HMI 01/x&y') -eq 'HMI_01_x_y')
Check 'Get-SafeHost empty' ((Get-SafeHost '') -eq 'unknown')

$ext = @(Read-IcsExtensions -Path "$kit/windows/ics-extensions.txt")
$n = @(Get-Content "$kit/windows/ics-extensions.txt" | Where-Object { $_.StartsWith('.') }).Count
Check "Read-IcsExtensions: $($ext.Count) patterns" ($ext.Count -eq $n -and @($ext | Where-Object { -not $_.StartsWith('*.') }).Count -eq 0)
Check 'Read-IcsExtensions: s7p, acd, ap1*' (($ext -contains '*.s7p') -and ($ext -contains '*.acd') -and ($ext -contains '*.ap1*'))
$names = @(Read-IcsVendors -Path "$kit/windows/ics-vendors.txt" -Kind 'name')
$dirs = @(Read-IcsVendors -Path "$kit/windows/ics-vendors.txt" -Kind 'dir')
Check 'Read-IcsVendors: names and dirs' (($names -contains 'Siemens') -and $dirs.Count -ge 5 -and @($dirs | Where-Object { $_ -notmatch '%' }).Count -eq 0)
Check 'Test-NameMatch' ((Test-NameMatch 'SIEMENS TIA Portal V17' $names) -eq 'Siemens' -and (Test-NameMatch 'Notepad++' $names) -eq '')
Check 'Get-ImagePath quoted' ((Get-ImagePath '"C:\Program Files\X\a.exe" -k') -eq 'C:\Program Files\X\a.exe')
Check 'Get-ImagePath unquoted' ((Get-ImagePath 'C:\Windows\system32\svchost.exe -k netsvcs') -eq 'C:\Windows\system32\svchost.exe')

# Project-file walk: depth bound, file cap, symlink loops not followed.
$r0 = "$tmp/proj"
$deep = "$r0/l1/l2/l3/l4"
[void][IO.Directory]::CreateDirectory("$deep/l5")
[IO.File]::WriteAllText("$r0/top.s7p", 'x'); [IO.File]::WriteAllText("$deep/d4.acd", 'x')
[IO.File]::WriteAllText("$deep/l5/d5.acd", 'x'); [IO.File]::WriteAllText("$r0/l1/other.txt", 'x')
& ln -s $r0 "$r0/l1/loop"
$q = @(Find-ProjectFiles -Roots @($r0) -Patterns @('*.s7p', '*.acd') -MaxDepth 4 -FileCap 100 -SkipDirs @())
$qn = @($q | ForEach-Object { [IO.Path]::GetFileName($_.Path) } | Sort-Object)
Check 'Find-ProjectFiles depth 4: top.s7p, d4.acd only' (($qn -join ',') -eq 'd4.acd,top.s7p') ($qn -join ',')
$f8 = @(Find-ProjectFiles -Roots @($r0) -Patterns @('*.s7p', '*.acd') -MaxDepth 8 -FileCap 100 -SkipDirs @())
Check 'Find-ProjectFiles depth 8: 3 files, loop not followed' ($f8.Count -eq 3) "got $($f8.Count)"
$c1 = @(Find-ProjectFiles -Roots @($r0) -Patterns @('*.s7p', '*.acd') -MaxDepth 8 -FileCap 1 -SkipDirs @())
Check 'Find-ProjectFiles file cap' ($c1.Count -eq 1)
$sk = @(Find-ProjectFiles -Roots @($r0) -Patterns @('*.acd') -MaxDepth 8 -FileCap 100 -SkipDirs @("$r0/l1"))
Check 'Find-ProjectFiles skip dir' ($sk.Count -eq 0)
Check 'Find-ProjectFiles columns' ($f8[0].Path -and $f8[0].ModifiedUtc -match 'Z$' -and $f8[0].Size -eq 1)

# Results folder helpers: Export-Table, Write-Manifest (checked by sha256sum).
$script:OutDir = "$tmp/out"
[void][IO.Directory]::CreateDirectory("$tmp/out/eventlogs")
Write-Text 'run.log' "line`r`n"
[IO.File]::WriteAllBytes("$tmp/out/eventlogs/Security.evtx", $rand)
[IO.File]::WriteAllBytes("$tmp/out/empty.txt", [byte[]]@())
Export-Table 'netstat' $rows
Check 'Export-Table writes .csv and .txt' ((Test-Path "$tmp/out/netstat.csv") -and (Test-Path "$tmp/out/netstat.txt") -and ((Get-Content "$tmp/out/netstat.csv")[0] -match '"Proto","Local"'))
Check 'Export-Table counts rows' ($script:Counts['netstat'] -eq 6)
Write-Manifest
$m = [IO.File]::ReadAllText("$tmp/out/MANIFEST.sha256")
Check 'manifest: LF only, forward slashes, no self' (-not $m.Contains("`r") -and $m.Contains('  eventlogs/Security.evtx') -and -not $m.Contains('MANIFEST'))
Push-Location "$tmp/out"; $v = & sha256sum -c --strict MANIFEST.sha256 2>&1; $vrc = $LASTEXITCODE; Pop-Location
Check 'manifest verifies with sha256sum -c' ($vrc -eq 0) ($v -join '; ')
Check 'manifest lists every file' (@($m.Trim() -split "`n").Count -eq 5)

Remove-Item -Recurse -Force $tmp
if ($script:fails) { "pwsh checks: $($script:fails) failed"; exit 1 }
"pwsh checks: OK"
PS
docker run --rm -v "$ROOT":/snapshot:ro -v "$WORK/pwsh-tests.ps1":/tmp/pwsh-tests.ps1:ro "$PWSH_IMAGE" \
    pwsh -NoProfile -File /tmp/pwsh-tests.ps1 || rc=$?
record "5. PowerShell: parse, ps2-lint, PSScriptAnalyzer, helper tests" "$rc"

cat <<'EOF'

== manual Windows QA (not covered here; docs/fieldkit.md has the full list) ==
  Windows 7 (PowerShell 2.0), Windows 10/11, and XP (cmd fallback) VMs:
  - collect-triage.cmd quick and full, elevated and not: banner, Enter pause,
    one results\<HOST>_<UTC>Z folder, run.log BEGIN/END rc lines, summary.txt
  - collect-triage.cmd cmd on Windows 10: UTC stamp from wmic; XP: stamp=local
  - import the stick on SnapshOT: every collection "verified" (XP: no-manifest)
  - nothing written outside the stick (e.g. compare a file listing before/after)
EOF

echo ""
echo "== check-fieldkit summary =="
printf '%s\n' "${summary[@]}"
if [ "$fail" -ne 0 ]; then echo "== check-fieldkit: FAIL =="; exit 1; fi
echo "== check-fieldkit: OK =="
