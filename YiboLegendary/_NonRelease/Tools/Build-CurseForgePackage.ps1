[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$OutputRoot = (Join-Path $PSScriptRoot "..\Builds")
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path $ProjectRoot).Path
$tocPath = Join-Path $projectRoot "YiboLegendary.toc"
$version = (Select-String -LiteralPath $tocPath -Pattern '^## Version:\s*(.+)$').Matches[0].Groups[1].Value.Trim().TrimStart('v', 'V')
$outputRoot = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("YiboLegendary-build-" + [guid]::NewGuid().ToString("N"))
$curseForgeStage = Join-Path $tempRoot "curseforge\YiboLegendary"
$githubStage = Join-Path $tempRoot "github\YiboLegendary"
$curseForgeZip = Join-Path $outputRoot ("YiboLegendary-v{0}-curseforge.zip" -f $version)
$githubZip = Join-Path $outputRoot ("YiboLegendary-v{0}-github.zip" -f $version)

try {
    New-Item -ItemType Directory -Path $curseForgeStage -Force | Out-Null
    Copy-Item -LiteralPath $tocPath -Destination $curseForgeStage
    Get-Content -LiteralPath $tocPath | Where-Object { $_ -and $_ -notmatch '^\s*##' -and $_ -notmatch '^\s*#' } | ForEach-Object {
        $relativePath = $_.Trim()
        $source = Join-Path $projectRoot $relativePath
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "TOC references missing file: $relativePath" }
        $target = Join-Path $curseForgeStage $relativePath
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target
    }
    New-Item -ItemType Directory -Path (Join-Path $curseForgeStage "Media") -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $projectRoot "Media") -Filter "*.tga" -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $curseForgeStage "Media")
    }
    if (Test-Path -LiteralPath $curseForgeZip) { Remove-Item -LiteralPath $curseForgeZip -Force }
    Compress-Archive -LiteralPath (Join-Path $tempRoot "curseforge\YiboLegendary") -DestinationPath $curseForgeZip -CompressionLevel Optimal

    New-Item -ItemType Directory -Path $githubStage -Force | Out-Null
    $robocopyArgs = @($projectRoot, $githubStage, "/E", "/R:1", "/W:1", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/XD", ".git", "dist", "Builds", "tmp", "/XF", "AGENTS.md")
    & robocopy @robocopyArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
    if (Test-Path -LiteralPath $githubZip) { Remove-Item -LiteralPath $githubZip -Force }
    Compress-Archive -LiteralPath (Join-Path $tempRoot "github\YiboLegendary") -DestinationPath $githubZip -CompressionLevel Optimal

    [pscustomobject]@{
        Version = $version
        CurseForge = $curseForgeZip
        GitHub = $githubZip
        CurseForgeFiles = (Get-ChildItem -LiteralPath $curseForgeStage -Recurse -File).Count
        GitHubFiles = (Get-ChildItem -LiteralPath $githubStage -Recurse -File).Count
    } | Format-List
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
