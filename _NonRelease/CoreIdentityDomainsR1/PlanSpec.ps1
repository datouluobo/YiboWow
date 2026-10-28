#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
& (Join-Path $workspace '_NonRelease/CoreStartupR1/PlanSpec.ps1')
. (Join-Path $workspace 'Tools/Release.Common.ps1')
$checks = 0
function Check($condition, $label) {
    $script:checks++
    if (-not $condition) { throw $label }
}
foreach ($target in @('Mists', 'Forever')) {
    $profile = Get-YiboReleaseProfile $workspace 'YiboCore' $target
    $entries = @(Get-YiboTocEntries $profile)
    $paths = @($entries.Relative)
    foreach ($shared in @('Runtime/Client.lua', 'Common/ClientReaders.lua', 'Common/ProfessionDomain.lua',
        'Data/Domains/Identity.lua', 'Data/Domains/Location.lua', 'Data/Fields/CharacterArchive.lua')) {
        Check ($paths -contains $shared) 'Shared definition loaded exactly once'
    }
    Check ($paths -contains "$target/Client.lua" -and $paths -contains "$target/Fields.lua") 'Target bindings and field policy present'
    foreach ($name in @('Professions', 'Equipment', 'Specialization')) {
        $old = "Data/Domains/$name.lua"
        Check ((Test-Path -LiteralPath (Join-Path $profile.Root $old)) -and $paths -notcontains $old) 'Retained old file excluded from live graph'
        if ($target -eq 'Mists') { Check ($paths -contains "Mists/$name.lua") 'Mists collector moved to target directory' }
    }
    $caps = @{}
    foreach ($entry in $entries) {
        $text = [IO.File]::ReadAllText($entry.Source)
        foreach ($match in [regex]::Matches($text, 'Capabilities:Register\("([^"]+)",\s*(\d+)\)')) {
            $caps[$match.Groups[1].Value] = [int]$match.Groups[2].Value
        }
        Check ($text -notmatch '\b(?:dofile|loadfile|LoadAddOn)\s*\(') 'No new indirect runtime file load'
    }
    Check ($caps.Count -eq 33) 'Effective capability set remains 33 per target'
    Check ($caps.ContainsKey('profession-profile') -eq ($target -eq 'Forever')) 'Only verified target declares profession-profile'
    Check ($caps.ContainsKey('calendar-day-query') -eq ($target -eq 'Mists')) 'Calendar remains Mists only'
    Check ($paths.IndexOf("$target/Client.lua") -lt $paths.IndexOf('Data/Characters.lua')) 'Native binding precedes directory use'
    Check ($paths.IndexOf("$target/Fields.lua") -lt $paths.IndexOf('Data/Fields/CharacterArchive.lua')) 'Policy precedes field registration'
}
Write-Output "CoreIdentityDomainsR1 PlanSpec passed: $checks checks (target migration, retained paths and capability declarations)"
