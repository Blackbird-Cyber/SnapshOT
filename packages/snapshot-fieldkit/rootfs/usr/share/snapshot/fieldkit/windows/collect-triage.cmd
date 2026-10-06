@echo off
rem SnapshOT field kit: Windows collector launcher, and the built-in-only
rem fallback for hosts without PowerShell (XP / 2003).
rem
rem   collect-triage.cmd [quick^|full] [cmd] [-y]
rem
rem With PowerShell present this runs Collect-Triage.ps1 through
rem powershell.exe -NoProfile -ExecutionPolicy Bypass. "cmd" forces the
rem built-in-only collection below even when PowerShell exists (blocked or
rem closely watched PowerShell). Both write only to
rem <kit>\results\<HOST>_<STAMP>\ beside this script. The fallback uses only
rem tools that ship with Windows; it never deletes, never changes the registry,
rem services or tasks, and never opens serial ports.
rem Keep this file ASCII with CRLF line ends: cmd.exe misparses LF-only files.
setlocal EnableExtensions EnableDelayedExpansion

set "MODE="
set "FORCECMD="
set "YES="
:args
if "%~1"=="" goto argsdone
if /i "%~1"=="quick" ( set "MODE=quick" & shift & goto args )
if /i "%~1"=="full" ( set "MODE=full" & shift & goto args )
if /i "%~1"=="cmd" ( set "FORCECMD=1" & shift & goto args )
if /i "%~1"=="-y" ( set "YES=1" & shift & goto args )
if /i "%~1"=="/y" ( set "YES=1" & shift & goto args )
echo collect-triage.cmd: unknown argument: %1
echo usage: collect-triage.cmd [quick^|full] [cmd] [-y]
exit /b 2
:argsdone

rem A 32-bit cmd.exe on 64-bit Windows sees the 32-bit System32; Sysnative
rem reaches the 64-bit PowerShell.
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "PSEXE=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if defined FORCECMD goto fallback
if not exist "%PSEXE%" goto fallback

set "PSARGS="
if defined MODE set "PSARGS=-Mode %MODE%"
if defined YES set "PSARGS=%PSARGS% -Yes"
"%PSEXE%" -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%~dp0Collect-Triage.ps1" %PSARGS%
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo.
    echo The PowerShell collector exited with %RC%. If PowerShell is blocked on
    echo this host, run the built-in-only collection instead:
    echo     collect-triage.cmd cmd
)
if not defined YES pause
exit /b %RC%

rem ======================================================================
rem Built-in-only fallback.
rem ======================================================================
:fallback
for %%I in ("%~dp0..") do set "KIT=%%~fI"
set "WINKIT=%~dp0"
if "%WINKIT:~-1%"=="\" set "WINKIT=%WINKIT:~0,-1%"
set "PF86=%ProgramFiles(x86)%"
set "VERSION=unknown"
if exist "%KIT%\VERSION" set /p VERSION=<"%KIT%\VERSION"
set "COLLECTOR_VERSION=0.1.0"
set "QUICKDEPTH=4"
set "FULLDEPTH=8"
set "SCANCAP=20000"

if not defined MODE (
    set "MODE=quick"
    if not defined YES set /p "MODE=Profile: quick (low impact) or full? [quick] "
)
if /i "!MODE!"=="f" set "MODE=full"
if /i "!MODE!"=="full" (set "MODE=full") else (set "MODE=quick")

rem Host name limited to [A-Za-z0-9._-].
set "HN=%COMPUTERNAME%"
set "HOST="
for /l %%i in (0,1,31) do (
    set "CH=!HN:~%%i,1!"
    if defined CH call :safechar
)
if not defined HOST set "HOST=unknown"

rem Time stamp. wmic's LocalDateTime carries the UTC offset, so the folder
rem name and the summary are in UTC. Without wmic (XP Home, newest Windows),
rem %DATE% %TIME% are local and locale-formatted: the stamp is their digits
rem plus "L", and summary.txt says stamp=local with the time zone.
set "HAVEWMIC="
set "LDT="
for /f "skip=1 tokens=1" %%t in ('wmic os get LocalDateTime 2^>nul ^<nul') do if not defined LDT set "LDT=%%t"
if defined LDT if "!LDT:~14,1!"=="." set "HAVEWMIC=1"
if defined HAVEWMIC (
    call :utcstamp
    set "STAMPKIND=utc"
    set "STAMP=!UTCSTAMP!"
    set "START=!UTCISO!"
) else (
    set "STAMPKIND=local"
    set "RAWDT=%DATE% %TIME%"
    call :digits
    set "STAMP=!DIGITS!L"
    set "START=%DATE% %TIME%"
)
set "STARTDATE=%DATE%"
set "STARTTIME=%TIME%"
set "OUT=%KIT%\results\%HOST%_%STAMP%"

if /i "%MODE%"=="full" (set "EXPECT=about 10 to 60 minutes; the drive scan and event logs dominate") else (set "EXPECT=about 2 to 5 minutes")
echo SnapshOT field kit %VERSION%: read-only collection to %OUT%, profile %MODE%
echo Expected duration: %EXPECT%.
echo Built-in tools only (cmd fallback).
if not defined YES (
    echo Press Enter to start, or Ctrl+C to abort.
    pause >nul
)

if not exist "%KIT%\results" mkdir "%KIT%\results"
mkdir "%OUT%" || ( echo cannot create !OUT! & exit /b 1 )
set "LOG=%OUT%\run.log"
set "ERR=%OUT%\errors.txt"
set "NONZERO=0"
type nul >"%ERR%"
>>"%LOG%" echo [%DATE% %TIME%] SnapshOT field kit %VERSION%: read-only collection to %OUT%, profile %MODE%
>>"%LOG%" echo [%DATE% %TIME%] Expected duration: %EXPECT%.
>>"%LOG%" echo [%DATE% %TIME%] collector=collect-triage.cmd version=%COLLECTOR_VERSION% stamp=%STAMPKIND% wmic=%HAVEWMIC%
>>"%LOG%" echo [%DATE% %TIME%] step times in this log are local ^(%%DATE%% %%TIME%%^); see summary.txt for the zone
>>"%LOG%" echo [%DATE% %TIME%] footprint: Prefetch may record cmd.exe and the tools run; wmic may compile its aliases on first use.

set "ISADMIN=0"
net session >nul 2>&1 && set "ISADMIN=1"
if "%ISADMIN%"=="0" (
    echo WARNING: not elevated: the Security log, other users' details and some keys will be missing.
    >>"%LOG%" echo [%DATE% %TIME%] WARNING: not elevated
)

rem ---------------------------------------------------------------- steps
rem Most volatile first. Each step: set "C=<command>" then call :run <file>
rem (overwrite) or :runa <file> (append under a heading).
set "C=tasklist /v" & call :run tasklist.txt
set "C=tasklist /svc" & call :run tasklist-svc.txt
if defined HAVEWMIC (
    set "C=wmic process get CommandLine,CreationDate,ExecutablePath,Name,ParentProcessId,ProcessId" & call :run processes-wmic.txt
)
set "C=netstat -ano" & call :run netstat.txt

set "C=sc query type= service state= all" & call :run services-sc.txt
set "C=sc query type= driver state= all" & call :run drivers-sc.txt
set "C=reg query "HKLM\SYSTEM\CurrentControlSet\Services" /s /v ImagePath" & call :run services-imagepath.txt
if defined HAVEWMIC (
    set "C=wmic service get Name,DisplayName,State,StartMode,ProcessId,StartName,PathName" & call :run services-wmic.txt
)

set "C=schtasks /query /fo csv /v" & call :run schtasks.csv
for %%d in ("%SystemRoot%\Tasks" "%SystemRoot%\System32\Tasks") do (
    if exist "%%~d" ( set "C=dir /a /s "%%~d"" & call :runa task-files.txt )
)

for %%k in (
    "HKLM\Software\Microsoft\Windows\CurrentVersion\Run"
    "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    "HKLM\Software\Microsoft\Windows\CurrentVersion\RunServices"
    "HKLM\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce"
    "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"
    "HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"
    "HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
    "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
    "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Windows"
    "HKLM\Software\Microsoft\Active Setup\Installed Components"
    "HKLM\System\CurrentControlSet\Control\Session Manager\KnownDLLs"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Windows"
) do ( set "C=reg query %%k" & call :runa autostart.txt )
set "C=reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" /s /v Debugger" & call :runa autostart.txt
set "C=reg query "HKLM\System\CurrentControlSet\Control\Session Manager" /v BootExecute" & call :runa autostart.txt
type nul >"%OUT%\autostart-files.txt"
for %%d in ("%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup" "%ALLUSERSPROFILE%\Start Menu\Programs\Startup") do (
    if exist "%%~d" ( set "C=dir /a "%%~d"" & call :runa autostart-files.txt )
)
for /d %%p in ("%SystemDrive%\Users\*" "%SystemDrive%\Documents and Settings\*") do (
    if exist "%%~p\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" ( set "C=dir /a "%%~p\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"" & call :runa autostart-files.txt )
    if exist "%%~p\Start Menu\Programs\Startup" ( set "C=dir /a "%%~p\Start Menu\Programs\Startup"" & call :runa autostart-files.txt )
)
if defined HAVEWMIC (
    set "C=wmic /namespace:\\root\subscription path __EventFilter get Name,Query,QueryLanguage" & call :runa wmi-persistence.txt
    set "C=wmic /namespace:\\root\subscription path CommandLineEventConsumer get Name,CommandLineTemplate,ExecutablePath" & call :runa wmi-persistence.txt
    set "C=wmic /namespace:\\root\subscription path ActiveScriptEventConsumer get Name,ScriptingEngine,ScriptText" & call :runa wmi-persistence.txt
    set "C=wmic /namespace:\\root\subscription path __FilterToConsumerBinding get Consumer,Filter" & call :runa wmi-persistence.txt
)

set "C=net user" & call :run users.txt
if defined HAVEWMIC (
    set "C=wmic useraccount where "LocalAccount=True" get Name,SID,Disabled,Lockout,PasswordRequired" & call :run users-wmic.txt
)
set "C=net localgroup" & call :run groups.txt
for /f "tokens=1* delims=*" %%g in ('net localgroup 2^>nul ^<nul ^| findstr /b /l /c:"*"') do (
    set "C=net localgroup "%%g"" & call :runa groups.txt
)
set "C=query user" & call :run sessions.txt
set "C=net session" & call :runa sessions.txt

set "C=systeminfo" & call :run systeminfo.txt
set "C=ver" & call :run ver.txt
set "C=reg query "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation"" & call :run timezone.txt
if defined HAVEWMIC ( set "C=wmic qfe list" & call :run hotfixes.txt )
for %%k in (
    "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    "HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall"
) do ( set "C=reg query %%k /s" & call :runa software.txt )

set "C=ipconfig /all" & call :run ipconfig.txt
set "C=ipconfig /displaydns" & call :run dnscache.txt
set "C=arp -a" & call :run arp.txt
set "C=route print" & call :run routes.txt
set "C=nbtstat -c" & call :run nbtstat.txt
set "C=netsh advfirewall show allprofiles" & call :run firewall.txt
if not "!RC!"=="0" ( set "C=netsh firewall show config" & call :runa firewall.txt )
set "C=net share" & call :run shares.txt
set "C=net use" & call :run netuse.txt
set "C=type "%SystemRoot%\System32\drivers\etc\hosts"" & call :run hosts.txt
set "C=reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"" & call :run proxy.txt
if exist "%SystemRoot%\System32\wevtutil.exe" ( set "C=netsh winhttp show proxy" & call :runa proxy.txt ) else ( set "C=proxycfg" & call :runa proxy.txt )

set "C=reg query "HKLM\SYSTEM\CurrentControlSet\Enum\USBSTOR" /s" & call :run usbstor.txt
set "C=reg query "HKLM\SYSTEM\MountedDevices"" & call :run mounted-devices.txt
set "C=set" & call :run env.txt
if defined HAVEWMIC (
    set "C=wmic logicaldisk get DeviceID,DriveType,FileSystem,VolumeName,VolumeSerialNumber,Size,FreeSpace,ProviderName" & call :run disks.txt
)

rem ------------------------------------------------------------------- OT
rem Serial ports from the registry and PnP only: opening a port (mode COMx,
rem Win32_SerialPort) can toggle DTR/RTS and reset attached equipment.
set "C=reg query "HKLM\HARDWARE\DEVICEMAP\SERIALCOMM"" & call :run ot-serialcomm.txt
if defined HAVEWMIC (
    set "C=wmic path Win32_PnPEntity where "ClassGuid='{4D36E978-E325-11CE-BFC1-08002BE10318}'" get Name,DeviceID,Manufacturer,Status" & call :run ot-serial.txt
)

rem OPC servers: the category keys, then (Vista+ reg /f) the CLSIDs that
rem implement an OPC category, then each server's registration.
type nul >"%OUT%\ot-opc.txt"
for %%c in (
    "{63D5F430-CFE4-11D1-B2C8-0060083BA1FB}" "{63D5F432-CFE4-11D1-B2C8-0060083BA1FB}"
    "{CC603642-66D7-48F1-B69A-B625E73652D7}" "{3098EDA4-A006-48B2-A27F-247453959408}"
    "{58E13251-AC87-11D1-84D5-00608CB8A7E9}" "{7DE5B060-E089-11D2-A5E6-000086339399}"
) do ( set "C=reg query "HKCR\Component Categories\%%~c"" & call :runa ot-opc.txt )
type nul >"%OUT%\ot-opc-keys.txt"
for %%v in ("HKCR\CLSID" "HKCR\Wow6432Node\CLSID") do (
    for %%c in ("63D5F43" "CC603642-66D7" "3098EDA4-A006" "58E13251-AC87" "7DE5B060-E089") do (
        set "C=reg query %%v /s /k /f %%c" & call :runa ot-opc-keys.txt
    )
)
type nul >"%OUT%\ot-opc-servers.txt"
for /f "delims=" %%k in ('findstr /i /l /c:"Implemented Categories" "%OUT%\ot-opc-keys.txt" 2^>nul') do (
    set "K=%%k"
    set "K=!K:\Implemented Categories\=|!"
    for /f "tokens=1 delims=|" %%a in ("!K!") do ( set "C=reg query "%%a" /s" & call :runa ot-opc-servers.txt )
)

rem ICS software: vendor names from ics-vendors.txt, matched against the
rem Uninstall keys, Program Files folders, services and running processes.
type nul >"%OUT%\ot-vendor-patterns.txt"
for /f "usebackq tokens=1* delims=|" %%a in ("%WINKIT%\ics-vendors.txt") do (
    if /i "%%a"=="name" >>"%OUT%\ot-vendor-patterns.txt" echo %%b
)
>>"%LOG%" echo [%DATE% %TIME%] BEGIN ot-ics-software.txt :: Uninstall, Program Files, services, tasklist ^| findstr /g:ot-vendor-patterns.txt
type nul >"%OUT%\ot-ics-software.txt"
for %%k in (
    "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    "HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall"
) do (
    >>"%OUT%\ot-ics-software.txt" echo == software %%~k
    reg query %%k /s /v DisplayName 2>>"%ERR%" <nul | findstr /i /l /g:"%OUT%\ot-vendor-patterns.txt" >>"%OUT%\ot-ics-software.txt"
)
for %%d in ("%ProgramFiles%" "%PF86%") do (
    if not "%%~d"=="" if exist "%%~d" (
        >>"%OUT%\ot-ics-software.txt" echo == folders in %%~d
        dir /b /ad "%%~d" 2>>"%ERR%" <nul | findstr /i /l /g:"%OUT%\ot-vendor-patterns.txt" >>"%OUT%\ot-ics-software.txt"
    )
)
>>"%OUT%\ot-ics-software.txt" echo == services
sc query state= all 2>>"%ERR%" <nul | findstr /i /l /g:"%OUT%\ot-vendor-patterns.txt" >>"%OUT%\ot-ics-software.txt"
>>"%OUT%\ot-ics-software.txt" echo == processes
tasklist /v 2>>"%ERR%" <nul | findstr /i /l /g:"%OUT%\ot-vendor-patterns.txt" >>"%OUT%\ot-ics-software.txt"
>>"%LOG%" echo [%DATE% %TIME%] END   ot-ics-software.txt rc=0

rem ICS project files (listed, never copied). quick: the usual project
rem folders, 4 levels; full: every fixed drive, 8 levels. for /d skips hidden
rem folders, which also keeps the profile junctions out.
set "EXTS="
for /f "usebackq tokens=1" %%e in ("%WINKIT%\ics-extensions.txt") do (
    set "E=%%e"
    if "!E:~0,1!"=="." set "EXTS=!EXTS! *%%e"
)
set "NFOUND=0"
>"%OUT%\ot-project-files.csv" echo "Path","Size","Modified (local)"
>>"%LOG%" echo [%DATE% %TIME%] BEGIN ot-project-files.csv :: profile %MODE%
if /i "%MODE%"=="full" (
    set "MAXDEPTH=%FULLDEPTH%"
    if defined HAVEWMIC (
        for /f "skip=1 tokens=1" %%d in ('wmic logicaldisk where "DriveType=3" get DeviceID 2^>nul ^<nul') do (
            set "DRV=%%d"
            if "!DRV:~1,1!"==":" call :scan "!DRV!" 0
        )
    ) else (
        call :scan "%SystemDrive%" 0
    )
) else (
    set "MAXDEPTH=%QUICKDEPTH%"
    for /d %%p in ("%SystemDrive%\Users\*" "%SystemDrive%\Documents and Settings\*") do (
        for %%s in ("Documents" "My Documents" "Desktop") do if exist "%%~p\%%~s" call :scan "%%~p\%%~s" 0
    )
    if defined PUBLIC if exist "%PUBLIC%\Documents" call :scan "%PUBLIC%\Documents" 0
    if exist "%ALLUSERSPROFILE%\Documents" call :scan "%ALLUSERSPROFILE%\Documents" 0
    for /f "usebackq tokens=1* delims=|" %%a in ("%WINKIT%\ics-vendors.txt") do (
        if /i "%%a"=="dir" (
            call set "VD=%%b"
            if exist "!VD!" call :scan "!VD!" 0
        )
    )
    for %%d in ("%ProgramFiles%" "%PF86%") do (
        if not "%%~d"=="" if exist "%%~d" (
            for /f "delims=" %%v in ('dir /b /ad "%%~d" 2^>nul ^<nul ^| findstr /i /l /g:"%OUT%\ot-vendor-patterns.txt"') do call :scan "%%~d\%%v" 0
        )
    )
)
>>"%LOG%" echo [%DATE% %TIME%] END   ot-project-files.csv rc=0 files=!NFOUND! cap=%SCANCAP% depth=!MAXDEPTH!

rem ------------------------------------------------------------ full only
if /i not "%MODE%"=="full" goto summary
mkdir "%OUT%\eventlogs"
if exist "%SystemRoot%\System32\wevtutil.exe" (
    for %%l in (
        "Security" "System" "Application" "Windows PowerShell"
        "Microsoft-Windows-PowerShell/Operational"
        "Microsoft-Windows-TaskScheduler/Operational"
        "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"
        "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational"
    ) do (
        set "LN=%%~l"
        set "LN=!LN:/=_!"
        set "LN=!LN: =_!"
        set "C=wevtutil epl %%l "%OUT%\eventlogs\!LN!.evtx"" & call :runa eventlogs\wevtutil.txt
    )
) else if defined HAVEWMIC (
    rem XP / 2003: no wevtutil; BackupEventlog writes a copy to the stick.
    for %%l in (Application System Security) do (
        set "C=wmic /privileges:enable nteventlog where "LogfileName='%%l'" call BackupEventlog "%OUT%\eventlogs\%%l.evt"" & call :runa eventlogs\backup.txt
    )
) else (
    >>"%LOG%" echo [%DATE% %TIME%] no wevtutil and no wmic: event logs not collected
)
if exist "%SystemRoot%\Prefetch" ( set "C=dir /a /o:d /t:w "%SystemRoot%\Prefetch"" & call :runa recent.txt )
for /d %%p in ("%SystemDrive%\Users\*" "%SystemDrive%\Documents and Settings\*") do (
    if exist "%%~p\AppData\Roaming\Microsoft\Windows\Recent" ( set "C=dir /a /s /o:d /t:w "%%~p\AppData\Roaming\Microsoft\Windows\Recent"" & call :runa recent.txt )
    if exist "%%~p\Recent" ( set "C=dir /a /o:d /t:w "%%~p\Recent"" & call :runa recent.txt )
)

:summary
set "C=dir /a "%WINKIT%\user-supplied"" & call :run user-supplied.txt
>>"%LOG%" echo [%DATE% %TIME%] user-supplied tools are not run by the cmd fallback

set "TZLINE="
for /f "delims=" %%z in ('findstr /i /c:"Time Zone" "%OUT%\systeminfo.txt" 2^>nul') do if not defined TZLINE set "TZLINE=%%z"
set "TZBIAS="
for /f "tokens=3" %%b in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v ActiveTimeBias 2^>nul ^<nul ^| findstr /i "ActiveTimeBias"') do set /a "TZBIAS=%%b"
set "OSVER="
for /f "delims=" %%o in ('ver') do if not "%%o"=="" set "OSVER=%%o"
if defined HAVEWMIC (
    set "LDT="
    for /f "skip=1 tokens=1" %%t in ('wmic os get LocalDateTime 2^>nul ^<nul') do if not defined LDT set "LDT=%%t"
    call :utcstamp
    set "END=!UTCISO!"
) else (
    set "END=%DATE% %TIME%"
)
set "HASHER=none"
certutil -hashfile "%LOG%" SHA256 >nul 2>&1 && set "HASHER=certutil"

>"%OUT%\summary.txt" (
    echo host=!HOST!
    echo os=!OSVER!
    echo profile=!MODE!
    echo start=!START!
    echo end=!END!
    echo stamp=!STAMPKIND!
    echo local_start_date=!STARTDATE!
    echo local_start_time=!STARTTIME!
    echo tz=!TZLINE!
    echo tz_active_bias_minutes=!TZBIAS!
    echo collector=collect-triage.cmd
    echo collector_version=!COLLECTOR_VERSION!
    echo kit_version=!VERSION!
    echo user=!USERDOMAIN!\!USERNAME!
    echo is_admin=!ISADMIN!
    echo wmic=!HAVEWMIC!
    echo project_files=!NFOUND!
    echo steps_nonzero=!NONZERO!
    echo hasher=!HASHER!
)
>>"%LOG%" echo [%DATE% %TIME%] summary.txt written; collection.txt and MANIFEST.sha256 follow (not logged after this line)

type nul >"%OUT%\collection.txt"
for /r "%OUT%" %%F in (*) do (
    set "R=%%~fF"
    set "R=!R:%OUT%\=!"
    set "R=!R:\=/!"
    if /i not "!R!"=="collection.txt" >>"%OUT%\collection.txt" echo %%~zF	!R!
)
if "%HASHER%"=="certutil" (
    type nul >"%OUT%\MANIFEST.sha256.tmp"
    for /r "%OUT%" %%F in (*) do (
        set "R=%%~fF"
        set "R=!R:%OUT%\=!"
        set "R=!R:\=/!"
        if /i not "!R:~0,15!"=="MANIFEST.sha256" call :hashone "%%~fF" "%%~zF"
    )
    move /y "%OUT%\MANIFEST.sha256.tmp" "%OUT%\MANIFEST.sha256" >nul
) else (
    echo No SHA-256 tool on this host: no MANIFEST.sha256; the import manifest covers integrity from the stick on.
)
echo Done: %OUT%
if not defined YES pause
exit /b 0

rem ----------------------------------------------------------- subroutines

rem :run <file>: run !C! into <file> in the results folder; log BEGIN/END rc.
:run
>>"%LOG%" echo [%DATE% %TIME%] BEGIN %~1 :: !C!
!C! >"%OUT%\%~1" 2>>"%ERR%" <nul
set "RC=!ERRORLEVEL!"
if not "!RC!"=="0" set /a NONZERO+=1
>>"%LOG%" echo [%DATE% %TIME%] END   %~1 rc=!RC!
goto :eof

rem :runa <file>: the same, appending under a "== command" heading.
:runa
>>"%OUT%\%~1" echo.
>>"%OUT%\%~1" echo == !C!
>>"%LOG%" echo [%DATE% %TIME%] BEGIN %~1 :: !C!
!C! >>"%OUT%\%~1" 2>>"%ERR%" <nul
set "RC=!ERRORLEVEL!"
if not "!RC!"=="0" set /a NONZERO+=1
>>"%LOG%" echo [%DATE% %TIME%] END   %~1 rc=!RC!
goto :eof

rem :safechar: append !CH! to HOST when it is in [A-Za-z0-9._-], else "_".
:safechar
for %%a in (0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z . _ -) do (
    if /i "!CH!"=="%%a" ( set "HOST=!HOST!%%a" & goto :eof )
)
set "HOST=!HOST!_"
goto :eof

rem :digits: DIGITS = the digits of !RAWDT!.
:digits
set "DIGITS="
for /l %%i in (0,1,40) do (
    set "CH=!RAWDT:~%%i,1!"
    for %%a in (0 1 2 3 4 5 6 7 8 9) do if "!CH!"=="%%a" set "DIGITS=!DIGITS!%%a"
)
goto :eof

rem :utcstamp: UTCSTAMP (yyyymmddTHHMMSSZ) and UTCISO from wmic's !LDT!
rem (yyyymmddHHMMSS.ffffff+UUU, UUU = offset in minutes). Civil-date
rem arithmetic after H. Hinnant's days_from_civil / civil_from_days; the
rem leading "1" keeps set /a from reading 08 and 09 as octal.
:utcstamp
set /a "Y=1!LDT:~0,4!-10000, M=1!LDT:~4,2!-100, D=1!LDT:~6,2!-100, HH=1!LDT:~8,2!-100, MI=1!LDT:~10,2!-100"
set "SS=!LDT:~12,2!"
set /a "OFS=1!LDT:~22,3!-1000"
if "!LDT:~21,1!"=="-" set /a "OFS=-OFS"
if !M! LEQ 2 (set /a "YY=Y-1, MM=M+9") else (set /a "YY=Y, MM=M-3")
set /a "ERA=YY/400, YOE=YY-ERA*400, DOY=(153*MM+2)/5+D-1, DOE=YOE*365+YOE/4-YOE/100+DOY, DAYS=ERA*146097+DOE-719468"
set /a "T=DAYS*1440+HH*60+MI-OFS"
set /a "DAYS=T/1440, RM=T%%1440, HH=RM/60, MI=RM%%60"
set /a "Z=DAYS+719468, ERA=Z/146097, DOE=Z-ERA*146097"
set /a "YOE=(DOE-DOE/1460+DOE/36524-DOE/146096)/365"
set /a "YY=YOE+ERA*400, DOY=DOE-(365*YOE+YOE/4-YOE/100), MP=(5*DOY+2)/153"
set /a "D=DOY-(153*MP+2)/5+1"
if !MP! LSS 10 (set /a "M=MP+3") else (set /a "M=MP-9")
if !M! LEQ 2 set /a "YY+=1"
set "M=0!M!" & set "D=0!D!" & set "HH=0!HH!" & set "MI=0!MI!"
set "M=!M:~-2!" & set "D=!D:~-2!" & set "HH=!HH:~-2!" & set "MI=!MI:~-2!"
set "UTCSTAMP=!YY!!M!!D!T!HH!!MI!!SS!Z"
set "UTCISO=!YY!-!M!-!D!T!HH!:!MI!:!SS!Z"
goto :eof

rem :scan <dir> <depth>: list project files in <dir>, recurse below MAXDEPTH.
:scan
if !NFOUND! GEQ %SCANCAP% goto :eof
setlocal
set "SD=%~1"
if "!SD:~-1!"=="\" set "SD=!SD:~0,-1!"
set /a "SDEP=%~2"
for %%x in (%EXTS%) do for %%f in ("!SD!\%%x") do (
    >>"%OUT%\ot-project-files.csv" echo "%%~ff",%%~zf,"%%~tf"
    set /a NFOUND+=1
)
if !SDEP! GEQ !MAXDEPTH! goto scanend
set /a "NEXT=SDEP+1"
for /d %%s in ("!SD!\*") do if /i not "%%~fs"=="%SystemRoot%" call :scan "%%~fs" !NEXT!
:scanend
endlocal & set "NFOUND=%NFOUND%"
goto :eof

rem :hashone <path> <size>: append "<sha256>  <relative path>" to the manifest.
rem certutil prints the hash on its second line (with spaces before Windows 8)
rem and fails on empty files, whose SHA-256 is fixed. A file it cannot hash
rem is reported on the console only: errors.txt is already in the manifest.
:hashone
set "H="
if "%~2"=="0" (
    set "H=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
) else (
    for /f "skip=1 delims=" %%h in ('certutil -hashfile "%~1" SHA256 2^>nul') do if not defined H set "H=%%h"
)
set "H=!H: =!"
if not "!H:~63,1!"=="" if "!H:~64,1!"=="" (
    >>"%OUT%\MANIFEST.sha256.tmp" echo !H!  !R!
    goto :eof
)
echo manifest: cannot hash !R!
goto :eof
