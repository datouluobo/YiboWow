#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$plans = @()
foreach ($target in @('Retail','Mists','Forever')) {
    $plan = & (Join-Path $workspace 'Tools/Build-ReleasePackages.ps1') -Addon YiboCore -Target $target -ValidateOnly
    if (-not $plan.ValidationOnly -or $plan.APIVersion -ne 13) { throw 'Unexpected current build contract.' }
    $plans += $plan
}
$plans | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'Build-Plans.json') -Encoding utf8
Write-Output 'R5 current three-target plans validated; no packages created, moved or published.'
