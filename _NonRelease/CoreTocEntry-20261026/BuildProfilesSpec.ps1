#Requires -Version 7.2
$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $workspace 'Tools/Release.Common.ps1')
$checks=0
function Check($condition,[string]$label) { $script:checks++; if(-not $condition) { throw $label } }
$plans=@{}
foreach($target in @('Mists','Forever')) {
    $profile=Get-YiboReleaseProfile $workspace YiboCore $target
    $entries=@(Get-YiboTocEntries $profile)
    Check ($profile.Client.SourceToc -eq "YiboCore_${target}.toc") 'Target must consume its own source manifest'
    Check ($profile.Client.LoadToc -eq 'YiboCore.toc') 'Player package must use the default loading name'
    Check ($profile.APIVersion -eq 13) 'API must be read independently of target version file'
    Check ('Common/TocHint.lua' -notin $entries.Relative) 'Hint must not replace a player package runtime'
    $other=if($target -eq 'Mists') {'Forever/'} else {'Mists/'}
    Check (-not @($entries | Where-Object {$_.Relative.StartsWith($other)}).Count) 'Other target must not leak into runtime'
    $versions=Get-YiboPackagedAddonVersions $workspace $profile
    Check ($versions.Contains('YiboCrafting')) 'Target version index must find applicable business source manifests'
    if($target -eq 'Forever') {
        Check ($profile.Version -eq '0.2.0' -and $versions.YiboCrafting -eq '0.1.2') 'Forever versions must not use MoP constants'
        Check (-not $versions.Contains('YiboLegendary')) 'Unimplemented target must not appear in package index'
    } else { Check ($profile.Version -eq '1.12.9') 'Mists runtime version preserved' }
    $plans[$target]=& (Join-Path $workspace 'Tools/Build-ReleasePackages.ps1') -Addon YiboCore -Target $target -ValidateOnly
}
Check ($plans.Mists.GitHub -eq $plans.Forever.GitHub) 'All-target source archive identity must be independent of selected build target'
Check ($plans.Forever.GitHub -match 'YiboCore-forever-mists-v1.12.9-api13-src\.') 'Source archive must use the canonical addon version and full target set'
Check ($plans.Forever.CurseForge -match 'YiboCore-forever-v0.2.0-api13-curseforge.zip$') 'Forever install version must remain independent'
Check ($plans.Mists.CurseForge -match 'YiboCore-mists-v1.12.9-api13-curseforge.zip$') 'Mists install name must remain stable'
Write-Output "Core build profile checks passed: $checks (validation only; no release artifacts)"
