$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open PowerShell as Administrator and run this script again.'
}
$marker = Join-Path $PSScriptRoot 'ActiveTrace.txt'
$session = (Get-Content -LiteralPath $marker -Raw).Trim()
$sessionRoot = [IO.Path]::GetFullPath($PSScriptRoot) + [IO.Path]::DirectorySeparatorChar
$resolved = [IO.Path]::GetFullPath($session)
if (-not $resolved.StartsWith($sessionRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected session path.' }
$sessionInfo = Get-Content -LiteralPath (Join-Path $session 'Session.json') -Raw | ConvertFrom-Json
if ($sessionInfo.StoppedUtc) { throw 'This session is already stopped.' }
& wpr.exe -stop (Join-Path $session 'ResourceIO.etl') 'WoW repeated update reproduction'
if ($LASTEXITCODE -ne 0) { throw ('WPR stop failed: ' + $LASTEXITCODE) }
$sessionInfo | Add-Member -NotePropertyName StoppedUtc -NotePropertyValue ([datetime]::UtcNow.ToString('o'))
$sessionInfo | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'Session.json') -Encoding utf8
Write-Output ('Trace saved: ' + (Join-Path $session 'ResourceIO.etl'))
