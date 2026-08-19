[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$OutputRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path "Builds")
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

$curseForgeZipPath = Join-Path $outputRoot ("YiboBeastPaths-v{0}-curseforge.zip" -f $versionTag)
$githubZipPath = Join-Path $outputRoot ("YiboBeastPaths-v{0}-github.zip" -f $versionTag)

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("YiboBeastPaths-build-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $githubStageRoot = Join-Path $tempRoot "github"
    $curseForgeStageRoot = Join-Path $tempRoot "curseforge"

    $commonExcludeDirs = @(
        (Join-Path $projectRoot ".git"),
        (Join-Path $projectRoot "Builds"),
        (Join-Path $projectRoot "_NonRelease")
    )
    $commonExcludeFiles = @(
        "PRODUCT.md"
    )

    $githubStagePath = New-StagingCopy -SourceRoot $projectRoot -StageRoot $githubStageRoot -ExcludeDirectories $commonExcludeDirs -ExcludeFiles $commonExcludeFiles
    $curseForgeExcludeDirs = @(
        (Join-Path $projectRoot ".git"),
        (Join-Path $projectRoot "Screenshots"),
        (Join-Path $projectRoot "Builds"),
        (Join-Path $projectRoot "_NonRelease")
    )
    $curseForgeExcludeFiles = @(
        "AGENTS.md",
        "PRODUCT.md"
    )
    $curseForgeStagePath = New-StagingCopy -SourceRoot $projectRoot -StageRoot $curseForgeStageRoot -ExcludeDirectories $curseForgeExcludeDirs -ExcludeFiles $curseForgeExcludeFiles
    Get-ChildItem -LiteralPath $curseForgeStagePath -Filter "YiboBeastPaths*.toc" | ForEach-Object {
        Remove-NonReleaseTocEntries -TocPath $_.FullName
    }

    if (Test-Path $githubZipPath) {
        Remove-Item -LiteralPath $githubZipPath -Force
    }
    if (Test-Path $curseForgeZipPath) {
        Remove-Item -LiteralPath $curseForgeZipPath -Force
    }

    Compress-Archive -LiteralPath $githubStagePath -DestinationPath $githubZipPath -CompressionLevel Optimal
    Compress-Archive -LiteralPath $curseForgeStagePath -DestinationPath $curseForgeZipPath -CompressionLevel Optimal

    [pscustomobject]@{
        Version = $version
        CurseForge = $curseForgeZipPath
        GitHub = $githubZipPath
    } | Format-List
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
