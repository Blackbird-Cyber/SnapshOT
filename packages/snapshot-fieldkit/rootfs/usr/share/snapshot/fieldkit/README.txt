SnapshOT field kit
==================

This stick is a SnapshOT field triage kit (Blackbird Cyber). It holds
read-only collectors that take an inventory of a Windows or Linux host met
on an OT engagement: processes, network connections, services, autostart
entries, users, installed software, devices, serial ports, OPC servers and
ICS project files. They write only to results\ on this stick.

Use it only on hosts you are authorised to examine, and read
docs\ot-safety.txt before running anything on a control system.

Quick start
-----------
Windows (XP to 11, PowerShell 2.0 or newer, or none):
    Open a command prompt (as Administrator for the full picture), then
        E:\windows\collect-triage.cmd            (asks quick or full)
        E:\windows\collect-triage.cmd quick
        E:\windows\collect-triage.cmd full
        E:\windows\collect-triage.cmd cmd        (built-in tools only, no PowerShell)
    Double-clicking collect-triage.cmd also works (unelevated).

Linux (any distribution, BusyBox included):
    sudo sh /media/<user>/SNAPKIT/linux/collect-triage.sh [quick|full]
    (as root for the full picture; plain "sh ..." also works with less detail)

Each run prints a banner with the results folder and the expected duration,
and waits for Enter: press Ctrl+C there to abort on a fragile host.
"-y" skips the prompts.

Back on the SnapshOT laptop
---------------------------
    snapshot-fieldkit-import --case <case> --examiner "<name>"
copies results\ into ~/cases/<case>/fieldkit/, checks every collection
against its MANIFEST.sha256 and appends to the case's chain-of-custody log.

Layout
------
    VERSION            kit version, build commit, build date
    MANIFEST.sha256    SHA-256 of every kit file (written when the stick was prepared)
    windows\           Collect-Triage.ps1, collect-triage.cmd, ICS lists
    windows\user-supplied\   put Sysinternals autorunsc / sigcheck here (optional)
    linux\             collect-triage.sh
    linux\user-supplied\     optional static tools (listed, not run)
    docs\              fieldkit-guide.txt, ot-safety.txt, chain-of-custody.txt
    results\           one folder per collection: <HOST>_<UTC time>
