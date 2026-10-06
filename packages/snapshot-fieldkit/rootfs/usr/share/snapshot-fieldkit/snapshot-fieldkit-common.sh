# shellcheck shell=bash
# Shared helpers for snapshot-fieldkit-prep and snapshot-fieldkit-import.
# Sourced, not run. Disk facts come from lsblk's JSON through jq.

# shellcheck disable=SC2034 # read by snapshot-fieldkit-import
FIELDKIT_TOOL_VERSION=0.1.0
FIELDKIT_SRC=/usr/share/snapshot/fieldkit
PROG=${0##*/}

utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
say() { printf '%s\n' "$*"; }
warn() { printf '%s: warning: %s\n' "$PROG" "$*" >&2; }
die() { printf '%s: %s\n' "$PROG" "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing tool: $1 (Debian package $2)"; }

# ask <prompt>: one line from the terminal into REPLY; fails without one.
ask() {
    [ -t 0 ] || die "no terminal to confirm on: run it in a terminal, or pass --yes"
    read -r -p "$1" REPLY || die "no answer"
}

# lsblk prints booleans as JSON true/false (util-linux 2.37+) or "1"/"0".
JQ_DEFS='def b: . == true or . == "1" or . == 1;'

# The disk (or loop device) that holds <dev>, through partitions, LUKS and LVM.
top_disks_of() {
    lsblk -s -n -r -p -o PATH,TYPE "$1" 2>/dev/null | awk '$2 == "disk" || $2 == "loop" { print $1 }' | sort -u
}

# Disks holding the SnapshOT boot medium (live) or the running system (root,
# /boot, /boot/efi, /usr, /var, /home, swap). SNAPSHOT_FIELDKIT_TEST_BOOT_DEV
# and SNAPSHOT_FIELDKIT_TEST_ROOT_DEV let the checks add a device to these
# lists; they can only add refusals, never remove one.
mounted_disks() {
    local m src
    for m in "$@"; do
        src=$(findmnt -n -o SOURCE --mountpoint "$m" 2>/dev/null | head -n 1) || continue
        src=${src%%\[*}
        [ -b "$src" ] && top_disks_of "$src"
    done
    return 0
}
boot_disks() {
    local d
    mounted_disks /run/live/medium /run/initramfs/live /lib/live/mount/medium
    # A SnapshOT live stick that is no longer mounted (booted with toram)
    # still counts: its ISO 9660 volume label starts with "SnapshOT".
    for d in $(blkid -t TYPE=iso9660 -o device 2>/dev/null); do
        case $(blkid -o value -s LABEL "$d" 2>/dev/null) in SnapshOT*) top_disks_of "$d" ;; esac
    done
    if [ -n "${SNAPSHOT_FIELDKIT_TEST_BOOT_DEV:-}" ]; then top_disks_of "$SNAPSHOT_FIELDKIT_TEST_BOOT_DEV"; fi
    return 0
}
root_disks() {
    local s
    mounted_disks / /boot /boot/efi /usr /var /home
    while read -r s _; do
        [ -b "$s" ] && top_disks_of "$s"
    done < <(tail -n +2 /proc/swaps 2>/dev/null)
    if [ -n "${SNAPSHOT_FIELDKIT_TEST_ROOT_DEV:-}" ]; then top_disks_of "$SNAPSHOT_FIELDKIT_TEST_ROOT_DEV"; fi
    return 0
}

# disk_field <dev> <field>: one lsblk column of the whole device.
disk_field() {
    lsblk -J -d -o NAME,PATH,TYPE,TRAN,RM,HOTPLUG,SIZE,MODEL,SERIAL,VENDOR,RO "$1" 2>/dev/null |
        jq -r ".blockdevices[0].$2 | if . == null then \"\" else tostring end"
}

# Removable candidates, one per line: path, size, transport, vendor+model,
# serial (tab-separated). USB, removable or hot-plug disks that are writable
# and hold neither the boot medium nor the running system. Loop devices only
# with SNAPSHOT_FIELDKIT_ALLOW_LOOP=1 (the checks use one as the "stick").
candidates() {
    local protected allow_loop=false
    protected=$( { boot_disks; root_disks; } | sort -u | jq -R -s 'split("\n") | map(select(length > 0))')
    [ "${SNAPSHOT_FIELDKIT_ALLOW_LOOP:-0}" = 1 ] && allow_loop=true
    lsblk -J -d -o NAME,PATH,TYPE,TRAN,RM,HOTPLUG,SIZE,MODEL,SERIAL,VENDOR,RO |
        jq -r --argjson prot "$protected" --argjson loop "$allow_loop" "$JQ_DEFS"'
            .blockdevices[]
            | select((.type == "disk" and ((.tran // "") == "usb" or (.rm | b) or (.hotplug | b)))
                     or ($loop and .type == "loop" and .size != "0B" and .size != null))
            | select((.ro | b) | not)
            | select(.path as $p | ($prot | map(select(. == $p)) | length) == 0)
            | [.path, .size, (.tran // "-"),
               (((.vendor // "") + " " + (.model // "")) | gsub("^ +| +$"; "") | if . == "" then "-" else . end),
               (.serial // "-")]
            | @tsv'
}

# check_target <dev>: refuse anything but a writable removable whole disk
# that holds neither the boot medium nor the running system.
check_target() {
    local dev=$1 type tran rm hot ro
    [ -b "$dev" ] || die "$dev is not a block device"
    dev=$(readlink -f "$dev")
    type=$(disk_field "$dev" type)
    if top_disks_of "$dev" | grep -qx -- "$dev"; then :; else
        die "refusing $dev: give the whole disk (for example /dev/sdb), not a partition"
    fi
    if boot_disks | grep -qx -- "$dev"; then
        die "refusing $dev: it holds the SnapshOT boot medium"
    fi
    if root_disks | grep -qx -- "$dev"; then
        die "refusing $dev: it holds the running system's root, boot or swap"
    fi
    tran=$(disk_field "$dev" tran); rm=$(disk_field "$dev" rm)
    hot=$(disk_field "$dev" hotplug); ro=$(disk_field "$dev" ro)
    case $type in
        disk) [ "$tran" = usb ] || [ "$rm" = true ] || [ "$rm" = 1 ] || [ "$hot" = true ] || [ "$hot" = 1 ] ||
                  die "refusing $dev: not a removable or USB disk (transport ${tran:-none}, rm $rm, hotplug $hot)" ;;
        loop) [ "${SNAPSHOT_FIELDKIT_ALLOW_LOOP:-0}" = 1 ] ||
                  die "refusing $dev: not a removable or USB disk (loop device)" ;;
        *) die "refusing $dev: not a disk (type ${type:-unknown})" ;;
    esac
    if [ "$ro" = true ] || [ "$ro" = 1 ]; then die "refusing $dev: it is read-only"; fi
    return 0
}

# first_part <disk>: path of its first partition, waiting for the node.
first_part() {
    local dev=$1 p i maj min
    for i in $(seq 1 20); do
        p=$(lsblk -n -r -p -o PATH,TYPE "$dev" 2>/dev/null | awk '$2 == "part" { print $1; exit }')
        if [ -n "$p" ] && [ -b "$p" ]; then echo "$p"; return 0; fi
        # Without udev (containers) the node never appears: make it from sysfs.
        if [ -n "$p" ] && [ ! -e "$p" ] && [ -r "/sys/class/block/${p##*/}/dev" ]; then
            IFS=: read -r maj min < "/sys/class/block/${p##*/}/dev"
            mknod "$p" b "$maj" "$min" && { echo "$p"; return 0; }
        fi
        [ "$i" -lt 20 ] && sleep 0.5
    done
    return 1
}

# Kit version line for the stick: "<kit-version> <git-short> <build-date>".
kit_version_line() {
    local ver git=unknown built=unknown SNAPSHOT_GIT='' SNAPSHOT_SOURCE_DATE_EPOCH=''
    ver=$(head -n 1 "$FIELDKIT_SRC/VERSION" | tr -d '\r' | awk '{ print $1 }')
    if [ -r /etc/snapshot-release ]; then
        # shellcheck disable=SC1091
        . /etc/snapshot-release
        git=${SNAPSHOT_GIT:-unknown}
        [ -n "$SNAPSHOT_SOURCE_DATE_EPOCH" ] && built=$(date -u -d "@$SNAPSHOT_SOURCE_DATE_EPOCH" +%Y-%m-%d)
    fi
    printf '%s %s %s' "${ver:-unknown}" "$git" "$built"
}

# write_kit_manifest <kit root>: MANIFEST.sha256 over the kit, not results/
# and not what Windows or desktops add at the root.
write_kit_manifest() {
    local root=$1
    ( cd "$root" &&
      find . \( -path ./results -o -path './System Volume Information' -o -path './$RECYCLE.BIN' \
                -o -path './.Trash-*' -o -path ./.fseventsd -o -path ./.Spotlight-V100 \) -prune \
             -o -type f ! -name 'MANIFEST.sha256*' -print |
      sed 's|^\./||' | LC_ALL=C sort |
      while IFS= read -r f; do sha256sum -- "$f"; done ) > "$root/MANIFEST.sha256.tmp"
    mv "$root/MANIFEST.sha256.tmp" "$root/MANIFEST.sha256"
}
