#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$OutputRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path 'Builds'),
    [string]$Target = 'Mists',
    [ValidateSet('Both', 'CurseForge', 'GitHub')][string]$Channel = 'Both',
    [string]$Version,
    [switch]$ValidateOnly,
    [switch]$KeepStaging
)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path (Resolve-Path -LiteralPath $ProjectRoot).Path -Parent
$builder = Join-Path $PSScriptRoot '../../../Tools/Build-ReleasePackages.ps1'
if ($Version) {
    $plan = & $builder -Addon YiboAutoOpen -Target $Target -Channel $Channel -WorkspaceRoot $workspacePath -OutputRoot $OutputRoot -ValidateOnly
    if ($plan.Version -ne $Version.TrimStart('v', 'V')) { throw "Requested version differs from source version: $($plan.Version)" }
}
& $builder -Addon YiboAutoOpen -Target $Target -Channel $Channel -WorkspaceRoot $workspacePath -OutputRoot $OutputRoot -ValidateOnly:$ValidateOnly -KeepStaging:$KeepStaging
