[CmdletBinding()]
param([string]$Lua = 'lua', [string]$LuaCompiler = 'luac')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$suites = @(
    '_NonRelease/CoreForever/Smoke.lua',
    '_NonRelease/BuildsForever/Smoke.lua',
    '_NonRelease/CraftingForever/Smoke.lua',
    '_NonRelease/CurrencyForever/Smoke.lua',
    '_NonRelease/MailForever/Smoke.lua',
    '_NonRelease/ReputationForever/Smoke.lua',
    '_NonRelease/VaultForever/Smoke.lua',
    '_NonRelease/ForeverBatch/Integration.lua',
    '_NonRelease/YiboAltoBossForeverProbe/Tests/Smoke.lua',
    '_NonRelease/YiboBuildsForeverProbe/Tests/Smoke.lua',
    '_NonRelease/YiboProgressForeverProbe/Tests/Smoke.lua'
)
$tocs = @('YiboCore', 'YiboBuilds', 'YiboCrafting', 'YiboCurrency', 'YiboMail', 'YiboReputation', 'YiboVault') |
    ForEach-Object { Join-Path $root "$_/${_}_Forever.toc" }
$tocs += @('YiboAltoBossForeverProbe', 'YiboBuildsForeverProbe', 'YiboProgressForeverProbe') |
    ForEach-Object { Join-Path $root "_NonRelease/$_/$_.toc" }
$files = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($toc in $tocs) {
    if (-not (Test-Path -LiteralPath $toc -PathType Leaf)) { throw "Missing manifest: $toc" }
    $base = Split-Path -Parent $toc
    foreach ($line in Get-Content -LiteralPath $toc) {
        $relative = $line.Trim()
        if (-not $relative -or $relative.StartsWith('#')) { continue }
        if (-not $relative.EndsWith('.lua')) { throw "Review indirect manifest entry: $toc -> $relative" }
        $path = [IO.Path]::GetFullPath((Join-Path $base $relative))
        if (-not $path.StartsWith($base + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Manifest escapes addon: $path" }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing runtime file: $path" }
        [void]$files.Add($path)
    }
}
Push-Location $root
try {
    foreach ($path in $files) {
        & $LuaCompiler -p $path
        if ($LASTEXITCODE -ne 0) { throw "Lua syntax failed: $path" }
    }
    Write-Output "Lua syntax passed: $($files.Count) runtime files in $($tocs.Count) manifests."
    foreach ($suite in $suites) {
        & $Lua $suite
        if ($LASTEXITCODE -ne 0) { throw "Suite failed: $suite" }
    }
} finally { Pop-Location }
