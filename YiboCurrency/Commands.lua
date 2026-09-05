local Addon = _G.YiboCurrency
SLASH_YCU1 = "/ycu"
SlashCmdList["YCU"] = function(message)
    message = strtrim(message or "")
    if message == "" then Addon:OpenAccountPage(); return end
    if message == "probe" then
        local core = _G.YiboCore
        local character = core and core.Characters and core.Characters:GetCurrent()
        local snapshot = character and core.DataDomains and core.DataDomains:Get(character.id, "economy")
        local data = snapshot and snapshot.data or {}
        local count = 0
        for _ in pairs(data.currencies or {}) do count = count + 1 end
        Addon:Print(string.format("货币 API：GetCurrencyInfo=%s，C_CurrencyInfo=%s；经济域=%s；金币=%s；已读取标准货币=%d。",
            GetCurrencyInfo and "可用" or "不可用", C_CurrencyInfo and "可用" or "不可用", snapshot and snapshot.state or "未扫描", tostring(data.money), count))
        for _, entry in ipairs(Addon:GetCatalog()) do
            if entry.currencyID then
                local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(entry.currencyID)
                local name, weekly, weeklyMax, maximum = info and info.name, info and info.weeklyQuantity, info and info.maxWeeklyQuantity, info and info.maxQuantity
                if not name and GetCurrencyInfo then name, _, _, weekly, weeklyMax, maximum = GetCurrencyInfo(entry.currencyID) end
                Addon:Print(string.format("%s · %s · 本周 %s/%s · 上限 %s · %s", entry.id, name or "客户端未返回名称", tostring(weekly), tostring(weeklyMax), tostring(maximum), entry.status or "待核验"))
            elseif entry.itemID then
                local name = GetItemInfo and GetItemInfo(entry.itemID)
                Addon:Print(string.format("%s · %s · %s", entry.id, name or "客户端未缓存名称", entry.status or "待核验"))
            end
        end
        return
    end
    local itemID = message:match("^add%s+(%d+)$")
    if itemID then Addon:Print("自定义物品代币需要在设置页确认客户端名称与图标；该交互将在下一轮目录编辑中开放。"); return end
    Addon:Print("命令：/ycu（打开货币总览）；/ycu probe（输出货币 API 诊断）")
end
