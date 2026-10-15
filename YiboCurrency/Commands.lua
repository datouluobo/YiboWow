local Addon = _G.YiboCurrency
local function Read(callback, ...)
    if type(callback) ~= "function" then return nil end
    local ok, value = pcall(callback, ...)
    return ok and value or nil
end
SLASH_YCU1 = "/ycu"
SlashCmdList["YCU"] = function(message)
    message = strtrim(message or "")
    if message == "" then Addon:OpenAccountPage(); return end
    if not (Addon.CoreIntegration and Addon.CoreIntegration.initialized) then Addon:OpenAccountPage(); return end
    if message == "scan" then
        Addon.Scanner:Request("manual")
        Addon:Print(Addon:T("MIGRATION.SCAN")); return
    elseif message == "migrate" then
        local imported, failed, err = Addon.Migration:ImportAll()
        if imported == nil then Addon:Print(err); return end
        Addon:Print(Addon:T("MIGRATION.RESULT", imported, failed)); return
    elseif message == "status" then
        local records, failed, blocked = 0, 0, 0
        for _ in pairs(Addon.Store.db.characters) do records = records + 1 end
        for _, metadata in pairs(Addon.Store.db.migration.byCharacter) do if metadata.status == "failed" then failed = failed + 1 end end
        for _ in pairs(Addon.Store.db.migration.blocked) do blocked = blocked + 1 end
        Addon:Print(Addon:T("MIGRATION.STATUS", records, failed, blocked)); return
    end
    if message == "probe" then
        local core = _G.YiboCore
        local character = core and core.Characters and core.Characters:GetCurrent()
        local snapshot = character and Addon.Store:Get(character.id, "native")
        local itemSnapshot = character and Addon.Store:Get(character.id, "carriedTokens")
        local data = snapshot and snapshot.data or {}
        local itemData = itemSnapshot and itemSnapshot.data or {}
        local count = 0
        for _ in pairs(data.currencies or {}) do count = count + 1 end
        Addon:Print(Addon:T("MIGRATION.PROBE", snapshot and snapshot.state or "unknown",
            tostring(snapshot and snapshot.observedAt), tostring(data.moneyCopper), count))
        for _, entry in ipairs(Addon:GetCatalog()) do
            if entry.currencyID then
                local info = C_CurrencyInfo and Read(C_CurrencyInfo.GetCurrencyInfo, entry.currencyID)
                if type(info) ~= "table" then info = nil end
                local name, weekly, weeklyMax, maximum = info and info.name, info and info.weeklyQuantity, info and info.maxWeeklyQuantity, info and info.maxQuantity
                if not name and type(GetCurrencyInfo) == "function" then
                    local ok, oldName, _, _, oldWeekly, oldWeeklyMax, oldMaximum = pcall(GetCurrencyInfo, entry.currencyID)
                    if ok then name, weekly, weeklyMax, maximum = oldName, oldWeekly, oldWeeklyMax, oldMaximum end
                end
                Addon:Print(string.format(Addon:T("CURRENCY.S_S_WEEKLY_S_S_CAP_S_S_6F8DFE"), entry.id, name or Addon:T("CURRENCY.NO_CLIENT_NAME_314AE2"), tostring(weekly), tostring(weeklyMax), tostring(maximum), entry.status or Addon:T("CURRENCY.UNVERIFIED_CF5B41")))
            elseif entry.itemID then
                local name = Read(GetItemInfo, entry.itemID)
                local live = C_Item and Read(C_Item.GetItemCount, entry.itemID, false, false, false)
                local stored = itemData.items and itemData.items[entry.itemID]
                Addon:Print(string.format(Addon:T("CURRENCY.S_S_BAGS_S_SNAPSHOT_S_S_465EA9"), entry.id, name or Addon:T("CURRENCY.NAME_NOT_CACHED_C21DAA"), tostring(live), tostring(stored and (stored.total or stored.carried) or Addon:T("CURRENCY.MISSING_2FE9B7")), entry.status or Addon:T("CURRENCY.UNVERIFIED_CF5B41")))
            end
        end
        return
    end
    local itemID = message:match("^add%s+(%d+)$")
    if itemID then Addon:Print(Addon:T("CURRENCY.ADD_CUSTOM_ITEM_TOKENS_IN_SETTINGS_DATA_CACHE_E237DA")); return end
    Addon:Print(Addon:T("MIGRATION.HELP"))
end
