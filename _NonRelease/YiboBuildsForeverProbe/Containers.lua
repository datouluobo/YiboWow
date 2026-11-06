local _, P = ...
local function Bag(bagID)
    return { bag = bagID, slots = P.Call("C_Container.GetContainerNumSlots", bagID),
        free = P.Call("C_Container.GetContainerNumFreeSlots", bagID), items = {} }
end
function P.ScanBags()
    local sample = P.Begin("bag_positions")
    if not sample then return end
    sample.bags = {}
    local observed = 0
    for bagID = 0, 4 do
        local bag = Bag(bagID)
        local count = P.First(bag.slots)
        if P.Integer(count, 0, 200) then
            for slot = 1, count do
                if observed >= 256 then bag.enumeration = "global_limit_reached"; break end
                observed = observed + 1
                bag.items[#bag.items + 1] = { slot = slot,
                    info = P.Call("C_Container.GetContainerItemInfo", bagID, slot),
                    id = P.Call("C_Container.GetContainerItemID", bagID, slot) }
            end
        else bag.enumeration = "slot_count_unreadable_or_outside_probe_bounds" end
        sample.bags[#sample.bags + 1] = bag
    end
    sample.scope = "bags 0..4 only; positions are observations, not inventory authority or container allowlist"
    return P.Finish(sample)
end
function P.ScanItem(bagID, slot)
    if not P.Integer(bagID, 0, 4) or not P.Integer(slot, 1, 200) then P.Say("invalid_item"); return end
    local sample = P.Begin("selected_item")
    if not sample then return end
    sample.bag, sample.slot, sample.slots = bagID, slot, P.Call("C_Container.GetContainerNumSlots", bagID)
    local count = P.First(sample.slots)
    if not P.Integer(count, slot, 200) then P.Say("invalid_item"); return end
    sample.item = P.Call("C_Container.GetContainerItemInfo", bagID, slot)
    sample.itemID = P.Call("C_Container.GetContainerItemID", bagID, slot)
    sample.link = P.Call("C_Container.GetContainerItemLink", bagID, slot)
    sample.cooldown = P.Call("C_Container.GetContainerItemCooldown", bagID, slot)
    sample.tooltip = P.Call("C_TooltipInfo.GetBagItem", bagID, slot)
    local id = P.First(sample.itemID)
    if P.Integer(id, 1, 2147483647) then
        sample.itemInfo = P.Call("C_Item.GetItemInfo", id)
        sample.itemSpell = P.Call("C_Item.GetItemSpell", id)
        sample.bagCount = P.Call("C_Item.GetItemCount", id, false, false, false, false)
    end
    sample.safety, sample.bags = {}, {}
    for _, path in ipairs({ "InCombatLockdown", "UnitIsDeadOrGhost", "UnitInVehicle", "UnitCastingInfo", "UnitChannelInfo" }) do
        sample.safety[path] = path == "InCombatLockdown" and P.Call(path) or P.Call(path, "player")
    end
    for bag = 0, 4 do sample.bags[#sample.bags + 1] = Bag(bag) end
    sample.operationsExist = {}
    for _, path in ipairs({ "C_Container.UseContainerItem", "UseContainerItem", "ConfirmBindOnUse", "ConfirmLootSlot", "LootSlot" }) do
        sample.operationsExist[path] = type(P.Resolve(path)) == "function"
    end
    sample.idAfter = P.Call("C_Container.GetContainerItemID", bagID, slot)
    sample.itemAfter = P.Call("C_Container.GetContainerItemInfo", bagID, slot)
    sample.sameItemID = P.Integer(id, 1, 2147483647) and id == P.First(sample.idAfter)
    sample.permission = "unknown; hasLoot, tooltip, item spell and API existence do not authorize automated use"
    sample.nextCheck = "Compare a normal manual opening before/after, binding or loot dialogs and quantity; validate each item separately"
    return P.Finish(sample)
end
