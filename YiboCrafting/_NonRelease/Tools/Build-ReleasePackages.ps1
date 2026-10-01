[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$OutputRoot
)

$ErrorActionPreference = "Stop"
$addonName = "YiboCrafting"
if (-not $ProjectRoot) { $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path }
if (-not $OutputRoot) { $OutputRoot = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path "Builds" }
$projectRoot = (Resolve-Path $ProjectRoot).Path
$tocPath = Join-Path $projectRoot "$addonName.toc"
$toc = @(Get-Content -LiteralPath $tocPath)
$versionLine = $toc | Where-Object { $_ -match '^## Version:\s*(.+)$' } | Select-Object -First 1
if (-not $versionLine) { throw "Unable to read $addonName TOC version" }
$version = ([regex]::Match($versionLine, '^## Version:\s*(.+)$')).Groups[1].Value.Trim().TrimStart('v', 'V')
$namespace = Get-Content -LiteralPath (Join-Path $projectRoot "Namespace.lua") -Raw
if ($namespace -notmatch 'Addon\.VERSION\s*=\s*"([^"]+)"') { throw "Unable to read $addonName Namespace version" }
if ($Matches[1] -ne $version) { throw "$addonName TOC and Namespace versions differ" }

$outputRoot = [IO.Path]::GetFullPath($OutputRoot)
$releasePath = Join-Path $outputRoot "$addonName-v$version-curseforge.zip"
$githubPath = Join-Path $outputRoot "$addonName-v$version-github.zip"
if ((Test-Path -LiteralPath $releasePath) -or (Test-Path -LiteralPath $githubPath)) {
    throw "A package already exists for $addonName v$version"
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("$addonName-build-" + [guid]::NewGuid().ToString("N"))
$releaseStage = Join-Path $tempRoot "curseforge\$addonName"
$githubStage = Join-Path $tempRoot "github\$addonName"
try {
    New-Item -ItemType Directory -Path $releaseStage, $githubStage, $outputRoot -Force | Out-Null
    Copy-Item -LiteralPath $tocPath -Destination $releaseStage
    foreach ($line in $toc) {
        $relative = $line.Trim()
        if ($relative -eq '' -or $relative.StartsWith('#')) { continue }
        $source = [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
        if (-not $source.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "TOC entry escapes project root: $relative"
        }
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "TOC references missing file: $relative" }
        $destination = Join-Path $releaseStage $relative
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination
    }
    $media = Join-Path $projectRoot "Media"
    if (Test-Path -LiteralPath $media) {
        Copy-Item -LiteralPath $media -Destination $releaseStage -Recurse -Force
    }
    & robocopy $projectRoot $githubStage /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /XD .git dist Builds tmp _NonRelease /XF AGENTS.md | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
    Compress-Archive -LiteralPath $releaseStage -DestinationPath $releasePath -CompressionLevel Optimal
    Compress-Archive -LiteralPath $githubStage -DestinationPath $githubPath -CompressionLevel Optimal
    [pscustomobject]@{ Version = $version; CurseForge = $releasePath; GitHub = $githubPath } | Format-List
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
