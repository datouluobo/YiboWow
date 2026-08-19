[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path,
    [string]$OutputRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path "Builds")
)

$ErrorActionPreference = "Stop"

function Get-AddonVersion {
    param([Parameter(Mandatory = $true)][string]$TocPath)
    $version = Select-String -Path $TocPath -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
    if (-not $version) { throw "Unable to find version in $TocPath" }
    $version.Matches[0].Groups[1].Value.Trim().TrimStart("v", "V")
}

function Copy-ReleaseFiles {
    param([Parameter(Mandatory = $true)][string]$SourceRoot, [Parameter(Mandatory = $true)][string]$StageRoot)
    $destination = Join-Path $StageRoot "YiboCore"
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $toc = Join-Path $SourceRoot "YiboCore.toc"
    Copy-Item -LiteralPath $toc -Destination $destination
    Get-Content -LiteralPath $toc | Where-Object { $_ -and $_ -notmatch '^#' } | ForEach-Object {
        $relativePath = $_.Trim()
        $source = Join-Path $SourceRoot $relativePath
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "TOC references missing file: $relativePath" }
        $target = Join-Path $destination $relativePath
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target
    }
    # Runtime textures can be referenced dynamically by registered pages.
    $mediaDestination = Join-Path $destination "Media"
    New-Item -ItemType Directory -Path $mediaDestination -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $SourceRoot "Media") -File -Filter "*.tga" | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $mediaDestination
    }
    $destination
}

function Copy-GitHubFiles {
    param([Parameter(Mandatory = $true)][string]$SourceRoot, [Parameter(Mandatory = $true)][string]$StageRoot)
    $destination = Join-Path $StageRoot "YiboCore"
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $roboArgs = @($SourceRoot, $destination, "/E", "/R:1", "/W:1", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/XD", ".git", "dist", "Builds", "tmp", "_NonRelease", "/XF", "AGENTS.md")
    & robocopy @roboArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
    $destination
}

$projectRoot = (Resolve-Path $ProjectRoot).Path
$tocPath = Join-Path $projectRoot "YiboCore.toc"
$version = Get-AddonVersion -TocPath $tocPath
$outputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$apiVersion = Select-String -Path (Join-Path $projectRoot "Bootstrap.lua") -Pattern '^Core\.API_VERSION\s*=\s*(\d+)' | Select-Object -First 1
if (-not $apiVersion) { throw "Unable to find Core API version in Bootstrap.lua" }
$apiTag = "api{0}" -f $apiVersion.Matches[0].Groups[1].Value
$cfZip = Join-Path $outputRoot ("YiboCore-v{0}-{1}-curseforge.zip" -f $version, $apiTag)
$githubZip = Join-Path $outputRoot ("YiboCore-v{0}-{1}-github.zip" -f $version, $apiTag)
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("YiboCore-build-" + [guid]::NewGuid().ToString("N"))

try {
    $cfStage = Join-Path $tempRoot "curseforge"
    $githubStage = Join-Path $tempRoot "github"
    Copy-ReleaseFiles -SourceRoot $projectRoot -StageRoot $cfStage | Out-Null
    Copy-GitHubFiles -SourceRoot $projectRoot -StageRoot $githubStage | Out-Null
    if (Test-Path -LiteralPath $cfZip) { Remove-Item -LiteralPath $cfZip -Force }
    if (Test-Path -LiteralPath $githubZip) { Remove-Item -LiteralPath $githubZip -Force }
    Compress-Archive -LiteralPath (Join-Path $cfStage "YiboCore") -DestinationPath $cfZip -CompressionLevel Optimal
    Compress-Archive -LiteralPath (Join-Path $githubStage "YiboCore") -DestinationPath $githubZip -CompressionLevel Optimal
    [pscustomobject]@{ Version = $version; CurseForge = $cfZip; GitHub = $githubZip } | Format-List
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
