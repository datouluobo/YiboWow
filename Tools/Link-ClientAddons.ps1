[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'ClientPaths.psd1'),
    [string]$MopPath,
    [string]$ForeverPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$config = Import-PowerShellDataFile -LiteralPath $ConfigPath
if (-not $MopPath) { $MopPath = $config.Mop }
if (-not $ForeverPath) { $ForeverPath = $config.Forever }

# Only runnable repository addons, excluding design folders and non-release probes.
$addons = @(Get-ChildItem -LiteralPath $sourceRoot -Directory -Filter 'Yibo*' |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName ($_.Name + '.toc')) -PathType Leaf } |
    Sort-Object Name)
if ($addons.Count -eq 0) { throw "No runnable addons found in $sourceRoot" }

# Check every destination before making changes. Never replace existing content.
$plan = @()
foreach ($client in @(@{ Name = 'MoP'; Path = $MopPath }, @{ Name = 'Forever'; Path = $ForeverPath })) {
    $clientRoot = [IO.Path]::GetFullPath($client.Path)
    $hasClient = (Test-Path -LiteralPath (Join-Path $clientRoot 'Wow.exe') -PathType Leaf) -or
        (Test-Path -LiteralPath (Join-Path $clientRoot 'WowClassic.exe') -PathType Leaf)
    if (-not $hasClient) {
        throw "Client Wow.exe / WowClassic.exe not found: $clientRoot"
    }
    $addonsRoot = Join-Path $clientRoot 'Interface\AddOns'
    $existing = @{}
    if (Test-Path -LiteralPath $addonsRoot) {
        foreach ($item in Get-ChildItem -LiteralPath $addonsRoot -Force) { $existing[$item.Name] = $item }
    }
    foreach ($addon in $addons) {
        $destination = Join-Path $addonsRoot $addon.Name
        $present = $existing[$addon.Name]
        if ($present) {
            if ($present.LinkType -ne 'Junction' -or
                [IO.Path]::GetFullPath([string]$present.Target).TrimEnd('\') -ine $addon.FullName.TrimEnd('\')) {
                throw "Destination already exists and is not the expected junction: $destination"
            }
        }
        $plan += [pscustomobject]@{
            Client = $client.Name
            Addon = $addon.Name
            Source = $addon.FullName
            Destination = $destination
            State = $(if ($present) { 'Verified' } else { 'Create' })
        }
    }
}

foreach ($entry in $plan) {
    if ($entry.State -eq 'Create' -and $PSCmdlet.ShouldProcess($entry.Destination, "Create junction to $($entry.Source)")) {
        $parent = Split-Path -Parent $entry.Destination
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        New-Item -ItemType Junction -Path $entry.Destination -Target $entry.Source | Out-Null
        $entry.State = 'Created'
    }
}
$plan | Select-Object Client, Addon, State, Destination, Source
