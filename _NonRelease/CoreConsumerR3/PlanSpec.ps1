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
    Check ($entries.Count -eq @{ Mists=62; Forever=59; Retail=56 }[$target]) 'Production load graph unchanged'
    Check (@($entries | Where-Object { $_.Relative -match 'CoreConsumerR3|_NonRelease|Consumer[.]lua' }).Count -eq 0) 'Synthetic consumer excluded from production TOC'
    Check ($profile.Client.LoadToc -eq 'YiboCore.toc') 'Single-target player loading name unchanged'
    foreach ($other in @('Retail','Mists','Forever') | Where-Object { $_ -ne $target }) {
        Check (@($entries | Where-Object { $_.Relative.StartsWith("$other/") }).Count -eq 0) 'Other-target code excluded'
    }
    $plan = & (Join-Path $workspace 'Tools/Build-ReleasePackages.ps1') -Addon YiboCore -Target $target -ValidateOnly
    Check ($plan.ValidationOnly -and $plan.APIVersion -eq 13) 'Unified builder validates API, Interface, references, syntax and package plan'
    Check ($plan.Version -eq @{ Mists='1.12.9'; Forever='0.2.0'; Retail='0.1.0' }[$target]) 'No target version bump for verification-only phase'
    Check ((Split-Path $plan.GitHub -Leaf) -match 'forever-mists-retail') 'Three-target source archive identity unchanged'
    $plans += $plan
}
$retail = Get-YiboReleaseProfile $workspace 'YiboCore' 'Retail'
Check ($retail.Client.SourceToc -eq 'YiboCore_Mainline.toc' -and -not $retail.Client.ContainsKey('DevelopmentToc')) 'Single measured Retail source'
Check ($retail.Interfaces[0] -eq 120105) 'Measured Retail Interface retained'
$plans | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'Build-Plans.json') -Encoding utf8
Write-Output "CoreConsumerR3 PlanSpec passed: $checks checks (current unified three-target build validation; no packages created or moved)"
