# SnapshOT field kit

The field kit is a USB stick of read-only triage collectors for the Windows and
Linux hosts met on an OT engagement. The SnapshOT laptop prepares the stick, the
operator runs a collector on each target, and the results come back into a case
folder with hash checks and a chain-of-custody log.

It lives in two packages:

- `packages/snapshot-fieldkit`: the kit itself under
  `/usr/share/snapshot/fieldkit/` (collectors, ICS lists, printable docs) and the
  host tools `snapshot-fieldkit-prep` and `snapshot-fieldkit-import`
  (implementation in `/usr/share/snapshot-fieldkit/`, wrappers in `/usr/bin`).
- `packages/snapshot-menu`: the launchers in **06 - Host Forensics**:
  *Prepare Field Kit USB*, *Import Field Kit results* (both in a terminal),
  *Field Kit folder* and *Field Kit guide*, next to The Sleuth Kit.

SnapshOT ships only its own scripts. Sysinternals and KAPE may not be
redistributed; the operator drops them into `windows/user-supplied/`.

## Workflow

```
SnapshOT laptop                    target host                     SnapshOT laptop
snapshot-fieldkit-prep  ──stick──▶ collect-triage.cmd / .sh ──stick──▶ snapshot-fieldkit-import
(erase, exFAT, kit,                (read-only; writes only            (verify, copy, read-only,
 MANIFEST.sha256)                   results/<HOST>_<UTC>/)             import manifest, CoC log)
```

### Prepare

```sh
snapshot-fieldkit-prep                   # pick the stick from a list, type its name, type ERASE
snapshot-fieldkit-prep --fat32           # FAT32 instead of exFAT (bare XP hosts; 4 GiB file limit)
snapshot-fieldkit-prep --refresh         # update the kit on a prepared stick; keeps results/
snapshot-fieldkit-prep --list            # removable disks it would offer
```

It runs as root (it re-runs itself with sudo; the live user needs no password,
the installed user is asked). It lists only USB, removable or hot-plug disks, and
refuses, whatever `--device` says, the disk holding the SnapshOT boot medium
(`/run/live/medium`), the disk holding the running system (`/`, `/boot`,
`/boot/efi`, `/usr`, `/var`, `/home`, swap; through LUKS and LVM), a partition
instead of a whole disk, and any non-removable disk. The operator types the
device name (`sdb`) to pick it and `ERASE` to confirm; `--yes --device /dev/sdX`
skips both prompts.

Prepare writes one MBR partition, exFAT (default) or FAT32, label `SNAPKIT`,
copies the kit, writes `VERSION` (`<kit version> <build commit> <build date>`)
and `MANIFEST.sha256` over every kit file except `results/`. exFAT has no 4 GiB
file limit; Windows XP reads it only with KB955704, so use `--fat32` for bare XP.

`--refresh` rewrites the kit files and the manifest, removes stale kit files, and
keeps `results/`, anything in `*/user-supplied/` and anything else at the stick
root. The manifest then covers the operator's user-supplied tools too.

### Collect

On Windows (XP to 11), from an elevated command prompt for the full picture:

```bat
E:\windows\collect-triage.cmd            :: asks quick or full
E:\windows\collect-triage.cmd full -y    :: no prompts
E:\windows\collect-triage.cmd cmd        :: built-in tools only, even with PowerShell
```

The `.cmd` starts `Collect-Triage.ps1` with `-NoProfile -ExecutionPolicy Bypass`
when PowerShell exists (64-bit through `Sysnative` from a 32-bit prompt). Without
PowerShell, or with `cmd`, it runs its own built-in-only collection. If policy
blocks the PowerShell collector, the launcher says so and suggests `cmd`; it
never falls back on its own, so a fragile host is not collected twice.

On Linux (any distribution, BusyBox included):

```sh
sudo sh /media/<user>/SNAPKIT/linux/collect-triage.sh [quick|full] [-y]
```

Every collector prints a banner (`SnapshOT field kit <version>: read-only
collection to <results path>, profile <p>` and the expected duration), logs it,
and waits for Enter so the operator can abort on a fragile host (`-y`, or no
terminal, skips the wait).

### Import

```sh
snapshot-fieldkit-import --case ACME-2026-10 --examiner "Jane Doe"
snapshot-fieldkit-import --path /some/copy/of/the/stick --case ACME-2026-10
snapshot-fieldkit-import --case ACME-2026-10 --take-stick   # then clear imported results off the stick
```

The import runs as the operator, never as root. It uses the stick where it is
already mounted, or mounts it read-only with `udisksctl mount -o ro` (udisks2 is
in the image for this) and unmounts it again afterwards; by default it writes
nothing to the stick. For each `results/<HOST>_<STAMP>/`:

1. If the collection has a `MANIFEST.sha256`, it is checked in place (CRLF and
   upper-case hex from Windows are fine). A mismatch or missing file prints a
   **TAMPER** banner; that collection is not imported, stays on the stick, and the
   run exits 1. Files present but not in the manifest are imported and flagged
   `UNLISTED` in the log. No manifest (the XP fallback has no hasher) is recorded
   as `no-manifest`.
2. It is copied to `~/cases/<case>/fieldkit/<HOST>_<STAMP>/`, checked again
   there, and made read-only (`chmod -R a-w`). Collections already in the case are
   skipped.
3. Everything imported in the run is hashed into
   `~/cases/<case>/fieldkit/IMPORT-MANIFEST-<UTC>.sha256` (read-only).
4. `~/cases/<case>/chain-of-custody.log` gets a block: UTC time, examiner (asked
   for, or `--examiner`), operator (`id -un`, uid, laptop host name), source,
   stick identity (device, partition, label, UUID, filesystem, vendor, model,
   serial), how it was mounted, one line per collection with its result, file
   count and bytes (and `stamp=local` for the cmd fallback without wmic), the
   import manifest's SHA-256, what was taken from the stick, and the result. The
   log is append-only: it is read-only between imports and writable only for the
   moment of the append. No email address is read or recorded.

`--take-stick` (after a typed `TAKE`, or `--yes`) then remounts the stick
read-write through udisks and removes the collections this run imported and
verified; tampered or earlier collections stay.

### Hand-off to an analysis workstation

SnapshOT collects, hashes and examines on the command line (The Sleuth Kit,
TestDisk/PhotoRec); it ships no GUI forensics suite. Deeper analysis of disk
images and imported collections, in Autopsy for example, happens on a separate
analysis workstation: Autopsy's Windows build is the usual choice, installed by
the operator and not redistributed with SnapshOT (the vendor layer dropped it on
2026-10-07; see [`docs/vendoring.md`](vendoring.md#out-of-scope-and-why)). The
transfer unit is the case folder, `~/cases/<case>/`, with the import manifests
the import wrote (`fieldkit/IMPORT-MANIFEST-*.sha256`), the case `SHA256SUMS`
and `chain-of-custody.log`. The import does not write `SHA256SUMS`: the operator
keeps it as the case's running hash file and adds the import manifests to it
(the wiki's evidence handling page). Check `SHA256SUMS` before the case leaves
the laptop; its lines carry the laptop's absolute paths, so also write a
transfer manifest with paths relative to the case folder, copy the folder
whole, verify the copy against that manifest on the workstation before opening
anything, and record the transfer in the chain of custody. The wiki's field kit
page has the commands. The stick stays collectors-only.

## Profiles

| | quick (default) | full |
|---|---|---|
| Intent | low impact, every host | when the host can take the load |
| Windows run time | 2 to 5 minutes | 10 to 60 minutes |
| Linux run time | 1 to 3 minutes | 5 to 30 minutes |
| ICS project files | Documents, Desktop, Public Documents, vendor folders from `ics-vendors.txt`, `Program Files*\<vendor>`; 4 levels | every fixed drive, 8 levels, at most 20000 files (Windows folder skipped) |
| Hashing | running binaries (Windows) | plus services, drivers, startup files, ICS project files; running binaries (Linux) |
| Event logs | no | Security, System, Application, PowerShell, Task Scheduler, RDP (`wevtutil epl`; XP: WMI `BackupEventlog`) |
| Logs (Linux) | no | `/var/log` copy (20 MiB per file, 200 MiB total), journal |
| Recent files | no | Prefetch, Recent, jump lists (Windows, listing); files changed in 14 days, SUID/SGID (Linux) |
| Sysinternals | listed only | `autorunsc`, `sigcheck` when present in `user-supplied\` |

## What each collector collects

Every collector writes only to `<kit>/results/<HOST>_<yyyymmddTHHMMSSZ>/`,
found from the script's own location. `<HOST>` is limited to `[A-Za-z0-9._-]`.
Steps run most volatile first, each fail-soft: `run.log` has a UTC
`BEGIN`/`END ... rc=` pair per step, `errors.txt` the error output. Each run
ends with `summary.txt` (`key=value`: host, OS, profile, start and end, stamp,
collector and kit versions, user, admin/root, counts, hasher),
`collection.txt` (sizes) and `MANIFEST.sha256` in `sha256sum` format.

| Area | Collect-Triage.ps1 (PowerShell 2.0+) | collect-triage.cmd fallback | collect-triage.sh |
|---|---|---|---|
| Processes | `processes.csv`: WMI, owner, start (UTC), path, SHA-256, command line; `tasklist-svc.txt` | `tasklist /v`, `/svc`, `wmic process` | `ps.tsv` from `/proc` (exe, deleted-exe flag, cwd, command line), `ps-raw.txt` |
| Network | `netstat.csv` + process names, `listening.csv`, ipconfig, DNS cache, ARP, routes, NetBIOS cache, firewall, proxy, shares, hosts | the same tools | `sockets.tsv` decoded from `/proc/net` with PIDs, `ss`/`netstat`, `net.txt` |
| Services, tasks | `services.csv`, `drivers.csv`, `schtasks.csv`, task files | `sc query`, service ImagePaths, `wmic service`, `schtasks` | systemd units/timers, init scripts, cron (`persistence.txt`) |
| Autostart | Run/RunOnce (HKLM, WOW64, every loaded user), Winlogon, AppInit, Active Setup, KnownDLLs, IFEO debuggers, BootExecute, Startup folders, WMI event subscriptions | the same keys (current user), Startup folders, WMI subscriptions | rc.local, `ld.so.preload`, profile scripts, `authorized_keys` (listing) |
| Users | local accounts and groups, logon sessions, `query user`, profiles | `net user`, `net localgroup`, `query user`, `net session` | passwd, group, sudoers, who/w/last; **shadow: presence and permissions only** |
| System, software | systeminfo, OS/BIOS/time zone, hotfixes, Uninstall keys (never `Win32_Product`) | systeminfo, `ver`, time zone key, `wmic qfe`, Uninstall keys | kernel, OS release, time zone, modules, mounts, disks, dpkg/rpm/opkg/apk |
| Devices | USBSTOR, MountedDevices, logical disks, `net use`, environment | the same | lsblk, lsusb, lspci, dmesg |
| OT | COM ports from PnP and `SERIALCOMM` (ports never opened), OPC servers by component category (`ot-opc.csv`), ICS software matches, ICS project files | the same via `reg query /f` (Vista+), `findstr` and a bounded folder walk | serial device nodes (not opened) |

The two ICS lists in `windows/` are shared by the PowerShell and cmd collectors:
`ics-extensions.txt` (project-file extensions, e.g. `.s7p`, `.ap1*`, `.acd`,
`.stu`, `.project`) and `ics-vendors.txt` (`name|` patterns matched against
software, folders, services and processes; `dir|` default project folders with
`%VAR%` expansion). Project files are listed (path, size, times), never copied.

### Safety rules in the code

- No network, no installs, no services started or stopped, no registry or
  configuration writes, no log clearing; serial ports are never opened (no
  `mode COMx`, no `Win32_SerialPort`, which opens each port).
- Installed software comes from the Uninstall keys, never `Win32_Product` (it
  runs an MSI consistency check and can repair packages).
- Local groups only (`Win32_Group LocalAccount=True` + `net localgroup`):
  `Win32_GroupUser` walks the whole domain on a domain member.
- Native tools run through `cmd.exe /d` (no AutoRun) with a timeout.
- Known footprint, logged in `run.log`: Prefetch entries, process-creation audit
  events, wmic's first-run compile, file access times (Linux), and the
  Sysinternals `EulaAccepted` value when those tools are used.
- `scripts/check-fieldkit.sh` greps all three collectors for destructive or
  state-changing commands and checks that every write goes to the results
  folder.

### Time stamps

PowerShell and Linux stamps are UTC. The cmd fallback takes the time from
`wmic os get LocalDateTime`, whose UTC offset it uses to compute the UTC stamp.
Without wmic (XP Home, Windows 11 24H2+ with `cmd`), `%DATE%`/`%TIME%` are local
and locale-formatted: the folder name is their digits plus `L`, `summary.txt`
says `stamp=local` with the raw date and time, the `systeminfo` time-zone line
and `ActiveTimeBias`, and the import notes it in the chain-of-custody log.

### PowerShell 2.0 and XP constraints

`Collect-Triage.ps1` must run on PowerShell 2.0 (CLR 2.0): `Get-WmiObject`
rather than CIM, no `[ordered]`/`[pscustomobject]`, no `-in`, no member
enumeration, no `$PSScriptRoot`, no `Get-FileHash` (SHA-256 through .NET, the
FIPS-safe CSP class first), no .NET 4 APIs, ASCII only (PS 2.0 reads BOM-less
scripts in the ANSI code page), and `Set-StrictMode -Version 2.0`.
`scripts/fieldkit/ps2-lint.ps1` enforces this from the AST, because
PSScriptAnalyzer has no PowerShell 2.0 profile. The `.cmd` uses only what XP
ships; the Windows-side files keep CRLF line ends (`.gitattributes`), because
`cmd.exe` misparses LF-only batch files. On XP there is no SHA-256 tool, so the
fallback writes no manifest (`hasher=none`) and integrity starts at the import.

## Checks

`scripts/check-fieldkit.sh` (Docker, network) runs:

1. **static**: shellcheck, file modes (755 for the scripts, 644 otherwise),
   CRLF/LF and ASCII, guardrails on the three collectors, the kit layout, and
   `dpkg-buildpackage` of snapshot-fieldkit with the modes in the `.deb`;
2. **Linux collector** in `busybox` and `debian:trixie`, as root and as `nobody`,
   quick and full, including a deleted running binary, a listening socket, a
   `/proc/net` decoder fixture, and a check that nothing changed outside the
   results folder;
3. **prep** against a loop device in a privileged container: the refusals (not
   removable, boot medium, root disk, a partition, no terminal), exFAT and FAT32,
   and `--refresh` (results, user-supplied tools and root files kept, stale kit
   files removed, deleted kit files restored);
4. **import** as a normal user: Linux and Windows-style collections, read-only
   copy, import manifest, append-only chain-of-custody log, no email, TAMPER and
   UNLISTED handling, refusal of root, `--take-stick`;
5. **PowerShell** in `mcr.microsoft.com/dotnet/sdk:8.0` (the PowerShell image is
   arm/v7 only and crashes under emulation on Apple Silicon): parse, ps2-lint and
   its self-test, PSScriptAnalyzer with the PowerShell 3.0 profile (advisory
   except syntax), and unit tests of the collector's helpers.

`scripts/check-desktop.sh` covers the menu (06 Host Forensics holds the
four field kit launchers and The Sleuth Kit) and
`scripts/check-installer.sh` the package changelog.

Not covered by containers: PowerShell 2.0 and `cmd.exe` themselves, real USB
sticks (udev timing, `sdX`/`nvme`/`mmcblk` partition naming), and udisks on a
desktop session. Those are the manual checks below.

## Manual QA (Windows VMs in VMware Fusion, a real stick)

Prepare a real stick on a SnapshOT VM with the stick passed through, then:

1. **Prep refusals.** `snapshot-fieldkit-prep --list` shows the stick and not the
   system disk; `--device /dev/sda` (system disk) is refused.
2. **Windows 7 SP1 (PowerShell 2.0), elevated.** `E:\windows\collect-triage.cmd`:
   the banner shows the version, `E:\results\<HOST>_<UTC>Z` and the duration, and
   waits for Enter. Pick quick. Then `collect-triage.cmd full -y`. Both: one
   folder each; `run.log` has BEGIN/END rc lines and the PowerShell 2.0 version;
   `summary.txt` has `is_admin=1`, `hasher=` a .NET provider; `processes.csv`
   has SHA-256 values; `ot-project-files.csv` exists (drop a dummy `test.s7p` in
   Documents first: it must be listed); full has `eventlogs\*.evtx`.
3. **Windows 7, not elevated** (double-click the `.cmd`): runs, warns "not
   elevated", the window stays open at the end.
4. **Windows 10/11.** Same as 2, plus `collect-triage.cmd cmd`: the fallback
   folder name ends in `Z` (wmic present) and `summary.txt` says `stamp=utc`,
   `hasher=certutil`. On Windows 11 24H2+ without wmic: folder ends in `L`,
   `stamp=local`.
5. **PowerShell blocked.** Set `ExecutionPolicy` to `AllSigned` by Group Policy
   (MachinePolicy) on a test VM: the launcher reports the failure and suggests
   `collect-triage.cmd cmd`, which then works.
6. **Windows XP SP3** (no PowerShell): the fallback runs, `stamp=utc` with wmic
   (XP Pro), `hasher=none`, no `MANIFEST.sha256`, event logs as `*.evt` in full.
   On an exFAT stick without KB955704 XP cannot read the stick: use `--fat32`.
7. **Footprint.** Before and after a quick run, compare
   `dir /s /a C:\ > list.txt` (taken onto another stick) apart from Prefetch,
   logs and the pagefile: nothing else should change.
8. **Import.** Back on SnapshOT, as the normal user:
   `snapshot-fieldkit-import --case QA --examiner "<name>"` mounts the stick
   read-only (check with `findmnt`), imports every collection as `verified` (XP:
   `no-manifest`), and `~/cases/QA/chain-of-custody.log` is read-only. Edit one
   byte of a collection on the stick and import again: TAMPER, exit 1. Then
   `--take-stick` clears the verified ones.
9. **Linux target** (any VM, BusyBox if available): `sudo sh
   /media/.../linux/collect-triage.sh` then plain `sh ...` as a user; both import
   as `verified`.
