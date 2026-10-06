#!/bin/sh
# SnapshOT field kit: read-only triage collector for Linux targets.
#
#   sh /path/to/kit/linux/collect-triage.sh [quick|full] [-y]
#
# POSIX sh and BusyBox-safe (ash and its applets); runs as root or as a normal
# user (non-root sees less and says so). It reads the target and writes only
# to <kit>/results/<HOST>_<UTCSTAMP>/ beside this script: no network, no
# installs, no changes to the target. Every step is fail-soft and logged with
# its rc in run.log; stderr goes to errors.txt. docs/fieldkit-guide.txt lists
# what each step collects.
#
#   quick (default)  processes, sockets, network, users, persistence, modules,
#                    mounts, packages, serial ports. About 1 to 3 minutes.
#   full             quick, plus recent files, SUID files, a capped copy of
#                    /var/log, the journal and SHA-256 of running binaries.
#
# -y skips the profile prompt and the "press Enter" pause (also skipped when
# stdin is not a terminal). Do not run it with "set -e" semantics: a failing
# step must not stop the collection.
umask 077
LC_ALL=C; export LC_ALL
# System directories first, so a planted tool earlier in PATH is not used.
PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH; export PATH
PAGER='cat'; SYSTEMD_PAGER=''; export PAGER SYSTEMD_PAGER

COLLECTOR_VERSION=0.1.0
RECENT_DAYS=14          # full: files modified in the last N days
RECENT_MAX=5000         # full: cap on listed recent files
LOG_FILE_CAP=20971520   # full: per-file cap on copied logs (20 MiB, tail kept)
LOG_TOTAL_CAP=209715200 # full: total cap on copied logs (200 MiB)

have() { command -v "$1" >/dev/null 2>&1; }
# A real tool, not a BusyBox applet (BusyBox rpm/dpkg install, never query).
have_real() {
    have "$1" || return 1
    case $(readlink -f "$(command -v "$1")" 2>/dev/null) in */busybox) return 1 ;; esac
    return 0
}
utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

usage() {
    echo "usage: sh collect-triage.sh [quick|full] [-y]"
}

log() { printf '%s %s\n' "$(utc)" "$*" >> "$LOG"; }

# run <outfile> <cmd...>: run one step; never abort; record rc. The step's
# stderr is appended to errors.txt, each line tagged with the step name.
run() {
    _o=$1; shift
    log "BEGIN $_o :: $*"
    "$@" > "$OUT/$_o" 2> "$OUT/.step.err"; _rc=$?
    note_errors "$_o"
    [ "$_rc" -eq 0 ] || STEPS_NONZERO=$((STEPS_NONZERO + 1))
    log "END   $_o rc=$_rc"
    return 0
}
# runsh <outfile> <shell snippet>: the same for a snippet, in a subshell.
runsh() {
    _o=$1; shift
    log "BEGIN $_o :: sh -c $1"
    ( eval "$1" ) > "$OUT/$_o" 2> "$OUT/.step.err"; _rc=$?
    note_errors "$_o"
    [ "$_rc" -eq 0 ] || STEPS_NONZERO=$((STEPS_NONZERO + 1))
    log "END   $_o rc=$_rc"
    return 0
}
note_errors() {
    if [ -s "$OUT/.step.err" ]; then
        sed "s|^|[$1] |" "$OUT/.step.err" >> "$OUT/errors.txt"
    fi
    : > "$OUT/.step.err"
}
section() { printf '\n== %s\n' "$*"; }
# show <file...>: print each readable file under a heading.
show() {
    for _f in "$@"; do
        [ -e "$_f" ] || continue
        section "$_f"
        cat "$_f"
    done
}

# --- processes -----------------------------------------------------------
ps_proc() {
    printf 'pid\tppid\tuid\tuser\tstate\tstart_ticks\tcomm\texe\texe_deleted\tcwd\tcmdline\n'
    for d in /proc/[0-9]*; do
        pid=${d#/proc/}
        [ -r "$d/stat" ] || continue
        st=$(cat "$d/stat" 2>/dev/null) || continue
        # comm may contain spaces/parens: strip through the LAST ')'
        comm=${st#*(}; comm=${comm%)*}
        rest=${st##*) }
        # shellcheck disable=SC2086 # split the numeric stat fields on purpose
        set -- $rest
        state=$1; ppid=$2
        shift 19 2>/dev/null; start=${1:-}
        uid=$(sed -n 's/^Uid:[[:space:]]*\([0-9]*\).*/\1/p' "$d/status" 2>/dev/null)
        user=$(awk -F: -v u="$uid" '$3==u{print $1; exit}' /etc/passwd 2>/dev/null)
        exe=$(readlink "$d/exe" 2>/dev/null)
        del=0; case $exe in *" (deleted)") del=1;; esac
        cwd=$(readlink "$d/cwd" 2>/dev/null)
        cmd=$(tr '\000\t\n' '   ' < "$d/cmdline" 2>/dev/null)
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$pid" "$ppid" "$uid" "$user" "$state" "$start" "$comm" "$exe" "$del" "$cwd" "$cmd" | tr -d '\r'
    done
}

# --- sockets -------------------------------------------------------------
# socket inode -> pid map from /proc/*/fd
sock_map() {
    for f in /proc/[0-9]*/fd/*; do
        l=$(readlink "$f" 2>/dev/null) || continue
        case $l in socket:\[*\]) i=${l#socket:[}; i=${i%]}; p=${f#/proc/}; printf '%s %s\n' "$i" "${p%%/*}";; esac
    done
}

decode_net() {
    # $1 = proto label, $2 = /proc/net file, $3 = sockmap file
    awk -v proto="$1" -v map="$3" '
    function hex(s,   i,n,c){ n=0; s=toupper(s); for(i=1;i<=length(s);i++){ c=index("0123456789ABCDEF",substr(s,i,1))-1; n=n*16+c }; return n }
    function ip4(h){ return hex(substr(h,7,2)) "." hex(substr(h,5,2)) "." hex(substr(h,3,2)) "." hex(substr(h,1,2)) }
    function ip6(h,   w,i,j,o,out){ out=""; for(w=0;w<4;w++){ o=substr(h,w*8+1,8); for(j=7;j>=1;j-=2) out=out substr(o,j,2) } ;
        h=tolower(out); out=""; for(i=0;i<8;i++){ out=out (i?":":"") substr(h,i*4+1,4) }; return out }
    function addr(a,  p,h){ split(a,p,":"); h=p[1]; return (length(h)==8?ip4(h):"[" ip6(h) "]") ":" hex(p[2]) }
    BEGIN{ split("ESTABLISHED SYN_SENT SYN_RECV FIN_WAIT1 FIN_WAIT2 TIME_WAIT CLOSE CLOSE_WAIT LAST_ACK LISTEN CLOSING NEW_SYN_RECV",S," ");
           while((getline l < map)>0){ split(l,m," "); if (m[1] in P) P[m[1]]=P[m[1]] "," m[2]; else P[m[1]]=m[2] } }
    NR>1 { st=hex($4); s=(proto ~ /^udp/ && st==7)?"UNCONN":S[st]; print proto "\t" addr($2) "\t" addr($3) "\t" s "\t" $8 "\t" $10 "\t" ((($10) in P)?P[$10]:"-") }
    ' "$2"
}

sockets() {
    printf 'proto\tlocal\tremote\tstate\tuid\tinode\tpids\n'
    for p in tcp tcp6 udp udp6; do
        [ -r "/proc/net/$p" ] && decode_net "$p" "/proc/net/$p" "$OUT/sockmap.txt"
    done
    return 0
}

sockets_raw() {
    if have ss; then section "ss -tulpane"; ss -tulpane
    elif have netstat; then section "netstat -tulpan"; netstat -tulpan
    else echo "(no ss or netstat on this host; sockets.tsv is decoded from /proc)"
    fi
}

# --- network, system, users ----------------------------------------------
net_info() {
    if have ip; then
        section "ip addr"; ip addr
        section "ip route"; ip route
        section "ip -6 route"; ip -6 route
        section "ip neigh"; ip neigh
    else
        section "ifconfig -a"; ifconfig -a
        section "route -n"; route -n
    fi
    show /proc/net/arp /proc/net/route /etc/resolv.conf /etc/hosts /etc/hostname \
        /etc/network/interfaces /etc/sysconfig/network
    for f in /etc/network/interfaces.d/* /etc/NetworkManager/system-connections/* \
             /etc/systemd/network/* /etc/netplan/*; do
        [ -f "$f" ] || continue
        section "$f (listing only)"; ls -ln "$f"
    done
    if [ -r /proc/net/dev ]; then section /proc/net/dev; cat /proc/net/dev; fi
}

system_info() {
    section "uname -a"; uname -a
    section "hostname"; hostname 2>/dev/null || cat /proc/sys/kernel/hostname
    section "date -u"; date -u
    section "date (local)"; date
    section "timezone"; cat /etc/timezone 2>/dev/null; readlink /etc/localtime 2>/dev/null
    section "uptime"; uptime; cat /proc/uptime
    section "boot time (btime) and clock ticks"; grep '^btime' /proc/stat; getconf CLK_TCK 2>/dev/null
    show /etc/os-release /usr/lib/os-release /etc/issue /etc/debian_version /etc/redhat-release \
        /etc/alpine-release /etc/openwrt_release /etc/version /proc/version /proc/cmdline
    section "id"; id
    show /proc/cpuinfo /proc/meminfo
}

users_info() {
    show /etc/passwd /etc/group
    # Credential hashes are out of scope: presence and permissions only.
    section "/etc/shadow, /etc/gshadow (presence and permissions only)"
    ls -ln /etc/shadow /etc/gshadow 2>&1
    show /etc/sudoers
    for f in /etc/sudoers.d/*; do [ -f "$f" ] && show "$f"; done
    if have who; then section who; who; fi
    if have w; then section w; w; fi
    if have last; then section "last -n 200"; last -n 200 2>/dev/null || last; fi
    if have lastlog; then section lastlog; lastlog; fi
    section "login records (presence)"; ls -ln /var/log/wtmp /var/log/btmp /var/log/lastlog /var/run/utmp 2>&1
    section "home directories"; ls -lan /home /root 2>&1
}

persistence_info() {
    show /etc/crontab /etc/anacrontab
    for f in /etc/cron.d/* /etc/cron.hourly/* /etc/cron.daily/* /etc/cron.weekly/* \
             /etc/cron.monthly/* /var/spool/cron/* /var/spool/cron/crontabs/* \
             /etc/crontabs/*; do
        [ -f "$f" ] && show "$f"
    done
    if have systemctl; then
        section "systemctl list-unit-files"; systemctl list-unit-files --no-pager
        section "systemctl list-units --all"; systemctl list-units --all --no-pager
        section "systemctl list-timers --all"; systemctl list-timers --all --no-pager
    fi
    for d in /etc/systemd/system /etc/systemd/user /run/systemd/system /lib/systemd/system \
             /usr/lib/systemd/system /etc/init.d /etc/rc.d /etc/rcS.d /etc/rc2.d /etc/rc3.d \
             /etc/rc5.d /etc/init /etc/xdg/autostart; do
        [ -d "$d" ] || continue
        section "$d (listing)"; ls -lanR "$d"
    done
    show /etc/rc.local /etc/rc.d/rc.local /etc/inittab /etc/ld.so.preload /etc/ld.so.conf \
        /etc/profile /etc/bash.bashrc /etc/environment
    for d in /etc/profile.d /etc/ld.so.conf.d; do
        [ -d "$d" ] && { section "$d (listing)"; ls -lan "$d"; }
    done
    section "shell start-up files in home directories (listing)"
    for h in /root /home/*; do
        for f in .profile .bashrc .bash_profile .bash_login .bash_logout .zshrc .config/autostart; do
            [ -e "$h/$f" ] && ls -lnd "$h/$f"
        done
    done
    # Key material stays on the target: paths and mtimes only.
    section "authorized_keys (listing only)"
    for h in /root /home/*; do
        for f in "$h/.ssh/authorized_keys" "$h/.ssh/authorized_keys2"; do
            [ -e "$f" ] && ls -ln "$f"
        done
    done
    return 0
}

kernel_info() {
    if have lsmod; then section lsmod; lsmod; else show /proc/modules; fi
    show /proc/mounts /proc/swaps /proc/partitions /etc/fstab
    section "df"; df -h 2>/dev/null || df
    if have lsblk; then section lsblk; lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,MOUNTPOINT 2>/dev/null || lsblk; fi
    if have lsusb; then section lsusb; lsusb; fi
    if have lspci; then section lspci; lspci; fi
    if have dmesg; then section dmesg; dmesg; fi
}

packages_info() {
    if have dpkg-query; then section "dpkg-query"; dpkg-query -W -f '${Status}\t${Package}\t${Version}\t${Architecture}\n'; fi
    if have_real rpm; then section "rpm -qa"; rpm -qa; fi
    if have_real opkg; then section "opkg list-installed"; opkg list-installed; fi
    if have_real apk; then section "apk info -v"; apk info -v; fi
    if have snap; then section "snap list"; snap list; fi
    if have flatpak; then section "flatpak list"; flatpak list; fi
    section "/opt and /usr/local (listing)"; ls -lan /opt /usr/local /usr/local/bin /usr/local/sbin 2>&1
    return 0
}

# Serial ports, listed without opening them (opening a port can toggle
# DTR/RTS and reset attached equipment).
ot_serial() {
    section "serial device nodes"
    ls -ln /dev/ttyS* /dev/ttyUSB* /dev/ttyACM* /dev/ttyAMA* /dev/ttymxc* /dev/ttyO* 2>/dev/null
    for d in /dev/serial/by-id /dev/serial/by-path; do
        [ -d "$d" ] && { section "$d"; ls -ln "$d"; }
    done
    show /proc/tty/drivers
    [ -r /proc/tty/driver/serial ] && show /proc/tty/driver/serial
    return 0
}

# --- full profile ------------------------------------------------------------
recent_files() {
    printf 'mtime_utc\tsize\tpath\n'
    find /etc /usr/local /opt /srv /tmp /var/tmp /dev/shm /home /root /var/www \
        -xdev -type f -mtime -"$RECENT_DAYS" 2>/dev/null | head -n "$RECENT_MAX" |
    while IFS= read -r f; do
        printf '%s\t%s\t%s\n' "$(date -u -r "$f" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" \
            "$(ls -ln "$f" 2>/dev/null | awk '{print $5}')" "$f"
    done
}

suid_files() {
    find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | head -n "$RECENT_MAX" |
    while IFS= read -r f; do ls -ln "$f"; done
}

copy_logs() {
    mkdir -p "$OUT/logs" || return 1
    printf 'path\tsize\tcopied\tmtime_utc\n'
    total=0
    find /var/log -xdev -path /var/log/journal -prune -o -type f -print 2>/dev/null | sort |
    while IFS= read -r f; do
        [ -r "$f" ] || continue
        [ "$total" -lt "$LOG_TOTAL_CAP" ] || { printf '%s\t-\t0\t-\t(total cap reached)\n' "$f"; continue; }
        size=$(ls -ln "$f" 2>/dev/null | awk '{print $5}'); size=${size:-0}
        dest="$OUT/logs$f"
        mkdir -p "$(dirname "$dest")" || continue
        if [ "$size" -gt "$LOG_FILE_CAP" ]; then
            tail -c "$LOG_FILE_CAP" "$f" > "$dest"; copied=$LOG_FILE_CAP
        else
            cat "$f" > "$dest"; copied=$size
        fi
        total=$((total + copied))
        printf '%s\t%s\t%s\t%s\n' "$f" "$size" "$copied" "$(date -u -r "$f" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
    done
}

journal() {
    have journalctl || { echo "(no journalctl)"; return 0; }
    journalctl --no-pager -q -o short-iso -n 50000
}

exe_hashes() {
    [ -n "$HASHER" ] || { echo "(no SHA-256 tool on this host)"; return 1; }
    printf 'sha256\texe\tpids\n'
    for d in /proc/[0-9]*; do
        e=$(readlink "$d/exe" 2>/dev/null) || continue
        printf '%s\t%s\n' "$e" "${d#/proc/}"
    done | sort | awk -F'\t' '
        $1 != prev { if (prev != "") print first "\t" prev "\t" pids; prev = $1; first = $2; pids = $2; next }
        { pids = pids "," $2 }
        END { if (prev != "") print first "\t" prev "\t" pids }' |
    while IFS="$TAB" read -r pid exe pids; do
        # Hash through /proc/<pid>/exe: works for deleted binaries too.
        # shellcheck disable=SC2086 # HASHER is a command with arguments
        h=$($HASHER "/proc/$pid/exe" 2>/dev/null | cut -d' ' -f1)
        printf '%s\t%s\t%s\n' "${h:--}" "$exe" "$pids"
    done
}

user_supplied() {
    us="$KIT_DIR/linux/user-supplied"
    echo "User-supplied tools are listed here, not run automatically."
    ls -lan "$us" 2>&1
}

# Pick a SHA-256 tool; empty when the host has none.
pick_hasher() {
    for h in sha256sum "busybox sha256sum" "openssl dgst -sha256 -r"; do
        # shellcheck disable=SC2086 # split the candidate into command + args
        set -- $h
        if have "$1" && { [ "$1" != busybox ] || busybox sha256sum </dev/null >/dev/null 2>&1; }; then
            echo "$h"; return 0
        fi
    done
    return 0
}

# Lets the checks source this file for its functions without collecting.
if [ "${SNAPSHOT_FIELDKIT_LIB:-0}" = 1 ]; then return 0 2>/dev/null || exit 0; fi

# --- main ------------------------------------------------------------------
MODE=; ASSUME_YES=0
for a in "$@"; do
    case $a in
        quick|full) MODE=$a ;;
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "collect-triage.sh: unknown argument: $a" >&2; usage >&2; exit 2 ;;
    esac
done
INTERACTIVE=0
[ "$ASSUME_YES" = 0 ] && [ -t 0 ] && INTERACTIVE=1
if [ -z "$MODE" ]; then
    MODE=quick
    if [ "$INTERACTIVE" = 1 ]; then
        printf 'Profile: quick (low impact) or full? [quick] '
        read -r ans || exit 1
        case $ans in full|FULL|f|F) MODE=full ;; esac
    fi
fi

# The kit root comes from this script's own location, never the cwd.
KIT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P) || { echo "cannot find the kit root" >&2; exit 1; }
KIT_VERSION=$(sed -n '1p' "$KIT_DIR/VERSION" 2>/dev/null | tr -d '\r')
HOST=$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null || echo unknown)
HOST=$(printf '%s' "$HOST" | tr -c 'A-Za-z0-9._-' '_')
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT="$KIT_DIR/results/${HOST}_${STAMP}"
TAB=$(printf '\t')
case $MODE in
    quick) EXPECT="about 1 to 3 minutes" ;;
    full)  EXPECT="about 5 to 30 minutes (longer with large logs or many files)" ;;
esac
banner() {
    printf 'SnapshOT field kit %s: read-only collection to %s, profile %s\n' "${KIT_VERSION:-unknown}" "$OUT" "$MODE"
    printf 'Expected duration: %s.\n' "$EXPECT"
}
banner
if [ "$INTERACTIVE" = 1 ]; then
    printf 'Press Enter to start, or Ctrl+C to abort. '
    read -r _ || exit 1
fi

mkdir -p "$KIT_DIR/results" && mkdir "$OUT" || { echo "cannot create $OUT" >&2; exit 1; }
LOG="$OUT/run.log"
: > "$OUT/errors.txt"
START_UTC=$(utc)
STEPS_NONZERO=0
banner | while IFS= read -r l; do log "$l"; done
log "collector=collect-triage.sh version=$COLLECTOR_VERSION kit=$KIT_DIR"
log "footprint: reads update access times where the filesystem allows (relatime);"
log "footprint: the shell that started this collector may keep its own history."

UID_NOW=$(id -u 2>/dev/null || sed -n 's/^Uid:[[:space:]]*\([0-9]*\).*/\1/p' /proc/self/status)
USER_NOW=$(id -un 2>/dev/null || echo "uid$UID_NOW")
IS_ROOT=0; [ "$UID_NOW" = 0 ] && IS_ROOT=1
if [ "$IS_ROOT" = 0 ]; then
    msg="WARNING: not root (uid $UID_NOW): other users' process details, sockets' owning PIDs and protected files are not visible."
    echo "$msg" >&2
    log "$msg"
fi
HASHER=$(pick_hasher)
log "hasher: ${HASHER:-none}"

# Most volatile first.
run ps.tsv ps_proc
runsh ps-raw.txt 'ps auxww 2>/dev/null || ps -ef 2>/dev/null || ps'
run sockmap.txt sock_map
run sockets.tsv sockets
run sockets-raw.txt sockets_raw
runsh unix-sockets.txt 'cat /proc/net/unix'
run net.txt net_info
run system.txt system_info
run users.txt users_info
run persistence.txt persistence_info
run kernel.txt kernel_info
run packages.txt packages_info
run ot-serial.txt ot_serial
if [ "$MODE" = full ]; then
    run recent.tsv recent_files
    run suid.txt suid_files
    run logs-index.tsv copy_logs
    run journal.txt journal
    run hashes.tsv exe_hashes
fi
run user-supplied.txt user_supplied
rm -f "$OUT/.step.err"

PROCS=$(($(wc -l < "$OUT/ps.tsv") - 1))
SOCKS=$(($(wc -l < "$OUT/sockets.tsv") - 1))
LISTEN=$(awk -F'\t' '$4=="LISTEN"' "$OUT/sockets.tsv" | wc -l | tr -d ' ')
OS=$(sed -n 's/^PRETTY_NAME="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' /etc/os-release 2>/dev/null)
END_UTC=$(utc)
{
    echo "host=$HOST"
    echo "os=${OS:-unknown}"
    echo "kernel=$(uname -r)"
    echo "arch=$(uname -m)"
    echo "profile=$MODE"
    echo "start_utc=$START_UTC"
    echo "end_utc=$END_UTC"
    echo "stamp=utc"
    echo "collector=collect-triage.sh"
    echo "collector_version=$COLLECTOR_VERSION"
    echo "kit_version=${KIT_VERSION:-unknown}"
    echo "user=$USER_NOW"
    echo "uid=$UID_NOW"
    echo "is_root=$IS_ROOT"
    echo "processes=$PROCS"
    echo "sockets=$SOCKS"
    echo "listening=$LISTEN"
    echo "steps_nonzero=$STEPS_NONZERO"
    echo "hasher=${HASHER:-none}"
} > "$OUT/summary.txt"
log "summary.txt written; collection.txt and MANIFEST.sha256 follow (not logged after this line)"

( cd "$OUT" && find . -type f ! -name 'MANIFEST.sha256*' ! -name collection.txt | sort |
  while IFS= read -r f; do printf '%s\t%s\n' "$(ls -ln "$f" | awk '{print $5}')" "${f#./}"; done ) > "$OUT/collection.txt"
if [ -n "$HASHER" ]; then
    # shellcheck disable=SC2086 # HASHER is a command with arguments
    ( cd "$OUT" && find . -type f ! -name 'MANIFEST.sha256*' | sort |
      while IFS= read -r f; do $HASHER "${f#./}"; done ) > "$OUT/MANIFEST.sha256.tmp" 2>/dev/null &&
    mv "$OUT/MANIFEST.sha256.tmp" "$OUT/MANIFEST.sha256"
fi
echo "Done: $OUT"
[ -n "$HASHER" ] || echo "No SHA-256 tool on this host: no MANIFEST.sha256; the import manifest covers integrity from the stick on."
exit 0
