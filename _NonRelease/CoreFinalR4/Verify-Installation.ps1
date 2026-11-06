#Requires -Version 7.2
param(
    [Parameter(Mandatory=$true)][ValidateSet('Retail','Mists','Forever')][string]$Target,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9-]+$')][string]$Savepoint
)
$ErrorActionPreference = 'Stop'
$state = Get-Content -LiteralPath (Join-Path $PSScriptRoot "Deployment-$Target.json") -Raw | ConvertFrom-Json
$report = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Package-Checks.json') -Raw | ConvertFrom-Json
$case = @($report.cases | Where-Object { $_.label -ceq $state.case -and $_.target -ceq $Target })
if ($case.Count -ne 1) { throw 'Expected one exact frozen scenario.' }
$case = $case[0]
$mismatches = @()
foreach ($file in $case.files.PSObject.Properties) {
    $path = Join-Path $state.live $file.Name
    if (-not (Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path).Hash -ine $file.Value) { $mismatches += $file.Name }
}
$disk = Get-Content -LiteralPath (Join-Path $PSScriptRoot "Savepoint-$Target-$Savepoint.json") -Raw | ConvertFrom-Json
$changedSaves = @($disk.files | Where-Object { (Get-FileHash -LiteralPath $_.active).Hash -ine $_.sha256 })
$changedBackups = @($state.originalSaves | Where-Object { (Get-FileHash -LiteralPath $_.backup).Hash -ine $_.sha256 })
$liveCount = @(Get-ChildItem -LiteralPath $state.live -File -Recurse).Count
$expectedCount = @($case.files.PSObject.Properties).Count
$result = [ordered]@{
    date='2026-10-27';target=$Target;case=$state.case;phase=$state.phase
    liveFileCount=$liveCount;expectedFileCount=$expectedCount;fileMismatches=$mismatches
    retainedExtraOldFiles=@($case.retainedFiles.PSObject.Properties).Count
    retainedOldPaths=@($case.retainedFiles.PSObject.Properties | Select-Object -ExpandProperty Name)
    tocNames=@(Get-ChildItem -LiteralPath $state.live -File -Filter '*.toc' | Select-Object -ExpandProperty Name)
    testSaveFilesUnchanged=($changedSaves.Count -eq 0);originalBackupsUnchanged=($changedBackups.Count -eq 0)
    priorCasePreserved=$state.history[-1].case;clientAcceptance='pending'
}
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $PSScriptRoot "Installation-$Target-$($state.case).json") -Encoding utf8
if ($mismatches.Count -or $changedSaves.Count -or $changedBackups.Count -or $liveCount -ne $expectedCount) { throw 'Installation or saved-data verification failed; see recorded mismatches.' }
Write-Output "$Target $($state.case) verified: $liveCount files, $($result.retainedExtraOldFiles) retained old files; test saves and original backups unchanged."
