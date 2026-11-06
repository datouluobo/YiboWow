#Requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Install','Switch','Restore')][string]$Mode,
    [Parameter(Mandatory=$true)][ValidateSet('Retail','Mists','Forever')][string]$Target,
    [string]$Case
)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$clients = @{ Retail='_retail_'; Mists='_classic_'; Forever='_cn_beta_' }
$client = [IO.Path]::GetFullPath((Join-Path 'C:/Program Files (x86)/World of Warcraft' $clients[$Target]))
function Assert-ClientPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($client + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes explicit client root: $full" }
    return $full
}
function Assert-Closed {
    if (@(Get-Process -Name 'Wow*' -ErrorAction SilentlyContinue).Count) { throw 'Exit all WoW clients before changing code directories or test save copies.' }
}
function Tree-Hashes([string]$Root) {
    $result = @{}
    foreach ($file in Get-ChildItem -LiteralPath $Root -File -Recurse) {
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Unexpected reparse point inside test payload.' }
        $result[[IO.Path]::GetRelativePath($Root,$file.FullName)] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
    return $result
}
function Copy-Payload([string]$Source,[string]$Destination) {
    $safeDestination = Assert-ClientPath $Destination
    if (Test-Path -LiteralPath $safeDestination) { throw "Destination already exists: $safeDestination" }
    $sourceHashes = Tree-Hashes $Source
    New-Item -ItemType Directory -Path $safeDestination | Out-Null
    foreach ($relative in $sourceHashes.Keys) {
        $destinationFile = Assert-ClientPath (Join-Path $safeDestination $relative)
        New-Item -ItemType Directory -Path (Split-Path $destinationFile -Parent) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $Source $relative) -Destination $destinationFile
        if ((Get-FileHash -LiteralPath $destinationFile).Hash -ne $sourceHashes[$relative]) { throw 'Installed payload hash mismatch.' }
    }
    return $sourceHashes
}
Assert-Closed
$statePath = Join-Path $PSScriptRoot "Deployment-$Target.json"
$probeName = "YiboCore${Target}R4"
$live = Assert-ClientPath (Join-Path $client 'Interface/AddOns/YiboCore')
$probe = Assert-ClientPath (Join-Path $client "Interface/AddOns/$probeName")
$checks = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Package-Checks.json') -Raw | ConvertFrom-Json
if ($Mode -ne 'Restore') {
    if (-not $Case) { $Case = "Clean-$Target" }
    $scenario = @($checks.cases | Where-Object { $_.label -ceq $Case -and $_.target -ceq $Target })
    if ($scenario.Count -ne 1) { throw 'Unknown exact target installation case.' }
    $source = [IO.Path]::GetFullPath($scenario[0].root)
    $expectedBase = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Scenarios'))
    if (-not $source.StartsWith($expectedBase + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Scenario source escaped R4 workspace.' }
    if (@(Get-ChildItem -LiteralPath $source -Filter '*.toc' -File).Count -ne 1) { throw 'Refuse a source-shaped directory with competing target TOCs.' }
    $verified = Tree-Hashes $source
    if ($verified.Count -ne @($scenario[0].files.PSObject.Properties).Count) { throw 'Scenario file set changed after checks.' }
    foreach ($property in $scenario[0].files.PSObject.Properties) {
        $relative = $property.Name.Replace('/',[IO.Path]::DirectorySeparatorChar)
        if ($verified[$relative] -ine $property.Value) { throw "Scenario hash changed after checks: $relative" }
    }
}
if ($Mode -eq 'Install') {
    if (Test-Path -LiteralPath $statePath) { throw 'Deployment already has a record; inspect/continue it instead.' }
    $original = Get-Item -LiteralPath $live
    if ($original.LinkType -ne 'Junction' -or @($original.Target)[0] -ne (Join-Path $workspace 'YiboCore')) { throw 'Core original must be the expected source Junction.' }
    if (Test-Path -LiteralPath $probe) { throw 'Probe target already exists; do not overwrite.' }
    $runID = '20261027-' + [guid]::NewGuid().ToString('N').Substring(0,8)
    $backup = Assert-ClientPath (Join-Path $client "_YiboCoreR4/$runID")
    $junctionBackup = Assert-ClientPath (Join-Path $backup 'OriginalJunction')
    New-Item -ItemType Directory -Path $backup | Out-Null
    $saveFiles = @(Get-ChildItem -LiteralPath (Join-Path $client 'WTF') -File -Recurse | Where-Object { $_.Name -in @('YiboCore.lua','YiboCore.lua.bak',"$probeName.lua","$probeName.lua.bak") })
    $saves = @()
    foreach ($file in $saveFiles) {
        $originalSave = Assert-ClientPath $file.FullName
        $relative = [IO.Path]::GetRelativePath((Join-Path $client 'WTF'),$originalSave)
        $copy = Assert-ClientPath (Join-Path $backup "OriginalSavedVariables/$relative")
        New-Item -ItemType Directory -Path (Split-Path $copy -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $originalSave -Destination $copy
        $digest = (Get-FileHash -LiteralPath $originalSave).Hash
        if ((Get-FileHash -LiteralPath $copy).Hash -ne $digest) { throw 'Save backup verification failed.' }
        $saves += @{ original=$originalSave; backup=$copy; sha256=$digest }
    }
    $state = @{ target=$Target; client=$client; backupRoot=$backup; live=$live; originalJunction=$junctionBackup;
        originalTarget=@($original.Target)[0]; probe=$probe; originalSaves=$saves; case=$Case; phase='backed-up'; history=@() }
    $state | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $statePath -Encoding utf8
    Assert-Closed
    Move-Item -LiteralPath $live -Destination $junctionBackup
    if ((Get-Item -LiteralPath $junctionBackup).LinkType -ne 'Junction' -or
        @((Get-Item -LiteralPath $junctionBackup).Target)[0] -ne $state.originalTarget) { throw 'Original Junction preservation check failed.' }
    $state.phase = 'junction-preserved'
    $state | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $statePath -Encoding utf8
    # Re-copy backups to the active filenames: these are explicitly the disposable working copies.
    foreach ($save in $saves) { Copy-Item -LiteralPath $save.backup -Destination $save.original -Force }
    $state.installedHashes = Copy-Payload $source $live
    New-Item -ItemType Junction -Path $probe -Target (Join-Path $workspace "_NonRelease/$probeName") | Out-Null
    $state.phase='awaiting-client'; $state.case=$Case
    $state | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $statePath -Encoding utf8
    Write-Output "$Target $Case installed as an ordinary directory; original Junction preserved; $($saves.Count) original save file(s) backed up and cloned."
    return
}
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -AsHashtable
if ($state.phase -eq 'restored') { throw 'Original environment already restored.' }
foreach ($path in @($state.live,$state.backupRoot,$state.originalJunction,$state.probe)) { $null = Assert-ClientPath $path }
if ((Get-Item -LiteralPath $live).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Active test payload unexpectedly became a link.' }
foreach ($save in $state.originalSaves) { if ((Get-FileHash -LiteralPath $save.backup).Hash -ne $save.sha256) { throw 'Original save backup changed.' } }
$preserved = Assert-ClientPath (Join-Path $state.backupRoot ("Test-"+$state.case+'-'+[guid]::NewGuid().ToString('N').Substring(0,6)))
Move-Item -LiteralPath $live -Destination $preserved
$state.history += @{case=$state.case; preservedDirectory=$preserved; hashes=(Tree-Hashes $preserved)}
if ($Mode -eq 'Switch') {
    $state.installedHashes = Copy-Payload $source $live
    $state.case=$Case; $state.phase='awaiting-client'
} else {
    $testSaves = @(Get-ChildItem -LiteralPath (Join-Path $client 'WTF') -File -Recurse | Where-Object { $_.Name -in @('YiboCore.lua','YiboCore.lua.bak',"$probeName.lua","$probeName.lua.bak") })
    foreach ($file in $testSaves) {
        $from = Assert-ClientPath $file.FullName
        $relative = [IO.Path]::GetRelativePath((Join-Path $client 'WTF'),$from)
        $to = Assert-ClientPath (Join-Path $state.backupRoot "TestSavedVariables/$relative")
        if (Test-Path -LiteralPath $to) { throw 'Test save preservation destination already exists.' }
        New-Item -ItemType Directory -Path (Split-Path $to -Parent) -Force | Out-Null
        Move-Item -LiteralPath $from -Destination $to
    }
    foreach ($save in $state.originalSaves) {
        Copy-Item -LiteralPath $save.backup -Destination $save.original
        if ((Get-FileHash -LiteralPath $save.original).Hash -ne $save.sha256) { throw 'Restored original save hash mismatch.' }
    }
    $probeBackup = Assert-ClientPath (Join-Path $state.backupRoot 'ProbeJunction')
    Move-Item -LiteralPath $probe -Destination $probeBackup
    Move-Item -LiteralPath $state.originalJunction -Destination $live
    if ((Get-Item -LiteralPath $live).LinkType -ne 'Junction') { throw 'Original Junction not restored.' }
    $state.phase='restored'
}
$state | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $statePath -Encoding utf8
Write-Output "$Target $Mode completed; $($state.phase)."
