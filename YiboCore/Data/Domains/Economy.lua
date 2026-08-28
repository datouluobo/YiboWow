local Core = _G.YiboCore

-- Retail exposes C_CurrencyInfo tables while MoP Classic still exposes the
-- stable-ID GetCurrencyInfo global.  The list API is only a supplemental UI
-- projection; known registered IDs must work without it.
local function ReadCurrency(currencyID)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then return {
            id = currencyID, name = info.name, quantity = info.quantity, iconFileID = info.iconFileID,
            maxQuantity = info.maxQuantity, weeklyQuantity = info.weeklyQuantity, maxWeeklyQuantity = info.maxWeeklyQuantity,
        } end
    end
    if GetCurrencyInfo then
        local name, quantity, iconFileID, weeklyQuantity, maxWeeklyQuantity, maxQuantity = GetCurrencyInfo(currencyID)
        if name ~= nil then return {
            id = currencyID, name = name, quantity = quantity, iconFileID = iconFileID,
            maxQuantity = maxQuantity, weeklyQuantity = weeklyQuantity, maxWeeklyQuantity = maxWeeklyQuantity,
        } end
    end
    return nil
end

local function CollectCurrencies()
    local list, getInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize, C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListInfo
    local currencies = {}
    if list and getInfo then
        for index = 1, list() do
            local info = getInfo(index)
            if info and info.currencyID and not info.isHeader then
                currencies[info.currencyID] = {
                    id = info.currencyID, name = info.name, quantity = info.quantity, iconFileID = info.iconFileID,
                    maxQuantity = info.maxQuantity, weeklyQuantity = info.weeklyQuantity, maxWeeklyQuantity = info.maxWeeklyQuantity,
                }
            end
        end
    end
    -- The Blizzard list is a UI projection and omits unused historical
    -- currencies.  Registered stable IDs are read directly as well.
    for _, definition in ipairs((Core.CurrencyCatalog and Core.CurrencyCatalog:GetCurrencies()) or {}) do
        local id = tonumber(definition.currencyID)
        local info = id and ReadCurrency(id)
        if info then currencies[id] = info end
    end
    return currencies, (next(currencies) ~= nil or GetCurrencyInfo ~= nil or (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo ~= nil)) and "known" or "unavailable"
end

Core.DataDomains:Register("YiboCore", {
    id = "economy", version = 1,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, PLAYER_MONEY = true, CURRENCY_DISPLAY_UPDATE = true, YIBO_CURRENCY_CATALOG_REGISTERED = true },
    Collect = function()
        local currencies, currencyState = CollectCurrencies()
        -- Money is independent of the optional currency API. A missing
        -- currency API must never erase every character's gold balance.
        return { money = GetMoney and GetMoney() or 0, currencies = currencies or {}, currencyState = currencyState }, "known"
    end,
    ProjectLegacy = function(record, data, domain)
        record.profile = record.profile or {}; record.profile.money, record.profile.currencies = data.money, data.currencies
        record.observedAt = record.observedAt or {}; record.observedAt.currencies = domain.updatedAt
        record.availability = record.availability or {}; record.availability.currencies = domain.state
    end,
})
