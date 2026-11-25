-- Run from the repository root: lua YiboBuilds/_NonRelease/Tests/EquipmentAugmentSpec.lua
local function FindUpvalue(fn, wanted, visited)
    visited = visited or {}
    if visited[fn] then return end
    visited[fn] = true
    for index = 1, 100 do
        local name, value = debug.getupvalue(fn, index)
        if not name then break end
        if name == wanted then return value end
        if type(value) == "function" then
            local found = FindUpvalue(value, wanted, visited)
            if found then return found end
        end
    end
end
local host = dofile("YiboBuilds/_NonRelease/Tests/Core13Host.lua")("zh")
dofile("YiboBuilds/Data/EngineeringCatalog.lua")
dofile("YiboBuilds/Data/EngineeringApply.lua")
dofile("YiboBuilds/Data/ApplyTargets.lua")
dofile("YiboBuilds/Snapshot.lua")
dofile("YiboBuilds/AccountPage.lua")
CreateFrame = nil
local readEngineering = assert(FindUpvalue(YiboBuilds.Snapshot.CaptureSlot, "ReadEngineeringEnchantID"))
local candidates = assert(FindUpvalue(YiboBuilds.AccountPage.Refresh, "AugmentCandidates"))
local tooltipLines = {}
C_TooltipInfo = { GetInventoryItem = function() return { lines = tooltipLines } end }
local function Detect(slot, lines, expected)
    tooltipLines = lines
    assert(readEngineering(slot, { "99086", "4430" }, "item:99086:4430") == expected,
        "unexpected engineering detection for slot " .. slot)
end
Detect(10, { { leftText = "使用：使你的智力、敏捷或力量提高|cff00ff001,920|r点，持续 10 秒。(1分钟冷却)" } }, 4898)
Detect(15, { { leftText = "使用：降低你的坠落速度，持续 2 分钟。(3分钟冷却)" } }, 4897)
Detect(10, { { leftText = "Use: Increases your Strength by 1,920 for 10 sec." } }, 4898)
Detect(10, { { leftText = "Use: Increases your damage by 1920 for 10 sec." } }, nil)
Detect(10, { { leftText = "没有工程强化" } }, nil)
Detect(10, { { spellID = 141331, leftText = "使智力提高1920点，持续10秒" } }, 5063)
Detect(6, { { leftText = "降低你的坠落速度，持续2分钟" } }, nil)
-- Legacy GameTooltip fallback carries the same colored use text.
C_TooltipInfo = nil
local nativeText = "使用：使你的智力、敏捷或力量提高|cff00ff001,920|r点，持续 10 秒。"
CreateFrame = function()
    YiboBuildsEnchantScanTooltipTextLeft1 = { GetText = function() return nativeText end }
    return { SetOwner = function() end, ClearLines = function() end, SetInventoryItem = function() end,
        NumLines = function() return 1 end, Hide = function() end }
end
assert(readEngineering(10, {}, "item:99086:4430") == 4898)
nativeText = "使用：降低你的坠落速度，持续 2 分钟。(3分钟冷却)"
assert(readEngineering(15, {}, "item:89076:4421") == 4897)
CreateFrame = nil
-- A physical bag buckle needs no blacksmith profession or learned recipe.
GetItemInfo = function() return "Belt", nil, nil, nil, nil, nil, nil, nil, "INVTYPE_WAIST", nil, nil, 4, 3 end
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
    GetContainerItemLink = function() return "item:90046" end,
    GetContainerItemInfo = function() return { stackCount = 1 } end,
}
local belt = { itemLink = "item:99100", beltBuckle = { state = "base-missing" } }
local available = candidates(6, belt)
assert(#available == 1 and available[1].source.itemID == 90046 and available[1].bag.count == 1)
belt.beltBuckle.state = "installed"
assert(#candidates(6, belt) == 0, "installed buckle must not offer another socket")
belt.beltBuckle.state = "base-missing"
C_Container.GetContainerNumSlots = function() return 0 end
assert(#candidates(6, belt) == 0, "absent bag buckle must not be offered")
-- One physical scroll must not expose scaled catalog aliases as separate choices.
dofile("YiboBuilds/Data/EnchantCatalog.lua")
dofile("YiboBuilds/Data/ProfessionCatalog.lua")
local scrollID, scrollSpell, inventoryType = 74719, 104416, "INVTYPE_HAND"
GetItemInfo = function() return "Equipped item", nil, nil, nil, nil, nil, nil, nil, inventoryType, nil, nil, 4, 1 end
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end
C_Container.GetContainerItemLink = function() return "item:" .. scrollID end
C_Item = { GetItemSpell = function() return "Native enchant name", scrollSpell end }
local glove = {itemLink="item:99100"}
available = candidates(10, glove)
assert(#available == 1 and available[1].enchantID == 4430 and available[1].bag.count == 1,
    "one haste scroll must offer +170 only, not +14/+8 catalog aliases")
scrollID, scrollSpell, inventoryType = 74700, 104338, "INVTYPE_WRIST"
available = candidates(9, glove)
assert(#available == 1 and available[1].enchantID == 4411, "wrist mastery must not offer scaled aliases")
scrollID, scrollSpell = 74703, 104389
available = candidates(9, glove)
assert(#available == 1 and available[1].enchantID == 4414, "four intellect records must resolve to one scroll effect")
-- A known use spell selects its actual effect rather than the highest number.
scrollSpell = 141170
available = candidates(9, glove)
assert(#available == 1 and available[1].enchantID == 5057, "actual use spell must win over a numeric heuristic")
scrollSpell = nil
assert(#candidates(9, glove) == 0, "unknown use spell must not guess among ambiguous records")
C_Item = nil
GetItemSpell = function() return "Native name", 104389 end
assert(#candidates(9, glove) == 1, "legacy item-spell API must also resolve scrolls")
GetItemSpell = nil
scrollID = 74701
available = candidates(9, glove)
assert(#available == 1 and available[1].enchantID == 4412, "unambiguous legacy catalog entry remains usable")
-- Distinct real scrolls remain distinct choices, with their own stack counts.
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end
C_Container.GetContainerItemLink = function(_, slot) return "item:" .. (slot == 1 and 74700 or 74703) end
C_Container.GetContainerItemInfo = function(_, slot) return {stackCount = slot == 1 and 2 or 1} end
C_Item = { GetItemSpell = function(id) return "Native name", id == 74700 and 104338 or 104389 end }
available = candidates(9, glove)
local byID = {}; for _, choice in ipairs(available) do byID[choice.enchantID] = choice end
assert(#available == 2 and byID[4411].bag.count == 2 and byID[4414].bag.count == 1,
    "different scrolls and stack counts must not be merged")
-- Craftable scrolls have the same item-to-effect ambiguity even with empty bags.
C_Container.GetContainerNumSlots = function() return 0 end
scrollID, scrollSpell = 74719, 104416
inventoryType = "INVTYPE_HAND"
C_Item = { GetItemSpell = function() return "Native enchant name", scrollSpell end }
YiboBuilds.CraftSources = { [74719] = { recipes = { 999123 }, skills = { [999123] = {333, 1} } } }
GetProfessions = function() return 1 end
GetProfessionInfo = function() return "Enchanting", nil, 600, nil, nil, nil, 333 end
IsSpellKnown = function(id) return id == 999123 end
YiboBuilds.AccountPage:InvalidateRecipeCache()
available = candidates(10, glove)
assert(#available == 1 and available[1].enchantID == 4430 and available[1].craftRecipe == 999123 and not available[1].bag,
    "craftable scroll must resolve to the actual effect too")
-- An independently learned direct enchant is not removed by scroll filtering.
YiboBuilds.CraftSources = nil
IsSpellKnown = function(id) return id == 104416 end
YiboBuilds.AccountPage:InvalidateRecipeCache()
C_Item = nil
available = candidates(10, glove)
assert(#available == 1 and available[1].enchantID == 4430 and available[1].learned, "learned direct enchant remains available")
IsSpellKnown = nil
GetProfessions, GetProfessionInfo = nil, nil
YiboBuilds.AccountPage:InvalidateRecipeCache()
-- Opening equipment details uses this production scheduler: preserve the
-- settled rescan even if another event schedules a glyph-only capture.
local pending, captures, clock = {}, {}, 0
GetTime = function() return clock end
C_Timer = { After = function(delay, callback) pending[#pending + 1] = { at = clock + delay, callback = callback } end }
local function Advance(at)
    while true do
        table.sort(pending, function(a,b) return a.at < b.at end)
        if not pending[1] or pending[1].at > at then clock = at; return end
        local timer = table.remove(pending, 1); clock = timer.at; timer.callback()
    end
end
YiboBuilds.Snapshot.Capture = function(_, reason, _, parts) captures[#captures + 1] = { reason, parts } end
YiboBuilds.Snapshot:ScheduleEquipmentCapture()
YiboBuilds.Snapshot:ScheduleCapture("glyph-update", 0.1, { glyphs = true })
assert(#pending == 2, "capture and settle each retain one worker")
Advance(0.1)
assert(#captures == 1 and captures[1][2].equipment and captures[1][2].glyphs)
Advance(0.3)
assert(#captures == 2 and captures[2][2].equipment)
-- API13 initialization and compatibility failures are exercised by Core13Spec.
print("EquipmentAugmentSpec passed: tooltip detection, bag buckle candidates, scroll identity/craft/legacy filtering, equipment rescan")
