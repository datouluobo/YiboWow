local Addon = _G.YiboMail
local Runtime = {}; Addon.CollectionRuntime = Runtime

function Runtime:HasRegularBagSpace()
    local slots = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
    if not slots then return nil end
    local free = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local count, family = slots(bag)
        if family == 0 then free = free + (count or 0) end
    end
    return free > 0
end

function Runtime:InCombat()
    return InCombatLockdown and InCombatLockdown()
end

function Runtime:GetTakeFunction(slot)
    return slot == "money" and TakeInboxMoney or TakeInboxItem
end

function Runtime:GetDispositionFunction(deleteEmpty)
    return deleteEmpty and DeleteInboxItem or ReturnInboxItem
end

function Runtime:HasReturnAPI()
    return type(ReturnInboxItem) == "function"
end

function Runtime:ObserveActions(callback)
    if not hooksecurefunc then return end
    for _, name in ipairs({ "TakeInboxItem", "TakeInboxMoney", "AutoLootMailItem", "ReturnInboxItem", "DeleteInboxItem" }) do
        if type(_G[name]) == "function" then hooksecurefunc(name, callback) end
    end
end
