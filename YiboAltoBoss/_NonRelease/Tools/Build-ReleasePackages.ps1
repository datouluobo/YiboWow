[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$OutputRoot
)

$ErrorActionPreference = "Stop"
if (-not $ProjectRoot) {
    $ProjectRoot = Join-Path $PSScriptRoot "..\\.."
}
if (-not $OutputRoot) {
    $OutputRoot = Join-Path $PSScriptRoot "..\\..\\..\\Builds"
}
$projectRoot = (Resolve-Path $ProjectRoot).Path
$tocPath = Join-Path $projectRoot "YiboAltoBoss.toc"
$version = (Select-String -LiteralPath $tocPath -Pattern '^## Version:\s*(.+)$').Matches[0].Groups[1].Value.Trim().TrimStart('v', 'V')
$outputRoot = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("YiboAltoBoss-build-" + [guid]::NewGuid().ToString("N"))
$cfZip = Join-Path $outputRoot ("YiboAltoBoss-v{0}-curseforge.zip" -f $version)
$githubZip = Join-Path $outputRoot ("YiboAltoBoss-v{0}-github.zip" -f $version)
$cfTempZip = Join-Path $tempRoot (Split-Path $cfZip -Leaf)
$githubTempZip = Join-Path $tempRoot (Split-Path $githubZip -Leaf)

function Move-PreviousPackagesToArchive {
    param([Parameter(Mandatory = $true)][string]$PackageRoot)
    $archiveRoot = Join-Path $PackageRoot "Archive"
    New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
    $archived = 0
    Get-ChildItem -LiteralPath $PackageRoot -File -Filter "YiboAltoBoss-*.zip" | ForEach-Object {
        $destination = Join-Path $archiveRoot $_.Name
        if (Test-Path -LiteralPath $destination) {
            $destination = Join-Path $archiveRoot ("{0}-{1}{2}" -f $_.BaseName, (Get-Date -Format "yyyyMMdd-HHmmssfff"), $_.Extension)
        }
        Move-Item -LiteralPath $_.FullName -Destination $destination
        $archived++
    }
    return $archived
}

try {
    $cfStage = Join-Path $tempRoot "curseforge\\YiboAltoBoss"
    New-Item -ItemType Directory -Path $cfStage -Force | Out-Null
    Copy-Item -LiteralPath $tocPath -Destination $cfStage
    Get-Content -LiteralPath $tocPath | Where-Object { $_ -and $_ -notmatch '^\s*##' -and $_ -notmatch '^\s*#' } | ForEach-Object {
        $relativePath = $_.Trim(); $source = Join-Path $projectRoot $relativePath
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "TOC references missing file: $relativePath" }
        $target = Join-Path $cfStage $relativePath
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target
    }
    New-Item -ItemType Directory -Path (Join-Path $cfStage "Media") -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $projectRoot "Media") -File -Filter "*.tga" | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $cfStage "Media") }
    Compress-Archive -LiteralPath $cfStage -DestinationPath $cfTempZip -CompressionLevel Optimal

    $githubStage = Join-Path $tempRoot "github\\YiboAltoBoss"
    New-Item -ItemType Directory -Path $githubStage -Force | Out-Null
    $roboArgs = @($projectRoot, $githubStage, "/E", "/R:1", "/W:1", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/XD", ".git", "dist", "Builds", "tmp", "_NonRelease", "/XF", "AGENTS.md")
    & robocopy @roboArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
    Compress-Archive -LiteralPath $githubStage -DestinationPath $githubTempZip -CompressionLevel Optimal

    $archived = Move-PreviousPackagesToArchive -PackageRoot $outputRoot
    Move-Item -LiteralPath $cfTempZip -Destination $cfZip
    Move-Item -LiteralPath $githubTempZip -Destination $githubZip
    [pscustomobject]@{ Version = $version; CurseForge = $cfZip; GitHub = $githubZip; Archived = $archived } | Format-List
}
finally { if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force } }
