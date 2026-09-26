[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path 'Builds')
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$workspaceRoot = (Resolve-Path -LiteralPath (Join-Path $projectRoot '..')).Path
$addonName = Split-Path $projectRoot -Leaf
if ($addonName -ne 'YiboBuilds') { throw "Unexpected addon root: $projectRoot" }

$tocPath = Join-Path $projectRoot 'YiboBuilds.toc'
$tocVersion = Select-String -LiteralPath $tocPath -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
$codeVersion = Select-String -LiteralPath (Join-Path $projectRoot 'Bootstrap.lua') -Pattern '^Addon\.VERSION\s*=\s*"([^"]+)"' | Select-Object -First 1
if (-not $tocVersion -or -not $codeVersion) { throw 'Missing release version in TOC or Bootstrap.lua.' }
$version = $tocVersion.Matches[0].Groups[1].Value.Trim()
if ($version -ne $codeVersion.Matches[0].Groups[1].Value) { throw 'TOC and runtime versions differ.' }

$outputRoot = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$curseForgeOutput = Join-Path $outputRoot "$addonName-v$version-curseforge.zip"
$githubOutput = Join-Path $outputRoot "$addonName-v$version-github.zip"
if ((Test-Path -LiteralPath $curseForgeOutput) -or (Test-Path -LiteralPath $githubOutput)) {
    throw "A v$version package already exists; choose a new version or handle the existing package explicitly."
}

$runtime = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
[void]$runtime.Add('YiboBuilds.toc')
foreach ($line in Get-Content -LiteralPath $tocPath) {
    $relative = $line.Trim()
    if ($relative -and -not $relative.StartsWith('#')) { [void]$runtime.Add($relative) }
}
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'Media') -File -Filter '*.tga' | ForEach-Object {
    [void]$runtime.Add("Media\$($_.Name)")
}

$source = @(& git -C $workspaceRoot ls-files --cached -- YiboBuilds) | Where-Object {
    $_ -like 'YiboBuilds/*' -and $_ -notlike 'YiboBuilds/_NonRelease/*' -and $_ -notlike 'YiboBuilds/dist/*'
} | ForEach-Object { $_.Substring('YiboBuilds/'.Length).Replace('/', '\') }
if ($LASTEXITCODE -ne 0 -or @($source).Count -eq 0) { throw 'Unable to list tracked YiboBuilds source files.' }

function Write-Package {
    param([string]$Path, [string[]]$Files)
    $zip = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($relative in @($Files | Sort-Object -Unique)) {
            $file = Join-Path $projectRoot $relative
            if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Package source is missing: $file" }
            $entry = "$addonName/$($relative.Replace('\', '/'))"
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $file, $entry, [IO.Compression.CompressionLevel]::Optimal)
        }
    }
    finally { $zip.Dispose() }
}

Write-Package -Path $curseForgeOutput -Files @($runtime)
Write-Package -Path $githubOutput -Files @($source)
[pscustomobject]@{
    Version = $version
    CurseForge = $curseForgeOutput
    GitHub = $githubOutput
    RuntimeFiles = $runtime.Count
    SourceFiles = @($source).Count
} | Format-List
