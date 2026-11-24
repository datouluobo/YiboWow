local locked = true
local cooldownStart, cooldownDuration = 0, 0
local itemID = 90735
local slotCount = 1
local tooltipLinesBySlot = { { "Container" } }
local originalCreateFrame, originalLocked, originalRetrieving = CreateFrame, LOCKED, RETRIEVING_ITEM_INFO
local tooltipReads = 0
LOCKED, RETRIEVING_ITEM_INFO = "已锁", "Retrieving item information"
CreateFrame = function(frameType, name)
    assert(frameType == "GameTooltip")
    local lines = {}
    for index = 1, 3 do
        _G[name .. "TextLeft" .. index] = { GetText = function() return lines[index] end }
    end
    return {
        SetOwner = function() end,
        ClearLines = function() lines = {} end,
        SetBagItem = function(_, bag, slot)
            assert(bag == 0)
            tooltipReads = tooltipReads + 1
            lines = tooltipLinesBySlot[slot]
        end,
        NumLines = function() return #lines end,
        Hide = function() end,
    }
end

GetTime = function() return 10 end
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and slotCount or 0 end,
    GetContainerItemInfo = function() return { itemID = itemID, isLocked = locked, stackCount = 1 } end,
    GetContainerItemCooldown = function() return cooldownStart, cooldownDuration, 1 end,
}
YiboAutoOpen = {}
dofile("YiboAutoOpen/Mists/Target.lua")
YiboAutoOpen.Target.supported = true
dofile("YiboAutoOpen/Catalog.lua")

dofile("YiboAutoOpen/BagAdapter.lua")

local entries, quarantined = { [90735] = true }, {}
local bag, slot, item, retryAfter = YiboAutoOpen.BagAdapter:FindNextEligible(entries, quarantined)
assert(not item and retryAfter == 0.5, "a locked catalog item should request a retry")
assert(tooltipReads == 0, "a temporarily busy slot does not need a tooltip scan")

locked = false
cooldownStart, cooldownDuration = 9, 2
bag, slot, item, retryAfter = YiboAutoOpen.BagAdapter:FindNextEligible(entries, quarantined)
assert(not item and retryAfter > 1 and retryAfter < 1.1, "an item on cooldown should retry after the cooldown")

cooldownStart, cooldownDuration = 0, 0
bag, slot, item, retryAfter = YiboAutoOpen.BagAdapter:FindNextEligible(entries, quarantined)
assert(bag == 0 and slot == 1 and item.itemID == 90735 and retryAfter == nil, "a ready catalog item should be returned")

itemID = 52340
entries[52340] = true
bag, slot, item, retryAfter = YiboAutoOpen.BagAdapter:FindNextEligible(entries, quarantined)
assert(not item and retryAfter == nil, "Abyssal Clam must be skipped because its use action is protected")
itemID = 24476
entries[24476] = true
bag, slot, item, retryAfter = YiboAutoOpen.BagAdapter:FindNextEligible(entries, quarantined)
assert(not item and retryAfter == nil, "Jaggal Clam must never enter the queue even with a stale catalog entry")

itemID = 43622
entries[itemID] = true
tooltipLinesBySlot[1] = { "Froststeel Lockbox", LOCKED }
bag, slot, item, retryAfter = YiboAutoOpen.BagAdapter:FindNextEligible(entries, quarantined)
assert(not item and retryAfter == nil, "a locked box must stay out of the queue without scheduling retries")

slotCount = 2
tooltipLinesBySlot[2] = tooltipLinesBySlot[1]
tooltipLinesBySlot[1] = { "Froststeel Lockbox", "Previously locked" }
bag, slot, item = YiboAutoOpen.BagAdapter:FindNextEligible(entries, quarantined)
assert(bag == 0 and slot == 1 and item.itemID == 43622, "an unlocked copy is eligible even if another copy is locked")

tooltipLinesBySlot[1] = { RETRIEVING_ITEM_INFO }
local found, delay = YiboAutoOpen.BagAdapter:FindEligibleItems(entries, quarantined)
assert(#found == 0 and delay == 0.5, "a loading tooltip must defer the slot without treating it as unlocked")

LOCKED = "Locked"
tooltipLinesBySlot[1] = { "Froststeel Lockbox", LOCKED }
tooltipLinesBySlot[2] = tooltipLinesBySlot[1]
assert(not YiboAutoOpen.BagAdapter:FindItemByID(itemID, entries, quarantined), "the use-time lookup must recheck the lock of each copy")
tooltipLinesBySlot[2] = { "Froststeel Lockbox" }
bag, slot, item = YiboAutoOpen.BagAdapter:FindItemByID(itemID, entries, quarantined)
assert(bag == 0 and slot == 2 and item.itemID == 43622, "an unlocked slot becomes usable on the next scan")

local originalTimer = C_Timer
local scheduled, registered, onEvent = {}, {}, nil
C_Timer = { After = function(delay, callback) scheduled[#scheduled + 1] = { delay = delay, callback = callback } end }
CreateFrame = function(frameType)
    assert(frameType == "Frame")
    return {
        RegisterEvent = function(_, event) registered[event] = true end,
        SetScript = function(_, _, callback) onEvent = callback end,
    }
end
dofile("YiboAutoOpen/Bootstrap.lua")
dofile("YiboAutoOpen/Defaults.lua")
dofile("YiboAutoOpen/Queue.lua")
local addon = YiboAutoOpen
addon.runtime.initialized, addon.runtime.loggedIn = true, true
addon.db = { catalog = { entries = entries } }
addon.Safety = { CanRun = function() return true end, SetSensitive = function() end }

local uses = 0
C_Container.UseContainerItem = function(useBag, useSlot)
    assert(useBag == 0 and useSlot == 1)
    uses = uses + 1
end
slotCount = 1
local function CheckUnlockRescan(event, ...)
    addon.Queue:Clear()
    scheduled, uses = {}, 0
    tooltipLinesBySlot[1] = { "Froststeel Lockbox", LOCKED }

    assert(registered[event], "the rescan must use a registered client event")
    onEvent(nil, event, ...)
    assert(#scheduled == 2 and scheduled[1].delay == 0 and scheduled[2].delay == 0.5,
        "unlock and trade must request both an immediate scan and a delayed scan")
    table.remove(scheduled, 1).callback()
    assert(uses == 0 and not addon.runtime.pending, "the old lock state must still prevent an open")

    tooltipLinesBySlot[1] = { "Froststeel Lockbox" }
    table.remove(scheduled, 1).callback()
    table.remove(scheduled, 1).callback()
    assert(uses == 1 and addon.runtime.pending.itemID == 43622, "the delayed scan must open the unlocked container")
end
CheckUnlockRescan("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1804)
CheckUnlockRescan("TRADE_CLOSED")
addon.Queue:Clear()
scheduled = {}
onEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 123)
assert(#scheduled == 1 and scheduled[1].delay == 0, "other spells must keep the normal immediate scan")

C_Timer = originalTimer
CreateFrame, LOCKED, RETRIEVING_ITEM_INFO = originalCreateFrame, originalLocked, originalRetrieving
for index = 1, 3 do _G["YiboAutoOpenContainerTooltipTextLeft" .. index] = nil end

print("Bag eligibility spec passed")
