#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Package-Builds.json')) { throw 'R4 package snapshot already prepared; inspect it instead of rebuilding.' }
$runID = 'CoreR4-20261027-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$output = Join-Path $workspace "Builds/$runID"
New-Item -ItemType Directory -Path $output | Out-Null
$plans = @()
foreach ($target in @('Retail','Mists','Forever')) {
    $channel = if ($target -eq 'Retail') { 'Both' } else { 'CurseForge' }
    $plans += & (Join-Path $workspace 'Tools/Build-ReleasePackages.ps1') -Addon YiboCore -Target $target -Channel $channel -OutputRoot $output
}
$plans | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'Package-Builds.json') -Encoding utf8
$targets = @(
    @{Target='Retail';Project=1;Constant='WOW_PROJECT_MAINLINE';Interface=120105;Slash='/yra'},
    @{Target='Mists';Project=19;Constant='WOW_PROJECT_MISTS_CLASSIC';Interface=50504;Slash='/yrm'},
    @{Target='Forever';Project=18;Constant='WOW_PROJECT_CAMELOT';Interface=16001;Slash='/yrf'}
)
foreach ($target in $targets) {
    $name = 'YiboCore' + $target.Target + 'R4'
    $directory = Join-Path $workspace "_NonRelease/$name"
    if (Test-Path -LiteralPath $directory) { throw "Probe directory already exists: $directory" }
    New-Item -ItemType Directory -Path $directory | Out-Null
    $savedVariable = $name + 'DB'
    $slashID = $name.ToUpperInvariant()
    $config = "_G.YiboCoreR4ProbeTarget = { target = '$($target.Target)', project = $($target.Project), constant = '$($target.Constant)', savedVariable = '$savedVariable', slashID = '$slashID', slash = '$($target.Slash)' }"
    [IO.File]::WriteAllText((Join-Path $directory 'Target.lua'), $config + "`n", [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Probe.lua') -Destination (Join-Path $directory 'Probe.lua')
    $toc = "## Interface: $($target.Interface)`n## Title: |cff20e070[Yibo]|r Core $($target.Target) R4 Acceptance`n## Version: 0.1.0`n## RequiredDeps: YiboCore`n## SavedVariables: $savedVariable`n## LoadOnDemand: 0`nTarget.lua`nProbe.lua`n"
    [IO.File]::WriteAllText((Join-Path $directory "$name.toc"), $toc, [Text.UTF8Encoding]::new($false))
}
Write-Output "R4 frozen packages prepared in $output; no client files changed."
