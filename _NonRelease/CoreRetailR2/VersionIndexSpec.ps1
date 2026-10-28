#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $workspace 'Tools/Release.Common.ps1')
$configuration = Import-PowerShellDataFile -LiteralPath (Join-Path $workspace 'Tools/ReleaseProfiles.psd1')
$checks = 0
function Check($condition, $label) { $script:checks++; if (-not $condition) { throw $label } }
function Reject($callback, $label) {
    $rejected = $false
    try { & $callback | Out-Null } catch { $rejected = $true }
    Check $rejected $label
}
$bundle = $configuration.LegacyBundles.YiboBeastPaths
$root = Join-Path $workspace 'YiboBeastPaths'
$expected = (Read-YiboRequiredValue ([IO.File]::ReadAllText((Join-Path $root 'YiboBeastPaths.toc'))) '^## Version:[ ]*([^\r\n]+)' 'source version').TrimStart('v','V')
Check ((Get-YiboLegacyIndexedVersion $root $bundle 'Retail') -eq $expected) 'Retail selects explicitly mapped default/Mainline bundle versions'
Check ((Get-YiboLegacyIndexedVersion $root $bundle 'Mists') -eq $expected) 'Mists keeps existing bundle version'
Check ($null -eq (Get-YiboLegacyIndexedVersion $root $bundle 'Forever')) 'Unmapped Forever does not fall back to legacy default'
$retailQuery = [pscustomobject]@{ Config = $configuration; Target = 'Retail'; Interfaces = @() }
$index = Get-YiboPackagedAddonVersions $workspace $retailQuery
Check ($index.Count -eq 1 -and $index.YiboBeastPaths -eq $expected) 'Retail index records declared YBP source version without guessing Core Interface'
foreach ($target in @('Mists','Forever')) {
    $profile = Get-YiboReleaseProfile $workspace 'YiboCore' $target
    $versions = Get-YiboPackagedAddonVersions $workspace $profile
    Check ($versions.Count -eq $(if ($target -eq 'Mists') {14} else {6})) 'Existing target index size unchanged'
    Check (($versions.Contains('YiboBeastPaths')) -eq ($target -eq 'Mists')) 'Existing target YBP membership unchanged'
}
$broken = $bundle.Clone(); $broken.TocTargets = @('Retail')
Reject { Get-YiboLegacyIndexedVersion $root $broken 'Retail' } 'Incomplete mapping rejected'
$broken = $bundle.Clone(); $broken.Interfaces = @(1,1,1)
Reject { Get-YiboLegacyIndexedVersion $root $broken 'Retail' } 'Source Interface drift rejected'
$broken = $bundle.Clone(); $broken.SourceTocs = @('../YiboCore/YiboCore.toc','YiboBeastPaths_Mainline.toc','YiboBeastPaths_Mists.toc')
Reject { Get-YiboLegacyIndexedVersion $root $broken 'Retail' } 'Escaping bundle directory rejected'
Write-Output "CoreRetailR2 VersionIndexSpec passed: $checks checks (declarative source versions; no publication or runtime compatibility claim)"
