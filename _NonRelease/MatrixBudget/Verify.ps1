[CmdletBinding()]
param()
$ErrorActionPreference = "Stop"
$matrixTaskRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Push-Location -LiteralPath $matrixTaskRoot
try {
    $matrixLua = (Get-Command lua -ErrorAction Stop).Source
    foreach ($arguments in @(
        @("_NonRelease/MatrixBudget/Spec.lua", "zhCN"),
        @("_NonRelease/MatrixBudget/Spec.lua", "enUS"),
        @("_NonRelease/MatrixBudget/Spec.lua", "zhCN", "en"),
        @("_NonRelease/MatrixBudget/Spec.lua", "enUS", "zh")
    )) {
        & $matrixLua @arguments
        if ($LASTEXITCODE -ne 0) { throw "Matrix check failed: $($arguments -join ' ')" }
    }
    & (Join-Path $matrixTaskRoot "_NonRelease/CurrencyMigration/Verify.ps1")
    foreach ($path in @(
        "YiboAltoBoss/_NonRelease/Tests/InstanceKillsSpec.lua",
        "YiboCrafting/Tests/CoreAdaptation.lua",
        "YiboCrafting/Tests/CoreNameIntegration.lua",
        "YiboCrafting/Tests/Smoke.lua",
        "YiboCrafting/Tests/SearchPerformance.lua",
        "YiboCrafting/Tests/RecipeScanScheduling.lua",
        "YiboCrafting/Tests/RecipeStateScanner.lua",
        "YiboCrafting/Tests/GoalTargets.lua",
        "_NonRelease/ReputationMigration/HoverSpec.lua"
    )) {
        & $matrixLua $path
        if ($LASTEXITCODE -ne 0) { throw "Regression failed: $path" }
    }
    & (Join-Path $matrixTaskRoot "Tools/Test-LuaSyntax.ps1") -Addon YiboCore,YiboCurrency,YiboReputation,YiboAltoBoss,YiboCrafting,YiboLegendary,YiboQuestBlocker
    & python Tools/Check-Localization.py --addon YiboCore YiboCurrency YiboReputation YiboAltoBoss YiboCrafting YiboLegendary YiboQuestBlocker --strict-core --output _NonRelease/Localization/MatrixBudget-Report.md
    if ($LASTEXITCODE -ne 0) { throw "Matrix localization check failed" }
    $matrixReport = Get-Content -LiteralPath _NonRelease/Localization/MatrixBudget-Report.json -Raw | ConvertFrom-Json
    foreach ($category in @("missingEnglish", "duplicateKeys", "formatMismatch", "unknownKeys")) {
        if (@($matrixReport.$category).Count -ne 0) { throw "Localization issue: $category" }
    }
    Write-Host "PASS: all ledger matrices use Core scroll budgets. Real client acceptance is pending."
} finally {
    Pop-Location
}
