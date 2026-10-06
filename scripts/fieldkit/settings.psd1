@{
  IncludeRules = @('PSUseCompatibleSyntax','PSUseCompatibleCommands','PSUseCompatibleTypes','PSAvoidUsingCmdletAliases','PSUseDeclaredVarsMoreThanAssignments')
  Rules = @{
    PSUseCompatibleSyntax = @{ Enable = $true; TargetVersions = @('3.0') }
    PSUseCompatibleCommands = @{ Enable = $true; TargetProfiles = @('win-8_x64_6.2.9200.0_3.0_x64_4.0.30319.42000_framework') }
    PSUseCompatibleTypes = @{ Enable = $true; TargetProfiles = @('win-8_x64_6.2.9200.0_3.0_x64_4.0.30319.42000_framework') }
  }
}
