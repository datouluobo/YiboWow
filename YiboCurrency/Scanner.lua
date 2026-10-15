local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Scanner = { retries = 0 }
Addon.Scanner = Scanner
local function Safe(callback, ...)
    if type(callback) ~= "function" then return nil, "unavailable" end
    local ok, value = pcall(callback, ...)
    if not ok then return nil, "error" end
    return value
end

local function Currency(id)
    local info, err
    if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then info, err = Safe(C_CurrencyInfo.GetCurrencyInfo, id) end
    if not info and type(GetCurrencyInfo) == "function" then
        local values = { pcall(GetCurrencyInfo, id) }
        if values[1] and values[2] then info = { name = values[2], quantity = values[3], iconFileID = values[4],
            weeklyQuantity = values[5], maxWeeklyQuantity = values[6], maxQuantity = values[7] }
        elseif not values[1] then err = "error" end
    end
    if type(info) ~= "table" or type(info.name) ~= "string" or info.name == "" then
        local available = type(GetCurrencyInfo) == "function" or (C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function")
        return nil, err or (available and "unsupported" or "unavailable")
    end
    if not Addon.Store.Count(info.quantity) then return nil, "error" end
    local result = { quantity = info.quantity, name = info.name, iconFileID = info.iconFileID, state = "known", observedAt = Addon.Store.Now() }
    for _, key in ipairs({ "weeklyQuantity", "maxWeeklyQuantity", "maxQuantity" }) do
        if info[key] ~= nil and not Addon.Store.Count(info[key]) then return nil, "error" end
        result[key] = info[key]
    end
    local seconds = C_DateAndTime and Safe(C_DateAndTime.GetSecondsUntilWeeklyReset)
    if Addon.Store.Count(seconds) and seconds > 0 then
        result.weeklyResetAt = Addon.Store.Now() + seconds
        result.weeklyState = result.weeklyQuantity ~= nil and "known" or "unknown"
    else result.weeklyState = "unknown" end
    return result
end

function Scanner:ReadNative(id)
    local previous = Addon.Store:Get(id, "native")
    local data = { currencies = {}, moneyState = "unknown" }
    local money, moneyError = Safe(GetMoney)
    if Addon.Store.Count(money) then data.moneyCopper, data.moneyState = money, "known"
    elseif previous then data.moneyCopper, data.moneyState = previous.data.moneyCopper, moneyError or "error"
    else data.moneyState = moneyError or "error" end
    local known, retryNeeded = data.moneyState == "known", data.moneyState ~= "known"
    for _, entry in ipairs(Addon:GetCatalog()) do
        if entry.currencyID then
            local value, state = Currency(entry.currencyID)
            if value then known = true
            else
                local old = previous and previous.data.currencies[entry.currencyID]
                value = old and Addon.Store.Copy(old) or {}
                value.state, value.weeklyState = state, "unknown"
                if state == "error" or state == "unavailable" then retryNeeded = true end
            end
            data.currencies[entry.currencyID] = value
        end
    end
    return data, known and "known" or "unavailable", retryNeeded
end

function Scanner:ReadTokens()
    local wanted, counts = {}, {}
    for _, entry in ipairs(Addon:GetCatalog()) do
        if entry.itemID and (entry.verified == "implemented" or entry.verified == "client") then wanted[entry.itemID] = true; counts[entry.itemID] = 0 end
    end
    local slots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local info = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
    if type(slots) == "function" and type(info) == "function" then
        for bag = 0, 4 do
            local length = Safe(slots, bag)
            if not Addon.Store.Count(length) then return nil, "unavailable" end
            for slot = 1, length do
                local values = { pcall(info, bag, slot) }
                if not values[1] then return nil, "error" end
                local itemID, quantity
                if type(values[2]) == "table" then itemID, quantity = values[2].itemID, values[2].stackCount or values[2].quantity or values[2].count
                else itemID, quantity = values[11], values[3] end
                if itemID == nil and C_Container and type(C_Container.GetContainerItemID) == "function" then itemID = Safe(C_Container.GetContainerItemID, bag, slot) end
                if itemID == nil and type(values[8]) == "string" then itemID = tonumber(values[8]:match("item:(%d+)")) end
                itemID = tonumber(itemID)
                if wanted[itemID] then
                    if not Addon.Store.Count(quantity) then return nil, "error" end
                    counts[itemID] = counts[itemID] + quantity
                end
            end
        end
    else
        local read = C_Item and C_Item.GetItemCount or GetItemCount
        for itemID in pairs(wanted) do
            local quantity = Safe(read, itemID, false, false, false)
            if not Addon.Store.Count(quantity) then return nil, "unavailable" end
            counts[itemID] = quantity
        end
    end
    local items = {}; for id, carried in pairs(counts) do items[id] = { carried = carried } end
    return { items = items }, "partial"
end

function Scanner:Scan(native, tokens)
    local character = Core.Characters:GetCurrent({ identityOnly = true })
    if not character then return false end
    local success = true
    if native then
        local data, state, retryNeeded = self:ReadNative(character.id)
        local ok = Addon.Store:Commit(character.id, "native", data, state)
        success = ok ~= nil and state == "known" and not retryNeeded and success
    end
    if tokens then
        local data, state = self:ReadTokens()
        local ok = Addon.Store:Commit(character.id, "carriedTokens", data, state)
        success = ok ~= nil and state == "partial" and success
    end
    return success
end

function Scanner:Request(reason, retry)
    local native = reason ~= "BAG_UPDATE_DELAYED" and reason ~= "PLAYER_EQUIPMENT_CHANGED" and reason ~= "catalog"
    local tokens = reason ~= "PLAYER_MONEY" and reason ~= "CURRENCY_DISPLAY_UPDATE"
    self.pendingNative, self.pendingTokens = self.pendingNative or native, self.pendingTokens or tokens
    if not retry then self.retries = 0 end
    if self.queued then return end
    self.queued = true
    local function Run()
        self.queued = false
        local n, t = self.pendingNative, self.pendingTokens; self.pendingNative, self.pendingTokens = nil, nil
        local ok = self:Scan(n, t)
        if not ok and self.retries < 3 and C_Timer and type(C_Timer.After) == "function" then
            self.retries = self.retries + 1
            local retryReason = n and (t and "retry-all" or "PLAYER_MONEY") or "catalog"
            C_Timer.After(1, function() self:Request(retryReason, true) end)
        end
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, Run) else Run() end
end

function Scanner:Initialize()
    if self.frame then return true end
    local frame = CreateFrame("Frame"); self.frame = frame
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" }) do frame:RegisterEvent(event) end
    frame:SetScript("OnEvent", function(_, event) self:Request(event) end)
    self:Request("initialize")
    return true
end
