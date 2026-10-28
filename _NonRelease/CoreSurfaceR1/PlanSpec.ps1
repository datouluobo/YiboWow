#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
& (Join-Path $workspace '_NonRelease/CoreIdentityDomainsR1/PlanSpec.ps1')
if (-not $?) { throw 'Prior phase plan failed' }
. (Join-Path $workspace 'Tools/Release.Common.ps1')
$checks = 0
function Check($condition, $label) { $script:checks++; if (-not $condition) { throw $label } }
foreach ($target in @('Mists','Forever')) {
    $profile = Get-YiboReleaseProfile $workspace 'YiboCore' $target
    $paths = @((Get-YiboTocEntries $profile).Relative)
    Check ($paths -contains 'Common/ClientSurface.lua') 'Shared native validation included'
    Check ($paths -contains "$target/Surface.lua") 'Exactly applicable target binding included'
    Check ([array]::IndexOf($paths,"$target/Surface.lua") -lt [array]::IndexOf($paths,'Runtime/ItemResolver.lua')) 'Surface configured before consumers'
    Check ($paths -notcontains 'Retail/Surface.lua') 'No Retail implementation claimed'
    $other = if ($target -eq 'Mists') {'Forever'} else {'Mists'}
    Check ($paths -notcontains "$other/Surface.lua") 'Other target binding excluded'
}
foreach ($file in @('Runtime/ItemResolver.lua','Runtime/AddonStatus.lua','Data/AddonCatalog.lua','UI/ItemPicker.lua','UI/IconPicker.lua','UI/BusinessItemActions.lua')) {
    $source = Get-Content -LiteralPath (Join-Path $workspace "YiboCore/$file") -Raw
    Check ($source -notmatch '\b(GetItemInfo|RequestLoadItemDataByID|GetContainerNumSlots|GetContainerItemID|GetCursorInfo|GetMouseFoci|GetMouseFocus|GetAddOnInfo|GetAddOnEnableState|GetLooseMacroIcons|GetMacroIcons)\s*\(') "Native query routed through Client: $file"
}
Write-Output "CoreSurfaceR1 PlanSpec passed: $checks checks (item/UI target boundaries, plus inherited target/package plans)"
