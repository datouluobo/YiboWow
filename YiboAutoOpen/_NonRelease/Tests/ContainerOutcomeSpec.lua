local slotInfo = { itemID = 54535, stackCount = 1, isLocked = false, hyperlink = "item:54535" }
local total = 1

C_Container = {
    GetContainerItemInfo = function() return slotInfo end,
    GetContainerNumSlots = function() return 1 end,
}
GetItemCount = function() return total end

YiboAutoOpen = {}
dofile("YiboAutoOpen/BagAdapter.lua")

local pending = { bag = 0, slot = 1, itemID = 54535, slotItemID = 54535, slotCount = 1, beforeTotal = 1 }
assert(YiboAutoOpen.BagAdapter:DidUseItem(pending) == false, "an unchanged unlocked slot is not a successful use")

slotInfo.stackCount = 0
total = 0
assert(YiboAutoOpen.BagAdapter:DidUseItem(pending) == true, "a reduced stack is a successful use")

slotInfo.stackCount = 1
total = 1
slotInfo.isLocked = true
assert(YiboAutoOpen.BagAdapter:DidUseItem(pending) == nil, "a locked result must remain unknown")

print("Container outcome spec passed")
