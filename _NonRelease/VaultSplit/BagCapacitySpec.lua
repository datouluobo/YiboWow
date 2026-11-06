local Boot = dofile("_NonRelease/VaultForever/Smoke.lua")
local count = 0
local function Check(value, message) count = count + 1; assert(value, message) end
local env, core, vault = Boot(nil, nil, nil, false)
local capacity = vault.BagCapacity
local area = { freeSlots = 25, totalSlots = 70, locations = {
    { capacity = { totalSlots = 28, freeSlots = 14, bagType = 0 } },
    { capacity = { totalSlots = 22, freeSlots = 0, bagType = 0 } },
    { capacity = { totalSlots = 4, freeSlots = 0, bagType = 0 } },
    { capacity = { totalSlots = 4, freeSlots = 0, bagType = 0 } },
    { capacity = { totalSlots = 12, freeSlots = 11, bagType = 32 } },
} }
local groups = capacity:Group(area, "bank")
Check(#groups == 2 and groups[1].emptySlots == 14 and groups[2].emptySlots == 11, "observed bank separates 14 general and 11 herb slots")
Check(vault:T(groups[1].emptyLabelKey) == "空位" and vault:T(groups[2].emptyLabelKey) == "草药", "Chinese two-character labels")
local records = { { itemID = 42, quantity = 3 } }
local slots = vault.StoragePage:BuildSlots(records, "bank", area.freeSlots, groups)
Check(#slots == 3 and slots[1] == records[1] and slots[2].emptySlots == 14 and slots[3].emptySlots == 11, "one summary tile per restriction, records unchanged")
Check(area.freeSlots == 25 and #area.locations == 5, "grouping does not alter snapshots")
local repeated = capacity:Group({ locations = {
    { capacity = { totalSlots = 12, freeSlots = 3, bagType = 32 } },
    { capacity = { totalSlots = 16, freeSlots = 8, bagType = 32 } },
} }, "bags")
Check(#repeated == 1 and repeated[1].emptySlots == 11, "same family aggregates without duplicate tiles")
local unknown = capacity:Group({ locations = {
    { capacity = { totalSlots = 12, freeSlots = 7 } },
    { capacity = { totalSlots = 12, freeSlots = 4, bagType = 999999 } },
    { capacity = { totalSlots = 12, freeSlots = 2, bagType = 96 } },
} }, "bank")
Check(#unknown == 2 and unknown[1].emptyLabelKey == "CAPACITY.SPECIAL" and unknown[1].emptySlots == 6
    and unknown[2].emptyLabelKey == "CAPACITY.UNKNOWN" and unknown[2].emptySlots == 7, "unknown and multi-family never become ordinary or double-count")
Check(#capacity:Group({ locations = { { capacity = { totalSlots = 12, freeSlots = 0, bagType = 32 } },
    { capacity = { totalSlots = 12, bagType = 32 } }, { capacity = { totalSlots = 12, freeSlots = 13, bagType = 0 } } } }, "bank") == 0,
    "full, missing and invalid free counts do not invent space")
Check(capacity:Group({ freeSlots = 4 }, "bank")[1].emptyLabelKey == "CAPACITY.UNKNOWN", "legacy totals retain unknown type")
Check(capacity:Group({ freeSlots = 4 }, "guild-1")[1].emptyLabelKey == "CAPACITY.GENERAL", "guild slots remain general")
Check(#vault.StoragePage:BuildSlots(records, "search", nil) == 1, "search does not append empty tiles")
Check(#vault.StoragePage:BuildSlots({}, "equipment", 25, groups) == 19, "equipment remains fixed slot layout")
local mock = { icon = {}, itemLevel = {}, count = {}, emptyLabel = {}, emptyCount = {} }
for _, child in pairs(mock) do
    function child:SetText(value) self.text = value end
    function child:SetShown(value) self.shown = value end
    function child:SetFont() end
    function child:SetTexture() end
end
function mock:SetBackdropColor() end
function mock:SetBackdropBorderColor() end
local goals = vault.GoalTargets; vault.GoalTargets = nil
vault.StoragePage:UpdateItemCell({}, mock, slots[3], 1)
Check(mock.emptyLabel.text == "草药" and mock.emptyCount.text == "11", "rendered herb tile has upper label and lower number")
vault.StoragePage:UpdateItemCell({}, mock, slots[2], 1)
Check(mock.emptyLabel.text == "空位" and mock.emptyCount.text == "14", "recycled tile resets category")
vault.StoragePage:UpdateItemCell({}, mock, nil, 1)
Check(not mock.emptyLabel.shown and not mock.emptyCount.shown, "recycled item cell hides category")
vault.GoalTargets = goals
for _, locale in ipairs({ "zhCN", "zhTW", "enUS", "deDE" }) do
    local e, c, v = Boot(nil, nil, function(e) e.GetLocale = function() return locale end end, false)
    for mask = 0, 17 do
        local family = mask == 0 and 0 or 2 ^ (mask - 1)
        local group = v.BagCapacity:Group({ locations = { { capacity = { totalSlots = 2, freeSlots = 1, bagType = family } } } }, "bank")[1]
        local text = v:T(group.emptyLabelKey)
        Check(not text:find("CAPACITY", 1, true), "family localized: " .. locale)
        Check(c.UITheme:MeasureText(c.UITheme.Font.meta, text) <= 38, "label fits one 42px tile: " .. locale .. " " .. text)
        if locale == "zhCN" or locale == "zhTW" then Check(#text == 6, "Chinese family label is two characters") end
    end
    Check(not v:T("CAPACITY.TOTAL_FREE", "", 25, 70):find("CAPACITY", 1, true), "total summary localized")
end
print("Vault BagCapacitySpec passed: " .. count .. " checks")
