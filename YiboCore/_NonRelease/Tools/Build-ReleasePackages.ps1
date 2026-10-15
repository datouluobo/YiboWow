#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path 'Builds'),
    [string]$Target = 'Mists',
    [ValidateSet('Both', 'CurseForge', 'GitHub')][string]$Channel = 'Both',
    [switch]$ValidateOnly,
    [switch]$KeepStaging
)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path (Resolve-Path -LiteralPath $ProjectRoot).Path -Parent
$builder = Join-Path $PSScriptRoot '..\..\..\Tools\Build-ReleasePackages.ps1'
& $builder -Addon YiboCore -Target $Target -Channel $Channel -WorkspaceRoot $workspacePath -OutputRoot $OutputRoot -ValidateOnly:$ValidateOnly -KeepStaging:$KeepStaging
