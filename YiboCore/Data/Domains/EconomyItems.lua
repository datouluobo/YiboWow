local Core = _G.YiboCore

local bankKnown = false
local function Collect()
    local items = {}
    for _, definition in ipairs((Core.CurrencyCatalog and Core.CurrencyCatalog:GetItems()) or {}) do
        local itemID = tonumber(definition.itemID)
        if itemID and GetItemCount then
            local carried = GetItemCount(itemID, false, false, false) or 0
            local total = GetItemCount(itemID, true, false, false) or carried
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
