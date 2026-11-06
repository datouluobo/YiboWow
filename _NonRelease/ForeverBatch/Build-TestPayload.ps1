[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$entries = @('YiboCore', 'YiboBuilds', 'YiboCrafting', 'YiboCurrency', 'YiboMail', 'YiboReputation', 'YiboVault') |
    ForEach-Object { @{ Name = $_; Base = Join-Path $root $_; Toc = "${_}_Forever.toc"; Kind = 'development' } }
$entries += @('YiboAltoBossForeverProbe', 'YiboBuildsForeverProbe', 'YiboProgressForeverProbe') |
    ForEach-Object { @{ Name = $_; Base = Join-Path $root "_NonRelease/$_"; Toc = "$_.toc"; Kind = 'probe' } }

# A fresh workspace-only directory every time. No client, WTF or previous payload is modified.
$output = Join-Path $PSScriptRoot ('Payload-' + [Guid]::NewGuid().ToString('N'))
$plan = @()
foreach ($entry in $entries) {
    $toc = Join-Path $entry.Base $entry.Toc
    $content = @(Get-Content -LiteralPath $toc)
    if (-not ($content -match '^## Interface: 16001$')) { throw "Unexpected target: $toc" }
    $paths = @($entry.Toc)
    foreach ($line in $content) {
        $relative = $line.Trim()
        if (-not $relative -or $relative.StartsWith('#')) { continue }
        if (-not $relative.EndsWith('.lua')) { throw "Review indirect load before copying: $relative" }
        $paths += $relative
    }
    # Runtime textures only, excluding archived designs and source artwork.
    $media = Join-Path $entry.Base 'Media'
    if (Test-Path -LiteralPath $media -PathType Container) {
        $paths += @(Get-ChildItem -LiteralPath $media -File | Where-Object { $_.Extension -in '.tga', '.blp' } | ForEach-Object { 'Media/' + $_.Name })
    }
    foreach ($relative in $paths) {
        $source = [IO.Path]::GetFullPath((Join-Path $entry.Base $relative))
        if (-not $source.StartsWith($entry.Base + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Source escapes addon: $source" }
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing file: $source" }
        $loadRelative = if ($relative -eq $entry.Toc) { $entry.Name + '.toc' } else { $relative }
        $destination = Join-Path (Join-Path $output $entry.Name) $loadRelative
        $plan += [pscustomobject]@{ Addon = $entry.Name; Kind = $entry.Kind; Relative = $loadRelative; SourceRelative = $relative; Source = $source; Destination = $destination; SHA256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash }
    }
}
foreach ($file in $plan) {
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $file.Destination) -Force)
    Copy-Item -LiteralPath $file.Source -Destination $file.Destination
    if ((Get-FileHash -LiteralPath $file.Destination -Algorithm SHA256).Hash -ne $file.SHA256) { throw "Copy differs: $($file.Destination)" }
}
$plan | Select-Object Addon, Kind, Relative, SourceRelative, SHA256 | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $output 'Files.json') -Encoding utf8
@'
Forever development test payload; not a release package.
Contains seven existing target builds and three non-release probes.
Crafting recipe collection has an unresolved client failure. Other declared client checks remain pending.
Do not distribute or mark as release-ready. Use Docs/无限服-集中开发与测试批次-2026-10-23.md.
Only reviewed runtime Lua and top-level TGA/BLP textures are included.
Each target source manifest is copied as Addon/Addon.toc; no source-suffix discovery is assumed.
'@ | Set-Content -LiteralPath (Join-Path $output 'README.txt') -Encoding utf8
Write-Output "Verified development payload: $output ($($plan.Count) files; no client changes)."
