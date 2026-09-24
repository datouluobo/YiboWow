param(
    [string]$Build = "5.5.4.68042",
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\YiboBuilds\Data")
)

$ErrorActionPreference = "Stop"
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

function Get-Db2Csv([string]$Table) {
    $uri = "https://wago.tools/db2/$Table/csv?build=$Build"
    return (Invoke-WebRequest -Uri $uri -TimeoutSec 60).Content | ConvertFrom-Csv
}

function ConvertTo-LuaString([string]$Value) {
    if ($null -eq $Value) { return "nil" }
    return '"' + $Value.Replace("\", "\\").Replace('"', '\"').Replace("`r", "").Replace("`n", "\n") + '"'
}

# These are the engineering gear-enhancement records present in the 5.5.4
# client. Slot values use WoW inventory slot IDs. Excludes the client test row
# 3291; includes stat scopes, which are permanent enchant records rather than
# the on-use-tinker effect type.
$engineeringSlots = @{
    3290 = 15; 3599 = 6; 3601 = 6; 3603 = 10; 3604 = 10; 3605 = 15
    3859 = 15; 3860 = 10; 4175 = 18; 4179 = 10; 4180 = 10; 4181 = 10
    4187 = 6; 4188 = 6; 4214 = 6; 4222 = 1; 4223 = 6; 4697 = 10
    4698 = 10; 4699 = 18; 4700 = 18; 4750 = 6; 4897 = 15; 4898 = 10
    5000 = 6; 5063 = 10
}
$nativeTooltipSpellAliases = @{
    3601 = @(54793); 3603 = @(54998); 3604 = @(54999); 3605 = @(55002)
    4179 = @(82175); 4180 = @(82177); 4181 = @(82180); 4187 = @(84424)
    4188 = @(84427); 4214 = @(84425); 4223 = @(55016); 4697 = @(108789)
    4698 = @(109077); 4699 = @(109086); 4700 = @(109093); 4750 = @(82200)
    4897 = @(126392); 4898 = @(126731); 5000 = @(109099)
}
$professionNames = @{
    164 = "锻造"; 165 = "制皮"; 171 = "炼金术"; 197 = "裁缝"; 202 = "工程学"
    333 = "附魔"; 755 = "珠宝加工"; 773 = "铭文"
}
$buckleSocketRecords = @(3729, 5002)

$enchantments = Get-Db2Csv "SpellItemEnchantment"
$spellEffects = Get-Db2Csv "SpellEffect"
$itemEffects = Get-Db2Csv "ItemEffect"
$columns = $enchantments[0].PSObject.Properties.Name
$professionColumn = $columns | Where-Object { $_ -match "_014$" } | Select-Object -First 1
$requiredSkillColumn = $columns | Where-Object { $_ -match "_015$" } | Select-Object -First 1
$applyRecordIDs = [System.Collections.Generic.HashSet[int]]::new()
$scrollBySpellID = @{}
foreach ($itemEffect in $itemEffects) {
    if ($itemEffect.TriggerType -eq "0" -and [int]$itemEffect.ParentItemID -gt 0) {
        $scrollBySpellID[[int]$itemEffect.SpellID] = [int]$itemEffect.ParentItemID
    }
}
$scrollByRecordID = @{}
$applySpellByRecordID = @{}
foreach ($effect in $spellEffects) {
    if ($effect.Effect -eq "53") {
        $recordID = 0
        if ([int]::TryParse($effect.EffectMiscValue_0, [ref]$recordID) -and $recordID -gt 0) {
            [void]$applyRecordIDs.Add($recordID)
            $spellID = [int]$effect.SpellID
            if (-not $applySpellByRecordID.ContainsKey($recordID)) { $applySpellByRecordID[$recordID] = $spellID }
            $scrollID = [int]$effect.EffectItemType
            if ($scrollID -le 0 -and $scrollBySpellID.ContainsKey($spellID)) { $scrollID = $scrollBySpellID[$spellID] }
            if ($scrollID -gt 0 -and -not $scrollByRecordID.ContainsKey($recordID)) { $scrollByRecordID[$recordID] = $scrollID }
        }
    }
}

$regular = @($enchantments | Where-Object {
    $recordID = [int]$_.ID
    $applyRecordIDs.Contains($recordID) -and -not $engineeringSlots.ContainsKey($recordID)
} | Sort-Object { [int]$_.ID })

$regularLines = [System.Collections.Generic.List[string]]::new()
$regularLines.Add("-- Generated from WoW client DB2 build $Build.")
$regularLines.Add("-- IDs are SpellItemEnchantment records; itemID is the applying scroll/item when known.")
$regularLines.Add("local catalog = {}")
foreach ($row in $regular) {
    $name = ConvertTo-LuaString $row.Name_lang
    $resolvedName = [string]$row.Name_lang
    $resolved = $true
    for ($index = 0; $index -lt 3; $index++) {
        $token = '$k' + ($index + 1)
        if ($resolvedName.Contains($token)) {
            $minimum = [int]$row.("EffectPointsMin_$index")
            $maximum = [int]$row.("EffectPointsMax_$index")
            if ($minimum -le 0 -or $minimum -ne $maximum) { $resolved = $false; break }
            $resolvedName = $resolvedName.Replace($token, [string]$minimum)
        }
    }
    $displayName = if ($resolved -and $resolvedName -ne $row.Name_lang -and $resolvedName -notmatch '\$') {
        ", displayName = " + (ConvertTo-LuaString $resolvedName)
    } else { "" }
    $professionID = 0
    if ($professionColumn) { [void][int]::TryParse($row.$professionColumn, [ref]$professionID) }
    $metadata = ""
    if ($professionNames.ContainsKey($professionID)) {
        $professionName = ConvertTo-LuaString $professionNames[$professionID]
        $requiredSkill = [int]$row.$requiredSkillColumn
        $metadata = ", professionID = $professionID, profession = $professionName, requiredSkill = $requiredSkill"
    }
    $recordID = [int]$row.ID
    $source = ""
    if ($scrollByRecordID.ContainsKey($recordID)) { $source += ", itemID = $($scrollByRecordID[$recordID])" }
    if ($applySpellByRecordID.ContainsKey($recordID)) { $source += ", spellID = $($applySpellByRecordID[$recordID])" }
    $regularLines.Add(("catalog[{0}] = {{ name = {1}, minLevel = {2}, maxLevel = {3}{4}{5}{6} }}" -f $recordID, $name, ([int]$row.MinLevel), ([int]$row.MaxLevel), $metadata, $displayName, $source))
}
$regularLines.Add("_G.YiboBuilds = _G.YiboBuilds or {}")
$regularLines.Add("_G.YiboBuilds.EnchantCatalog = catalog")
$regularLines.Add("")
[System.IO.File]::WriteAllText((Join-Path $OutputDirectory "EnchantCatalog.lua"), ($regularLines -join "`n"), [System.Text.UTF8Encoding]::new($false))

$professionEnchantments = @($enchantments | Where-Object {
    $recordID = [int]$_.ID
    $professionID = 0
    if ($professionColumn) { [void][int]::TryParse($_.$professionColumn, [ref]$professionID) }
    $isSocket = $_.Effect_0 -eq "8" -or $_.Effect_1 -eq "8" -or $_.Effect_2 -eq "8"
    $isApplyable = $applyRecordIDs.Contains($recordID) -or $isSocket
    $hasProfession = $professionNames.ContainsKey($professionID) -or $buckleSocketRecords -contains $recordID -or $engineeringSlots.ContainsKey($recordID)
    $notTestData = $_.Name_lang -notmatch "(?i)^(test|placeholder)"
    $isApplyable -and $hasProfession -and $notTestData
} | Sort-Object { [int]$_.ID })

$professionLines = [System.Collections.Generic.List[string]]::new()
$professionLines.Add("-- Profession ownership and required-skill metadata from client DB2 build $Build.")
$professionLines.Add("local catalog = {}")
foreach ($row in $professionEnchantments) {
    $recordID = [int]$row.ID
    $professionID = 0
    if ($professionColumn) { [void][int]::TryParse($row.$professionColumn, [ref]$professionID) }
    if ($buckleSocketRecords -contains $recordID) { $professionID = 164 }
    if ($engineeringSlots.ContainsKey($recordID)) { $professionID = 202 }
    $isSocket = $row.Effect_0 -eq "8" -or $row.Effect_1 -eq "8" -or $row.Effect_2 -eq "8"
    $kind = if ($isSocket) { "socket" } else { "enchant" }
    $professionName = ConvertTo-LuaString $professionNames[$professionID]
    $name = ConvertTo-LuaString $row.Name_lang
    $requiredSkill = 0
    if ($requiredSkillColumn) { [void][int]::TryParse($row.$requiredSkillColumn, [ref]$requiredSkill) }
    $professionLines.Add(("catalog[{0}] = {{ professionID = {1}, profession = {2}, requiredSkill = {3}, kind = {4}, name = {5} }}" -f $recordID, $professionID, $professionName, $requiredSkill, (ConvertTo-LuaString $kind), $name))
}
$professionLines.Add("_G.YiboBuilds = _G.YiboBuilds or {}")
$professionLines.Add("_G.YiboBuilds.ProfessionCatalog = catalog")
$professionLines.Add("")
[System.IO.File]::WriteAllText((Join-Path $OutputDirectory "ProfessionCatalog.lua"), ($professionLines -join "`n"), [System.Text.UTF8Encoding]::new($false))

$socketEffects = @($enchantments | Where-Object {
    ($_.Effect_0 -eq "8" -or $_.Effect_1 -eq "8" -or $_.Effect_2 -eq "8") -and $_.Name_lang -notmatch "(?i)^(test|placeholder)"
} | Sort-Object { [int]$_.ID })
$socketLines = [System.Collections.Generic.List[string]]::new()
$socketLines.Add("-- Socket-generation enchant records from client DB2 build $Build.")
$socketLines.Add("local catalog = {}")
foreach ($row in $socketEffects) {
    $recordID = [int]$row.ID
    $professionID = 0
    if ($professionColumn) { [void][int]::TryParse($row.$professionColumn, [ref]$professionID) }
    if ($buckleSocketRecords -contains $recordID) { $professionID = 164 }
    $professionName = if ($professionNames.ContainsKey($professionID)) { ConvertTo-LuaString $professionNames[$professionID] } else { "nil" }
    $requiredSkill = 0
    if ($requiredSkillColumn) { [void][int]::TryParse($row.$requiredSkillColumn, [ref]$requiredSkill) }
    $name = ConvertTo-LuaString $row.Name_lang
    $source = switch ($recordID) {
        3717 { "blacksmith-wrist" }
        3723 { "blacksmith-hands" }
        { $_ -in 3729, 5002 } { "belt-buckle" }
        default { "other" }
    }
    $socketLines.Add(("catalog[{0}] = {{ name = {1}, professionID = {2}, profession = {3}, requiredSkill = {4}, source = {5} }}" -f $recordID, $name, $professionID, $professionName, $requiredSkill, (ConvertTo-LuaString $source)))
}
$socketLines.Add("_G.YiboBuilds = _G.YiboBuilds or {}")
$socketLines.Add("_G.YiboBuilds.SocketEffectCatalog = catalog")
$socketLines.Add("")
[System.IO.File]::WriteAllText((Join-Path $OutputDirectory "SocketEffectCatalog.lua"), ($socketLines -join "`n"), [System.Text.UTF8Encoding]::new($false))

$engineeringLines = [System.Collections.Generic.List[string]]::new()
$engineeringRecordCount = 0
$engineeringLines.Add("-- Generated from WoW client DB2 build $Build.")
$engineeringLines.Add("-- Slot IDs: 1=head, 6=waist, 10=hands, 15=back, 18=ranged.")
$engineeringLines.Add("-- SpellItemEnchantment record IDs are kept distinct from their trigger spell IDs.")
$engineeringLines.Add("local catalog = {}")
foreach ($recordID in ($engineeringSlots.Keys | Sort-Object)) {
    $row = $enchantments | Where-Object { [int]$_.ID -eq [int]$recordID } | Select-Object -First 1
    if (-not $row) { continue }
    $spellIDs = [System.Collections.Generic.List[int]]::new()
    for ($index = 0; $index -lt 3; $index++) {
        if ($row.("Effect_$index") -eq "7") {
            $spellID = 0
            if ([int]::TryParse($row.("EffectArg_$index"), [ref]$spellID) -and $spellID -gt 0) { $spellIDs.Add($spellID) }
        }
    }
    foreach ($spellID in $nativeTooltipSpellAliases[[int]$recordID]) {
        if ($spellID -and -not $spellIDs.Contains([int]$spellID)) { $spellIDs.Add([int]$spellID) }
    }
    if ($spellIDs.Count -eq 0 -and $applySpellByRecordID.ContainsKey([int]$recordID)) {
        $spellIDs.Add([int]$applySpellByRecordID[[int]$recordID])
    }
    $spellList = "{ " + (($spellIDs | ForEach-Object { [string]$_ }) -join ", ") + " }"
    $name = ConvertTo-LuaString $row.Name_lang
    $engineeringLines.Add(("catalog[{0}] = {{ slotID = {1}, name = {2}, spellIDs = {3} }}" -f [int]$row.ID, $engineeringSlots[[int]$recordID], $name, $spellList))
    $engineeringRecordCount++
}
$engineeringLines.Add("_G.YiboBuilds = _G.YiboBuilds or {}")
$engineeringLines.Add("_G.YiboBuilds.EngineeringCatalog = catalog")
$engineeringLines.Add("")
[System.IO.File]::WriteAllText((Join-Path $OutputDirectory "EngineeringCatalog.lua"), ($engineeringLines -join "`n"), [System.Text.UTF8Encoding]::new($false))

Write-Output "Generated $($regular.Count) permanent enchant records, $($professionEnchantments.Count) profession-owned records, $($socketEffects.Count) socket effects, and $engineeringRecordCount engineering enhancement records from build $Build."
