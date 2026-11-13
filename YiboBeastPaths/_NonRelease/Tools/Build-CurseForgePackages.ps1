#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$OutputRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path 'Builds'),
    [ValidateSet('Universal')][string]$Target = 'Universal',
    [ValidateSet('Both','CurseForge','GitHub')][string]$Channel = 'CurseForge',
    [string]$Version,
    [switch]$ValidateOnly,
    [switch]$KeepStaging
)
$ErrorActionPreference='Stop'
$workspacePath=Split-Path (Resolve-Path -LiteralPath $ProjectRoot).Path -Parent
if ($Version -and $Version.TrimStart('v','V') -ne '1.9.0') { throw 'Version must match the selected source TOC.' }
$builder=Join-Path $PSScriptRoot '../../../Tools/Build-ReleasePackages.ps1'
& $builder -Addon YiboBeastPaths -Target $Target -Channel $Channel -WorkspaceRoot $workspacePath -OutputRoot $OutputRoot -ValidateOnly:$ValidateOnly -KeepStaging:$KeepStaging
