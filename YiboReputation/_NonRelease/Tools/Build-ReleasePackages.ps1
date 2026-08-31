[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path,
    [string]$OutputRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\.." )).Path "Builds")
)

$ErrorActionPreference = "Stop"
$addonName = "YiboReputation"
$projectRoot = (Resolve-Path $ProjectRoot).Path
$tocPath = Join-Path $projectRoot "$addonName.toc"
$version = (Select-String -LiteralPath $tocPath -Pattern '^## Version:\s*(.+)$').Matches[0].Groups[1].Value.Trim().TrimStart('v', 'V')
$outputRoot = [IO.Path]::GetFullPath($OutputRoot)
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("$addonName-build-" + [guid]::NewGuid().ToString("N"))
$curseForgeStage = Join-Path $tempRoot "curseforge\$addonName"
$githubStage = Join-Path $tempRoot "github\$addonName"
$curseForgeOutput = Join-Path $outputRoot "$addonName-v$version-curseforge.zip"
$githubOutput = Join-Path $outputRoot "$addonName-v$version-github.zip"
$curseForgeTemp = Join-Path $tempRoot (Split-Path $curseForgeOutput -Leaf)
$githubTemp = Join-Path $tempRoot (Split-Path $githubOutput -Leaf)

function Move-PreviousPackagesToArchive {
    $archiveRoot = Join-Path $outputRoot "Archive"
    New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
    $moved = 0
    Get-ChildItem -LiteralPath $outputRoot -File -Filter "$addonName-*.zip" | ForEach-Object {
        $destination = Join-Path $archiveRoot $_.Name
        if (Test-Path -LiteralPath $destination) {
            $destination = Join-Path $archiveRoot ("{0}-{1}{2}" -f $_.BaseName, (Get-Date -Format "yyyyMMdd-HHmmssfff"), $_.Extension)
        }
        Move-Item -LiteralPath $_.FullName -Destination $destination
        $moved++
    }
    return $moved
}

try {
    New-Item -ItemType Directory -Path $curseForgeStage, $githubStage -Force | Out-Null
    Copy-Item -LiteralPath $tocPath -Destination $curseForgeStage
    Get-Content -LiteralPath $tocPath | Where-Object { $_ -and $_ -notmatch '^\s*##' -and $_ -notmatch '^\s*#' } | ForEach-Object {
        $relativePath = $_.Trim()
        $source = Join-Path $projectRoot $relativePath
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "TOC references missing file: $relativePath" }
        $target = Join-Path $curseForgeStage $relativePath
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target
    }
    $media = Join-Path $projectRoot "Media"
    if (Test-Path -LiteralPath $media) { Copy-Item -LiteralPath $media -Destination $curseForgeStage -Recurse -Force }
    $robocopyArgs = @($projectRoot, $githubStage, "/E", "/R:1", "/W:1", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/XD", ".git", "dist", "Builds", "tmp", "_NonRelease", "/XF", "AGENTS.md")
    & robocopy @robocopyArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
    Compress-Archive -LiteralPath $curseForgeStage -DestinationPath $curseForgeTemp -CompressionLevel Optimal
    Compress-Archive -LiteralPath $githubStage -DestinationPath $githubTemp -CompressionLevel Optimal
    $archived = Move-PreviousPackagesToArchive
    Move-Item -LiteralPath $curseForgeTemp -Destination $curseForgeOutput
    Move-Item -LiteralPath $githubTemp -Destination $githubOutput
    [pscustomobject]@{ Version = $version; CurseForge = $curseForgeOutput; GitHub = $githubOutput; Archived = $archived } | Format-List
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
