param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('PendingUpdate', 'UpdatedBeforeLaunch', 'Running', 'AfterExit')]
    [string]$Stage
)
$ErrorActionPreference = 'Stop'
$gameRoot = 'C:\Program Files (x86)\World of Warcraft'
$captureRoot = Join-Path $PSScriptRoot ($Stage + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $captureRoot | Out-Null
$files = @(
    Get-ChildItem -LiteralPath (Join-Path $gameRoot 'Data\data') -File -Force | Where-Object { $_.Name -notlike 'data.*' }
    Get-ChildItem -LiteralPath (Join-Path $gameRoot 'Data\wow_cn_beta') -File -Force
    Get-ChildItem -LiteralPath (Join-Path $gameRoot 'Data\wow_classic') -File -Force
    Get-ChildItem -LiteralPath (Join-Path $gameRoot 'Data\ecache') -File -Force
    Get-Item -LiteralPath (Join-Path $gameRoot '.build.info')
    Get-Item -LiteralPath (Join-Path $gameRoot '_cn_beta_\.flavor.info')
    Get-Item -LiteralPath (Join-Path $gameRoot '_classic_\.flavor.info')
)
$records = foreach ($file in $files) {
    $relative = $file.FullName.Substring($gameRoot.Length + 1)
    $destination = Join-Path $captureRoot $relative
    New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
    try {
        Copy-Item -LiteralPath $file.FullName -Destination $destination
        [pscustomobject]@{ Path = $relative; Length = $file.Length; LastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('o'); SHA256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash; Error = '' }
    } catch {
        [pscustomobject]@{ Path = $relative; Length = $file.Length; LastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('o'); SHA256 = ''; Error = $_.Exception.Message }
    }
}
$records | Export-Csv -LiteralPath (Join-Path $captureRoot 'IndexHashes.csv') -NoTypeInformation -Encoding utf8
Get-ChildItem -LiteralPath (Join-Path $gameRoot 'Data\data') -File -Force |
    Select-Object Name, Length, @{n='LastWriteTimeUtc';e={$_.LastWriteTimeUtc.ToString('o')}} |
    Export-Csv -LiteralPath (Join-Path $captureRoot 'ArchiveMetadata.csv') -NoTypeInformation -Encoding utf8
$logSources = @{
    Agent = 'C:\ProgramData\Battle.net\Agent\Agent.9824\Logs'
    Game = (Join-Path $gameRoot '_cn_beta_\Logs')
    MistsGame = (Join-Path $gameRoot '_classic_\Logs')
}
foreach ($entry in $logSources.GetEnumerator()) {
    $destination = Join-Path $captureRoot ('Logs\' + $entry.Key)
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Get-ChildItem -LiteralPath $entry.Value -File | Where-Object {
        $_.Name -match '^(Agent-|Operations-|bc-|AgentNGDP-|Tact\.|Client\.|General\.)' -and $_.LastWriteTime.Date -eq (Get-Date).Date
    } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $destination }
}
Get-Process -Name Wow, WowClassic, Battle.net, Agent -ErrorAction SilentlyContinue |
    Select-Object ProcessName, Id, StartTime |
    Export-Csv -LiteralPath (Join-Path $captureRoot 'Processes.csv') -NoTypeInformation -Encoding utf8
[pscustomobject]@{ Stage = $Stage; CapturedUtc = [datetime]::UtcNow.ToString('o'); GameRoot = $gameRoot; Note = 'Read-only best-effort capture; files may change during capture. Large data archives are metadata-only.' } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $captureRoot 'Capture.json') -Encoding utf8
Write-Output $captureRoot
Write-Output ('Index files captured: ' + @($records).Count)
Write-Output ('Copy errors: ' + @($records | Where-Object Error).Count)
