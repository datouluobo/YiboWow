[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$OutputRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "Builds")
)

$ErrorActionPreference = "Stop"

function Get-AddonVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TocPath
    )

    $versionLine = Select-String -Path $TocPath -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
    if (-not $versionLine) {
        throw "Unable to find version in $TocPath"
    }

    return $versionLine.Matches[0].Groups[1].Value.Trim()
}

function New-StagingCopy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,
        [Parameter(Mandatory = $true)]
        [string]$StageRoot,
        [string[]]$ExcludeDirectories,
        [string[]]$ExcludeFiles
    )

    New-Item -ItemType Directory -Path $StageRoot -Force | Out-Null

    $destination = Join-Path $StageRoot "YiboBeastPaths"
    New-Item -ItemType Directory -Path $destination -Force | Out-Null

    $roboArgs = @(
        $SourceRoot,
        $destination,
        "/E",
        "/R:1",
        "/W:1",
        "/NFL",
        "/NDL",
        "/NJH",
        "/NJS",
        "/NP"
    )

    if ($ExcludeDirectories.Count -gt 0) {
        $roboArgs += "/XD"
        $roboArgs += $ExcludeDirectories
    }

    if ($ExcludeFiles.Count -gt 0) {
        $roboArgs += "/XF"
        $roboArgs += $ExcludeFiles
    }

    & robocopy @roboArgs | Out-Null
    $exitCode = $LASTEXITCODE
    if ($exitCode -ge 8) {
        throw "robocopy failed with exit code $exitCode"
    }

    return $destination
}

function Remove-NonReleaseTocEntries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TocPath
    )

    $lines = Get-Content -LiteralPath $TocPath
    $filtered = $lines | Where-Object { $_ -notmatch '^\s*_NonRelease[\\/]' }
    Set-Content -LiteralPath $TocPath -Value $filtered -Encoding UTF8
}

$projectRoot = (Resolve-Path $ProjectRoot).Path
$outputRoot = $OutputRoot
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

$tocPath = Join-Path $projectRoot "YiboBeastPaths.toc"
$version = Get-AddonVersion -TocPath $tocPath
$versionTag = $version.TrimStart("vV")

$fullZipPath = Join-Path $outputRoot ("YiboBeastPaths-v{0}-debug.zip" -f $versionTag)
$releaseZipPath = Join-Path $outputRoot ("YiboBeastPaths-v{0}.zip" -f $versionTag)

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("YiboBeastPaths-build-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $fullStageRoot = Join-Path $tempRoot "full"
    $releaseStageRoot = Join-Path $tempRoot "release"

    $commonExcludeDirs = @(
        (Join-Path $projectRoot ".git"),
        (Join-Path $projectRoot "Screenshots"),
        (Join-Path $projectRoot "_NonRelease\Builds")
    )
    $commonExcludeFiles = @(
        "PRODUCT.md"
    )

    $fullStagePath = New-StagingCopy -SourceRoot $projectRoot -StageRoot $fullStageRoot -ExcludeDirectories $commonExcludeDirs -ExcludeFiles $commonExcludeFiles
    $releaseExcludeDirs = @(
        (Join-Path $projectRoot ".git"),
        (Join-Path $projectRoot "Screenshots"),
        (Join-Path $projectRoot "_NonRelease")
    )
    $releaseExcludeFiles = @(
        "AGENTS.md",
        "PRODUCT.md"
    )
    $releaseStagePath = New-StagingCopy -SourceRoot $projectRoot -StageRoot $releaseStageRoot -ExcludeDirectories $releaseExcludeDirs -ExcludeFiles $releaseExcludeFiles
    Get-ChildItem -LiteralPath $releaseStagePath -Filter "YiboBeastPaths*.toc" | ForEach-Object {
        Remove-NonReleaseTocEntries -TocPath $_.FullName
    }

    if (Test-Path $fullZipPath) {
        Remove-Item -LiteralPath $fullZipPath -Force
    }
    if (Test-Path $releaseZipPath) {
        Remove-Item -LiteralPath $releaseZipPath -Force
    }

    Compress-Archive -LiteralPath $fullStagePath -DestinationPath $fullZipPath -CompressionLevel Optimal
    Compress-Archive -LiteralPath $releaseStagePath -DestinationPath $releaseZipPath -CompressionLevel Optimal

    [pscustomobject]@{
        Version = $version
        FullZip = $fullZipPath
        ReleaseZip = $releaseZipPath
    } | Format-List
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
