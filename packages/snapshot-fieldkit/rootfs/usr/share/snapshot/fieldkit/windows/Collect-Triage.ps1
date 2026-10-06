# SnapshOT field kit: read-only triage collector for Windows targets.
#
#   collect-triage.cmd [quick|full] [-y]          (the launcher; preferred)
#   powershell -NoProfile -ExecutionPolicy Bypass -File Collect-Triage.ps1 [-Mode quick|full] [-Yes]
#
# Written for PowerShell 2.0 (Windows 7 / Server 2008 R2, and XP / 2003 with
# WMF 2.0) and checked with scripts/fieldkit/ps2-lint.ps1: WMI through
# Get-WmiObject, no PS 3+ syntax, ASCII only. It reads the target and writes
# only to <kit>\results\<HOST>_<UTCSTAMP>\ beside this script: no network, no
# installs, no changes to the target. Every step is fail-soft and logged with
# its rc in run.log; errors go to errors.txt. docs\fieldkit-guide.txt lists
# what each step collects.
#
#   quick (default)  processes (with SHA-256 of running binaries), network,
#                    services, tasks, autostart, users, system, software,
#                    devices, and the OT section (serial ports, OPC servers,
#                    ICS software, ICS project files in the usual folders).
#   full             quick, plus event logs, more hashes, recent files and
#                    Prefetch, ICS project files on every fixed drive, and the
#                    user-supplied Sysinternals tools when present.
param(
    [string]$Mode = '',
    [switch]$Yes,
    [switch]$LibOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

# Strict mode: every script variable is set before its first read.
$script:CollectorVersion = '0.1.0'
$script:ScriptPath = $MyInvocation.MyCommand.Definition
$script:WinDir = Split-Path -Parent $script:ScriptPath
$script:KitRoot = Split-Path -Parent $script:WinDir
$script:OutDir = ''
$script:LogFile = ''
$script:ErrFile = ''
$script:Hasher = $null
$script:HasherName = 'none'
$script:HashCache = @{}
$script:ProcNames = @{}
$script:ProcPaths = @()
$script:StepsNonZero = 0
$script:Counts = @{}
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:ComSpec = $env:ComSpec
if (-not $script:ComSpec) { $script:ComSpec = 'cmd.exe' }

# Project-file scan bounds (docs/fieldkit-guide.txt, "ICS project files").
$script:QuickScanDepth = 4
$script:FullScanDepth = 8
$script:ScanFileCap = 20000
$script:ScanDirCap = 200000
$script:HashSizeCap = 268435456

# OPC component categories (DA 1/2/3, XML-DA, A&E, HDA).
$script:OpcCategories = @{
    '{63D5F430-CFE4-11D1-B2C8-0060083BA1FB}' = 'OPC DA 1.0'
    '{63D5F432-CFE4-11D1-B2C8-0060083BA1FB}' = 'OPC DA 2.0'
    '{CC603642-66D7-48F1-B69A-B625E73652D7}' = 'OPC DA 3.0'
    '{3098EDA4-A006-48B2-A27F-247453959408}' = 'OPC XML-DA 1.0'
    '{58E13251-AC87-11D1-84D5-00608CB8A7E9}' = 'OPC A&E 1.0'
    '{7DE5B060-E089-11D2-A5E6-000086339399}' = 'OPC HDA 1.0'
}

# ---------------------------------------------------------------- helpers

function Get-UtcNow { return [DateTime]::UtcNow.ToString('s') + 'Z' }

function Get-UtcStamp {
    $n = [DateTime]::UtcNow
    return $n.ToString('yyyyMMdd') + 'T' + $n.ToString('HHmmss') + 'Z'
}

function Get-SafeHost {
    param([string]$Name)
    if (-not $Name) { $Name = 'unknown' }
    return ($Name -replace '[^A-Za-z0-9._-]', '_')
}

# PowerShell 2.0 runs a foreach over $null once, so every loop over a
# function's output wraps it in @().
function Get-OutPath {
    param([string]$Name)
    return [System.IO.Path]::Combine($script:OutDir, $Name)
}

# Text output, UTF-8 without a BOM, CRLF line ends.
function Write-Text {
    param([string]$Name, [string]$Text, [switch]$Append)
    $p = Get-OutPath $Name
    if ($Append) { [System.IO.File]::AppendAllText($p, $Text, $script:Utf8) }
    else { [System.IO.File]::WriteAllText($p, $Text, $script:Utf8) }
}

function Write-RunLog {
    param([string]$Message)
    if ($script:LogFile) {
        [System.IO.File]::AppendAllText($script:LogFile, (Get-UtcNow) + ' ' + $Message + "`r`n", $script:Utf8)
    }
}

function Add-ErrorText {
    param([string]$Step, [string]$Message)
    if ($script:ErrFile) {
        $t = ($Message -replace "`r?`n", ' ')
        [System.IO.File]::AppendAllText($script:ErrFile, '[' + $Step + '] ' + $t + "`r`n", $script:Utf8)
    }
}

# One step: logs BEGIN/END with rc, catches everything, records errors.
# rc 0 = clean, 1 = the step threw, 2 = the step reported non-terminating errors.
function Invoke-Step {
    param([string]$Name, [scriptblock]$Body)
    Write-RunLog "BEGIN $Name"
    Write-Host ('  ' + $Name)
    $Error.Clear()
    $rc = 0
    try { $null = & $Body } catch { $rc = 1; Add-ErrorText $Name ($_.Exception.Message) }
    if ($Error.Count -gt 0) {
        for ($i = $Error.Count - 1; $i -ge 0; $i--) { Add-ErrorText $Name ([string]$Error[$i]) }
        if ($rc -eq 0) { $rc = 2 }
        $Error.Clear()
    }
    if ($rc -ne 0) { $script:StepsNonZero++ }
    Write-RunLog "END   $Name rc=$rc"
}

# Runs a built-in command through cmd.exe (/d: no AutoRun), its output going
# straight to a file in the results folder. Process.Start keeps the quoting
# exact on every PowerShell version; the timeout keeps a hung tool from
# stalling the collection.
function Invoke-Native {
    param([string]$File, [string]$CommandLine, [int]$TimeoutSec = 300, [switch]$Append)
    $op = '>'
    if ($Append) { $op = '>>' }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:ComSpec
    $psi.Arguments = '/d /c "' + $CommandLine + ' ' + $op + ' "' + (Get-OutPath $File) + '" 2>> "' + $script:ErrFile + '" <nul"'
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = $script:OutDir
    $p = [System.Diagnostics.Process]::Start($psi)
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        Write-RunLog "  timeout after $TimeoutSec s :: $CommandLine"
        return -1
    }
    Write-RunLog ('  rc=' + $p.ExitCode + ' :: ' + $CommandLine)
    return $p.ExitCode
}

function Test-Command {
    param([string]$Name)
    $sys = [System.IO.Path]::Combine([Environment]::SystemDirectory, $Name)
    return (Test-Path -LiteralPath $sys)
}

function New-Row {
    param([string[]]$Names, [object[]]$Values)
    $o = New-Object PSObject
    for ($i = 0; $i -lt $Names.Length; $i++) {
        $v = $null
        if ($i -lt $Values.Length) { $v = $Values[$i] }
        Add-Member -InputObject $o -MemberType NoteProperty -Name $Names[$i] -Value $v
    }
    return $o
}

# CSV plus a fixed-width .txt view of the same rows.
function Export-Table {
    param([string]$Name, [object[]]$Rows, [switch]$NoText)
    $rows2 = @($Rows | Where-Object { $null -ne $_ })
    $script:Counts[$Name] = $rows2.Length
    if ($rows2.Length -eq 0) { Write-Text ($Name + '.csv') ''; return }
    $rows2 | Export-Csv -Path (Get-OutPath ($Name + '.csv')) -NoTypeInformation -Encoding UTF8
    if (-not $NoText) {
        $t = $rows2 | Format-Table -AutoSize | Out-String -Width 512
        Write-Text ($Name + '.txt') $t
    }
}

function Format-WmiDate {
    param([string]$Value)
    if (-not $Value) { return '' }
    try { return [System.Management.ManagementDateTimeConverter]::ToDateTime($Value).ToUniversalTime().ToString('s') + 'Z' }
    catch { return $Value }
}

function Format-FileTime {
    param([DateTime]$Value)
    return $Value.ToUniversalTime().ToString('s') + 'Z'
}

# SHA-256: the CSP class is FIPS-safe but needs .NET 3.5 (System.Core) and a
# provider with SHA-256 (XP SP3+); SHA256Managed covers the rest. Each
# candidate must hash an empty buffer before it is trusted.
function New-Sha256 {
    try {
        [void][System.Reflection.Assembly]::LoadWithPartialName('System.Core')
        $t = [Type]::GetType('System.Security.Cryptography.SHA256CryptoServiceProvider, System.Core, Version=3.5.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
        if ($t) {
            $h = New-Object $t.FullName
            [void]$h.ComputeHash([byte[]]@())
            $script:HasherName = '.NET SHA256CryptoServiceProvider'
            return $h
        }
    } catch { }
    try {
        $h = New-Object System.Security.Cryptography.SHA256Managed
        [void]$h.ComputeHash([byte[]]@())
        $script:HasherName = '.NET SHA256Managed'
        return $h
    } catch { }
    $script:HasherName = 'none'
    return $null
}

function Get-Sha256 {
    param([string]$Path)
    if (-not $script:Hasher) { $script:Hasher = New-Sha256 }
    if (-not $script:Hasher -or -not $Path) { return '' }
    $fs = $null
    try {
        $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        $h = $script:Hasher.ComputeHash($fs)
        return ([System.BitConverter]::ToString($h) -replace '-', '').ToLower()
    } catch { return '' } finally { if ($fs) { $fs.Close() } }
}

# Hash once per path; files over the size cap are skipped.
function Get-CachedSha256 {
    param([string]$Path)
    if (-not $Path) { return '' }
    $k = $Path.ToLower()
    if ($script:HashCache.ContainsKey($k)) { return $script:HashCache[$k] }
    $h = ''
    try {
        $fi = New-Object System.IO.FileInfo($Path)
        if ($fi.Exists -and $fi.Length -le $script:HashSizeCap) { $h = Get-Sha256 $Path }
    } catch { }
    $script:HashCache[$k] = $h
    return $h
}

# netstat -ano lines to rows. The state column is localised on non-English
# Windows, so "listening" is decided from the remote address instead.
function ConvertFrom-Netstat {
    param([string[]]$Lines, [hashtable]$ProcNames)
    foreach ($l in $Lines) {
        if (-not $l) { continue }
        $f = @(($l.Trim() -split '\s+'))
        if ($f.Count -lt 4 -or ($f[0] -ne 'TCP' -and $f[0] -ne 'UDP')) { continue }
        if ($f[0] -eq 'TCP') {
            if ($f.Count -lt 5) { continue }
            $state = $f[3]; $procId = $f[4]
            $listen = ($f[2] -eq '0.0.0.0:0' -or $f[2] -eq '[::]:0')
        } else {
            $state = ''; $procId = $f[3]
            $listen = $true
        }
        $n = ''
        if ($ProcNames -and $ProcNames.ContainsKey($procId)) { $n = $ProcNames[$procId] }
        New-Row @('Proto', 'Local', 'Remote', 'State', 'PID', 'Process', 'Listening') @($f[0], $f[1], $f[2], $state, $procId, $n, $listen)
    }
}

# Pattern files shared with collect-triage.cmd. Lines: "# comment" or
# "<value> [description]" (ics-extensions.txt), "kind|value" (ics-vendors.txt).
function Read-IcsExtensions {
    param([string]$Path)
    $out = @()
    foreach ($l in @(Get-Content -LiteralPath $Path)) {
        $t = $l.Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        $e = @($t -split '\s+')[0]
        if ($e.StartsWith('.')) { $out += ('*' + $e) }
    }
    return $out
}

function Read-IcsVendors {
    param([string]$Path, [string]$Kind)
    $out = @()
    foreach ($l in @(Get-Content -LiteralPath $Path)) {
        $t = $l.Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        $p = $t.Split('|')
        if ($p.Length -ge 2 -and $p[0].Trim() -eq $Kind -and $p[1].Trim()) { $out += $p[1].Trim() }
    }
    return $out
}

function Test-NameMatch {
    param([string]$Text, [string[]]$Patterns)
    if (-not $Text) { return '' }
    $low = $Text.ToLower()
    foreach ($p in $Patterns) { if ($low.Contains($p.ToLower())) { return $p } }
    return ''
}

# Bounded, read-only walk for project files. Skips reparse points (junctions,
# symlinks) so profile junction loops are not followed; lists, never copies.
function Find-ProjectFiles {
    param([string[]]$Roots, [string[]]$Patterns, [int]$MaxDepth, [int]$FileCap, [string[]]$SkipDirs)
    $found = New-Object System.Collections.ArrayList
    $seen = @{}
    $dirs = 0
    $stack = New-Object System.Collections.Stack
    foreach ($r in $Roots) {
        if ($r -and [System.IO.Directory]::Exists($r)) { $stack.Push(@($r, 0)) }
    }
    while ($stack.Count -gt 0 -and $found.Count -lt $FileCap -and $dirs -lt $script:ScanDirCap) {
        $item = $stack.Pop()
        $dir = [string]$item[0]
        $depth = [int]$item[1]
        $key = $dir.TrimEnd('\', '/').ToLower()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $dirs++
        try {
            foreach ($p in $Patterns) {
                foreach ($f in [System.IO.Directory]::GetFiles($dir, $p)) {
                    if ($found.Count -ge $FileCap) { break }
                    $fi = New-Object System.IO.FileInfo($f)
                    [void]$found.Add((New-Row @('Path', 'Size', 'ModifiedUtc', 'CreatedUtc') @($fi.FullName, $fi.Length, (Format-FileTime $fi.LastWriteTime), (Format-FileTime $fi.CreationTime))))
                }
            }
            if ($depth -lt $MaxDepth) {
                foreach ($d in [System.IO.Directory]::GetDirectories($dir)) {
                    $di = New-Object System.IO.DirectoryInfo($d)
                    if (($di.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                    $skip = $false
                    foreach ($s in $SkipDirs) { if ($s -and $d.TrimEnd('\').ToLower() -eq $s.TrimEnd('\').ToLower()) { $skip = $true } }
                    if (-not $skip) { $stack.Push(@($d, ($depth + 1))) }
                }
            }
        } catch { }
    }
    return $found
}

# Files under OutDir, relative paths with forward slashes, sorted.
function Get-OutFiles {
    $base = $script:OutDir.TrimEnd('\', '/')
    $all = @([System.IO.Directory]::GetFiles($base, '*', [System.IO.SearchOption]::AllDirectories))
    $rel = @()
    foreach ($f in $all) { $rel += $f.Substring($base.Length + 1).Replace('\', '/') }
    return @($rel | Sort-Object)
}

# MANIFEST.sha256 in sha256sum format ("<hex>  <path>", LF), checked on import.
# A file it cannot hash is reported on the console only: errors.txt is
# already hashed by then.
function Write-Manifest {
    $sb = New-Object System.Text.StringBuilder
    foreach ($r in @(Get-OutFiles)) {
        if ($r.StartsWith('MANIFEST.sha256')) { continue }
        $h = Get-Sha256 (Get-OutPath $r)
        if ($h) { [void]$sb.Append($h + '  ' + $r + "`n") }
        else { Write-Host ('manifest: cannot hash ' + $r) }
    }
    $tmp = Get-OutPath 'MANIFEST.sha256.tmp'
    [System.IO.File]::WriteAllText($tmp, $sb.ToString(), $script:Utf8)
    [System.IO.File]::Move($tmp, (Get-OutPath 'MANIFEST.sha256'))
}

function Get-ProfileDirs {
    $out = @()
    $roots = @()
    if ($env:SystemDrive) {
        $roots += ($env:SystemDrive + '\Users')
        $roots += ($env:SystemDrive + '\Documents and Settings')
    }
    foreach ($r in $roots) {
        if (-not [System.IO.Directory]::Exists($r)) { continue }
        foreach ($d in [System.IO.Directory]::GetDirectories($r)) {
            $di = New-Object System.IO.DirectoryInfo($d)
            if (($di.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
            $out += $d
        }
    }
    return $out
}

function Get-LoadedUserHives {
    $out = @()
    try {
        foreach ($n in [Microsoft.Win32.Registry]::Users.GetSubKeyNames()) {
            if ($n -match '^S-1-5-21-[0-9-]+$') { $out += $n }
        }
    } catch { }
    return $out
}

function Get-FileRows {
    param([string[]]$Dirs, [string]$Filter, [switch]$Recurse)
    $rows = @()
    foreach ($d in $Dirs) {
        if (-not $d -or -not [System.IO.Directory]::Exists($d)) { continue }
        $opt = [System.IO.SearchOption]::TopDirectoryOnly
        if ($Recurse) { $opt = [System.IO.SearchOption]::AllDirectories }
        try {
            foreach ($f in [System.IO.Directory]::GetFiles($d, $Filter, $opt)) {
                $fi = New-Object System.IO.FileInfo($f)
                $rows += New-Row @('Path', 'Size', 'ModifiedUtc', 'CreatedUtc', 'AccessedUtc') @($fi.FullName, $fi.Length, (Format-FileTime $fi.LastWriteTime), (Format-FileTime $fi.CreationTime), (Format-FileTime $fi.LastAccessTime))
            }
        } catch { Add-ErrorText 'files' ($d + ': ' + $_.Exception.Message) }
    }
    return $rows
}

# Image path from a service PathName / command line: drops quotes and args.
function Get-ImagePath {
    param([string]$CommandLine)
    if (-not $CommandLine) { return '' }
    $c = [Environment]::ExpandEnvironmentVariables($CommandLine.Trim())
    if ($c.StartsWith('"')) {
        $end = $c.IndexOf('"', 1)
        if ($end -gt 1) { return $c.Substring(1, $end - 1) }
        return $c.Trim('"')
    }
    if ($c.StartsWith('\??\')) { $c = $c.Substring(4) }
    if ($c -match '^(?i)\\?SystemRoot\\') { $c = $c -replace '^(?i)\\?SystemRoot', $env:SystemRoot }
    if ($c -match '^(?i)system32\\') { $c = [System.IO.Path]::Combine($env:SystemRoot, $c) }
    $m = [regex]::Match($c, '^(?i)(.+?\.(exe|sys|dll|com|scr))(\s|$)')
    if ($m.Success) { return $m.Groups[1].Value }
    return @($c -split ' ')[0]
}

if ($LibOnly) { return }

# ------------------------------------------------------------------ steps

function Step-Processes {
    $procs = @(Get-WmiObject -Class Win32_Process)
    $rows = @()
    $paths = @()
    foreach ($p in $procs) {
        $procId = [string]$p.ProcessId
        $script:ProcNames[$procId] = $p.Name
        $owner = ''
        try {
            $o = $p.GetOwner()
            if ($o -and $o.ReturnValue -eq 0) { $owner = $o.Domain + '\' + $o.User }
        } catch { }
        $exe = [string]$p.ExecutablePath
        $hash = ''
        if ($exe) { $hash = Get-CachedSha256 $exe; $paths += $exe }
        $rows += New-Row @('PID', 'PPID', 'Name', 'Owner', 'CreatedUtc', 'ExecutablePath', 'Sha256', 'CommandLine') @($procId, $p.ParentProcessId, $p.Name, $owner, (Format-WmiDate $p.CreationDate), $exe, $hash, $p.CommandLine)
    }
    $script:ProcPaths = @($paths | Sort-Object -Unique)
    Export-Table 'processes' $rows
    [void](Invoke-Native 'tasklist-svc.txt' 'tasklist /svc')
}

function Step-Network {
    [void](Invoke-Native 'netstat.txt' 'netstat -ano')
    if ($script:ProcNames.Count -eq 0) {
        foreach ($p in @(Get-WmiObject -Class Win32_Process)) { $script:ProcNames[[string]$p.ProcessId] = $p.Name }
    }
    $lines = @(Get-Content -LiteralPath (Get-OutPath 'netstat.txt'))
    $rows = @(ConvertFrom-Netstat -Lines $lines -ProcNames $script:ProcNames)
    Export-Table 'netstat' $rows
    Export-Table 'listening' @($rows | Where-Object { $_.Listening })
}

function Step-Services {
    $rows = @()
    foreach ($s in @(Get-WmiObject -Class Win32_Service)) {
        $rows += New-Row @('Name', 'DisplayName', 'State', 'StartMode', 'ProcessId', 'StartName', 'PathName') @($s.Name, $s.DisplayName, $s.State, $s.StartMode, $s.ProcessId, $s.StartName, $s.PathName)
    }
    Export-Table 'services' $rows
    $rows = @()
    foreach ($s in @(Get-WmiObject -Class Win32_SystemDriver)) {
        $rows += New-Row @('Name', 'DisplayName', 'State', 'StartMode', 'PathName') @($s.Name, $s.DisplayName, $s.State, $s.StartMode, $s.PathName)
    }
    Export-Table 'drivers' $rows
}

function Step-Tasks {
    [void](Invoke-Native 'schtasks.csv' 'schtasks /query /fo csv /v')
    $dirs = @()
    if ($env:SystemRoot) { $dirs += ($env:SystemRoot + '\Tasks'); $dirs += ($env:SystemRoot + '\System32\Tasks') }
    Export-Table 'task-files' (Get-FileRows -Dirs $dirs -Filter '*' -Recurse) -NoText
}

function Step-Autostart {
    $keys = @(
        'HKLM\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM\Software\Microsoft\Windows\CurrentVersion\RunServices',
        'HKLM\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce',
        'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run',
        'HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon',
        'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Windows',
        'HKLM\Software\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Windows',
        'HKLM\Software\Microsoft\Active Setup\Installed Components',
        'HKLM\System\CurrentControlSet\Control\Session Manager\KnownDLLs'
    )
    foreach ($sid in @(Get-LoadedUserHives)) {
        $keys += ('HKU\' + $sid + '\Software\Microsoft\Windows\CurrentVersion\Run')
        $keys += ('HKU\' + $sid + '\Software\Microsoft\Windows\CurrentVersion\RunOnce')
        $keys += ('HKU\' + $sid + '\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run')
        $keys += ('HKU\' + $sid + '\Software\Microsoft\Windows NT\CurrentVersion\Windows')
    }
    Write-Text 'autostart.txt' ''
    foreach ($k in $keys) {
        Write-Text 'autostart.txt' ("`r`n== " + $k + "`r`n") -Append
        [void](Invoke-Native 'autostart.txt' ('reg query "' + $k + '"') -Append)
    }
    Write-Text 'autostart.txt' "`r`n== Image File Execution Options (Debugger values)`r`n" -Append
    [void](Invoke-Native 'autostart.txt' 'reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" /s /v Debugger' -Append)
    Write-Text 'autostart.txt' "`r`n== Session Manager BootExecute`r`n" -Append
    [void](Invoke-Native 'autostart.txt' 'reg query "HKLM\System\CurrentControlSet\Control\Session Manager" /v BootExecute' -Append)

    $dirs = @()
    if ($env:ProgramData) { $dirs += ($env:ProgramData + '\Microsoft\Windows\Start Menu\Programs\Startup') }
    if ($env:ALLUSERSPROFILE) { $dirs += ($env:ALLUSERSPROFILE + '\Start Menu\Programs\Startup') }
    foreach ($p in @(Get-ProfileDirs)) {
        $dirs += ($p + '\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup')
        $dirs += ($p + '\Start Menu\Programs\Startup')
    }
    Export-Table 'autostart-files' (Get-FileRows -Dirs $dirs -Filter '*')

    # WMI event subscriptions, a common fileless persistence.
    $t = ''
    foreach ($c in @('__EventFilter', '__EventConsumer', '__FilterToConsumerBinding')) {
        $t += "== root\subscription $c`r`n"
        $t += (@(Get-WmiObject -Namespace 'root\subscription' -Class $c) | Format-List * | Out-String -Width 512)
    }
    Write-Text 'wmi-persistence.txt' $t
}

function Step-Users {
    $rows = @()
    foreach ($u in @(Get-WmiObject -Class Win32_UserAccount -Filter 'LocalAccount=True')) {
        $rows += New-Row @('Name', 'Domain', 'SID', 'Disabled', 'Lockout', 'PasswordRequired', 'Description') @($u.Name, $u.Domain, $u.SID, $u.Disabled, $u.Lockout, $u.PasswordRequired, $u.Description)
    }
    Export-Table 'users' $rows
    # Local groups only: Win32_GroupUser on a domain member walks the domain.
    Write-Text 'groups.txt' ''
    foreach ($g in @(Get-WmiObject -Class Win32_Group -Filter 'LocalAccount=True')) {
        [void](Invoke-Native 'groups.txt' ('net localgroup "' + $g.Name + '"') -Append)
    }
    $rows = @()
    foreach ($s in @(Get-WmiObject -Class Win32_LogonSession)) {
        $rows += New-Row @('LogonId', 'LogonType', 'StartUtc', 'AuthenticationPackage') @($s.LogonId, $s.LogonType, (Format-WmiDate $s.StartTime), $s.AuthenticationPackage)
    }
    Export-Table 'logon-sessions' $rows
    $rows = @()
    foreach ($l in @(Get-WmiObject -Class Win32_LoggedOnUser)) {
        $rows += New-Row @('Account', 'Session') @([string]$l.Antecedent, [string]$l.Dependent)
    }
    Export-Table 'logged-on-users' $rows -NoText
    $rc = Invoke-Native 'sessions.txt' 'query user'
    if ($rc -ne 0) { [void](Invoke-Native 'sessions.txt' 'net session' -Append) }
    $rows = @()
    foreach ($p in @(Get-WmiObject -Class Win32_UserProfile)) {
        $rows += New-Row @('LocalPath', 'SID', 'LastUseUtc', 'Loaded', 'Special') @($p.LocalPath, $p.SID, (Format-WmiDate $p.LastUseTime), $p.Loaded, $p.Special)
    }
    Export-Table 'profiles' $rows
}

function Step-System {
    [void](Invoke-Native 'systeminfo.txt' 'systeminfo' -TimeoutSec 600)
    $t = ''
    foreach ($c in @('Win32_OperatingSystem', 'Win32_ComputerSystem', 'Win32_BIOS', 'Win32_TimeZone')) {
        $t += "== $c`r`n"
        $t += (@(Get-WmiObject -Class $c) | Format-List * | Out-String -Width 512)
    }
    Write-Text 'os.txt' $t
    $rows = @()
    foreach ($h in @(Get-WmiObject -Class Win32_QuickFixEngineering)) {
        $rows += New-Row @('HotFixID', 'Description', 'InstalledOn', 'InstalledBy') @($h.HotFixID, $h.Description, $h.InstalledOn, $h.InstalledBy)
    }
    Export-Table 'hotfixes' $rows
    # Installed software from the Uninstall keys. Never Win32_Product: it
    # triggers an MSI consistency check (and repairs) on every package.
    $rows = @()
    $views = @(
        @([Microsoft.Win32.Registry]::LocalMachine, 'HKLM', 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'),
        @([Microsoft.Win32.Registry]::LocalMachine, 'HKLM', 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
    )
    foreach ($sid in @(Get-LoadedUserHives)) {
        $views += ,@([Microsoft.Win32.Registry]::Users, ('HKU\' + $sid), ($sid + '\Software\Microsoft\Windows\CurrentVersion\Uninstall'))
    }
    foreach ($v in $views) {
        $root = $v[0].OpenSubKey($v[2])
        if (-not $root) { continue }
        foreach ($n in $root.GetSubKeyNames()) {
            $k = $root.OpenSubKey($n)
            if (-not $k) { continue }
            $name = $k.GetValue('DisplayName')
            if ($name) {
                $rows += New-Row @('Name', 'Version', 'Publisher', 'InstallDate', 'InstallLocation', 'UninstallString', 'Hive', 'Key') @($name, $k.GetValue('DisplayVersion'), $k.GetValue('Publisher'), $k.GetValue('InstallDate'), $k.GetValue('InstallLocation'), $k.GetValue('UninstallString'), $v[1], $n)
            }
            $k.Close()
        }
        $root.Close()
    }
    $script:Software = $rows
    Export-Table 'software' $rows
}

function Step-NetConfig {
    [void](Invoke-Native 'ipconfig.txt' 'ipconfig /all')
    [void](Invoke-Native 'dnscache.txt' 'ipconfig /displaydns')
    [void](Invoke-Native 'arp.txt' 'arp -a')
    [void](Invoke-Native 'routes.txt' 'route print')
    [void](Invoke-Native 'nbtstat.txt' 'nbtstat -c')
    $rc = Invoke-Native 'firewall.txt' 'netsh advfirewall show allprofiles'
    if ($rc -ne 0) { [void](Invoke-Native 'firewall.txt' 'netsh firewall show config' -Append) }
    [void](Invoke-Native 'proxy.txt' 'reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"')
    if ([Environment]::OSVersion.Version.Major -ge 6) { [void](Invoke-Native 'proxy.txt' 'netsh winhttp show proxy' -Append) }
    else { [void](Invoke-Native 'proxy.txt' 'proxycfg' -Append) }
    $rows = @()
    foreach ($s in @(Get-WmiObject -Class Win32_Share)) {
        $rows += New-Row @('Name', 'Path', 'Type', 'Description') @($s.Name, $s.Path, $s.Type, $s.Description)
    }
    Export-Table 'shares' $rows
    $hosts = [System.IO.Path]::Combine($env:SystemRoot, 'System32\drivers\etc\hosts')
    if (Test-Path -LiteralPath $hosts) { [System.IO.File]::WriteAllBytes((Get-OutPath 'hosts.txt'), [System.IO.File]::ReadAllBytes($hosts)) }
}

function Step-Devices {
    [void](Invoke-Native 'usbstor.txt' 'reg query "HKLM\SYSTEM\CurrentControlSet\Enum\USBSTOR" /s')
    [void](Invoke-Native 'mounted-devices.txt' 'reg query "HKLM\SYSTEM\MountedDevices"')
    [void](Invoke-Native 'netuse.txt' 'net use')
    $rows = @()
    foreach ($d in @(Get-WmiObject -Class Win32_LogicalDisk)) {
        $rows += New-Row @('DeviceID', 'DriveType', 'FileSystem', 'VolumeName', 'VolumeSerialNumber', 'Size', 'FreeSpace', 'ProviderName') @($d.DeviceID, $d.DriveType, $d.FileSystem, $d.VolumeName, $d.VolumeSerialNumber, $d.Size, $d.FreeSpace, $d.ProviderName)
    }
    Export-Table 'disks' $rows
    Write-Text 'env.txt' (Get-ChildItem Env: | Sort-Object Name | Format-Table -AutoSize | Out-String -Width 4096)
}

function Get-IcsVendorNames {
    return @(Read-IcsVendors -Path ([System.IO.Path]::Combine($script:WinDir, 'ics-vendors.txt')) -Kind 'name')
}

function Step-OtSerial {
    # PnP inventory only. Win32_SerialPort opens each port to read its
    # properties, which can toggle DTR/RTS on attached equipment.
    $rows = @()
    foreach ($d in @(Get-WmiObject -Class Win32_PnPEntity -Filter "ClassGuid='{4D36E978-E325-11CE-BFC1-08002BE10318}'")) {
        $rows += New-Row @('Name', 'DeviceID', 'Manufacturer', 'Status', 'Service') @($d.Name, $d.DeviceID, $d.Manufacturer, $d.Status, $d.Service)
    }
    Export-Table 'ot-serial' $rows
    [void](Invoke-Native 'ot-serialcomm.txt' 'reg query "HKLM\HARDWARE\DEVICEMAP\SERIALCOMM"')
}

function Step-OtOpc {
    $rows = @()
    $views = @(@('CLSID', 'native'), @('Wow6432Node\CLSID', 'wow64'))
    foreach ($v in $views) {
        $root = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey($v[0])
        if (-not $root) { continue }
        foreach ($clsid in $root.GetSubKeyNames()) {
            $ic = $root.OpenSubKey($clsid + '\Implemented Categories')
            if (-not $ic) { continue }
            $cats = @()
            foreach ($c in $ic.GetSubKeyNames()) {
                if ($script:OpcCategories.ContainsKey($c.ToUpper())) { $cats += $script:OpcCategories[$c.ToUpper()] }
            }
            $ic.Close()
            if ($cats.Length -eq 0) { continue }
            $k = $root.OpenSubKey($clsid)
            $name = ''; $progId = ''; $local = ''; $inproc = ''
            if ($k) {
                $name = [string]$k.GetValue('')
                $sk = $k.OpenSubKey('ProgID'); if ($sk) { $progId = [string]$sk.GetValue(''); $sk.Close() }
                $sk = $k.OpenSubKey('LocalServer32'); if ($sk) { $local = [string]$sk.GetValue(''); $sk.Close() }
                $sk = $k.OpenSubKey('InprocServer32'); if ($sk) { $inproc = [string]$sk.GetValue(''); $sk.Close() }
                $k.Close()
            }
            $rows += New-Row @('CLSID', 'Name', 'ProgID', 'Categories', 'LocalServer32', 'InprocServer32', 'View') @($clsid, $name, $progId, ($cats -join '; '), $local, $inproc, $v[1])
        }
        $root.Close()
    }
    Export-Table 'ot-opc' $rows
    Write-Text 'ot-opc.txt' ''
    foreach ($c in $script:OpcCategories.Keys) {
        [void](Invoke-Native 'ot-opc.txt' ('reg query "HKCR\Component Categories\' + $c + '"') -Append)
    }
}

function Step-OtSoftware {
    $names = Get-IcsVendorNames
    $rows = @()
    foreach ($s in @($script:Software)) {
        if ($null -eq $s) { continue }
        $m = Test-NameMatch ([string]$s.Name + ' ' + [string]$s.Publisher) $names
        if ($m) { $rows += New-Row @('Source', 'Match', 'Name', 'Detail') @('software', $m, $s.Name, ([string]$s.Version + ' ' + [string]$s.InstallLocation).Trim()) }
    }
    foreach ($pf in @(Get-ProgramFilesDirs)) {
        foreach ($d in [System.IO.Directory]::GetDirectories($pf)) {
            $m = Test-NameMatch ([System.IO.Path]::GetFileName($d)) $names
            if ($m) { $rows += New-Row @('Source', 'Match', 'Name', 'Detail') @('folder', $m, [System.IO.Path]::GetFileName($d), $d) }
        }
    }
    foreach ($s in @(Get-WmiObject -Class Win32_Service)) {
        $m = Test-NameMatch ([string]$s.Name + ' ' + [string]$s.DisplayName + ' ' + [string]$s.PathName) $names
        if ($m) { $rows += New-Row @('Source', 'Match', 'Name', 'Detail') @('service', $m, $s.Name, ([string]$s.State + ' ' + [string]$s.PathName)) }
    }
    foreach ($p in @($script:ProcPaths)) {
        $m = Test-NameMatch $p $names
        if ($m) { $rows += New-Row @('Source', 'Match', 'Name', 'Detail') @('process', $m, [System.IO.Path]::GetFileName($p), $p) }
    }
    Export-Table 'ot-ics-software' $rows
}

function Get-ProgramFilesDirs {
    $out = @()
    foreach ($v in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432)) {
        if ($v -and [System.IO.Directory]::Exists($v) -and ($out -notcontains $v)) { $out += $v }
    }
    return $out
}

# Quick: the usual project roots, 4 levels. Full: every fixed drive, 8 levels.
function Step-OtProjects {
    param([string]$Kind)
    $patterns = @(Read-IcsExtensions -Path ([System.IO.Path]::Combine($script:WinDir, 'ics-extensions.txt')))
    $roots = @()
    $skip = @()
    if ($Kind -eq 'full') {
        foreach ($d in @(Get-WmiObject -Class Win32_LogicalDisk -Filter 'DriveType=3')) { $roots += ($d.DeviceID + '\') }
        $skip += $env:SystemRoot
        $depth = $script:FullScanDepth
    } else {
        foreach ($p in @(Get-ProfileDirs)) {
            $roots += ($p + '\Documents'); $roots += ($p + '\My Documents'); $roots += ($p + '\Desktop')
        }
        if ($env:PUBLIC) { $roots += ($env:PUBLIC + '\Documents') }
        if ($env:ALLUSERSPROFILE) { $roots += ($env:ALLUSERSPROFILE + '\Documents') }
        foreach ($d in @(Read-IcsVendors -Path ([System.IO.Path]::Combine($script:WinDir, 'ics-vendors.txt')) -Kind 'dir')) {
            $roots += [Environment]::ExpandEnvironmentVariables($d)
        }
        $names = Get-IcsVendorNames
        foreach ($pf in @(Get-ProgramFilesDirs)) {
            foreach ($d in [System.IO.Directory]::GetDirectories($pf)) {
                if (Test-NameMatch ([System.IO.Path]::GetFileName($d)) $names) { $roots += $d }
            }
        }
        $depth = $script:QuickScanDepth
    }
    Write-RunLog ('  project scan: ' + $roots.Length + ' roots, depth ' + $depth + ', cap ' + $script:ScanFileCap + ' files, ' + $patterns.Length + ' patterns')
    $rows = @(Find-ProjectFiles -Roots $roots -Patterns $patterns -MaxDepth $depth -FileCap $script:ScanFileCap -SkipDirs $skip)
    $script:ProjectFiles = $rows
    Export-Table 'ot-project-files' $rows -NoText
}

function Step-EventLogs {
    $dir = Get-OutPath 'eventlogs'
    [void][System.IO.Directory]::CreateDirectory($dir)
    if (Test-Command 'wevtutil.exe') {
        $logs = @('Security', 'System', 'Application', 'Windows PowerShell',
            'Microsoft-Windows-PowerShell/Operational',
            'Microsoft-Windows-TaskScheduler/Operational',
            'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational',
            'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational',
            'Microsoft-Windows-Windows Defender/Operational')
        foreach ($l in $logs) {
            $f = 'eventlogs\' + ($l -replace '[/ ]', '_') + '.evtx'
            [void](Invoke-Native 'eventlogs\wevtutil.txt' ('wevtutil epl "' + $l + '" "' + (Get-OutPath $f) + '"') -Append -TimeoutSec 900)
        }
    } else {
        # XP / 2003: no wevtutil. BackupEventlog writes a copy to the stick and
        # needs the backup privilege (EnableAllPrivileges).
        Write-RunLog '  no wevtutil (pre-Vista): using Win32_NTEventlogFile.BackupEventlog'
        foreach ($l in @(Get-WmiObject -Class Win32_NTEventlogFile -EnableAllPrivileges)) {
            $f = Get-OutPath ('eventlogs\' + ($l.LogfileName -replace '[^A-Za-z0-9._-]', '_') + '.evt')
            $r = $l.BackupEventlog($f)
            Write-RunLog ('  BackupEventlog ' + $l.LogfileName + ' rc=' + $r.ReturnValue)
        }
    }
}

function Step-Hashes {
    $rows = @()
    $seen = @{}
    $targets = @()
    foreach ($p in @($script:ProcPaths)) { $targets += ,@('process', $p) }
    foreach ($s in @(Get-WmiObject -Class Win32_Service)) { $targets += ,@('service', (Get-ImagePath $s.PathName)) }
    foreach ($s in @(Get-WmiObject -Class Win32_SystemDriver)) { $targets += ,@('driver', (Get-ImagePath $s.PathName)) }
    $af = Get-OutPath 'autostart-files.csv'
    if (Test-Path -LiteralPath $af) {
        foreach ($r in @(Import-Csv -Path $af)) { if ($r) { $targets += ,@('startup-folder', $r.Path) } }
    }
    foreach ($r in @($script:ProjectFiles)) { if ($r) { $targets += ,@('ics-project', $r.Path) } }
    foreach ($t in $targets) {
        $path = [string]$t[1]
        if (-not $path) { continue }
        $k = $t[0] + '|' + $path.ToLower()
        if ($seen.ContainsKey($k)) { continue }
        $seen[$k] = $true
        $exists = Test-Path -LiteralPath $path
        $h = ''
        if ($exists) { $h = Get-CachedSha256 $path }
        $rows += New-Row @('Source', 'Path', 'Exists', 'Sha256') @($t[0], $path, $exists, $h)
    }
    Export-Table 'hashes' $rows -NoText
}

function Step-Recent {
    $rows = @()
    if ($env:SystemRoot) {
        foreach ($r in @(Get-FileRows -Dirs @($env:SystemRoot + '\Prefetch') -Filter '*.pf')) { if ($r) { $r | Add-Member NoteProperty Kind 'prefetch'; $rows += $r } }
    }
    foreach ($p in @(Get-ProfileDirs)) {
        $rec = @(($p + '\AppData\Roaming\Microsoft\Windows\Recent'), ($p + '\Recent'))
        foreach ($r in @(Get-FileRows -Dirs $rec -Filter '*.lnk')) { if ($r) { $r | Add-Member NoteProperty Kind 'recent'; $rows += $r } }
        $jl = @(($p + '\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations'), ($p + '\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations'))
        foreach ($r in @(Get-FileRows -Dirs $jl -Filter '*')) { if ($r) { $r | Add-Member NoteProperty Kind 'jumplist'; $rows += $r } }
    }
    Export-Table 'recent' $rows -NoText
}

# Sysinternals tools the operator dropped in user-supplied\ (not shipped:
# their licence forbids redistribution). -accepteula writes the EulaAccepted
# value under HKCU\Software\Sysinternals: logged as a footprint.
function Step-UserSupplied {
    param([string]$Kind)
    $us = [System.IO.Path]::Combine($script:WinDir, 'user-supplied')
    $list = ''
    if ([System.IO.Directory]::Exists($us)) {
        $list = (@(Get-ChildItem -LiteralPath $us -Force) | Format-Table Name, Length, LastWriteTime -AutoSize | Out-String -Width 512)
    }
    Write-Text 'user-supplied.txt' ("user-supplied folder: $us`r`n" + $list)
    $is64 = ([IntPtr]::Size -eq 8)
    $autoruns = ''
    foreach ($n in @('autorunsc64.exe', 'autorunsc.exe')) {
        $c = [System.IO.Path]::Combine($us, $n)
        if (-not $autoruns -and (Test-Path -LiteralPath $c) -and ($is64 -or $n -eq 'autorunsc.exe')) { $autoruns = $c }
    }
    $sigcheck = ''
    foreach ($n in @('sigcheck64.exe', 'sigcheck.exe')) {
        $c = [System.IO.Path]::Combine($us, $n)
        if (-not $sigcheck -and (Test-Path -LiteralPath $c) -and ($is64 -or $n -eq 'sigcheck.exe')) { $sigcheck = $c }
    }
    if ($Kind -ne 'full') {
        Write-RunLog ('  quick profile: user-supplied tools not run (autorunsc: ' + [bool]$autoruns + ', sigcheck: ' + [bool]$sigcheck + ')')
        return
    }
    if ($autoruns) {
        Write-RunLog '  footprint: autorunsc -accepteula sets HKCU\Software\Sysinternals\AutoRuns EulaAccepted'
        [void](Invoke-Native 'autoruns.csv' ('"' + $autoruns + '" -accepteula -nobanner -a * -c -h') -TimeoutSec 1200)
    } else { Write-RunLog '  autorunsc not present (normal)' }
    if ($sigcheck) {
        Write-RunLog '  footprint: sigcheck -accepteula sets HKCU\Software\Sysinternals\SigCheck EulaAccepted'
        Write-Text 'sigcheck.csv' ''
        foreach ($p in @($script:ProcPaths)) {
            [void](Invoke-Native 'sigcheck.csv' ('"' + $sigcheck + '" -accepteula -nobanner -c -h "' + $p + '"') -Append -TimeoutSec 120)
        }
    } else { Write-RunLog '  sigcheck not present (normal)' }
    foreach ($n in @('kape.exe', 'gkape.exe')) {
        if (Test-Path -LiteralPath ([System.IO.Path]::Combine($us, $n))) { Write-RunLog "  $n present: run KAPE by hand, it is not driven by this collector" }
    }
}

# ------------------------------------------------------------------- main

$script:Software = @()
$script:ProjectFiles = @()
$interactive = (-not $Yes) -and [Environment]::UserInteractive
if ($PSVersionTable.PSVersion.Major -lt 2) { Write-Warning 'PowerShell older than 2.0: continuing, expect gaps' }
$env:PSModulePath = [System.IO.Path]::Combine($PSHOME, 'Modules')

if (-not $Mode) {
    $Mode = 'quick'
    if ($interactive) {
        try {
            $a = Read-Host 'Profile: quick (low impact) or full? [quick]'
            if ($a -match '^(?i)f(ull)?$') { $Mode = 'full' }
        } catch { }
    }
}
$Mode = $Mode.ToLower()
if ($Mode -ne 'quick' -and $Mode -ne 'full') { Write-Error "unknown profile '$Mode' (quick or full)"; exit 2 }

$kitVersion = 'unknown'
$vf = [System.IO.Path]::Combine($script:KitRoot, 'VERSION')
if (Test-Path -LiteralPath $vf) { $kitVersion = ([string]@(Get-Content -LiteralPath $vf)[0]).Trim() }
$hostName = Get-SafeHost $env:COMPUTERNAME
$script:OutDir = [System.IO.Path]::Combine([System.IO.Path]::Combine($script:KitRoot, 'results'), ($hostName + '_' + (Get-UtcStamp)))
$expect = 'about 2 to 5 minutes'
if ($Mode -eq 'full') { $expect = 'about 10 to 60 minutes (event logs and the drive scan dominate)' }
$banner = @(
    ('SnapshOT field kit ' + $kitVersion + ': read-only collection to ' + $script:OutDir + ', profile ' + $Mode),
    ('Expected duration: ' + $expect + '.')
)
foreach ($b in $banner) { Write-Host $b }
if ($interactive) {
    try { [void](Read-Host 'Press Enter to start, or Ctrl+C to abort') } catch { }
}

[void][System.IO.Directory]::CreateDirectory($script:OutDir)
$script:LogFile = Get-OutPath 'run.log'
$script:ErrFile = Get-OutPath 'errors.txt'
Write-Text 'errors.txt' ''
$startUtc = Get-UtcNow
foreach ($b in $banner) { Write-RunLog $b }
Write-RunLog ('collector=Collect-Triage.ps1 version=' + $script:CollectorVersion + ' powershell=' + $PSVersionTable.PSVersion + ' clr=' + $PSVersionTable.CLRVersion)
Write-RunLog 'footprint: Windows may record this run in Prefetch (powershell.exe, cmd.exe and the tools it runs) and in process-creation audit events if enabled.'
Write-RunLog 'footprint: started with -NoProfile; PowerShell 2.0 keeps no command history file.'

$isAdmin = $false
try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }
if (-not $isAdmin) {
    $w = 'WARNING: not elevated: the Security log, other users'' details, Prefetch and some registry keys will be missing.'
    Write-Host $w
    Write-RunLog $w
}
$script:Hasher = New-Sha256
Write-RunLog ('hasher: ' + $script:HasherName)

# Most volatile first.
Invoke-Step 'processes' { Step-Processes }
Invoke-Step 'network' { Step-Network }
Invoke-Step 'services' { Step-Services }
Invoke-Step 'tasks' { Step-Tasks }
Invoke-Step 'autostart' { Step-Autostart }
Invoke-Step 'users' { Step-Users }
Invoke-Step 'system' { Step-System }
Invoke-Step 'netconfig' { Step-NetConfig }
Invoke-Step 'devices' { Step-Devices }
Invoke-Step 'ot-serial' { Step-OtSerial }
Invoke-Step 'ot-opc' { Step-OtOpc }
Invoke-Step 'ot-ics-software' { Step-OtSoftware }
Invoke-Step 'ot-project-files' { Step-OtProjects -Kind $Mode }
if ($Mode -eq 'full') {
    Invoke-Step 'eventlogs' { Step-EventLogs }
    Invoke-Step 'hashes' { Step-Hashes }
    Invoke-Step 'recent' { Step-Recent }
}
Invoke-Step 'user-supplied' { Step-UserSupplied -Kind $Mode }

$os = ''
try { $os = [string]@(Get-WmiObject -Class Win32_OperatingSystem)[0].Caption } catch { }
$sb = New-Object System.Text.StringBuilder
$kv = @(
    @('host', $hostName), @('os', $os.Trim()), @('os_version', [Environment]::OSVersion.VersionString),
    @('profile', $Mode), @('start_utc', $startUtc), @('end_utc', (Get-UtcNow)), @('stamp', 'utc'),
    @('collector', 'Collect-Triage.ps1'), @('collector_version', $script:CollectorVersion),
    @('kit_version', $kitVersion), @('powershell', [string]$PSVersionTable.PSVersion),
    @('user', ($env:USERDOMAIN + '\' + $env:USERNAME)), @('is_admin', [int]$isAdmin),
    @('steps_nonzero', $script:StepsNonZero), @('hasher', $script:HasherName)
)
foreach ($p in $kv) { [void]$sb.Append($p[0] + '=' + $p[1] + "`r`n") }
foreach ($k in @($script:Counts.Keys | Sort-Object)) { [void]$sb.Append('count_' + $k + '=' + $script:Counts[$k] + "`r`n") }
Write-Text 'summary.txt' $sb.ToString()
Write-RunLog 'summary.txt written; collection.txt and MANIFEST.sha256 follow (not logged after this line)'

$sb = New-Object System.Text.StringBuilder
foreach ($r in @(Get-OutFiles)) {
    if ($r.StartsWith('MANIFEST.sha256') -or $r -eq 'collection.txt') { continue }
    $fi = New-Object System.IO.FileInfo((Get-OutPath $r))
    [void]$sb.Append([string]$fi.Length + "`t" + $r + "`r`n")
}
Write-Text 'collection.txt' $sb.ToString()
if ($script:Hasher) { try { Write-Manifest } catch { Write-Host ('manifest failed: ' + $_.Exception.Message) } }
else { Write-Host 'No SHA-256 provider: no MANIFEST.sha256; the import manifest covers integrity from the stick on.' }
Write-Host ('Done: ' + $script:OutDir)
exit 0
