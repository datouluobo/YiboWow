$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open PowerShell as Administrator and run this script again. Kernel file IO tracing requires elevation.'
}
$status = (& wpr.exe -status 2>&1 | Out-String)
if ($status -notmatch 'WPR is not recording') {
    throw ('Cannot confirm WPR is idle. Existing recordings will not be changed. Status: ' + $status)
}
$session = Join-Path $PSScriptRoot ('Trace-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $session | Out-Null
$profile = (Join-Path $PSScriptRoot 'ResourceIO.wprp') + '!ResourceIO'
& wpr.exe -start $profile -filemode -recordtempto $session
if ($LASTEXITCODE -ne 0) { throw ('WPR start failed: ' + $LASTEXITCODE) }
[pscustomobject]@{
    StartedUtc = [datetime]::UtcNow.ToString('o')
    Session = $session
    Output = (Join-Path $session 'ResourceIO.etl')
    Note = 'System-wide file IO and process identity metadata; no file content or network payload capture. Keep local. Stop after the reproduction.'
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'Session.json') -Encoding utf8
$session | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'ActiveTrace.txt') -Encoding utf8
Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('Wow.exe', 'Agent.exe', 'Battle.net.exe') } |
    Select-Object Name, ProcessId, ParentProcessId, ExecutablePath, CreationDate |
    Export-Csv -LiteralPath (Join-Path $session 'InitialProcesses.csv') -NoTypeInformation -Encoding utf8
& wpr.exe -status
Write-Output ('Trace started: ' + $session)
Write-Output 'Return to the chat before updating or launching a game. Stop after reproduction; avoid leaving the trace running.'
