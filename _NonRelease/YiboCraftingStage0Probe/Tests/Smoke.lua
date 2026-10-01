local messages, scripts, registered = {}, {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
SlashCmdList = {}
function CreateFrame()
    return {
        RegisterEvent = function(_, event) registered[event] = true end,
        SetScript = function(_, _, callback) scripts.event = callback end,
    }
end
function GetServerTime() return 1790500000 end
function GetBuildInfo() return "5.5.4", "60000", "2026-09-27", 50504 end
function GetLocale() return "zhCN" end
function UnitGUID() return "Player-1-123456" end
function GetProfessions() return 1, nil, nil, nil, 5, nil end
function GetProfessionInfo(index)
    if index == 1 then return "Alchemy", "icon", 75, 75, nil, nil, 171 end
    return "Cooking", "icon", 30, 75, nil, nil, 185
end
C_Timer = { After = function(_, callback) callback() end }
TradeSkillFrame = { IsShown = function() return true end }

local legacyRows = {
    { "Header", "header" },
    { "Recipe One", "optimal", 2, true, "|Hspell:1001|h[Recipe One]|h", "|Hitem:2001|h[Output]|h" },
    { "Recipe Two", "trivial", 0, true, "|Henchant:1002|h[Recipe Two]|h", nil },
}
function GetNumTradeSkills() return #legacyRows end
function GetTradeSkillInfo(index) return unpack(legacyRows[index], 1, 4) end
function GetTradeSkillRecipeLink(index) return legacyRows[index][5] end
function GetTradeSkillItemLink(index) return legacyRows[index][6] end
function GetTradeSkillLine() return "Alchemy", 75, 75 end
function IsTradeSkillLinked() return false end
function IsTradeSkillGuild() return false end
function GetTradeSkillNumReagents() return 1 end
function GetTradeSkillReagentInfo() return "Herb", "icon", 3, 2 end
function GetTradeSkillReagentItemLink() return "|Hitem:3001|h[Herb]|h" end
function GetTradeSkillSubClasses() return "Potions", "Elixirs" end
function GetTradeSkillInvSlots() return "Head", "Chest" end
function GetTradeSkillSubClassFilter(index) return index == 0 and 1 or 0 end
function GetTradeSkillInvSlotFilter(index) return index == 0 and 1 or 0 end
function GetOnlyShowMakeable() return false end
function GetOnlyShowSkillUps() return false end
function GetTradeSkillItemNameFilter() return nil end
function GetTradeSkillItemLevelFilter() return 0, 0 end
TradeSkillFrameSearchBox = { GetText = function() return "" end }
ArchaeologyFrame = { IsShown = function() return true end }
function GetNumArchaeologyRaces() return 1 end
function GetNumArtifactsByRace() return 2 end
function GetArtifactInfoByRace(_, projectIndex)
    return "Artifact", "description", "common", "icon", "spell", 0, "background",
        113968 + projectIndex - 1, nil, projectIndex == 1 and 1 or 0
end
C_TradeSkillUI = {
    GetAllRecipeIDs = function() return { 1001, 1002, 1003 } end,
    GetFilteredRecipeIDs = function() return { 1001 } end,
    GetRecipeInfo = function(id) return { name = "Recipe " .. id, learned = id == 1001, icon = 42, sourceType = 1 } end,
    GetRecipeItemLink = function() return "|Hitem:2001|h[Output]|h" end,
    GetRecipeSchematic = function(id) return { recipeID = id, outputItemID = 2001, reagentSlotSchematics = { { quantityRequired = 3, reagents = { { itemID = 3001 } } } } } end,
    GetBaseProfessionInfo = function() return { professionID = 171, professionName = "Alchemy", skillLineID = 171 } end,
}

dofile("_NonRelease/YiboCraftingStage0Probe/Probe.lua")
dofile("_NonRelease/YiboCraftingStage0Probe/Commands.lua")
dofile("_NonRelease/YiboCraftingStage0Probe/Bootstrap.lua")

scripts.event(nil, "ADDON_LOADED", "YiboCraftingStage0Probe")
scripts.event(nil, "PLAYER_LOGIN")
local probe = YiboCraftingStage0Probe
assert(registered.TRADE_SKILL_SHOW and registered.NEW_RECIPE_LEARNED)
assert(#probe.session.snapshots == 1)
assert(type(probe.session.characterKeyHash) == "string" and #probe.session.characterKeyHash == 8)
local login = probe.session.snapshots[1]
assert(login.modern.allCount == 3 and login.modern.filteredCount == 1)
assert(#login.professions.entries == 2 and login.professions.entries[2].skillLineID == 185)
assert(login.legacy.uniqueRecipeCount == 2 and login.legacy.rows[3].recipeID == 1002)
assert(login.legacy.filters.subClasses.all == 1 and login.legacy.filters.inventorySlots.all == 1)
assert(login.legacy.filters.onlyMakeable == false and login.legacy.filters.searchText == "")
assert(login.legacy.filters.itemName == nil and login.legacy.filters.itemNameError == nil)
assert(login.legacy.filters.minItemLevel == 0 and login.legacy.filters.maxItemLevel == 0)
assert(login.legacy.unknownExpansionHeaderCount == 1)
assert(login.completeness == "unverified")
assert(login.visibleList.scope == "unverified")
assert(login.visibleList.uncertainties[1] == "header-expansion-unknown")
assert(login.context.source == "own-window-candidate")
local foundSummary = false
for _, message in ipairs(messages) do
    if message:find("Alchemy", 1, true) and message:find("2 个配方 ID", 1, true) then foundSummary = true end
end
assert(foundSummary, "chat summary should identify profession and unique recipe count")

local detail = probe:Recipe(1001)
assert(detail.outputItemID == 2001 and detail.legacy.reagents[1].itemID == 3001)
assert(detail.legacy.reagents[1].quantity == 3)
assert(detail.schematic.reagentSlotSchematics[1].reagents[1].itemID == 3001)

GetTradeSkillSubClassFilter = function(index) return index == 1 and 1 or 0 end
GetOnlyShowMakeable = function() return true end
GetTradeSkillItemNameFilter = function() return "Potion" end
GetTradeSkillItemLevelFilter = function() return 20, 30 end
TradeSkillFrameSearchBox.GetText = function() return "Potion" end
local filtered = probe:Snapshot("filtered")
assert(filtered.legacy.filters.subClasses.all == 0)
assert(filtered.legacy.filters.subClasses.checked[1] == 1)
assert(filtered.legacy.filters.onlyMakeable == true)
assert(filtered.legacy.filters.searchText == "Potion" and filtered.completeness == "unverified")
assert(filtered.visibleList.scope == "restricted")
assert(#filtered.visibleList.restrictions == 5)
GetTradeSkillSubClassFilter = function(index) return index == 0 and 1 or 0 end
GetOnlyShowMakeable = function() return false end
GetTradeSkillItemNameFilter = function() return nil end
GetTradeSkillItemLevelFilter = function() return 0, 0 end
TradeSkillFrameSearchBox.GetText = function() return "" end

SlashCmdList.YIBOCRAFTINGPROBE("archaeology")
local archaeology = probe.session.archaeologySamples[1]
assert(archaeology.frameShown and archaeology.raceCount == 1 and archaeology.projectCount == 2)
assert(archaeology.spellIDCount == 2 and archaeology.completedCount == 1)
assert(archaeology.races[1].projects[1].spellID == 113968)
assert(archaeology.completeness == "unverified")

scripts.event(nil, "NEW_RECIPE_LEARNED", 1004)
assert(#probe.session.events == 1 and probe.session.events[1].args[1] == 1004)
scripts.event(nil, "TRADE_SKILL_SHOW")
assert(#probe.session.snapshots == 3)
SlashCmdList.YIBOCRAFTINGPROBE("status")

-- A missing modern list leaves completeness unverified and keeps the legacy evidence.
C_TradeSkillUI.GetAllRecipeIDs = nil
local fallback = probe:Snapshot("missing-modern")
assert(fallback.modern.allRecipeIDsReturned == false)
assert(fallback.legacy.uniqueRecipeCount == 2 and fallback.completeness == "unverified")

IsTradeSkillLinked = function() return true end
local foreign = probe:Snapshot("linked")
assert(foreign.context.source == "linked" and foreign.completeness == "unverified")
assert(foreign.visibleList.scope == "unverified" and foreign.visibleList.uncertainties[1] == "own-window-not-confirmed")
IsTradeSkillLinked = function() return false end
GetNumTradeSkills = function() return 1 end
GetTradeSkillInfo = function() return "Collapsed", "header", 0, nil end
local collapsed = probe:Snapshot("collapsed")
assert(collapsed.legacy.headerCount == 1 and collapsed.legacy.headerGroupsWithoutRecipes == 1)
assert(collapsed.legacy.uniqueRecipeCount == 0 and collapsed.completeness == "unverified")
assert(collapsed.visibleList.scope == "restricted")
assert(collapsed.visibleList.restrictions[1] == "subset-of-earlier-own-list")
TradeSkillFrame.IsShown = function() return false end
GetTradeSkillLine = function() return "UNKNOWN" end
GetNumTradeSkills = function() return 3 end
GetTradeSkillItemNameFilter = nil
local stale = probe:Snapshot("window-closed")
assert(stale.context.source == "unknown" and stale.legacy.rowCount == 3)
assert(stale.completeness == "unverified")
assert(stale.legacy.filters.itemNameError == "missing")
local missingNameFilter = false
for _, reason in ipairs(stale.visibleList.uncertainties) do
    if reason == "native-item-name-filter-unknown" then missingNameFilter = true end
end
assert(missingNameFilter)
print("YiboCrafting stage 0 smoke OK")
