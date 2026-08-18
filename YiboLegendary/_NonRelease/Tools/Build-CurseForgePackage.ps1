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
$stage = Join-Path $tempRoot "YiboLegendary"
$zip = Join-Path $outputRoot ("YiboLegendary-v{0}-curseforge.zip" -f $version)

try {
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Copy-Item -LiteralPath $tocPath -Destination $stage
    Get-Content -LiteralPath $tocPath | Where-Object { $_ -and $_ -notmatch '^\s*##' -and $_ -notmatch '^\s*#' } | ForEach-Object {
        $relativePath = $_.Trim()
        $source = Join-Path $projectRoot $relativePath
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "TOC references missing file: $relativePath" }
        $target = Join-Path $stage $relativePath
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target
    }
    New-Item -ItemType Directory -Path (Join-Path $stage "Media") -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $projectRoot "Media") -Filter "*.tga" -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $stage "Media")
    }
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -LiteralPath (Join-Path $tempRoot "YiboLegendary") -DestinationPath $zip -CompressionLevel Optimal
    [pscustomobject]@{ Version = $version; Package = $zip; Files = (Get-ChildItem -LiteralPath $stage -Recurse -File | ForEach-Object FullName) } | Format-List
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
