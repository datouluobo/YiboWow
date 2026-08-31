[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string[]]$Addon
)

$ErrorActionPreference = "Stop"

if (-not $ProjectRoot) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Find-LuaCompiler {
    $candidates = [System.Collections.Generic.List[string]]::new()
    foreach ($commandName in "luac5.1", "luac") {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command -and $command.Source) { $candidates.Add($command.Source) }
    }
    $candidates.Add("C:\Program Files (x86)\Lua\5.1\luac.exe")
    $candidates.Add("C:\Program Files\Lua\5.1\luac.exe")
    $candidates = @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })

    if ($candidates.Count -eq 0) {
        throw "Lua 5.1 compiler not found. Install Lua for Windows 5.1, then rerun: winget install --id rjpcomputing.luaforwindows --exact"
    }

    return $candidates[0]
}

function Get-TocLuaFiles {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$Toc)

    $addonRoot = $Toc.Directory.FullName
    foreach ($line in Get-Content -LiteralPath $Toc.FullName) {
        $relativePath = $line.Trim()
        if (-not $relativePath -or $relativePath.StartsWith("#") -or -not $relativePath.EndsWith(".lua", [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $luaPath = Join-Path $addonRoot $relativePath
        if (-not (Test-Path -LiteralPath $luaPath -PathType Leaf)) {
            throw "TOC references missing Lua file: $($Toc.FullName) -> $relativePath"
        }
        Get-Item -LiteralPath $luaPath
    }
}

$compiler = Find-LuaCompiler
$version = (& $compiler -v 2>&1 | Select-Object -First 1)
if ($version -notmatch "Lua 5\.1") {
    throw "Expected a Lua 5.1 compiler for WoW syntax checks, but found: $version"
}

$addonRoots = Get-ChildItem -LiteralPath $ProjectRoot -Directory -Filter "Yibo*" | Sort-Object Name
if ($Addon) {
    $wanted = [System.Collections.Generic.HashSet[string]]::new($Addon, [System.StringComparer]::OrdinalIgnoreCase)
    $addonRoots = @($addonRoots | Where-Object { $wanted.Contains($_.Name) })
    $unknown = @($Addon | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_) -PathType Container) })
    if ($unknown.Count -gt 0) { throw "Unknown addon directory: $($unknown -join ', ')" }
}

$tocs = @($addonRoots | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Filter "*.toc" } | Sort-Object FullName)
if ($tocs.Count -eq 0) { throw "No addon TOC files found under $ProjectRoot" }

$files = @($tocs | ForEach-Object { Get-TocLuaFiles -Toc $_ } | Sort-Object FullName -Unique)
$errors = [System.Collections.Generic.List[string]]::new()
foreach ($file in $files) {
    & $compiler -p $file.FullName 2>&1 | ForEach-Object { $errors.Add("$_") }
    if ($LASTEXITCODE -ne 0) { continue }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    throw "Lua syntax check failed for $($errors.Count) compiler diagnostic(s)."
}

Write-Host "Lua 5.1 syntax check passed: $($files.Count) files from $($tocs.Count) TOC file(s)."
