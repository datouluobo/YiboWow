param([string]$WorkspaceRoot)
$ErrorActionPreference = 'Stop'
. (Join-Path $WorkspaceRoot 'Tools/Release.Common.ps1')
$hash = 'a' * 64
$targets = @([pscustomobject]@{ slug = 'mists' })
$mail = Get-YiboPackageNames YiboMail mists 1.2.22-api1 1 $true $hash $targets
if ($mail.CurseForge -ne 'YiboMail-mists-v1.2.22-api1-curseforge.zip' -or
    $mail.GitHub -ne 'YiboMail-mists-v1.2.22-api1-src.aaaaaaaaaaaa-github.zip') { throw 'Mail naming mismatch' }
$core = Get-YiboPackageNames YiboCore mists 1.12.1 13 $false $hash $targets
if ($core.CurseForge -ne 'YiboCore-mists-v1.12.1-api13-curseforge.zip') { throw 'Core API suffix regression' }
$currency = Get-YiboPackageNames YiboCurrency mists 1.0.0 $null $false $hash $targets
if ($currency.CurseForge -ne 'YiboCurrency-mists-v1.0.0-curseforge.zip') { throw 'Dependency API leaked into version' }
$rejected = $false
try { Get-YiboPackageNames YiboMail mists 1.2.22-api2 1 $true $hash $targets | Out-Null }
catch { $rejected = $true }
if (-not $rejected) { throw 'Mismatched API suffix accepted' }
Write-Output 'PASS: Mail/Core/non-API package naming; source hash naming; API mismatch rejection'
