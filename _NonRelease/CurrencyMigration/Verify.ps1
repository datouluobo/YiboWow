[CmdletBinding()]
param()
$ErrorActionPreference = "Stop"
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Push-Location -LiteralPath $taskRoot
try {
    $lua = (Get-Command lua -ErrorAction Stop).Source
    $python = (Get-Command python -ErrorAction Stop).Source
    $cases = @(
        @("_NonRelease/CurrencyMigration/RetentionSpec.lua"),
        @("_NonRelease/CurrencyMigration/TocSpec.lua"),
        @("_NonRelease/CurrencyMigration/ScrollBudgetSpec.lua"),
        @("YiboCurrency/_NonRelease/Tests/BalanceSpec.lua"),
        @("YiboCurrency/_NonRelease/Tests/VaultIntegrationSpec.lua"),
        @("YiboCurrency/_NonRelease/Tests/API13Spec.lua", "zhCN"),
        @("YiboCurrency/_NonRelease/Tests/API13Spec.lua", "enUS"),
        @("YiboCurrency/_NonRelease/Tests/API13Spec.lua", "zhCN", "en"),
        @("YiboCurrency/_NonRelease/Tests/API13Spec.lua", "enUS", "zh"),
        @("YiboCurrency/_NonRelease/Tests/CoreItemControlsSpec.lua"),
        @("-e", 'GetLocale=function() return "enUS" end; dofile("YiboCurrency/_NonRelease/Tests/CoreItemControlsSpec.lua")'),
        @("YiboCore/_NonRelease/Tests/ContractsSpec.lua"),
        @("YiboCore/_NonRelease/Tests/CharacterNamesSpec.lua"),
        @("_NonRelease/EntryBar/EntryBarSpec.lua"),
        @("_NonRelease/ReputationMigration/RetentionSpec.lua")
    )
    foreach ($case in $cases) {
        & $lua @case
        if ($LASTEXITCODE -ne 0) { throw "Lua check failed: $($case -join ' ')" }
    }
    & (Join-Path $taskRoot "Tools/Test-LuaSyntax.ps1") -Addon YiboCore,YiboCurrency,YiboReputation
    & $python Tools/Check-Localization.py --addon YiboCore YiboCurrency --strict-core --output _NonRelease/Localization/YiboCurrency-Migration-Report.md
    if ($LASTEXITCODE -ne 0) { throw "Localization check failed" }
    $report = Get-Content -LiteralPath _NonRelease/Localization/YiboCurrency-Migration-Report.json -Raw | ConvertFrom-Json
    foreach ($key in @("missingEnglish", "extraEnglish", "duplicateKeys", "formatMismatch", "unknownKeys", "hardcoded")) {
        if (@($report.$key).Count -ne 0) { throw "Localization issue: $key" }
    }
    Write-Host "PASS: Currency migration offline acceptance checks. Real client acceptance remains pending."
} finally {
    Pop-Location
}
