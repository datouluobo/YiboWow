#Requires -Version 7.2
param([Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExpectedSHA256)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $workspace 'Tools/Release.Common.ps1')
$profile = Get-YiboReleaseProfile $workspace 'YiboCore' 'Retail'
$entries = @(Get-YiboPublicEntries $profile.Root) + [pscustomobject]@{
    Relative = 'build-config/ReleaseProfiles.psd1'; Source = (Join-Path $workspace 'Tools/ReleaseProfiles.psd1'); Content = $null
}
if ((Get-YiboSourceDigest $entries) -cne $ExpectedSHA256) { throw 'Current source/configuration no longer matches the actual local packages.' }
Write-Output 'CoreRetailR2 package source snapshot matches current unified build inputs.'
