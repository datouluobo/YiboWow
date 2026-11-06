#Requires -Version 7.2
param(
    [Parameter(Mandatory=$true)][ValidateSet('Retail','Mists','Forever')][string]$Target,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9-]+$')][string]$Label
)
$ErrorActionPreference = 'Stop'
if (@(Get-Process -Name 'Wow*' -ErrorAction SilentlyContinue).Count) { throw 'WoW must finish exiting before capturing a persistence savepoint.' }
$state = Get-Content -LiteralPath (Join-Path $PSScriptRoot "Deployment-$Target.json") -Raw | ConvertFrom-Json
$client = [IO.Path]::GetFullPath($state.client)
function Safe-ClientPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($client + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escaped the explicit client root.' }
    return $full
}
$originalChecks = @()
foreach ($save in $state.originalSaves) {
    $backup = Safe-ClientPath $save.backup
    $digest = (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash
    if ($digest -ne $save.sha256) { throw 'Original saved data backup changed.' }
    $originalChecks += @{backup=$backup;sha256=$digest;unchanged=$true}
}
$root = Safe-ClientPath (Join-Path $state.backupRoot ("Savepoints/$Label"))
if (Test-Path -LiteralPath $root) { throw 'Savepoint already exists; preserve it and choose a new exact label.' }
$probe = "YiboCore${Target}R4"
$files = @(Get-ChildItem -LiteralPath (Join-Path $client 'WTF') -File -Recurse | Where-Object { $_.Name -in @('YiboCore.lua','YiboCore.lua.bak',"$probe.lua","$probe.lua.bak") })
if (-not @($files | Where-Object { $_.Name -eq 'YiboCore.lua' }).Count -or
    -not @($files | Where-Object { $_.Name -eq "$probe.lua" }).Count) { throw 'Core and probe saved files must both exist before restart acceptance.' }
$captured = @()
foreach ($file in $files) {
    $active = Safe-ClientPath $file.FullName
    $relative = [IO.Path]::GetRelativePath((Join-Path $client 'WTF'),$active)
    $copy = Safe-ClientPath (Join-Path $root $relative)
    New-Item -ItemType Directory -Path (Split-Path $copy -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $active -Destination $copy
    $digest = (Get-FileHash -LiteralPath $active -Algorithm SHA256).Hash
    if ((Get-FileHash -LiteralPath $copy).Hash -ne $digest) { throw 'Captured savepoint file hash mismatch.' }
    $captured += @{active=$active;copy=$copy;sha256=$digest;bytes=$file.Length;lastWriteUTC=$file.LastWriteTimeUtc.ToString('o')}
}
$record = @{target=$Target;case=$state.case;label=$Label;capturedUTC=[DateTimeOffset]::UtcNow.ToString('o');wowProcessCount=0;
    originalBackups=$originalChecks;files=$captured;rawDataExecuted=$false;activeFilesModified=$false;status='disk-savepoint-captured; restart runtime verification pending'}
$record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $PSScriptRoot "Savepoint-$Target-$Label.json") -Encoding utf8
Write-Output "$Target $Label captured: $($captured.Count) test save files, $($originalChecks.Count) original backups unchanged; no WoW process."
