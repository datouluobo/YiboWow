local Core = _G.YiboCore

local bankKnown = false
local CARRIED_BAGS = { 0, 1, 2, 3, 4 }
local BANK_BAGS = { -1, 5, 6, 7, 8, 9, 10, 11, 12 }

local function ScanContainers(itemID, includeBank)
    local getSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
    if type(getSlots) ~= "function" or type(getInfo) ~= "function" then return nil end
    local carried, total = 0, 0
    local function Scan(bags)
        for _, bagID in ipairs(bags) do
            for slot = 1, (getSlots(bagID) or 0) do
                local info = getInfo(bagID, slot)
                local foundID, stack
                if type(info) == "table" then
                    foundID, stack = info.itemID, info.stackCount or info.quantity or info.count
                else
                    local _, oldStack, _, _, _, _, _, _, _, oldID = getInfo(bagID, slot)
                    foundID, stack = oldID, oldStack
                end
                if tonumber(foundID) == itemID then
                    stack = tonumber(stack) or 1
                    total = total + stack
                end
            end
        end
    end
    carried = Scan(CARRIED_BAGS)
    if includeBank then Scan(BANK_BAGS) end
    return includeBank and total or carried
end

local function GetCount(itemID, includeBank)
    if C_Item and type(C_Item.GetItemCount) == "function" then
        return C_Item.GetItemCount(itemID, includeBank, false, false)
    end
    if type(GetItemCount) == "function" then
        return GetItemCount(itemID, includeBank, false, false)
    end
    return ScanContainers(itemID, includeBank)
end

local function Collect()
    local items = {}
    for _, definition in ipairs((Core.CurrencyCatalog and Core.CurrencyCatalog:GetItems()) or {}) do
        local itemID = tonumber(definition.itemID)
        if itemID and (C_Item and type(C_Item.GetItemCount) == "function" or type(GetItemCount) == "function" or type(GetContainerItemInfo) == "function" or C_Container and type(C_Container.GetContainerItemInfo) == "function") then
            local carried = GetCount(itemID, false) or 0
            local total = GetCount(itemID, true) or carried
            items[itemID] = { itemID = itemID, carried = carried, total = total, bank = bankKnown and math.max(0, total - carried) or nil, bankKnown = bankKnown }
        end
    end
    return { items = items, bankKnown = bankKnown }, "known"
end

Core.DataDomains:Register("YiboCore", {
    id = "economy-items", version = 1,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, BAG_UPDATE_DELAYED = true, BANKFRAME_OPENED = true, PLAYERBANKSLOTS_CHANGED = true, YIBO_CURRENCY_CATALOG_REGISTERED = true },
    Collect = function(context)
        if context.reason == "BANKFRAME_OPENED" or context.reason == "PLAYERBANKSLOTS_CHANGED" then bankKnown = true end
        return Collect()
    end,
})
