# ps2-lint self-test: every non-comment line below must be flagged
# (scripts/check-fieldkit.sh asserts it). Never run this file.
$h = [ordered]@{ a = 1 }
$o = [pscustomobject]@{ b = 2 }
$x = Get-CimInstance Win32_Process
$j = $o | ConvertTo-Json
$f = Get-FileHash C:\Windows\notepad.exe
$c = Get-NetTCPConnection
$n = (Get-Process).Name
$p = Get-Process | Where-Object Name -eq 'svchost'
if ('a' -in @('a','b')) { }
$x = 1 -notin 2
$r = Get-Content C:\x.txt -Raw
Get-ChildItem C:\ -File | Out-Null
$s = $PSScriptRoot
class Foo { }
$t = [System.Text.StringBuilder]::new()
Get-Process | Export-Csv C:\x.csv -Append -NoTypeInformation
Get-Process | Export-Csv -LiteralPath C:\x.csv -NoTypeInformation
$i = Import-Csv -LiteralPath C:\x.csv
Get-Item C:\ -ErrorAction Ignore
$u = Get-LocalUser
$v = Get-ScheduledTask
$e = [System.IO.Directory]::EnumerateFiles('C:\')
$w = [string]::IsNullOrWhiteSpace($x)
$q = [System.IO.Path]::Combine('C:\', 'a', 'b')
