#Requires -Version 7.2
[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateRange(1,999999)][int]$Interface)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$names = @('YiboRetailTocDefault','YiboRetailTocRetail','YiboRetailTocMainline','YiboRetailTocBoth','YiboRetailTocMissing')
$report = @()
foreach ($name in ($names + @('YiboRetailTocConsumer','YiboRetailTocObserver'))) {
    $folder = Join-Path $workspace "_NonRelease/$name"
    if (Test-Path -LiteralPath $folder) { throw "Probe directory already exists; inspect before preparing: $folder" }
}
function WriteProbe($name, $suffix, $entry, $body, $dependencies) {
    $folder = Join-Path $workspace "_NonRelease/$name"
    [void][IO.Directory]::CreateDirectory($folder)
    $tocName = "$name$suffix.toc"
    $lines = @("## Interface: $Interface", "## Title: |cff20e070[Yibo]|r Retail TOC probe - $name", '## Version: 0.1.0',
        "## X-Probe-Source: $tocName", "## X-Probe-Entry: $entry")
    if ($dependencies) { $lines += "## RequiredDeps: $dependencies" }
    $lines += $body
    [IO.File]::WriteAllText((Join-Path $folder $tocName), ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    $script:report += [ordered]@{ addon=$name; sourceToc=$tocName; entry=$entry; interface=$Interface }
}
foreach ($name in $names) {
    WriteProbe $name '' $(if ($name -eq 'YiboRetailTocDefault') {'default-target'} else {'hint'}) 'Probe.lua' $null
    [IO.File]::Copy((Join-Path $PSScriptRoot 'ProbeTemplates/Probe.lua'), (Join-Path $workspace "_NonRelease/$name/Probe.lua"))
}
WriteProbe 'YiboRetailTocRetail' '_Retail' 'retail' 'Probe.lua' $null
WriteProbe 'YiboRetailTocMainline' '_Mainline' 'mainline' 'Probe.lua' $null
foreach ($pair in @(@('_Retail','retail'), @('_Mainline','mainline'), @('_Mists','mists'), @('_Forever','forever'))) {
    WriteProbe 'YiboRetailTocBoth' $pair[0] $pair[1] 'Probe.lua' $null
}
foreach ($pair in @(@('_Mists','mists'), @('_Forever','forever'))) {
    WriteProbe 'YiboRetailTocMissing' $pair[0] $pair[1] 'Probe.lua' $null
}
WriteProbe 'YiboRetailTocConsumer' '' 'consumer' 'Consumer.lua' ($names -join ', ')
WriteProbe 'YiboRetailTocObserver' '' 'observer' 'Observer.lua' $null
foreach ($type in @('Consumer','Observer')) {
    [IO.File]::Copy((Join-Path $PSScriptRoot "ProbeTemplates/$type.lua"), (Join-Path $workspace "_NonRelease/YiboRetailToc$type/$type.lua"))
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'Prepared-Probes.json') -Encoding utf8
Write-Output 'Prepared seven independent, non-release probe directories. No client links or Core target were created.'
