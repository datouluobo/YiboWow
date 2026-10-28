#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../Tools/Release.Common.ps1')
$fixture = Join-Path $PSScriptRoot ('AliasFixture/' + [guid]::NewGuid().ToString('N'))
$root = Join-Path $fixture 'YiboCore'
[void][IO.Directory]::CreateDirectory((Join-Path $root 'Retail'))
$toc = "## Interface: 120105`n## Version: 0.1.0`n"
[IO.File]::WriteAllText((Join-Path $root 'YiboCore_Mainline.toc'), $toc)
[IO.File]::WriteAllText((Join-Path $root 'Retail/Target.lua'), 'Core.VERSION = "0.1.0"')
[IO.File]::WriteAllText((Join-Path $root 'Bootstrap.lua'), "Core.VERSION = `"1.12.9`"`nCore.API_VERSION = 13`n")
$profile = Get-YiboReleaseProfile $fixture 'YiboCore' 'Retail'
if ($profile.Version -ne '0.1.0' -or $profile.Client.SourceToc -ne 'YiboCore_Mainline.toc') { throw 'Single Mainline source fixture did not validate' }
[IO.File]::WriteAllText((Join-Path $root 'YiboCore_Retail.toc'), $toc)
$rejected = $false
try { Get-YiboReleaseProfile $fixture 'YiboCore' 'Retail' | Out-Null }
catch { if ($_.Exception.Message -like '*remove the redundant Retail TOC*') { $rejected = $true } else { throw } }
if (-not $rejected) { throw 'Duplicate Retail source TOC was accepted' }
Write-Output 'CoreRetailR2 AliasSpec passed: 2 checks (single Mainline source accepted; duplicate Retail TOC rejected)'
