#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
& (Join-Path $workspace '_NonRelease/CoreSurfaceR1/PlanSpec.ps1')
if (-not $?) { throw 'Prior phase plans failed' }
. (Join-Path $workspace 'Tools/Release.Common.ps1')
$checks = 0
function Check($condition, $label) { $script:checks++; if (-not $condition) { throw $label } }
foreach ($target in @('Mists','Forever')) {
    $profile = Get-YiboReleaseProfile $workspace 'YiboCore' $target
    $paths = @((Get-YiboTocEntries $profile).Relative)
    Check ($paths -contains "$target/Metadata.lua") 'Explicit target metadata included'
    Check ([array]::IndexOf($paths,"$target/Metadata.lua") -lt [array]::IndexOf($paths,'Data/CharacterCleanup.lua')) 'Policy before cleanup owner list'
    Check ([array]::IndexOf($paths,"$target/Metadata.lua") -lt [array]::IndexOf($paths,'Data/AddonCatalog.lua')) 'Policy before catalog'
    $other = if ($target -eq 'Mists') { 'Forever' } else { 'Mists' }
    Check ($paths -notcontains "$other/Metadata.lua") 'No other target directory policy'
    $policy = Get-Content -LiteralPath (Join-Path $workspace "YiboCore/$target/Metadata.lua") -Raw
    $names = @([regex]::Matches($policy,'(?m)^    (Yibo[A-Za-z]+) = [{]') | ForEach-Object { $_.Groups[1].Value })
    Check ($names.Count -eq $(if ($target -eq 'Mists') {14} else {6})) "Declared business directory size: $target $($names.Count)"
    $versions = Get-YiboPackagedAddonVersions $workspace $profile
    Check ($versions.Count -eq $names.Count) 'Build version index matches applicable catalog'
    foreach ($name in $names) { Check ($versions.Contains($name)) "Version index includes $name" }
    Check (($names -contains 'YiboBeastPaths') -eq ($target -eq 'Mists')) 'YBP route metadata does not enable unsupported target'
}
Check (Test-Path -LiteralPath (Join-Path $workspace 'YiboCore/Retail/Target.lua')) 'R2 target is explicitly separated from prior targets'
Check ((Get-YiboReleaseProfile $workspace 'YiboCore' 'Retail').Client.SourceToc -eq 'YiboCore_Retail.toc') 'R2 source manifest uses standard target identity'
Write-Output "CoreMetadataContractsR1 PlanSpec passed: $checks checks (target metadata, version index and inherited retained-file build plans)"
