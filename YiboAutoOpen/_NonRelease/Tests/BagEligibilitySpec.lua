local locked = true
local cooldownStart, cooldownDuration = 0, 0

GetTime = function() return 10 end
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
    GetContainerItemInfo = function() return { itemID = 90735, isLocked = locked, stackCount = 1 } end,
    GetContainerItemCooldown = function() return cooldownStart, cooldownDuration, 1 end,
}
YiboAutoOpen = {}

dofile("YiboAutoOpen/BagAdapter.lua")

local entries, quarantined = { [90735] = true }, {}
local bag, slot, item, retryAfter = YiboAutoOpen.BagAdapter:FindNextEligible(entries, quarantined)
assert(not item and retryAfter == 0.5, "a locked catalog item should request a retry")

locked = false
cooldownStart, cooldownDuration = 9, 2
bag, slot, item, retryAfter = YiboAutoOpen.BagAdapter:FindNextEligible(entries, quarantined)
assert(not item and retryAfter > 1 and retryAfter < 1.1, "an item on cooldown should retry after the cooldown")

cooldownStart, cooldownDuration = 0, 0
bag, slot, item, retryAfter = YiboAutoOpen.BagAdapter:FindNextEligible(entries, quarantined)
assert(bag == 0 and slot == 1 and item.itemID == 90735 and retryAfter == nil, "a ready catalog item should be returned")

print("Bag eligibility spec passed")
