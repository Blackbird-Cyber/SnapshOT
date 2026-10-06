# PowerShell 2.0 compatibility lint for the field kit's Windows collector.
#
#   pwsh -NoProfile -File scripts/fieldkit/ps2-lint.ps1 -Path <file.ps1> [...]
#
# PSScriptAnalyzer has no PowerShell 2.0 profile (its oldest is Windows 8 /
# PowerShell 3.0) and its compatibility rules miss most PS 3+ constructs, so
# this walks the AST itself. Run by scripts/check-fieldkit.sh under pwsh 7;
# the deny lists below are not exhaustive, so a reviewer still reads the
# collector. scripts/fieldkit/ps2-lint-sample.ps1 holds one offending line per
# rule; the check asserts that every line of it is flagged.
param([Parameter(Mandatory=$true)][string[]]$Path)
$ErrorActionPreference = 'Stop'

# Cmdlets that do not exist in PowerShell 2.0 (value: the version that added them).
$badCommands = @{
  'Get-CimInstance'=3; 'Invoke-CimMethod'=3; 'New-CimSession'=3; 'Get-CimAssociatedInstance'=3
  'ConvertTo-Json'=3; 'ConvertFrom-Json'=3; 'Invoke-RestMethod'=3; 'Invoke-WebRequest'=3
  'Get-FileHash'=4; 'Get-NetTCPConnection'=3; 'Get-NetUDPEndpoint'=3; 'Get-NetIPAddress'=3
  'Get-NetAdapter'=3; 'Get-NetRoute'=3; 'Get-NetNeighbor'=3; 'Get-DnsClientCache'=3; 'Get-NetFirewallProfile'=3
  'Get-ScheduledTask'=3; 'Get-ScheduledTaskInfo'=3; 'Get-SmbShare'=3; 'Get-SmbSession'=3
  'Get-LocalUser'=5; 'Get-LocalGroup'=5; 'Get-LocalGroupMember'=5; 'Get-WinEvent'=2
  'New-TemporaryFile'=5; 'Expand-Archive'=5; 'Compress-Archive'=5; 'Get-ItemPropertyValue'=5
  'Get-Volume'=3; 'Get-Disk'=3; 'Get-PnpDevice'=4; 'Get-ComputerInfo'=5; 'Get-TimeZone'=5
  'Write-Information'=5; 'Unblock-File'=3; 'Resolve-DnsName'=3; 'Test-NetConnection'=3
}
# Get-WinEvent exists in PS2 but needs Vista+; listed so its use is a deliberate exception.

# Parameters PS 3+ added to cmdlets that PS 2.0 does have.
$badParams = @{
  'Get-ChildItem' = @('File','Directory','Depth','Attribute','Hidden','ReadOnly','System')
  'Get-Content'   = @('Raw','Stream')
  'Export-Csv'    = @('Append','LiteralPath')
  'Import-Csv'    = @('LiteralPath','Encoding')
  'Out-File'      = @('NoNewline')
  'Set-Content'   = @('NoNewline')
  'Add-Content'   = @('NoNewline')
  'Select-Object' = @('SkipLast')
  'Get-Item'      = @('Stream')
}
$badTypes = @('ordered','pscustomobject','System.Management.Automation.PSCustomObject')
$badOps = @('Iin','Inotin','Cin','Cnotin','Shl','Shr')
# .NET 4+ members: PowerShell 2.0 runs on CLR 2.0 (.NET 2.0 to 3.5).
$badMembers = @('EnumerateFiles','EnumerateDirectories','EnumerateFileSystemEntries','IsNullOrWhiteSpace','HasFlag','CopyTo','ReadLines')

$fail = 0
foreach ($p in $Path) {
  $tokens = $null; $errs = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tokens, [ref]$errs)
  foreach ($e in $errs) { "{0}:{1}: parse error: {2}" -f $p, $e.Extent.StartLineNumber, $e.Message; $fail++ }
  $hits = $ast.FindAll({ $true }, $true)
  foreach ($n in $hits) {
    $line = $n.Extent.StartLineNumber; $msg = $null
    switch ($n.GetType().Name) {
      'CommandAst' {
        $name = $n.GetCommandName()
        if ($name -and $badCommands.ContainsKey($name) -and $name -ne 'Get-WinEvent') { $msg = "command $name needs PowerShell $($badCommands[$name])+" }
        if ($name -and $badParams.ContainsKey($name)) {
          foreach ($el in $n.CommandElements) {
            if ($el -is [System.Management.Automation.Language.CommandParameterAst] -and ($badParams[$name] -contains $el.ParameterName)) {
              $msg = "$name -$($el.ParameterName) is not in PowerShell 2.0" }
          }
        }
        if ($name -eq 'Where-Object' -or $name -eq 'ForEach-Object' -or $name -eq '?' -or $name -eq '%') {
          $args1 = @($n.CommandElements | Select-Object -Skip 1)
          if ($args1.Count -gt 0 -and -not ($args1 | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] })) {
            $msg = "$name simplified syntax needs PowerShell 3+; use a script block" }
        }
        foreach ($el in $n.CommandElements) {
          if ($el -is [System.Management.Automation.Language.CommandParameterAst] -and $el.ParameterName -eq 'ErrorAction' -and $el.Argument -and $el.Argument.Extent.Text -match 'Ignore') { $msg = "-ErrorAction Ignore needs PowerShell 3+" }
        }
        if ($n.CommandElements.Count -ge 3) {
          for ($i = 0; $i -lt $n.CommandElements.Count - 1; $i++) {
            $el = $n.CommandElements[$i]
            if ($el -is [System.Management.Automation.Language.CommandParameterAst] -and $el.ParameterName -eq 'ErrorAction' -and -not $el.Argument -and $n.CommandElements[$i+1].Extent.Text -match '^[''"]?Ignore') { $msg = "-ErrorAction Ignore needs PowerShell 3+" }
          }
        }
      }
      'TypeExpressionAst'  { if ($badTypes -contains $n.TypeName.FullName) { $msg = "[$($n.TypeName.FullName)] needs PowerShell 3+" } }
      'ConvertExpressionAst' { if ($badTypes -contains $n.Type.TypeName.FullName) { $msg = "[$($n.Type.TypeName.FullName)] cast needs PowerShell 3+" } }
      'BinaryExpressionAst' { if ($badOps -contains "$($n.Operator)") { $msg = "operator -$($n.Operator) needs PowerShell 3+" } }
      'VariableExpressionAst' {
        $v = $n.VariablePath.UserPath
        if ($v -eq 'PSItem' -or $v -eq 'PSScriptRoot' -or $v -eq 'PSCommandPath') { $msg = "`$$v needs PowerShell 3+ in scripts" }
        if ($n.VariablePath.DriveName -eq 'using') { $msg = "`$using: needs PowerShell 3+" }
      }
      'InvokeMemberExpressionAst' {
        $m = $n.Member.Extent.Text
        if ($n.Static -and $m -eq 'new') { $msg = "::new() needs PowerShell 5+" }
        elseif ($badMembers -contains $m) { $msg = ".$m() needs .NET 4 (PowerShell 2.0 runs on CLR 2.0)" }
        elseif ($n.Static -and $m -eq 'Combine' -and $n.Expression.Extent.Text -match 'IO\.Path\]$' -and @($n.Arguments).Count -gt 2) {
          $msg = "Path.Combine with more than two arguments needs .NET 4" }
      }
      'TypeDefinitionAst' { $msg = "class/enum needs PowerShell 5+" }
      'UsingStatementAst' { $msg = "using statement needs PowerShell 5+" }
      'MemberExpressionAst' {
        if (-not $n.Static -and $n.Expression -is [System.Management.Automation.Language.ParenExpressionAst] -and $n.Expression.Pipeline.Extent.Text -match '^\s*[A-Za-z]+-[A-Za-z]+' -and $n.Member.Extent.Text -notin @('Count','Length')) {
          $msg = "possible member enumeration ($($n.Extent.Text)) needs PowerShell 3+; use ForEach-Object or Select-Object -ExpandProperty" }
      }
    }
    if ($msg) { "{0}:{1}: {2}" -f $p, $line, $msg; $fail++ }
  }
  # Non-ASCII bytes: PS2 reads BOM-less scripts in the ANSI code page.
  $bytes = [System.IO.File]::ReadAllBytes($p)
  for ($i = 0; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -gt 127) { "{0}: non-ASCII byte at offset {1}" -f $p, $i; $fail++; break } }
}
if ($fail) { "ps2-lint: $fail problem(s)"; exit 1 } else { "ps2-lint: OK"; exit 0 }
