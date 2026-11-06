[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$config = Import-PowerShellDataFile -LiteralPath (Join-Path $root 'Tools/ClientPaths.psd1')
$client = [IO.Path]::GetFullPath($config.Forever)
$addons = Join-Path $client 'Interface/AddOns'
if (-not (Test-Path -LiteralPath (Join-Path $client 'Wow.exe') -PathType Leaf) -and
    -not (Test-Path -LiteralPath (Join-Path $client 'WowClassic.exe') -PathType Leaf)) { throw "Missing client executable: $client" }
if (-not (Test-Path -LiteralPath $addons -PathType Container)) { throw "Missing AddOns directory: $addons" }
$running = @(Get-Process -Name Wow, WowClassic, WowB, WowT -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and [IO.Path]::GetFullPath($_.Path).StartsWith($client + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
})
if ($running.Count) { throw 'Close the Forever client before adding new addon directories.' }
$plan = @()
foreach ($name in 'YiboAltoBossForeverProbe', 'YiboBuildsForeverProbe', 'YiboProgressForeverProbe') {
    $source = Join-Path $root "_NonRelease/$name"
    $destination = Join-Path $addons $name
    if (-not (Test-Path -LiteralPath (Join-Path $source "$name.toc") -PathType Leaf)) { throw "Missing probe manifest: $source" }
    $existing = Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
    if ($existing -and ($existing.LinkType -ne 'Junction' -or
        [IO.Path]::GetFullPath([string]$existing.Target).TrimEnd('\') -ine $source.TrimEnd('\'))) {
        throw "Existing destination does not match the expected junction: $destination"
    }
    $plan += [pscustomobject]@{ Source = $source; Destination = $destination; State = $(if ($existing) { 'Verified' } else { 'Create' }) }
}
foreach ($entry in $plan) {
    if ($entry.State -eq 'Create' -and $PSCmdlet.ShouldProcess($entry.Destination, "Create probe junction to $($entry.Source)")) {
        [void](New-Item -ItemType Junction -Path $entry.Destination -Target $entry.Source)
        $entry.State = 'Created'
    }
}
$plan | Format-List State, Destination, Source
