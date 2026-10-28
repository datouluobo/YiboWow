#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $workspace 'Tools/Release.Common.ps1')
$checks = 0
function Check($condition, $label) { $script:checks++; if (-not $condition) { throw $label } }
$plans = @()
foreach ($target in @('Mists','Forever','Retail')) {
    $profile = Get-YiboReleaseProfile $workspace 'YiboCore' $target
    $entries = @(Get-YiboTocEntries $profile)
    $paths = @($entries.Relative)
    Check ($profile.Client.LoadToc -eq 'YiboCore.toc') 'Player package uses exactly the default loading name'
    Check ($paths.Count -eq @{Mists=62;Forever=59;Retail=56}[$target]) 'Expected target graph size'
    Check (($paths | Select-Object -Unique).Count -eq $paths.Count) 'No duplicate load references'
    foreach ($other in @('Mists','Forever','Retail') | Where-Object { $_ -ne $target }) {
        Check (@($paths | Where-Object { $_.StartsWith("$other/") }).Count -eq 0) 'Other target code excluded'
    }
    Check ($paths[0] -eq 'Libs/LibStub/LibStub.lua' -and $paths[-1] -eq 'Runtime/Lifecycle.lua') 'Native lifecycle after all definitions'
    Check ($paths -notcontains 'Common/TocHint.lua') 'Player target excludes source Hint'
    $caps = @{}
    foreach ($entry in $entries) {
        $text = [IO.File]::ReadAllText($entry.Source)
        foreach ($match in [regex]::Matches($text, 'Capabilities:Register[(]"([^"]+)",[ ]*([0-9]+)[)]')) {
            $caps[$match.Groups[1].Value] = [int]$match.Groups[2].Value
        }
        Check ($text -notmatch '(?:dofile|loadfile|LoadAddOn)[ ]*[(]') 'No indirect runtime code loads'
    }
    Check ($caps.Count -eq $(if ($target -eq 'Retail') {32} else {33})) 'Only implemented capabilities declared'
    $plan = & (Join-Path $workspace 'Tools/Build-ReleasePackages.ps1') -Addon YiboCore -Target $target -ValidateOnly
    Check ($plan.ValidationOnly -and $plan.Interface.Count -eq 1) 'Unified Interface/reference/package plan validated'
    Check ((Split-Path $plan.GitHub -Leaf) -match 'forever-mists-retail') 'Source archive contains explicitly registered three-target set'
    $plans += $plan
}
$retail = Get-YiboReleaseProfile $workspace 'YiboCore' 'Retail'
Check ($retail.Version -eq '0.1.0' -and $retail.APIVersion -eq 13 -and $retail.Interfaces[0] -eq 120105) 'Retail version and measured Interface explicit'
Check ($retail.Client.SourceToc -eq 'YiboCore_Mainline.toc' -and -not $retail.Client.ContainsKey('DevelopmentToc')) 'Single measured Mainline source'
Check (-not (Test-Path (Join-Path $retail.Root 'YiboCore_Retail.toc'))) 'Redundant Retail source absent'
Check ($retail.TocText -match 'SavedVariables: YiboCoreRetailDB') 'Independent Retail SavedVariables identity'
Check (@(Get-YiboTocEntries $retail | Where-Object { $_.Relative -match 'Professions|Equipment|Specialization|Location|Calendar' }).Count -eq 0) 'Retail does not import deferred collectors'
Check ((Get-YiboPackagedAddonVersions $workspace $retail).YiboBeastPaths -eq '1.8.3') 'Current Retail bundle version indexed'
$plans | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'Build-Plans.json') -Encoding utf8
Write-Output "CoreRetailR2 PlanSpec passed: $checks checks (three targets, source/native alias, capability declarations and unified plans)"
