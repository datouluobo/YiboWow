#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $workspace 'Tools/Release.Common.ps1')
$checks = 0
function Check($condition, $label) {
    $script:checks++
    if (-not $condition) { throw $label }
}
$baseline = Get-Content -LiteralPath (Join-Path $workspace 'YiboCore/Docs/Retail-R0-源码基线.json') -Raw | ConvertFrom-Json -AsHashtable
foreach ($target in @('Mists', 'Forever')) {
    $profile = Get-YiboReleaseProfile $workspace 'YiboCore' $target
    $entries = @(Get-YiboTocEntries $profile)
    $paths = @($entries.Relative)
    Check ($profile.Client.LoadToc -eq 'YiboCore.toc') 'Player package retains one default load manifest'
    Check ($profile.APIVersion -eq 13) 'Public API retained'
    Check ($profile.Version -eq $(if ($target -eq 'Mists') { '1.12.9' } else { '0.2.0' })) 'Target version retained'
    Check ($paths.Count -eq $(if ($target -eq 'Mists') {62} else {59})) 'Expected source graph size after target metadata adaptation'
    Check ($paths -contains "$target/Target.lua") 'Explicit target loaded'
    Check ($paths -contains 'Data/Validation.lua') 'Store preflight is loaded'
    Check ($paths[-1] -eq 'Runtime/Lifecycle.lua') 'Lifecycle starts after dependencies and domain registration'
    Check ($paths -notcontains 'Common/TocHint.lua') 'Target player package excludes Hint'
    Check (($paths | Select-Object -Unique).Count -eq $paths.Count) 'No duplicate loads'
    # A virtual overlay retains every old file, then replaces matching paths.
    # All new references must resolve in that union; residual files add no load edges.
    $overlay = @{}
    foreach ($old in $baseline.files.Keys) { $overlay[$old] = 'retained-old-file' }
    foreach ($file in Get-ChildItem -LiteralPath $profile.Root -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($profile.Root, $file.FullName).Replace('\', '/')
        $overlay[$relative] = $file.FullName
    }
    foreach ($entry in $entries) {
        Check ($overlay.ContainsKey($entry.Relative) -and (Test-Path -LiteralPath $entry.Source -PathType Leaf)) 'Overlay reference resolves to current source'
    }
    $other = if ($target -eq 'Mists') { 'Forever' } else { 'Mists' }
    Check (@($paths | Where-Object { $_.StartsWith("$other/") }).Count -eq 0) 'Other target source excluded'
    Check (@($paths | Where-Object { $_ -match 'Economy|CurrencyCatalog|Reputation.lua' }).Count -eq 0) 'Retired source excluded even when files remain'
    Check ($profile.TocText -match $(if ($target -eq 'Mists') { 'SavedVariables: YiboCoreDB\s' } else { 'SavedVariables: YiboCoreForeverDB\s' })) 'SavedVariables identity retained'
    $plan = & (Join-Path $workspace 'Tools/Build-ReleasePackages.ps1') -Addon YiboCore -Target $target -ValidateOnly
    Check ($plan.ValidationOnly -and $plan.Interface.Count -eq 1) 'Unified target/Interface/reference/Lua checks pass without package mutation'
}
Check ((Get-YiboReleaseProfile $workspace 'YiboCore' 'Retail').Client.DevelopmentToc -eq 'YiboCore_Mainline.toc') 'R2 native development mapping explicitly registered; earlier evidence remains frozen'
Write-Output "CoreStartupR1 PlanSpec passed: $checks checks (source graphs and virtual retained-file overlays; no installation package created)"
