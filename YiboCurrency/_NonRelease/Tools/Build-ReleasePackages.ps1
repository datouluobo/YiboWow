[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$OutputRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path "Builds")
)

$ErrorActionPreference = "Stop"
$addonName = "YiboCurrency"
$projectRoot = (Resolve-Path $ProjectRoot).Path
$outputRoot = [IO.Path]::GetFullPath($OutputRoot)
$tocPath = Join-Path $projectRoot "$addonName.toc"
$tocText = Get-Content -LiteralPath $tocPath
$versionLine = $tocText | Where-Object { $_ -match '^## Version:\s*(.+)$' } | Select-Object -First 1
if (-not $versionLine) { throw "Unable to read Currency TOC version" }
$version = ([regex]::Match($versionLine, '^## Version:\s*(.+)$')).Groups[1].Value.Trim()
$bootstrap = Get-Content -LiteralPath (Join-Path $projectRoot "Bootstrap.lua") -Raw
if ($bootstrap -notmatch 'Addon\.NAME, Addon\.VERSION\s*=\s*"YiboCurrency",\s*"([^"]+)"') {
    throw "Unable to read Currency Bootstrap version"
}
if ($Matches[1] -ne $version) { throw "Currency TOC and Bootstrap versions differ" }

function Package-Entry {
    param([string]$Source, [string]$Relative)
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { throw "Package source is missing: $Source" }
    [pscustomobject]@{ Source = $Source; Entry = "$addonName/$($Relative.Replace('\', '/'))" }
}

function New-PackageFile {
    param([string]$Path, [object[]]$Files)
    if (Test-Path -LiteralPath $Path) { throw "Package already exists: $Path" }
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew)
    try {
        $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            foreach ($file in $Files) {
                [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $archive, $file.Source, $file.Entry, [IO.Compression.CompressionLevel]::Optimal)
            }
        }
        finally { $archive.Dispose() }
    }
    finally { $stream.Dispose() }
}

$releaseFiles = @(Package-Entry $tocPath "$addonName.toc")
foreach ($line in $tocText) {
    $relative = $line.Trim()
    if ($relative -eq '' -or $relative.StartsWith('#')) { continue }
    $source = [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
    if (-not $source.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "TOC entry escapes project root: $relative"
    }
    $releaseFiles += Package-Entry $source $relative
}
Get-ChildItem -LiteralPath (Join-Path $projectRoot "Media") -File -Filter "*.tga" | Sort-Object Name | ForEach-Object {
    $relative = "Media/$($_.Name)"
    if (-not ($releaseFiles | Where-Object Entry -eq "$addonName/$relative")) {
        $releaseFiles += Package-Entry $_.FullName $relative
    }
}

$githubFiles = @()
Get-ChildItem -LiteralPath $projectRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($projectRoot, $_.FullName).Replace('\', '/')
    if ($relative -match '^(?:_NonRelease|\.git|Builds|dist|tmp)/' -or $relative -eq 'AGENTS.md') { return }
    $githubFiles += Package-Entry $_.FullName $relative
}

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$releasePath = Join-Path $outputRoot "$addonName-v$version.zip"
$githubPath = Join-Path $outputRoot "$addonName-v$version-github.zip"
$releaseTemp, $githubTemp = "$releasePath.building", "$githubPath.building"
if ((Test-Path -LiteralPath $releasePath) -or (Test-Path -LiteralPath $githubPath) -or (Test-Path -LiteralPath $releaseTemp) -or (Test-Path -LiteralPath $githubTemp)) {
    throw "A package or intermediate file already exists for $version"
}
New-PackageFile $releaseTemp $releaseFiles
New-PackageFile $githubTemp $githubFiles
Move-Item -LiteralPath $releaseTemp -Destination $releasePath
Move-Item -LiteralPath $githubTemp -Destination $githubPath
[pscustomobject]@{ Version = $version; Release = $releasePath; GitHub = $githubPath } | Format-List
