_G.YiboCore = { UITheme = { Colors = {} } }
_G.YiboVault = {}
dofile("YiboVault/StoragePage.lua")
local page = YiboVault.StoragePage

local records = {
    { itemID = 10, quantity = 5, location = { slot = 3 } },
    { itemID = 10, quantity = 7, location = { slot = 8 } },
}
local bags = page:BuildSlots(records, "bags", 4)
assert(#bags == 3 and bags[1].quantity == 5 and bags[2].quantity == 7 and bags[3].emptySlots == 4,
    "merged bags must preserve stacks and collapse known empty slots into one cell")
local unknown = page:BuildSlots(records, "bags", nil)
assert(#unknown == 2, "unknown free-slot count must not generate an empty cell")
local full = page:BuildSlots(records, "bank", 0)
assert(#full == 2, "a full storage area must not add an empty-slot cell")
local equipment = page:BuildSlots(records, "equipment")
assert(#equipment == 19 and equipment[1] == false and equipment[3] == records[1] and equipment[8] == records[2],
    "equipment cells must retain slot identity")
local columns = page:GetGridColumns(490)
assert(columns == 10, "grid columns should fit the viewport width")
local fitted = page:GetGridColumns(635)
assert(fitted == 14, "a nearly full cell of trailing space should allow a tighter extra column")
assert(page:GetGridColumnOffset(635, fitted, fitted) + 42 == 633,
    "the last cell should end two pixels before the viewport edge")
assert(page:GetGridContentHeight(120, columns) == 568,
    "all grid rows should contribute to vertical scroll height")
assert(page:GetGridContentHeight(0, columns) == 4,
    "an empty grid should keep only its minimal inset")

_G.GetItemInfo = function(item)
    if item == "item:100" then return "Sword", nil, nil, 400, nil, nil, nil, nil, "INVTYPE_WEAPON" end
    if item == "item:200" then return "Ore", nil, nil, 1, nil, nil, nil, nil, "" end
    if item == "item:300" then return "Bag", nil, nil, 100, nil, nil, nil, nil, "INVTYPE_BAG" end
    if item == "item:400" then return "Ore", nil, nil, 90, nil, nil, nil, nil, "INVTYPE_NON_EQUIP_IGNORE" end
end
_G.C_Item = { GetDetailedItemLevelInfo = function(item)
    if item == "item:100" then return 450 end
end }
local level, isEquipment = page:GetItemLevel({ itemID = 100, itemLink = "item:100" })
assert(level == 450 and isEquipment,
    "equippable items must show their actual level from the stored link")
local materialLevel, materialIsEquipment = page:GetItemLevel({ itemID = 200, itemLink = "item:200" })
local bagLevel, bagIsEquipment = page:GetItemLevel({ itemID = 300, itemLink = "item:300" })
local ignoredLevel, ignoredIsEquipment = page:GetItemLevel({ itemID = 400, itemLink = "item:400" })
assert(materialLevel == nil and not materialIsEquipment
    and bagLevel == nil and not bagIsEquipment and ignoredLevel == nil and not ignoredIsEquipment,
    "materials and bags must not show an item level")
_G.C_Item.GetDetailedItemLevelInfo = function() return nil end
local unknownLevel, stillEquipment = page:GetItemLevel({ itemID = 100, itemLink = "item:100" })
assert(unknownLevel == nil and stillEquipment,
    "an unavailable actual level must not be replaced with the base level")
_G.C_Item = nil
_G.GetDetailedItemLevelInfo = nil
assert(page:GetItemLevel({ itemID = 100, itemLink = "item:100" }) == 400,
    "older clients without a detailed-level API may show the cached base level")
print("YiboVault storage grid spec passed")
